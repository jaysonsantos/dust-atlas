# Repository Guidelines

## Project Structure

Dust Atlas is a V frontend for dust. The app supports macOS, Linux, and Windows. File actions remain macOS-only; other platforms report that limit.

The V sources use one module for each area. `v.mod` marks the module lookup root, so each module imports its siblings by name.

- `main.v`: `module main`. It reads the folder argument and starts the interface.
- `atlas/`: `module atlas`. GUI controls, folder tree, navigation, worker coordination, and the Linux dbus build flag.
- `model/`: `module model`. Dust arguments, JSON data, byte totals, and treemap layout.
- `actions/` with `native/actions.{h,m}`: `module actions`. macOS menus, Trash, and permanent deletion.
- `*_test.v`: internal tests beside the module source.
- `scripts/`: build helper, local macOS bundle script, and `Info.plist`.
- `scripts/ci/sources/`: `module sources`. It lists the repository V files for the check and test scripts.
- `scripts/ci/` and `.github/workflows/ci.yml`: lint checks, tests, and release packages for each platform.
- `patches/`: local changes to pinned GUI dependencies.
- `licenses/` and `THIRD_PARTY.md`: dependency notices. Keep interface artwork original.

## Development Commands

Install Nix with flakes enabled. On macOS, also install the Xcode command line tools.

- Run `direnv allow` to activate `.envrc`, or enter `nix develop`.
- Run `v run scripts/build.vsh` to build `bin/dust-atlas` with production optimization and the platform build flags.
- Run `./bin/dust-atlas /path/to/folder` to open the app.
- Run `sh scripts/bundle-macos.sh` on macOS to create a local `bin/Dust Atlas.app`. This bundle links development libraries and excludes dust. Use `scripts/ci/package-*` for release packages.
- Run `v run scripts/ci/test.vsh` to execute the project tests. Do not run `v test .`, because it also collects dependency tests.
- Run `v run scripts/ci/check.vsh -w` to format all repository V source.
- Run `v run scripts/ci/check.vsh` before review. It verifies the format of all repository sources and the whitespace of the diff.

Keep generated `bin/` and `.direnv/` files out of commits.

## Coding and Architecture

Use tabs and let `v fmt` control V formatting. Use `snake_case` for functions and variables; use `PascalCase` for types.

Write repository scripts in V, as `.vsh` files. Only `scripts/ci/install-v.py` stays Python, because it installs V.

Keep each module small and give it one responsibility. Export only the items that other modules use. Do not name a module `ui`: `v fmt` removes the `gui.` qualifier from types in a module with that name.

Keep scans, JSON parsing, tree preparation, and file operations on workers. Apply results through `gui.Window.queue_command`. Open native menus after click handlers return. Preserve text-layout caching and Metal frame scheduling.

## Testing and File Safety

Name tests `*_test.v` and functions `test_*`. No numeric coverage target exists. Add focused regression tests for changed behavior.

Use disposable fixtures for file actions. Check symbolic-link targets, errors, and cancelled deletion. Never replace a failed Trash operation with permanent deletion. Preserve the confirmation dialog and default filesystem limit.

Check scrolling, navigation, context menus, and both themes after GUI changes.

## Commits and Pull Requests

No commit history or remote currently defines repository conventions. Use focused, imperative commit subjects, such as `Fix tree scroll spacing`.

Describe the problem, change, and checks in each PR. Link related issues when available. Include screenshots for visual changes. Write documentation and PR descriptions in Simplified Technical English. Preserve unrelated local changes.
