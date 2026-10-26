#!/bin/zsh
# Usage: ./preview.sh [--zoom] [symbol names...]
# Compiles symbols from symbols.py with actool and renders previews/sheet.png (or previews/zoom.png).
# With no names: every custom symbol, between waterbottle.fill and mug.fill for scale.
# System symbol names can be mixed in and are drawn black as references.
set -e
ROOT="${0:A:h}"
MODE=sheet
if [[ "$1" == "--zoom" ]]; then MODE=zoom; shift; fi
BUILD="$ROOT/.build"
rm -rf "$BUILD" && mkdir -p "$BUILD/Preview.xcassets" "$BUILD/out" "$BUILD/Preview.bundle/Contents/Resources" "$ROOT/previews"
echo '{ "info" : { "author" : "xcode", "version" : 1 } }' > "$BUILD/Preview.xcassets/Contents.json"
NAMES=("${(@f)$(python3 -I "$ROOT/symbols.py" "$BUILD/Preview.xcassets" "$@")}")
if (( $# )); then
  NAMES=("$@")
else
  NAMES=(waterbottle.fill $NAMES mug.fill)
fi
xcrun actool "$BUILD/Preview.xcassets" --compile "$BUILD/out" --platform macosx --minimum-deployment-target 14.0 \
  --output-format human-readable-text 2>&1 | grep -iE "error|warning" && exit 1
cp "$BUILD/out/Assets.car" "$BUILD/Preview.bundle/Contents/Resources/"
cat > "$BUILD/Preview.bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>preview.symbols</string><key>CFBundlePackageType</key><string>BNDL</string></dict></plist>
PLIST
swift "$ROOT/sheet.swift" "$BUILD/Preview.bundle" "$ROOT/previews/$MODE.png" $MODE $NAMES
