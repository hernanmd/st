#!/usr/bin/env bash
#
# publish-checksums.sh - Generate and upload checksums.txt to a GitHub release
#
# Computes the SHA256 of the GitHub archive tarball for the given tag and
# uploads it as a `checksums.txt` release asset, so install.sh can verify
# downloaded tarballs. install.sh downloads the archive and saves it locally
# as `${SCRIPT_NAME}.tar.gz` (i.e. `st.tar.gz`), then greps `checksums.txt`
# for that basename - so the checksum line is keyed as `st.tar.gz` regardless
# of the actual archive filename.
#
# Usage: ./libexec/publish-checksums.sh <tag/version>
#
# Exit codes:
#   0 - Success
#   1 - Error (missing args, download failed, no sha256 tool, gh unavailable)
#
set -Eeuo pipefail
IFS=$'\n\t'

readonly GITHUB_REPO="hernanmd/st"
readonly SCRIPT_NAME="st"   # install.sh saves the tarball as ${SCRIPT_NAME}.tar.gz

# Globals so the EXIT trap can reference them under `set -u` after main()
# returns (locals would be unbound there).
TMP_DIR=""

die() {
    printf 'publish-checksums: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    rm -rf -- "$TMP_DIR"
}

# SHA256 of a file (sha256sum on Linux, shasum on macOS/BSD).
get_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | cut -d' ' -f1
    else
        printf ''
    fi
}

main() {
    local version="${1:-}"
    [[ -n "$version" ]] || die "usage: $0 <tag/version>"

    command -v gh >/dev/null 2>&1 || die "gh CLI not found; install it and run 'gh auth login'"
    command -v curl >/dev/null 2>&1 || die "curl not found"

    local archive_url="https://github.com/${GITHUB_REPO}/archive/${version}.tar.gz"

    # Use a temp dir so the checksums file is literally named `checksums.txt`
    # (gh names the asset from the file basename; the `#rename` syntax only
    # sets the asset label, not the download name).
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    TMP_DIR="$tmp_dir"
    trap cleanup EXIT
    local archive_tmp="${tmp_dir}/archive.tar.gz"
    local checksums_tmp="${tmp_dir}/checksums.txt"

    # The archive URL may take a few seconds to become available after the tag
    # is pushed; retry briefly.
    local sha=""
    local attempt
    for attempt in $(seq 1 10); do
        if curl -fsSL "$archive_url" -o "$archive_tmp"; then
            sha="$(get_sha256 "$archive_tmp")"
            [[ -n "$sha" ]] && break
        fi
        sleep 2
    done
    [[ -n "$sha" ]] || die "could not fetch/compute checksum for $archive_url"

    # sha256sum-format: "<hash>  <filename>"; install.sh greps for the basename
    # it uses locally (st.tar.gz) and takes the first whitespace-separated field.
    printf '%s  %s.tar.gz\n' "$sha" "$SCRIPT_NAME" > "$checksums_tmp"

    printf 'publish-checksums: uploading checksums.txt for release %s (sha=%s)\n' \
        "$version" "$sha"
    gh release upload "$version" "$checksums_tmp" \
        --repo "$GITHUB_REPO" --clobber

    printf 'publish-checksums: done -> https://github.com/%s/releases/download/%s/checksums.txt\n' \
        "$GITHUB_REPO" "$version"
}

main "$@"