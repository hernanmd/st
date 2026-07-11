---
name: st-workflow
description: Use the `st` CLI to install, run, and script Smalltalk implementations (Pharo, Cuis, GT, Squeak, GNU Smalltalk, Little Smalltalk v3/v4) in your own workflows — CI, Makefiles, shell scripts, and REPL-style headless eval. Covers install/upgrade/uninstall one-liners, per-dialect commands, headless eval, package install/search/list, caching, env vars, and the sudo/build-deps/PATH gotchas. Use when integrating `st` into automation or day-to-day Smalltalk work.
license: MIT
compatibility: Bash 4.0+, curl, jq (for package list/search), plus a Smalltalk VM/image per dialect you use. Linux, macOS, WSL.
metadata:
  project: st
---

# `st` — Smalltalk CLI in your workflows

`st` is a unified, pure-Bash CLI for installing and managing Smalltalk implementations
and their packages. This skill is for **users** who want to drive `st` from a shell,
a Makefile, CI, or an agent.

## Install / upgrade / uninstall

`st` installs **per-user** under `~/.st/st/bin` (not system-wide). The curl one-liner
fetches `install.sh` from `master`; `install.sh` then downloads the **latest release**
archive and unpacks it.

```bash
# install (first time)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hernanmd/st/master/install.sh)" _

# add to PATH (zsh example; use ~/.bash_profile for bash)
echo 'export PATH="$HOME/.st/st/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

# self-upgrade (reinstalls the latest release, backs up the old one)
st upgrade

# reinstall/force, check, uninstall (the '_' is the throwaway $0 for bash -c)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hernanmd/st/master/install.sh)" _ --force
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hernanmd/st/master/install.sh)" _ --check
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hernanmd/st/master/install.sh)" _ --uninstall
```

> The `_` placeholder matters: `bash -c "<script>" <name> <args…>` makes the first
> token `$0`. Without `_`, `--force`/`--uninstall` would be eaten as the script name.

## Dialects & commands at a glance

```
st <impl> <command> [args]
impl  ∈ pharo cuis gt squeak gnu lst ls4
cmd   ∈ install run eval load save metacello search list update clean clean-artifacts version help
```

Global flags (before the impl): `-x/--debug` (set -x), `-q/--quiet`, `-v/--verbose`,
`-y/--yes` (auto-confirm prompts, e.g. GNU sudo install), `--list`, `--version`, `--help`.

## Common workflow recipes

### Install and run a dialect
```bash
st pharo install                 # install Pharo (prebuilt)
st cuis  install                  # install Cuis stable
st gt    install                  # install Glamorous Toolkit
st pharo run                      # launch the UI
st cuis  run
```

### Headless eval (REPL-style, prints the result)
```bash
st pharo eval '1 + 2'             # -> 3   (Pharo/GT have a built-in eval that prints)
st gt    eval 'Smalltalk version'
st cuis  eval '1 + 2'             # Cuis: headless VM -d DoIt + Smalltalk quit (no hang)
```
- `st ls4 eval` drops into the LS4 REPL.
- `st squeak eval` / `st gnu eval` / `st lst eval`: command-line eval is **not supported** by those VMs — `st` says so (use Pharo/Cuis/GT for headless eval).

### Install / search / list packages (Pharo-style, GitHub `topic:` index)
```bash
st pharo update                  # refresh the package cache (paginated; fetches ALL repos)
st pharo list | grep -i json     # list packages
st pharo search polyglot         # search by term
st pharo install NeoCSV          # install a package into the Pharo image
st pharo install Seaside
st pharo metacello 'BaselineOfSeaside'
```
The cache lives at `~/.smalltalk-cache`; `st pharo clean` clears it.

### Scripting & CI
```bash
# CI: install, eval, capture output, exit code propagates
st pharo install && out="$(st pharo eval '1 + 2')"; [ "$out" = "3" ] && echo ok
# Makefile target
check:
	st pharo install
	st pharo eval 'Smalltalk version'
# loop over dialects
for d in pharo cuis gt; do st "$d" version; done
```

## Environment variables & flags
- `GITHUB_TOKEN` — optional; raises the GitHub Search rate limit (~30/min vs ~10/min unauth) for `st <impl> update/search`.
- `VERBOSE=1` (or `-v`), `QUIET=1` (`-q`), `DEBUG=1` (`-x`).
- `SMALLTALK_YES=1` (or `-y`) — auto-confirm prompts.
- Per-dialect version overrides where supported, e.g. `CUIS_VERSION=7.0 st cuis install`.

## Gotchas (read these before automating)

1. **Per-user install, not system-wide.** `st` is at `~/.st/st/bin`. Add it to PATH.
   `st upgrade` / `--force` back up the previous install to `~/.st/st.backup.<timestamp>`.
2. **Don't prefix `sudo` for dialects that need root.** `st gnu install` calls `sudo apt-get`
   **internally** and prompts for your password. Running `sudo st gnu install` fails
   (`sudo` resets `PATH` and can't find `~/.st/st/bin/st`). If you must run under sudo,
   use the absolute path: `sudo "$HOME/.st/st/bin/st" gnu install`.
3. **Source-build dialects need build tools** (LS4/LST `--build`/GNU `--source`):
   cmake, a C/C++ compiler, make, etc. If missing, `st` prints an **OS-tailored
   one-liner** (e.g. `sudo apt-get install -y cmake g++ make`) and aborts before
   downloading — just run that line and retry.
4. **GNU Smalltalk on Debian 12+/recent Ubuntu:** the `gnu-smalltalk` apt package was
   removed (upstream unmaintained). `st gnu install` offers a menu: build from source,
   or run it in a Debian 11 (bullseye) Docker container where apt still has it.
5. **GitHub rate limits / transient errors:** `st <impl> update` paces requests and
   retries transient transport errors. For heavy/listing use, set `GITHUB_TOKEN`.
6. **CDN cache:** `raw.githubusercontent.com/.../master/install.sh` and the
   `releases/latest` pointer lag a push by ~1 minute. If a fresh fix isn't visible
   immediately, wait a moment or re-run.

## Where to get help
```bash
st --help
st pharo help          # per-dialect help (loads doc/HELP_<impl>.md)
st --list              # list implementations
```