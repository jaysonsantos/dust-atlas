#!/bin/sh
set -eu
app='dist/Dust Atlas.app'
contents="$app/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources/licenses" "$contents/Frameworks"
cp bin/dust-atlas "$contents/MacOS/"
cp assets/fonts-macos.conf "$contents/MacOS/fonts.conf"
cp .ci/dust/bin/dust "$contents/MacOS/"
cp scripts/Info.plist "$contents/Info.plist"
plutil -insert LSMinimumSystemVersion -string 15.0 "$contents/Info.plist"
cp LICENSE THIRD_PARTY.md "$contents/Resources/"
cp licenses/*.txt "$contents/Resources/licenses/"
cp -R .ci/notices "$contents/Resources/licenses/"
dylibbundler -b -of -x "$contents/MacOS/dust-atlas" -x "$contents/MacOS/dust" \
  -d "$contents/Frameworks" -p '@executable_path/../Frameworks/'
for library in "$contents/Frameworks/"*.dylib; do
  codesign --force --sign - "$library"
done
codesign --force --sign - "$contents/MacOS/dust"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
v run scripts/ci/check-macos-libs.vsh "$contents"
v run scripts/ci/smoke.vsh "$contents/MacOS/dust-atlas"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/Dust-Atlas-macos-$(uname -m).zip"
