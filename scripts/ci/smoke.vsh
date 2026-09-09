#!/usr/bin/env -S v run

// Check packaged dust, then detect immediate GUI startup failures.
import json
import model
import os
import time

fn fail(temporary string, message string) {
	os.rmdir_all(temporary) or {}
	eprintln(message)
	exit(1)
}

if os.args.len < 2 {
	eprintln('Usage: v run scripts/ci/smoke.vsh <executable>')
	exit(2)
}
executable := os.real_path(os.args[1])
mut dust_name := 'dust'
$if windows {
	dust_name = 'dust.exe'
}
dust := os.join_path(os.dir(executable), dust_name)

temporary := os.join_path(os.temp_dir(), 'atlas package ü ${os.getpid()}')
os.mkdir_all(temporary)!
os.write_file(os.join_path(temporary, 'test.txt'), 'disk space fixture\n'.repeat(1000))!

mut scan := os.new_process(dust)
scan.set_args(['-j', '-P', '-p', '-o', 'b', '--limit-filesystem', '--', temporary])
scan.set_redirect_stdio()
scan.run()
report := scan.stdout_slurp()
scan.wait()
scan_code := scan.code
scan.close()
if scan_code != 0 {
	fail(temporary, 'Packaged dust failed (${scan_code})')
}
tree := json.decode(model.Node, report.trim_space()) or {
	fail(temporary, 'Cannot read the dust report: ${err}')
	return
}
if tree.children.len == 0 || model.bytes(tree) == 0 {
	fail(temporary, 'Packaged dust did not report the fixture')
}

$if windows {
	// Hosted Windows runners do not provide a suitable interactive OpenGL session.
	os.rmdir_all(temporary) or {}
	exit(0)
}

mut app := os.new_process(executable)
app.set_args([temporary])
app.run()
for _ in 0 .. 8 {
	time.sleep(time.second)
	if !app.is_alive() {
		break
	}
}
if !app.is_alive() {
	app.wait()
	status := app.code
	app.close()
	fail(temporary, 'GUI exited during startup (${status})')
}
app.signal_term()
app.wait()
app.close()
os.rmdir_all(temporary) or {}
