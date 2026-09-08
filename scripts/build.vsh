#!/usr/bin/env -S v run

import os

os.mkdir_all('bin')!
mut args := ['-prod', '-o', 'bin/dust-atlas', '.']
$if macos {
	// Modern macOS frameworks exceed the default Boehm static-root limit.
	args = ['-prod', '-d', 'use_bundled_libgc', '-cflags', '-DLARGE_CONFIG', '-ldflags',
		'-Wl,-headerpad_max_install_names', '-o', 'bin/dust-atlas', '.']
}
$if windows {
	args = ['-prod', '-o', 'bin/dust-atlas.exe', '.']
}
mut compiler := os.new_process(@VEXE)
compiler.set_args(args)
compiler.run()
compiler.wait()
code := compiler.code
compiler.close()
exit(code)
