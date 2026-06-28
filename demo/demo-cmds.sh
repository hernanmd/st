#!/usr/bin/env bash
#
# demo-cmds.sh - Recorded demo of the `st` Smalltalk CLI.
#
# Run directly (./demo/demo-cmds.sh [options]) or via demo-record.sh.
#
# Playback options (forwarded by demo-record.sh):
#   -d, --debug       no simulated typing delay
#   -n, --no-wait     do not wait for ENTER between steps
#   -w, --wait N      auto-proceed N seconds after each step (0 = manual)
#   -t, --type N      typing speed in chars/sec (default 20); 0 = instant
#       --fast        shorthand for -d -n (instant, non-interactive playback)
#   -h, --help        show this help
#
# Environment overrides: DEMO_TYPE_SPEED, DEMO_NO_WAIT, DEMO_TIMEOUT
#
# The demo runs inside a throwaway sandbox. On exit (including Ctrl+C) the
# sandbox is destroyed and the repo is swept (demo/ and demo.cast are preserved).

set -Eo pipefail
IFS=$'\n\t'

DEMO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Source the libs with no positional params so demo-magic's getopts uses its
# defaults; restore our own args afterwards for parsing below.
_demo_args=("$@")
set --
# shellcheck source=demo-lib.sh
source "$DEMO_DIR/demo-lib.sh"
# shellcheck source=demo-cleanup.sh
source "$DEMO_DIR/demo-cleanup.sh"
set -- "${_demo_args[@]}"

# --- Sandbox: all st commands run inside a temp dir -------------------------
DEMO_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/st-demo.XXXXXX")" || {
    printf 'demo: cannot create sandbox directory\n' >&2
    exit 1
}
export DEMO_WORK_DIR
cd -- "$DEMO_WORK_DIR" || exit 1

# --- Playback options (override demo-magic defaults) -----------------------
# demo-magic.sh provides: TYPE_SPEED, NO_WAIT, PROMPT_TIMEOUT.
TYPE_SPEED="${DEMO_TYPE_SPEED:-20}"
NO_WAIT="${DEMO_NO_WAIT:-false}"
PROMPT_TIMEOUT="${DEMO_TIMEOUT:-0}"

_demo_usage() {
    cat <<EOF
Usage: $(basename -- "$0") [options]

Playback options:
  -d, --debug       no simulated typing delay
  -n, --no-wait     do not wait for ENTER between steps
  -w, --wait N      auto-proceed N seconds after each step (0 = manual)
  -t, --type N      typing speed in chars/sec (default 20); 0 = instant
      --fast        shorthand for -d -n (instant, non-interactive playback)
  -h, --help        show this help message

Environment overrides: DEMO_TYPE_SPEED, DEMO_NO_WAIT, DEMO_TIMEOUT
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)   TYPE_SPEED=""; shift ;;
        -n|--no-wait) NO_WAIT="true"; shift ;;
        -w|--wait)    PROMPT_TIMEOUT="${2:?--wait requires a number}"; shift 2 ;;
        -t|--type)    TYPE_SPEED="${2:?--type requires a number}"; shift 2 ;;
        --fast)       TYPE_SPEED=""; NO_WAIT="true"; shift ;;
        -h|--help)    _demo_usage; exit 0 ;;
        --)           shift; break ;;
        *) printf 'demo-cmds: unknown option: %s\n' "$1" >&2; _demo_usage; exit 2 ;;
    esac
done
# 0 typing speed => instant (pv with -qL 0 would hang, so clear it instead).
[[ "$TYPE_SPEED" == "0" ]] && TYPE_SPEED=""
export TYPE_SPEED NO_WAIT PROMPT_TIMEOUT

# --- Cleanup on exit / cancel (Ctrl+C) --------------------------------------
# EXIT: destroy the sandbox + sweep the repo once.
# INT/TERM (Ctrl+C / kill): run cleanup, then actually exit so the demo stops
# (the previous trap only cleaned up without exiting, so the demo resumed).
_DEMO_CLEAN_DONE=0
_demo_cleanup_once() {
    [[ $_DEMO_CLEAN_DONE -eq 1 ]] && return 0
    _DEMO_CLEAN_DONE=1
    demo_cleanup
}
_demo_on_signal() {
    _demo_cleanup_once
    exit 130
}
trap _demo_cleanup_once EXIT
trap _demo_on_signal INT TERM

# Route `st ...` to the detected main script. `command` bypasses this function
# so there is no recursion when ST_CMD is the bare name `st` (PATH install).
st() { command "$ST_CMD" "$@"; }

# demo-magic's wait() uses `read -rs`; the -s (silent) flag runs tcsetattr,
# which Ctrl+C interrupts with EINTR *without firing the trap* — so the demo
# could not be cancelled during a wait. Drop -s (use `read -r`) so the INT trap
# fires and Ctrl+C cancels. The ENTER keystroke may echo; acceptable for a demo.
wait() {
    if [[ "${PROMPT_TIMEOUT:-0}" == "0" ]]; then
        read -r
    else
        read -r -t "$PROMPT_TIMEOUT"
    fi
}

clear

pe "# List available implementations"
pe "st --list"

pe "# Evaluating an expression"
pe 'st pharo eval "3 + 4"'

pe "# Search for packages on GitHub"
pe "st pharo search BioSmalltalk"

pe "# Command-line handler help"
pe "st pharo metacello --help"

pe "# Install a package (Metacello baseline) and save the image"
pe "st pharo metacello install github://hernanmd/ISO3166/repository BaselineOfISO3166 --save"

pe "# Download, install, and run Squeak"
pe "st squeak run"

pe "# Query LittleSmalltalk v4 versions"
pe "st ls4 versions"

pe "# Start CLI interactive eval"
pe "st ls4 eval"

# (EXIT trap runs demo_cleanup, destroying the sandbox and sweeping the repo.)