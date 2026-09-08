module atlas

import actions
import gg
import gui
import model
import os

pub struct FolderView {
	node    model.Node
	entries []model.Node
	tiles   []model.Tile
	tree    gui.TreeNodeCfg
	index   map[string]model.Node
}

@[heap]
pub struct App {
mut:
	path             string
	root             FolderView
	current          FolderView
	history          []FolderView
	busy             bool
	status           string = 'Choose a folder to explore its disk usage.'
	detail           string
	version          u64
	dark             bool
	tree_nodes       []gui.TreeNodeCfg
	node_index       map[string]model.Node
	limit_filesystem bool = true
	scan_limit       bool = true
}

// run opens the Dust Atlas window for `path` and returns after the user closes it.
pub fn run(path string) {
	// Packaged builds use host fonts without build-host configuration paths.
	font_config := os.join_path(os.dir(os.executable()), 'fonts.conf')
	if os.getenv('FONTCONFIG_FILE') == '' && os.is_file(font_config) {
		os.setenv('FONTCONFIG_FILE', font_config, true)
	}
	mut window := gui.window(
		title:        'Dust Atlas'
		app_id:       'local.dustatlas.app'
		width:        1180
		height:       800
		cursor_blink: true
		state:        &App{
			path: path
		}
		on_init:      fn (mut w gui.Window) {
			// Metal already schedules frames. Disable gg's second, blocking limiter.
			$if macos {
				mut context := w.context()
				context.config = gg.Config{
					...context.config
					swap_interval: 0
				}
			}
			w.update_view(main_view)
		}
	)
	window.set_theme(atlas_light_theme())
	window.run()
}

// Scan, JSON decoding, sorting, and treemap subdivision all run on this worker.
fn load_folder(path string, cached model.Node, as_child bool, limit_filesystem bool, mut w gui.Window) {
	mut node := cached
	mut warning := ''
	if cached.name == '' {
		results := chan model.ScanResult{cap: 1}
		model.scan_with_options(path, limit_filesystem, results)
		result := <-results
		if result.error != '' {
			message := result.error
			w.queue_command(fn [message] (mut window gui.Window) {
				mut app := window.state[App]()
				app.busy = false
				app.status = message
				window.update_window()
			})
			return
		}
		node = result.root
		warning = result.warning
	}
	mut entries := node.children.clone()
	entries.sort_with_compare(model.compare_nodes)
	mut index := map[string]model.Node{}
	tree := make_tree(node, mut index)
	view := FolderView{
		node:    node
		entries: entries
		tiles:   model.layout(node, 0, 0, 1000, 700)
		tree:    tree
		index:   index
	}
	w.queue_command(fn [view, as_child, warning] (mut window gui.Window) {
		mut app := window.state[App]()
		if as_child {
			app.history << app.current
			app.tree_nodes = replace_tree(app.tree_nodes, view.tree)
			for path, n in view.index {
				app.node_index[path] = n
			}
		} else {
			app.root = view
			app.tree_nodes = view.tree.nodes
			app.node_index = view.index.clone()
			app.history.clear()
		}
		app.current = view
		app.busy = false
		app.detail = ''
		app.version++
		app.status = if warning == '' {
			'Scan complete · Select a folder to explore its contents.'
		} else {
			'Dust warning: ${warning}'
		}
		window.update_window()
	})
}

fn begin_scan(mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy { return }
	app.busy = true
	app.detail = ''
	app.status = 'Scan in progress… You can still move and resize this window.'
	app.scan_limit = app.limit_filesystem
	spawn load_folder(os.abs_path(app.path), model.Node{}, false, app.scan_limit, mut w)
}

fn open_node(n model.Node, mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy { return }
	if n.children.len == 0 && !os.is_dir(n.name) {
		app.detail = '${n.name} · ${model.human(model.bytes(n))}'
		return
	}
	app.busy = true
	app.detail = ''
	app.status = 'Open folder…'
	cached := if n.children.len > 0 { n } else { model.Node{} }
	spawn load_folder(n.name, cached, true, app.scan_limit, mut w)
}

fn go_back(mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy || app.history.len == 0 { return }
	app.current = app.history.pop()
	app.detail = ''
	app.version++
}

fn browse(mut w gui.Window) {
	app := w.state[App]()
	w.native_folder_dialog(
		title:                  'Choose a folder to scan'
		start_dir:              app.path
		can_create_directories: false
		on_done:                fn (result gui.NativeDialogResult, mut window gui.Window) {
			if result.paths.len > 0 {
				mut state := window.state[App]()
				state.path = result.paths[0].path
				begin_scan(mut window)
			} else if result.error_message != '' {
				mut state := window.state[App]()
				state.status = result.error_message
			}
		}
	)
}

fn show_file_menu(path string, mut w gui.Window) {
	// Native menus run a nested event loop. Start after event traversal returns,
	// so a modal dialog cannot invalidate the active tree row's layout pointer.
	w.queue_command(fn [path] (mut window gui.Window) {
		open_file_menu(path, mut window)
	})
}

fn open_file_menu(path string, mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy || !actions.valid_action_path(path) || path !in app.node_index { return }
	action := actions.file_menu(path)
	if action < 0 {
		app.status = 'Trash and deletion are available on macOS only.'
		w.update_window()
		return
	}
	if action == 0 { return }
	app.busy = true
	app.detail = ''
	app.status = if action == 1 { 'Move to Trash…' } else { 'Delete item…' }
	w.update_window()
	root_path := app.root.node.name
	spawn remove_and_refresh(path, action == 2, root_path, app.scan_limit, mut w)
}

fn remove_and_refresh(path string, permanent bool, root_path string, limit_filesystem bool, mut w gui.Window) {
	actions.remove_entry(path, permanent) or {
		message := err.msg()
		w.queue_command(fn [message] (mut window gui.Window) {
			mut app := window.state[App]()
			app.busy = false
			app.status = 'Cannot remove item: ${message}'
			window.update_window()
		})
		return
	}
	// Re-read totals after a successful operation. Never present stale sizes.
	load_folder(root_path, model.Node{}, false, limit_filesystem, mut w)
}
