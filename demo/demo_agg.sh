#!/usr/bin/env bash

for t in asciinema dracula github-dark github-light kanagawa kanagawa-dragon kanagawa-light monokai nord solarized-dark solarized-light gruvbox-dark
   do
     agg --theme custom demo/demo.cast demo/demo_$f.gif
   done
