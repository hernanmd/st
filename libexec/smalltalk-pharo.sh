#!/usr/bin/env bash
#
# smalltalk-pharo.sh - Pharo Smalltalk implementation
#
set -u
set -o pipefail

source "${BASH_SOURCE%/*}/smalltalk-common.sh"

#################################
## Pharo Configuration
#################################

PHARO_VERSION="${PHARO_VERSION:-130}"
PHARO_URL_BASE="https://get.pharo.org"
PHARO_CACHE_DIR="${CACHE_DIR}/pharo"
PHARO_IMAGE_NAME="${PHARO_IMAGE_NAME:-Pharo.image}"

# Installation directory (can be overridden with -d option)
PHARO_INSTALL_DIR="${PHARO_INSTALL_DIR:-.}"

#################################
## Pharo Helper Functions
#################################

# Parse install options
parse_install_options() {
    local install_dir="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                install_dir="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                return 1
                ;;
            *)
                # First non-option argument is the package name
                if [[ -z "$remaining_args" ]]; then
                    remaining_args="$1"
                else
                    remaining_args="$remaining_args $1"
                fi
                shift
                ;;
        esac
    done

    echo "$install_dir"
    echo "$remaining_args"
}

# Set Pharo download URL based on OS and architecture
set_pharo_url() {
    local os_type
    local arch
    local version="${1:-$PHARO_VERSION}"

    os_type=$(get_os)
    arch=$(get_arch)

    # get.pharo.org automatically detects architecture
    # For ARM64 Macs, ensure we get ARM64-compatible binaries
    case "$os_type" in
        macos|linux|windows)
            PHARO_URL="https://get.pharo.org/${version}+vm/"
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac
}

# Check if Pharo is installed
is_pharo_installed() {
    # First check current directory
    if [[ -f "./Pharo.image" ]] && [[ -f "./Pharo.changes" ]]; then
        echo "$(pwd)"
        return 0
    fi
    
    # Check for timestamped directories in current directory (e.g., Pharo-13_20240410_220002)
    for dir in Pharo-*; do
        if [[ -d "$dir" ]] && [[ -f "${dir}/Pharo.image" ]] && [[ -f "${dir}/Pharo.changes" ]]; then
            echo "$(pwd)/$dir"
            return 0
        fi
    done
    
    # Check for Pharo in common locations
    local search_dirs=("$HOME/pharo" "$HOME/.local/share/pharo" "$HOME/Pharo")
    for dir in "${search_dirs[@]}"; do
        if [[ -f "${dir}/Pharo.image" ]] && [[ -f "${dir}/Pharo.changes" ]]; then
            echo "$dir"
            return 0
        fi
        # Also check subdirectories
        for subdir in "$dir"/Pharo-*; do
            if [[ -d "$subdir" ]] && [[ -f "${subdir}/Pharo.image" ]] && [[ -f "${subdir}/Pharo.changes" ]]; then
                echo "$subdir"
                return 0
            fi
        done
    done
    
    return 1
}

# Find Pharo installation relative to current directory
find_pharo_in_current_dir() {
    # Check current directory
    if [[ -f "./Pharo.image" ]] && [[ -f "./Pharo.changes" ]]; then
        echo "$(pwd)"
        return 0
    fi
    
    # Check for timestamped directories (Pharo-13_YYYYMMDD_HHMMSS)
    local latest_dir=""
    local latest_time=0
    
    shopt -s nullglob
    for dir in Pharo-*; do
        if [[ -d "$dir" ]] && [[ -f "${dir}/Pharo.image" ]]; then
            # Get modification time to find most recent
            local mtime
            mtime=$(stat -f %m "$dir" 2>/dev/null || stat -c %Y "$dir" 2>/dev/null || echo 0)
            if [[ "$mtime" -gt "$latest_time" ]]; then
                latest_time="$mtime"
                latest_dir="$dir"
            fi
        fi
    done
    shopt -u nullglob
    
    if [[ -n "$latest_dir" ]]; then
        echo "$(pwd)/$latest_dir"
        return 0
    fi
    
    return 1
}

# Download Pharo image and VM
download_pharo() {
    local version="${1:-$PHARO_VERSION}"
    local install_dir="${2:-.}"
    local os_type
    local arch
    
    os_type=$(get_os)
    arch=$(get_arch)

    log_info "Downloading Pharo ${version} for ${os_type}/${arch} to ${install_dir}..."

    ensure_install_dir "$install_dir"
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    # Clear any existing installation to ensure fresh download
    log_debug "Cleaning existing installation files..."
    rm -rf Pharo*.image Pharo*.changes Pharo*.sources pharo pharo-ui pharo-vm Pharo.app 2>/dev/null || true

    # Determine architecture bits for get.pharo.org URL pattern
    # get.pharo.org/64/ for 64-bit (x86_64, arm64, aarch64)
    # get.pharo.org/32/ for 32-bit (i386, i686)
    local arch_bits=64
    case "$arch" in
        i386|i686|armv7|arm32)
            arch_bits=32
            ;;
        *)
            # Default to 64-bit for x86_64, arm64, aarch64, etc.
            arch_bits=64
            ;;
    esac
    
    # Use get.pharo.org installer with explicit architecture bits
    # Pattern: get.pharo.org/<arch_bits>/<version>+vm
    log_info "Running Pharo installer (${arch_bits}-bit for ${arch} on ${os_type})..."
    
    if cmd_exists curl; then
        curl -fsSL "https://get.pharo.org/${arch_bits}/${version}+vm" 2>/dev/null | bash
    elif cmd_exists wget; then
        wget -qO- "https://get.pharo.org/${arch_bits}/${version}+vm" 2>/dev/null | bash
    else
        die "Neither curl nor wget is installed"
    fi

    # Verify installation and check VM architecture
    if [[ -f "./Pharo.image" ]] && [[ -f "./Pharo.changes" ]]; then
        # Log VM architecture for debugging
        local vm_path
        for vm_path in ./pharo-vm/Pharo.app/Contents/MacOS/Pharo ./pharo ./Pharo.app/Contents/MacOS/Pharo; do
            if [[ -f "$vm_path" ]]; then
                local vm_arch
                vm_arch=$(file "$vm_path" 2>/dev/null | grep -oE 'x86_64|arm64|i386' | head -1)
                log_debug "VM at $vm_path: $vm_arch"
                break
            fi
        done
        
        log_success "Pharo ${version} installed successfully to ${install_dir}"

        # Register installed files
        local pharo_files=()
        for f in Pharo.image Pharo.changes Pharo*.sources pharo pharo-ui pharo-vm Pharo.app; do
            if [[ -e "$f" ]]; then
                pharo_files+=("$(pwd)/$f")
            fi
        done
        register_install "pharo" "$(pwd)" "${pharo_files[@]}"
    else
        log_warn "Standard installation returned no image, trying alternative method..."
        download_pharo_alternative "$version" "$install_dir"
    fi
}

# Alternative download method for Pharo using GitHub releases
# Uses architecture-specific downloads
# Note: GitHub releases may not have ARM64 builds for all versions
# get.pharo.org is preferred as it handles architecture automatically
download_pharo_alternative() {
    local version="${1:-$PHARO_VERSION}"
    local install_dir="${2:-.}"
    
    local os_type
    local arch
    os_type=$(get_os)
    arch=$(get_arch)
    
    local download_url
    local archive_name="pharo.zip"
    local temp_dir
    temp_dir=$(make_temp_dir pharo)
    
    # Construct architecture-specific URL
    # Note: Pharo GitHub releases use different naming conventions
    case "$os_type" in
        macos)
            # macOS 64-bit binary - Pharo supports Apple Silicon natively
            download_url="https://github.com/pharo-project/pharo/releases/download/P${version}/Pharo-${version}-mac64.zip"
            ;;
        linux)
            if [[ "$arch" == "arm64" ]]; then
                download_url="https://github.com/pharo-project/pharo/releases/download/P${version}/Pharo-${version}-linux-arm64.zip"
            else
                download_url="https://github.com/pharo-project/pharo/releases/download/P${version}/Pharo-${version}-linux-x86_64.zip"
            fi
            ;;
        windows)
            download_url="https://github.com/pharo-project/pharo/releases/download/P${version}/Pharo-${version}-windows-x86_64.zip"
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac
    
    log_info "Alternative download from: $download_url"
    
    if download_file "$download_url" "${temp_dir}/${archive_name}"; then
        extract_archive "${temp_dir}/${archive_name}" "$install_dir"
        rm -rf "$temp_dir"
        log_success "Pharo ${version} installed successfully (via alternative method)"
    else
        rm -rf "$temp_dir"
        die "Alternative download failed. Please check your internet connection and try again."
    fi
}

# Run Pharo
run_pharo() {
    local pharo_dir
    local original_dir="$(pwd)"
    
    # First try to find existing Pharo installation
    pharo_dir=$(find_pharo_in_current_dir 2>/dev/null) || pharo_dir=$(is_pharo_installed 2>/dev/null) || true
    
    # If not found, offer to install
    if [[ -z "$pharo_dir" ]]; then
        log_warn "No Pharo installation found in current directory or common locations"
        log_info "Creating a new Pharo installation..."
        
        # Create timestamped directory
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local install_dir="Pharo-${PHARO_VERSION}_${timestamp}"
        
        mkdir -p "$install_dir"
        cd "$install_dir" || die "Cannot change to directory: $install_dir"
        
        download_pharo "$PHARO_VERSION" "."
        
        # Verify installation
        if [[ ! -f "./Pharo.image" ]]; then
            die "Pharo installation failed - no image file found"
        fi
        
        pharo_dir="$(pwd)"
        log_success "Pharo installed to: $pharo_dir"
    else
        cd "$pharo_dir" || die "Cannot change to Pharo directory: $pharo_dir"
    fi
    
    # Determine how to run based on OS and available executables
    local os_type
    os_type=$(get_os)
    
    case "$os_type" in
        macos)
            # Try pharo-ui script first (get.pharo.org provides correct architecture)
            if [[ -f "./pharo-ui" ]]; then
                chmod +x ./pharo-ui 2>/dev/null || true
                log_info "Launching Pharo..."
                ./pharo-ui &
            elif [[ -f "./Pharo.app/Contents/MacOS/Pharo" ]]; then
                open ./Pharo.app
            elif [[ -f "./pharo" ]]; then
                chmod +x ./pharo 2>/dev/null || true
                ./pharo --interactive &
            else
                die "Cannot find Pharo executable in $pharo_dir"
            fi
            ;;
        linux)
            if [[ -f "./pharo-ui" ]]; then
                chmod +x ./pharo-ui 2>/dev/null || true
                ./pharo-ui &
            elif [[ -f "./pharo" ]]; then
                chmod +x ./pharo 2>/dev/null || true
                ./pharo --interactive &
            else
                die "Cannot find Pharo executable in $pharo_dir"
            fi
            ;;
        windows)
            if [[ -f "./Pharo.exe" ]]; then
                ./Pharo.exe &
            elif [[ -f "./pharo-ui" ]]; then
                chmod +x ./pharo-ui 2>/dev/null || true
                ./pharo-ui &
            else
                die "Cannot find Pharo executable in $pharo_dir"
            fi
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac
    
    log_info "Pharo launched from: $pharo_dir"
}

# Search for packages on GitHub
search_pharo_packages() {
    local search_term="$1"
    local per_page=100

    ensure_cache_dir

    log_info "Searching for packages matching '$search_term'..."

    # Search GitHub for Pharo packages
    local api_url="https://api.github.com/search/repositories?q=topic:pharo+${search_term}&per_page=${per_page}"

    ensure_cache_dir
    local cache_file="${PHARO_CACHE_DIR}/search_${search_term// /_}.json"

    if download_file "$api_url" "$cache_file"; then
        if cmd_exists jq; then
            jq -r '.items[] | "\(.full_name) - \(.description // "No description")"' "$cache_file" 2>/dev/null || {
                log_error "Failed to parse search results"
                return 1
            }
        else
            cat "$cache_file"
        fi
    else
        log_error "Search failed"
        return 1
    fi
}

# Install a package
install_pharo_package() {
    local package_name="$1"
    local pharo_dir

    pharo_dir=$(is_pharo_installed) || {
        log_info "Pharo not found, installing..."
        download_pharo
        pharo_dir="."
    }

    cd "$pharo_dir" || die "Cannot change to Pharo directory"

    # Search for the package
    log_info "Searching for package '$package_name'..."

    local search_url="https://api.github.com/search/repositories?q=topic:pharo+${package_name}"
    ensure_cache_dir
    mkdir -p "${PHARO_CACHE_DIR}"
    local search_results="${PHARO_CACHE_DIR}/pkg_search.json"

    download_file "$search_url" "$search_results"

    if ! cmd_exists jq; then
        die "jq is required for package installation. Please install jq."
    fi

    local match_count
    match_count=$(jq '.total_count' "$search_results")

    if [[ "$match_count" -eq 0 ]]; then
        die "No packages found matching '$package_name'"
    fi

    if [[ "$match_count" -gt 1 ]]; then
        log_info "Found $match_count packages. Showing first 10:"
        jq -r '.items[0:10] | .[] | "\(.full_name)\n  \(.description // "No description")\n"' "$search_results"
        log_info "Please use the full package name: st pharo install <owner>/<repo>"
        return 1
    fi

    local repo full_name clone_url install_expr
    full_name=$(jq -r '.items[0].full_name' "$search_results")
    clone_url=$(jq -r '.items[0].clone_url' "$search_results")
    repo=$(jq -r '.items[0].name' "$search_results")

    log_info "Found package: $full_name"

    # Clone the repository
    local temp_dir
    temp_dir=$(mktemp -d)
    git clone "$clone_url" "$temp_dir/$repo"

    # Try to find install expression in README
    local readme_file="$temp_dir/$repo/README.md"
    if [[ -f "$readme_file" ]]; then
        # Look for Smalltalk code blocks
        install_expr=$(grep -A 20 '^```smalltalk' "$readme_file" 2>/dev/null | grep -v '^```' | head -1 || true)
        if [[ -z "$install_expr" ]]; then
            install_expr=$(grep -A 20 '^```st' "$readme_file" 2>/dev/null | grep -v '^```' | head -1 || true)
        fi
    fi

    if [[ -n "$install_expr" ]]; then
        log_info "Installing package with: $install_expr"
        ./pharo-ui --headless "$PHARO_IMAGE_NAME" eval --save "$install_expr" 2>/dev/null || {
            log_error "Failed to install package"
            rm -rf "$temp_dir"
            return 1
        }
    else
        log_error "Could not find installation instructions in README.md"
        log_info "Repository cloned to: $temp_dir/$repo"
        log_info "Please install manually or add install instructions to your README.md"
        return 1
    fi

    rm -rf "$temp_dir"
    log_success "Package '$package_name' installed successfully"
}

#################################
## Command Handlers
#################################

smalltalk_pharo_help() {
    load_help_from_doc "pharo"
}


smalltalk_pharo_install() {
    local install_dir="."
    local packages=()

    # Parse options - -d flag for directory, everything else is packages
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                if [[ -n "${2:-}" ]]; then
                    install_dir="$2"
                    shift 2
                else
                    log_error "Option -d requires a directory argument"
                    echo "Usage: st pharo install [-d <dir>] [package1 package2 ...]"
                    return 1
                fi
                ;;
            -h|--help)
                smalltalk_pharo_help
                return 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Usage: st pharo install [-d <dir>] [package1 package2 ...]"
                return 1
                ;;
            *)
                # All positional arguments are package names
                # Validate package name for security
                if ! validate_package_name "$1"; then
                    log_error "Invalid package name: $1"
                    return 1
                fi
                packages+=("$1")
                shift
                ;;
        esac
    done

    # Validate install directory path
    if [[ "$install_dir" != "." ]] && ! validate_path "$install_dir"; then
        log_error "Invalid installation directory: $install_dir"
        return 1
    fi

    # Installing Pharo itself
    if [[ -d "$install_dir" ]]; then
        local existing
        existing=$(detect_existing_smalltalk "$install_dir")
        if [[ -n "$existing" && "$existing" != "pharo" ]]; then
            log_error "Directory $install_dir already contains a $existing installation"
            log_error "Use a different directory or remove the existing installation first"
            return 1
        fi
    fi

    # If no destination directory specified, create timestamped subdirectory FIRST
    if [[ "$install_dir" == "." ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="Pharo-${PHARO_VERSION}_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
        mkdir -p "$install_dir"
    fi

    download_pharo "$PHARO_VERSION" "$install_dir"
    
    # After installing Pharo, install any packages specified
    if [[ ${#packages[@]} -gt 0 ]]; then
        for pkg in "${packages[@]}"; do
            install_pharo_package "$pkg"
        done
    fi
}

smalltalk_pharo_run() {
    local cmd="${1:-}"
    local pharo_dir
    local original_dir="$(pwd)"
    
    # First try current directory, then search common locations
    pharo_dir=$(find_pharo_in_current_dir 2>/dev/null) || pharo_dir=$(is_pharo_installed 2>/dev/null) || true
    
    # If not found, create installation and try again
    if [[ -z "$pharo_dir" ]]; then
        log_info "No Pharo installation found. Creating new installation..."
        
        # Create timestamped directory
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local install_dir="Pharo-${PHARO_VERSION}_${timestamp}"
        
        mkdir -p "$install_dir"
        cd "$install_dir" || die "Cannot create directory: $install_dir"
        
        download_pharo "$PHARO_VERSION" "."
        
        if [[ ! -f "./Pharo.image" ]]; then
            die "Pharo installation failed - no image file found"
        fi
        
        pharo_dir="$(pwd)"
        log_success "Pharo installed to: $pharo_dir"
    else
        cd "$pharo_dir" || die "Cannot change to Pharo directory: $pharo_dir"
    fi

    # If no command, just run the UI
    if [[ -z "$cmd" ]]; then
        if [[ -f "./pharo-ui" ]]; then
            chmod +x ./pharo-ui 2>/dev/null || true
            log_info "Launching Pharo from: $pharo_dir"
            ./pharo-ui &
        elif [[ -f "./Pharo.app/Contents/MacOS/Pharo" ]]; then
            open ./Pharo.app
        elif [[ -f "./pharo" ]]; then
            chmod +x ./pharo 2>/dev/null || true
            ./pharo --interactive &
        else
            die "Cannot find Pharo executable"
        fi
        return
    fi

    # Handle Clap commands
    case "$cmd" in
        metacello)
            shift
            local spec="$*"
            if [[ -z "$spec" ]]; then
                log_error "Usage: st pharo run metacello <baseline-spec>"
                return 1
            fi
            ./pharo --headless Pharo.image metacello install "$spec" --save
            ;;
        st)
            local st_file="${1:-}"
            if [[ -z "$st_file" ]]; then
                log_error "Usage: st pharo run st <file.st>"
                return 1
            fi
            ./pharo --headless Pharo.image load "$st_file"
            ;;
        save)
            local save_name="${1:-}"
            if [[ -z "$save_name" ]]; then
                ./pharo --headless Pharo.image save
            else
                ./pharo --headless Pharo.image save "$save_name"
            fi
            ;;
        printVersion)
            ./pharo --headless Pharo.image printVersion
            ;;
        eval)
            shift
            local code="$*"
            if [[ -z "$code" ]]; then
                log_error "Usage: st pharo run eval <code>"
                return 1
            fi
            ./pharo --headless Pharo.image eval "$code"
            ;;
        fuel)
            local fuel_file="${1:-}"
            if [[ -z "$fuel_file" ]]; then
                log_error "Usage: st pharo run fuel <file.fuel>"
                return 1
            fi
            ./pharo --headless Pharo.image fuel load "$fuel_file"
            ;;
        help|--help|-h)
            smalltalk_pharo_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            echo "Run 'st pharo help' for available commands"
            return 1
            ;;
    esac
}

smalltalk_pharo_search() {
    local search_term="${1:-}"

    if [[ -z "$search_term" ]]; then
        log_error "Please provide a search term"
        echo "Usage: st pharo search <term>"
        exit 1
    fi

    search_pharo_packages "$search_term"
}

smalltalk_pharo_list() {
    list_monticello_packages "pharo" "pharo"
}

smalltalk_pharo_update() {
    update_monticello_packages "pharo" "pharo"
}

smalltalk_pharo_clean() {
    clean_impl_cache "pharo"
}

smalltalk_pharo_clean_artifacts() {
    log_info "Cleaning Pharo artifacts..."

    # Get install directory from manifest
    local impl_dir
    impl_dir=$(manifest_get_dir "pharo")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        # Remove Pharo artifacts
        local patterns=(
            "Pharo*.image"
            "Pharo*.changes"
            "Pharo*.sources"
            "pharo"
            "pharo-ui"
            "pharo-vm"
            "Pharo.app"
        )

        for pattern in "${patterns[@]}"; do
            find . -maxdepth 1 -name "$pattern" -exec rm -rf {} \; 2>/dev/null || true
        done

        manifest_remove "pharo"
        log_success "Pharo artifacts cleaned"
    else
        log_info "No registered Pharo installation found in manifest"
        log_info "To clean manually, remove Pharo files from your installation directory"
    fi
}

smalltalk_pharo_version() {
    local pharo_dir
    pharo_dir=$(is_pharo_installed) || {
        echo "Pharo is not installed"
        return 1
    }

    cd "$pharo_dir" || return 1
    if [[ -f "./pharo" ]]; then
        ./pharo --version 2>/dev/null || echo "Pharo ${PHARO_VERSION}"
    else
        echo "Pharo ${PHARO_VERSION}"
    fi
}
