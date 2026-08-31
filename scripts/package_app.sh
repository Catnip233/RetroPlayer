#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
final_app_dir="$project_dir/outputs/RetroPlayer.app"
staging_dir="$(mktemp -d /private/tmp/retroplayer-package.XXXXXX)"
app_dir="$staging_dir/RetroPlayer.app"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
trap 'rm -rf "$staging_dir"' EXIT

cd "$project_dir"
DEVELOPER_DIR="$developer_dir" CLANG_MODULE_CACHE_PATH="$project_dir/work/clang-cache" \
    swift build -c release --disable-sandbox \
    --cache-path "$project_dir/work/swiftpm-cache" \
    --config-path "$project_dir/work/swiftpm-config" \
    --security-path "$project_dir/work/swiftpm-security" \
    --scratch-path "$project_dir/.build"

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$app_dir/Contents/Frameworks"
cp "$project_dir/.build/release/RetroPlayer" "$app_dir/Contents/MacOS/RetroPlayer"
cp "$project_dir/AppResources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Sources/RetroPlayer/Resources/"*.glsl "$app_dir/Contents/Resources/"
cp "$project_dir/AppResources/RetroPlayer.icns" "$app_dir/Contents/Resources/RetroPlayer.icns"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"
chmod +x "$app_dir/Contents/MacOS/RetroPlayer"
python3 "$project_dir/scripts/bundle_dylibs.py" \
    "$app_dir/Contents/MacOS/RetroPlayer" \
    "$app_dir/Contents/Frameworks"
/usr/bin/xattr -cr "$app_dir"
/usr/bin/codesign --force --deep --sign - "$app_dir"
# Cloud-backed folders can reattach an empty FinderInfo xattr while the larger
# self-contained bundle is being signed. Removing it does not alter the code
# signature and keeps strict verification valid.
/usr/bin/xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict "$app_dir"

rm -rf "$final_app_dir"
/usr/bin/ditto "$app_dir" "$final_app_dir"
/usr/bin/xattr -cr "$final_app_dir"
/usr/bin/xattr -d com.apple.FinderInfo "$final_app_dir" 2>/dev/null || true
/usr/bin/codesign --verify --deep --strict "$final_app_dir"

echo "$final_app_dir"
