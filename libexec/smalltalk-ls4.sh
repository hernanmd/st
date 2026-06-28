#!/usr/bin/env bash
#
# smalltalk-ls4.sh - Little Smalltalk v4 implementation (kyle-github/littlesmalltalk)
#
set -Euo pipefail
IFS=$'\n\t'

# shellcheck source=libexec/smalltalk-common.sh
source "${BASH_SOURCE%/*}/smalltalk-common.sh"

#################################
## Little Smalltalk v4 Configuration
#################################

LS4_REPO="kyle-github/littlesmalltalk"
LS4_API_URL="https://api.github.com/repos/${LS4_REPO}/releases"
LS4_URL_BASE="https://github.com/${LS4_REPO}/archive/refs/tags"

#################################
## Little Smalltalk v4 Helper Functions
#################################

# Get the latest version tag from GitHub releases
get_ls4_latest_version() {
    local latest_version
    latest_version=$(curl -s "$LS4_API_URL/latest" 2> /dev/null | jq -r '.tag_name // empty' 2> /dev/null)

    if [[ -z "$latest_version" ]]; then
        # Fallback: try to get the most recent release tag
        latest_version=$(curl -s "$LS4_API_URL" 2> /dev/null | jq -r '.[0].tag_name // empty' 2> /dev/null)
    fi

    if [[ -z "$latest_version" ]]; then
        die "Failed to fetch latest version from GitHub releases"
    fi

    echo "$latest_version"
}

# List available versions (tags) from GitHub
list_ls4_versions() {
    log_info "Fetching available versions from GitHub..."

    local versions
    versions=$(curl -s "$LS4_API_URL" 2> /dev/null | jq -r '.[].tag_name // empty' 2> /dev/null)

    if [[ -z "$versions" ]]; then
        die "Failed to fetch versions from GitHub"
    fi

    echo "Available versions:"
    echo "$versions" | while IFS= read -r version; do
        echo "  $version"
    done
}

# Check if LS4 is installed and working
is_ls4_installed() {
    # First check current directory
    if [[ -f "./build/lst" ]] && [[ -x "./build/lst" ]]; then
        echo "$(pwd)"
        return 0
    fi

    # Search current directory for timestamped installations (littlesmalltalk_*)
    local dir
    for dir in littlesmalltalk_*; do
        if [[ -d "$dir" ]] && [[ -f "${dir}/build/lst" ]] && [[ -x "${dir}/build/lst" ]]; then
            echo "$(pwd)/$dir"
            return 0
        fi
    done

    # Also search parent directory for timestamped installations
    local parent_dir
    parent_dir="$(cd .. && pwd)"
    if [[ "$(pwd)" != "$parent_dir" ]]; then
        for dir in "$parent_dir"/littlesmalltalk-*; do
            if [[ -d "$dir" ]] && [[ -f "${dir}/build/lst" ]] && [[ -x "${dir}/build/lst" ]]; then
                echo "$dir"
                return 0
            fi
        done
    fi

    # Check PATH
    if command -v lst &> /dev/null; then
        echo "system"
        return 0
    fi

    return 1
}

# Download and build LS4 from source archive
download_ls4() {
    local install_dir="${1:-.}"
    local original_dir
    original_dir="$(pwd)"

    # Get latest version dynamically
    local version
    version=$(get_ls4_latest_version)
    log_info "Latest version: $version"

    log_info "Downloading Little Smalltalk v4 ($version) to ${install_dir}..."

    # Ensure the directory exists
    mkdir -p "$install_dir"
    cd "$install_dir" || {
                           cd "$original_dir"
                                               die "Cannot change to directory: $install_dir"
    }

    install_dir="$(pwd)"

    # Construct download URL (version includes 'v' prefix from GitHub tags)
    local archive_name="littlesmalltalk-${version}.zip"
    local download_url="${LS4_URL_BASE}/${version}.zip"

    # Download the archive
    download_file "$download_url" "$archive_name"

    if [[ ! -f "$archive_name" ]]; then
        cd "$original_dir"
        die "Failed to download Little Smalltalk v4"
    fi

    # Extract the archive
    log_info "Extracting archive..."
    extract_archive "$archive_name" "$install_dir"
    rm -f -- "$archive_name"

    # The archive extracts to a directory like "littlesmalltalk-v4.7.2"
    # Find the extracted directory
    local extracted_dir=""
    for dir in littlesmalltalk-*; do
        if [[ -d "$dir" ]]; then
            extracted_dir="$dir"
            break
        fi
    done

    if [[ -z "$extracted_dir" ]]; then
        cd "$original_dir"
        die "Failed to find extracted LS4 directory"
    fi

    # Move contents of extracted directory to install_dir
    log_info "Moving files to installation directory..."
    mv "$extracted_dir"/* . 2> /dev/null || true
    mv "$extracted_dir"/.* . 2> /dev/null || true
    rmdir "$extracted_dir" 2> /dev/null || true

    # Build the binary using CMake
    log_info "Building Little Smalltalk v4..."
    if [[ -f "CMakeLists.txt" ]]; then
        mkdir -p build
        cd build || {
                      cd "$original_dir"
                                          die "Cannot create build directory"
        }
        cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .. || {
                                                         cd "$original_dir"
                                                                             die "CMake configuration failed"
        }
        make -j"$(nproc 2> /dev/null || echo 4)" || {
                                                     cd "$original_dir"
                                                                         die "Build failed"
        }
        cd ..
    else
        cd "$original_dir"
        die "No CMakeLists.txt found. Expected build system not found."
    fi

    # Ensure lst is executable
    if [[ -f "./build/lst" ]]; then
        chmod +x ./build/lst
        cd "$original_dir"
        log_success "Little Smalltalk v4 installed successfully to ${install_dir}"
    else
        cd "$original_dir"
        die "Build failed: lst binary not found in build directory"
    fi
}

# Run LS4
run_ls4() {
    local ls4_path
    local extra_args="$*"

    ls4_path=$(is_ls4_installed) || die "LS4 is not installed. Run 'st ls4 install' first."

    if [[ "$ls4_path" == "system" ]]; then
        lst $extra_args
    elif [[ -f "${ls4_path}/build/lst" ]]; then
        "${ls4_path}/build/lst" $extra_args
    else
        die "LS4 executable not found"
    fi
}

#################################
## Command Handlers
#################################

smalltalk_ls4_help() {
    load_help_from_doc "ls4"
}

smalltalk_ls4_install() {
    local install_dir="."
    local remaining=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d | --dir)
                install_dir="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Usage: st ls4 install [-d <dir>]"
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
        if [[ -n "$existing" && "$existing" != "ls4" ]]; then
            log_error "Directory $install_dir already contains a $existing installation"
            log_error "Use a different directory or remove the existing installation first"
            return 1
        fi
    fi

    # If no destination specified, create timestamped subdirectory
    if [[ "$install_dir" == "." ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="littlesmalltalk_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
        mkdir -p "$install_dir"
    fi

    download_ls4 "$install_dir"
}

# Run LS4 Web IDE
smalltalk_ls4_run() {
    local target_dir=""
    local extra_args=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d | --dir)
                target_dir="$2"
                shift 2
                ;;
            *)
                extra_args="$extra_args $1"
                shift
                ;;
        esac
    done

    local ls4_dir

    # If target directory specified, use it; otherwise search for existing LS4
    if [[ -n "$target_dir" ]]; then
        ls4_dir="$target_dir"
        cd "$ls4_dir" || die "Cannot change to LS4 directory: $ls4_dir"
    else
        ls4_dir=$(is_ls4_installed) || {
            log_info "LS4 not found, installing..."
            # Create timestamped directory if no -d specified
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            ls4_dir="littlesmalltalk_${timestamp}"
            log_info "Creating directory: $ls4_dir"
            mkdir -p "$ls4_dir"
            cd "$ls4_dir" || die "Cannot create directory: $ls4_dir"
            download_ls4 "."
            ls4_dir="$(pwd)"
            log_success "LS4 installed to: $ls4_dir"
        }
    fi

    # Ensure we are in the LS4 directory
    if [[ "$ls4_dir" != "$(pwd)" ]]; then
        cd "$ls4_dir" || die "Cannot change to LS4 directory: $ls4_dir"
    fi

    # Check if we have a display available
    if [[ -z "${DISPLAY:-}" ]] && [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "The LS4 Web IDE requires a graphical display"
        log_info "Use 'st ls4 eval' for headless REPL evaluation instead"
        return 1
    fi

    # Run the Web IDE
    if [[ -f "./build/lst" && -f "./bin/lst_webide.img" ]]; then
        "./build/lst" "./bin/lst_webide.img" $extra_args
    else
        die "LS4 Web IDE not found. Expected ./build/lst and ./bin/lst_webide.img"
    fi
}

# Run LS4 REPL evaluator
smalltalk_ls4_eval() {
    local target_dir=""
    local extra_args=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d | --dir)
                target_dir="$2"
                shift 2
                ;;
            *)
                extra_args="$extra_args $1"
                shift
                ;;
        esac
    done

    local ls4_dir

    # If target directory specified, use it; otherwise search for existing LS4
    if [[ -n "$target_dir" ]]; then
        ls4_dir="$target_dir"
        cd "$ls4_dir" || die "Cannot change to LS4 directory: $ls4_dir"
    else
        ls4_dir=$(is_ls4_installed) || {
            log_info "LS4 not found, installing..."
            # Create timestamped directory if no -d specified
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            ls4_dir="littlesmalltalk_${timestamp}"
            log_info "Creating directory: $ls4_dir"
            mkdir -p "$ls4_dir"
            cd "$ls4_dir" || die "Cannot create directory: $ls4_dir"
            download_ls4 "."
            ls4_dir="$(pwd)"
            log_success "LS4 installed to: $ls4_dir"
        }
    fi

    # Ensure we are in the LS4 directory
    if [[ "$ls4_dir" != "$(pwd)" ]]; then
        cd "$ls4_dir" || die "Cannot change to LS4 directory: $ls4_dir"
    fi

    # Run the REPL evaluator
    if [[ -f "./build/lst" && -f "./bin/lst_repl.img" ]]; then
        "./build/lst" "./bin/lst_repl.img" $extra_args
    else
        die "LS4 REPL not found. Expected ./build/lst and ./bin/lst_repl.img"
    fi
}

smalltalk_ls4_search() {
    log_error "Little Smalltalk v4 does not support package searching"
    log_info "Little Smalltalk v4 has no package manager"
    log_info "Visit https://github.com/kyle-github/littlesmalltalk to learn more"
    return 1
}

smalltalk_ls4_list() {
    log_error "Little Smalltalk v4 does not support package listing"
    log_info "Little Smalltalk v4 has no package manager"
    log_info "Visit https://github.com/kyle-github/littlesmalltalk to learn more"
    return 1
}

smalltalk_ls4_update() {
    log_error "Little Smalltalk v4 does not require package updates"
    log_info "Little Smalltalk v4 has no package manager"
    return 1
}

smalltalk_ls4_clean() {
    log_info "Little Smalltalk v4 does not maintain a cache"
}

smalltalk_ls4_clean_artifacts() {
    log_info "Cleaning Little Smalltalk v4 artifacts..."

    local impl_dir
    impl_dir=$(manifest_get_dir "ls4")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        # Clean build artifacts but keep source
        rm -rf -- build 2> /dev/null || true
        rm -f -- *.o *.a 2> /dev/null || true

        manifest_remove "ls4"
        log_success "Little Smalltalk v4 build artifacts cleaned"
    else
        log_info "No registered LS4 installation found in manifest"
    fi
}

smalltalk_ls4_version() {
    local target_dir=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d | --dir)
                target_dir="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local ls4_dir

    if [[ -n "$target_dir" ]]; then
        ls4_dir="$target_dir"
    else
        ls4_dir=$(is_ls4_installed) || {
            echo "Little Smalltalk v4 is not installed"
            return 1
        }
    fi

    cd "$ls4_dir" || {
        echo "Cannot change to LS4 directory: $ls4_dir"
        return 1
    }

    # Get the version from git tags if available
    if [[ -d ".git" ]]; then
        local version
        version=$(git describe --tags 2> /dev/null || echo "unknown")
        echo "Little Smalltalk v4 $version"
    else
        echo "Little Smalltalk v4"
    fi
}

smalltalk_ls4_versions() {
    list_ls4_versions
}
