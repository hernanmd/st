#!/usr/bin/env bash
#
# deploy.sh - Release deployment script
#
# Usage: ./deploy.sh [version]
#
# Exit codes:
#   0 - Success
#   1 - Error
#
set -Eeuo pipefail

main() {
    local version

    if [[ -f .nvmrc ]]; then
        # shellcheck disable=SC1091
        source ~/.nvm/nvm.sh
        nvm use
    else
        printf "Couldn't find .nvmrc file.\n"
        printf "You can generate a .nvmrc file for your node version by installing nvm, then:\n"
        printf "  mkdir ~/.nvm && nvm current > .nvmrc\n"
    fi

    printf '%s' "$(date '+%d-%m-%Y')" > DATE
    if [[ ! -f DATE ]]; then
        printf "Couldn't write DATE file for release\n"
        exit 1
    fi

    # It is highly recommended to supply a version number, otherwise we lose tracking the number in VERSION file
    if [[ $# -eq 0 ]]; then
        release-it
    else
        printf "ST: Version supplied: %s\n" "$1"
        version="$1"
        printf '%s' "$version" > VERSION
        release-it "$version"
    fi
}

main "$@"