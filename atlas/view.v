module atlas

import gui
import model
import os

const atlas_colors = [gui.Color{44, 131, 144, 255}, gui.Color{76, 111, 181, 255},
	gui.Color{142, 105, 171, 255}, gui.Color{190, 132, 65, 255},
	gui.Color{91, 143, 108, 255}, gui.Color{182, 99, 117, 255}]

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
					gui.text(
						text:       model.human(model.bytes(app.current.node))
						text_style: gui.theme().b2
					),
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
					text:       model.human(model.bytes(t.node))
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
				state.detail = '${node.name} · ${model.human(model.bytes(node))}'
			}
		}
	)
}

fn tile_at(tiles []model.Tile, x f32, y f32) ?model.Node {
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
