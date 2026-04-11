# Squeak Smalltalk Commands

## Usage

```bash
st [-x] squeak <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [ver] [-d dir]` | Install Squeak (options: stable, 6.1, 6.0, 5.3) |
| `run` | Run Squeak |
| `search <term>` | Search for packages |
| `list` | List available packages |
| `update` | Update package information |
| `clean` | Clean cache directory |
| `clean_artifacts` | Clean installed artifacts |
| `version` | Show Squeak version |
| `help` | Show this help message |

## Options

- `-d, --dir <path>` - Installation directory (default: current directory)

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x squeak install`

## Download Notes

- All platforms download the "All-in-One" ZIP which includes the VM
- This ensures consistent behavior across macOS, Linux, and Windows
- The "stable" version is detected from files.squeak.org/current_stable/

## Available Versions

| Version | Description |
|---------|-------------|
| `stable` | Latest stable (detected from files.squeak.org/current_stable/) |
| `6.1` | Squeak 6.1 |
| `6.0` | Squeak 6.0 |
| `5.3` | Squeak 5.3 |

## Examples

```bash
st squeak install                    # Install latest stable Squeak
st squeak install 6.0                # Install Squeak 6.0
st squeak install -d ~/squeak        # Install to specific directory
st -x squeak install                 # Install with debug output
st squeak run                        # Run Squeak
st squeak version                    # Show installed version
```

## Notes

- Squeak uses All-in-One zip format with bundled VM
- Works on macOS (Intel and Apple Silicon), Linux, and Windows
- Package management via Monticello (search runs GitHub queries)

## About Squeak

Squeak is a modern, open-source Smalltalk environment.
It provides a fully object-oriented, dynamically typed language.
Website: https://squeak.org
