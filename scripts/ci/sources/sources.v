module sources

import os

// Build output and downloaded dependencies hold V files that are not ours.
const skip_folders = ['bin', 'dist', 'ui-fixture']

// v_sources returns every repository V file, scripts and tests included.
pub fn v_sources() []string {
	mut found := []string{}
	collect(@VMODROOT, mut found)
	return found
}

// v_tests returns every repository V test file.
pub fn v_tests() []string {
	return v_sources().filter(it.ends_with('_test.v'))
}

fn collect(folder string, mut found []string) {
	mut entries := os.ls(folder) or { return }
	entries.sort()
	for entry in entries {
		path := os.join_path(folder, entry)
		if os.is_dir(path) {
			if entry.starts_with('.') || entry in skip_folders {
				continue
			}
			collect(path, mut found)
		} else if entry.ends_with('.v') || entry.ends_with('.vsh') {
			found << path
		}
	}
}
