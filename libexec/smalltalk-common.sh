#!/usr/bin/env bash
#
# smalltalk-common.sh - Common utilities for all Smalltalk implementations
#
set -u
set -o pipefail

#################################
## Debug Mode Support
#################################

# Enable debug mode with DEBUG=1 environment variable
# This enables 'set -x' tracing for all scripts
if [[ "${DEBUG:-0}" == "1" ]]; then
    set -x
fi

#################################
## Common Environment Variables
#################################

# Get the directory where this script is located
CURRENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "${CURRENT_SCRIPT_DIR}/.." && pwd)"

# Cache directory
CACHE_DIR="${HOME}/.smalltalk-cache"
DEFAULT_IMAGE_NAME="Pharo.image"

# Manifest file for tracking installed artifacts
MANIFEST_FILE="${HOME}/.smalltalk-manifest.json"

# GitHub API rate limiting (requests per hour limit)
GITHUB_API_RATE_LIMIT=60
GITHUB_API_CACHE_DURATION=3600  # 1 hour in seconds

#################################
## Temp File Cleanup
#################################

# Global arrays to track temp files for cleanup
declare -a _TEMP_FILES=()
declare -a _TEMP_DIRS=()

# Cleanup function registered with trap
_cleanup_temp_resources() {
    local i
    for (( i=${#_TEMP_FILES[@]}-1; i>=0; i-- )); do
        rm -f "${_TEMP_FILES[$i]}" 2>/dev/null || true
    done
    for (( i=${#_TEMP_DIRS[@]}-1; i>=0; i-- )); do
        rm -rf "${_TEMP_DIRS[$i]}" 2>/dev/null || true
    done
}

# Register cleanup trap
trap _cleanup_temp_resources EXIT INT TERM

# Create a temp file and register it for cleanup
make_temp_file() {
    local prefix="${1:-st}"
    local tmpfile
    tmpfile=$(mktemp "${TMPDIR:-/tmp}/${prefix}.XXXXXX" 2>/dev/null) || return 1
    _TEMP_FILES+=("$tmpfile")
    echo "$tmpfile"
}

# Create a temp directory and register it for cleanup
make_temp_dir() {
    local prefix="${1:-st}"
    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX" 2>/dev/null) || return 1
    _TEMP_DIRS+=("$tmpdir")
    echo "$tmpdir"
}

#################################
## Security Functions
#################################

# Validate path to prevent path traversal attacks
validate_path() {
    local path="$1"
    local allowed_prefix="${2:-}"
    
    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        return 1
    fi
    
    # Check for path traversal attempts
    case "$path" in
        ..|../*|*/../*|*/..)
            return 1
            ;;
    esac
    
    # Check if path starts with allowed prefix (if specified)
    if [[ -n "$allowed_prefix" ]]; then
        local abs_path abs_prefix
        abs_path=$(cd "$path" 2>/dev/null && pwd || echo "$path")
        abs_prefix=$(cd "$allowed_prefix" 2>/dev/null && pwd || echo "$allowed_prefix")
        if [[ "$abs_path" != "$abs_prefix"* ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Validate package name (alphanumeric, dash, underscore, dot, forward slash only)
validate_package_name() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        return 1
    fi
    
    # Block overly long names
    if [[ ${#name} -gt 255 ]]; then
        return 1
    fi
    
    # Allow: alphanumeric, dash, underscore, dot, forward slash (for owner/repo)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate URL (basic check for security)
validate_url() {
    local url="$1"
    
    # Must start with http:// or https://
    if [[ ! "$url" =~ ^https?:// ]]; then
        return 1
    fi
    
    # Block file:// and other dangerous protocols
    case "$url" in
        file://*|ftp://*|javascript:*)
            return 1
            ;;
    esac
    
    return 0
}

# Sanitize input for safe use in shell commands
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters
    echo "$input" | tr -cd '[:alnum:]._/-@:' | head -c 255
}

#################################
## Debug Functions
#################################

# Enable debug mode - activates 'set -x' tracing
enable_debug() {
    export DEBUG=1
    set -x
}

# Disable debug mode
disable_debug() {
    export DEBUG=0
    set +x 2>/dev/null || true
}

#################################
## Manifest Functions
#################################

# Initialize manifest file
init_manifest() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        echo '{}' > "$MANIFEST_FILE"
    fi
}

# Add entry to manifest
manifest_add() {
    local impl="$1"
    local install_dir="$2"
    shift 2
    local files=("$@")

    init_manifest

    # Create a temporary file for the new manifest
    local temp_file
    temp_file=$(make_temp_file manifest) || return 1

    # Read existing manifest and add new entry
    local impl_escaped
    impl_escaped=$(echo "$impl" | sed 's/"/\\"/g')
    local dir_escaped
    dir_escaped=$(echo "$install_dir" | sed 's/"/\\"/g')

    # Use jq to add to manifest if available, otherwise use sed
    if cmd_exists jq; then
        local files_json="[]"
        for file in "${files[@]}"; do
            local file_escaped
            file_escaped=$(echo "$file" | sed 's/"/\\"/g')
            files_json=$(echo "$files_json" | jq --arg f "$file_escaped" '. += [$f]')
        done

        jq --arg impl "$impl_escaped" \
           --arg dir "$dir_escaped" \
           --argjson files "$files_json" \
           '.[$impl] = {"install_dir": $dir, "files": $files, "timestamp": now}' \
           "$MANIFEST_FILE" > "$temp_file" && mv "$temp_file" "$MANIFEST_FILE"
    else
        # Fallback: just store the install directory
        sed -i.bak "s/\"$impl_escaped\":/\"$impl_escaped\":{\"install_dir\":\"$dir_escaped\"/" "$MANIFEST_FILE" 2>/dev/null || true
    fi
}

# Get install directory for implementation from manifest
manifest_get_dir() {
    local impl="$1"

    init_manifest

    if cmd_exists jq; then
        jq -r ".\"$impl\".install_dir // empty" "$MANIFEST_FILE" 2>/dev/null || true
    fi
}

# Get files for implementation from manifest
manifest_get_files() {
    local impl="$1"

    init_manifest

    if cmd_exists jq; then
        jq -r ".\"$impl\".files[] // empty" "$MANIFEST_FILE" 2>/dev/null || true
    fi
}

# Remove implementation from manifest
manifest_remove() {
    local impl="$1"

    init_manifest

    if cmd_exists jq; then
        local temp_file
        temp_file=$(make_temp_file manifest) || return 1
        jq "del(.\"$impl\")" "$MANIFEST_FILE" > "$temp_file" && mv "$temp_file" "$MANIFEST_FILE"
    fi
}

# Clean artifacts for a specific implementation
clean_impl_artifacts() {
    local impl="$1"
    local impl_dir="${2:-.}"

    log_info "Cleaning artifacts for $impl in $impl_dir..."

    local files
    files=$(manifest_get_files "$impl")

    if [[ -n "$files" ]]; then
        while IFS= read -r file; do
            if [[ -n "$file" && -e "$file" ]]; then
                rm -rf "$file"
                log_debug "Removed: $file"
            fi
        done <<< "$files"
    fi

    log_success "Artifacts cleaned for $impl"
}

# Clean all artifacts for all implementations
clean_all_artifacts() {
    log_info "Cleaning all Smalltalk artifacts..."

    init_manifest

    if cmd_exists jq; then
        local impls
        impls=$(jq -r 'keys[]' "$MANIFEST_FILE" 2>/dev/null)

        if [[ -n "$impls" ]]; then
            while IFS= read -r impl; do
                clean_impl_artifacts "$impl" "$(manifest_get_dir "$impl")"
            done <<< "$impls"
        fi
    fi

    # Also clean up common artifact patterns using glob (faster than find)
    # Enable nullglob to handle non-matching patterns gracefully
    local old_nullglob
    if [[ $- == *f* ]]; then old_nullglob=true; else old_nullglob=false; fi
    shopt -s nullglob

    local files_to_clean=(
        Pharo*.image Pharo*.changes Pharo*.sources
        pharo-vm pharo-ui pharo
        Pharo.app Pharo*.app
        GlamorousToolkit GlamorousToolkit*.app GlamorousToolkit*.image
        Cuis*.image Cuis*.changes Cuis.app
        Squeak*.image Squeak*.changes Squeak*.app
        lst3r *.fuel
    )

    # Only remove files that exist in current directory
    for f in "${files_to_clean[@]}"; do
        if [[ -e "$f" ]]; then
            rm -rf "$f" 2>/dev/null || true
        fi
    done

    # Handle .st files separately (they're common but we don't want to remove all)
    # Only remove if it's clearly a Smalltalk script file name pattern
    for f in *.st; do
        if [[ -f "$f" && "$f" =~ ^(script|load|run|test).*\.st$ ]]; then
            rm -f "$f" 2>/dev/null || true
        fi
    done

    # Restore nullglob setting
    if ! $old_nullglob; then shopt -u nullglob; fi

    log_success "All artifacts cleaned"
}

#################################
## Common Helper Functions
#################################

# Logging functions
#################################
## Logging & Colors
#################################

# Color codes (disabled if NO_COLOR is set)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    COLOR_INFO='\033[1;33m'    # Bold yellow
    COLOR_ERROR='\033[1;31m'   # Bold red
    COLOR_SUCCESS='\033[1;32m' # Bold green
    COLOR_WARN='\033[1;35m'    # Bold magenta
    COLOR_DEBUG='\033[0;36m'    # Cyan
    COLOR_RESET='\033[0m'
else
    COLOR_INFO=''
    COLOR_ERROR=''
    COLOR_SUCCESS=''
    COLOR_WARN=''
    COLOR_DEBUG=''
    COLOR_RESET=''
fi

log_info() {
    printf "${COLOR_INFO}[INFO] %s${COLOR_RESET}\n" "$*"
}

log_error() {
    printf "${COLOR_ERROR}[ERROR] %s${COLOR_RESET}\n" "$*" >&2
}

log_success() {
    printf "${COLOR_SUCCESS}[SUCCESS] %s${COLOR_RESET}\n" "$*"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        printf "${COLOR_DEBUG}[DEBUG] %s${COLOR_RESET}\n" "$*"
    fi
}

log_warn() {
    printf "${COLOR_WARN}[WARN] %s${COLOR_RESET}\n" "$*"
}

# Print error and exit
die() {
    log_error "$*"
    exit 1
}

# Get the directory containing the script (resolves symlinks)
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        source=$(readlink "$source")
    done
    echo "$(cd "$(dirname "$source")" && pwd)"
}

# Load help text from a markdown file in doc/ directory
load_help_from_doc() {
    local impl_name="$1"  # e.g., "pharo", "squeak", "cuis"
    local doc_dir
    
    # Get the libexec directory and go up to project root
    local libexec_dir
    libexec_dir=$(get_script_dir)
    local project_root
    project_root=$(cd "${libexec_dir}/.." && pwd)
    
    local help_file="${project_root}/doc/HELP_${impl_name}.md"
    
    if [[ -f "$help_file" ]]; then
        cat "$help_file"
    else
        # Fallback error message
        printf "Help file not found: %s\n" "$help_file" >&2
        return 1
    fi
}

# Check if a command exists
cmd_exists() {
    type -- "$1" &>/dev/null
    return $?
}

# Ensure cache directory exists
ensure_cache_dir() {
    if [[ ! -d "${CACHE_DIR}" ]]; then
        mkdir -p "${CACHE_DIR}"
    fi
}

# Clean cache directory
clean_cache() {
    if [[ -d "${CACHE_DIR}" ]]; then
        rm -rf "${CACHE_DIR:?}"/*
        log_info "Cache directory cleaned"
    else
        log_info "Cache directory does not exist"
    fi
}

# Clean cache directory for specific implementation
clean_impl_cache() {
    local impl="$1"
    local impl_cache_dir="${CACHE_DIR}/${impl}"

    if [[ -d "${impl_cache_dir}" ]]; then
        rm -rf "${impl_cache_dir:?}"/*
        log_info "${impl} cache cleaned"
    else
        log_info "${impl} cache directory does not exist"
    fi
}

# Get OS type
get_os() {
    local os_type
    case "$(uname -s)" in
        Linux*)     os_type="linux" ;;
        Darwin*)    os_type="macos" ;;
        MINGW*|MSYS*) os_type="windows" ;;
        *)          os_type="unknown" ;;
    esac
    echo "$os_type"
}

# Get architecture
get_arch() {
    local arch
    case "$(uname -m)" in
        x86_64)     arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l)     arch="arm" ;;
        i386|i686)  arch="x86" ;;
        *)          arch="unknown" ;;
    esac
    echo "$arch"
}

# Download file using curl or wget with progress bar
download_file() {
    local url="$1"
    local output="$2"

    if cmd_exists curl; then
        # -#: progress bar, -L: follow redirects, -C: resume support
        curl -# -L -C - -o "$output" "$url"
    elif cmd_exists wget; then
        # --progress=bar:dot: progress bar, -c: continue (resume)
        wget --progress=bar:dot -c -O "$output" "$url"
    else
        die "Neither curl nor wget is installed"
    fi
}

# Extract archive (zip, tar.gz, tar.xz)
extract_archive() {
    local archive="$1"
    local dest_dir="${2:-.}"

    case "$archive" in
        *.zip)
            unzip -o "$archive" -d "$dest_dir"
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$dest_dir"
            ;;
        *.tar.xz)
            tar -xJf "$archive" -C "$dest_dir"
            ;;
        *)
            die "Unsupported archive format: $archive"
            ;;
    esac
}

# Run command with optional loading animation
run_with_animation() {
    local cmd="$1"
    local message="${2:-Running...}"
    local result

    log_info "$message"
    if eval "$cmd"; then
        return 0
    else
        return 1
    fi
}

# Prompt for confirmation
confirm() {
    local prompt="${1:-Are you sure?}"
    local response

    read -p "$prompt [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if directory contains a Smalltalk installation
detect_existing_smalltalk() {
    local dir="$1"

    # Pharo detection
    if [[ -f "${dir}/Pharo.image" ]] && [[ -f "${dir}/Pharo.changes" ]]; then
        echo "pharo"
        return 0
    fi

    # GT detection
    if [[ -d "${dir}/GlamorousToolkit.app" ]] || [[ -f "${dir}/GlamorousToolkit.image" ]]; then
        echo "gt"
        return 0
    fi

    # Cuis detection
    if [[ -f "${dir}/Cuis.image" ]] && [[ -f "${dir}/Cuis.changes" ]]; then
        echo "cuis"
        return 0
    fi

    # Squeak detection
    if [[ -f "${dir}/Squeak.image" ]] && [[ -f "${dir}/Squeak.changes" ]]; then
        echo "squeak"
        return 0
    fi

    # LST detection
    if [[ -f "${dir}/lst3r" ]] || command -v lst3r &>/dev/null; then
        echo "lst"
        return 0
    fi

    return 1
}

#################################
## Package Listing Functions
## (Shared by Pharo, GT, Squeak, Cuis)
#################################

# List packages for an implementation that uses GitHub with topics
list_monticello_packages() {
    local impl="${1:-pharo}"
    local topic="${2:-$impl}"
    local cache_file="${CACHE_DIR}/${impl}/packages.json"

    ensure_cache_dir
    mkdir -p "${CACHE_DIR}/${impl}"

    if [[ -f "$cache_file" ]]; then
        if cmd_exists jq; then
            jq -r '.items[] | "\(.full_name) | \(.description // "N/A")"' "$cache_file"
        else
            log_error "jq is required for package listing"
            return 1
        fi
    else
        log_info "No cached packages. Run 'smalltalk $impl update' first."
        return 1
    fi
}

# Update package cache for GitHub-based implementations
# Includes rate limiting and caching for GitHub API
update_monticello_packages() {
    local impl="${1:-pharo}"
    local topic="${2:-$impl}"
    local cache_file="${CACHE_DIR}/${impl}/packages.json"
    local rate_limit_file="${CACHE_DIR}/github_rate_limit"

    ensure_cache_dir
    mkdir -p "${CACHE_DIR}/${impl}"

    # Check GitHub API rate limit to avoid being blocked
    if [[ -f "$rate_limit_file" ]]; then
        local last_call=0
        last_call=$(cat "$rate_limit_file" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local min_interval=1  # Minimum 1 second between API calls
        
        if [[ $((now - last_call)) -lt $min_interval ]]; then
            log_debug "Rate limiting: waiting $((min_interval - (now - last_call))) seconds..."
            sleep $((min_interval - (now - last_call)))
        fi
    fi

    log_info "Updating ${impl} package cache..."

    local api_url="https://api.github.com/search/repositories?q=topic:${topic}&per_page=100"
    
    # Record the API call timestamp
    date +%s > "$rate_limit_file"
    
    download_file "$api_url" "$cache_file"

    if [[ -f "$cache_file" ]]; then
        # Check if we got an error response
        if cmd_exists jq; then
            local errors
            errors=$(jq '.errors // [] | length' "$cache_file" 2>/dev/null || echo 0)
            if [[ "$errors" -gt 0 ]]; then
                log_error "GitHub API returned errors"
                jq '.errors[]?.message' "$cache_file" 2>/dev/null
                return 1
            fi
            
            local rate_remaining
            rate_remaining=$(jq '.response.headers."X-RateLimit-Remaining" // "unknown"' "$cache_file" 2>/dev/null || echo "unknown")
            if [[ "$rate_remaining" == "0" ]]; then
                log_warn "GitHub API rate limit reached"
            fi
        fi
        log_success "Package cache updated"
    else
        log_error "Failed to update cache"
        return 1
    fi
}

#################################
## Clap Command Line Handler
## Available in: Pharo, GT (confirmed)
## May be available in: Squeak, Cuis
#################################

# Check if an image has Clap support
check_clap_available() {
    local image_path="${1:-.}"

    if [[ ! -f "${image_path}/pharo" ]] && [[ ! -f "${image_path}/Pharo.image" ]]; then
        return 1
    fi

    # Try to get Clap version
    local version_output
    version_output=$("${image_path}/pharo" "${image_path}/Pharo.image" eval --save "SpEnvironment current versionString" 2>/dev/null || true)

    [[ -n "$version_output" ]]
}

# Run a Clap command on an image
run_clap() {
    local image_path="${1:-.}"
    shift
    local clap_args="$@"

    local pharo_cmd="./pharo"
    local image_name="Pharo.image"

    if [[ -f "${image_path}/Pharo.image" ]]; then
        image_path="."
    fi

    if [[ ! -f "${image_path}/Pharo.image" ]]; then
        die "Pharo image not found in ${image_path}"
    fi

    "$pharo_cmd" "${image_path}/${image_name}" "$clap_args"
}

#################################
## Metacello Command Handler
## (Pharo, GT, Squeak use Metacello)
#################################

# Install a package using Metacello
install_metacello_package() {
    local package_spec="$1"
    local image_path="${2:-.}"

    if [[ ! -f "${image_path}/Pharo.image" ]]; then
        die "Pharo image not found in ${image_path}"
    fi

    log_info "Installing package: $package_spec"

    "./pharo" "${image_path}/Pharo.image" metacello install "$package_spec" --save
}

# Run Metacello baseline
install_metacello_baseline() {
    local baseline_spec="$1"
    local image_path="${2:-.}"

    if [[ ! -f "${image_path}/Pharo.image" ]]; then
        die "Pharo image not found in ${image_path}"
    fi

    log_info "Installing baseline: $baseline_spec"

    "./pharo" "${image_path}/Pharo.image" metacello install baseline "$baseline_spec" --save
}

#################################
## Common Image Commands
#################################

# Get image version
get_image_version() {
    local image_path="${1:-.}"

    if [[ -f "${image_path}/Pharo.image" ]]; then
        if [[ -f "${image_path}/pharo" ]]; then
            "./pharo" "${image_path}/Pharo.image" eval --save "Smalltalk version" 2>/dev/null || echo "unknown"
        else
            echo "unknown"
        fi
    else
        echo "not installed"
    fi
}

# Save the image
save_image() {
    local image_path="${1:-.}"

    if [[ ! -f "${image_path}/Pharo.image" ]]; then
        die "Image not found in ${image_path}"
    fi

    log_info "Saving image..."
    "./pharo" "${image_path}/Pharo.image" save 2>/dev/null || true
}

# Evaluate Smalltalk code
eval_code() {
    local code="$1"
    local image_path="${2:-.}"

    if [[ ! -f "${image_path}/Pharo.image" ]]; then
        die "Image not found in ${image_path}"
    fi

    "./pharo" "${image_path}/Pharo.image" eval --save "$code"
}

# Ensure directory exists and is writable
ensure_install_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi

    if [[ ! -w "$dir" ]]; then
        die "Directory is not writable: $dir"
    fi
}

# Generate a timestamped installation directory name
get_timestamped_dir() {
    local impl_name="$1"
    local version="${2:-unknown}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    echo "${impl_name}-${version}_${timestamp}"
}

# Ensure installation goes to a timestamped directory if no destination specified
resolve_install_dir() {
    local specified_dir="$1"
    local impl_name="$2"
    local version="${3:-unknown}"
    
    if [[ "$specified_dir" == "." ]]; then
        local new_dir
        new_dir=$(get_timestamped_dir "$impl_name" "$version")
        log_info "No destination specified. Creating directory: $new_dir"
        ensure_install_dir "$new_dir"
        echo "$new_dir"
    else
        ensure_install_dir "$specified_dir"
        echo "$specified_dir"
    fi
}

# Register installed files to manifest
register_install() {
    local impl="$1"
    local install_dir="$2"
    shift 2
    local files=("$@")

    manifest_add "$impl" "$install_dir" "${files[@]}"
    log_debug "Registered installation of $impl to manifest"
}
