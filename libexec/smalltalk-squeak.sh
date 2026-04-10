#!/usr/bin/env bash
#
# smalltalk-squeak.sh - Squeak Smalltalk implementation
#
set -u
set -o pipefail

source "${BASH_SOURCE%/*}/smalltalk-common.sh"

#################################
## Squeak Configuration
#################################

SQUEAK_VERSION="${SQUEAK_VERSION:-stable}"
SQUEAK_URL_BASE="https://files.squeak.org"
SQUEAK_CACHE_DIR="${CACHE_DIR}/squeak"

# Known Squeak versions and their download URLs (using files.squeak.org)
# URL pattern: files.squeak.org/<version>/Squeak<version>-<build>-64bit/Squeak<version>-<build>-64bit-<platform>.<ext>
declare -A SQUEAK_DOWNLOAD_URLS=(
    # Squeak 6.0 (stable)
    ["6.0-macos-x64"]="https://files.squeak.org/6.0/Squeak6.0-22148-64bit/Squeak6.0-22148-64bit-202312181441-macOS-x64.dmg"
    ["6.0-macos-arm64"]="https://files.squeak.org/6.0/Squeak6.0-22148-64bit/Squeak6.0-22148-64bit-202312181441-macOS-ARMv8.dmg"
    ["6.0-linux-x64"]="https://files.squeak.org/6.0/Squeak6.0-22148-64bit/Squeak6.0-22148-64bit-202312181441-Linux-x64.tar.gz"
    ["6.0-linux-arm64"]="https://files.squeak.org/6.0/Squeak6.0-22148-64bit/Squeak6.0-22148-64bit-202312181441-Linux-ARMv8.tar.gz"
    ["6.0-windows"]="https://files.squeak.org/6.0/Squeak6.0-22148-64bit/Squeak6.0-22148-64bit-202312181441-Windows-x64.zip"
    # Squeak 6.0 All-in-One (cross-platform zip with VM included)
    ["6.0-allinone"]="https://files.squeak.org/6.0/Squeak6.0-22148-64bit/Squeak6.0-22148-64bit-All-in-One.zip"
    # Squeak 5.4 (older)
    ["5.4"]="https://files.squeak.org/5.4/Squeak5.4-23647-64bit/Squeak5.4-23647-64bit.zip"
    # Squeak 5.3 (current_stable)
    ["5.3"]="https://files.squeak.org/5.3/Squeak5.3-19486-64bit/Squeak5.3-19486-64bit.zip"
)

#################################
## Squeak Helper Functions
#################################

# Get available Squeak versions by scraping the website
get_squeak_versions() {
    local cache_file="${SQUEAK_CACHE_DIR}/squeak-versions.json"

    ensure_cache_dir
    mkdir -p "${SQUEAK_CACHE_DIR}"

    # Try to fetch from cache first if recent
    if [[ -f "$cache_file" ]] && [[ $(find "$cache_file" -mtime -1 2>/dev/null) ]]; then
        cat "$cache_file"
        return
    fi

    # Try to scrape the download page
    local download_page="${SQUEAK_CACHE_DIR}/squeak-downloads.html"
    if download_file "https://squeak.org/downloads/" "$download_page" 2>/dev/null; then
        # Extract version numbers and download URLs from the page
        # Look for patterns like "Squeak-6.0" or "Squeak 6.0"
        grep -oP 'Squeak[- ]?[0-9]+\.[0-9]+' "$download_page" 2>/dev/null | \
            sort -uV | \
            head -10 > "${SQUEAK_CACHE_DIR}/versions-temp.txt"

        # Return known stable versions if scraping fails
        if [[ ! -s "${SQUEAK_CACHE_DIR}/versions-temp.txt" ]]; then
            echo "6.0" > "${SQUEAK_CACHE_DIR}/versions-temp.txt"
            echo "5.4" >> "${SQUEAK_CACHE_DIR}/versions-temp.txt"
            echo "5.3" >> "${SQUEAK_CACHE_DIR}/versions-temp.txt"
        fi

        cat "${SQUEAK_CACHE_DIR}/versions-temp.txt"
    else
        # Fallback to known versions
        echo "6.0"
        echo "5.4"
        echo "5.3"
    fi
}

# List available Squeak versions
list_squeak_versions() {
    log_info "Available Squeak versions:"
    echo "  stable - Latest stable release (Squeak 6.0)"
    echo "  6.0    - Squeak 6.0"
    echo "  5.4    - Squeak 5.4"
    echo "  5.3    - Squeak 5.3"
}

# Get Squeak download URL for a specific version
get_squeak_url() {
    local version="${1:-$SQUEAK_VERSION}"
    local os_type
    local arch

    os_type=$(get_os)
    arch=$(get_arch)

    local url_key

    # Normalize version
    case "$version" in
        stable|latest)
            version="6.0"
            ;;
    esac

    # Map OS and architecture to URL key
    case "$os_type" in
        macos)
            case "$arch" in
                arm64)
                    url_key="${version}-macos-arm64"
                    ;;
                *)
                    url_key="${version}-macos-x64"
                    ;;
            esac
            ;;
        linux)
            case "$arch" in
                arm64)
                    url_key="${version}-linux-arm64"
                    ;;
                *)
                    url_key="${version}-linux-x64"
                    ;;
            esac
            ;;
        windows)
            url_key="${version}-windows"
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac

    # Look up URL from known URLs
    local url
    case "$url_key" in
        6.0-macos-x64) url="${SQUEAK_DOWNLOAD_URLS[6.0-macos-x64]}" ;;
        6.0-macos-arm64) url="${SQUEAK_DOWNLOAD_URLS[6.0-macos-arm64]}" ;;
        6.0-linux-x64) url="${SQUEAK_DOWNLOAD_URLS[6.0-linux-x64]}" ;;
        6.0-linux-arm64) url="${SQUEAK_DOWNLOAD_URLS[6.0-linux-arm64]}" ;;
        6.0-windows) url="${SQUEAK_DOWNLOAD_URLS[6.0-windows]}" ;;
        5.4*)
            # Fall back to all-in-one for older versions
            url="${SQUEAK_DOWNLOAD_URLS[5.4]}"
            ;;
        5.3*)
            # Fall back to all-in-one for older versions
            url="${SQUEAK_DOWNLOAD_URLS[5.3]}"
            ;;
        *)
            die "Unsupported Squeak version $version for $os_type-$arch. Try using 'stable' for Squeak 6.0"
            ;;
    esac

    echo "$url"
}

# Check if Squeak is installed
is_squeak_installed() {
    local search_dirs=("." "$HOME/Squeak" "$HOME/squeak" "$HOME/.local/share/squeak")

    for dir in "${search_dirs[@]}"; do
        if [[ -f "${dir}/Squeak.image" ]] && [[ -f "${dir}/Squeak.changes" ]]; then
            echo "$dir"
            return 0
        fi
        if [[ -d "${dir}/Squeak.app" ]] || [[ -d "${dir}/Squeak6.0.app" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Download Squeak
download_squeak() {
    local version="${1:-$SQUEAK_VERSION}"
    local install_dir="${2:-.}"

    log_info "Downloading Squeak ${version}..."

    local download_url
    download_url=$(get_squeak_url "$version")

    log_debug "Download URL: $download_url"

    ensure_install_dir "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    local archive_name="Squeak-${version}.zip"
    local temp_dir
    temp_dir=$(mktemp -d)

    if ! download_file "$download_url" "${temp_dir}/${archive_name}"; then
        log_error "Failed to download Squeak ${version}"
        rm -rf "$temp_dir"
        return 1
    fi

    # Extract
    extract_archive "${temp_dir}/${archive_name}" "$temp_dir"

    # Find and move extracted contents
    local extracted_dir
    extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d \( -name "Squeak*" -o -name "squeak*" \) | head -1)

    if [[ -n "$extracted_dir" && -d "$extracted_dir" ]]; then
        cp -r "$extracted_dir"/* .
        cp -r "$extracted_dir"/.* . 2>/dev/null || true
    fi

    rm -rf "$temp_dir"

    if is_squeak_installed >/dev/null; then
        log_success "Squeak ${version} installed successfully"

        # Register files
        local files=()
        for f in Squeak.image Squeak.changes Squeak*.sources Squeak*.app squeak; do
            if [[ -e "$f" ]]; then
                files+=("$(pwd)/$f")
            fi
        done
        register_install "squeak" "$(pwd)" "${files[@]}"
    else
        die "Squeak installation failed - image files not found after extraction"
    fi
}

# Run Squeak
run_squeak() {
    local squeak_dir
    squeak_dir=$(is_squeak_installed) || die "Squeak is not installed. Run 'smalltalk squeak install' first."

    cd "$squeak_dir" || die "Cannot change to Squeak directory"

    local os_type
    os_type=$(get_os)

    case "$os_type" in
        macos)
            # Find .app bundle
            local app_path
            app_path=$(find . -name "*.app" -type d 2>/dev/null | head -1)
            if [[ -n "$app_path" ]]; then
                open "$app_path"
            elif [[ -f "./Squeak.app" ]]; then
                open ./Squeak.app
            elif [[ -f "./Squeak6.0.app" ]]; then
                open ./Squeak6.0.app
            else
                die "Squeak.app not found"
            fi
            ;;
        linux)
            local vm_path
            vm_path=$(find . -name "squeak" -o -name "squeakvm" 2>/dev/null | head -1 || true)
            if [[ -n "$vm_path" ]]; then
                chmod +x "$vm_path"
                "$vm_path" Squeak.image
            elif [[ -f "./Squeak.image" ]]; then
                squeak Squeak.image || die "Failed to run Squeak"
            else
                die "Cannot find Squeak VM or image"
            fi
            ;;
        windows)
            if [[ -f "./Squeak.exe" ]]; then
                ./Squeak.exe
            else
                die "Squeak.exe not found"
            fi
            ;;
    esac
}

#################################
## Command Handlers
#################################

smalltalk_squeak_help() {
    cat << 'EOF'
Squeak Smalltalk Commands
========================

Usage: smalltalk [-x] squeak <command> [options]

Commands:
  install [ver] [-d dir]   Install Squeak (options: stable, 6.0, 5.4, 5.3)
  run                       Run Squeak
  search <term>             Search for packages
  list                      List available packages
  update                    Update package information
  clean                     Clean cache directory
  clean_artifacts           Clean installed artifacts
  version                   Show Squeak version
  help                      Show this help message

Options:
  -d, --dir <path>          Installation directory (default: current directory)

Debug Mode:
  -x, --debug               Enable debug mode (set -x tracing)
                            Must be specified before implementation name
                            Example: smalltalk -x squeak install

Examples:
  smalltalk squeak install                    # Install latest stable Squeak
  smalltalk squeak install 5.4              # Install Squeak 5.4
  smalltalk squeak install -d ~/squeak      # Install to specific directory
  smalltalk squeak install 5.3 -d ~/squeak53  # Install specific version
  smalltalk -x squeak install               # Install with debug output
  smalltalk squeak run                       # Run Squeak
  smalltalk squeak version                   # Show installed version

Available Versions:
  stable  - Latest stable release (Squeak 6.0)
  6.0     - Squeak 6.0
  5.4     - Squeak 5.4
  5.3     - Squeak 5.3

Notes:
  - Squeak has limited command-line interface compared to Pharo/GT
  - Squeak uses Monticello for package management
  - Package listings use GitHub topics

About Squeak:
  Squeak is a modern, open-source Smalltalk environment.
  It provides a fully object-oriented, dynamically typed language.
  Website: https://squeak.org

EOF
}

smalltalk_squeak_install() {
    local version="$SQUEAK_VERSION"
    local install_dir="."

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                install_dir="$2"
                shift 2
                ;;
            -h|--help)
                smalltalk_squeak_help
                return 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Usage: smalltalk squeak install [version] [-d <dir>]"
                return 1
                ;;
            *)
                version="$1"
                shift
                ;;
        esac
    done

    # Validate version
    case "$version" in
        stable|latest|6.0|5.4|5.3)
            ;;
        help)
            list_squeak_versions
            return 0
            ;;
        *)
            log_error "Unknown Squeak version: $version"
            echo "Run 'smalltalk squeak install help' to see available versions."
            return 1
            ;;
    esac

    # If no destination directory specified, create timestamped subdirectory
    if [[ "$install_dir" == "." ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="Squeak-${version}_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
    fi

    # Check for existing Smalltalk installation
    if [[ -d "$install_dir" ]]; then
        local existing
        existing=$(detect_existing_smalltalk "$install_dir")
        if [[ -n "$existing" && "$existing" != "squeak" ]]; then
            log_error "Directory $install_dir already contains a $existing installation"
            return 1
        fi
    fi

    download_squeak "$version" "$install_dir"
}

smalltalk_squeak_run() {
    local cmd="${1:-}"

    # If no command, just run the UI
    if [[ -z "$cmd" ]]; then
        run_squeak
        return
    fi

    # Squeak has different command line interface than Pharo
    case "$cmd" in
        help|--help|-h)
            smalltalk_squeak_help
            ;;
        *)
            log_error "Squeak does not support command-line execution of scripts"
            log_info "Run 'smalltalk squeak run' to launch the Squeak UI"
            return 1
            ;;
    esac
}

smalltalk_squeak_search() {
    local search_term="${1:-}"

    if [[ -z "$search_term" ]]; then
        log_error "Please provide a search term"
        echo "Usage: smalltalk squeak search <term>"
        exit 1
    fi

    log_info "Searching for packages matching '$search_term'..."

    local api_url="https://api.github.com/search/repositories?q=topic:squeak+${search_term}&per_page=50"
    ensure_cache_dir
    mkdir -p "${SQUEAK_CACHE_DIR}"
    local cache_file="${SQUEAK_CACHE_DIR}/search_${search_term// /_}.json"

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

smalltalk_squeak_list() {
    list_monticello_packages "squeak" "squeak"
}

smalltalk_squeak_update() {
    update_monticello_packages "squeak" "squeak"
}

smalltalk_squeak_clean() {
    clean_impl_cache "squeak"
}

smalltalk_squeak_clean_artifacts() {
    log_info "Cleaning Squeak artifacts..."

    local impl_dir
    impl_dir=$(manifest_get_dir "squeak")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        local patterns=(
            "Squeak*.image"
            "Squeak*.changes"
            "Squeak*.sources"
            "Squeak*.app"
            "squeak"
            "squeak-console"
        )

        for pattern in "${patterns[@]}"; do
            find . -maxdepth 1 -name "$pattern" -exec rm -rf {} \; 2>/dev/null || true
        done

        manifest_remove "squeak"
        log_success "Squeak artifacts cleaned"
    else
        log_info "No registered Squeak installation found"
        log_info "To clean manually, remove Squeak files from your installation directory"
    fi
}

smalltalk_squeak_version() {
    local squeak_dir
    squeak_dir=$(is_squeak_installed) || {
        echo "Squeak is not installed"
        return 1
    }

    cd "$squeak_dir" || return 1

    # Try to detect version from image file
    if [[ -f "./Squeak.image" ]]; then
        echo "Squeak ${SQUEAK_VERSION:-unknown} (installed at $squeak_dir)"
    else
        echo "Squeak (installed at $squeak_dir)"
    fi
}
