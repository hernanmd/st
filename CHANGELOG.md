# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-01

### Added
- Unified CLI for 7 Smalltalk implementations: Pharo, Cuis, GT, Squeak, GNU, LST, LS4
- Install, run, eval, search, list, update, clean commands for each implementation
- Metacello baseline support for Pharo and GT
- Package search via GitHub API with rate limiting
- Cross-platform support (Linux, macOS, Windows/WSL)
- ARM64/Apple Silicon support for Pharo and GT
- Automatic architecture detection
- Timestamped installation directories
- Manifest-based artifact tracking
- Package installation for Pharo
- Fuel serialization support for Pharo
- Version-specific downloads for Squeak (stable, 6.1, 6.0, 5.3)
- Source build support for GNU Smalltalk and LST
- Comprehensive help documentation per implementation
- Quiet mode (`-q`), verbose mode (`-v`), debug mode (`-x`)
- NO_COLOR support for non-interactive environments
- Temp file cleanup on exit
- Path traversal prevention security
- URL validation for downloads
- Package name validation
- ShellCheck and shfmt compatible codebase

### Changed
- Improved error handling with `set -Eeuo pipefail`
- Standardized exit codes (0=success, 1=error, 2=unsupported)
- Replaced `echo` with `printf` for consistent output
- Added `--` safety to `rm` commands
- Improved quoting of all variable expansions
- Added `IFS=$'\n\t'` to prevent word splitting
- Added error handler with stack traces on ERR
- Made all temp file operations use tracked cleanup
- Improved macOS/Linux stat compatibility

### Security
- Added path traversal prevention in `validate_path`
- Added URL protocol validation in `validate_url`
- Added package name sanitization in `validate_package_name`
- Added input length limits (255 chars for package names)
- Added checksum verification in install.sh
- Added root check prevention in install.sh
- Added script integrity check in install.sh

### Fixed
- Fixed unbound variable errors in GNU and LST install commands
- Fixed quoting issues in version detection
- Fixed temp file cleanup on interrupt signals
- Fixed Squeak All-in-One extraction on all platforms
- Fixed GT architecture detection for ARM64 Macs

### Infrastructure
- Added GitHub Actions CI workflow
- Added pre-commit hooks configuration
- Added ShellCheck configuration (.shellcheckrc)
- Added shfmt configuration (.shfmt.toml)
- Added EditorConfig for consistent coding style
- Added Makefile with lint, format, test, security, release targets
- Added comprehensive Bats test suite