module atlas

import gui
import model
import os

// The map ramps from warm for the largest entry to cool for the smallest, so
// rank is readable without a legend.
const atlas_ramp = [gui.Color{197, 86, 62, 255}, gui.Color{201, 133, 58, 255},
	gui.Color{169, 154, 66, 255}, gui.Color{92, 146, 104, 255},
	gui.Color{64, 130, 152, 255}, gui.Color{86, 106, 172, 255},
	gui.Color{125, 96, 163, 255}]

const tree_id = 'folders'

fn main_view(mut window gui.Window) gui.View {
	mut app := window.state[App]()
	w, h := window.window_size()
	// The outer scroll container also keeps controls reachable in small windows.
	content_width := f32_max(560, w - 48)
	tree_width := f32_min(360, f32_max(230, content_width * 0.30))
	graph_width := content_width - tree_width - 18
	graph_height := f32_max(220, h - 372)
	app.retile(graph_width, graph_height)
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
		padding:         gui.padding(20, 24, 16, 24)
		spacing:         14
		id_scroll:       1
		on_mouse_move:   fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			// The map marks its own moves as handled, so this runs off the map.
			mut state := w.state[App]()
			if state.hover >= 0 {
				state.hover = -1
				w.update_window()
			}
		}
		scrollbar_cfg_x: &gui.ScrollbarCfg{
			overflow: .on_hover
		}
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			overflow: .on_hover
		}
		content:         [
			header_row(app, content_width, muted),
			path_row(app, content_width),
			nav_row(app, content_width, muted),
			gui.row(
				padding: gui.padding_none
				width:   content_width
				sizing:  gui.fixed_fit
				spacing: 18
				content: [
					tree_panel(mut window, app, tree_width, graph_height, panel, muted),
					map_panel(app, graph_width, graph_height, muted),
				]
			),
			footer(app, content_width, muted),
		]
	)
}

fn header_row(app &App, content_width f32, muted gui.TextStyle) gui.View {
	mut title := []gui.View{cap: 2}
	title << gui.text(text: 'Dust Atlas', text_style: gui.theme().b1)
	// The tagline explains the empty app. A scanned map explains itself.
	if app.current.node.name == '' {
		title << gui.text(text: 'See where your space goes.', text_style: muted)
	}
	return gui.row(
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
				content: title
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
	)
}

fn path_row(app &App, content_width f32) gui.View {
	mut buttons := []gui.View{cap: 3}
	buttons << gui.input(
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
	)
	buttons << gui.button(
		id_focus: 2
		disabled: app.busy
		content:  [
			gui.text(text: 'Browse…'),
		]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			browse(mut w)
		}
	)
	scan_label := gui.TextStyle{
		...gui.theme().b3
		color: gui.white
	}
	if app.busy {
		buttons << gui.button(
			id_focus: 3
			content:  [
				gui.text(text: 'Cancel scan'),
			]
			on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
				cancel_scan(mut w)
			}
		)
	} else {
		buttons << gui.button(
			id_focus: 3
			color:    gui.Color{44, 112, 167, 255}
			content:  [
				gui.text(text: 'Scan this folder', text_style: scan_label),
			]
			on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
				begin_scan(mut w)
			}
		)
	}
	return gui.row(
		padding: gui.padding_none
		width:   content_width
		sizing:  gui.fixed_fit
		spacing: 10
		v_align: .middle
		content: buttons
	)
}

fn nav_row(app &App, content_width f32, muted gui.TextStyle) gui.View {
	return gui.row(
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
				disabled: app.busy || app.history.len == 0
				content:  [
					gui.text(text: 'Top folder'),
				]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					go_to_depth(0, mut w)
				}
			),
			gui.column(
				sizing:  gui.fill_fit
				padding: gui.padding(0, 8, 0, 8)
				clip:    true
				content: [
					trail(app, muted),
				]
			),
			gui.text(
				text:       model.human(model.bytes(app.current.node))
				text_style: gui.theme().b2
			),
		]
	)
}

// trail builds the clickable path from the scan root down to the open folder.
fn trail(app &App, muted gui.TextStyle) gui.View {
	paths := app.ancestors()
	if paths.len == 0 {
		return gui.text(text: 'No folder selected', mode: .single_line, text_style: muted)
	}
	mut items := []gui.BreadcrumbItemCfg{cap: paths.len}
	for i, path in paths {
		label := if i == 0 { path } else { os.file_name(path) }
		items << gui.BreadcrumbItemCfg{
			id:    '${i}'
			label: label
		}
	}
	return gui.breadcrumb(
		id:        'trail'
		id_focus:  6
		items:     items
		selected:  '${paths.len - 1}'
		disabled:  app.busy
		on_select: fn (id string, mut _ gui.Event, mut w gui.Window) {
			go_to_depth(id.int(), mut w)
		}
	)
}

fn tree_panel(mut window gui.Window, app &App, width f32, height f32, panel gui.Color, muted gui.TextStyle) gui.View {
	return gui.column(
		width:   width
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
				id:              tree_id
				id_scroll:       10
				id_focus:        20
				height:          height
				max_height:      height
				nodes:           app.tree_nodes
				selected:        app.current.node.name
				reveal:          app.ancestors()
				on_select:       fn (id string, mut w gui.Window) {
					state := w.state[App]()
					if n := state.node_index[id] {
						open_node(n, mut w)
					}
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
	)
}

fn map_panel(app &App, width f32, height f32, muted gui.TextStyle) gui.View {
	mut hint := 'Rectangle area represents disk space.'
	$if macos {
		hint += ' Right-click an item to move it to Trash.'
	}
	return gui.column(
		width:   width
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
			treemap(app, width, height),
			gui.text(text: hint, text_style: muted),
		]
	)
}

fn footer(app &App, content_width f32, muted gui.TextStyle) gui.View {
	mut content := []gui.View{cap: 2}
	if app.busy {
		content << gui.progress_bar(
			id:         'scan-progress'
			width:      content_width
			sizing:     gui.fixed_fit
			indefinite: true
			text_show:  false
		)
	}
	content << gui.text(
		text:       if app.detail != '' && !app.busy { app.detail } else { app.status }
		text_style: muted
		mode:       .wrap
	)
	return gui.column(
		width:   content_width
		sizing:  gui.fixed_fit
		padding: gui.padding_none
		spacing: 8
		content: content
	)
}

// tile_color ramps from warm for the largest entry to cool for the smallest.
fn tile_color(rank int, count int) gui.Color {
	if count <= 1 {
		return atlas_ramp[0]
	}
	span := f32(rank) * f32(atlas_ramp.len - 1) / f32(count - 1)
	first := int(span)
	if first >= atlas_ramp.len - 1 {
		return atlas_ramp[atlas_ramp.len - 1]
	}
	t := span - f32(first)
	a, b := atlas_ramp[first], atlas_ramp[first + 1]
	return gui.Color{
		r: u8(f32(a.r) + (f32(b.r) - f32(a.r)) * t)
		g: u8(f32(a.g) + (f32(b.g) - f32(a.g)) * t)
		b: u8(f32(a.b) + (f32(b.b) - f32(a.b)) * t)
		a: 255
	}
}

// cushion shades one tile like a lit pillow. Two crossed passes of bands cost
// far less than a per-pixel surface and read the same at map sizes.
fn cushion(mut dc gui.DrawContext, x f32, y f32, w f32, h f32, base gui.Color) {
	dc.filled_rect(x, y, w, h, base)
	if w < 10 || h < 10 {
		return
	}
	// Enough bands that the steps blend, few enough to stay cheap.
	bands := int(f32_min(24, f32_max(10, f32_min(w, h) / 6)))
	bw, bh := w / f32(bands), h / f32(bands)
	for i in 0 .. bands {
		// -1 at the lit edge, +1 at the shaded edge.
		s := 2 * ((f32(i) + 0.5) / f32(bands)) - 1
		level := u8(34 * s * s)
		shade := if s < 0 {
			gui.Color{255, 255, 255, level}
		} else {
			gui.Color{0, 0, 0, level}
		}
		dc.filled_rect(x + f32(i) * bw, y, bw, h, shade)
		dc.filled_rect(x, y + f32(i) * bh, w, bh, shade)
	}
}

fn treemap(app &App, width f32, height f32) gui.View {
	if app.tiles.len == 0 {
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
	tiles := app.tiles
	marked := if app.hover >= 0 { app.hover } else { app.keyed }
	mut children := []gui.View{}
	children << gui.draw_canvas(
		id:      'space-geometry'
		width:   width
		height:  height
		version: app.version * 1000003 + u64(marked + 1) * 1009 + u64(width) * 31 + u64(height)
		on_draw: fn [tiles, marked] (mut dc gui.DrawContext) {
			for i, t in tiles {
				if t.w <= 2 || t.h <= 2 {
					continue
				}
				cushion(mut dc, t.x + 1, t.y + 1, t.w - 2, t.h - 2, tile_color(i, tiles.len))
			}
			if marked >= 0 && marked < tiles.len {
				t := tiles[marked]
				// A dark line under the white one keeps the mark on pale tiles.
				dc.rect(t.x + 3, t.y + 3, t.w - 6, t.h - 6, gui.Color{0, 0, 0, 90}, 5)
				dc.rect(t.x + 2, t.y + 2, t.w - 4, t.h - 4, gui.white, 3)
			}
		}
	)

	for t in tiles {
		if t.w < 46 || t.h < 20 {
			continue
		}
		mut label := []gui.View{cap: 2}
		label << gui.text(
			text:       os.file_name(t.node.name)
			text_style: gui.TextStyle{
				...gui.theme().b4
				color: gui.white
			}
		)
		// Only roomy tiles carry a second line. Smaller ones keep the name.
		if t.w >= 92 && t.h >= 40 {
			label << gui.text(
				text:       model.human(model.bytes(t.node))
				text_style: gui.TextStyle{
					...gui.theme().n4
					color: gui.white
				}
			)
		}
		children << gui.column(
			x:       t.x + 7
			y:       t.y + 5
			width:   t.w - 12
			height:  t.h - 8
			sizing:  gui.fixed_fixed
			clip:    true
			padding: gui.padding_none
			spacing: 2
			content: label
		)
	}
	if app.hover >= 0 && app.hover < tiles.len {
		children << hover_card(app, tiles[app.hover].node, width, height)
	}
	return gui.canvas(
		id:            'space-map'
		id_focus:      7
		width:         width
		height:        height
		sizing:        gui.fixed_fixed
		padding:       gui.padding_none
		radius:        12
		clip:          true
		content:       children
		on_keydown:    fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			map_keydown(mut e, mut w)
		}
		on_any_click:  fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut state := w.state[App]()
			// Click events arrive in canvas coordinates; hover events do not.
			index := tile_at(state.tiles, e.mouse_x, e.mouse_y)
			if index < 0 {
				return
			}
			node := state.tiles[index].node
			if e.mouse_button == .right || (e.mouse_button == .left && e.modifiers == .ctrl) {
				show_file_menu(node.name, mut w)
			} else if e.mouse_button == .left {
				state.keyed = index
				open_node(node, mut w)
			}
			e.is_handled = true
		}
		on_mouse_move: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut state := w.state[App]()
			// Mouse callbacks receive coordinates relative to the canvas.
			x, y := e.mouse_x, e.mouse_y
			index := tile_at(state.tiles, x, y)
			moved := index != state.hover || abs_f32(x - state.hover_x) > 4
				|| abs_f32(y - state.hover_y) > 4
			state.hover = index
			state.hover_x = x
			state.hover_y = y
			e.is_handled = true
			if index >= 0 {
				w.set_mouse_cursor_pointing_hand()
				state.detail = '${os.file_name(state.tiles[index].node.name)} · ${model.human(model.bytes(state.tiles[index].node))}'
			}
			// The pointer card follows the mouse, so its move needs a frame.
			if moved {
				w.update_window()
			}
		}
	)
}

// hover_card follows the pointer, so the name stays beside the tile it names.
fn hover_card(app &App, node model.Node, width f32, height f32) gui.View {
	// A canvas child needs a fixed height: a fitted one collapses to nothing.
	card_width := f32_min(230, width - 16)
	card_height := f32(46)
	x := f32_min(f32_max(4, app.hover_x + 14), width - card_width - 4)
	y := f32_min(f32_max(4, app.hover_y + 18), height - card_height - 6)
	return gui.column(
		x:       x
		y:       y
		width:   card_width
		height:  card_height
		sizing:  gui.fixed_fixed
		padding: gui.padding(6, 9, 6, 9)
		spacing: 2
		radius:  6
		clip:    true
		color:   gui.Color{22, 27, 34, 232}
		content: [
			gui.text(
				text:       os.file_name(node.name)
				mode:       .single_line
				text_style: gui.TextStyle{
					...gui.theme().b4
					color: gui.white
				}
			),
			gui.text(
				text:       model.human(model.bytes(node))
				text_style: gui.TextStyle{
					...gui.theme().n4
					color: gui.Color{198, 210, 224, 255}
				}
			),
		]
	)
}

fn map_keydown(mut e gui.Event, mut w gui.Window) {
	mut app := w.state[App]()
	if app.tiles.len == 0 {
		return
	}
	match e.key_code {
		.enter, .space {
			if app.keyed >= 0 && app.keyed < app.tiles.len {
				open_node(app.tiles[app.keyed].node, mut w)
			}
		}
		.backspace {
			go_back(mut w)
		}
		.left, .right, .up, .down {
			dx := match e.key_code {
				.left { f32(-1) }
				.right { f32(1) }
				else { f32(0) }
			}

			dy := match e.key_code {
				.up { f32(-1) }
				.down { f32(1) }
				else { f32(0) }
			}

			app.keyed = step_tile(app.tiles, app.keyed, dx, dy)
			app.hover = -1
			if app.keyed >= 0 {
				app.detail = '${os.file_name(app.tiles[app.keyed].node.name)} · ${model.human(model.bytes(app.tiles[app.keyed].node))}'
			}
		}
		else {
			return
		}
	}

	e.is_handled = true
}

// step_tile picks the closest tile in the direction (dx, dy).
fn step_tile(tiles []model.Tile, from int, dx f32, dy f32) int {
	if from < 0 || from >= tiles.len {
		return 0
	}
	origin := tiles[from]
	ox, oy := origin.x + origin.w / 2, origin.y + origin.h / 2
	mut best := from
	mut best_cost := f32(0)
	for i, t in tiles {
		if i == from {
			continue
		}
		cx, cy := t.x + t.w / 2, t.y + t.h / 2
		along := (cx - ox) * dx + (cy - oy) * dy
		if along <= 0 {
			continue
		}
		across := abs_f32((cx - ox) * dy + (cy - oy) * dx)
		// Prefer near tiles, and punish drift away from the travel line.
		cost := along + across * 2
		if best == from || cost < best_cost {
			best = i
			best_cost = cost
		}
	}
	return best
}

fn abs_f32(v f32) f32 {
	return if v < 0 { -v } else { v }
}

// tile_at returns the index of the tile under the point, or -1.
fn tile_at(tiles []model.Tile, x f32, y f32) int {
	for i, t in tiles {
		if x >= t.x && x < t.x + t.w && y >= t.y && y < t.y + t.h {
			return i
		}
	}
	return -1
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
