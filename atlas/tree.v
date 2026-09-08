module atlas

import gui
import model
import os

fn make_tree(node model.Node, mut index map[string]model.Node) gui.TreeNodeCfg {
	index[node.name] = node
	mut entries := node.children.clone()
	entries.sort_with_compare(model.compare_nodes)
	mut children := []gui.TreeNodeCfg{cap: entries.len}
	for entry in entries {
		children << make_tree(entry, mut index)
	}
	return gui.tree_node(
		id:    node.name
		text:  '${os.file_name(node.name)}  ·  ${model.human(model.bytes(node))}'
		nodes: children
	)
}

fn replace_tree(nodes []gui.TreeNodeCfg, replacement gui.TreeNodeCfg) []gui.TreeNodeCfg {
	mut result := nodes.clone()
	for i, n in result {
		if n.id == replacement.id {
			result[i] = replacement
			return result
		}
		if n.nodes.len > 0 { result[i].nodes = replace_tree(n.nodes, replacement) }
	}
	return result
}
