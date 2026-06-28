# Pharo Smalltalk Commands

## Usage

```bash
st [-x] pharo <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [-d dir] [packages...]` | Install Pharo with optional packages |
| `run` | Launch the Pharo UI |
| `eval '<code>'` | Evaluate Smalltalk code (headless); installs Pharo if not present |
| `load <file.st>` | Load and execute a .st source file; installs Pharo if not present |
| `save [name]` | Save the Pharo image; installs Pharo if not present |
| `metacello <spec>` | Install a Metacello baseline/configuration; installs Pharo if not present |
| `fuel <file.fuel>` | Load a Fuel serialization file; installs Pharo if not present |
| `search <term>` | Search for packages |
| `list` | List available packages (cached) |
| `update` | Update package cache |
| `clean` | Clean cache directory |
| `clean-artifacts` | Clean installed artifacts |
| `version` | Show Pharo version |
| `help` | Show this help message |

## Clap Commands

Pharo's command-line handler ([Clap](https://github.com/pharo-project/pharo)) exposes
headless subcommands run against a Pharo image. These back the `st pharo` commands
`eval`, `load`, `save`, `metacello`, and `fuel` (which install Pharo automatically
if no image is present):

| Clap command | `st pharo` equivalent | Description |
|--------------|------------------------|-------------|
| `eval <code>` | `st pharo eval '<code>'` | Evaluate Smalltalk code headless |
| `st <file.st>` | `st pharo load <file.st>` | Load and execute a .st source file |
| `save [name]` | `st pharo save [name]` | Save the image |
| `metacello <spec>` | `st pharo metacello <spec>` | Load a Metacello baseline/configuration |
| `fuel load <file.fuel>` | `st pharo fuel <file.fuel>` | Load a Fuel serialization file |

## Options

- `-d, --dir <path>` - Installation directory (default: current directory)

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x pharo install`

## Package Installation

Multiple packages can be specified after the install command:

```bash
st pharo install Seaside NeoCSV
```

## Examples

```bash
st pharo install                  # Install Pharo
st pharo install -d ~/my-pharo    # Install to specific directory
st pharo install Seaside          # Install Pharo with Seaside package
st pharo install Seaside NeoCSV   # Install with multiple packages
st pharo install -d ~/p Seaside   # Install to directory with package
st -x pharo install               # Install with debug output
st -v pharo install               # Install with verbose output
st pharo run                      # Launch the Pharo UI
st pharo eval '1+2'               # Evaluate Smalltalk code
st pharo load script.st           # Load a .st file
st pharo metacello github://hernanmd/ISO3166/repository ISO3166  # Load Metacello baseline
st pharo save myimage             # Save the image
st pharo fuel data.fuel           # Load a Fuel file
st pharo search polyglot          # Search for packages
st pharo clean-artifacts          # Clean installed files
```

## About Pharo

Pharo is a pure object-oriented language and development environment.
It is a modern, open-source Smalltalk implementation.
Website: https://pharo.org