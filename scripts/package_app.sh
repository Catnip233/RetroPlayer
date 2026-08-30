#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/outputs/RetroPlayer.app"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$project_dir"
DEVELOPER_DIR="$developer_dir" CLANG_MODULE_CACHE_PATH="$project_dir/work/clang-cache" \
    swift build -c release --disable-sandbox \
    --cache-path "$project_dir/work/swiftpm-cache" \
    --config-path "$project_dir/work/swiftpm-config" \
    --security-path "$project_dir/work/swiftpm-security" \
    --scratch-path "$project_dir/.build"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/.build/release/RetroPlayer" "$app_dir/Contents/MacOS/RetroPlayer"
cp "$project_dir/AppResources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Sources/RetroPlayer/Resources/CRT.glsl" "$app_dir/Contents/Resources/CRT.glsl"
cp "$project_dir/AppResources/RetroPlayer.icns" "$app_dir/Contents/Resources/RetroPlayer.icns"
chmod +x "$app_dir/Contents/MacOS/RetroPlayer"
/usr/bin/xattr -cr "$app_dir"
/usr/bin/codesign --force --deep --sign - "$app_dir"
/usr/bin/codesign --verify --deep --strict "$app_dir"

echo "$app_dir"
