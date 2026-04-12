# Little Smalltalk v3 Commands

## Usage

```bash
st [-x] lst <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [-d dir]` | Install LST (downloads and builds from source) |
| `run [args] [-d dir]` | Run LST (builds if needed) |
| `version` | Show LST version |
| `clean-artifacts` | Clean build artifacts |
| `help` | Show this help message |

## Options

- `-d, --dir <path>` - Target directory for installation or run

## Notes

- LST must be built from source (downloads archive and runs make)
- LST does not support Windows
- LST does not have packages (no search, list, update)
- LST does not support headless code evaluation from CLI

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x lst install`

## Examples

```bash
st lst install                # Download, build and install LST
st lst install -d ~/lst3r    # Install to specific directory
st -x lst install            # Install with debug output
st -v lst install            # Install with verbose output
st lst run                   # Run LST REPL
st lst run -d ~/lst3r        # Run from specific directory
st lst version               # Show LST version
```

## About Little Smalltalk v3

Little Smalltalk is a simplified Smalltalk dialect designed
for learning and teaching. Version 3 is a modern rewrite in C.
Repository: https://codeberg.org/suetanvil/lst3r