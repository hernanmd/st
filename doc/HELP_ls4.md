# Little Smalltalk v4 Commands

## Usage

```bash
st [-x] ls4 <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [-d dir]` | Install LS4 (downloads and builds from source) |
| `run [args] [-d dir]` | Run LS4 Web IDE |
| `eval [args] [-d dir]` | Run LS4 REPL evaluator |
| `versions` | List available versions from GitHub releases |
| `version` | Show LS4 version |
| `clean-artifacts` | Clean build artifacts |
| `help` | Show this help message |

## Options

- `-d, --dir <path>` - Target directory for installation or run

## Notes

- LS4 must be built from source (uses CMake)
- LS4 has no package manager (no search, list, update, install commands return errors)
- The `run` command starts the Web IDE (requires a graphical display)
- The `eval` command starts the REPL evaluator

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x ls4 install`

## Examples

```bash
st ls4 install                # Download, build and install LS4
st ls4 install -d ~/ls4       # Install to specific directory
st -x ls4 install             # Install with debug output
st -v ls4 install             # Install with verbose output
st ls4 run                    # Run LS4 Web IDE
st ls4 run -d ~/ls4           # Run Web IDE from specific directory
st ls4 eval                   # Run LS4 REPL evaluator
st ls4 eval -d ~/ls4          # Run REPL from specific directory
st ls4 versions               # List available versions
st ls4 version                # Show LS4 version
```

## About Little Smalltalk v4

Little Smalltalk v4 is a new implementation by Kyle Gray (kyle-github).
It uses CMake as its build system and is downloaded from GitHub releases.
Repository: https://github.com/kyle-github/littlesmalltalk
