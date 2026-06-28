#!/usr/bin/env bash
#
# smalltalk-gt.sh - Glamorous Toolkit implementation
#
set -Euo pipefail
IFS=$'\n\t'

# shellcheck source=libexec/smalltalk-common.sh
source "${BASH_SOURCE%/*}/smalltalk-common.sh"

#################################
## GT Configuration
#################################

GT_URL_BASE="https://dl.feenk.com"
GT_VERSION="${GT_VERSION:-latest}"
GT_CACHE_DIR="${CACHE_DIR}/gt"
GT_INSTALL_DIR="${GT_INSTALL_DIR:-.}"

#################################
## GT Helper Functions
#################################

# Set GT download URL based on OS and architecture
set_gt_url() {
    local os_type
    local arch

    os_type=$(get_os)
    arch=$(get_arch)

    case "$os_type" in
        macos)
            if [[ "$arch" == "arm64" ]]; then
                # macOS ARM64 (Apple Silicon M1/M2/M3)
                GT_URL="${GT_URL_BASE}/gt/GlamorousToolkitOSXM1-release.zip"
            else
                # macOS x86_64 (Intel)
                GT_URL="${GT_URL_BASE}/gt/GlamorousToolkit-x86_64-release.zip"
            fi
            ;;
        linux)
            if [[ "$arch" == "arm64" ]]; then
                # Linux ARM64
                GT_URL="${GT_URL_BASE}/gt/GlamorousToolkit-arm64-release.zip"
            else
                # Linux x86_64
                GT_URL="${GT_URL_BASE}/gt/GlamorousToolkit-x86_64-release.zip"
            fi
            ;;
        windows)
            GT_URL="${GT_URL_BASE}/gt/GlamorousToolkit-win-release.zip"
            ;;
        *)
            die "Unsupported OS: $os_type"
            ;;
    esac
}

# Get latest GT version from releases
get_latest_gt_version() {
    local api_url="https://api.github.com/repos/feenkcom/gtoolkit/releases/latest"
    local version

    version=$(download_file "$api_url" - 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 || echo "latest")
    echo "${version#v}"
}

# Check if GT is installed
is_gt_installed() {
    local search_dirs=("." "$HOME/gtoolkit" "$HOME/gt")

    for dir in "${search_dirs[@]}"; do
        if [[ -d "${dir}/GlamorousToolkit.app" ]] || [[ -f "${dir}/GlamorousToolkit.image" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Download GT
download_gt() {
    local version="${1:-$GT_VERSION}"
    local install_dir="${2:-.}"

    log_info "Downloading Glamorous Toolkit to ${install_dir}..."

    set_gt_url

    # Ensure install directory exists
    ensure_install_dir "$install_dir"
    mkdir -p "$install_dir"
    cd "$install_dir" || die "Cannot change to directory: $install_dir"
    install_dir="$(pwd)"

    local archive_file
    archive_file=$(mktemp)

    if download_file "$GT_URL" "$archive_file"; then
        case "$GT_URL" in
            *.zip)
                # Use bsdtar for better cross-platform zip handling (from libarchive)
                # Falls back to unzip if bsdtar is not available
                if cmd_exists bsdtar; then
                    local tar_v=""
                    [[ "${VERBOSE:-0}" == "1" ]] && tar_v="v"
                    bsdtar -x${tar_v}f "$archive_file"
                elif cmd_exists unzip; then
                    local unzip_flags="-q"
                    [[ "${VERBOSE:-0}" == "1" ]] && unzip_flags=""
                    unzip $unzip_flags -o "$archive_file"
                else
                    log_error "Neither bsdtar nor unzip is available"
                    rm -f -- "$archive_file"
                    return 1
                fi
                ;;
            *)
                mv "$archive_file" "GlamorousToolkit"
                chmod +x "GlamorousToolkit"
                ;;
        esac
    else
        log_error "Failed to download Glamorous Toolkit"
        rm -f -- "$archive_file"
        return 1
    fi

    rm -f -- "$archive_file"

    # Make the GlamorousToolkit executable if present
    if [[ -f "GlamorousToolkit.app/Contents/MacOS/GlamorousToolkit" ]]; then
        chmod 755 "GlamorousToolkit.app/Contents/MacOS/GlamorousToolkit"
    fi

    if is_gt_installed >/dev/null; then
        log_success "Glamorous Toolkit installed successfully to ${install_dir}"

        # Register installed files
        local gt_files=()
        for f in GlamorousToolkit GlamorousToolkit.app GlamorousToolkit.image GlamorousToolkit.changes pharo; do
            if [[ -e "$f" ]]; then
                gt_files+=("$(pwd)/$f")
            fi
        done
        register_install "gt" "$(pwd)" "${gt_files[@]}"
    else
        die "Glamorous Toolkit installation failed"
    fi
}

# Run GT
run_gt() {
    local gt_dir
    gt_dir=$(is_gt_installed) || {
        log_info "GT not found, installing..."
        download_gt
        gt_dir="."
    }

    cd "$gt_dir" || die "Cannot change to GT directory"

    if [[ -d "./GlamorousToolkit.app" ]]; then
        open ./GlamorousToolkit.app
    elif [[ -f "./GlamorousToolkit" ]]; then
        chmod +x ./GlamorousToolkit
        ./GlamorousToolkit &
    else
        die "Cannot find Glamorous Toolkit executable"
    fi
}

#################################
## Command Handlers
#################################

smalltalk_gt_help() {
    load_help_from_doc "gt"
}


smalltalk_gt_install() {
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
                echo "Usage: st gt install [-d <dir>]"
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
        if [[ -n "$existing" && "$existing" != "gt" ]]; then
            log_error "Directory $install_dir already contains a $existing installation"
            log_error "Use a different directory or remove the existing installation first"
            return 1
        fi
    fi

    # If no destination directory specified, create timestamped subdirectory
    if [[ "$install_dir" == "." ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        install_dir="GlamorousToolkit_${timestamp}"
        log_info "No destination specified. Creating directory: $install_dir"
        mkdir -p "$install_dir"
    fi

    download_gt "$GT_VERSION" "$install_dir"
}

smalltalk_gt_run() {
    local target_dir=""
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                target_dir="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    local gt_dir
    
    # If target directory specified, use it; otherwise search for existing GT
    if [[ -n "$target_dir" ]]; then
        gt_dir="$target_dir"
    else
        gt_dir=$(is_gt_installed) || {
            log_info "GT not found, installing..."
            # Create timestamped directory if no -d specified
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            gt_dir="GlamorousToolkit_${timestamp}"
            log_info "Creating directory: $gt_dir"
            mkdir -p "$gt_dir"
            cd "$gt_dir" || die "Cannot create directory: $gt_dir"
            download_gt "$GT_VERSION" "."
            gt_dir="$(pwd)"
            log_success "GT installed to: $gt_dir"
        }
    fi
    
    cd "$gt_dir" || die "Cannot change to GT directory: $gt_dir"

    # Launch the GT UI
    run_gt
}

smalltalk_gt_search() {
    local search_term="${1:-}"

    if [[ -z "$search_term" ]]; then
        log_error "Please provide a search term"
        echo "Usage: st gt search <term>"
        exit 1
    fi

    log_info "Searching for packages matching '$search_term'..."

    local api_url="https://api.github.com/search/repositories?q=topic:gtoolkit+${search_term}&per_page=100"
    ensure_cache_dir
    local cache_file="${GT_CACHE_DIR}/search_${search_term// /_}.json"

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

smalltalk_gt_list() {
    list_monticello_packages "gt" "pharo"
}

smalltalk_gt_update() {
    update_monticello_packages "gt" "pharo"
}

smalltalk_gt_clean() {
    clean_impl_cache "gt"
}

smalltalk_gt_clean_artifacts() {
    log_info "Cleaning Glamorous Toolkit artifacts..."

    # Get install directory from manifest
    local impl_dir
    impl_dir=$(manifest_get_dir "gt")

    if [[ -n "$impl_dir" && -d "$impl_dir" ]]; then
        cd "$impl_dir" || return 1

        # Remove GT artifacts
        local patterns=(
            "GlamorousToolkit"
            "GlamorousToolkit.app"
            "GlamorousToolkit.image"
            "GlamorousToolkit.changes"
            "pharo"
        )

        for pattern in "${patterns[@]}"; do
            find . -maxdepth 1 -name "$pattern" -exec rm -rf -- {} \; 2>/dev/null || true
        done

        manifest_remove "gt"
        log_success "Glamorous Toolkit artifacts cleaned"
    else
        log_info "No registered GT installation found in manifest"
        log_info "To clean manually, remove GT files from your installation directory"
    fi
}

smalltalk_gt_versions() {
    log_info "Fetching available GT versions from GitHub releases..."
    
    local api_url="https://api.github.com/repos/feenkcom/gtoolkit/releases"
    local versions
    
    versions=$(curl -s "$api_url" 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sort -V -r || true)
    
    if [[ -z "$versions" ]]; then
        log_error "Failed to fetch versions from GitHub"
        return 1
    fi
    
    echo "Available Glamorous Toolkit versions:"
    echo "$versions" | while IFS= read -r version; do
        echo "  $version"
    done
}

smalltalk_gt_version() {
    local gt_dir
    gt_dir=$(is_gt_installed) || {
        echo "Glamorous Toolkit is not installed"
        return 1
    }

    cd "$gt_dir" || return 1

    # Try different ways to get version
    local gt_cli="${gt_dir}/GlamorousToolkit.app/Contents/MacOS/GlamorousToolkit-cli"
    local gt_app="${gt_dir}/GlamorousToolkit.app/Contents/MacOS/GlamorousToolkit"
    local gt_image="${gt_dir}/GlamorousToolkit.image"

    if [[ -f "$gt_cli" ]]; then
        "$gt_cli" --version 2>/dev/null && return
    fi

    if [[ -f "$gt_app" ]]; then
        "$gt_app" --version 2>/dev/null && return
    fi

    if [[ -f "${gt_dir}/GlamorousToolkit" ]]; then
        "${gt_dir}/GlamorousToolkit" --version 2>/dev/null && return
    fi

    if [[ -f "${gt_dir}/pharo" ]]; then
        "${gt_dir}/pharo" "$gt_image" eval --save "Smalltalk version" 2>/dev/null && return
    fi

    echo "Glamorous Toolkit version unknown (files found but version command failed)"
}

smalltalk_gt_eval() {
    local code="$*"
    
    if [[ -z "$code" ]]; then
        log_error "Please provide code to evaluate"
        echo "Usage: st gt eval '<code>'"
        return 1
    fi
    
    local gt_dir
    gt_dir=$(is_gt_installed) || {
        log_error "Glamorous Toolkit is not installed"
        log_error "Run 'st gt install' first"
        return 1
    }
    
    cd "$gt_dir" || return 1
    
    local gt_image="${gt_dir}/GlamorousToolkit.image"
    local gt_executable="${gt_dir}/GlamorousToolkit"
    
    # Fallback to pharo executable if GT executable doesn't exist
    if [[ -f "${gt_dir}/pharo" ]]; then
        gt_executable="${gt_dir}/pharo"
    fi
    
    if [[ -f "$gt_executable" ]]; then
        "$gt_executable" --headless "$gt_image" eval "$code"
    else
        log_error "GT executable not found in: $gt_dir"
        return 1
    fi
}

# Load a Metacello baseline/configuration
smalltalk_gt_metacello() {
    if [[ $# -eq 0 ]]; then
        log_error "Please provide a Metacello baseline specification"
        echo "Usage: st gt metacello <repo-url> <baseline-name>"
        return 1
    fi
    
    local gt_dir
    gt_dir=$(is_gt_installed) || {
        log_error "Glamorous Toolkit is not installed"
        log_error "Run 'st gt install' first"
        return 1
    }
    
    cd "$gt_dir" || return 1
    
    local gt_image="${gt_dir}/GlamorousToolkit.image"
    local gt_executable="${gt_dir}/GlamorousToolkit"
    
    if [[ -f "${gt_dir}/pharo" ]]; then
        gt_executable="${gt_dir}/pharo"
    fi
    
    if [[ -f "$gt_executable" ]]; then
        "$gt_executable" --headless "$gt_image" metacello "$@" --save
    else
        log_error "GT executable not found"
        return 1
    fi
}

# Load and execute a .st source file
smalltalk_gt_load() {
    local st_file="${1:-}"
    
    if [[ -z "$st_file" ]]; then
        log_error "Please provide a .st file to load"
        echo "Usage: st gt load <file.st>"
        return 1
    fi
    
    local gt_dir
    gt_dir=$(is_gt_installed) || {
        log_error "Glamorous Toolkit is not installed"
        log_error "Run 'st gt install' first"
        return 1
    }
    
    cd "$gt_dir" || return 1
    
    local gt_image="${gt_dir}/GlamorousToolkit.image"
    local gt_executable="${gt_dir}/GlamorousToolkit"
    
    if [[ -f "${gt_dir}/pharo" ]]; then
        gt_executable="${gt_dir}/pharo"
    fi
    
    if [[ -f "$gt_executable" ]]; then
        "$gt_executable" --headless "$gt_image" load "$st_file"
    else
        log_error "GT executable not found"
        return 1
    fi
}

# Save the GT image
smalltalk_gt_save() {
    local save_name="${1:-}"
    
    local gt_dir
    gt_dir=$(is_gt_installed) || {
        log_error "Glamorous Toolkit is not installed"
        log_error "Run 'st gt install' first"
        return 1
    }
    
    cd "$gt_dir" || return 1
    
    local gt_image="${gt_dir}/GlamorousToolkit.image"
    local gt_executable="${gt_dir}/GlamorousToolkit"
    
    if [[ -f "${gt_dir}/pharo" ]]; then
        gt_executable="${gt_dir}/pharo"
    fi
    
    if [[ -f "$gt_executable" ]]; then
        if [[ -z "$save_name" ]]; then
            "$gt_executable" --headless "$gt_image" save
        else
            "$gt_executable" --headless "$gt_image" save "$save_name"
        fi
    else
        log_error "GT executable not found"
        return 1
    fi
}
