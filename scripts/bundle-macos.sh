#!/bin/sh
set -eu
v run scripts/build.vsh
mkdir -p 'bin/Dust Atlas.app/Contents/MacOS'
cp bin/dust-atlas 'bin/Dust Atlas.app/Contents/MacOS/dust-atlas'
cp scripts/Info.plist 'bin/Dust Atlas.app/Contents/Info.plist'
mkdir -p 'bin/Dust Atlas.app/Contents/Resources/licenses'
cp LICENSE THIRD_PARTY.md 'bin/Dust Atlas.app/Contents/Resources/'
cp licenses/*.txt 'bin/Dust Atlas.app/Contents/Resources/licenses/'
