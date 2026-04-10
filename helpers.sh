#!/bin/bash

#################################
## Helper Functions
#################################
# This file provides security utilities and backwards compatibility.
# All common functions are in libexec/smalltalk-common.sh

# --- Security Functions ---

# Validate path to prevent path traversal attacks
validate_path() {
    local path="$1"
    local allowed_prefix="${2:-}"
    
    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        echo "Error: Invalid path (contains null byte)" >&2
        return 1
    fi
    
    # Check for path traversal attempts (.. components)
    case "$path" in
        ..|../*|*/../*|*/..)
            echo "Error: Invalid path (contains .. traversal)" >&2
            return 1
            ;;
    esac
    
    # Check if path starts with allowed prefix (if specified)
    if [[ -n "$allowed_prefix" ]]; then
        local abs_path abs_prefix
        abs_path=$(cd "$path" 2>/dev/null && pwd || echo "$path")
        abs_prefix=$(cd "$allowed_prefix" 2>/dev/null && pwd || echo "$allowed_prefix")
        if [[ "$abs_path" != "$abs_prefix"* ]]; then
            echo "Error: Path must be under $allowed_prefix" >&2
            return 1
        fi
    fi
    
    return 0
}

# Validate package name (alphanumeric, dash, underscore, forward slash only)
validate_package_name() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        echo "Error: Package name cannot be empty" >&2
        return 1
    fi
    
    # Allow: alphanumeric, dash, underscore, forward slash (for owner/repo)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
        echo "Error: Invalid package name '$name'. Use only alphanumeric, dash, underscore, dot, and forward slash." >&2
        return 1
    fi
    
    # Block overly long names
    if [[ ${#name} -gt 255 ]]; then
        echo "Error: Package name too long (max 255 characters)" >&2
        return 1
    fi
    
    return 0
}

# Validate URL (basic check for security)
validate_url() {
    local url="$1"
    
    # Must start with http:// or https://
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo "Error: URL must start with http:// or https://" >&2
        return 1
    fi
    
    # Block file:// and other dangerous protocols
    if [[ "$url" =~ ^file:// ]] || [[ "$url" =~ ^ftp:// ]] || [[ "$url" =~ ^javascript: ]]; then
        echo "Error: Protocol not allowed" >&2
        return 1
    fi
    
    return 0
}

# --- Temp File Management ---

# Global arrays to track temp files for cleanup
declare -a _TEMP_FILES=()
declare -a _TEMP_DIRS=()

# Cleanup function registered with trap
_cleanup_temp_resources() {
    for f in "${_TEMP_FILES[@]}"; do
        rm -f "$f" 2>/dev/null || true
    done
    for d in "${_TEMP_DIRS[@]}"; do
        rm -rf "$d" 2>/dev/null || true
    done
}

# Register cleanup trap
trap _cleanup_temp_resources EXIT INT TERM

# Create a temp file and register it for cleanup
make_temp_file() {
    local prefix="${1:-smalltalk}"
    local tmpfile
    tmpfile=$(mktemp "${TMPDIR:-/tmp}/${prefix}.XXXXXX" 2>/dev/null) || return 1
    _TEMP_FILES+=("$tmpfile")
    echo "$tmpfile"
}

# Create a temp directory and register it for cleanup
make_temp_dir() {
    local prefix="${1:-smalltalk}"
    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX" 2>/dev/null) || return 1
    _TEMP_DIRS+=("$tmpdir")
    echo "$tmpdir"
}

# --- Core Functions ---

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Source the common utilities for backwards compatibility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/libexec/smalltalk-common.sh" ]]; then
    source "${SCRIPT_DIR}/libexec/smalltalk-common.sh"
fi