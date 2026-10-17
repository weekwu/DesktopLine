#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app="$PWD/桌面一句.app"
desktopline_arch="${DESKTOPLINE_ARCH:-$(uname -m)}"
case "$desktopline_arch" in
  arm64|x86_64) ;;
  *) print -u2 "Unsupported architecture: $desktopline_arch"; exit 1 ;;
esac
desktopline_cache="$(mktemp -d "${TMPDIR:-/tmp/}DesktopLine-build.XXXXXX")"
trap 'rm -rf "$desktopline_cache"' EXIT
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun swiftc -O -module-cache-path "$desktopline_cache" Scripts/make-icon.swift -o "$desktopline_cache/make-icon"
"$desktopline_cache/make-icon" "$desktopline_cache/AppIcon.iconset" "$PWD/Assets/AppIcon.png" "$app/Contents/Resources/AppIcon.icns"
xcrun swiftc -O -swift-version 5 -target "$desktopline_arch-apple-macos14.0" -module-cache-path "$desktopline_cache" \
  Sources/Settings.swift Sources/DesktopWindow.swift Sources/Preferences.swift \
  Tests/SelfTests.swift Sources/main.swift -o "$app/Contents/MacOS/DesktopLine"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DesktopLine</string>
<key>CFBundleIdentifier</key><string>local.week.DesktopLine</string>
<key>CFBundleName</key><string>桌面一句</string>
<key>CFBundleDisplayName</key><string>桌面一句</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
touch "$app"
printf '%s\n' "$app"
