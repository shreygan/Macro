#!/bin/zsh
# Usage: ./export.sh [symbol names...]
# Writes .symbolset folders for the given symbols (default: all) into the app's asset catalog.
set -e
ROOT="${0:A:h}"
python3 -I "$ROOT/symbols.py" "$ROOT/../../Macro/Resources/Assets.xcassets" "$@"
