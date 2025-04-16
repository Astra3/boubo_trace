#!/bin/sh

ls *.mermaid | parallel -j+0 "mmdc -o {.}.svg -i {} -t neutral -c mermaid_config.json"

