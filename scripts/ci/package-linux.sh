#!/bin/sh
set -eu
mkdir -p .ci/tools dist/AppDir/usr/bin dist/AppDir/usr/share/dust-atlas/licenses
curl -fL --retry 3 -o .ci/tools/linuxdeploy.AppImage \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage
printf '%s  %s\n' c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d .ci/tools/linuxdeploy.AppImage | sha256sum -c -
chmod +x .ci/tools/linuxdeploy.AppImage
cp assets/fonts-linux.conf dist/AppDir/usr/bin/fonts.conf
cp LICENSE THIRD_PARTY.md dist/AppDir/usr/share/dust-atlas/
cp licenses/*.txt dist/AppDir/usr/share/dust-atlas/licenses/
cp -R .ci/notices dist/AppDir/usr/share/dust-atlas/licenses/
export APPIMAGE_EXTRACT_AND_RUN=1
export OUTPUT=dist/Dust-Atlas-linux-x86_64.AppImage
.ci/tools/linuxdeploy.AppImage --appdir dist/AppDir \
  --executable bin/dust-atlas --executable .ci/dust/bin/dust \
  --desktop-file assets/dust-atlas.desktop --icon-file assets/dust-atlas.svg --output appimage
# Check the payload without FUSE. Tests already exercise a real dust scan.
(cd .ci && ../dist/Dust-Atlas-linux-x86_64.AppImage --appimage-extract >/dev/null)
.ci/squashfs-root/usr/bin/dust --version
if ldd .ci/squashfs-root/usr/bin/dust-atlas | grep 'not found'; then
  exit 1
fi
LD_LIBRARY_PATH="$PWD/.ci/squashfs-root/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  xvfb-run -a python3 scripts/ci/smoke.py .ci/squashfs-root/usr/bin/dust-atlas
