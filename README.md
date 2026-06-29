[![license-badge](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
[![ShellCheck](https://github.com/hernanmd/st/actions/workflows/ci.yml/badge.svg)](https://github.com/hernanmd/st/actions/workflows/ci.yml)

# Table of Contents

- [Description](#description)
- [Demo](#demo)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Common steps](#common-steps)
  - [Bash users](#bash-users)
  - [Zsh users](#zsh-users)
- [Features](#features)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Contribute](#contribute)
- [Change Log](./CHANGELOG.md)
- [Develop](#develop)
- [License](./LICENSE)

# Description

**st** - A unified command-line tool for installing and managing multiple Smalltalk implementations.

Supported implementations:
- **Pharo** - Modern, full-featured Smalltalk (https://pharo.org)
- **Cuis** - Compact, portable Smalltalk (https://cuis.st)
- **GT (Glamorous Toolkit)** - Multi-language IDE built in Pharo (https://gtoolkit.com)
- **Squeak** - Open-source Smalltalk environment (https://squeak.org)
- **GNU Smalltalk** - Classic Smalltalk-80 implementation (https://gnu.org/software/smalltalk)
- **LST (Little Smalltalk v3)** - Simplified Smalltalk for learning (https://codeberg.org/suetanvil/lst3r)

The CLI provides a consistent interface for installing, running, and managing packages across all these implementations.

# Demo

![smalltalk-session](https://github.com/user-attachments/assets/c0c4cd8c-0226-4f24-9766-ee54ff43358d)

# Requirements

  - bash or zsh (4.0+)
  - curl or wget (for downloading)
  - unzip (for extracting archives)
  - git (for cloning repositories)
  - jq (optional, for better JSON parsing)

### Installing dependencies

**macOS:**
```bash
brew install jq git
```

**Debian/Ubuntu:**
```bash
sudo apt install jq git curl unzip
```

**Fedora/RHEL:**
```bash
sudo dnf install jq git curl unzip
```

**Arch Linux:**
```bash
sudo pacman -S jq git curl unzip
```

**Windows (WSL/MSYS2/Git Bash):**
```bash
# Using MSYS2 or Git Bash
pacman -S jq git curl unzip

# Using Chocolatey (run in elevated PowerShell)
choco install jq git curl unzip

# Using Scoop
scoop install jq git curl unzip
```

**Windows Notes:**
- For Pharo, Cuis, Squeak, and GT: Windows is fully supported
- For GNU Smalltalk: Works under WSL (Windows Subsystem for Linux)
- For Little Smalltalk: Some limitations on Windows - prefer WSL or use prebuilt binaries

# Installation

## Common steps

The first step is to download the package from a command line terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hernanmd/st/master/install.sh)"
```

The next step is to configure your PATH variable to find the command. To find which shell you are using now, type:

```bash
echo $0
```

## bash users

To persist usage between multiple shell sessions:
```bash
echo "export PATH=$HOME/.st/st/bin:$PATH" >> ~/.bash_profile
source ~/.bash_profile
```

## zsh users

To persist usage between multiple shell sessions:
```bash
echo -n 'export PATH=$HOME/.st/st/bin:$PATH' >> ~/.zshrc
source ~/.zshrc
```

# Features

  - **Unified CLI** - One command for all Smalltalk implementations
  - **Install packages** - Easy installation of packages from various sources
  - **Package search** - Search for available packages
  - **Image management** - Download and manage Smalltalk images/VMs
  - **Cross-platform** - Works on Linux, macOS, and Windows (WSL/MSYS2)

# Capabilities Matrix

| Implementation | Linux | macOS | Windows | Install Packages | Eval | Run Scripts | Headless |
|---------------|:-----:|:-----:|:-------:|:----------------:|:----:|:-----------:|:--------:|
| **Pharo** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Cuis** | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| **GT** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Squeak** | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| **GNU Smalltalk** | ✅ | ✅ | ⚠️ (WSL) | ❌ | ✅ | ✅ | ✅ |
| **Little Smalltalk** | ✅ | ✅ | ⚠️ | ❌ | ✅ | ✅ | ✅ |

**Legend:**
- ✅ Fully supported
- ⚠️ Partially supported / limited functionality
- ❌ Not supported
- WSL = Windows Subsystem for Linux required

**Notes:**
- **Pharo**: Full CLI support including headless mode via `--headless` flag
- **Cuis/Squeak**: Limited CLI support - primarily GUI-based; package installation via GUI
- **GT**: Full CLI support for automation and scripting
- **GNU Smalltalk**: Script-based, no image - runs directly from command line
- **Little Smalltalk**: Minimal implementation with basic REPL support

# Usage Examples

## Global Options

```bash
st -x pharo install          # Enable debug mode (set -x tracing)
st --debug pharo install     # Same as -x
st --version                 # Show version
st --help                    # Show help
```

## Installing Smalltalk Implementations

### Pharo
```bash
st pharo install              # Install Pharo
st pharo install -d ~/pharo  # Install to specific directory
st pharo install Seaside     # Install Pharo with Seaside package
st pharo run                  # Run Pharo
```

### Cuis
```bash
st cuis install               # Install Cuis
st cuis install -d ~/cuis    # Install to specific directory
st cuis run                   # Run Cuis
```

### Glamorous Toolkit
```bash
st gt install                 # Install Glamorous Toolkit
st gt install -d ~/gt         # Install to specific directory
st gt run                     # Run GT
```

### Squeak
```bash
st squeak install             # Install Squeak
st squeak install -d ~/squeak # Install to specific directory
st squeak run                 # Run Squeak
```

### GNU Smalltalk
```bash
st gnu install              # Install via package manager
st gnu install --source     # Build from source
st gnu run script.st        # Run a GNU Smalltalk script
```

### Little Smalltalk v3
```bash
st lst install              # Download prebuilt binary
st lst install --build     # Build from source
st lst run                 # Start REPL
st lst run script.lst3     # Run a .lst3 file
```

## Package Management

### Search for packages
```bash
st pharo search polyglot    # Search Pharo packages
st pharo search seaside     # Search for Seaside
```

### List available packages
```bash
st pharo list               # List cached packages
st pharo update             # Update package cache
```

### Install packages
```bash
st pharo install NeoCSV     # Install NeoCSV package
st pharo install Seaside    # Install Seaside
```

## Help

Get help for any implementation:
```bash
st                    # Show general help
st pharo help         # Show Pharo-specific help
st gt help           # Show GT-specific help
st --help            # Show general help
```

# Troubleshooting

If you experience problems, please run the collect environment script:

```bash
./tests/runStCollectEnv
```

And open an issue with the output in the [Issue Tracker](https://github.com/hernanmd/st/issues)).

You can obtain the version with:

```bash
st --version
```

# Contribute

**Working on your first Pull Request?** You can learn how from this *free* series [How to Contribute to an Open Source Project on
GitHub](https://egghead.io/series/how-to-contribute-to-an-open-source-project-on-github)

If you have discovered a bug or have a feature suggestions, feel free to create an issue on Github.

If you'd like to make some changes yourself, see the following:

  - Fork this repository to your own GitHub account and then clone it to your local device
  - Edit files in the `bin/` and `libexec/` directories with your favorite text editor
  - Test the CLI
  - Add <your GitHub username> to add yourself as author below
  - Finally, submit a pull request with your changes!
  - This project follows the [all-contributors specification](https://github.com/kentcdodds/all-contributors). Contributions of any kind are welcome!

# Develop

## Prerequisites

- bash 4.0+
- [bats-core](https://github.com/bats-core/bats-core) for running tests
- [ShellCheck](https://github.com/koalaman/shellcheck) for static analysis
- [shfmt](https://github.com/mvdan/sh) for formatting
- [jq](https://stedolan.github.io/jq/) (optional, for better JSON parsing)
- curl or wget (for downloading)
- unzip (for extracting archives)
- git (for cloning repositories)

## Quick Development Commands

```bash
# Run all checks (lint + test)
make check

# Run tests only
make test

# Run linters only
make lint

# Format all shell scripts
make format

# Run security scan
make security

# Clean build artifacts
make clean

# Run directly from source
./bin/st pharo help
```

## Adding a new Smalltalk implementation

1. Create a new file `libexec/smalltalk-<impl>.sh`
2. Start with the standard header:
   ```bash
   #!/usr/bin/env bash
   #
   # smalltalk-<impl>.sh - <Implementation> implementation
   #
   set -Eeuo pipefail
   IFS=$'\n\t'
   # shellcheck source=libexec/smalltalk-common.sh
   source "${BASH_SOURCE%/*}/smalltalk-common.sh"
   ```
3. Implement the required functions:
   - `smalltalk_<impl>_install`
   - `smalltalk_<impl>_run`
   - `smalltalk_<impl>_search`
   - `smalltalk_<impl>_list`
   - `smalltalk_<impl>_update`
   - `smalltalk_<impl>_clean`
   - `smalltalk_<impl>_version`
   - `smalltalk_<impl>_help`
4. Add the implementation to the validation in `bin/st`
5. Add help documentation in `doc/HELP_<impl>.md`
6. Add tests in `tests/test-smalltalk.bats`
7. Run `make check` to verify

## Coding Standards

- Use `set -Eeuo pipefail` and `IFS=$'\n\t'` at the top of every script
- Quote all variable expansions: `"$var"` not `$var`
- Use `printf` over `echo` for output
- Use `--` separator with `rm`, `mv`, `cp`: `rm -rf -- "$dir"`
- Use `$(...)` not backticks for command substitution
- Use `[[ ]]` for conditionals (Bash-specific)
- Use `readonly` for constants, `local` for function variables
- Validate all external input before use
- Register temp files with `make_temp_file`/`make_temp_dir` for cleanup
- Use `log_info`, `log_error`, `log_success`, `log_warn`, `log_debug` for output
- Use `die` for fatal errors
- All scripts must pass `shellcheck --severity=warning --external-sources`

## To add tests

- Have a look at [bats](https://github.com/bats-core/bats-core)
- Check the .bats files in the tests directory
- Run tests: `make test` or `./tests/runSmalltalkTests`

## To deploy a new release

- Install [release-it](https://www.npmjs.com/package/release-it)
  - As global
    - brew: `brew install release-it`
    - npm: `npm install -g release-it`
- Copy or setup a [GitHub token](https://github.com/settings/tokens)
- Evaluate `export GITHUB_TOKEN=...` with the scoped token as value. Alternatively, log-in to your GitHub account with your web browser and release-it will authenticate.
- Ensure NVM is installed and accessible running: `source ~/.nvm/nvm.sh`
- To interactively deploy run `./libexec/deploy.sh` or `make release`
