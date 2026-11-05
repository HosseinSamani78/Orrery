#!/bin/bash
# Wrap the SwiftPM executable in a minimal .app so the surfaces that only exist inside a
# bundle can be exercised: notification banners, `orrery://` links, `.orreryboard` double-click.
# App Group access still needs a team-signed build, so SharedStoreTests keeps skipping here.
set -euo pipefail
cd "$(dirname "$0")/.."

bin=$(swift build --show-bin-path)
app="$bin/Orrery.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin/Orrery" "$app/Contents/MacOS/Orrery"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>com.orrery.app</string>
	<key>CFBundleName</key><string>Orrery</string>
	<key>CFBundleExecutable</key><string>Orrery</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key><string>com.orrery.board</string>
			<key>CFBundleURLSchemes</key><array><string>orrery</string></array>
		</dict>
	</array>
	<key>UTExportedTypeDeclarations</key>
	<array>
		<dict>
			<key>UTTypeIdentifier</key><string>com.orrery.board</string>
			<key>UTTypeDescription</key><string>Orrery Board</string>
			<key>UTTypeConformsTo</key><array><string>public.json</string></array>
			<key>UTTypeTagSpecification</key>
			<dict><key>public.filename-extension</key><array><string>orreryboard</string></array></dict>
		</dict>
	</array>
</dict>
</plist>
PLIST

codesign --force --sign - "$app" >/dev/null
echo "$app"
open "$app"
