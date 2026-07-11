#!/usr/bin/env bash
#
# smalltalk-gnu.sh - GNU Smalltalk implementation
#
set -Euo pipefail
IFS=$'\n\t'

# shellcheck source=libexec/smalltalk-common.sh
source "${BASH_SOURCE%/*}/smalltalk-common.sh"

#################################
## GNU Smalltalk Configuration
#################################

GNUSTACK_VERSION="${GNUSTACK_VERSION:-3.2.5}"
GNUSTACK_URL_BASE="https://ftp.gnu.org/gnu/smalltalk"
GNUSTACK_CACHE_DIR="${CACHE_DIR}/gnu"

#################################
## GNU Smalltalk Helper Functions
#################################

# Unalias gst if it exists (Zsh omz git plugin may alias gst to git status)
unescape_gst_alias() {
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ -n "${BASH_VERSION:-}" ]]; then
        # Check if gst is an alias
        local gst_type
        gst_type=$(type gst 2> /dev/null || true)
        if [[ "$gst_type" == *"is an alias"* ]]; then
            unalias gst 2> /dev/null || true
        fi
    fi
}

# Check if GNU Smalltalk is installed
is_gnustack_installed() {
    if command -v gst &> /dev/null; then
        echo "system"
        return 0
    fi
    return 1
}

# Install GNU Smalltalk from source or binary
install_gnustack_from_source() {
    local install_dir="${1:-$HOME/gnu-smalltalk}"
    local original_dir
    original_dir="$(pwd)"

    log_info "Installing GNU Smalltalk from source..."
    log_info "This may take a while as it requires compilation."

    # Check for build dependencies; suggest an OS-tailored install one-liner.
    local deps=("gcc" "make" "bison" "flex" "libtool" "gettext")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! cmd_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        suggest_install_packages "${missing_deps[@]}"
        die "Cannot install GNU Smalltalk without the required build tools."
    fi

    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    local archive_name="smalltalk-${GNUSTACK_VERSION}.tar.xz"
    local download_url="${GNUSTACK_URL_BASE}/${archive_name}"

    install_dir="$(pwd)"
    log_info "Downloading GNU Smalltalk ${GNUSTACK_VERSION} to ${install_dir}..."
    download_file "$download_url" "$archive_name"

    if [[ ! -f "$archive_name" ]]; then
        cd "$original_dir"
        die "Failed to download GNU Smalltalk"
    fi

    extract_archive "$archive_name" "."
    rm -f -- "$archive_name"

    local source_dir="smalltalk-${GNUSTACK_VERSION}"
    if [[ ! -d "$source_dir" ]]; then
        cd "$original_dir"
        die "Failed to extract GNU Smalltalk source"
    fi

    cd "$source_dir" || {
                          cd "$original_dir"
                                              die "Cannot change to source directory"
    }

    log_info "Configuring..."
    ./configure --prefix="$install_dir" || {
                                             cd "$original_dir"
                                                                 die "Configuration failed"
    }

    log_info "Building (this may take a while)..."
    make -j"$(nproc 2> /dev/null || echo 4)" || {
                                                 cd "$original_dir"
                                                                     die "Build failed"
    }

    log_info "Installing..."
    make install || {
                      cd "$original_dir"
                                          die "Installation failed"
    }

    cd "$original_dir"

    # Add to PATH
    local bin_dir="$install_dir/bin"
    if [[ -d "$bin_dir" ]]; then
        log_info "GNU Smalltalk installed to $bin_dir"
        log_info "Add this to your PATH: export PATH=\"$bin_dir:\$PATH\""
    fi

    log_success "GNU Smalltalk installed successfully to ${install_dir}"
}

# Ask the user how to proceed when the gnu-smalltalk apt package is unavailable
# (Debian 12+ / recent Ubuntu, where the package was removed). Echoes one of:
#   source | container | cancel
# Non-interactive (SMALLTALK_YES set, or no TTY on stdin) defaults to "source".
choose_gnustack_fallback() {
    if [[ -n "${SMALLTALK_YES:-}" ]] || [[ ! -t 0 ]]; then
        echo "source"
        return 0
    fi
    printf '\nGNU Smalltalk is not available via apt on this system.\n' >&2
    printf 'How would you like to install it?\n' >&2
    printf '  1) Build from source (vanilla %s - may fail with modern GCC)\n' "${GNUSTACK_VERSION}" >&2
    printf '  2) Use a Debian 11 (bullseye) container via Docker (gst installs with apt)\n' >&2
    printf '  3) Cancel\n' >&2
    local choice
    while true; do
        read -r -p "Select [1-3] (default 1): " choice || {
                                                            echo "source"
                                                                           return 0
        }
        case "$choice" in
            1 | "")
                echo "source"
                return 0
                ;;
            2)
                echo "container"
                return 0
                ;;
            3)
                echo "cancel"
                return 0
                ;;
            *)
                printf 'Invalid choice.\n' >&2
                ;;
        esac
    done
}

# Launch a Debian 11 (bullseye) container, install gnu-smalltalk via apt (the
# package still exists there), and drop into an interactive shell where 'gst' is
# available. The container is removed on exit (--rm). Requires Docker.
# Print an OS/package-manager-tailored one-liner to install Docker.
suggest_install_docker() {
    local os_type
    os_type=$(get_os)
    case "$os_type" in
        macos)
            log_info "On macOS, install Docker Desktop with:"
            printf '  brew install --cask docker\n'
            ;;
        linux)
            if cmd_exists apt-get; then
                log_info "On Debian/Ubuntu, install Docker with:"
                printf '  sudo apt-get install -y docker.io\n'
            elif cmd_exists dnf; then
                log_info "On Fedora/RHEL, install Docker with:"
                printf '  sudo dnf install -y docker\n'
            elif cmd_exists pacman; then
                log_info "On Arch, install Docker with:"
                printf '  sudo pacman -S --noconfirm docker\n'
            else
                log_info "Install Docker via your package manager."
            fi
            log_info 'Then start the daemon (e.g. `sudo systemctl enable --now docker`) and add yourself to the docker group (`sudo usermod -aG docker "$USER"`; re-login), or run Docker with sudo.'
            ;;
        *)
            log_info "Install Docker via your package manager, then start the daemon."
            ;;
    esac
}

install_gnustack_in_container() {
    if ! cmd_exists docker; then
        log_error "Docker is not installed."
        suggest_install_docker
        log_info "Or choose 'Build from source' instead."
        return 1
    fi
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not reachable (not running, or you lack permissions)."
        log_info "Start Docker (and add your user to the 'docker' group), or choose 'Build from source'."
        return 1
    fi
    log_info "Launching a Debian 11 (bullseye) container and installing GNU Smalltalk..."
    log_info "Once the prompt appears, run 'gst --version' to verify; 'exit' to leave (container is auto-removed)."
    docker run --rm -it debian:bullseye-slim \
        bash -c 'apt-get update && apt-get install -y gnu-smalltalk && exec bash'
    return $?
}

# Install via package manager with user confirmation
install_gnustack_package() {
    local os_type
    os_type=$(get_os)

    case "$os_type" in
        macos)
            if cmd_exists brew; then
                log_info "Installing GNU Smalltalk via Homebrew..."
                brew install gnu-smalltalk
            else
                die "Homebrew not found. Install from source with 'st gnu install --source'"
            fi
            ;;
        linux)
            log_info "GNU Smalltalk requires sudo privileges for package installation."
            log_info "You may be prompted for your password."

            if [[ -z "${SMALLTALK_YES:-}" ]]; then
                if ! confirm "Continue with sudo installation?"; then
                    log_info "Installation cancelled. Use --source to build without sudo."
                    return 1
                fi
            fi

            if cmd_exists apt-get; then
                log_info "Installing GNU Smalltalk via apt..."
                # The Debian/Ubuntu package is 'gnu-smalltalk' (not 'smalltalk'). It was
                # removed from Debian 12+ / recent Ubuntu because upstream GNU Smalltalk
                # became unmaintained and no longer builds cleanly with modern
                # toolchains. If apt can't provide it, fall back to building from source.
                if sudo apt-get install -y gnu-smalltalk && command -v gst > /dev/null 2>&1; then
                    log_success "GNU Smalltalk installed via apt"
                    return 0
                fi
                log_warn "The 'gnu-smalltalk' package is unavailable in your apt repositories."
                local fallback
                fallback=$(choose_gnustack_fallback)
                case "$fallback" in
                    container)
                        install_gnustack_in_container
                        return $?
                        ;;
                    cancel)
                        log_info "Installation cancelled."
                        return 1
                        ;;
                    source)
                        log_info "Building GNU Smalltalk ${GNUSTACK_VERSION} from source (this takes a while)."
                        log_info "Installing build dependencies (sudo)..."
                        sudo apt-get install -y \
                            build-essential autoconf automake libtool libtool-bin texinfo pkg-config gawk zip unzip \
                            libgmp-dev libffi-dev libsigsegv-dev libreadline-dev libncurses-dev libltdl-dev \
                            zlib1g-dev libsqlite3-dev libgdbm-dev libexpat1-dev \
                            || die "Failed to install build dependencies"
                        local ts build_dir
                        ts=$(date +%Y%m%d_%H%M%S)
                        build_dir="${HOME}/gnu-smalltalk_${ts}"
                        mkdir -p -- "$build_dir"
                        install_gnustack_from_source "$build_dir"
                        ;;
                esac
            elif cmd_exists dnf; then
                log_info "Installing GNU Smalltalk via dnf..."
                sudo dnf install -y smalltalk
            elif cmd_exists pacman; then
                log_info "Installing GNU Smalltalk via pacman..."
                sudo pacman -S --noconfirm smalltalk
            else
                die "No supported package manager found. Install from source with 'st gnu install --source'"
            fi
            ;;
        *)
            die "Unsupported OS for package installation: $os_type"
            ;;
    esac
}

# Run GNU Smalltalk
run_gnustack() {
    if ! is_gnustack_installed; then
        die "GNU Smalltalk is not installed. Run 'st gnu install' first."
    fi

    # Unalias gst if it's an alias (Zsh omz git plugin)
    unescape_gst_alias

    # Run gst with any additional arguments
    if [[ $# -eq 0 ]]; then
        gst
    else
        gst "$@"
    fi
}

#################################
## Command Handlers
#################################

smalltalk_gnu_help() {
    load_help_from_doc "gnu"
}

smalltalk_gnu_install() {
    local use_source=false
    local install_arg=""

    # Handle case when no arguments provided (set -u safety)
    if [[ $# -gt 0 ]]; then
        if [[ "$1" == "--source" ]]; then
            use_source=true
            shift
        fi
        if [[ $# -gt 0 ]]; then
            install_arg="$1"
        fi
    fi

    local install_dir="${install_arg:-$HOME/gnu-smalltalk}"

    # If installing from source and no destination, use timestamped directory
    if $use_source && [[ "$install_arg" == "" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="gnu-smalltalk_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
    fi

    if $use_source; then
        mkdir -p "$install_dir"
        install_gnustack_from_source "$install_dir"
    else
        install_gnustack_package
    fi
}

smalltalk_gnu_run() {
    if ! is_gnustack_installed; then
        log_info "GNU Smalltalk not found, installing..."
        smalltalk_gnu_install || {
                                   log_error "GNU Smalltalk installation failed"
                                                                                  return 1
        }
        if ! is_gnustack_installed; then
            log_error "GNU Smalltalk installed but 'gst' not found on PATH"
            log_info "Add the install bin directory to your PATH or restart your shell"
            return 1
        fi
    fi
    run_gnustack "$@"
}

smalltalk_gnu_search() {
    log_info "Searching for GNU Smalltalk packages..."
    log_info "Visit https://github.com/bonzini/smalltalk to browse packages"
}

smalltalk_gnu_list() {
    log_info "Available packages for GNU Smalltalk:"
    log_info "Visit https://github.com/bonzini/smalltalk to browse packages"
}

smalltalk_gnu_update() {
    ensure_cache_dir
    mkdir -p "${GNUSTACK_CACHE_DIR}"
    log_info "GNU Smalltalk package information updated"
}

smalltalk_gnu_clean() {
    if [[ -d "${GNUSTACK_CACHE_DIR}" ]]; then
        rm -rf -- "${GNUSTACK_CACHE_DIR:?}"/*
        log_info "GNU Smalltalk cache cleaned"
    else
        log_info "GNU Smalltalk cache directory does not exist"
    fi
}

smalltalk_gnu_clean_artifacts() {
    log_info "Cleaning GNU Smalltalk artifacts..."

    local impl_dir
    impl_dir=$(manifest_get_dir "gnu")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        local patterns=(
            "gst"
            "gst-run"
            "*.image"
            "*.changes"
            "lib/*.so"
        )

        for pattern in "${patterns[@]}"; do
            find . -maxdepth 2 -name "$pattern" -exec rm -rf -- {} \; 2> /dev/null || true
        done

        manifest_remove "gnu"
        log_success "GNU Smalltalk artifacts cleaned"
    else
        log_info "No registered GNU Smalltalk installation found in manifest"
        log_info "To clean manually, remove GNU Smalltalk files from your installation directory"
    fi
}

smalltalk_gnu_version() {
    if is_gnustack_installed; then
        # Unalias gst if it's an alias (Zsh omz git plugin)
        unescape_gst_alias
        gst --version
    else
        echo "GNU Smalltalk is not installed"
        return 1
    fi
}

smalltalk_gnu_eval() {
    log_error "GNU Smalltalk does not support command-line code evaluation"
    log_info "Use 'st gnu run' to start the REPL"
    log_info "Or write code to a file and use 'st gnu run script.st'"
    log_info "For headless evaluation, consider using Pharo or Cuis"
    return 1
}
