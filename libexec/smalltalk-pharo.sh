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

PHARO_VERSION="${PHARO_VERSION:-13}"
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

    case "$os_type" in
        macos)
            if [[ "$arch" == "arm64" ]]; then
                PHARO_URL="https://get.pharo.org/${version}+vm/"
            else
                PHARO_URL="https://get.pharo.org/${version}+vm/"
            fi
            ;;
        linux)
            if [[ "$arch" == "arm64" ]]; then
                PHARO_URL="https://get.pharo.org/${version}+vm/"
            else
                PHARO_URL="https://get.pharo.org/${version}+vm/"
            fi
            ;;
        windows)
            PHARO_URL="https://get.pharo.org/${version}+vm/"
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac
}

# Check if Pharo is installed
is_pharo_installed() {
    local search_dirs=("." "$HOME/pharo" "$HOME/.local/share/pharo")

    for dir in "${search_dirs[@]}"; do
        if [[ -f "${dir}/Pharo.image" ]] && [[ -f "${dir}/Pharo.changes" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Download Pharo image and VM
download_pharo() {
    local version="${1:-$PHARO_VERSION}"
    local install_dir="${2:-.}"

    log_info "Downloading Pharo ${version} to ${install_dir}..."

    set_pharo_url "$version"

    local download_url="${PHARO_URL}"

    log_debug "Download URL: $download_url"

    ensure_install_dir "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    if cmd_exists curl; then
        # Use get.pharo.org installer which handles all platform-specific downloads
        curl -fsSL "https://get.pharo.org/${version}+vm" | bash
    elif cmd_exists wget; then
        wget -qO- "https://get.pharo.org/${version}+vm" | bash
    else
        die "Neither curl nor wget is installed"
    fi

    if is_pharo_installed >/dev/null; then
        log_success "Pharo ${version} installed successfully to ${install_dir}"

        # Register installed files
        local pharo_files=()
        for f in Pharo.image Pharo.changes Pharo*.sources pharo pharo-ui pharo-vm Pharo.app; do
            if [[ -e "$f" ]]; then
                pharo_files+=("$install_dir/$f")
            fi
        done
        register_install "pharo" "$(pwd)" "${pharo_files[@]}"
    else
        # If standard installation failed, try alternative approach
        log_info "Trying alternative download method..."
        download_pharo_alternative "$version" "$install_dir"
    fi
}

# Alternative download method for Pharo
download_pharo_alternative() {
    local version="${1:-$PHARO_VERSION}"
    local install_dir="${2:-.}"
    
    local os_type=$(get_os)
    local arch=$(get_arch)
    
    local download_url
    local archive_name="pharo.zip"
    local temp_dir=$(mktemp -d)
    
    # Try to get Pharo from GitHub releases as fallback
    case "$os_type" in
        macos)
            download_url="https://github.com/pharo-project/pharo/releases/download/P${version}/Pharo-${version}-mac.zip"
            ;;
        linux)
            download_url="https://github.com/pharo-project/pharo/releases/download/P${version}/Pharo-${version}-linux.zip"
            ;;
        windows)
            download_url="https://github.com/pharo-project/pharo/releases/download/P${version}/Pharo-${version}-windows.zip"
            ;;
    esac
    
    log_info "Attempting download from: $download_url"
    
    if download_file "$download_url" "${temp_dir}/${archive_name}"; then
        extract_archive "${temp_dir}/${archive_name}" "$install_dir"
    else
        log_error "Alternative download also failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    rm -rf "$temp_dir"
    
    if is_pharo_installed >/dev/null; then
        log_success "Pharo ${version} installed successfully (via alternative method)"
    else
        die "Pharo installation failed"
    fi
}

# Run Pharo
run_pharo() {
    local pharo_dir
    pharo_dir=$(is_pharo_installed) || die "Pharo is not installed. Run 'st pharo install' first."

    cd "$pharo_dir" || die "Cannot change to Pharo directory"

    if [[ -f "./pharo-ui" ]]; then
        chmod +x ./pharo-ui
        ./pharo-ui &
    elif [[ -f "./Pharo.app/Contents/MacOS/Pharo" ]]; then
        open ./Pharo.app
    else
        die "Cannot find Pharo executable"
    fi
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
    cat << 'EOF'
Pharo Smalltalk Commands
=======================

Usage: st [-x] pharo <command> [options]

Commands:
  install [-d dir] [packages...]  Install Pharo with optional packages
  run [cmd]                       Run Pharo (with optional Clap commands)
  search <term>                    Search for packages
  list                            List available packages (cached)
  update                          Update package cache
  clean                           Clean cache directory
  clean-artifacts                 Clean installed artifacts
  version                         Show Pharo version
  help                            Show this help message

Options:
  -d, --dir <path>        Installation directory (default: current directory)

Debug Mode:
  -x, --debug             Enable debug mode (set -x tracing)
                          Must be specified before implementation name
                          Example: st -x pharo install

Package Installation:
  Multiple packages can be specified after the install command:
  st pharo install Seaside NeoCSV

Clap Commands (run as: st pharo run <cmd>):
  metacello <spec>         Install Metacello baseline/configuration
  st <file.st>           Load and execute .st source file
  save [name]            Save the image
  printVersion            Print image version
  eval <code>             Evaluate Smalltalk code
  fuel <file.fuel>       Load fuel file

Examples:
  st pharo install                  # Install Pharo
  st pharo install -d ~/my-pharo    # Install to specific directory
  st pharo install Seaside          # Install Pharo with Seaside package
  st pharo install Seaside NeoCSV   # Install with multiple packages
  st pharo install -d ~/p Seaside   # Install to directory with package
  st -x pharo install               # Install with debug output
  st pharo run                      # Run Pharo
  st pharo search polyglot          # Search for packages
  st pharo clean-artifacts          # Clean installed files

EOF
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
    pharo_dir=$(is_pharo_installed) || {
        log_info "Pharo not found, installing..."
        download_pharo
        pharo_dir="."
    }

    cd "$pharo_dir" || die "Cannot change to Pharo directory"

    # If no command, just run the UI
    if [[ -z "$cmd" ]]; then
        if [[ -f "./pharo-ui" ]]; then
            chmod +x ./pharo-ui
            ./pharo-ui &
        elif [[ -f "./Pharo.app/Contents/MacOS/Pharo" ]]; then
            open ./Pharo.app
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
