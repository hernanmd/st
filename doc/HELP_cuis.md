# Cuis Smalltalk Commands

## Usage

```bash
st [-x] cuis <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [ver] [-d dir]` | Install Cuis (default: stable, options: stable, 7.0, 6.0) |
| `run` | Launch Cuis (installs Cuis if not present) |
| `eval '<code>'` | Evaluate Smalltalk code (headless); installs Cuis if not present |
| `search <term>` | Search for packages |
| `list` | List available packages |
| `update` | Update package information |
| `clean` | Clean cache directory |
| `clean-artifacts` | Clean installed artifacts |
| `version` | Show Cuis version |
| `help` | Show this help message |

## Options

- `-d, --dir <path>` - Installation directory (default: current directory)

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x cuis install`

## Available Versions

| Version | Description |
|---------|-------------|
| `stable` | Latest stable release (Cuis 7.6) |
| `7.0` | Cuis 7.0 |
| `6.0` | Cuis 6.0 |

## Examples

```bash
st cuis install                    # Install latest stable Cuis
st cuis install 7.0               # Install Cuis 7.0
st cuis install -d ~/cuis         # Install to specific directory
st cuis install 7.0 -d ~/cuis70   # Install specific version to directory
st -x cuis install                # Install with debug output
st -v cuis install                # Install with verbose output
st cuis run                       # Launch Cuis
st cuis eval '1 + 2'             # Evaluate Smalltalk code
st cuis version                   # Show installed version
```

## About Cuis

Cuis is a modern, modular, and portable Smalltalk environment.
It is designed to be small, clean, and fast while remaining portable.
Website: https://cuis.st