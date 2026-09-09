module atlas

import model

fn fixture_tiles() []model.Tile {
	// Four equal tiles in a two by two grid.
	return [
		model.Tile{
			node: model.Node{
				name: '/a'
				size: '4B'
			}
			x:    0
			y:    0
			w:    100
			h:    100
		},
		model.Tile{
			node: model.Node{
				name: '/b'
				size: '3B'
			}
			x:    100
			y:    0
			w:    100
			h:    100
		},
		model.Tile{
			node: model.Node{
				name: '/c'
				size: '2B'
			}
			x:    0
			y:    100
			w:    100
			h:    100
		},
		model.Tile{
			node: model.Node{
				name: '/d'
				size: '1B'
			}
			x:    100
			y:    100
			w:    100
			h:    100
		},
	]
}

fn test_tile_at_reports_the_index_under_the_point() {
	tiles := fixture_tiles()
	assert tile_at(tiles, 50, 50) == 0
	assert tile_at(tiles, 150, 50) == 1
	assert tile_at(tiles, 50, 150) == 2
	assert tile_at(tiles, 199.5, 199.5) == 3
	assert tile_at(tiles, 200, 200) == -1
	assert tile_at(tiles, -1, 50) == -1
	assert tile_at([]model.Tile{}, 0, 0) == -1
}

fn test_step_tile_moves_to_the_neighbour_in_that_direction() {
	tiles := fixture_tiles()
	assert step_tile(tiles, 0, 1, 0) == 1
	assert step_tile(tiles, 0, 0, 1) == 2
	assert step_tile(tiles, 3, -1, 0) == 2
	assert step_tile(tiles, 3, 0, -1) == 1
	// No tile lies that way, so the cursor holds its place.
	assert step_tile(tiles, 0, -1, 0) == 0
	// An unset cursor starts at the largest tile.
	assert step_tile(tiles, -1, 1, 0) == 0
}

fn test_tile_color_ramps_from_warm_to_cool() {
	count := 8
	first := tile_color(0, count)
	last := tile_color(count - 1, count)
	assert first == atlas_ramp[0]
	assert last == atlas_ramp[atlas_ramp.len - 1]
	// Red falls and blue rises as the entries get smaller.
	assert tile_color(2, count).r < first.r
	assert tile_color(2, count).b > first.b
	assert tile_color(0, 1) == atlas_ramp[0]
}

fn test_ancestors_list_the_open_path() {
	mut app := App{}
	assert app.ancestors().len == 0
	app.history = [
		FolderView{
			node: model.Node{
				name: '/root'
			}
		},
		FolderView{
			node: model.Node{
				name: '/root/a'
			}
		},
	]
	app.current = FolderView{
		node: model.Node{
			name: '/root/a/b'
		}
	}
	assert app.ancestors() == ['/root', '/root/a', '/root/a/b']
}

fn test_retile_rebuilds_only_when_the_map_size_changes() {
	mut app := App{}
	app.current = FolderView{
		node:    model.Node{
			name: '/root'
			size: '100B'
		}
		entries: model.entries(model.Node{
			name:     '/root'
			size:     '100B'
			children: [model.Node{
				name: '/root/a'
				size: '100B'
			}]
		})
	}
	app.retile(400, 200)
	assert app.tiles.len == 1
	assert app.tiles[0].w == 400
	app.keyed = 0
	app.retile(400, 200)
	// An unchanged size keeps the keyboard cursor.
	assert app.keyed == 0
	app.retile(200, 400)
	assert app.tiles[0].h == 400
}
