# st Demo Recording

Asciinema-based demo of the `st` Smalltalk CLI, scripted with
[demo-magic.sh](https://github.com/paxtonhare/demo-magic) (simulated typing).

## Files

| File | Role |
|------|------|
| `demo-magic.sh` | Vendored typing-simulation library (defines `pe`, `p`, `pei`, `cmd`). |
| `demo-lib.sh` | Shared bootstrap: sources `demo-magic.sh` by absolute path (fixes the `pe: command not found` bug) and detects the project main script. |
| `demo-cmds.sh` | The demo script: the sequence of `st` commands to type/run. |
| `demo-record.sh` | Records `demo-cmds.sh` into `demo.cast` via `asciinema rec`. |
| `demo-cleanup.sh` | Destroys demo-created Smalltalk artifacts so the repo stays clean. |
| `demo.cast` | Generated recording (gitignored). |

## Automatic cleanup (no repo pollution)

The demo never pollutes the repository:

1. **Sandbox.** `demo-cmds.sh` runs every `st` command inside a throwaway temp
   directory (`mktemp -d .../st-demo.XXXXXX`). All installations, images, VMs, and
   caches that `st` creates land there, never in the repo.
2. **Trap.** An `EXIT`/`INT`/`TERM` trap calls `demo_cleanup` (from
   `demo-cleanup.sh`), which destroys the sandbox.
3. **Defensive sweep.** `demo-cleanup.sh` also scans the repo root for `st`
   artifact patterns (`Pharo*.image`, `pharo-*_*`, `github-cache/`, `*.fuel`,
   …) and removes them — but it **never** touches `demo/`, `demo.cast`,
   `bin/`, or `libexec/`.

So after a run the repository is clean except for the freshly written `demo.cast`.

The global `~/.smalltalk-cache` and `~/.smalltalk-manifest.json` are shared across
projects, so they are left untouched by default. To wipe them too (affects **all**
`st` installations on the machine), opt in:

```bash
DEMO_CLEAN_GLOBAL=1 ./demo/demo-cleanup.sh
```

You can also run cleanup manually (e.g. to recover from an interrupted demo):

```bash
./demo/demo-cleanup.sh                       # remove sandbox + sweep repo
DEMO_WORK_DIR=/path/to/sandbox ./demo/demo-cleanup.sh   # remove a specific sandbox
```

## Prerequisites

```bash
brew install asciinema pv      # macOS
# or: apt install asciinema pv # Debian/Ubuntu
```

`pv` is required by `demo-magic.sh` for the typing effect; `demo-magic.sh` aborts
with install instructions if it is missing.

## Record a demo

```bash
./demo/demo-record.sh                 # interactive: types each line, waits for ENTER
./demo/demo-record.sh --fast          # instant, non-interactive playback (no typing/waits)
./demo/demo-record.sh -w 2            # auto-advance every 2 seconds
./demo/demo-record.sh -d -n            # no typing delay, no ENTER waits
```

Any extra args are forwarded to `demo-cmds.sh` — see `./demo/demo-cmds.sh --help`
for all playback options (`-d/--debug`, `-n/--no-wait`, `-w/--wait N`,
`-t/--type N`, `--fast`). You can also set `DEMO_TYPE_SPEED`, `DEMO_NO_WAIT`,
and `DEMO_TIMEOUT` environment variables.

To play it back:

```bash
asciinema play demo/demo.cast
```

You can also run the demo without recording (press ENTER to step through each command):

```bash
./demo/demo-cmds.sh
```

### Canceling a run

Press **Ctrl+C** at any point to cancel the demo. It cleans up the sandbox
(destroying any demo-created Smalltalk install) and exits with code 130;
asciinema then finalizes the (partial) cast. `./demo/demo-record.sh` always
removes any previous `demo.cast` before recording, so just re-run to retry.

## How the `pe` bug was fixed

The original `demo-cmds.sh` sourced demo-magic with a broken path:

```bash
. /$HOME/demo/demo-magic.sh     # => //Users/.../demo/demo-magic.sh: No such file
```

The leading `/` plus `$HOME` produced a path that never existed, so `pe` was never
defined and every line printed `pe: command not found` (see the old `demo.cast`).

Now `demo-lib.sh` resolves its own directory and sources demo-magic by absolute path:

```bash
DEMO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$DEMO_DIR/demo-magic.sh"
```

The scripts are fully location-independent: you can run them from any directory and
they still find each other and the project root.

## Detecting the main script

`demo-lib.sh` exposes `detect_main_script [<name>]` (default `st`). It resolves, in order:

1. The project-local build: `$DEMO_DIR/../bin/<name>` (e.g. `../bin/st`).
2. The executable on `PATH` (e.g. a globally installed `st`).
3. Failure with a clear message.

The resolved path is exported as an uppercased `<NAME>_CMD` variable
(`st` → `ST_CMD`, `pi` → `PI_CMD`).

`demo-cmds.sh` uses the default (`st`) and wraps it in a thin `st()` function so the
recording reads as `st ...` while actually invoking the local `bin/st` when present.

### Detecting `pi` (or any other main script)

The detector is generic, so it can locate any main script — including the
[`pi`](https://github.com/earendil-works/pi-coding-agent) agent harness binary:

```bash
source demo/demo-lib.sh   # sources demo-magic.sh too (needs pv)
detect_main_script pi      # prints the pi path and exports PI_CMD
echo "$PI_CMD"
```

To demo a different tool, copy `demo-cmds.sh`, call `detect_main_script <name>`, and
wrap `<name>` the same way `st` is wrapped here.