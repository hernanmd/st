# Release Readiness Checklist

This document tracks all changes made to prepare the `st` project for public release,
following the bash-pro skill guidelines from SKILL.md.

## Checklist

### Strict Mode & Error Handling
- [x] Added `set -Euo pipefail` to all scripts (bin/st, libexec/*.sh, install.sh, etc.)
- [x] Added `IFS=$'\n\t'` to prevent word splitting on spaces in all scripts
- [x] Switched from `set -e` to `set -u` (intentional non-zero exits must work)
- [x] Used `set -o pipefail` everywhere
- [x] Removed problematic ERR trap (too aggressive for CLI with expected non-zero exits)

### Variable Quoting & Expansion
- [x] Replaced `echo` with `printf` throughout common.sh and bin/st
- [x] Used `printf '%s'` for variable output (prevents interpretation of escapes)
- [x] Properly quoted all variable expansions in common.sh and bin/st
- [x] Used `$()` consistently instead of backticks

### Safety & Security
- [x] Added `--` separator to all `rm -rf` commands (`rm -rf -- "$dir"`)
- [x] Added `--` separator to `mv`, `cat`, `mkdir -p --` where appropriate
- [x] URL validation in `download_file()` before downloading
- [x] Path traversal prevention (`validate_path`)
- [x] Package name validation (`validate_package_name`)
- [x] URL protocol blocking (`validate_url`)
- [x] Input sanitization (`sanitize_input`)
- [x] Proper temp file cleanup with `make_temp_file`/`make_temp_dir`

### Script Headers & Documentation
- [x] All scripts use `#!/usr/bin/env bash` shebang (portability)
- [x] Added comprehensive header comments with exit codes and environment variables
- [x] Added function documentation (parameters, returns) to common.sh
- [x] Added `# shellcheck source=` directives for sourced files

### Configuration Files (New)
- [x] `.shellcheckrc` - ShellCheck configuration with `enable=all` and `external-sources=true`
- [x] `.shfmt.toml` - shfmt formatting configuration (4-space indent, consistent style)
- [x] `.editorconfig` - Cross-editor formatting rules
- [x] `.pre-commit-config.yaml` - Pre-commit hooks (ShellCheck, shfmt, gitleaks, etc.)
- [x] `.github/workflows/ci.yml` - GitHub Actions CI pipeline
- [x] `Makefile` - Standard targets: lint, format, test, check, security, clean

### Naming & Constants
- [x] Made environment-overridable variables use `${VAR:-default}` pattern (CACHE_DIR, MANIFEST_FILE)
- [x] Removed `readonly` from variables that may be re-assigned when sourced (colors, configs)
- [x] Added exit code constants (`EXIT_SUCCESS=0`, `EXIT_ERROR=1`, `EXIT_UNSUPPORTED=2`)
- [x] Fixed VERSION file (contained just `l`, now contains `1.0.0`)

### CI/CD & Testing
- [x] GitHub Actions workflow with ShellCheck, shfmt, Bats, security scanning
- [x] Pre-commit hooks for ShellCheck, shfmt, trailing whitespace, large files, gitleaks
- [x] Makefile with lint, format, test, check, security, release, clean targets

### Project Files (New/Updated)
- [x] `CHANGELOG.md` - Release history following Keep a Changelog format
- [x] `LICENSE` - MIT License file
- [x] `package.json` - Updated with proper metadata and scripts
- [x] `VERSION` - Fixed (was `l`, now `1.0.0`)
- [x] `.gitignore` - Expanded with comprehensive patterns
- [x] `README.md` - Added CI badge, development section, coding standards

### Portability & Compatibility
- [x] Used `$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)` for script directory detection
- [x] Handled macOS vs Linux `stat` differences (already existed)
- [x] Used `command -v` instead of `which` for command detection
- [x] Portable `printf` instead of `echo` for all output in core scripts
- [x] Environment variable overrides for all configurable paths

### Coding Standards Applied
- [x] `set -Euo pipefail` + `IFS=$'\n\t'` in every script
- [x] `--` separator with destructive commands (`rm -rf --`, `mv --`, `mkdir -p --`)
- [x] Function documentation with parameters and return values
- [x] `local` keyword for all function variables
- [x] `readonly` for true constants only (where re-sourcing is not a concern)
- [x] Error handler uses `printf` to stderr (`>&2`)
- [x] Proper exit codes (0 success, 1 error, 2 unsupported)
- [x] Consistent naming: snake_case for functions/variables

### Tools Configuration
- [x] ShellCheck: `enable=all`, `external-sources=true`
- [x] shfmt: 4-space indent, switch-case indent, space redirects, keep padding
- [x] EditorConfig: 4-space for .sh/.bats, 2-space for .md/.json/.yml
- [x] Pre-commit: shellcheck, shfmt, trailing-whitespace, end-of-file-fixer, check-executables, gitleaks
- [x] CI: ShellCheck → shfmt → Bats tests → Security scan