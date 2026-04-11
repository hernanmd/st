# Smalltalk CLI Examples

A collection of examples for using the `smalltalk` CLI to manage Smalltalk implementations.

## Table of Contents

- [Installation](#installation)
- [Pharo](#pharo)
- [Cuis](#cuis)
- [Squeak](#squeak)
- [Glamorous Toolkit](#glamorous-toolkit)
- [GNU Smalltalk](#gnu-smalltalk)
- [Little Smalltalk](#little-smalltalk)
- [Package Management](#package-management)
- [Maintenance](#maintenance)

## Installation

### Install a specific Smalltalk implementation

```bash
# Install Pharo
st pharo install

# Install Cuis
st cuis install

# Install Squeak
st squeak install

# Install Glamorous Toolkit
st gt install

# Install GNU Smalltalk
st gnu install

# Install Little Smalltalk
st lst install
```

### Install to a specific directory

```bash
st pharo install -d ~/smalltalk/pharo
st cuis install -d ~/smalltalk/cuis
st squeak install -d ~/smalltalk/squeak
```

### Install a specific version

```bash
# Cuis versions
st cuis install stable    # Latest stable (default)
st cuis install 7.0       # Cuis 7.0
st cuis install 6.0       # Cuis 6.0

# Squeak versions
st squeak install stable  # Latest stable (default)
st squeak install 6.0     # Squeak 6.0
st squeak install 5.4     # Squeak 5.4
st squeak install 5.3     # Squeak 5.3
```

## Pharo

### Install Pharo

```bash
# Install latest Pharo to current directory
st pharo install

# Install to specific directory
st pharo install -d ~/my-pharo
```

### Run Pharo

```bash
# Launch Pharo UI
st pharo run

# Evaluate Smalltalk code directly
st pharo run eval '1 + 2'
st pharo run eval 'Date today'

# Run a Smalltalk script file
st pharo run st myscript.st

# Save the image
st pharo run save

# Install a Metacello baseline
st pharo run metacello 'BaselineOfSeaside3'
```

### Pharo Package Management

```bash
# Search for packages
st pharo search seaside

# List cached packages
st pharo list

# Update package cache
st pharo update
```

### Get Pharo Version

```bash
st pharo version
```

## Cuis

### Install Cuis

```bash
# Install latest stable Cuis
st cuis install

# Install specific version
st cuis install 7.0
st cuis install 6.0

# Install to directory
st cuis install -d ~/cuis
```

### Run Cuis

```bash
st cuis run
```

### Cuis Package Search

```bash
st cuis search morphic
st cuis update
st cuis list
```

### Get Cuis Version

```bash
st cuis version
```

## Squeak

### Install Squeak

```bash
# Install latest stable Squeak
st squeak install

# Install specific version
st squeak install 6.0
st squeak install 5.4

# Install to directory
st squeak install -d ~/squeak
```

### Run Squeak

```bash
st squeak run
```

### Squeak Package Search

```bash
st squeak search seaside
st squeak update
st squeak list
```

### Get Squeak Version

```bash
st squeak version
```

## Glamorous Toolkit

### Install Glamorous Toolkit

```bash
# Install to current directory
st gt install

# Install to specific directory
st gt install -d ~/gt
```

### Run Glamorous Toolkit

```bash
# Launch GT UI
st gt run

# Evaluate Smalltalk code
st gt run eval '1 + 2'

# Run a Smalltalk script
st gt run st myscript.st

# Install a Metacello baseline
st gt run metacello 'BaselineOfPhexample'
```

### GT Version

```bash
st gt version
```

## GNU Smalltalk

### Install GNU Smalltalk

```bash
# Install via system package manager
st gnu install

# Build from source (requires development tools)
st gnu install --source
```

### Run GNU Smalltalk

```bash
# Start REPL
st gnu run

# Run a script file
st gnu run script.st

# Run script and exit
st gnu run -i script.st
```

### Get GNU Smalltalk Version

```bash
st gnu version
```

## Little Smalltalk

### Install Little Smalltalk

```bash
# Download prebuilt binary
st lst install

# Build from source
st lst install --build
```

### Run Little Smalltalk

```bash
# Start REPL
st lst run

# Run with arguments
st lst run arg1 arg2
```

### Get LST Version

```bash
st lst version
```

## Package Management

### Search for Packages

```bash
# Search Pharo packages
st pharo search polyglot
st pharo search seaside

# Search GT packages
st gt search debugger

# Search Cuis packages
st cuis search morphic

# Search Squeak packages
st squeak search seaside
```

### List Cached Packages

```bash
st pharo list
st gt list
st cuis list
st squeak list
```

### Update Package Cache

```bash
st pharo update
st gt update
st cuis update
st squeak update
```

## Maintenance

### Clean Cache

```bash
# Clean all caches
st pharo clean
st gt clean
st cuis clean
st squeak clean
```

### Clean Installed Artifacts

```bash
# Clean all Smalltalk artifacts
st clean_artifacts

# Clean specific implementation artifacts
st clean_artifacts pharo
st clean_artifacts gt
st clean_artifacts cuis
st clean_artifacts squeak
```

### Help

```bash
# General help
st --help

# Implementation-specific help
st pharo help
st gt help
st cuis help
st squeak help
st gnu help
st lst help
```

## Common Workflows

### First Time Setup

```bash
# 1. Install Pharo
st pharo install -d ~/smalltalk

# 2. Run it to verify
st pharo run

# 3. Search for a package
st pharo search seaside

# 4. Install a package (in Pharo image)
st pharo run metacello 'BaselineOfSeaside3'
```

### Multiple Implementations

```bash
# Install multiple implementations in separate directories
mkdir ~/smalltalk
cd ~/smalltalk

st pharo install -d pharo
st gt install -d gt
st cuis install -d cuis
st squeak install -d squeak

# Run each one
cd pharo && st pharo run
cd ../gt && st gt run
cd ../cuis && st cuis run
cd ../squeak && st squeak run
```

### Clean Up

```bash
# Before reinstalling, clean old artifacts
cd ~/smalltalk/pharo
st clean_artifacts

# Then reinstall
st pharo install
```
