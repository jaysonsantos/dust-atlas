module model

import math
import os

fn test_layout_preserves_area_and_remainder() {
	root := Node{
		name:     'root'
		size:     '100B'
		children: [Node{ name: 'a', size: '60B' }, Node{ name: 'b', size: '20B' }]
	}
	tiles := layout(entries(root), 0, 0, 100, 100)
	assert tiles.len == 3
	mut area := f32(0)
	for tile in tiles {
		assert math.abs(tile.w * tile.h - f32(bytes(tile.node)) * 100) < 0.1
		assert tile.x >= 0 && tile.y >= 0
		assert tile.x + tile.w <= 100.01 && tile.y + tile.h <= 100.01
		area += tile.w * tile.h
	}
	assert math.abs(area - 10000) < 0.1
}

fn test_empty_layout() {
	assert layout(entries(Node{}), 0, 0, 100, 100).len == 0
	assert layout(entries(root_fixture()), 0, 0, 0, 100).len == 0
}

fn root_fixture() Node {
	return Node{
		name:     'root'
		size:     '100B'
		children: [Node{
			name: 'a'
			size: '60B'
		}]
	}
}

fn test_layout_follows_the_map_shape() {
	// A wide rectangle splits along x; a tall one splits along y.
	nodes := entries(Node{
		name:     'root'
		size:     '100B'
		children: [Node{ name: 'a', size: '50B' }, Node{ name: 'b', size: '50B' }]
	})
	wide := layout(nodes, 0, 0, 400, 100)
	tall := layout(nodes, 0, 0, 100, 400)
	assert wide[0].w < wide[0].h * 4
	assert wide[0].y == wide[1].y
	assert tall[0].x == tall[1].x
}

fn test_entries_name_the_unexplained_space() {
	nodes := entries(Node{
		name:     '/root'
		size:     '100B'
		children: [Node{ name: '/root/a', size: '60B' }]
	})
	assert nodes.len == 2
	assert os.file_name(nodes[1].name) == 'Other files in this folder'
	assert bytes(nodes[1]) == 40
}

fn test_real_dust_handles_special_path() {
	path := os.join_path(os.temp_dir(), 'dust-atlas test ${os.getpid()} & quote\' ü')
	os.mkdir_all(path) or { panic(err) }
	defer { os.rmdir_all(path) or {} }
	os.write_file(os.join_path(path, 'sample.txt'), 'test data'.repeat(1000)) or { panic(err) }
	results := chan ScanResult{cap: 1}
	scan(path, results)
	result := <-results
	assert result.error == ''
	assert result.root.name == path
	assert bytes(result.root) > 0
	assert result.root.children.len == 1
}

fn test_filesystem_limit_is_optional_and_path_remains_one_argument() {
	path := '/tmp/a folder & --all'
	limited := dust_args(path, true)
	unlimited := dust_args(path, false)
	assert '--limit-filesystem' in limited
	assert '--limit-filesystem' !in unlimited
	assert limited[limited.len - 2] == '--'
	assert limited.last() == path
	assert unlimited.last() == path
}

fn test_bundled_dust_takes_precedence_over_path() {
	path := os.join_path(os.temp_dir(), 'atlas-bundled-${os.getpid()}')
	os.mkdir_all(path) or { panic(err) }
	defer { os.rmdir_all(path) or {} }
	mut name := 'dust'
	$if windows { name += '.exe' }
	bundled := os.join_path(path, name)
	os.write_file(bundled, 'fixture') or { panic(err) }
	assert dust_executable(path) or { panic(err) } == bundled
	os.rm(bundled) or { panic(err) }
	assert dust_executable(path) or { panic(err) } == os.find_abs_path_of_executable(name) or {
		panic(err)
	}
}
