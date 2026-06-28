#!/usr/bin/env bash
#
# demo-lib.sh - Shared bootstrap for the st demo scripts.
#
# Responsibilities:
#   1. Resolve the demo directory from the caller's location (location-independent).
#   2. Source demo-magic.sh so pe/p/pei/cmd are defined (fixes "pe: command not found").
#   3. Detect the project's main script and expose it via ST_CMD.
#
# Sourcing this file is enough; it does not run any demo commands.
#
# Notes:
#   - Demo scripts intentionally do NOT use `set -e`: a recorded demo must keep
#     running even if an `st` command exits non-zero (e.g. `st pharo version`
#     returns 1 when Pharo is not installed). We use `set -Eo pipefail` + IFS only.
#   - `set -u` is omitted because the vendored demo-magic.sh is not strict-mode-safe.

set -Eo pipefail
IFS=$'\n\t'

# Resolve the directory holding this file (works regardless of CWD / login shell).
DEMO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export DEMO_DIR

# Source the demo-magic library by absolute path (the original bug sourced
# "/$HOME/demo/demo-magic.sh", which never existed and left pe undefined).
# shellcheck source=demo-magic.sh
source "$DEMO_DIR/demo-magic.sh"

##
# detect_main_script - locate the project's main executable.
#
# Resolution order:
#   1. Project-local build:  $DEMO_DIR/../bin/<name>  (e.g. ../bin/st)
#   2. On PATH:              command -v <name>         (e.g. globally installed)
#   3. Fail with a clear message.
#
# Arguments:
#   $1 - executable name to detect (default: st)
# Outputs:
#   Prints the resolved path and sets the global <NAME_UPPER>_CMD variable.
# Returns:
#   0 on success, 1 if the script cannot be found.
##
detect_main_script() {
    local name="${1:-st}"
    local local_bin="$DEMO_DIR/../bin/$name"
    local resolved=""

    if [[ -x "$local_bin" ]]; then
        resolved="$(cd -- "$(dirname -- "$local_bin")" && pwd -P)/$(basename -- "$local_bin")"
    elif command -v "$name" > /dev/null 2>&1; then
        resolved="$(command -v "$name")"
    else
        printf 'demo-lib: cannot detect main script "%s"\n' "$name" >&2
        printf '  looked for: %s\n' "$local_bin" >&2
        printf '  and on PATH: %s\n' "$name" >&2
        return 1
    fi

    # Export an uppercased <NAME>_CMD variable so demo scripts can use $ST_CMD, $PI_CMD, ...
    local var_name
    var_name="$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')_CMD"
    # shellcheck disable=SC2229
    declare -g "$var_name=$resolved"
    printf -v "$var_name" '%s' "$resolved"
    export "${var_name?}"
    printf '%s\n' "$resolved"
}

# Default: detect the st project main script and export ST_CMD.
detect_main_script st || exit 1
