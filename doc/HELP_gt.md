# Glamorous Toolkit Commands

## Usage

```bash
st [-x] gt <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [-d dir]` | Install Glamorous Toolkit to the specified directory |
| `run [cmd] [-d dir]` | Run GT (with optional Clap commands) |
| `search <term>` | Search for packages |
| `list` | List available packages |
| `update` | Update package information |
| `clean` | Clean cache directory |
| `clean-artifacts` | Clean installed artifacts |
| `version` | Show GT version |
| `help` | Show this help message |

## Options

- `-d, --dir <path>` - Target directory (for `install` and `run` commands)
  - If not specified for `run`, a timestamped directory `GlamorousToolkit_YYYYMMDD_HHMMSS` is created

## Debug Mode

`-x, --debug` - Enable debug mode (set -x tracing)
Must be specified before implementation name.

Example: `st -x gt install`

## Clap Commands

Run as: `st gt run <cmd>`

| Command | Description |
|---------|-------------|
| `metacello <spec>` | Install Metacello baseline/configuration |
| `st <file.st>` | Load and execute .st source file |
| `save [name]` | Save the image |
| `printVersion` | Print version |
| `eval <code>` | Evaluate Smalltalk code |

## Examples

```bash
st gt install           # Install GT to current directory
st gt install -d ~/gt   # Install GT to ~/gt
st -x gt install        # Install with debug output
st -v pharo install           # Install with verbose output
st gt run               # Run GT (creates timestamped dir if needed)
st gt run -d ~/gt       # Run GT from ~/gt directory
st gt run metacello 'BaselineOfPha...'
st gt eval '1+2'
st gt eval '42 inspect'
```

## About Glamorous Toolkit

Glamorous Toolkit is a multi-language IDE developed in Pharo.
It provides a novel approach to software development.
Website: https://gtoolkit.com

## Installation Notes

- **macOS**: Downloads .app bundle, simply double-click to run
- **Linux**: Downloads executable, run `./GlamorousToolkit`
- **Windows**: Downloads .exe installer
