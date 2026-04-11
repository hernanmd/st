# Little Smalltalk v3 Commands

## Usage

```bash
st [-x] lst <command>
```

## Commands

| Command | Description |
|---------|-------------|
| `install [--build]` | Install LST (use --build to compile from source) |
| `run [args]` | Run Little Smalltalk |
| `search <term>` | Search for packages |
| `list` | List available packages |
| `update` | Update package information |
| `clean` | Clean cache directory |
| `clean_artifacts` | Clean installed artifacts |
| `version` | Show LST version |
| `help` | Show this help message |

## Options

- `--build` - Build from source instead of prebuilt binary

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x lst install`

## Examples

```bash
st lst install           # Download prebuilt binary
st lst install --build  # Build from source
st -x lst install       # Install with debug output
st lst run              # Start REPL
st lst run script.lst3   # Run a .lst3 file
```

## About Little Smalltalk v3

Little Smalltalk is a simplified Smalltalk dialect designed
for learning and teaching. Version 3 is a modern rewrite.
Repository: https://codeberg.org/suetanvil/lst3r
