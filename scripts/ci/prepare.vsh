#!/usr/bin/env -S v run

// Prepare the same patched V modules as the Nix development shell.
import os
import x.json2

fn run(command string) {
	code := os.system(command)
	if code != 0 {
		exit(code)
	}
}

fn field(value json2.Any, key string) json2.Any {
	return value.as_map()[key] or { panic('flake.lock has no `${key}`') }
}

fn append_line(variable string, line string) ! {
	path := os.getenv(variable)
	if path == '' {
		return
	}
	mut file := os.open_append(path)!
	defer {
		file.close()
	}
	file.writeln(line)!
}

modules := os.join_path(@VMODROOT, '.ci', 'modules')
os.mkdir_all(modules)!
flake := json2.decode[json2.Any](os.read_file(os.join_path(@VMODROOT, 'flake.lock'))!)!
for name in ['gui', 'vglyph'] {
	source := field(field(field(flake, 'nodes'), name), 'locked')
	target := os.join_path(modules, name)
	if os.exists(target) {
		os.rmdir_all(target)!
	}
	url := 'https://github.com/${field(source, 'owner').str()}/${field(source, 'repo').str()}.git'
	run('git clone --config core.autocrlf=false --no-checkout ${url} ${os.quoted_path(target)}')
	run('git -C ${os.quoted_path(target)} checkout --detach ${field(source, 'rev').str()}')
	mut patches := os.glob(os.join_path(@VMODROOT, 'patches', '${name}-*.patch'))!
	patches.sort()
	for patch in patches {
		run('git -C ${os.quoted_path(target)} apply --unidiff-zero ${os.quoted_path(patch)}')
	}
}

json2_module := os.join_path(modules, 'json2')
if os.exists(json2_module) {
	os.rmdir_all(json2_module)!
}
os.cp_all(os.join_path(os.getenv('VROOT'), 'vlib', 'x', 'json2'), json2_module, true)!

mut flags := '-path ${modules}|@vlib|@vmodules -no-parallel'
$if windows {
	flags += ' -cc msvc'
}
if os.getenv('RUNNER_OS') == 'macOS' {
	flags += ' -d use_bundled_libgc -cflags -DLARGE_CONFIG'
}
append_line('GITHUB_ENV', 'VFLAGS=${flags}')!
append_line('GITHUB_PATH', os.join_path(@VMODROOT, '.ci', 'dust', 'bin'))!
