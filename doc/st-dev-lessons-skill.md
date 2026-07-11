---
name: st-dev-lessons
description: Operational lessons and abstract patterns for developing the `st` universal Smalltalk installer — debugging installer/dialect bugs, shipping fixes, and adding new Smalltalk implementations. Distills the two-shipping-surfaces model, GitHub-API limits & resilient fetching, tar/strict-mode pitfalls, OS-tailored build-dep hints, per-dialect binary-location normalization, headless-eval mechanisms per VM, the sudo/PATH/per-user-install contract, and the release/verification discipline. Use when fixing `st`, shipping a fix, or adding a dialect; pairs with the st-installer-dev (procedural) and bash-pro (bash conventions) skills.
license: MIT
compatibility: Bash 4.0+, shellcheck, shfmt, jq, git, gh, release-it (for releases). Linux/macOS/WSL.
metadata:
  project: st
---

# Developing `st` — operational lessons & patterns

These are the abstract, reusable lessons learned from developing `st`. They are
*operational* (tell you what to do/check) and *abstract* (apply to future bugs,
features, and new dialects), not step-by-step recipes — pair with `st-installer-dev`
for the per-step "add a dialect" flow and `bash-pro` for bash conventions.

## 1. The two shipping surfaces (the most important mental model)

`st` ships through **two independent surfaces**. Always ask *which surface* a fix
touches before declaring it done:

- **`install.sh` (master)** — the curl one-liner fetches
  `raw.githubusercontent.com/hernanmd/st/master/install.sh` directly from `master`.
  A fix to `install.sh` takes effect on the user's next reinstall (after ~1 min CDN
  cache) — **no release required**.
- **The payload (`bin/st`, `libexec/smalltalk-*.sh`, `install.sh`-as-shipped)** —
  `install.sh` downloads the **latest release tag** archive
  (`github.com/hernanmd/st/archive/<tag>.tar.gz`). A fix to `bin/st` or
  `libexec/*.sh` only reaches users after you **cut a new release**.

Lesson: "it works on master" is **not** "users have it". If the bug is in
`libexec/` or `bin/`, you must release. This bit us repeatedly (a `master` fix that
didn't help users still on the stale release tag).

Corollaries:
- GitHub's `releases/latest` pointer lags a new tag by seconds-to-a-minute; **poll**
  `releases/latest` until it flips to the new tag before declaring the release done.
- `st upgrade` (which re-runs `install.sh --force`) only pulls the *latest release*;
  users on an old release get the new code only once `latest` points at it.

## 2. GitHub API limits & resilient fetching

- **Search API caps at 1000 results per query.** To enumerate more (e.g. all
  `topic:pharo` repos), walk in `created`-asc order; when a window hits the 1000 cap,
  narrow with `created:>=<last item's date>` and fetch the next window. Use `>=` so
  windows overlap at the boundary (no repo lost), then **dedup by `id`**
  (order-preserving) when merging. (`update_monticello_packages`.)
- **Rate limit:** unauthenticated Search ≈ 10 req/min → pace ~7s between requests;
  authenticated (`GITHUB_TOKEN`) ≈ 30/min. `per_page=100`, paginate with `&page=N`.
- **Transient transport errors** (curl 56 SSL eof, timeouts, resets): retry on the
  downloader's **exit code** (a few attempts + backoff). Do **not** retry HTTP 4xx —
  without `-f`, curl/wget return 0 and save the body, so a 403 rate-limit returns
  "success"; detect it via empty `items` + `.message` and stop gracefully. (`download_file`.)
- `total_count` from the API can legitimately differ from the count on a
  `github.com/topics/<x>` page (searchability/indexing) — trust the API number.

## 3. Defensive-bash pitfalls that actually bit us

- **`set -u` + unbound vars:** use `${VAR:-}` for optional vars. Under
  `bash -c "$(curl …)"`, `BASH_SOURCE[0]` is unset → use `${BASH_SOURCE[0]:-$0}`.
- **`tar` needs `-f` to read a file.** `tar -xzf -- "$file"` is **broken** (`-f`
  greedily grabs `--` as the archive name); `tar -x "$file"` reads from **stdin**
  ("Refusing to read archive contents from terminal"). Use
  `tar -xzf "$file" -C "$dir"`. This hit *both* `install.sh` unpack and
  `extract_archive` — grep every `tar` invocation for a missing `-f`.
- **Don't `find` the extracted dir among backups.** Extracting into the install base
  and then `find … -name "st*"` matches `st.backup.*` too; on `--force` this
  **restored the old install over the fresh one**. Extract into a **clean temp dir**
  and move the single top-level dir into place.
- **shfmt** wants `2> /dev/null` (space after `>`); run `make format` before `make lint`.
- No `set -e` in CLI scripts (commands intentionally return non-zero); handle with
  `||`/`die`. Quote every expansion; `--` on `rm`/`mv`/`cp`; `printf` over `echo`.

## 4. Build-tool dependencies (source dialects: gnu `--source`, lst `--build`, ls4)

- **Pre-check** required tools **before** downloading — fail fast with an actionable
  hint, not a raw `cmake: command not found` mid-build.
- **OS-tailored install one-liner** via `suggest_install_packages` (in
  `smalltalk-common.sh`): map tool→package per package manager. Real traps:
  - `libtool` **command** is in `libtool-bin` on apt (the `libtool` package only
    ships m4 macros); `libtool` on dnf/pacman/brew.
  - `g++`→`gcc-c++` on dnf, but `gcc`→`gcc` (C vs C++ compiler distinction);
    `clang`/`clang++`→`llvm` on brew.
  - `bison`/`flex`/`gettext` map to the same name on all PMs (use the default).
- Check for a C compiler (`gcc` **or** `clang`) vs a C++ compiler (`g++` **or**
  `clang++`) depending on what the dialect's source is written in (LS4 is C++, LST is C).

## 5. Per-dialect binary location & normalization

Pick **one canonical location** for the built binary and make install,
`is_<impl>_installed`, `run_<impl>`, and `version` **all** agree on it. LST built
`lst3` at the install root but the post-build check looked in `./build/` → "binary
not found" *after a successful build*. **Normalize** after build (e.g. move
`./build/X` up to the root) so the rest of the code finds it unchanged rather than
special-casing every reader.

## 6. Headless eval — per VM (don't fake it)

- **Pharo / GT** have a built-in `eval` that prints the result:
  `<vm> --headless <image> eval "<code>"`.
- **Cuis has no built-in eval.** `<vm> -headless <image> -s file.st` **hangs** (the
  image ignores `-s` and enters the event loop). Use the VM **`-d` (DoIt)** flag
  (documented Cuis CookBook pattern):
  `<vm> -headless <image> -d "StdIOWriteStream stdout nextPutAll: (<code>) printString; newLine; flush." -d "Smalltalk quit."`
  — `StdIOWriteStream stdout` (the `stdout` accessor) + `flush` are required for
  real stdout; `Smalltalk quit.` exits. Add `timeout N` as a safety net.
  `$code` substitutes **verbatim** (bash doesn't recursively expand → `$a` char
  literals and `"…"` comments are preserved; backticks/`$()` are not executed).
- **Squeak / GNU / LST** don't support command-line eval → `smalltalk_<impl>_eval`
  should **say so clearly** (point to Pharo/Cuis/GT). Don't ship a half-working eval.

## 7. sudo, PATH, and the per-user-install contract

- `st` installs **per-user** under `~/.st/st/bin` (never system-wide). Users add it
  to PATH; `--force` backs up to `~/.st/st.backup.<ts>`; `--uninstall` removes.
- Dialects that use a package manager (GNU `apt`) call `sudo` **internally** and
  prompt for the password. Users must **not** prefix `sudo st …`: `sudo` resets
  `PATH` (`secure_path`) and can't find `st`. Absolute-path fallback for when sudo is
  truly needed: `sudo "$HOME/.st/st/bin/st" <impl> <cmd>`.

## 8. Adding a new Smalltalk implementation (abstract recipe)

1. **`libexec/smalltalk-<impl>.sh`** implementing
   `smalltalk_<impl>_{install,run,eval,search,list,update,clean,clean_artifacts,version,help}`.
   **Reuse `smalltalk-common.sh`** — don't reinvent: `download_file` (retry),
   `extract_archive` (uses `-f`), `get_os`/`get_arch`, `suggest_install_packages`,
   `cmd_exists`, `log_*`/`die`, the cache dir, `register_install`/`is_*_installed`.
2. **Source build?** Add a pre-build tool check (§4); pick + normalize the binary
   location (§5).
3. **Headless eval?** Implement it correctly for that VM (§6); if unsupported, say so.
4. **Wire into `bin/st`:** add `<impl>` to the dispatch `case`, the IMPLEMENTATIONS
   list, the `clean_artifacts` impl allow-list, and `--help` COMMANDS/EXAMPLES.
5. **Docs/tests:** `doc/HELP_<impl>.md` (loaded by `load_help_from_doc`), README
   dialect matrix, Makefile `.PHONY`/help targets, Bats tests under `tests/`.
6. **Ship via a release** (§1) — a new dialect in `libexec/` only reaches users after
   a release tag.

## 9. Release & verification discipline

- Before release: `make lint` (shellcheck `--severity=warning` + shfmt) and
  `make check`/`make test` (bats) must pass.
- **Test the real code path with mocks** (the single most effective technique):
  extract a function with `eval "$(awk '/^func\(\)/,/^}/' libexec/<file>.sh)"`,
  then call it with mocked deps (`get_os`, `cmd_exists`, `download_file`, `log_*`,
  `die`). This catches logic bugs **without** needing the real VM/network. Reproduce
  the user's exact scenario in an isolated `$HOME` before fixing.
- **Release:** `release-it <ver> --ci` with `GITHUB_TOKEN=$(gh auth token)`, tools
  resolved via `npx -p release-it@^19 -p auto-changelog -p @release-it/conventional-changelog`.
  The `after:github:release` hook auto-publishes `checksums.txt` (so `install.sh`
  can verify the tarball).
- **Dry-run gotcha:** `release-it --dry-run` still executes `npm version`, bumping
  `package.json` as a side effect → the real run then fails with
  `npm error Version not changed`. Revert `package.json` after a dry-run, or skip it.
- **Verify the release:** tag → master HEAD; `gh release view <tag> --json assets`
  shows `checksums.txt`; fetch the archive's changed file **at the tag** and assert
  the fix is present; poll `releases/latest` until it flips to the new tag.

## 10. Principles

- The **live behavior** is the source of truth; test the real code path, not a paraphrase.
- Ask **"which shipping surface?"** (master `install.sh` vs release payload) before
  declaring a fix done.
- **Respect external limits** (GitHub search cap, rate limits, CDN cache) — design
  for them (paginate/split, pace, retry, poll) rather than fight them.
- **Fail fast with actionable, OS-tailored hints** — never let a user see a raw
  `command not found` or an unexplained hang.
- **One canonical location / one contract per concern** — normalize to it; don't
  special-case every reader.
- **Reuse `smalltalk-common.sh`** for download/extract/OS-detect/dep-hints/caching.
- **Defensive bash**: strict mode (`set -Euo pipefail`, no `-e`), quote everything,
  `--` on file ops, `printf` over `echo`, `${VAR:-}` for optional vars.