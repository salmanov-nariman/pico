#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
destination="$HOME/Applications/Pico.app"
built_app="$project_root/build/Build/Products/Release/Pico.app"

if /usr/bin/pgrep -x Pico >/dev/null; then
    echo "Quit Pico from its paw menu (and stop the Xcode run), then run this script again." >&2
    exit 1
fi

if [[ -e "$destination" ]]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)
    if [[ "$bundle_id" != "app.pico.desktop" ]]; then
        echo "Another app already exists at $destination; refusing to overwrite it." >&2
        exit 1
    fi
fi

/usr/bin/xcodebuild -project "$project_root/Pico.xcodeproj" -scheme Pico \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$project_root/build" build

if /usr/bin/pgrep -x Pico >/dev/null; then
    echo "Pico started during the build. Quit it and run this script again." >&2
    exit 1
fi

/bin/mkdir -p "$HOME/Applications"
/usr/bin/ditto "$built_app" "$destination"
/usr/bin/codesign --verify --deep --strict "$destination"
echo "Installed: $destination"
echo 'Launch separately: open "$HOME/Applications/Pico.app"'
