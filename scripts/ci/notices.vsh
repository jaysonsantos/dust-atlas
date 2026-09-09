#!/usr/bin/env -S v run

// Collect installed dependency notices without changing source notices.
import os

fn is_notice(name string) bool {
	lower := name.to_lower()
	return lower.starts_with('license') || lower.starts_with('copying')
		|| lower.starts_with('copyright')
}

fn collect(root string, relative string, destination string) {
	folder := if relative == '' { root } else { os.join_path(root, relative) }
	entries := os.ls(folder) or { return }
	for entry in entries {
		path := os.join_path(folder, entry)
		child := if relative == '' { entry } else { os.join_path(relative, entry) }
		if os.is_dir(path) {
			if !os.is_link(path) {
				collect(root, child, destination)
			}
		} else if is_notice(entry) {
			target := os.join_path(destination, child)
			os.mkdir_all(os.dir(target)) or { panic(err) }
			os.cp(path, target) or { panic('Cannot copy ${path}: ${err}') }
		}
	}
}

fn contains_name(folder string, part string) bool {
	entries := os.ls(folder) or { return false }
	for entry in entries {
		if entry.contains(part) {
			return true
		}
		path := os.join_path(folder, entry)
		if os.is_dir(path) && !os.is_link(path) && contains_name(path, part) {
			return true
		}
	}
	return false
}

fn command_output(command string) string {
	result := os.execute(command)
	if result.exit_code != 0 {
		eprintln('`${command}` failed (${result.exit_code}): ${result.output}')
		exit(1)
	}
	return result.output
}

output := os.join_path(@VMODROOT, '.ci', 'notices')
os.mkdir_all(output)!

mut cargo := os.getenv('CARGO_HOME')
if cargo == '' {
	cargo = os.join_path(os.home_dir(), '.cargo')
}
collect(os.join_path(cargo, 'registry', 'src'), '', os.join_path(output, 'rust'))

$if macos {
	collect(command_output('brew --cellar').trim_space(), '', os.join_path(output, 'homebrew'))
	os.write_file(os.join_path(output, 'homebrew-packages.json'),
		command_output('brew info --json=v2 --installed'))!
} $else $if linux {
	collect('/usr/share/doc', '', os.join_path(output, 'linux'))
}

if !contains_name(os.join_path(output, 'rust'), 'du-dust') {
	eprintln('The dust source notice is missing')
	exit(1)
}
