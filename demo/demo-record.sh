#!/usr/bin/env bash
#
# demo-record.sh - Record an asciinema cast of the `st` demo.
#
# Writes demo.cast next to this script (location-independent): demo/demo.cast.
# Any previous demo.cast is removed first, so each run produces a fresh recording.
#
# Usage:
#   ./demo/demo-record.sh                 # interactive (type + wait for ENTER)
#   ./demo/demo-record.sh --fast          # instant, non-interactive playback
#   ./demo/demo-record.sh -w 2            # auto-advance every 2s
#   ./demo/demo-record.sh -d -n           # no typing delay, no waits
#
# Extra args are forwarded to demo-cmds.sh; see `./demo/demo-cmds.sh --help`.
# Ctrl+C cancels the demo and finalizes the (partial) cast.
#
# Requires: asciinema (recording), pv (typing simulation in demo-magic.sh).

set -Eo pipefail
IFS=$'\n\t'

DEMO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CAST="$DEMO_DIR/demo.cast"
CMD_SCRIPT="$DEMO_DIR/demo-cmds.sh"

# Remove any previous recording so asciinema never refuses with
# "file exists, use --overwrite or --append".
rm -f -- "$CAST"

# Forward args to demo-cmds.sh, shell-quoted (handles values with spaces too).
quoted=""
for a in "$@"; do quoted+=" $(printf '%q' "$a")"; done

# Plain bash (not a login shell) so user profiles don't shadow the demo.
# demo-cmds.sh resolves its own location, so the working directory is irrelevant.
exec asciinema rec "$CAST" -c "bash '$CMD_SCRIPT'$quoted"
