#!/usr/bin/env -S v run

// Check only repository source, not downloaded dependencies.
// Pass `-w` to write the format instead of verifying it.
import os
import scripts.ci.sources

fn run(command string) {
	code := os.system(command)
	if code != 0 {
		exit(code)
	}
}

write := '-w' in os.args
quoted := sources.v_sources().map(os.quoted_path(it)).join(' ')
run('${os.quoted_path(@VEXE)} fmt ${if write { '-w' } else { '-verify' }} ${quoted}')
if write {
	exit(0)
}
run('git diff --check')
// The V toolchain cannot install itself. Check that the Python installer still parses.
run('python3 -m compileall -q ${os.quoted_path(os.join_path(@VMODROOT, 'scripts'))}')
