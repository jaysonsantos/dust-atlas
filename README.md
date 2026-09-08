# Dust Atlas

Dust Atlas uses `vlang/gui` for its desktop interface.
It is a V desktop frontend for [dust](https://github.com/bootandy/dust).
Rectangles show the disk space for each entry in a folder.
Click a folder rectangle or tree entry to see its contents.

## Start on macOS

Install Nix with flakes enabled. On macOS, install the Xcode command line tools.

```sh
nix develop
v run scripts/build.vsh
./bin/dust-atlas /path/to/folder
```

Click **Browse** to choose and scan a folder. You can also enter a path and click **Scan**. The scan runs outside the interface thread.
The app first looks for dust beside its executable. It then checks `PATH`.
The flake supplies V, dust, GUI modules, and text libraries.
The lock file also fixes the `gui` and `vglyph` revisions.
The lock file fixes the Nix package versions.

GitHub Actions builds Linux, Windows, and macOS packages. Native Trash and deletion remain exclusive to macOS.

## CI packages

`.github/workflows/ci.yml` runs on pushes, pull requests, and manual requests.
The lint job checks V format, whitespace, shell scripts, Python syntax, and workflow syntax.
Each platform job runs the tests before its production build.
The jobs use V 0.5.2 and the GUI revisions from `flake.lock`.
The scripts apply the same local patches as the Nix shell.

| Platform | Runner | Download |
| --- | --- | --- |
| Linux x64 | Ubuntu 22.04 | AppImage with dust and library dependencies |
| Windows x64 | Windows Server 2022 | ZIP with dust, text libraries, and the MSVC runtime |
| macOS Apple Silicon | macOS 15 | ZIP with an app bundle, dust, and text libraries |
| macOS Intel | macOS 15 Intel | ZIP with an app bundle, dust, and text libraries |

Download packages from the workflow's **Artifacts** section. Artifacts expire after 14 days.
The workflow does not publish releases.

For Linux, use AppImage for a single portable download.
The build uses Ubuntu 22.04 to limit its minimum glibc requirement.
The host supplies fonts, graphics drivers, and an X11 display or XWayland.
See the [AppImage dependency guide](https://docs.appimage.org/introduction/concepts.html).

```sh
chmod +x Dust-Atlas-linux-x86_64.AppImage
./Dust-Atlas-linux-x86_64.AppImage
```

If FUSE is unavailable, add `--appimage-extract-and-run`.
For Windows, extract the complete ZIP before you start `dust-atlas.exe`.
The macOS packages require macOS 15 or later.
Extract the ZIP and open `Dust Atlas.app`.
The macOS packages use ad hoc signatures. They have no Developer ID signature or notarization.

The packages include dust 1.2.5 and dependency notices.
They use host fonts through package-specific Fontconfig files.
On Linux and Windows, right-click reports that Trash and deletion require macOS.

## Controls

- Click **Browse** to choose a folder with the macOS folder picker.
- Click the path field to change the folder path.
- Use Command+A to select the path text.
- Use Command+V to paste a path.
- Press Enter or click **Scan** to scan the folder.
- Click a folder rectangle or a tree entry to see its contents.
- Expand folders in the tree. Scroll to reach small entries. The tree includes zero-byte entries.
- If dust omitted a folder's contents, the app scans that folder when you open it.
- Click **Back** to return to the previous folder.
- Click **Scan root** to return to the first folder.
- Click **Scan folder** to scan the path again.
- Click **Dark appearance** or **Light appearance** to change the theme.
- Use Tab to move between controls.
- Move the pointer over a rectangle to see its full path and size.

## Data limits

Dust reports allocated disk bytes. Sparse files can differ from their apparent size.
Each scan requests at most 20,000 entries and 12 levels.
**Stay on this filesystem** starts enabled. This adds dust's `--limit-filesystem` option.
Clear the checkbox before a new scan to include other filesystems.
The option limits each scan to the filesystem of its selected folder.
It does not prevent a scan when you directly select a network folder.
Folder navigation and automatic rescans keep the active scan's setting.
Dust still calculates the folder totals.
The **Other entries / directory data** rectangle preserves the area for bytes outside the returned children.
Zero-byte entries have no rectangle. An empty folder has no rectangles.
Permissions and filesystem changes can prevent a complete scan. Check any reported error before you compare totals.
Right-click a tree entry or rectangle to open its native macOS context menu.
Select **Move to Trash** to use the macOS Trash.
Select **Delete Permanently** to remove the item and its contents without recovery.
The permanent action requires confirmation and shows the full path.
The app reports failures and rescans after a successful operation.
The app never uses permanent deletion as a fallback for a failed Trash operation.

## Checks

```sh
nix develop -c python3 scripts/ci/test.py
nix develop -c python3 scripts/ci/check.py
```

The tests check proportional area, omitted entries, empty folders, and a real dust scan with a special-character path.

The tests also check tree paths, bundled dust lookup, and file-action safeguards.

The macOS build uses Boehm with `LARGE_CONFIG`.
Modern macOS frameworks exceed the default static-root limit on the test host.
The build keeps garbage collection enabled.

To create a local macOS app bundle, run:

```sh
nix develop -c sh scripts/bundle-macos.sh
```

Start the binary from `nix develop` if Finder cannot find dust in `PATH`.
The bundle is local and unsigned. It does not include dust.
It uses the text libraries from the Nix store.

## Source and licenses

This project uses original source code, a flat color palette, and a binary treemap layout.
It contains no WinDirStat source code, icons, images, or copied interface assets.
The reference screenshot is not part of this project.

The project code uses the MIT license in `LICENSE`.
V, its bundled graphics libraries, and dust retain their own licenses.
See `THIRD_PARTY.md` before you distribute binaries.

## Current macOS check

The local Apple Silicon build opens and scans a real folder.
The interface checks cover the native folder picker, path paste, folder rectangles, tree entries, Back, Scan root, themes, and tree scrolling.
The automated tests check dust output and treemap area.
The local app bundle contains the third-party license notices.

## GUI integration

A worker runs dust, parses JSON, sorts entries, and calculates treemap rectangles.
The worker sends the prepared result through `gui.Window.queue_command`.
The main thread applies the result and draws the interface.
The tree renders visible rows. The map caches its drawing geometry.

The flake adds a `json2` module alias for V 0.5.2.
The alias points to the compiler's `x/json2` module.
V's package resolver also needs the private text-library dependencies in the development shell.

`patches/gui-macos-input.patch` changes the pinned GUI source:

- Refresh pending layouts before keyboard events and native text commits. This prevents old input text from replacing new characters within one frame.
- Report each control's enabled state through macOS accessibility.

`patches/vglyph-macos-paste.patch` adds Command+V support to the native text input overlay.

The flake applies the patches to separate build copies of the dependency sources.

## Interface performance

The macOS build uses V production optimization.
Metal controls the frame schedule. The app disables gg's extra sleep after native initialization.
`patches/gui-macos-performance.patch` reuses VGlyph text layouts across interface updates.
The cache includes text, font settings, and available width.

`patches/gui-tree-context.patch` adds tree context menus and corrects row spacing, spacer borders, and theme colors.
The app prepares tree data on the worker thread.
Trash and permanent deletion use `NSFileManager` on a worker thread.
The file-action tests check error reporting and preserve a symbolic link's target.

The map uses one subtle gradient overlay. Gradient work does not grow with the number of rectangles.

Native menus open after the click handler returns. This prevents modal dialogs from invalidating the active layout.
