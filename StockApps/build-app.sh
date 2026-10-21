#!/bin/bash
# Builds "Stock Screener.app" and "Stock Evaluator.app" in ./build so you can
# drag them to /Applications. Pass a product name to build just one:
#   ./build-app.sh StockEvaluator
# Set UNIVERSAL=1 to build for both Apple Silicon and Intel Macs.
set -euo pipefail
cd "$(dirname "$0")"

FLAGS=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    FLAGS+=(--arch arm64 --arch x86_64)
fi
swift build "${FLAGS[@]}"
BIN_DIR="$(swift build "${FLAGS[@]}" --show-bin-path)"

make_app() {
    local product="$1" name="$2" bundle_id="$3"
    local app="build/$name.app"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$BIN_DIR/$product" "$app/Contents/MacOS/$product"

    cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$name</string>
    <key>CFBundleDisplayName</key><string>$name</string>
    <key>CFBundleIdentifier</key><string>$bundle_id</string>
    <key>CFBundleExecutable</key><string>$product</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.finance</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

    # Ad-hoc signature so macOS will launch it on this Mac.
    codesign --force --sign - "$app"
    echo "Built $(pwd)/$app"
}

want="${1:-all}"
if [[ "$want" == "all" || "$want" == "StockScreener" ]]; then
    make_app StockScreener "Stock Screener" local.stockscreener
fi
if [[ "$want" == "all" || "$want" == "StockEvaluator" ]]; then
    make_app StockEvaluator "Stock Evaluator" local.stockevaluator
fi
echo "Open with:  open \"build/Stock Evaluator.app\"  (or \"build/Stock Screener.app\")"
