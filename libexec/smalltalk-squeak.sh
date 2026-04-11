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

# Use All-in-One ZIP for all platforms (includes VM and is cross-platform)
# The All-in-One format is preferred because it works on all platforms

#################################
## Squeak Helper Functions
#################################

# Get the current stable version from files.squeak.org/current_stable/
get_current_stable_version() {
    local cache_file="${SQUEAK_CACHE_DIR}/current_stable.txt"
    ensure_cache_dir
    mkdir -p "${SQUEAK_CACHE_DIR}"
    
    # Check cache (valid for 1 day)
    if [[ -f "$cache_file" ]]; then
        local cache_age
        if [[ "$(uname)" == "Darwin" ]]; then
            cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0) ))
        else
            cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
        fi
        if [[ $cache_age -lt 86400 ]]; then  # 24 hours
            cat "$cache_file"
            return
        fi
    fi
    
    # Fetch the current_stable directory listing
    log_debug "Fetching current_stable version from files.squeak.org..."
    local listing
    listing=$(curl -fsSL "${SQUEAK_URL_BASE}/current_stable/" 2>/dev/null | grep -oE 'Squeak[0-9]+\.[0-9]+-[0-9]+-64bit' | head -1) || true
    
    if [[ -z "$listing" ]]; then
        # Fallback to known version
        log_warn "Could not detect current_stable, using fallback"
        listing="Squeak6.1-22165-64bit"
    fi
    
    # Cache the result
    echo "$listing" > "$cache_file"
    echo "$listing"
}

# Get available Squeak versions
get_squeak_versions() {
    log_info "Available Squeak versions:"
    echo "  stable - Latest from files.squeak.org/current_stable (recommended)"
    echo "  6.1    - Squeak 6.1"
    echo "  6.0    - Squeak 6.0"
    echo "  5.3    - Squeak 5.3"
}

# List available Squeak versions
list_squeak_versions() {
    get_squeak_versions
}

# Get Squeak download URL for a specific version
# Prioritizes All-in-One ZIP format for consistency across platforms
get_squeak_url() {
    local version="${1:-$SQUEAK_VERSION}"

    log_debug "Getting Squeak URL for version=$version"

    # For stable/latest, use current_stable directory
    case "$version" in
        stable|latest)
            # Get current stable version dynamically
            local current_stable
            current_stable=$(get_current_stable_version)
            
            # Use All-in-One ZIP for cross-platform compatibility
            echo "${SQUEAK_URL_BASE}/current_stable/${current_stable}/${current_stable}-All-in-One.zip"
            return
            ;;
    esac

    # For specific versions, construct URL using All-in-One format
    # All-in-One ZIP works on all platforms and includes VM
    local version_dir
    local squeak_build
    
    case "$version" in
        6.1)
            version_dir="6.1"
            squeak_build="Squeak6.1alpha-22148-64bit"
            ;;
        6.0)
            version_dir="6.0"
            squeak_build="Squeak6.0-22148-64bit"
            ;;
        5.3)
            version_dir="5.3"
            squeak_build="Squeak5.3-19486-64bit"
            ;;
        *)
            die "Unsupported Squeak version: $version. Use stable, 6.1, 6.0, or 5.3"
            ;;
    esac

    # Use All-in-One ZIP for all platforms (includes VM, cross-platform)
    echo "${SQUEAK_URL_BASE}/${version_dir}/${squeak_build}/${squeak_build}-All-in-One.zip"
}

# Check if Squeak is installed
is_squeak_installed() {
    # First check current directory
    if [[ -f "./Squeak.image" ]] && [[ -f "./Squeak.changes" ]]; then
        echo "$(pwd)"
        return 0
    fi
    
    # Check for Squeak*.image at root
    shopt -s nullglob
    for img in Squeak*.image; do
        if [[ -f "$img" ]]; then
            local changes="${img%.image}.changes"
            if [[ -f "$changes" ]]; then
                shopt -u nullglob
                echo "$(pwd)"
                return 0
            fi
        fi
    done
    
    # Check for timestamped directories
    for dir in Squeak-*; do
        if [[ -d "$dir" ]]; then
            for img in "$dir"/Squeak*.image; do
                if [[ -f "$img" ]]; then
                    shopt -u nullglob
                    echo "$(pwd)/$dir"
                    return 0
                fi
            done
            # Check inside .app bundle in subdirectory
            for app_dir in "$dir"/*.app; do
                if [[ -d "$app_dir" ]]; then
                    local resources="$app_dir/Contents/Resources"
                    if [[ -d "$resources" ]]; then
                        for img in "$resources"/*.image; do
                            if [[ -f "$img" ]]; then
                                shopt -u nullglob
                                echo "$(pwd)/$dir"
                                return 0
                            fi
                        done
                    fi
                fi
            done
        fi
    done
    shopt -u nullglob
    
    # Check inside .app bundle (macOS All-in-One format)
    shopt -s nullglob
    for app_dir in *.app; do
        if [[ -d "$app_dir" ]]; then
            local resources="$app_dir/Contents/Resources"
            if [[ -d "$resources" ]]; then
                for img in "$resources"/*.image; do
                    if [[ -f "$img" ]]; then
                        shopt -u nullglob
                        echo "$(pwd)"
                        return 0
                    fi
                done
            fi
        fi
    done
    shopt -u nullglob
    
    # Check common locations
    local search_dirs=("$HOME/Squeak" "$HOME/squeak" "$HOME/.local/share/squeak")
    for dir in "${search_dirs[@]}"; do
        if [[ -f "${dir}/Squeak.image" ]] && [[ -f "${dir}/Squeak.changes" ]]; then
            echo "$dir"
            return 0
        fi
        
        # Check for versioned images
        shopt -s nullglob
        for img in "${dir}"/Squeak*.image; do
            if [[ -f "$img" ]]; then
                local changes="${img%.image}.changes"
                if [[ -f "$changes" ]]; then
                    shopt -u nullglob
                    echo "$dir"
                    return 0
                fi
            fi
        done
        shopt -u nullglob
        
        # Check inside .app bundles
        shopt -s nullglob
        for app_dir in "${dir}"/*.app; do
            if [[ -d "$app_dir" ]]; then
                local resources="$app_dir/Contents/Resources"
                if [[ -d "$resources" ]]; then
                    for img in "$resources"/*.image; do
                        if [[ -f "$img" ]]; then
                            shopt -u nullglob
                            echo "$dir"
                            return 0
                        fi
                    done
                fi
            fi
        done
        shopt -u nullglob
    done
    
    return 1
}

# Find Squeak installation relative to current directory
find_squeak_in_current_dir() {
    # Check current directory
    if [[ -f "./Squeak.image" ]] && [[ -f "./Squeak.changes" ]]; then
        echo "$(pwd)"
        return 0
    fi
    
    # Check for timestamped directories
    shopt -s nullglob
    local latest_dir=""
    local latest_time=0
    
    for dir in Squeak-*; do
        if [[ -d "$dir" ]]; then
            # Check for .app inside
            local found_image=false
            for app in "$dir"/*.app; do
                if [[ -d "$app" ]] && [[ -d "$app/Contents/Resources" ]]; then
                    for img in "$app/Contents/Resources"/*.image; do
                        if [[ -f "$img" ]]; then
                            found_image=true
                            break 2
                        fi
                    done
                fi
            done
            
            # Also check for image at root of dir
            if ! $found_image; then
                for img in "$dir"/Squeak*.image; do
                    if [[ -f "$img" ]]; then
                        found_image=true
                        break
                    fi
                done
            fi
            
            if $found_image; then
                local mtime
                mtime=$(stat -f %m "$dir" 2>/dev/null || stat -c %Y "$dir" 2>/dev/null || echo 0)
                if [[ "$mtime" -gt "$latest_time" ]]; then
                    latest_time="$mtime"
                    latest_dir="$dir"
                fi
            fi
        fi
    done
    
    # Also check .app bundles at root
    for app in *.app; do
        if [[ -d "$app" ]] && [[ -d "$app/Contents/Resources" ]]; then
            for img in "$app/Contents/Resources"/*.image; do
                if [[ -f "$img" ]]; then
                    shopt -u nullglob
                    echo "$(pwd)"
                    return 0
                fi
            done
        fi
    done
    shopt -u nullglob
    
    if [[ -n "$latest_dir" ]]; then
        echo "$(pwd)/$latest_dir"
        return 0
    fi
    
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

    # Validate URL
    if ! validate_url "$download_url"; then
        die "Invalid download URL: $download_url"
    fi

    ensure_install_dir "$install_dir"
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"

    local archive_name="Squeak-${version}.zip"
    local temp_dir
    temp_dir=$(make_temp_dir squeak)

    log_info "Downloading from: $download_url"
    
    if ! download_file "$download_url" "${temp_dir}/${archive_name}"; then
        log_error "Failed to download Squeak ${version}"
        log_error "The version may not be available, or the URL has changed."
        log_error "Try a different version or check https://files.squeak.org/"
        rm -rf "$temp_dir"
        return 1
    fi

    # Verify download
    if [[ ! -f "${temp_dir}/${archive_name}" ]]; then
        log_error "Download file not found"
        rm -rf "$temp_dir"
        return 1
    fi

    log_info "Extracting Squeak..."
    
    # Extract the ZIP file
    if ! extract_archive "${temp_dir}/${archive_name}" "$temp_dir"; then
        log_error "Failed to extract archive"
        rm -rf "$temp_dir"
        return 1
    fi

    # Find the extracted content
    # All-in-One format: the .app bundle is directly in the extracted folder
    local found_image=false
    local extracted_app=""
    
    # Look for .app bundle in extracted directory (macOS All-in-One)
    for app_dir in "$temp_dir"/*.app "$temp_dir"/Squeak*.app; do
        if [[ -d "$app_dir" ]]; then
            extracted_app="$app_dir"
            break
        fi
    done
    
    if [[ -n "$extracted_app" ]] && [[ -d "$extracted_app" ]]; then
        log_debug "Found .app bundle: $extracted_app"
        
        # Copy the entire .app bundle to install directory
        local app_name
        app_name=$(basename "$extracted_app")
        cp -r "$extracted_app" .
        log_info "Installed: $app_name"
        
        # Check for image inside the .app/Contents/Resources/
        local resources="$extracted_app/Contents/Resources"
        if [[ -d "$resources" ]]; then
            for img in "$resources"/*.image; do
                if [[ -f "$img" ]]; then
                    found_image=true
                    log_debug "Found image: $(basename $img)"
                    break
                fi
            done
        fi
    else
        # Fallback: Look for image files or extracted directory at root
        log_debug "No .app bundle found, looking for other formats..."
        
        # Try to find a Squeak directory in the extracted content
        extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "Squeak*" 2>/dev/null | head -1)
        
        if [[ -n "$extracted_dir" ]] && [[ -d "$extracted_dir" ]]; then
            # Copy contents to install directory
            cp -r "$extracted_dir"/* . 2>/dev/null || true
        else
            # Files might be at root of archive
            cp -r "$temp_dir"/* . 2>/dev/null || true
        fi
        
        # Check for image files at root
        for img in Squeak*.image *.image; do
            if [[ -f "$img" ]]; then
                found_image=true
                break
            fi
        done
    fi

    # Cleanup temp directory
    rm -rf "$temp_dir"

    # Final verification: check inside installed .app bundles
    if ! $found_image; then
        for app_dir in *.app; do
            if [[ -d "$app_dir" ]]; then
                local resources="$app_dir/Contents/Resources"
                if [[ -d "$resources" ]]; then
                    for img in "$resources"/*.image; do
                        if [[ -f "$img" ]]; then
                            found_image=true
                            log_debug "Verified image in: $app_dir/Contents/Resources/"
                            break 2
                        fi
                    done
                fi
            fi
        done
    fi

    # Also check for Squeak*.image pattern
    if ! $found_image; then
        for img in Squeak*.image; do
            if [[ -f "$img" ]]; then
                found_image=true
                break
            fi
        done
    fi

    if ! $found_image; then
        log_error "Squeak installation failed - no image file found after extraction"
        log_error "Contents of install directory:"
        ls -la .
        die "Please check the extracted files manually"
    fi

    log_success "Squeak ${version} installed successfully"

    # Register files
    local files=()
    # Register the .app bundle(s)
    for app in *.app; do
        if [[ -d "$app" ]]; then
            files+=("$(pwd)/$app")
        fi
    done
    # Register any standalone image files
    for f in Squeak*.image Squeak*.changes Squeak*.sources; do
        if [[ -e "$f" ]]; then
            files+=("$(pwd)/$f")
        fi
    done
    register_install "squeak" "$(pwd)" "${files[@]}"
}

# Run Squeak
run_squeak() {
    local squeak_dir
    local original_dir="$(pwd)"
    
    # First try current directory, then search common locations
    squeak_dir=$(find_squeak_in_current_dir 2>/dev/null) || squeak_dir=$(is_squeak_installed 2>/dev/null) || true
    
    # If not found, create installation
    if [[ -z "$squeak_dir" ]]; then
        log_info "No Squeak installation found. Creating new installation..."
        
        # Create timestamped directory
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local install_dir="Squeak-${SQUEAK_VERSION}_${timestamp}"
        
        mkdir -p "$install_dir"
        cd "$install_dir" || die "Cannot create directory: $install_dir"
        
        download_squeak "$SQUEAK_VERSION" "."
        
        if [[ ! -d "*.app" ]] && [[ ! -f "Squeak*.image" ]]; then
            die "Squeak installation failed - no .app or image found"
        fi
        
        squeak_dir="$(pwd)"
        log_success "Squeak installed to: $squeak_dir"
    else
        cd "$squeak_dir" || die "Cannot change to Squeak directory: $squeak_dir"
    fi
    
    # Determine how to launch based on OS
    local os_type
    os_type=$(get_os)
    
    case "$os_type" in
        macos)
            # Find .app bundle (works for All-in-One)
            local app_path
            app_path=$(find . -name "*.app" -type d 2>/dev/null | head -1)
            if [[ -n "$app_path" ]]; then
                log_info "Launching Squeak from: $squeak_dir"
                open "$app_path"
            elif [[ -f "./Squeak.app" ]]; then
                open ./Squeak.app
            else
                # Look for any .app
                shopt -s nullglob
                local apps=(*.app)
                shopt -u nullglob
                if [[ ${#apps[@]} -gt 0 ]] && [[ -d "${apps[0]}" ]]; then
                    open "${apps[0]}"
                else
                    die "Squeak.app not found in $squeak_dir"
                fi
            fi
            ;;
        linux)
            # Look for the Squeak VM executable inside .app bundle or at root
            local vm_path=""
            local image_name=""
            
            # Check inside .app bundle for Linux executable
            shopt -s nullglob
            for app in *.app; do
                if [[ -d "$app" ]]; then
                    # Check for Linux executable in bin/ or similar
                    if [[ -f "$app/bin/squeak" ]]; then
                        vm_path="$app/bin/squeak"
                    elif [[ -f "$app/squeak" ]]; then
                        vm_path="$app/squeak"
                    fi
                    
                    # Also look for image in Contents/Resources
                    local resources="$app/Contents/Resources"
                    if [[ -d "$resources" ]]; then
                        for img in "$resources"/*.image; do
                            if [[ -f "$img" ]]; then
                                image_name="$img"
                                break
                            fi
                        done
                    fi
                    
                    if [[ -n "$vm_path" ]]; then
                        break
                    fi
                fi
            done
            shopt -u nullglob
            
            # Fallback: Check for image at root
            if [[ -z "$image_name" ]]; then
                shopt -s nullglob
                image_name=$(ls Squeak*.image 2>/dev/null | head -1)
                shopt -u nullglob
            fi
            
            # Fallback: Check for squeak/squeakvm at root
            if [[ -z "$vm_path" ]]; then
                vm_path=$(find . -maxdepth 2 -name "squeak" -o -name "squeakvm" 2>/dev/null | head -1)
            fi
            
            if [[ -n "$vm_path" ]] && [[ -n "$image_name" ]]; then
                chmod +x "$vm_path" 2>/dev/null || true
                log_info "Launching Squeak from: $squeak_dir"
                "$vm_path" "$image_name"
            elif [[ -n "$image_name" ]]; then
                # Try system squeak
                if command -v squeak &>/dev/null; then
                    squeak "$image_name"
                else
                    die "Cannot find Squeak VM. Install system Squeak or check the All-in-One bundle."
                fi
            else
                die "Cannot find Squeak image or VM in $squeak_dir"
            fi
            ;;
        windows)
            # Look for .exe file inside .app or at root
            local exe_path=""
            
            # Check inside .app bundle for Windows executable
            shopt -s nullglob
            for app in *.app; do
                if [[ -d "$app" ]]; then
                    if [[ -f "$app/Contents/Resources/Squeak.exe" ]]; then
                        exe_path="$app/Contents/Resources/Squeak.exe"
                    elif [[ -f "$app/Squeak.exe" ]]; then
                        exe_path="$app/Squeak.exe"
                    fi
                    if [[ -n "$exe_path" ]]; then
                        break
                    fi
                fi
            done
            shopt -u nullglob
            
            # Fallback: Check for .exe at root or in subdirectories
            if [[ -z "$exe_path" ]]; then
                exe_path=$(find . -name "Squeak.exe" -o -name "*.exe" 2>/dev/null | head -1)
            fi
            
            if [[ -n "$exe_path" ]] && [[ -f "$exe_path" ]]; then
                chmod +x "$exe_path" 2>/dev/null || true
                log_info "Launching Squeak from: $squeak_dir"
                "$exe_path"
            else
                die "Squeak.exe not found in $squeak_dir"
            fi
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac
}

#################################
## Command Handlers
#################################

smalltalk_squeak_help() {
    cat << 'EOF'
Squeak Smalltalk Commands
=========================

Usage: smalltalk [-x] squeak <command> [options]

Commands:
  install [ver] [-d dir]   Install Squeak (options: stable, 6.1, 6.0, 5.3)
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

Download Notes:
  - All platforms download the "All-in-One" ZIP which includes the VM
  - This ensures consistent behavior across macOS, Linux, and Windows
  - The "stable" version is detected from files.squeak.org/current_stable/

Examples:
  smalltalk squeak install                    # Install latest stable Squeak
  smalltalk squeak install 6.0                # Install Squeak 6.0
  smalltalk squeak install -d ~/squeak        # Install to specific directory
  smalltalk -x squeak install                 # Install with debug output
  smalltalk squeak run                        # Run Squeak
  smalltalk squeak version                    # Show installed version

Available Versions:
  stable  - Latest stable (detected from files.squeak.org/current_stable/)
  6.1     - Squeak 6.1
  6.0     - Squeak 6.0
  5.3     - Squeak 5.3

Notes:
  - Squeak uses All-in-One zip format with bundled VM
  - Works on macOS (Intel and Apple Silicon), Linux, and Windows
  - Package management via Monticello (search runs GitHub queries)

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
        stable|latest|6.1|6.0|5.3)
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

    # Check for existing Smalltalk installation
    if [[ -d "$install_dir" ]]; then
        local existing
        existing=$(detect_existing_smalltalk "$install_dir")
        if [[ -n "$existing" && "$existing" != "squeak" ]]; then
            log_error "Directory $install_dir already contains a $existing installation"
            return 1
        fi
    fi

    # If no destination directory specified, create timestamped subdirectory
    if [[ "$install_dir" == "." ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="Squeak-${version}_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
        mkdir -p "$install_dir"
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

    # Squeak has limited command-line interface
    case "$cmd" in
        help|--help|-h)
            smalltalk_squeak_help
            ;;
        *)
            log_error "Squeak does not support command-line execution of scripts"
            log_info "Run 'smalltalk squeak run' to launch the Squeak UI"
            log_info "For script execution, use the Squeak UI or Pharo/GNU Smalltalk"
            return 1
            ;;
    esac
}

smalltalk_squeak_search() {
    local search_term="${1:-}"

    if [[ -z "$search_term" ]]; then
        log_error "Please provide a search term"
        echo "Usage: smalltalk squeak search <term>"
        return 1
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

        # Use glob patterns for performance
        shopt -s nullglob
        local patterns=(
            Squeak*.image Squeak*.changes Squeak*.sources
            Squeak*.app squeak squeakvm
        )
        
        for pattern in "${patterns[@]}"; do
            for f in $pattern; do
                rm -rf "$f" 2>/dev/null || true
            done
        done
        shopt -u nullglob

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

    # Try to detect version from image file name
    local image_name=""
    
    # First check inside .app bundle (All-in-One format)
    for app_dir in *.app Squeak*.app; do
        if [[ -d "$app_dir" ]]; then
            local resources="$app_dir/Contents/Resources"
            if [[ -d "$resources" ]]; then
                for img in "$resources"/*.image; do
                    if [[ -f "$img" ]]; then
                        image_name=$(basename "$img")
                        break 2
                    fi
                done
            fi
        fi
    done
    
    # Fallback: check for image at root
    if [[ -z "$image_name" ]]; then
        for img in Squeak*.image *.image; do
            if [[ -f "$img" ]]; then
                image_name=$(basename "$img")
                break
            fi
        done
    fi

    if [[ -n "$image_name" ]]; then
        # Extract version from image name (e.g., Squeak5.3-19486.image, Squeak6.0-22148.image)
        local version
        version=$(echo "$image_name" | grep -oE 'Squeak[0-9]+(\.[0-9]+)?' | head -1)
        if [[ -n "$version" ]]; then
            echo "${version} (installed at $squeak_dir)"
        else
            echo "Squeak (installed at $squeak_dir)"
        fi
    else
        echo "Squeak (installed at $squeak_dir)"
    fi
}