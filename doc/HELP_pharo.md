# Pharo Smalltalk Commands

## Usage

```bash
st [-x] pharo <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [-d dir] [packages...]` | Install Pharo with optional packages |
| `run [cmd]` | Run Pharo (with optional Clap commands) |
| `search <term>` | Search for packages |
| `list` | List available packages (cached) |
| `update` | Update package cache |
| `clean` | Clean cache directory |
| `clean-artifacts` | Clean installed artifacts |
| `version` | Show Pharo version |
| `help` | Show this help message |

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

## Clap Commands

Run as: `st pharo run <cmd>`

| Command | Description |
|---------|-------------|
| `metacello <spec>` | Install Metacello baseline/configuration |
| `st <file.st>` | Load and execute .st source file |
| `save [name]` | Save the image |
| `printVersion` | Print image version |
| `eval <code>` | Evaluate Smalltalk code |
| `fuel <file.fuel>` | Load fuel file |

## Examples

```bash
st pharo install                  # Install Pharo
st pharo install -d ~/my-pharo    # Install to specific directory
st pharo install Seaside          # Install Pharo with Seaside package
st pharo install Seaside NeoCSV   # Install with multiple packages
st pharo install -d ~/p Seaside   # Install to directory with package
st -x pharo install               # Install with debug output
st pharo run                      # Run Pharo
st pharo search polyglot          # Search for packages
st pharo clean-artifacts          # Clean installed files
```

## About Pharo

Pharo is a pure object-oriented language and development environment.
It is a modern, open-source Smalltalk implementation.
Website: https://pharo.org
