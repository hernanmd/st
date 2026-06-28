#!/usr/bin/env bash
#
# helpers.sh - Security utilities and backwards compatibility
#
# This file provides supplementary security functions. All common functions
# (logging, platform detection, download, extraction, manifest, etc.) are
# in libexec/smalltalk-common.sh.
#
# Exit codes: 0 on success, 1 on error
#
set -Eeuo pipefail

IFS=$'\n\t'

# --- Security Functions ---

# Validate path to prevent path traversal attacks
# Arguments:
#   $1 - path to validate
#   $2 - optional allowed prefix
# Returns: 0 on success, 1 on validation failure
validate_path() {
    local path="$1"
    local allowed_prefix="${2:-}"

    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        printf 'Error: Invalid path (contains null byte)\n' >&2
        return 1
    fi

    # Check for path traversal attempts (.. components)
    case "$path" in
        .. | ../* | */../* | */..)
            printf 'Error: Invalid path (contains .. traversal)\n' >&2
            return 1
            ;;
    esac

    # Check if path starts with allowed prefix (if specified)
    if [[ -n "$allowed_prefix" ]]; then
        local abs_path abs_prefix
        abs_path="$(cd -- "$path" 2> /dev/null && pwd -P || printf '%s' "$path")"
        abs_prefix="$(cd -- "$allowed_prefix" 2> /dev/null && pwd -P || printf '%s' "$allowed_prefix")"
        if [[ "$abs_path" != "$abs_prefix"* ]]; then
            printf 'Error: Path must be under %s\n' "$allowed_prefix" >&2
            return 1
        fi
    fi

    return 0
}

# Validate package name (alphanumeric, dash, underscore, dot, forward slash only)
# Arguments:
#   $1 - package name to validate
# Returns: 0 on success, 1 on validation failure
validate_package_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        printf 'Error: Package name cannot be empty\n' >&2
        return 1
    fi

    # Block overly long names
    if [[ ${#name} -gt 255 ]]; then
        printf 'Error: Package name too long (max 255 characters)\n' >&2
        return 1
    fi

    # Allow: alphanumeric, dash, underscore, dot, forward slash (for owner/repo)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
        printf 'Error: Invalid package name '\''%s'\''. Use only alphanumeric, dash, underscore, dot, and forward slash.\n' "$name" >&2
        return 1
    fi

    return 0
}

# Validate URL (basic security check)
# Arguments:
#   $1 - URL to validate
# Returns: 0 on success, 1 on validation failure
validate_url() {
    local url="$1"

    # Must start with http:// or https://
    if [[ ! "$url" =~ ^https?:// ]]; then
        printf 'Error: URL must start with http:// or https://\n' >&2
        return 1
    fi

    # Block file:// and other dangerous protocols
    if [[ "$url" =~ ^file:// ]] || [[ "$url" =~ ^ftp:// ]] || [[ "$url" =~ ^javascript: ]]; then
        printf 'Error: Protocol not allowed\n' >&2
        return 1
    fi

    return 0
}

# --- Core Functions ---

# Print error and exit
# Arguments:
#   $@ - error message
error_exit() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

# Check if a command exists
# Arguments:
#   $1 - command name
# Returns: 0 if command exists, non-zero otherwise
cmd_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Source the common utilities for backwards compatibility
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -f "${SCRIPT_DIR}/libexec/smalltalk-common.sh" ]]; then
    # shellcheck source=libexec/smalltalk-common.sh
    source "${SCRIPT_DIR}/libexec/smalltalk-common.sh"
fi
