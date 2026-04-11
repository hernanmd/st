#!/usr/bin/env bash
#
# smalltalk-gnu.sh - GNU Smalltalk implementation
#
set -u
set -o pipefail

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

# Check if GNU Smalltalk is installed
is_gnustack_installed() {
    if command -v gst &>/dev/null; then
        echo "system"
        return 0
    fi
    return 1
}

# Install GNU Smalltalk from source or binary
install_gnustack_from_source() {
    local install_dir="${1:-$HOME/gnu-smalltalk}"

    log_info "Installing GNU Smalltalk from source..."
    log_info "This may take a while as it requires compilation."

    # Check for dependencies
    local deps=("gcc" "make" "bison" "flex" "libtool" "gettext")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! cmd_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "On Debian/Ubuntu: sudo apt-get install ${missing_deps[*]}"
        log_info "On macOS: brew install ${missing_deps[*]}"
        die "Cannot install GNU Smalltalk without dependencies"
    fi

    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    local archive_name="smalltalk-${GNUSTACK_VERSION}.tar.xz"
    local download_url="${GNUSTACK_URL_BASE}/${archive_name}"

        install_dir="$(pwd)"
    log_info "Downloading GNU Smalltalk ${GNUSTACK_VERSION} to ${install_dir}..."
    download_file "$download_url" "$archive_name"

    if [[ ! -f "$archive_name" ]]; then
        die "Failed to download GNU Smalltalk"
    fi

    extract_archive "$archive_name" "."
    rm -f "$archive_name"

    local source_dir="smalltalk-${GNUSTACK_VERSION}"
    if [[ ! -d "$source_dir" ]]; then
        die "Failed to extract GNU Smalltalk source"
    fi

    cd "$source_dir" || die "Cannot change to source directory"

    log_info "Configuring..."
    ./configure --prefix="$install_dir" || die "Configuration failed"

    log_info "Building (this may take a while)..."
    make -j"$(nproc 2>/dev/null || echo 4)" || die "Build failed"

    log_info "Installing..."
    make install || die "Installation failed"

    # Add to PATH
    local bin_dir="$install_dir/bin"
    if [[ -d "$bin_dir" ]]; then
        log_info "GNU Smalltalk installed to $bin_dir"
        log_info "Add this to your PATH: export PATH=\"$bin_dir:\$PATH\""
    fi

    log_success "GNU Smalltalk installed successfully to ${install_dir}"
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
                die "Homebrew not found. Install from source with 'smalltalk gnu install --source'"
            fi
            ;;
        linux)
            log_info "GNU Smalltalk requires sudo privileges for package installation."
            log_info "You may be prompted for your password."
            
            if [[ -z "$SMALLTALK_YES" ]]; then
                if ! confirm "Continue with sudo installation? [y/N] "; then
                    log_info "Installation cancelled. Use --source to build without sudo."
                    return 1
                fi
            fi
            
            if cmd_exists apt-get; then
                log_info "Installing GNU Smalltalk via apt..."
                sudo apt-get install -y smalltalk
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
        rm -rf "${GNUSTACK_CACHE_DIR:?}"/*
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
            find . -maxdepth 2 -name "$pattern" -exec rm -rf {} \; 2>/dev/null || true
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
        gst --version
    else
        echo "GNU Smalltalk is not installed"
        return 1
    fi
}

smalltalk_gnu_eval() {
    local code="${1:-}"
    
    if [[ -z "$code" ]]; then
        log_error "Please provide code to evaluate"
        echo "Usage: st gnu eval '<code>'"
        return 1
    fi
    
    if ! is_gnustack_installed; then
        log_error "GNU Smalltalk is not installed"
        log_error "Run 'st gnu install' first"
        return 1
    fi
    
    echo "$code" | gst --quiet
}
