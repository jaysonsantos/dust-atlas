#!/usr/bin/env -S v run

// Reject references to build-host libraries in a macOS artifact.
import os

if os.args.len < 2 {
	eprintln('Usage: v run scripts/ci/check-macos-libs.vsh <Contents>')
	exit(2)
}
contents := os.args[1]
mut paths := [os.join_path(contents, 'MacOS', 'dust-atlas'), os.join_path(contents, 'MacOS', 'dust')]
paths << os.glob(os.join_path(contents, 'Frameworks', '*.dylib'))!

for path in paths {
	result := os.execute('otool -L ${os.quoted_path(path)}')
	if result.exit_code != 0 {
		eprintln('otool failed for ${path}: ${result.output}')
		exit(1)
	}
	for line in result.output.split_into_lines()#[1..] {
		dependency := line.trim_space().all_before(' (')
		if dependency == '' {
			continue
		}
		if !dependency.starts_with('@') && !dependency.starts_with('/usr/lib/')
			&& !dependency.starts_with('/System/Library/') {
			eprintln('External library in ${path}: ${dependency}')
			exit(1)
		}
	}
}
