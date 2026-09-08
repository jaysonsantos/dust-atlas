module main

import json
import os

struct Node {
	name     string
	size     string
	children []Node
}

struct ScanResult {
	root    Node
	error   string
	warning string
}

fn bytes(n Node) u64 {
	return n.size.trim_string_right('B').u64()
}

fn scan(path string, results chan ScanResult) {
	scan_with_options(path, true, results)
}

fn dust_args(path string, limit_filesystem bool) []string {
	mut args := ['-j', '-P', '-p', '-o', 'b', '-n', '20000', '-d', '12']
	if limit_filesystem { args << '--limit-filesystem' }
	args << ['--', path]
	return args
}

fn dust_executable(directory string) !string {
	mut name := 'dust'
	$if windows { name += '.exe' }
	bundled := os.join_path(directory, name)
	if os.is_file(bundled) { return bundled }
	return os.find_abs_path_of_executable(name)
}

fn scan_with_options(path string, limit_filesystem bool, results chan ScanResult) {
	executable := dust_executable(os.dir(os.executable())) or {
		results <- ScanResult{
			error: 'Cannot find dust. Install dust and add it to PATH.'
		}
		return
	}
	mut p := os.new_process(executable)
	p.set_args(dust_args(path, limit_filesystem))
	p.set_redirect_stdio()
	p.run()
	stderr_task := spawn read_errors(mut p)
	output := p.stdout_slurp()
	errors := stderr_task.wait()
	p.wait()
	code := p.code
	p.close()
	if code != 0 {
		results <- ScanResult{
			error: 'Dust failed (${code}): ${errors.limit(220)}'
		}
		return
	}
	root := json.decode(Node, output.trim_space()) or {
		results <- ScanResult{
			error: 'Cannot read dust JSON: ${err}'
		}
		return
	}
	results <- ScanResult{
		root:    root
		warning: errors.trim_space().limit(220)
	}
}

struct Tile {
	node Node
	x    f32
	y    f32
	w    f32
	h    f32
}

// Binary subdivision keeps areas proportional without copying a third-party layout.
fn partition(nodes []Node, x f32, y f32, w f32, h f32) []Tile {
	if nodes.len == 0 { return []Tile{} }
	if nodes.len == 1 { return [Tile{ node: nodes[0], x: x, y: y, w: w, h: h }] }
	mut total := u64(0)
	for n in nodes {
		total += bytes(n)
	}
	if total == 0 { return []Tile{} }
	mut sum := u64(0)
	mut split := 1
	for i in 0 .. nodes.len - 1 {
		sum += bytes(nodes[i])
		split = i + 1
		if sum >= total / 2 { break
		 }
	}
	ratio := f32(f64(sum) / f64(total))
	mut tiles := []Tile{}
	if w >= h {
		tiles << partition(nodes[..split], x, y, w * ratio, h)
		tiles << partition(nodes[split..], x + w * ratio, y, w * (1 - ratio), h)
	} else {
		tiles << partition(nodes[..split], x, y, w, h * ratio)
		tiles << partition(nodes[split..], x, y + h * ratio, w, h * (1 - ratio))
	}
	return tiles
}

fn layout(root Node, x f32, y f32, w f32, h f32) []Tile {
	mut nodes := root.children.filter(bytes(it) > 0)
	mut total := u64(0)
	for n in nodes {
		total += bytes(n)
	}
	if bytes(root) > total {
		nodes << Node{
			name: '[Other entries / directory data]'
			size: '${bytes(root) - total}B'
		}
	}
	nodes.sort_with_compare(compare_nodes)
	return partition(nodes, x, y, w, h)
}

fn human(size u64) string {
	if size >= 1073741824 { return '${f64(size) / 1073741824:.1f} GiB' }
	if size >= 1048576 { return '${f64(size) / 1048576:.1f} MiB' }
	if size >= 1024 { return '${f64(size) / 1024:.1f} KiB' }
	return '${size} B'
}

fn read_errors(mut p os.Process) string {
	return p.stderr_slurp()
}

fn compare_nodes(a &Node, b &Node) int {
	if bytes(a) > bytes(b) { return -1 }
	if bytes(a) < bytes(b) { return 1 }
	return compare_strings(a.name, b.name)
}
