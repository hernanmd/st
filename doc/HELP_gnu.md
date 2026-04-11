# GNU Smalltalk Commands

## Usage

```bash
st [-x] gnu <command>
```

## Commands

| Command | Description |
|---------|-------------|
| `install [--source]` | Install GNU Smalltalk (use --source for building from source) |
| `run [file]` | Run GNU Smalltalk (or a specific file) |
| `search <term>` | Search for packages |
| `list` | List available packages |
| `update` | Update package information |
| `clean` | Clean cache directory |
| `clean_artifacts` | Clean installed artifacts |
| `version` | Show GNU Smalltalk version |
| `help` | Show this help message |

## Options

- `--source` - Build from source instead of package manager

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x gnu install`

## Examples

```bash
st gnu install            # Install via package manager
st gnu install --source   # Build from source
st -x gnu install         # Install with debug output
st gnu run                # Start REPL
st gnu run script.st      # Run a .st file
st gnu run -i script.st   # Run script and exit
```

## About GNU Smalltalk

GNU Smalltalk is an implementation that follows the Smalltalk-80 standard
with unique extensions. It includes an image-based environment and a
scripting environment.
Website: https://gnu.org/software/smalltalk
