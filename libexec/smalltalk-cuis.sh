#!/usr/bin/env bash
#
# smalltalk-cuis.sh - Cuis Smalltalk implementation
#
set -Euo pipefail
IFS=$'\n\t'

# shellcheck source=libexec/smalltalk-common.sh
source "${BASH_SOURCE%/*}/smalltalk-common.sh"

#################################
## Cuis Configuration
#################################

CUIS_URL_BASE="https://github.com/Cuis-Smalltalk"
CUIS_VERSION="${CUIS_VERSION:-stable}"
CUIS_CACHE_DIR="${CACHE_DIR}/cuis"

#################################
## Cuis Helper Functions
#################################

# Get Cuis version information
get_cuis_versions() {
    local api_url="${CUIS_URL_BASE}/Cuis-Smalltalk-Dev"
    local releases_file="${CUIS_CACHE_DIR}/cuis-releases.json"

    ensure_cache_dir
    mkdir -p "${CUIS_CACHE_DIR}"

    if [[ -f "$releases_file" ]] && [[ $(find "$releases_file" -mtime +1 2> /dev/null) ]]; then
        cat "$releases_file"
    else
        download_file "$api_url" "$releases_file" 2> /dev/null || true
        cat "$releases_file" 2> /dev/null || echo '{}'
    fi
}

# Get Cuis download URL for a specific version
get_cuis_url() {
    local version="${1:-$CUIS_VERSION}"
    local os_type
    local arch

    os_type=$(get_os)
    arch=$(get_arch)

    local base_url
    case "$version" in
        stable | latest)
            base_url="${CUIS_URL_BASE}/Cuis7-6/archive/refs/heads/main.zip"
            ;;
        7.0 | 7.0*)
            base_url="${CUIS_URL_BASE}/Cuis7-0/archive/refs/heads/main.zip"
            ;;
        6.0 | 6.0*)
            base_url="${CUIS_URL_BASE}/Cuis6-0/archive/refs/heads/main.zip"
            ;;
        *)
            # Try as a branch name
            base_url="${CUIS_URL_BASE}/${version}/archive/refs/heads/main.zip"
            ;;
    esac

    echo "$base_url"
}

# List available Cuis versions
list_cuis_versions() {
    log_info "Available Cuis versions:"
    echo "  stable - Latest stable release (Cuis 7.6)"
    echo "  7.0    - Cuis 7.0"
    echo "  6.0    - Cuis 6.0"
}

# Check if Cuis is installed
is_cuis_installed() {
    # First check current directory for Cuis*.image
    shopt -s nullglob
    for img in Cuis*.image; do
        if [[ -f "$img" ]]; then
            local changes="${img%.image}.changes"
            if [[ -f "$changes" ]]; then
                shopt -u nullglob
                echo "$(pwd)"
                return 0
            fi
        fi
    done
    shopt -u nullglob

    # Check for timestamped directories (e.g., Cuis-stable_20240410_220002)
    shopt -s nullglob
    for dir in Cuis-*; do
        if [[ -d "$dir" ]]; then
            for img in "$dir"/Cuis*.image; do
                if [[ -f "$img" ]]; then
                    local changes="${img%.image}.changes"
                    if [[ -f "$changes" ]]; then
                        shopt -u nullglob
                        echo "$(pwd)/$dir"
                        return 0
                    fi
                fi
            done
            # Also check for Cuis7-6-main style directory
            if compgen -G "${dir}/CuisImage/*.image" > /dev/null; then
                shopt -u nullglob
                echo "$(pwd)/$dir"
                return 0
            fi
        fi
    done
    shopt -u nullglob

    # Check for Cuis in common locations
    local search_dirs=("$HOME/Cuis" "$HOME/cuis" "$HOME/.local/share/cuis")
    for dir in "${search_dirs[@]}"; do
        shopt -s nullglob
        for img in "$dir"/Cuis*.image; do
            if [[ -f "$img" ]]; then
                local changes="${img%.image}.changes"
                if [[ -f "$changes" ]]; then
                    shopt -u nullglob
                    echo "$dir"
                    return 0
                fi
            fi
        done
        # Also check subdirectories
        for subdir in "$dir"/Cuis-*; do
            if [[ -d "$subdir" ]]; then
                for img in "$subdir"/Cuis*.image "$subdir"/CuisImage/*.image; do
                    if [[ -f "$img" ]]; then
                        shopt -u nullglob
                        echo "$subdir"
                        return 0
                    fi
                done
            fi
        done
        shopt -u nullglob
    done

    return 1
}

# Find Cuis installation relative to current directory
find_cuis_in_current_dir() {
    # Check current directory for Cuis*.image
    shopt -s nullglob
    local latest_dir=""
    local latest_time=0

    for img in Cuis*.image; do
        if [[ -f "$img" ]]; then
            shopt -u nullglob
            echo "$(pwd)"
            return 0
        fi
    done
    shopt -u nullglob

    # Check for timestamped directories
    for dir in Cuis-*; do
        if [[ -d "$dir" ]]; then
            for img in "$dir"/Cuis*.image; do
                if [[ -f "$img" ]]; then
                    local mtime
                    mtime=$(stat -f %m "$dir" 2> /dev/null || stat -c %Y "$dir" 2> /dev/null || echo 0)
                    if [[ "$mtime" -gt "$latest_time" ]]; then
                        latest_time="$mtime"
                        latest_dir="$dir"
                    fi
                fi
            done
            # Also check for CuisImage subdirectory (Cuis7-6-main style)
            if [[ -d "$dir/CuisImage" ]]; then
                for img in "$dir/CuisImage"/*.image; do
                    if [[ -f "$img" ]]; then
                        local mtime
                        mtime=$(stat -f %m "$dir" 2> /dev/null || stat -c %Y "$dir" 2> /dev/null || echo 0)
                        if [[ "$mtime" -gt "$latest_time" ]]; then
                            latest_time="$mtime"
                            latest_dir="$dir"
                        fi
                    fi
                done
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

# Download and extract Cuis
download_cuis() {
    local version="${1:-$CUIS_VERSION}"
    local install_dir="${2:-.}"
    local original_dir
    original_dir="$(pwd)"

    log_info "Downloading Cuis ${version} to ${install_dir}..."

    local download_url
    download_url=$(get_cuis_url "$version")

    log_debug "Download URL: $download_url"

    # Ensure install directory exists
    ensure_install_dir "$install_dir"
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"
    install_dir="$(pwd)"

    local archive_name="Cuis-${version}.zip"
    local temp_dir
    temp_dir=$(mktemp -d)

    if ! download_file "$download_url" "${temp_dir}/${archive_name}"; then
        log_error "Failed to download Cuis ${version}"
        rm -rf -- "$temp_dir"
        cd "$original_dir"
        return 1
    fi

    # Extract - the zip will have a subdirectory like Cuis7-6-main
    extract_archive "${temp_dir}/${archive_name}" "$temp_dir"

    # Find the extracted directory
    local extracted_dir
    extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "Cuis*" | head -1)

    if [[ -z "$extracted_dir" || ! -d "$extracted_dir" ]]; then
        log_error "Failed to extract Cuis archive"
        rm -rf -- "$temp_dir"
        cd "$original_dir"
        return 1
    fi

    # Move contents to install_dir
    cp -r "$extracted_dir"/* .
    rm -rf -- "$temp_dir"

    # Check for launch scripts (Cuis provides RunCuisOnMac.sh, RunCuisOnLinux.sh, RunCuisOnWindows.bat)
    local has_launcher=false
    shopt -s nullglob
    for f in RunCuisOn*.sh RunCuisOn*.bat; do
        if [[ -f "$f" ]]; then
            has_launcher=true
            break
        fi
    done
    shopt -u nullglob

    if $has_launcher; then
        cd "$original_dir"
        log_success "Cuis ${version} installed successfully to ${install_dir}"

        # Register files
        local files=()
        for f in CuisImage/*.image CuisImage/*.changes CuisImage/*.sources RunCuisOn*.sh RunCuisOn*.bat CuisVM.app; do
            if [[ -e "$f" ]]; then
                files+=("$(pwd)/$f")
            fi
        done
        register_install "cuis" "$(pwd)" "${files[@]}"
    else
        log_error "Contents of install directory:"
        ls -la .
        cd "$original_dir"
        die "Cuis installation failed - launch scripts not found after extraction"
    fi
}

# Run Cuis
run_cuis() {
    local cuis_dir
    local original_dir="$(pwd)"

    # First try current directory, then search common locations
    cuis_dir=$(find_cuis_in_current_dir 2> /dev/null) || cuis_dir=$(is_cuis_installed 2> /dev/null) || true

    # If not found, create installation
    if [[ -z "$cuis_dir" ]]; then
        log_info "No Cuis installation found. Creating new installation..."

        # Create timestamped directory
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local install_dir="Cuis-${CUIS_VERSION}_${timestamp}"

        mkdir -p "$install_dir"
        cd "$install_dir" || die "Cannot create directory: $install_dir"

        download_cuis "$CUIS_VERSION" "."

        # Verify installation - check for launch scripts
        local has_launcher=false
        shopt -s nullglob
        for f in RunCuisOn*.sh RunCuisOn*.bat; do
            if [[ -f "$f" ]]; then
                has_launcher=true
                break
            fi
        done
        shopt -u nullglob

        if ! $has_launcher; then
            die "Cuis installation failed - no launch scripts found"
        fi

        cuis_dir="$(pwd)"
        log_success "Cuis installed to: $cuis_dir"
    else
        cd "$cuis_dir" || die "Cannot change to Cuis directory: $cuis_dir"
    fi

    # Launch based on OS
    local os_type
    os_type=$(get_os)

    case "$os_type" in
        macos)
            # Cuis provides platform-specific launch scripts
            # Check in root directory first, then in CuisImage for Cuis7-6-main style
            if [[ -f "./RunCuisOnMac.sh" ]]; then
                chmod +x ./RunCuisOnMac.sh 2> /dev/null || true
                ./RunCuisOnMac.sh
            elif [[ -f "./CuisImage/RunCuisOnMac.sh" ]]; then
                chmod +x ./CuisImage/RunCuisOnMac.sh 2> /dev/null || true
                ./CuisImage/RunCuisOnMac.sh
            elif [[ -f "./CuisVM.app" ]]; then
                open ./CuisVM.app
            else
                die "Cannot find Cuis executable for macOS (RunCuisOnMac.sh)"
            fi
            ;;
        linux)
            if [[ -f "./RunCuisOnLinux.sh" ]]; then
                chmod +x ./RunCuisOnLinux.sh 2> /dev/null || true
                ./RunCuisOnLinux.sh
            elif [[ -f "./CuisImage/RunCuisOnLinux.sh" ]]; then
                chmod +x ./CuisImage/RunCuisOnLinux.sh 2> /dev/null || true
                ./CuisImage/RunCuisOnLinux.sh
            else
                die "Cannot find Cuis executable for Linux (RunCuisOnLinux.sh)"
            fi
            ;;
        windows)
            if [[ -f "./RunCuisOnWindows.bat" ]]; then
                ./RunCuisOnWindows.bat
            elif [[ -f "./CuisImage/RunCuisOnWindows.bat" ]]; then
                ./CuisImage/RunCuisOnWindows.bat
            else
                die "Cannot find Cuis executable for Windows (RunCuisOnWindows.bat)"
            fi
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac

    log_info "Cuis launched from: $cuis_dir"
}

#################################
## Shared install-or-find helper
#################################

# Find an existing Cuis installation (current dir or common locations), or
# download one into a timestamped directory if none is found. On success CWD is
# the Cuis install dir and the global _CUIS_DIR holds its path. Used by the
# headless handlers (eval) so they auto-install instead of erroring, consistent
# with `st cuis run`, `st pharo eval`, and `st ls4 eval`. Must be called WITHOUT
# command substitution so the `cd` persists.
ensure_cuis_dir() {
    _CUIS_DIR=""
    local cuis_dir
    cuis_dir=$(find_cuis_in_current_dir 2> /dev/null) || cuis_dir=$(is_cuis_installed 2> /dev/null) || true

    if [[ -n "$cuis_dir" ]]; then
        cd "$cuis_dir" || die "Cannot change to Cuis directory: $cuis_dir"
        _CUIS_DIR="$(pwd)"
        return 0
    fi

    log_info "No Cuis installation found. Installing Cuis ${CUIS_VERSION}..."
    local timestamp install_dir
    timestamp=$(date +%Y%m%d_%H%M%S)
    install_dir="Cuis-${CUIS_VERSION}_${timestamp}"
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"
    download_cuis "$CUIS_VERSION" "."
    local has_launcher=false
    shopt -s nullglob
    for f in RunCuisOn*.sh RunCuisOn*.bat; do
        if [[ -f "$f" ]]; then
                               has_launcher=true
                                                  break
        fi
    done
    shopt -u nullglob
    if ! $has_launcher; then die "Cuis installation failed - no launch scripts found"; fi
    _CUIS_DIR="$(pwd)"
    log_success "Cuis installed to: $_CUIS_DIR"
}

#################################
## Command Handlers
#################################

smalltalk_cuis_help() {
    load_help_from_doc "cuis"
}

smalltalk_cuis_install() {
    local version="$CUIS_VERSION"
    local install_dir="."

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d | --dir)
                install_dir="$2"
                shift 2
                ;;
            -h | --help)
                smalltalk_cuis_help
                return 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Usage: st cuis install [version] [-d <dir>]"
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
        stable | latest | 7.0 | 7.0* | 6.0 | 6.0*)
            ;;
        help)
            list_cuis_versions
            return 0
            ;;
        *)
            log_error "Unknown Cuis version: $version"
            echo "Run 'st cuis install help' to see available versions."
            return 1
            ;;
    esac

    # Check for existing Smalltalk installation
    if [[ -d "$install_dir" ]]; then
        local existing
        existing=$(detect_existing_smalltalk "$install_dir")
        if [[ -n "$existing" && "$existing" != "cuis" ]]; then
            log_error "Directory $install_dir already contains a $existing installation"
            return 1
        fi
    fi

    # If no destination directory specified, create timestamped subdirectory
    if [[ "$install_dir" == "." ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="Cuis-${version}_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
        mkdir -p "$install_dir"
    fi

    download_cuis "$version" "$install_dir"
}

smalltalk_cuis_run() {
    run_cuis
}

smalltalk_cuis_search() {
    local search_term="${1:-}"

    if [[ -z "$search_term" ]]; then
        log_error "Please provide a search term"
        echo "Usage: st cuis search <term>"
        exit 1
    fi

    log_info "Searching for Cuis packages matching '$search_term'..."

    local api_url="https://api.github.com/search/repositories?q=cuis+${search_term}&per_page=50"
    ensure_cache_dir
    mkdir -p "${CUIS_CACHE_DIR}"
    local cache_file="${CUIS_CACHE_DIR}/search_${search_term// /_}.json"

    if download_file "$api_url" "$cache_file"; then
        if cmd_exists jq; then
            jq -r '.items[] | "\(.full_name) - \(.description // "No description")"' "$cache_file" 2> /dev/null || {
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

smalltalk_cuis_list() {
    list_monticello_packages "cuis" "cuis"
}

smalltalk_cuis_update() {
    update_monticello_packages "cuis" "cuis"
}

smalltalk_cuis_clean() {
    clean_impl_cache "cuis"
}

smalltalk_cuis_clean_artifacts() {
    log_info "Cleaning Cuis artifacts..."

    local impl_dir
    impl_dir=$(manifest_get_dir "cuis")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        local patterns=(
            "Cuis*.image"
            "Cuis*.changes"
            "Cuis*.sources"
            "Cuis.app"
            "run_cuis.sh"
            "cuis"
        )

        for pattern in "${patterns[@]}"; do
            find . -maxdepth 1 -name "$pattern" -exec rm -rf -- {} \; 2> /dev/null || true
        done

        manifest_remove "cuis"
        log_success "Cuis artifacts cleaned"
    else
        log_info "No registered Cuis installation found"
        log_info "To clean manually, remove Cuis files from your installation directory"
    fi
}

# Locate the Cuis (Squeak) VM inside CuisVM.app for the current OS/arch.
find_cuis_vm() {
    local cpu os_type
    os_type=$(get_os)
    case "$os_type" in
        macos)
            if [[ -x "./CuisVM.app/Contents/MacOS/Squeak" ]]; then
                echo "./CuisVM.app/Contents/MacOS/Squeak"
                return 0
            fi
            ;;
        linux)
            cpu="$(uname -m)"
            case "$cpu" in
                i386 | i686) cpu="i686" ;;
                aarch64 | arm64) cpu="arm64" ;;
                armv6l | armv7l) cpu="arm" ;;
            esac
            if [[ -x "./CuisVM.app/Contents/Linux-${cpu}/squeak" ]]; then
                echo "./CuisVM.app/Contents/Linux-${cpu}/squeak"
                return 0
            fi
            ;;
        windows)
            local f
            shopt -s nullglob
            for f in ./CuisVM.app/Contents/Windows-*/Squeak.exe ./CuisVM.app/Contents/Windows-*/squeak.exe; do
                if [[ -x "$f" ]]; then
                    shopt -u nullglob
                    echo "$f"
                    return 0
                fi
            done
            shopt -u nullglob
            ;;
    esac
    return 1
}

# Locate the Cuis image (CuisImage/*.image, then root Cuis*.image).
find_cuis_image() {
    local img
    shopt -s nullglob
    for img in CuisImage/*.image Cuis*.image; do
        shopt -u nullglob
        echo "$img"
        return 0
    done
    shopt -u nullglob
    return 1
}

smalltalk_cuis_version() {
    local cuis_dir
    cuis_dir=$(is_cuis_installed) || {
        echo "Cuis is not installed"
        return 1
    }

    cd "$cuis_dir" || return 1

    # Read the version from the image filename (e.g. Cuis7.6.image -> 7.6)
    local img base ver
    img=$(find_cuis_image 2> /dev/null | head -1)
    if [[ -n "$img" ]]; then
        base="$(basename "$img")"
        ver="$(printf '%s' "$base" | sed -nE 's/^Cuis([0-9.]+).*\.image$/\1/p')"
        if [[ -n "$ver" ]]; then
            echo "Cuis $ver"
            return 0
        fi
    fi
    echo "Cuis (installed at $cuis_dir)"
}

smalltalk_cuis_eval() {
    local code="$*"

    if [[ -z "$code" ]]; then
        log_error "Please provide code to evaluate"
        echo "Usage: st cuis eval '<code>'"
        return 1
    fi

    ensure_cuis_dir

    # Cuis has no built-in 'eval' command; use the documented headless mechanism:
    # <VM> -headless <image> -s <file.st>. The .st evaluates the code, prints the
    # result to stdout via StdIOWriteStream, and quits. (Previously this looked
    # for a nonexistent run_cuis.sh and errored with 'Cuis executable not found'.)
    local vm image
    vm=$(find_cuis_vm) || {
        log_error "Cuis VM not found in: $_CUIS_DIR"
        return 1
    }
    image=$(find_cuis_image) || {
        log_error "Cuis image not found in: $_CUIS_DIR"
        return 1
    }
    chmod +x "$vm" 2> /dev/null || true

    local script_file
    script_file="$(mktemp).st"
    {
        printf 'StdIOWriteStream nextPutAll: ([ '
        printf '%s' "$code"
        printf ' ] value printString); newLine.\nSmalltalk quit.\n'
    } > "$script_file"

    "$vm" -headless "$image" -s "$script_file"
    local rc=$?
    rm -f -- "$script_file"
    return $rc
}
