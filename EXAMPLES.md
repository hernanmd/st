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
smalltalk pharo install

# Install Cuis
smalltalk cuis install

# Install Squeak
smalltalk squeak install

# Install Glamorous Toolkit
smalltalk gt install

# Install GNU Smalltalk
smalltalk gnu install

# Install Little Smalltalk
smalltalk lst install
```

### Install to a specific directory

```bash
smalltalk pharo install -d ~/smalltalk/pharo
smalltalk cuis install -d ~/smalltalk/cuis
smalltalk squeak install -d ~/smalltalk/squeak
```

### Install a specific version

```bash
# Cuis versions
smalltalk cuis install stable    # Latest stable (default)
smalltalk cuis install 7.0       # Cuis 7.0
smalltalk cuis install 6.0       # Cuis 6.0

# Squeak versions
smalltalk squeak install stable  # Latest stable (default)
smalltalk squeak install 6.0     # Squeak 6.0
smalltalk squeak install 5.4     # Squeak 5.4
smalltalk squeak install 5.3     # Squeak 5.3
```

## Pharo

### Install Pharo

```bash
# Install latest Pharo to current directory
smalltalk pharo install

# Install to specific directory
smalltalk pharo install -d ~/my-pharo
```

### Run Pharo

```bash
# Launch Pharo UI
smalltalk pharo run

# Evaluate Smalltalk code directly
smalltalk pharo run eval '1 + 2'
smalltalk pharo run eval 'Date today'

# Run a Smalltalk script file
smalltalk pharo run st myscript.st

# Save the image
smalltalk pharo run save

# Install a Metacello baseline
smalltalk pharo run metacello 'BaselineOfSeaside3'
```

### Pharo Package Management

```bash
# Search for packages
smalltalk pharo search seaside

# List cached packages
smalltalk pharo list

# Update package cache
smalltalk pharo update
```

### Get Pharo Version

```bash
smalltalk pharo version
```

## Cuis

### Install Cuis

```bash
# Install latest stable Cuis
smalltalk cuis install

# Install specific version
smalltalk cuis install 7.0
smalltalk cuis install 6.0

# Install to directory
smalltalk cuis install -d ~/cuis
```

### Run Cuis

```bash
smalltalk cuis run
```

### Cuis Package Search

```bash
smalltalk cuis search morphic
smalltalk cuis update
smalltalk cuis list
```

### Get Cuis Version

```bash
smalltalk cuis version
```

## Squeak

### Install Squeak

```bash
# Install latest stable Squeak
smalltalk squeak install

# Install specific version
smalltalk squeak install 6.0
smalltalk squeak install 5.4

# Install to directory
smalltalk squeak install -d ~/squeak
```

### Run Squeak

```bash
smalltalk squeak run
```

### Squeak Package Search

```bash
smalltalk squeak search seaside
smalltalk squeak update
smalltalk squeak list
```

### Get Squeak Version

```bash
smalltalk squeak version
```

## Glamorous Toolkit

### Install Glamorous Toolkit

```bash
# Install to current directory
smalltalk gt install

# Install to specific directory
smalltalk gt install -d ~/gt
```

### Run Glamorous Toolkit

```bash
# Launch GT UI
smalltalk gt run

# Evaluate Smalltalk code
smalltalk gt run eval '1 + 2'

# Run a Smalltalk script
smalltalk gt run st myscript.st

# Install a Metacello baseline
smalltalk gt run metacello 'BaselineOfPhexample'
```

### GT Version

```bash
smalltalk gt version
```

## GNU Smalltalk

### Install GNU Smalltalk

```bash
# Install via system package manager
smalltalk gnu install

# Build from source (requires development tools)
smalltalk gnu install --source
```

### Run GNU Smalltalk

```bash
# Start REPL
smalltalk gnu run

# Run a script file
smalltalk gnu run script.st

# Run script and exit
smalltalk gnu run -i script.st
```

### Get GNU Smalltalk Version

```bash
smalltalk gnu version
```

## Little Smalltalk

### Install Little Smalltalk

```bash
# Download prebuilt binary
smalltalk lst install

# Build from source
smalltalk lst install --build
```

### Run Little Smalltalk

```bash
# Start REPL
smalltalk lst run

# Run with arguments
smalltalk lst run arg1 arg2
```

### Get LST Version

```bash
smalltalk lst version
```

## Package Management

### Search for Packages

```bash
# Search Pharo packages
smalltalk pharo search polyglot
smalltalk pharo search seaside

# Search GT packages
smalltalk gt search debugger

# Search Cuis packages
smalltalk cuis search morphic

# Search Squeak packages
smalltalk squeak search seaside
```

### List Cached Packages

```bash
smalltalk pharo list
smalltalk gt list
smalltalk cuis list
smalltalk squeak list
```

### Update Package Cache

```bash
smalltalk pharo update
smalltalk gt update
smalltalk cuis update
smalltalk squeak update
```

## Maintenance

### Clean Cache

```bash
# Clean all caches
smalltalk pharo clean
smalltalk gt clean
smalltalk cuis clean
smalltalk squeak clean
```

### Clean Installed Artifacts

```bash
# Clean all Smalltalk artifacts
smalltalk clean_artifacts

# Clean specific implementation artifacts
smalltalk clean_artifacts pharo
smalltalk clean_artifacts gt
smalltalk clean_artifacts cuis
smalltalk clean_artifacts squeak
```

### Help

```bash
# General help
smalltalk --help

# Implementation-specific help
smalltalk pharo help
smalltalk gt help
smalltalk cuis help
smalltalk squeak help
smalltalk gnu help
smalltalk lst help
```

## Common Workflows

### First Time Setup

```bash
# 1. Install Pharo
smalltalk pharo install -d ~/smalltalk

# 2. Run it to verify
smalltalk pharo run

# 3. Search for a package
smalltalk pharo search seaside

# 4. Install a package (in Pharo image)
smalltalk pharo run metacello 'BaselineOfSeaside3'
```

### Multiple Implementations

```bash
# Install multiple implementations in separate directories
mkdir ~/smalltalk
cd ~/smalltalk

smalltalk pharo install -d pharo
smalltalk gt install -d gt
smalltalk cuis install -d cuis
smalltalk squeak install -d squeak

# Run each one
cd pharo && smalltalk pharo run
cd ../gt && smalltalk gt run
cd ../cuis && smalltalk cuis run
cd ../squeak && smalltalk squeak run
```

### Clean Up

```bash
# Before reinstalling, clean old artifacts
cd ~/smalltalk/pharo
smalltalk clean_artifacts

# Then reinstall
smalltalk pharo install
```
