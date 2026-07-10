#!/usr/bin/env bash
#
# install.sh - Installer for Smalltalk CLI
#
# SECURITY NOTE: This script downloads code from GitHub and installs it.
# We recommend verifying the checksum of downloaded files before installation.
#
# Usage:
#   1. Download and verify: curl -fsSL https://raw.githubusercontent.com/hernanmd/st/master/install.sh -o install.sh
#   2. Review: cat install.sh
#   3. Run: bash install.sh
#
# Or use with automatic verification:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/hernanmd/st/master/install.sh)"
#
# Exit codes:
#   0 - Success
#   1 - General error
#
set -Eeuo pipefail

# Prevent word splitting on spaces
IFS=$'\n\t'

{ # Prevent execution if this script was only partially downloaded

    #################################
    ## Security Configuration
    #################################

    readonly GITHUB_REPO="hernanmd/st"
    readonly GITHUB_RELEASES_URL="https://github.com/${GITHUB_REPO}/releases"
    readonly INSTALL_BASE="${HOME}/.st"
    readonly SCRIPT_NAME="st"

    #################################
    ## Utility Functions
    #################################

    oops() {
        echo "$0: Error: $*" >&2
        exit 1
    }

    require_util() {
        command -v "$1" > /dev/null 2>&1 \
                                     || oops "you do not have '$1' installed, which I need to $2"
    }

    log_info() {
        printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
    }

    log_success() {
        printf '\033[1;32m[SUCCESS]\033[0m %s\n' "$*"
    }

    log_warn() {
        printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2
    }

    log_error() {
        printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
    }

    # ANSI color constants (real ESC bytes via $'...' so they work inside
    # heredocs/echo where '\033' would otherwise print literally).
    readonly C_GREEN=$'\033[1;32m' C_BOLD=$'\033[1m' C_RESET=$'\033[0m'

    # Cleanup temporary files on exit
    cleanup() {
        if [[ -n "${tmpDir:-}" ]] && [[ -d "$tmpDir" ]]; then
            rm -rf -- "$tmpDir"
        fi
    }

    trap cleanup EXIT INT QUIT TERM

    #################################
    ## Security Functions
    #################################

    # Get checksum of a file (using sha256sum or shasum)
    get_checksum() {
        local file="$1"
        if command -v sha256sum > /dev/null 2>&1; then
            sha256sum "$file" | cut -d' ' -f1
        elif command -v shasum > /dev/null 2>&1; then
            shasum -a 256 "$file" | cut -d' ' -f1
        else
            echo ""
        fi
    }

    # Verify a checksum
    verify_checksum() {
        local file="$1"
        local expected="$2"

        if [[ -z "$expected" ]]; then
            log_warn "No checksum provided, skipping verification"
            return 0
        fi

        local actual
        actual=$(get_checksum "$file")

        if [[ -z "$actual" ]]; then
            log_warn "Could not compute checksum, skipping verification"
            return 0
        fi

        if [[ "$actual" != "$expected" ]]; then
            log_error "Checksum verification failed!"
            log_error "Expected: $expected"
            log_error "Actual:   $actual"
            return 1
        fi

        log_success "Checksum verified"
        return 0
    }

    # Verify the tarball after download
    verify_tarball() {
        local tarball="$1"
        local version="$2"

        # Try to get checksum from GitHub releases
        local checksum_url="${GITHUB_RELEASES_URL}/download/${version}/checksums.txt"
        local checksum_file="${tmpDir}/checksums.txt"

        if curl -fsSL "$checksum_url" -o "$checksum_file" 2> /dev/null; then
            log_info "Verifying checksum..."
            local expected_checksum
            expected_checksum=$(grep "$(basename "$tarball")" "$checksum_file" 2> /dev/null | cut -d' ' -f1)

            if verify_checksum "$tarball" "$expected_checksum"; then
                return 0
            fi
        else
            log_warn "No checksum file found at $checksum_url"
            log_warn "To verify manually, run: sha256sum $tarball"
        fi

        return 0
    }

    # Check if running as root - we don't want to install as root
    check_not_root() {
        if [[ "$(id -u)" -eq 0 ]]; then
            log_error "Do not run this script as root or with sudo"
            log_error "This script installs to your home directory"
            exit 1
        fi
    }

    # Verify the downloaded script is valid
    verify_script_integrity() {
        local script="$1"

        # Check the script exists
        [[ -f "$script" ]] || return 1

        # Check for obvious issues
        if grep -q "rm -rf /" "$script" 2> /dev/null; then
            log_error "Downloaded script contains suspicious content!"
            return 1
        fi

        # Check that it's a valid shell script (starts with shebang)
        if ! head -n 1 "$script" | grep -q "^#!/"; then
            log_warn "Script may not be a valid shell script"
        fi

        return 0
    }

    #################################
    ## Download Functions
    #################################

    # Get the latest version tag from GitHub
    get_latest_version() {
        local version
        version=$(curl -s -o /dev/null -I -w "%{redirect_url}" "${GITHUB_RELEASES_URL}/latest" 2> /dev/null | sed 's/.*\///')

        if [[ -z "$version" ]]; then
            # Fallback: try to get version from API
            version=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2> /dev/null | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')
        fi

        if [[ -z "$version" ]]; then
            log_warn "Could not determine latest version"
            version="master"
        fi

        echo "$version"
    }

    # Download the tarball with integrity checks
    download_tarball() {
        local version="$1"
        local tarball="$2"

        # Construct download URL
        local url="https://github.com/${GITHUB_REPO}/archive/${version}.tar.gz"
        log_info "Downloading ${SCRIPT_NAME} ${version}..."
        log_info "URL: $url"

        # Check if URL is valid (follow redirects: GitHub archive 302s to codeload.github.com).
        # Without -L, %{http_code} is 302 and the check always fails even though the
        # real download (curl -fsSL) would succeed.
        if ! curl -sL -o /dev/null -w "%{http_code}" "$url" | grep -q '^200$'; then
            log_error "Could not download from $url"
            oops "Failed to download tarball"
        fi

        # Download with progress
        if ! curl -fsSL "$url" -o "$tarball"; then
            log_error "Download failed"
            oops "Failed to download tarball"
        fi

        # Verify download
        if [[ ! -f "$tarball" ]] || [[ ! -s "$tarball" ]]; then
            oops "Downloaded file is empty or missing"
        fi

        log_success "Download complete"
        verify_tarball "$tarball" "$version"
    }

    #################################
    ## Installation Functions
    #################################

    # Create backup of existing installation
    create_backup() {
        local target="$1"
        local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"

        if [[ -d "$target" ]]; then
            log_info "Creating backup at $backup"
            mv "$target" "$backup"
        fi
    }

    # Uninstall: remove the installed directory and report leftovers.
    # Mirrors `make uninstall` (rm -rf ~/.st/st) plus helpful hints for
    # backups, cache, and the PATH export the user may have added.
    uninstall_st() {
        local install_dir="${INSTALL_BASE}/${SCRIPT_NAME}"

        if [[ ! -d "$install_dir" ]]; then
            log_info "No installation found at ${install_dir}"
            return 1
        fi

        log_info "Removing ${install_dir}"
        rm -rf -- "$install_dir"

        if [[ -d "$install_dir" ]]; then
            log_error "Failed to remove ${install_dir}"
            return 1
        fi

        log_success "Uninstalled ${SCRIPT_NAME}"

        # Report leftovers the user may want to clean up manually.
        local backups
        backups="$(find "$INSTALL_BASE" -maxdepth 1 -type d -name "${SCRIPT_NAME}.backup.*" 2> /dev/null || true)"
        if [[ -n "$backups" ]]; then
            log_warn "Backup directories remain under ${INSTALL_BASE}:"
            while IFS= read -r line; do
                [[ -n "$line" ]] && printf '  %s\n' "$line"
            done <<< "$backups"
            log_warn "Remove with: rm -rf ${INSTALL_BASE}/${SCRIPT_NAME}.backup.*"
        fi

        if [[ -d "${HOME}/.smalltalk-cache" ]]; then
            log_warn "Smalltalk cache remains at ${HOME}/.smalltalk-cache"
            log_warn "Remove with: rm -rf ${HOME}/.smalltalk-cache"
        fi

        log_info "Remove the PATH export from your shell rc (~/.zshrc / ~/.bash_profile) if you added one."
        return 0
    }

    # Install the downloaded files
    do_install() {
        require_util curl "download the tarball"
        require_util tar "unpack the tarball"

        local version
        version=$(get_latest_version)

        local tarball="${tmpDir}/${SCRIPT_NAME}.tar.gz"

        download_tarball "$version" "$tarball"

        local unpack="${INSTALL_BASE}"
        local target_dir="${unpack}/${SCRIPT_NAME}"

        # Create installation directory
        mkdir -pv "$unpack"

        # Backup existing installation
        if [[ -d "$target_dir" ]]; then
            log_info "Previous installation found"
            create_backup "$target_dir"
        fi

        # Unpack. Note: 'tar -xzf -- <file>' is broken because -f greedily takes the
        # next token ('--') as the archive name. Use -C to set the target dir instead.
        log_info "Unpacking..."
        tar -xzf "$tarball" -C "$unpack" || oops "Failed to unpack tarball"

        # Find the extracted directory (github archives include a prefix)
        local extracted_dir
        extracted_dir=$(find "$unpack" -maxdepth 1 -type d -name "smalltalk*" -o -name "st*" 2> /dev/null | head -1)

        if [[ -n "${extracted_dir:-}" ]] && [[ "$extracted_dir" != "$target_dir" ]]; then
            mv -- "$extracted_dir" "$target_dir" 2> /dev/null || true
        fi

        # Verify main script exists
        local main_script="${target_dir}/bin/${SCRIPT_NAME}"
        if [[ ! -f "$main_script" ]]; then
            main_script=$(find "$target_dir" -name "${SCRIPT_NAME}" -type f 2> /dev/null | head -1)
        fi

        if [[ -z "$main_script" ]] || [[ ! -f "$main_script" ]]; then
            oops "Main script not found in tarball"
        fi

        # Verify script integrity
        if ! verify_script_integrity "$main_script"; then
            oops "Script integrity check failed"
        fi

        chmod +x "$main_script"

        log_success "Installation complete"
        show_post_install "$main_script"
    }

    # Show post-install instructions
    show_post_install() {
        local script="$1"
        local script_dir
        script_dir=$(dirname "$script")

        cat <<- EOF

${C_GREEN}${SCRIPT_NAME} is installed!${C_RESET}

${C_BOLD}To add ${SCRIPT_NAME} to your PATH:${C_RESET}

  For bash users:
    echo "export PATH=\"${script_dir}:\$PATH\"" >> ~/.bash_profile
    source ~/.bash_profile

  For zsh users:
    echo "export PATH=\"${script_dir}:\$PATH\"" >> ~/.zshrc
    source ~/.zshrc

Or run directly:
    ${script} --help

EOF
    }

    # Show usage
    show_usage() {
        cat <<- EOF
Usage: $(basename "$0") [OPTIONS]

Install ${SCRIPT_NAME} - A unified CLI for Smalltalk implementations

Options:
  -h, --help          Show this help message
  -u, --upgrade       Upgrade to latest version
  -v, --version       Show version
  -f, --force         Force reinstall even if already installed
  -c, --check          Check installation status
      --uninstall      Remove the installed ${SCRIPT_NAME}

Security:
  This script downloads from: https://github.com/${GITHUB_REPO}
  To verify before running:
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/master/install.sh -o /tmp/install.sh
    cat /tmp/install.sh  # Review the script
    bash /tmp/install.sh

EOF
    }

    #################################
    ## Check Functions
    #################################

    check_install() {
        local script="${INSTALL_BASE}/${SCRIPT_NAME}/bin/${SCRIPT_NAME}"

        if [[ -f "$script" ]]; then
            log_info "Found installation at: $script"
            "$script" --version 2> /dev/null || log_info "Version: unknown"
            return 0
        fi

        if command -v "$SCRIPT_NAME" > /dev/null 2>&1; then
            log_info "Found ${SCRIPT_NAME} in PATH"
            "${SCRIPT_NAME}" --version 2> /dev/null || true
            return 0
        fi

        log_info "No existing installation found"
        return 1
    }

    #################################
    ## Main Function
    #################################

    install_st() {
        check_not_root

        # Create temp directory
        tmpDir=$(mktemp -d -t st-install.XXXXXXXXXX) || oops "Failed to create temp directory"

        # Do the installation
        do_install
    }

    main() {
        local force=false
        local check_only=false
        local uninstall_only=false

        while [[ $# -gt 0 ]]; do
            case "$1" in
                -h | --help)
                    show_usage
                    exit 0
                    ;;
                -u | --upgrade | --update)
                    shift
                    ;;
                -v | --version)
                    echo "${SCRIPT_NAME} installer v1.0.0"
                    exit 0
                    ;;
                -f | --force)
                    force=true
                    shift
                    ;;
                -c | --check)
                    check_only=true
                    shift
                    ;;
                --uninstall)
                    uninstall_only=true
                    shift
                    ;;
                *)
                    show_usage
                    exit 1
                    ;;
            esac
        done

        if $uninstall_only; then
            uninstall_st
            exit $?
        fi

        if $check_only; then
            check_install
            exit $?
        fi

        # Check existing installation
        if ! $force && check_install; then
            log_info "Already installed. Use --force to reinstall."
            exit 0
        fi

        install_st
    }

    # Run main if script is executed (not sourced)
    # Use ${BASH_SOURCE[0]:-$0} so the script also works under `bash -c "$(curl ...)"
    # where BASH_SOURCE is unset (avoids 'unbound variable' under set -u).
    if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
        main "$@"
    fi

} # End of wrapping
