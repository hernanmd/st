#!/usr/bin/env bash
#
# smalltalk-common.sh - Common utilities for all Smalltalk implementations
#
# Provides: logging, platform detection, download/extraction, security,
#           manifest tracking, temp file management, and package listing.
#
# Exit codes:
#   0 - Success
#   1 - General error
#
# Environment variables:
#   DEBUG     - Set to 1 to enable debug tracing
#   QUIET     - Set to 1 to suppress all output
#   VERBOSE   - Set to 1 for verbose output
#   NO_COLOR  - Set to any value to disable colored output
#   CACHE_DIR - Override default cache directory
#
set -Euo pipefail

# Prevent word splitting on spaces
IFS=$'\n\t'

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

# Get the directory where this script is located (resolves symlinks)
CURRENT_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT_DIR="$(cd -- "${CURRENT_SCRIPT_DIR}/.." && pwd -P)"

# Cache directory
CACHE_DIR="${CACHE_DIR:-${HOME}/.smalltalk-cache}"
DEFAULT_IMAGE_NAME="Pharo.image"

# Manifest file for tracking installed artifacts
MANIFEST_FILE="${MANIFEST_FILE:-${HOME}/.smalltalk-manifest.json}"

# GitHub API rate limiting (requests per hour limit)
GITHUB_API_RATE_LIMIT=${GITHUB_API_RATE_LIMIT:-60}
GITHUB_API_CACHE_DURATION=${GITHUB_API_CACHE_DURATION:-3600}  # 1 hour in seconds

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_UNSUPPORTED=2

#################################
## Temp File Cleanup
#################################

# Global arrays to track temp files for cleanup
declare -a _TEMP_FILES=()
declare -a _TEMP_DIRS=()

# Cleanup function registered with trap
_cleanup_temp_resources() {
    local i
    for ((i = ${#_TEMP_FILES[@]} - 1; i >= 0; i--)); do
        rm -f -- "${_TEMP_FILES[$i]}" 2> /dev/null || true
    done
    for ((i = ${#_TEMP_DIRS[@]} - 1; i >= 0; i--)); do
        rm -rf -- "${_TEMP_DIRS[$i]}" 2> /dev/null || true
    done
}

# Register cleanup trap
trap _cleanup_temp_resources EXIT INT TERM

# Create a temp file and register it for cleanup
# Arguments:
#   $1 - prefix for the temp file name (default: "st")
# Returns:
#   Path to the created temp file on stdout
make_temp_file() {
    local prefix="${1:-st}"
    local tmpfile
    tmpfile="$(mktemp "${TMPDIR:-/tmp}/${prefix}.XXXXXX" 2> /dev/null)" || return 1
    _TEMP_FILES+=("$tmpfile")
    printf '%s' "$tmpfile"
}

# Create a temp directory and register it for cleanup
# Arguments:
#   $1 - prefix for the temp directory name (default: "st")
# Returns:
#   Path to the created temp directory on stdout
make_temp_dir() {
    local prefix="${1:-st}"
    local tmpdir
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX" 2> /dev/null)" || return 1
    _TEMP_DIRS+=("$tmpdir")
    printf '%s' "$tmpdir"
}

#################################
## Security Functions
#################################

# Validate path to prevent path traversal attacks
# Arguments:
#   $1 - path to validate
#   $2 - optional allowed prefix (if set, path must be under this prefix)
# Returns:
#   0 on success, 1 on validation failure
validate_path() {
    local path="$1"
    local allowed_prefix="${2:-}"

    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        return 1
    fi

    # Check for path traversal attempts
    case "$path" in
        .. | ../* | */../* | */..)
            return 1
            ;;
    esac

    # Check if path starts with allowed prefix (if specified)
    if [[ -n "$allowed_prefix" ]]; then
        local abs_path abs_prefix
        abs_path="$(cd -- "$path" 2> /dev/null && pwd -P || printf '%s' "$path")"
        abs_prefix="$(cd -- "$allowed_prefix" 2> /dev/null && pwd -P || printf '%s' "$allowed_prefix")"
        if [[ "$abs_path" != "$abs_prefix"* ]]; then
            return 1
        fi
    fi

    return 0
}

# Validate package name (alphanumeric, dash, underscore, dot, forward slash only)
# Arguments:
#   $1 - package name to validate
# Returns:
#   0 on success, 1 on validation failure
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

# Validate URL (basic security check)
# Arguments:
#   $1 - URL to validate
# Returns:
#   0 on success, 1 on validation failure
validate_url() {
    local url="$1"

    # Must start with http:// or https://
    if [[ ! "$url" =~ ^https?:// ]]; then
        return 1
    fi

    # Block file:// and other dangerous protocols
    case "$url" in
        file://* | ftp://* | javascript:*)
            return 1
            ;;
    esac

    return 0
}

# Sanitize input for safe use in shell commands
# Arguments:
#   $1 - input string to sanitize
# Returns:
#   Sanitized string on stdout (max 255 chars, alphanumeric + safe chars)
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters
    printf '%s' "$input" | tr -cd '[:alnum:]._/-@:' | head -c 255
}

#################################
## Debug Functions
###################################

# Enable debug mode - activates 'set -x' tracing
enable_debug() {
    export DEBUG=1
    set -x
}

# Disable debug mode
disable_debug() {
    export DEBUG=0
    set +x 2> /dev/null || true
}

#################################
## Manifest Functions
#################################

# Initialize manifest file
init_manifest() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        printf '{}' > "$MANIFEST_FILE"
    fi
}

# Add entry to manifest
# Arguments:
#   $1 - implementation name (e.g., "pharo", "gt")
#   $2 - installation directory path
#   $@ - remaining args: list of installed file paths
manifest_add() {
    local impl="$1"
    local install_dir="$2"
    shift 2
    local files=("$@")

    init_manifest

    # Create a temporary file for the new manifest
    local temp_file
    temp_file="$(make_temp_file manifest)" || return 1

    # Read existing manifest and add new entry
    local impl_escaped
    impl_escaped="$(printf '%s' "$impl" | sed 's/"/\\"/g')"
    local dir_escaped
    dir_escaped="$(printf '%s' "$install_dir" | sed 's/"/\\"/g')"

    # Use jq to add to manifest if available, otherwise use sed
    if cmd_exists jq; then
        local files_json="[]"
        for file in "${files[@]}"; do
            local file_escaped
            file_escaped="$(printf '%s' "$file" | sed 's/"/\\"/g')"
            files_json="$(printf '%s' "$files_json" | jq --arg f "$file_escaped" '. += [$f]')"
        done

        jq --arg impl "$impl_escaped" \
            --arg dir "$dir_escaped" \
            --argjson files "$files_json" \
            '.[$impl] = {"install_dir": $dir, "files": $files, "timestamp": now}' \
            "$MANIFEST_FILE" > "$temp_file" && mv -- "$temp_file" "$MANIFEST_FILE"
    else
        # Fallback: just store the install directory
        sed -i.bak "s/\"$impl_escaped\":/\"$impl_escaped\":{\"install_dir\":\"$dir_escaped\"/" "$MANIFEST_FILE" 2> /dev/null || true
    fi
}

# Get install directory for implementation from manifest
# Arguments:
#   $1 - implementation name
# Returns:
#   Install directory path on stdout (empty if not found)
manifest_get_dir() {
    local impl="$1"

    init_manifest

    if cmd_exists jq; then
        jq -r --arg impl "$impl" '.[$impl].install_dir // empty' "$MANIFEST_FILE" 2> /dev/null || true
    fi
}

# Get files for implementation from manifest
# Arguments:
#   $1 - implementation name
# Returns:
#   List of file paths on stdout
manifest_get_files() {
    local impl="$1"

    init_manifest

    if cmd_exists jq; then
        jq -r --arg impl "$impl" '.[$impl].files[] // empty' "$MANIFEST_FILE" 2> /dev/null || true
    fi
}

# Remove implementation from manifest
# Arguments:
#   $1 - implementation name
manifest_remove() {
    local impl="$1"

    init_manifest

    if cmd_exists jq; then
        local temp_file
        temp_file="$(make_temp_file manifest)" || return 1
        jq --arg impl "$impl" 'del(.[$impl])' "$MANIFEST_FILE" > "$temp_file" && mv -- "$temp_file" "$MANIFEST_FILE"
    fi
}

# Clean artifacts for a specific implementation
# Arguments:
#   $1 - implementation name
#   $2 - installation directory path
clean_impl_artifacts() {
    local impl="$1"
    local impl_dir="${2:-.}"

    log_info "Cleaning artifacts for $impl in $impl_dir..."

    local files
    files="$(manifest_get_files "$impl")"

    if [[ -n "$files" ]]; then
        while IFS= read -r file; do
            if [[ -n "$file" && -e "$file" ]]; then
                rm -rf -- "$file"
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
        impls="$(jq -r 'keys[]' "$MANIFEST_FILE" 2> /dev/null)"

        if [[ -n "$impls" ]]; then
            while IFS= read -r impl; do
                clean_impl_artifacts "$impl" "$(manifest_get_dir "$impl")"
            done <<< "$impls"
        fi
    fi

    # Also clean up common artifact patterns using glob
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
            rm -rf -- "$f" 2> /dev/null || true
        fi
    done

    # Handle .st files separately (they're common but we don't want to remove all)
    # Only remove if it's clearly a Smalltalk script file name pattern
    for f in *.st; do
        if [[ -f "$f" && "$f" =~ ^(script|load|run|test).*\.st$ ]]; then
            rm -f -- "$f" 2> /dev/null || true
        fi
    done

    # Restore nullglob setting
    if ! $old_nullglob; then shopt -u nullglob; fi

    log_success "All artifacts cleaned"
}

#################################
## Common Helper Functions
#################################

#################################
## Logging & Colors
#################################

# Color codes (disabled if NO_COLOR is set or output is not a terminal)
# Note: Use conditional assignment instead of readonly to allow re-sourcing
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    COLOR_INFO='\033[1;33m'    # Bold yellow
    COLOR_ERROR='\033[1;31m'   # Bold red
    COLOR_SUCCESS='\033[1;32m'  # Bold green
    COLOR_WARN='\033[1;35m'     # Bold magenta
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

# Log informational message
# Arguments: message string(s)
log_info() {
    if [[ "${QUIET:-0}" != "1" ]]; then
        printf "${COLOR_INFO}[INFO] %s${COLOR_RESET}\n" "$*"
    fi
}

# Log error message to stderr
# Arguments: message string(s)
log_error() {
    if [[ "${QUIET:-0}" != "1" ]]; then
        printf "${COLOR_ERROR}[ERROR] %s${COLOR_RESET}\n" "$*" >&2
    fi
}

# Log success message
# Arguments: message string(s)
log_success() {
    if [[ "${QUIET:-0}" != "1" ]]; then
        printf "${COLOR_SUCCESS}[SUCCESS] %s${COLOR_RESET}\n" "$*"
    fi
}

# Log debug message (only if DEBUG=1)
# Arguments: message string(s)
log_debug() {
    if [[ "${DEBUG:-0}" == "1" && "${QUIET:-0}" != "1" ]]; then
        printf "${COLOR_DEBUG}[DEBUG] %s${COLOR_RESET}\n" "$*"
    fi
}

# Log warning message
# Arguments: message string(s)
log_warn() {
    if [[ "${QUIET:-0}" != "1" ]]; then
        printf "${COLOR_WARN}[WARN] %s${COLOR_RESET}\n" "$*"
    fi
}

# Print error and exit with code 1
# Arguments: message string(s)
die() {
    log_error "$*"
    exit 1
}

# Get the directory containing the script (resolves symlinks)
# Returns: absolute path to script directory on stdout
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        source="$(readlink -- "$source")"
    done
    printf '%s' "$(cd -- "$(dirname -- "$source")" && pwd -P)"
}

# Load help text from a markdown file in doc/ directory
# Arguments:
#   $1 - implementation name (e.g., "pharo", "squeak", "cuis")
# Returns:
#   0 on success, 1 if help file not found
load_help_from_doc() {
    local impl_name="$1"

    # Get the libexec directory and go up to project root
    local libexec_dir
    libexec_dir="$(get_script_dir)"
    local project_root
    project_root="$(cd -- "${libexec_dir}/.." && pwd -P)"

    local help_file="${project_root}/doc/HELP_${impl_name}.md"

    if [[ -f "$help_file" ]]; then
        cat -- "$help_file"
    else
        # Fallback error message
        printf "Help file not found: %s\n" "$help_file" >&2
        return 1
    fi
}

# Check if a command exists
# Arguments:
#   $1 - command name to check
# Returns:
#   0 if command exists, non-zero otherwise
cmd_exists() {
    type -- "$1" &> /dev/null
    return $?
}

# Ensure cache directory exists
ensure_cache_dir() {
    if [[ ! -d "${CACHE_DIR}" ]]; then
        mkdir -p -- "${CACHE_DIR}"
    fi
}

# Clean cache directory
clean_cache() {
    if [[ -d "${CACHE_DIR}" ]]; then
        rm -rf -- "${CACHE_DIR:?}"/*
        log_info "Cache directory cleaned"
    else
        log_info "Cache directory does not exist"
    fi
}

# Clean cache directory for specific implementation
# Arguments:
#   $1 - implementation name
clean_impl_cache() {
    local impl="$1"
    local impl_cache_dir="${CACHE_DIR}/${impl}"

    if [[ -d "${impl_cache_dir}" ]]; then
        rm -rf -- "${impl_cache_dir:?}"/*
        log_info "${impl} cache cleaned"
    else
        log_info "${impl} cache directory does not exist"
    fi
}

# Get OS type
# Returns: "linux", "macos", "windows", or "unknown" on stdout
get_os() {
    local os_type
    case "$(uname -s)" in
        Linux*)     os_type="linux" ;;
        Darwin*)    os_type="macos" ;;
        MINGW* | MSYS*) os_type="windows" ;;
        *)          os_type="unknown" ;;
    esac
    printf '%s' "$os_type"
}

# Given command names that are missing, print an OS/package-manager-tailored
# one-liner to install the packages that provide them, then return 1. Used to
# guide users when a build tool is absent (e.g. cmake/g++/make for LS4) instead
# of letting them hit a raw 'command not found'.
suggest_install_packages() {
    local -a missing=("$@")
    [[ ${#missing[@]} -eq 0 ]] && return 0

    local os_type
    os_type=$(get_os)

    local cmd
    local -a pkgs=()
    case "$os_type" in
        macos)
            for cmd in "${missing[@]}"; do
                case "$cmd" in
                    g++ | gcc) pkgs+=(gcc) ;;
                    clang | clang++) pkgs+=(llvm) ;;
                    make) pkgs+=(make) ;;
                    libtool) pkgs+=(libtool) ;;
                    *) pkgs+=("$cmd") ;;
                esac
            done
            log_error "Missing build tools: ${missing[*]}"
            log_info "Install them with:"
            printf '  xcode-select --install 2> /dev/null; brew install %s\n' "${pkgs[*]}"
            ;;
        linux)
            if cmd_exists apt-get; then
                # On Debian the 'libtool' command is in libtool-bin (the 'libtool'
                # package only ships the m4 macros), so map libtool -> libtool-bin.
                for cmd in "${missing[@]}"; do
                    case "$cmd" in
                        g++) pkgs+=(g++) ;;
                        gcc) pkgs+=(gcc) ;;
                        clang | clang++) pkgs+=(clang) ;;
                        make) pkgs+=(make) ;;
                        libtool) pkgs+=(libtool-bin) ;;
                        *) pkgs+=("$cmd") ;;
                    esac
                done
                log_error "Missing build tools: ${missing[*]}"
                log_info "On Debian/Ubuntu, install them with:"
                printf '  sudo apt-get install -y %s\n' "${pkgs[*]}"
            elif cmd_exists dnf; then
                for cmd in "${missing[@]}"; do
                    case "$cmd" in
                        g++) pkgs+=(gcc-c++) ;;
                        gcc) pkgs+=(gcc) ;;
                        clang | clang++) pkgs+=(clang) ;;
                        make) pkgs+=(make) ;;
                        libtool) pkgs+=(libtool) ;;
                        *) pkgs+=("$cmd") ;;
                    esac
                done
                log_error "Missing build tools: ${missing[*]}"
                log_info "On Fedora/RHEL, install them with:"
                printf '  sudo dnf install -y %s\n' "${pkgs[*]}"
            elif cmd_exists pacman; then
                for cmd in "${missing[@]}"; do
                    case "$cmd" in
                        g++ | gcc | clang | clang++) pkgs+=(gcc) ;;
                        make) pkgs+=(make) ;;
                        libtool) pkgs+=(libtool) ;;
                        *) pkgs+=("$cmd") ;;
                    esac
                done
                log_error "Missing build tools: ${missing[*]}"
                log_info "On Arch, install them with:"
                printf '  sudo pacman -S --noconfirm %s\n' "${pkgs[*]}"
            else
                log_error "Missing build tools: ${missing[*]}"
                log_info "Install them via your package manager."
            fi
            ;;
        *)
            log_error "Missing build tools: ${missing[*]}"
            log_info "Install them via your package manager."
            ;;
    esac
    return 1
}

# Get architecture
# Returns: "x86_64", "arm64", "arm", "x86", or "unknown" on stdout
get_arch() {
    local arch
    case "$(uname -m)" in
        x86_64)     arch="x86_64" ;;
        aarch64 | arm64) arch="arm64" ;;
        armv7l)     arch="arm" ;;
        i386 | i686) arch="x86" ;;
        *)          arch="unknown" ;;
    esac
    printf '%s' "$arch"
}

# Download file using curl or wget with progress bar
# Arguments:
#   $1 - URL to download
#   $2 - output file path (use "-" for stdout)
# Returns:
#   0 on success, non-zero on failure
download_file() {
    local url="$1"
    local output="$2"

    # Validate URL before downloading
    if ! validate_url "$url"; then
        die "Invalid or unsafe URL: $url"
    fi

    # Retry transient transport errors (e.g. curl 56 'unexpected eof while
    # reading' with OpenSSL 3.x, timeouts, connection resets). Keyed on the
    # downloader's exit code: HTTP 4xx (403 rate-limit, 404) returns 0 here
    # (curl/wget save the response body without -f), so those are NOT retried
    # - callers detect them via the response body. Up to max_retries attempts.
    local max_retries=3
    local attempt=1
    while true; do
        if cmd_exists curl; then
            # -#: progress bar, -L: follow redirects. Fresh download (no -C resume):
            curl -# -L -o "$output" "$url" && return 0
        elif cmd_exists wget; then
            # --progress=bar:dot: progress bar. Fresh download (no -c resume).
            wget --progress=bar:dot -O "$output" "$url" && return 0
        else
            die "Neither curl nor wget is installed"
        fi
        attempt=$((attempt + 1))
        if [[ $attempt -gt $max_retries ]]; then
            return 1
        fi
        log_warn "Download failed (attempt $((attempt - 1))/$max_retries), retrying in 3s..."
        sleep 3
    done
}

# Extract archive (zip, tar.gz, tar.xz)
# Arguments:
#   $1 - archive file path
#   $2 - destination directory (default: ".")
# Returns:
#   0 on success, exits with error on unsupported format
extract_archive() {
    local archive="$1"
    local dest_dir="${2:-.}"

    # Always use -x (extract), add -v only if VERBOSE is set
    local tar_flags="-x"
    [[ "${VERBOSE:-0}" == "1" ]] && tar_flags="-xv"

    local unzip_flags="-q"
    [[ "${VERBOSE:-0}" == "1" ]] && unzip_flags=""

    case "$archive" in
        *.zip)
            unzip $unzip_flags -o "$archive" -d "$dest_dir"
            ;;
        *.tar.gz | *.tgz)
            tar $tar_flags -f "$archive" -C "$dest_dir"
            ;;
        *.tar.xz)
            tar $tar_flags -f "$archive" -C "$dest_dir"
            ;;
        *)
            die "Unsupported archive format: $archive"
            ;;
    esac
}

# Prompt for confirmation
# Arguments:
#   $1 - prompt message (default: "Are you sure?")
# Returns:
#   0 if user confirms, 1 otherwise
confirm() {
    local prompt="${1:-Are you sure?}"
    local response

    read -p "$prompt [y/N] " response
    case "$response" in
        [yY][eE][sS] | [yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if directory contains a Smalltalk installation
# Arguments:
#   $1 - directory path to check
# Returns:
#   Implementation name on stdout if found, exits 1 if not found
detect_existing_smalltalk() {
    local dir="$1"

    # Pharo detection
    if [[ -f "${dir}/Pharo.image" ]] && [[ -f "${dir}/Pharo.changes" ]]; then
        printf 'pharo'
        return 0
    fi

    # GT detection
    if [[ -d "${dir}/GlamorousToolkit.app" ]] || [[ -f "${dir}/GlamorousToolkit.image" ]]; then
        printf 'gt'
        return 0
    fi

    # Cuis detection
    if [[ -f "${dir}/Cuis.image" ]] && [[ -f "${dir}/Cuis.changes" ]]; then
        printf 'cuis'
        return 0
    fi

    # Squeak detection
    if [[ -f "${dir}/Squeak.image" ]] && [[ -f "${dir}/Squeak.changes" ]]; then
        printf 'squeak'
        return 0
    fi

    # LST detection
    if [[ -f "${dir}/lst3r" ]] || command -v lst3r &> /dev/null; then
        printf 'lst'
        return 0
    fi

    # LS4 detection
    if [[ -f "${dir}/build/lst" ]] || command -v lst &> /dev/null; then
        printf 'ls4'
        return 0
    fi

    return 1
}

#################################
## Package Listing Functions
## (Shared by Pharo, GT, Squeak, Cuis)
#################################

# List packages for an implementation that uses GitHub with topics
# Arguments:
#   $1 - implementation name (default: "pharo")
#   $2 - GitHub topic (default: same as implementation name)
# Returns:
#   0 on success, 1 if no cache available
list_monticello_packages() {
    local impl="${1:-pharo}"
    local topic="${2:-$impl}"
    local cache_file="${CACHE_DIR}/${impl}/packages.json"

    ensure_cache_dir
    mkdir -p -- "${CACHE_DIR}/${impl}"

    if [[ -f "$cache_file" ]]; then
        if cmd_exists jq; then
            jq -r '.items[] | "\(.full_name) | \(.description // "N/A")"' "$cache_file"
        else
            log_error "jq is required for package listing"
            return 1
        fi
    else
        log_info "No cached packages. Run 'st $impl update' first."
        return 1
    fi
}

# Update package cache for GitHub-based implementations
# Includes rate limiting and caching for GitHub API
# Arguments:
#   $1 - implementation name (default: "pharo")
#   $2 - GitHub topic (default: same as implementation name)
# Returns:
#   0 on success, 1 on failure
update_monticello_packages() {
    local impl="${1:-pharo}"
    local topic="${2:-$impl}"
    local cache_file="${CACHE_DIR}/${impl}/packages.json"
    local rate_limit_file="${CACHE_DIR}/github_rate_limit"
    local per_page=100

    ensure_cache_dir
    mkdir -p -- "${CACHE_DIR}/${impl}"

    if ! cmd_exists jq; then
        die "jq is required to update the package cache. Please install jq."
    fi

    # Pace GitHub Search API requests. Unauthenticated search is limited to
    # ~10 requests/minute, so wait at least this many seconds between calls.
    local min_interval=7
    if [[ -f "$rate_limit_file" ]]; then
        local last_call=0
        last_call="$(cat -- "$rate_limit_file" 2> /dev/null || printf '0')"
        local now
        now="$(date +%s)"
        if [[ $((now - last_call)) -lt $min_interval ]]; then
            log_debug "Rate limiting: waiting $((min_interval - (now - last_call))) seconds..."
            sleep $((min_interval - (now - last_call)))
        fi
    fi

    log_info "Updating ${impl} package cache..."

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local -a page_files=()
    local grand_total=0
    local created_after=""          # date boundary for splitting windows
    local batch=0
    local first_req=1

    # GitHub Search caps each query at 1000 results. To enumerate more, walk the
    # topic in created-asc order; whenever a window hits the 1000 cap, narrow to
    # repos created on/after the 1000th item's date and continue. Windows overlap
    # at the boundary (created:>=) so no repo is lost; duplicates are removed by
    # id when merging.
    while true; do
        batch=$((batch + 1))
        local q="topic:${topic}"
        [[ -n "$created_after" ]] && q="${q}+created:%3E=${created_after}"
        local base_url="https://api.github.com/search/repositories?per_page=${per_page}&sort=created&order=asc&q=${q}"

        # Page 1 of this window.
        if [[ $first_req -eq 1 ]]; then first_req=0; else sleep "$min_interval"; fi
        date +%s > "$rate_limit_file"
        local p1="$tmp_dir/b${batch}_p1.json"
        if ! download_file "${base_url}&page=1" "$p1"; then
            log_warn "Failed to fetch a page; stopping."
            break
        fi

        local errors
        errors="$(jq '.errors // [] | length' "$p1" 2> /dev/null || printf '0')"
        if [[ "$errors" -gt 0 ]]; then
            log_error "GitHub API returned errors"
            jq '.errors[]?.message' "$p1" 2> /dev/null
            break
        fi

        local window_total window_count
        window_total="$(jq '.total_count // 0' "$p1" 2> /dev/null || printf '0')"
        window_count="$(jq '.items // [] | length' "$p1" 2> /dev/null || printf '0')"
        [[ $grand_total -eq 0 ]] && grand_total="$window_total"
        page_files+=("$p1")

        # Pages 2..10 of this window (a query yields at most 1000 = 10 pages).
        local pg=1
        while [[ $pg -lt 10 ]] && [[ $window_count -lt $window_total ]]; do
            pg=$((pg + 1))
            sleep "$min_interval"
            date +%s > "$rate_limit_file"
            local pf="$tmp_dir/b${batch}_p${pg}.json"
            if ! download_file "${base_url}&page=${pg}" "$pf"; then
                log_warn "Failed to fetch page ${pg}; stopping."
                break 2
            fi
            local n msg
            n="$(jq '.items // [] | length' "$pf" 2> /dev/null || printf '0')"
            if [[ "$n" -eq 0 ]]; then
                msg="$(jq -r '.message // ""' "$pf" 2> /dev/null || true)"
                if [[ -n "$msg" ]]; then log_warn "GitHub: $msg"; fi
                break
            fi
            page_files+=("$pf")
            window_count=$((window_count + n))
        done

        # If the whole window fit within the 1000 cap, we have everything.
        if [[ $window_total -le 1000 ]]; then break; fi

        # Otherwise advance the boundary to the last (newest in window) item's
        # created date and loop to fetch the remainder.
        local last_idx=$((${#page_files[@]} - 1))
        local last_created
        last_created="$(jq -r '.items[-1].created_at // ""' "${page_files[$last_idx]}" 2> /dev/null | cut -dT -f1)"
        if [[ -z "$last_created" ]] || [[ "$last_created" == "$created_after" ]]; then
            log_warn "Cannot advance the date window past ${created_after:-start}; stopping."
            break
        fi
        created_after="$last_created"
    done

    # Merge all pages, deduping by id (order-preserving) since the created:>=
    # windows overlap at each boundary. list_monticello_packages reads .items[].
    local collected=0
    if [[ ${#page_files[@]} -gt 0 ]]; then
        jq -s '
            ([.[].items] | add) as $all
            | { total_count: ([.[].total_count] | max),
                items: ($all | reduce .[] as $x ({seen:{}, out:[]};
                    if .seen[($x.id|tostring)] then .
                    else (.seen[($x.id|tostring)] = true | .out += [$x]) end) | .out) }
        ' "${page_files[@]}" > "$cache_file"
        collected="$(jq '.items | length' "$cache_file" 2> /dev/null || printf '0')"
    fi

    rm -rf -- "$tmp_dir"

    if [[ -f "$cache_file" ]]; then
        log_success "Package cache updated (${collected} of ${grand_total} packages)"
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
# Arguments:
#   $1 - image path (default: ".")
# Returns:
#   0 if Clap is available, 1 otherwise
check_clap_available() {
    local image_path="${1:-.}"

    if [[ ! -f "${image_path}/pharo" ]] && [[ ! -f "${image_path}/Pharo.image" ]]; then
        return 1
    fi

    # Try to get Clap version
    local version_output
    version_output="$("${image_path}/pharo" "${image_path}/Pharo.image" eval --save "SpEnvironment current versionString" 2> /dev/null || true)"

    [[ -n "$version_output" ]]
}

# Run a Clap command on an image
# Arguments:
#   $1 - image path
#   $@ - Clap arguments
run_clap() {
    local image_path="${1:-.}"
    shift
    local clap_args="$*"

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
# Arguments:
#   $1 - package specification string
#   $2 - image path (default: ".")
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
# Arguments:
#   $1 - baseline specification string
#   $2 - image path (default: ".")
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
# Arguments:
#   $1 - image path (default: ".")
# Returns:
#   Version string on stdout
get_image_version() {
    local image_path="${1:-.}"

    if [[ -f "${image_path}/Pharo.image" ]]; then
        if [[ -f "${image_path}/pharo" ]]; then
            "./pharo" "${image_path}/Pharo.image" eval --save "Smalltalk version" 2> /dev/null || printf 'unknown'
        else
            printf 'unknown'
        fi
    else
        printf 'not installed'
    fi
}

# Save the image
# Arguments:
#   $1 - image path (default: ".")
save_image() {
    local image_path="${1:-.}"

    if [[ ! -f "${image_path}/Pharo.image" ]]; then
        die "Image not found in ${image_path}"
    fi

    log_info "Saving image..."
    "./pharo" "${image_path}/Pharo.image" save 2> /dev/null || true
}

# Evaluate Smalltalk code
# Arguments:
#   $1 - Smalltalk code string
#   $2 - image path (default: ".")
eval_code() {
    local code="$1"
    local image_path="${2:-.}"

    if [[ ! -f "${image_path}/Pharo.image" ]]; then
        die "Image not found in ${image_path}"
    fi

    "./pharo" "${image_path}/Pharo.image" eval --save "$code"
}

# Ensure directory exists and is writable
# Arguments:
#   $1 - directory path
# Returns:
#   0 on success, exits with error if directory is not writable
ensure_install_dir() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        mkdir -p -- "$dir"
        log_debug "Created directory: $dir"
    fi

    if [[ ! -w "$dir" ]]; then
        die "Directory is not writable: $dir"
    fi
}

# Generate a timestamped installation directory name
# Arguments:
#   $1 - implementation name
#   $2 - version (default: "unknown")
# Returns:
#   Generated directory name on stdout
get_timestamped_dir() {
    local impl_name="$1"
    local version="${2:-unknown}"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    printf '%s' "${impl_name}-${version}_${timestamp}"
}

# Ensure installation goes to a timestamped directory if no destination specified
# Arguments:
#   $1 - specified directory ("." means auto-generate)
#   $2 - implementation name
#   $3 - version (default: "unknown")
# Returns:
#   Resolved directory path on stdout
resolve_install_dir() {
    local specified_dir="$1"
    local impl_name="$2"
    local version="${3:-unknown}"

    if [[ "$specified_dir" == "." ]]; then
        local new_dir
        new_dir="$(get_timestamped_dir "$impl_name" "$version")"
        log_info "No destination specified. Creating directory: $new_dir"
        ensure_install_dir "$new_dir"
        printf '%s' "$new_dir"
    else
        ensure_install_dir "$specified_dir"
        printf '%s' "$specified_dir"
    fi
}

# Register installed files to manifest
# Arguments:
#   $1 - implementation name
#   $2 - installation directory path
#   $@ - remaining args: list of file paths
register_install() {
    local impl="$1"
    local install_dir="$2"
    shift 2
    local files=("$@")

    manifest_add "$impl" "$install_dir" "${files[@]}"
    log_debug "Registered installation of $impl to manifest"
}
