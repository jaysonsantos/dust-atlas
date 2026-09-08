# Third-party components

This repository does not vendor third-party source code or reference-image assets.
The build uses these external components:

| Component | Role | License source |
| --- | --- | --- |
| V and gg | Compiler, standard library, and graphics API | https://github.com/vlang/v/blob/master/LICENSE |
| V bundled libraries | Graphics, fonts, JSON, and garbage collection | https://github.com/vlang/v/tree/master/thirdparty |
| dust | Separate process for disk usage and JSON | https://github.com/bootandy/dust/blob/master/LICENSE |
| Nixpkgs | Development packages | https://github.com/NixOS/nixpkgs/blob/master/COPYING |

Keep the applicable third-party notices when you distribute a binary with these components.
Check the exact dependency versions in your build.
This project does not include the supplied WinDirStat screenshot.

The `licenses` directory contains notices from the V 0.5.2 toolchain used for the local build.
These notices cover V, Sokol, Fontstash, stb image, stb truetype, cJSON, and Boehm GC.
The Boehm build sets `LARGE_CONFIG`; it does not change the collector source.

## GUI integration

The flake fixes the source revisions of `vlang/gui` and `vlang/vglyph`.
The `licenses` directory includes GUI, VGlyph, and Feathericon notices.
GUI embeds the Feathericon font. The app loads its text fonts from the host.
The app also links Pango, FreeType, HarfBuzz, FriBidi, Fontconfig, and their dependencies from the Nix store.
The local app bundle does not copy these libraries.

`patches/gui-macos-input.patch` contains local changes to GUI input handling and macOS accessibility.
`patches/vglyph-macos-paste.patch` adds paste support to the macOS text input overlay.
The performance patch reuses text layouts. The tree patch adds a context-menu callback.
All patches change separate build copies of the upstream source.

## CI packages

CI packages include dust 1.2.5 and its Rust dependency notices.
The scripts collect these notices from the Cargo source cache.
Linux packages include installed package notices. macOS packages include Homebrew notices and package metadata.
Windows packages include vcpkg notices and the MSVC redistributable runtime.
Each package also contains this file, `LICENSE`, and the notices from `licenses/`.
The original icon in `assets/dust-atlas.svg` uses this project's MIT license.
