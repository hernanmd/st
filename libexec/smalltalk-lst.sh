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

LST_VERSION="${LST_VERSION:-main}"
LST_URL="https://codeberg.org/suetanvil/lst3r/archive/main.zip"

#################################
## Little Smalltalk Helper Functions
#################################

# Check if LST is installed and working
is_lst_installed() {
    local search_paths=(".")

    for path in "${search_paths[@]}"; do
        if [[ -f "${path}/lst3" ]] && [[ -x "${path}/lst3" ]]; then
            echo "$(pwd)"
            return 0
        fi
    done

    # Check PATH
    if command -v lst3 &>/dev/null; then
        echo "system"
        return 0
    fi

    return 1
}

# Download and build LST from source archive
download_lst() {
    local install_dir="${1:-.}"

    log_info "Downloading Little Smalltalk v3 to ${install_dir}..."

    # Ensure the directory exists
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    install_dir="$(pwd)"

    # Download the archive
    local archive_name="main.zip"
    download_file "$LST_URL" "$archive_name"

    if [[ ! -f "$archive_name" ]]; then
        die "Failed to download Little Smalltalk v3"
    fi

    # Extract the archive
    log_info "Extracting archive..."
    extract_archive "$archive_name" "$install_dir"
    rm -f "$archive_name"

    # The archive extracts to a directory like "lst3r-main"
    # Find the extracted directory
    local extracted_dir=""
    for dir in lst3r-* lst3r; do
        if [[ -d "$dir" ]]; then
            extracted_dir="$dir"
            break
        fi
    done

    if [[ -z "$extracted_dir" ]]; then
        die "Failed to find extracted LST directory"
    fi

    # Move contents of extracted directory to install_dir
    log_info "Moving files to installation directory..."
    mv "$extracted_dir"/* . 2>/dev/null || true
    mv "$extracted_dir"/.* . 2>/dev/null || true
    rmdir "$extracted_dir" 2>/dev/null || true

    # Build the  binary
    log_info "Building Little Smalltalk v3..."
    if [[ -f "Makefile" ]]; then
        make -j"$(nproc 2>/dev/null || echo 4)" || die "Build failed"
    elif [[ -f "CMakeLists.txt" ]]; then
        mkdir -p build
        cd build
        cmake .. || die "CMake configuration failed"
        make -j"$(nproc 2>/dev/null || echo 4)" || die "Build failed"
        cd ..
    else
        die "No build system found. Expected Makefile or CMakeLists.txt"
    fi

    # Ensure lst3 is executable
    if [[ -f "./${install_dir}/lst3" ]]; then
        chmod +x ./"${install_dir}"/lst3
        log_success "Little Smalltalk v3 installed successfully to ${install_dir}"
    else
        die "Build failed: lst3 binary not found"
    fi
}

# Run LST
run_lst() {
    local lst_path
    lst_path=$(is_lst_installed) || die "LST is not installed. Run 'st lst install' first."

    if [[ "$lst_path" == "system" ]]; then
        lst3 "$@"
    elif [[ -f "${lst_path}/lst3" ]]; then
        "${lst_path}/lst3" "$@"
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
    load_help_from_doc "lst"
}

smalltalk_lst_install() {
    local install_dir="."
    local remaining=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                install_dir="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Usage: st lst install [-d <dir>]"
                return 1
                ;;
            *)
                remaining="$remaining $1"
                shift
                ;;
        esac
    done

    # Check for existing Smalltalk installation
    if [[ -d "$install_dir" ]]; then
        local existing
        existing=$(detect_existing_smalltalk "$install_dir")
        if [[ -n "$existing" && "$existing" != "lst" ]]; then
            log_error "Directory $install_dir already contains a $existing installation"
            log_error "Use a different directory or remove the existing installation first"
            return 1
        fi
    fi

    # If no destination specified, create timestamped subdirectory
    if [[ "$install_dir" == "." ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="lst3r_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
        mkdir -p "$install_dir"
    fi

    download_lst "$install_dir"
}

smalltalk_lst_run() {
    local target_dir=""
    local extra_args=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                target_dir="$2"
                shift 2
                ;;
            *)
                extra_args="$extra_args $1"
                shift
                ;;
        esac
    done

    local lst_dir

    # If target directory specified, use it; otherwise search for existing LST
    if [[ -n "$target_dir" ]]; then
        lst_dir="$target_dir"
    else
        lst_dir=$(is_lst_installed) || {
            log_info "LST not found, installing..."
            # Create timestamped directory if no -d specified
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            lst_dir="lst3r_${timestamp}"
            log_info "Creating directory: $lst_dir"
            download_lst "$lst_dir"
            lst_dir="$(pwd)/lst3r_${timestamp}"
        }
    fi

    cd "$lst_dir" || die "Cannot change to LST directory: $lst_dir"

    run_lst $extra_args
}

smalltalk_lst_search() {
    log_info "Little Smalltalk v3 does not support package searching"
    log_info "Visit https://codeberg.org/suetanvil/lst3r to learn more"
}

smalltalk_lst_list() {
    log_info "Little Smalltalk v3 does not support package listing"
    log_info "Visit https://codeberg.org/suetanvil/lst3r to learn more"
}

smalltalk_lst_update() {
    log_info "Little Smalltalk v3 does not require package updates"
}

smalltalk_lst_clean() {
    log_info "Little Smalltalk v3 does not maintain a cache"
}

smalltalk_lst_clean_artifacts() {
    log_info "Cleaning Little Smalltalk artifacts..."

    local impl_dir
    impl_dir=$(manifest_get_dir "lst")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        # Clean build artifacts but keep source
        rm -f lst3r 2>/dev/null || true
        rm -rf build 2>/dev/null || true
        rm -f *.o *.a 2>/dev/null || true

        manifest_remove "lst"
        log_success "Little Smalltalk build artifacts cleaned"
    else
        log_info "No registered LST installation found in manifest"
    fi
}

smalltalk_lst_version() {
    local lst_path
    lst_path=$(is_lst_installed) || {
        echo "Little Smalltalk v3 is not installed"
        return 1
    }

    if [[ "$lst_path" == "system" ]]; then
        lst3 --version 2>/dev/null || echo "LST (version unknown)"
    elif [[ -f "${lst_path}/lst3" ]]; then
        "${lst_path}/lst3" --version 2>/dev/null || echo "LST (version unknown)"
    else
        echo "Little Smalltalk v3"
    fi
}
# LST does not support command-line code evaluation
smalltalk_lst_eval() {
    log_error "LST does not support command-line code evaluation"
    log_info "Use 'st lst run' to start the LST REPL"
    return 1
}
