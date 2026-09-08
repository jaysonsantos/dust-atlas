module main

import gui
import gg
import os

const atlas_colors = [gui.Color{44, 131, 144, 255}, gui.Color{76, 111, 181, 255},
	gui.Color{142, 105, 171, 255}, gui.Color{190, 132, 65, 255},
	gui.Color{91, 143, 108, 255}, gui.Color{182, 99, 117, 255}]

struct FolderView {
	node    Node
	entries []Node
	tiles   []Tile
	tree    gui.TreeNodeCfg
	index   map[string]Node
}

@[heap]
struct App {
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
	node_index       map[string]Node
	limit_filesystem bool = true
	scan_limit       bool = true
}

fn main() {
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
			path: if os.args.len > 1 { os.abs_path(os.args[1]) } else { os.home_dir() }
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
fn load_folder(path string, cached Node, as_child bool, limit_filesystem bool, mut w gui.Window) {
	mut node := cached
	mut warning := ''
	if cached.name == '' {
		results := chan ScanResult{cap: 1}
		scan_with_options(path, limit_filesystem, results)
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
	entries.sort_with_compare(compare_nodes)
	mut index := map[string]Node{}
	tree := make_tree(node, mut index)
	view := FolderView{
		node:    node
		entries: entries
		tiles:   layout(node, 0, 0, 1000, 700)
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
	spawn load_folder(os.abs_path(app.path), Node{}, false, app.scan_limit, mut w)
}

fn open_node(n Node, mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy { return }
	if n.children.len == 0 && !os.is_dir(n.name) {
		app.detail = '${n.name} · ${human(bytes(n))}'
		return
	}
	app.busy = true
	app.detail = ''
	app.status = 'Open folder…'
	cached := if n.children.len > 0 { n } else { Node{} }
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

fn main_view(mut window gui.Window) gui.View {
	app := window.state[App]()
	w, h := window.window_size()
	// The outer scroll container also keeps controls reachable in small windows.
	content_width := f32_max(850, w - 48)
	graph_width := content_width - 370
	graph_height := f32_max(260, h - 360)
	panel := gui.theme().color_panel
	muted := gui.TextStyle{
		...gui.theme().n4
		color: if app.dark { gui.Color{159, 177, 197, 255} } else { gui.Color{93, 109, 130, 255} }
	}
	return gui.column(
		width:           w
		height:          h
		sizing:          gui.fixed_fixed
		color:           gui.theme().color_background
		padding:         gui.padding(24, 24, 20, 24)
		spacing:         16
		id_scroll:       1
		scrollbar_cfg_x: &gui.ScrollbarCfg{
			overflow: .on_hover
		}
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			overflow: .on_hover
		}
		content:         [
			gui.row(
				padding: gui.padding_none
				width:   content_width
				sizing:  gui.fixed_fit
				v_align: .middle
				spacing: 14
				content: [
					gui.column(
						sizing:  gui.fill_fit
						padding: gui.padding_none
						spacing: 4
						content: [
							gui.text(text: 'Dust Atlas', text_style: gui.theme().b1),
							gui.text(text: 'See where your space goes.', text_style: muted),
						]
					),
					gui.checkbox(
						id:       'limit-filesystem'
						id_focus: 9
						label:    'Stay on this filesystem'
						select:   app.limit_filesystem
						disabled: app.busy
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[App]()
							state.limit_filesystem = !state.limit_filesystem
						}
					),
					gui.button(
						id_focus: 8
						content:  [
							gui.text(
								text: if app.dark { 'Light appearance' } else { 'Dark appearance' }
							),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[App]()
							state.dark = !state.dark
							w.set_theme(if state.dark {
								gui.theme_dark_bordered
							} else {
								atlas_light_theme()
							})
						}
					),
				]
			),
			gui.row(
				padding: gui.padding_none
				width:   content_width
				sizing:  gui.fixed_fit
				spacing: 10
				v_align: .middle
				content: [
					gui.input(
						id:              'folder-path'
						id_focus:        1
						text:            app.path
						placeholder:     'Folder path'
						sizing:          gui.fill_fit
						on_text_changed: fn (_ &gui.Layout, value string, mut w gui.Window) {
							w.state[App]().path = value
						}
						on_enter:        fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							begin_scan(mut w)
						}
					),
					gui.button(
						id_focus: 2
						disabled: app.busy
						content:  [
							gui.text(text: 'Browse…'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							browse(mut w)
						}
					),
					gui.button(
						id_focus: 3
						disabled: app.busy
						color:    gui.Color{44, 112, 167, 255}
						content:  [
							gui.text(
								text:       if app.busy { 'Please wait…' } else { 'Scan folder' }
								text_style: gui.TextStyle{
									...gui.theme().b3
									color: gui.white
								}
							),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							begin_scan(mut w)
						}
					),
				]
			),
			gui.row(
				padding: gui.padding_none
				width:   content_width
				sizing:  gui.fixed_fit
				v_align: .middle
				spacing: 10
				content: [
					gui.button(
						id_focus: 4
						disabled: app.busy || app.history.len == 0
						content:  [
							gui.text(text: '← Back'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							go_back(mut w)
						}
					),
					gui.button(
						id_focus: 5
						disabled: app.busy || app.current.node.name == ''
						content:  [
							gui.text(text: 'Scan root'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[App]()
							state.current = state.root
							state.history.clear()
							state.detail = ''
							state.version++
						}
					),
					gui.column(
						sizing:  gui.fill_fit
						padding: gui.padding(0, 8, 0, 8)
						content: [
							gui.text(
								text:       if app.current.node.name == '' {
									'No folder selected'
								} else {
									app.current.node.name
								}
								mode:       .single_line
								text_style: muted
							),
						]
					),
					gui.text(text: human(bytes(app.current.node)), text_style: gui.theme().b2),
				]
			),
			gui.row(
				padding: gui.padding_none
				width:   content_width
				sizing:  gui.fixed_fit
				spacing: 18
				content: [
					gui.column(
						width:   352
						sizing:  gui.fixed_fit
						padding: gui.padding(12, 12, 12, 12)
						spacing: 12
						radius:  12
						color:   panel
						content: [
							gui.row(
								padding: gui.padding_none
								sizing:  gui.fill_fit
								content: [
									gui.text(text: 'Folder tree', text_style: gui.theme().b3),
								]
							),
							window.tree(
								id:              'folders'
								id_scroll:       10
								id_focus:        20
								height:          graph_height
								max_height:      graph_height
								nodes:           app.tree_nodes
								on_select:       fn (id string, mut w gui.Window) {
									state := w.state[App]()
									if n := state.node_index[id] { open_node(n, mut w) }
								}
								on_context_menu: fn (id string, mut w gui.Window) {
									show_file_menu(id, mut w)
								}
							),
							gui.text(
								text:       '${app.tree_nodes.len} top-level entries · Largest first'
								text_style: muted
							),
						]
					),
					gui.column(
						width:   graph_width
						sizing:  gui.fixed_fit
						padding: gui.padding_none
						spacing: 12
						content: [
							gui.row(
								sizing:  gui.fill_fit
								padding: gui.padding(12, 0, 0, 0)
								content: [
									gui.text(text: 'Space map', text_style: gui.theme().b3),
								]
							),
							treemap(app, graph_width, graph_height),
							gui.text(
								text:       'Rectangle area represents disk space.'
								text_style: muted
							),
						]
					),
				]
			),
			gui.text(
				text:       if app.detail != '' && !app.busy { app.detail } else { app.status }
				text_style: muted
				mode:       .wrap
			),
		]
	)
}

fn treemap(app &App, width f32, height f32) gui.View {
	if app.current.tiles.len == 0 {
		return gui.column(
			width:   width
			height:  height
			sizing:  gui.fixed_fixed
			radius:  12
			color:   gui.theme().color_panel
			h_align: .center
			v_align: .middle
			spacing: 12
			content: [
				gui.text(
					text:       if app.current.node.name == '' {
						'A clearer view of your disk'
					} else {
						'This folder is empty'
					}
					text_style: gui.theme().b2
				),
				gui.text(
					text:       if app.current.node.name == '' {
						'Choose a folder to create your space map.'
					} else {
						'Use Back to return to its parent.'
					}
					text_style: gui.theme().n4
				),
			]
		)
	}
	tiles := app.current.tiles
	mut children := []gui.View{}
	children << gui.draw_canvas(
		id:      'space-geometry'
		width:   width
		height:  height
		version: app.version * 100000000 + u64(width) * 10000 + u64(height)
		on_draw: fn [tiles] (mut dc gui.DrawContext) {
			for i, t in tiles {
				x, y := t.x * dc.width / 1000, t.y * dc.height / 700
				tw, th := t.w * dc.width / 1000, t.h * dc.height / 700
				if tw > 2 && th > 2 {
					dc.filled_rect(x + 1, y + 1, tw - 2, th - 2, atlas_colors[i % atlas_colors.len])
				}
			}
		}
	)
	// One subtle overlay keeps gradient work constant as tile count grows.
	children << gui.rectangle(
		width:    width
		height:   height
		sizing:   gui.fixed_fixed
		radius:   0
		color:    gui.color_transparent
		gradient: &gui.Gradient{
			direction: .to_bottom
			stops:     [
				gui.GradientStop{
					pos:   0
					color: gui.Color{255, 255, 255, 14}
				},
				gui.GradientStop{
					pos:   1
					color: gui.Color{0, 0, 0, 20}
				},
			]
		}
	)

	for t in tiles {
		tw, th := t.w * width / 1000, t.h * height / 700
		if tw < 105 || th < 62 { continue
		 }
		children << gui.column(
			x:       t.x * width / 1000 + 10
			y:       t.y * height / 700 + 10
			width:   tw - 20
			height:  th - 20
			sizing:  gui.fixed_fixed
			clip:    true
			padding: gui.padding_none
			spacing: 4
			content: [
				gui.text(
					text:       os.file_name(t.node.name)
					text_style: gui.TextStyle{
						...gui.theme().b4
						color: gui.white
					}
				),
				gui.text(
					text:       human(bytes(t.node))
					text_style: gui.TextStyle{
						...gui.theme().n4
						color: gui.white
					}
				),
			]
		)
	}
	return gui.canvas(
		id:           'space-map'
		width:        width
		height:       height
		sizing:       gui.fixed_fixed
		padding:      gui.padding_none
		radius:       12
		clip:         true
		content:      children
		on_any_click: fn (l &gui.Layout, mut e gui.Event, mut w gui.Window) {
			state := w.state[App]()
			if node := tile_at(state.current.tiles, e.mouse_x * 1000 / l.shape.width,
				e.mouse_y * 700 / l.shape.height)
			{
				if e.mouse_button == .right || (e.mouse_button == .left && e.modifiers == .ctrl) {
					show_file_menu(node.name, mut w)
				} else if e.mouse_button == .left {
					open_node(node, mut w)
				}
				e.is_handled = true
			}
		}
		on_hover:     fn (mut l gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut state := w.state[App]()
			if node := tile_at(state.current.tiles, (e.mouse_x - l.shape.x) * 1000 / l.shape.width,
				(e.mouse_y - l.shape.y) * 700 / l.shape.height)
			{
				state.detail = '${node.name} · ${human(bytes(node))}'
			}
		}
	)
}

fn tile_at(tiles []Tile, x f32, y f32) ?Node {
	for t in tiles {
		if x >= t.x && x < t.x + t.w && y >= t.y && y < t.y + t.h { return t.node }
	}
	return none
}

fn atlas_light_theme() gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		...gui.theme_light_bordered_cfg
		name:               'Atlas light'
		color_background:   gui.Color{243, 246, 250, 255}
		color_panel:        gui.white
		color_interior:     gui.white
		color_border:       gui.Color{216, 224, 234, 255}
		color_hover:        gui.Color{232, 240, 249, 255}
		color_focus:        gui.Color{222, 235, 249, 255}
		color_active:       gui.Color{204, 226, 245, 255}
		color_select:       gui.Color{210, 231, 249, 255}
		color_border_focus: gui.Color{44, 112, 167, 255}
		radius:             8
		text_style:         gui.TextStyle{
			...gui.theme_light_cfg.text_style
			family: 'Helvetica Neue'
			color:  gui.Color{34, 47, 65, 255}
		}
	})
}

fn make_tree(node Node, mut index map[string]Node) gui.TreeNodeCfg {
	index[node.name] = node
	mut entries := node.children.clone()
	entries.sort_with_compare(compare_nodes)
	mut children := []gui.TreeNodeCfg{cap: entries.len}
	for entry in entries {
		children << make_tree(entry, mut index)
	}
	return gui.tree_node(
		id:    node.name
		text:  '${os.file_name(node.name)}  ·  ${human(bytes(node))}'
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

fn show_file_menu(path string, mut w gui.Window) {
	// Native menus run a nested event loop. Start after event traversal returns,
	// so a modal dialog cannot invalidate the active tree row's layout pointer.
	w.queue_command(fn [path] (mut window gui.Window) {
		open_file_menu(path, mut window)
	})
}

fn open_file_menu(path string, mut w gui.Window) {
	mut app := w.state[App]()
	if app.busy || !valid_action_path(path) || path !in app.node_index { return }
	action := file_menu(path)
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

fn valid_action_path(path string) bool {
	return os.is_abs_path(path) && os.norm_path(path) != '/'
}

fn remove_and_refresh(path string, permanent bool, root_path string, limit_filesystem bool, mut w gui.Window) {
	remove_entry(path, permanent) or {
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
	load_folder(root_path, Node{}, false, limit_filesystem, mut w)
}
