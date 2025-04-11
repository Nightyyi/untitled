package untitled

import "core:fmt"
import nl "libs/nlib"
import rl "vendor:raylib"

Game_Data :: struct {
	mouse:   nl.Mouse_Data,
	window:  nl.Window_Data,
	map_dat: Map_Data,
}


tile_type :: enum {
	grass,
	stone,
}

Map_Data :: struct {
	dimensions: [2]i32,
	tile_array: []tile_type,
}

map_init_blank :: proc(dimensions: [2]i32) -> Map_Data {
	area := dimensions.x * dimensions.y
	tile_array := make([]tile_type, area)
	for i in 0 ..< area {
		tile_array[i] = tile_type.grass
	}
	return Map_Data{dimensions, tile_array}
}

map_interate :: proc(
	map_data: Map_Data,
	game: Game_Data,
	input_proc: proc(pos: [2]i32, tile: tile_type, game: Game_Data),
) {
	dimensions := map_data.dimensions
	for y in 0 ..< dimensions.y {
		for x in 0 ..< dimensions.x {
			tile_at_pos := map_data.tile_array[x + y * dimensions.y]
			input_proc([2]i32{x, y}, tile_at_pos, game)
		}
	}
}


draw_tile :: proc(pos: [2]i32, tile: tile_type, game: Game_Data) {
	size := nl.Coord{16, 16}
	pos := pos * size
	if tile == tile_type.grass {
		rl.DrawRectangle(pos.x, pos.y, size.x, size.y, rl.Color{100, 188, 40, 255})
	}
	if tile == tile_type.stone {
		rl.DrawRectangle(pos.x, pos.y, size.x, size.y, rl.Color{100, 100, 100, 255})
	}
}

init_game_data :: proc() -> (game: Game_Data) {
	Screen_Width :: 400
	Screen_Height :: 240
	cache_map := make(map[string]rl.Texture)
	font := rl.LoadFont("assets\\BigBlueTerm437NerdFont-Regular.ttf")

	game = Game_Data {
		mouse = nl.Mouse_Data{},
		window = nl.Window_Data {
			original_size = nl.Coord{Screen_Width, Screen_Height},
			present_size = nl.Coord{Screen_Width, Screen_Height},
			image_cache_map = cache_map,
			font = font,
		},
		map_dat = map_init_blank([2]i32{10, 10}),
	}
	return
}


main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	game := init_game_data()
	rl.InitWindow(game.window.original_size.x, game.window.original_size.y, "ETERNALOID")
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)
	rl.SetTraceLogLevel(rl.TraceLogLevel.FATAL)
	rl.SetWindowState(rl.ConfigFlags{.WINDOW_RESIZABLE})

	render_texture := rl.LoadRenderTexture(400, 240)
	run := true
	for run {
		if rl.IsWindowResized() {
			game.window.present_size = nl.Coord{rl.GetScreenWidth(), rl.GetScreenHeight()}
		}

		if rl.IsKeyDown(rl.KeyboardKey.ESCAPE) {run = false}
		rl.BeginTextureMode(render_texture)
		rl.ClearBackground(rl.Color{255, 255, 105, 255})
		map_interate(game.map_dat, game, draw_tile)
		rl.EndTextureMode()

		dest := rl.Rectangle {
			0,
			0,
			f32(game.window.present_size.x),
			f32(game.window.present_size.y),
		}
    source := rl.Rectangle{
      0,
      0,
      400,
      240,
    }
    origin := [2]f32{
			f32(game.window.present_size.y)/2,
			f32(game.window.present_size.x)/2,
    }

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{0, 0, 0, 255})
		rl.DrawTextureNPatch(
			texture = render_texture.texture,
			nPatchInfo = rl.NPatchInfo{source, 0, 0, 0, 0, rl.NPatchLayout.NINE_PATCH},
			rotation = 0,
			dest = dest,
			origin = [2]f32{0,0},
			tint = rl.Color{255, 255, 255, 255},
		)
		rl.EndDrawing()
	}
}
