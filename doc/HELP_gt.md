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
| `eval '<code>'` | Evaluate Smalltalk code (headless); installs GT if not present |
| `load <file.st>` | Load and execute a .st source file; installs GT if not present |
| `save [name]` | Save the GT image; installs GT if not present |
| `metacello <spec>` | Install a Metacello baseline/configuration; installs GT if not present |
| `search <term>` | Search for packages |
| `list` | List available packages |
| `update` | Update package information |
| `clean` | Clean cache directory |
| `clean-artifacts` | Clean installed artifacts |
| `version` | Show GT version |
| `help` | Show this help message |

## Clap Commands

Glamorous Toolkit ships with Pharo's command-line handler
([Clap](https://github.com/pharo-project/pharo)), exposing headless subcommands run
against the GT image. These back the `st gt` commands `eval`, `load`, `save`, and
`metacello` (which install Glamorous Toolkit automatically if no image is present):

| Clap command | `st gt` equivalent | Description |
|--------------|--------------------|-------------|
| `eval <code>` | `st gt eval '<code>'` | Evaluate Smalltalk code headless (e.g. `42 inspect`) |
| `st <file.st>` | `st gt load <file.st>` | Load and execute a .st source file |
| `save [name]` | `st gt save [name]` | Save the GT image |
| `metacello <spec>` | `st gt metacello <spec>` | Load a Metacello baseline/configuration |

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