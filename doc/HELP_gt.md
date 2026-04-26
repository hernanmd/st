# Glamorous Toolkit Commands

## Usage

```bash
st [-x] gt <command> [options]
```

## Commands

| Command | Description |
|---------|-------------|
| `install [-d dir]` | Install Glamorous Toolkit to the specified directory |
| `run [-d dir]` | Launch the GT UI |
| `eval '<code>'` | Evaluate Smalltalk code (headless) |
| `load <file.st>` | Load and execute a .st source file |
| `save [name]` | Save the GT image |
| `metacello <spec>` | Install a Metacello baseline/configuration |
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

## Examples

```bash
st gt install              # Install GT
st gt install -d ~/gt      # Install GT to ~/gt
st -x gt install           # Install with debug output
st -v gt install           # Install with verbose output
st gt run                  # Launch the GT UI
st gt run -d ~/gt          # Launch GT from ~/gt directory
st gt eval '1+2'           # Evaluate Smalltalk code
st gt eval '42 inspect'    # Evaluate and inspect result
st gt load script.st       # Load a .st file
st gt metacello github://hernanmd/ISO3166/repository ISO3166 # Load Metacello baseline
st gt save myimage         # Save the GT image
```

## About Glamorous Toolkit

Glamorous Toolkit is a multi-language IDE developed in Pharo.
It provides a novel approach to software development.
Website: https://gtoolkit.com

## Installation Notes

- **macOS**: Downloads .app bundle, simply double-click to run
- **Linux**: Downloads executable, run `./GlamorousToolkit`
- **Windows**: Downloads .exe installer