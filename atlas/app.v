module atlas

import actions
import gg
import gui
import model
import os

pub struct FolderView {
	node    model.Node
	entries []model.Node
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
	// Tiles hold real pixel geometry, so they are rebuilt when the map resizes.
	tiles   []model.Tile
	tiles_w f32
	tiles_h f32
	// Pointer and keyboard focus inside the space map.
	hover   int = -1
	hover_x f32
	hover_y f32
	keyed   int = -1
	// One scan runs at a time. `scan_seq` drops the results of cancelled scans.
	scan_seq    u64
	scan_cancel chan bool = chan bool{cap: 1}
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

// ancestors lists the folder paths from the scan root down to the open folder.
fn (app &App) ancestors() []string {
	mut paths := []string{cap: app.history.len + 1}
	for view in app.history {
		paths << view.node.name
	}
	if app.current.node.name != '' {
		paths << app.current.node.name
	}
	return paths
}

// retile rebuilds the tile geometry for the given map size. It keeps the last
// size, so a redraw at an unchanged size does no work.
fn (mut app App) retile(w f32, h f32) {
	if w == app.tiles_w && h == app.tiles_h {
		return
	}
	app.tiles_w = w
	app.tiles_h = h
	app.tiles = model.layout(app.current.entries, 0, 0, w, h)
	app.hover = -1
	if app.keyed >= app.tiles.len {
		app.keyed = -1
	}
}

// reveal_current scrolls the folder tree to the open folder. The scroll runs
// after the render that expands its ancestors, so the row exists by then.
fn reveal_current(mut w gui.Window) {
	app := w.state[App]()
	id := gui.tree_row_id(tree_id, app.current.node.name)
	w.queue_command(fn [id] (mut window gui.Window) {
		window.queue_command(fn [id] (mut inner gui.Window) {
			inner.scroll_to_view(id)
		})
	})
}

// show applies `view` as the open folder and rebuilds the derived state.
fn (mut app App) show(view FolderView) {
	app.current = view
	app.path = view.node.name
	app.detail = ''
	app.hover = -1
	app.keyed = -1
	app.tiles_w = 0
	app.tiles_h = 0
	app.version++
}

// Scan, JSON decoding, sorting, and tree preparation all run on this worker.
fn load_folder(path string, cached model.Node, as_child bool, limit_filesystem bool, seq u64, cancel chan bool, mut w gui.Window) {
	mut node := cached
	mut warning := ''
	if cached.name == '' {
		results := chan model.ScanResult{cap: 1}
		model.scan_with_options(path, limit_filesystem, cancel, results)
		result := <-results
		if result.error != '' {
			message := result.error
			w.queue_command(fn [message, seq] (mut window gui.Window) {
				mut app := window.state[App]()
				if app.scan_seq != seq {
					return
				}
				app.busy = false
				app.status = message
				window.update_window()
			})
			return
		}
		node = result.root
		warning = result.warning
	}
	mut index := map[string]model.Node{}
	tree := make_tree(node, mut index)
	view := FolderView{
		node:    node
		entries: model.entries(node)
		tree:    tree
		index:   index
	}
	w.queue_command(fn [view, as_child, warning, seq] (mut window gui.Window) {
		mut app := window.state[App]()
		if app.scan_seq != seq {
			return
		}
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
		app.show(view)
		reveal_current(mut window)
		app.busy = false
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
	if app.busy {
		return
	}
	app.busy = true
	app.detail = ''
	app.status = 'Scan in progress… You can still move and resize this window.'
	app.scan_limit = app.limit_filesystem
	app.scan_seq++
	spawn load_folder(os.abs_path(app.path), model.Node{}, false, app.scan_limit, app.scan_seq,
		app.scan_cancel, mut w)
}

fn cancel_scan(mut w gui.Window) {
	mut app := w.state[App]()
	if !app.busy {
		return
	}
	// The sequence number rises first, so the abandoned worker cannot apply.
	app.scan_seq++
	app.scan_cancel <- true
	app.busy = false
	app.status = 'Scan cancelled.'
}

fn open_node(n model.Node, mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy {
		return
	}
	if n.children.len == 0 && !os.is_dir(n.name) {
		app.detail = '${os.file_name(n.name)} · ${model.human(model.bytes(n))}'
		return
	}
	app.busy = true
	app.detail = ''
	app.status = 'Open folder…'
	app.scan_seq++
	cached := if n.children.len > 0 { n } else { model.Node{} }
	spawn load_folder(n.name, cached, true, app.scan_limit, app.scan_seq, app.scan_cancel, mut w)
}

fn go_back(mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy || app.history.len == 0 {
		return
	}
	view := app.history.pop()
	app.show(view)
	reveal_current(mut w)
}

// go_to_depth opens the ancestor at `depth`, where 0 is the scan root.
fn go_to_depth(depth int, mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy || depth < 0 || depth >= app.history.len {
		return
	}
	view := app.history[depth]
	app.history = app.history[..depth].clone()
	app.show(view)
	reveal_current(mut w)
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
	if app.busy || !actions.valid_action_path(path) || path !in app.node_index {
		return
	}
	action := actions.file_menu(path)
	if action < 0 {
		app.status = 'Trash and deletion are available on macOS only.'
		w.update_window()
		return
	}
	if action == 0 {
		return
	}
	app.busy = true
	app.detail = ''
	app.status = if action == 1 { 'Move to Trash…' } else { 'Delete item…' }
	app.scan_seq++
	w.update_window()
	root_path := app.root.node.name
	spawn remove_and_refresh(path, action == 2, root_path, app.scan_limit, app.scan_seq,
		app.scan_cancel, mut w)
}

fn remove_and_refresh(path string, permanent bool, root_path string, limit_filesystem bool, seq u64, cancel chan bool, mut w gui.Window) {
	actions.remove_entry(path, permanent) or {
		message := err.msg()
		w.queue_command(fn [message, seq] (mut window gui.Window) {
			mut app := window.state[App]()
			if app.scan_seq != seq {
				return
			}
			app.busy = false
			app.status = 'Cannot remove item: ${message}'
			window.update_window()
		})
		return
	}
	// Re-read totals after a successful operation. Never present stale sizes.
	load_folder(root_path, model.Node{}, false, limit_filesystem, seq, cancel, mut w)
}
