#!/usr/bin/env bash
#
# demo-cleanup.sh - Destroy Smalltalk artifacts created by the demo so the
# repository stays clean. Only the recorded demo.cast (and the demo/ scripts)
# are preserved.
#
# Safe by design:
#   - The demo runs inside a throwaway sandbox dir; this destroys it.
#   - A defensive sweep removes any st artifact patterns from the repo root.
#   - The demo/ folder and demo.cast are NEVER removed.
#   - The global ~/.smalltalk-cache and ~/.smalltalk-manifest.json (shared across
#     projects) are left untouched unless DEMO_CLEAN_GLOBAL=1.
#
# Usage (run directly for manual/recovery cleanup):
#   ./demo/demo-cleanup.sh                     # clean default locations
#   DEMO_CLEAN_GLOBAL=1 ./demo/demo-cleanup.sh # also wipe global cache + manifest
#   DEMO_WORK_DIR=/path ./demo/demo-cleanup.sh  # also remove a specific sandbox dir
#
# Also sourced by demo-cmds.sh to provide the `demo_cleanup` function for its
# EXIT trap (sourcing only defines functions; it does not run cleanup).

set -Eo pipefail
IFS=$'\n\t'

# Resolve demo dir / project root from this file's location (works when sourced).
_DEMO_CLEAN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEMO_CLEAN_PROJECT_ROOT="$(cd -- "${_DEMO_CLEAN_DIR}/.." && pwd -P)"

# Artifact patterns that `st` creates in an install directory / CWD.
# Mirrors libexec/smalltalk-common.sh::clean_all_artifacts, scoped to the repo
# root (non-recursive), plus the timestamped install dirs produced by
# `st <impl> install` (impl-version_timestamp). Never matches demo/ or demo.cast.
declare -a _DEMO_ARTIFACT_GLOBS=(
    "Pharo*.image" "Pharo*.changes" "Pharo*.sources"
    "pharo-vm" "pharo-ui" "pharo" "Pharo.app" "Pharo*.app"
    "GlamorousToolkit" "GlamorousToolkit*.app" "GlamorousToolkit*.image"
    "Cuis*.image" "Cuis*.changes" "Cuis.app"
    "Squeak*.image" "Squeak*.changes" "Squeak*.app"
    "lst3r" "*.fuel"
    "github-cache" "github-*.zip" "package-cache" "play-cache" "play-stash"
    "PharoDebug.log" "SqueakDebug.log"
    "pharo-*_*" "cuis-*_*" "gt-*_*" "squeak-*_*" "gnu-*_*" "lst-*_*" "ls4-*_*"
)

# Remove a path only if it is NOT inside the demo/ folder (protects demo.cast/scripts).
_demo_safe_rm() {
    local target="$1"
    [[ -e "$target" ]] || return 0
    local abs dirpart
    dirpart="$(cd -- "$(dirname -- "$target")" 2> /dev/null && pwd -P)" || return 0
    abs="${dirpart}/$(basename -- "$target")"
    case "$abs" in
        "$_DEMO_CLEAN_DIR" | "$_DEMO_CLEAN_DIR"/*) return 0 ;; # never delete demo/
    esac
    rm -rf -- "$target"
}

# Sweep the repo root for artifact patterns (defensive; the sandbox already
# isolates installations so this normally finds nothing).
demo_cleanup_repo() {
    local root="${1:-$DEMO_CLEAN_PROJECT_ROOT}"
    local pat f
    shopt -s nullglob
    for pat in "${_DEMO_ARTIFACT_GLOBS[@]}"; do
        for f in "$root"/$pat; do
            _demo_safe_rm "$f"
        done
    done
    shopt -u nullglob
}

# Destroy the throwaway sandbox directory used by the demo.
demo_cleanup_sandbox() {
    local work_dir="${1:-${DEMO_WORK_DIR:-}}"
    [[ -n "$work_dir" && -d "$work_dir" ]] || return 0
    # Safety: only remove paths that look like our sandboxes.
    case "$work_dir" in
        */st-demo.* | */st-demo.XXXXXX)
            rm -rf -- "$work_dir"
            ;;
        *)
            printf 'demo-cleanup: refusing to remove non-sandbox dir: %s\n' "$work_dir" >&2
            ;;
    esac
}

# Wipe the global st cache + manifest. Affects ALL st installations on the machine;
# opt-in only via DEMO_CLEAN_GLOBAL=1.
demo_cleanup_global() {
    local cache="${CACHE_DIR:-$HOME/.smalltalk-cache}"
    local manifest="${MANIFEST_FILE:-$HOME/.smalltalk-manifest.json}"
    [[ -d "$cache" ]] && rm -rf -- "$cache"
    [[ -f "$manifest" ]] && rm -f -- "$manifest"
}

# Full cleanup: sandbox + repo sweep (+ optional global).
demo_cleanup() {
    demo_cleanup_sandbox "${DEMO_WORK_DIR:-}"
    demo_cleanup_repo "$DEMO_CLEAN_PROJECT_ROOT"
    if [[ "${DEMO_CLEAN_GLOBAL:-0}" == "1" ]]; then
        demo_cleanup_global
    fi
}

# Run cleanup only when executed directly, not when sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    demo_cleanup
fi
