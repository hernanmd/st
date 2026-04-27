#!/bin/bash

. /$HOME/demo/demo-magic.sh
clear

pe "# List available implementations"
pe "st --list"

pe "# Evaluating expression"
pe "st pharo eval "3 + 4""

pe "# Search for packages in Github"
pe "st pharo search BioSmalltalk"

pe "# Command-line handler help"
pe "st pharo metacello --help"

pe "# Install package"
pe "st pharo metacello install github://hernanmd/ISO3166/repository BaselineOfISO3166 --save"

pe "# Download, install, and run Squeak"
pe "st squeak run"

pe "# Query LittleSmalltalk v4 versions"
pe "st ls4 versions"

pe "# Start CLI interactive eval"
pe "st ls4 eval"

