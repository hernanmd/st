#!/usr/bin/env bash
#
# smalltalk-lst.sh - Little Smalltalk v3 implementation
#
set -u
set -o pipefail

source "${BASH_SOURCE%/*}/smalltalk-common.sh"

#################################
## Little Smalltalk Configuration
#################################

LST_VERSION="${LST_VERSION:-latest}"
LST_URL_BASE="https://codeberg.org/suetanvil/lst3r"
LST_CACHE_DIR="${CACHE_DIR}/lst"

#################################
## Little Smalltalk Helper Functions
#################################

# Get latest LST release from GitLab/Codeberg
get_latest_lst_version() {
    local version
    version=$(curl -sL "https://codeberg.org/api/v1/repos/suetanvil/lst3r/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v3")
    echo "$version"
}

# Check if LST is installed
is_lst_installed() {
    local search_paths=("." "$HOME/lst3r" "$HOME/.local/bin/lst3r")

    for path in "${search_paths[@]}"; do
        if [[ -f "${path}/lst3r" ]] || [[ -x "${path}/lst3r" ]]; then
            echo "$path"
            return 0
        fi
        if [[ -d "${path}/lst3r" ]] && [[ -f "${path}/lst3r/lst3r" ]]; then
            echo "$path/lst3r"
            return 0
        fi
    done

    # Also check PATH
    if command -v lst3r &>/dev/null; then
        echo "system"
        return 0
    fi

    return 1
}

# Download and build LST from source
download_lst_source() {
    local install_dir="${1:-$HOME/lst3r}"

    log_info "Downloading Little Smalltalk v3 source..."

    # Ensure the directory exists
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    # Clone the repository
    if [[ ! -d ".git" ]]; then
        git clone "https://codeberg.org/suetanvil/lst3r.git" "$install_dir" 2>/dev/null || {
            # Try GitHub mirror if Codeberg fails
            git clone "https://github.com/nordlow/lst3r.git" "$install_dir" 2>/dev/null || {
                die "Failed to clone LST repository"
            }
        }
    fi

    cd "$install_dir" || die "Cannot change to LST directory"

    log_info "Building Little Smalltalk v3..."

    # Detect build system
    if [[ -f "Makefile" ]]; then
        make -j"$(nproc 2>/dev/null || echo 4)" || die "Build failed"
    elif [[ -f "CMakeLists.txt" ]]; then
        mkdir -p build
        cd build
        cmake .. || die "CMake configuration failed"
        make -j"$(nproc 2>/dev/null || echo 4)" || die "Build failed"
        cd ..
    elif [[ -f "meson.build" ]]; then
        meson setup build || die "Meson setup failed"
        meson compile -C build || die "Build failed"
    else
        die "No build system found. Expected Makefile, CMakeLists.txt, or meson.build"
    fi

    # Ensure lst3r is executable
    if [[ -f "./lst3r" ]]; then
        chmod +x ./lst3r
    fi

    log_info "LST installed to: $install_dir/lst3r"
    log_info "Add $install_dir to your PATH to use 'lst3r' directly"

    log_success "Little Smalltalk v3 installed successfully"
}

# Download prebuilt LST binary
download_lst_binary() {
    local install_dir="${1:-.}"

    log_info "Downloading Little Smalltalk v3..."

    local os_type
    os_type=$(get_os)
    local arch
    arch=$(get_arch)

    # Ensure the directory exists
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    local download_url
    local archive_name

    case "$os_type" in
        macos)
            archive_name="lst3r-macos.tar.gz"
            download_url="https://github.com/nordlow/lst3r/releases/latest/download/lst3r-macos.tar.gz"
            ;;
        linux)
            if [[ "$arch" == "x86_64" ]]; then
                archive_name="lst3r-linux.tar.gz"
                download_url="https://github.com/nordlow/lst3r/releases/latest/download/lst3r-linux.tar.gz"
            else
                die "No prebuilt binary for $arch. Use --build from source instead."
            fi
            ;;
        *)
            die "No prebuilt binary for $os_type. Use --build from source instead."
            ;;
    esac

    download_file "$download_url" "$archive_name"

    if [[ -f "$archive_name" ]]; then
        extract_archive "$archive_name"
        rm -f "$archive_name"

        if [[ -f "./lst3r" ]]; then
            chmod +x ./lst3r
            log_success "Little Smalltalk v3 installed successfully"
        else
            die "Failed to extract LST"
        fi
    else
        die "Failed to download Little Smalltalk v3"
    fi
}

# Run LST
run_lst() {
    local lst_path
    lst_path=$(is_lst_installed) || die "LST is not installed. Run 'smalltalk lst install' first."

    if [[ "$lst_path" == "system" ]]; then
        lst3r "$@"
    elif [[ -f "${lst_path}/lst3r" ]]; then
        "${lst_path}/lst3r" "$@"
    elif [[ -f "$lst_path" ]]; then
        "$lst_path" "$@"
    else
        die "LST executable not found"
    fi
}

#################################
## Command Handlers
#################################

smalltalk_lst_help() {
    cat << 'EOF'
Little Smalltalk v3 Commands
============================

Usage: smalltalk [-x] lst <command>

Commands:
  install [--build]   Install LST (use --build to compile from source)
  run [args]          Run Little Smalltalk
  search <term>       Search for packages
  list                List available packages
  update              Update package information
  clean               Clean cache directory
  clean_artifacts      Clean installed artifacts
  version             Show LST version
  help                Show this help message

Options:
  --build             Build from source instead of prebuilt binary

Debug Mode:
  -x, --debug         Enable debug mode (set -x tracing)
                      Must be specified before implementation name
                      Example: smalltalk -x lst install

Examples:
  smalltalk lst install           # Download prebuilt binary
  smalltalk lst install --build   # Build from source
  smalltalk -x lst install        # Install with debug output
  smalltalk lst run               # Start REPL
  smalltalk lst run script.lst3   # Run a .lst3 file

About Little Smalltalk v3:
  Little Smalltalk is a simplified Smalltalk dialect designed
  for learning and teaching. Version 3 is a modern rewrite.
  Repository: https://codeberg.org/suetanvil/lst3r

EOF
}

smalltalk_lst_install() {
    local build_from_source=false
    local install_arg=""

    # Handle case when no arguments provided (set -u safety)
    if [[ $# -gt 0 ]]; then
        if [[ "$1" == "--build" ]]; then
            build_from_source=true
            shift
        fi
        if [[ $# -gt 0 ]]; then
            install_arg="$1"
        fi
    fi

    local install_dir="${install_arg:-$HOME/lst3r}"

    # If no destination specified, use timestamped directory
    if [[ -z "$install_arg" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="lst3r_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
    fi

    # Create directory if needed
    mkdir -p "$install_dir"

    if $build_from_source; then
        download_lst_source "$install_dir"
    else
        download_lst_binary "$install_dir"
    fi
}

smalltalk_lst_run() {
    run_lst "$@"
}

smalltalk_lst_search() {
    log_info "Searching for Little Smalltalk packages..."
    log_info "Visit https://codeberg.org/suetanvil/lst3r to browse packages"
}

smalltalk_lst_list() {
    log_info "Available packages for Little Smalltalk:"
    log_info "Visit https://codeberg.org/suetanvil/lst3r to browse packages"
}

smalltalk_lst_update() {
    ensure_cache_dir
    mkdir -p "${LST_CACHE_DIR}"
    log_info "LST package information updated"
}

smalltalk_lst_clean() {
    if [[ -d "${LST_CACHE_DIR}" ]]; then
        rm -rf "${LST_CACHE_DIR:?}"/*
        log_info "LST cache cleaned"
    else
        log_info "LST cache directory does not exist"
    fi
}

smalltalk_lst_clean_artifacts() {
    log_info "Cleaning Little Smalltalk artifacts..."

    local impl_dir
    impl_dir=$(manifest_get_dir "lst")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        local patterns=(
            "lst3r"
            "*.st"
        )

        for pattern in "${patterns[@]}"; do
            find . -maxdepth 1 -name "$pattern" -exec rm -rf {} \; 2>/dev/null || true
        done

        manifest_remove "lst"
        log_success "Little Smalltalk artifacts cleaned"
    else
        log_info "No registered LST installation found in manifest"
        log_info "To clean manually, remove LST files from your installation directory"
    fi
}

smalltalk_lst_version() {
    local lst_path
    lst_path=$(is_lst_installed) || {
        echo "Little Smalltalk v3 is not installed"
        return 1
    }

    if [[ "$lst_path" == "system" ]] || [[ -f "$lst_path/lst3r" ]] || [[ -f "$lst_path" ]]; then
        if [[ "$lst_path" == "system" ]]; then
            lst3r --version 2>/dev/null || echo "LST (version unknown)"
        else
            "$lst_path/lst3r" --version 2>/dev/null || echo "LST (version unknown)"
        fi
    else
        echo "Little Smalltalk v3"
    fi
}
