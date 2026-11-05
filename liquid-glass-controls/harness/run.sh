#!/bin/sh
# Builds GlassMorphLab.swift into a small app outside this folder and opens it.
#   sh harness/run.sh [-slow N]   (from the skill's folder, or give the path to this script)
# Needs Xcode with the macOS 26 SDK or later. The app goes to $TMPDIR/glassmorphlab/GlassMorphLab.app.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
tmp="${TMPDIR:-/tmp}"
out="${tmp%/}/glassmorphlab/GlassMorphLab.app"
mkdir -p "$out/Contents/MacOS"
cat > "$out/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GlassMorphLab</string>
<key>CFBundleIdentifier</key><string>dev.def-initialize.glassmorphlab</string>
<key>CFBundleName</key><string>GlassMorphLab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
EOF
arch="$(uname -m)"
xcrun swiftc -parse-as-library -O -target "$arch-apple-macos26.0" "$here/GlassMorphLab.swift" -o "$out/Contents/MacOS/GlassMorphLab"
pkill -x GlassMorphLab 2>/dev/null || true
open -n "$out" --args -ApplePersistenceIgnoreState YES "$@"
echo "opened $out"
