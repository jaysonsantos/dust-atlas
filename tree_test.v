module main

fn test_tree_keeps_full_paths_and_replaces_only_loaded_branch() {
	node := Node{
		name:     '/fixture'
		size:     '12B'
		children: [
			Node{
				name:     '/fixture/left'
				size:     '8B'
				children: [
					Node{
						name: '/fixture/left/same.txt'
						size: '8B'
					},
				]
			},
			Node{
				name:     '/fixture/right'
				size:     '4B'
				children: [
					Node{
						name: '/fixture/right/same.txt'
						size: '4B'
					},
				]
			},
		]
	}
	mut index := map[string]Node{}
	tree := make_tree(node, mut index)
	assert index.len == 5
	assert bytes(index['/fixture/left/same.txt']) == 8
	assert bytes(index['/fixture/right/same.txt']) == 4
	replacement := make_tree(Node{ name: '/fixture/left', size: '0B' }, mut index)
	updated := replace_tree(tree.nodes, replacement)
	assert updated[0].nodes.len == 0
	assert updated[1].nodes[0].id == '/fixture/right/same.txt'
	assert tree.nodes[0].nodes.len == 1
}
