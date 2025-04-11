package nlib

import "core:fmt"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

Coord :: [2]i32

Mouse_Data :: struct {
	pos:         Coord,
	virtual_pos: Coord,
	clicking:    bool,
	hold:        bool,
}

Window_Data :: struct {
	original_size:   Coord,
	present_size:    Coord,
	image_cache_map: map[string]rl.Texture,
	font:            rl.Font,
}

Image_Key :: struct {
	string_key: string,
	size_key:   f32,
}

Texture_Cache :: struct {
	cached_texture: rl.Texture,
	size:           f32,
}

clamp_Coord :: proc(val: ^Coord, min: Coord, max: Coord) {
	if val^.x < min.x {val^.x = min.x}
	if val^.y < min.y {val^.y = min.y}
	if val^.x > max.x {val^.x = max.x}
	if val^.y > max.y {val^.x = max.y}
}

get_virtual_window :: proc(window: Window_Data) -> (Coord, f64) {
	width_ratio := f64(window.present_size.x) / f64(window.original_size.x)
	height_ratio := f64(window.present_size.y) / f64(window.original_size.y)

	ratio: f64 = min(height_ratio, width_ratio)

	v_width := i32(f64(window.original_size.x) * ratio)
	v_height := i32(f64(window.original_size.y) * ratio)

	return Coord{v_width, v_height}, ratio
}

get_virtual_x_y_ratio :: proc(pos: Coord, window: Window_Data) -> (Coord, f64) {
	virtual_size, virtual_ratio := get_virtual_window(window)
	padding := get_padding(window, virtual_size)
	return Coord {
			i32(f64(pos.x) * virtual_ratio) + padding.x,
			i32(f64(pos.y) * virtual_ratio) + padding.y,
		},
		virtual_ratio


}

get_padding :: proc(window: Window_Data, virtual_size: Coord) -> Coord {
	return Coord {
		(window.present_size.x - virtual_size.x) / 2,
		(window.present_size.y - virtual_size.y) / 2,
	}
}

update_mouse :: proc(mouse: ^Mouse_Data, window: Window_Data) {
	virtual_size, virtual_ratio := get_virtual_window(window)
	padding := get_padding(window, virtual_size)
	pos := rl.GetMousePosition()
	mouse.pos = Coord {
		i32(f64(i32(pos.x) - padding.x) / virtual_ratio),
		i32(f64(i32(pos.y) - padding.y) / virtual_ratio),
	}
	mouse.virtual_pos = Coord{i32(pos.x), i32(pos.y)}
	mouse.clicking = rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
	mouse.hold = rl.IsMouseButtonDown(rl.MouseButton.LEFT)
}

acquire_texture :: proc(image_name: string) -> rl.Texture {
	new_image_name := filepath.join([]string{"assets", image_name})
	image_name_C: cstring = strings.clone_to_cstring(new_image_name)
	texture: rl.Texture = rl.LoadTexture(image_name_C)
	delete(image_name_C)
	delete(new_image_name)
	return texture
}

switch_texture :: proc(
	original_image_name: string,
	new_image_name: string,
	image_cache_map: ^map[string]rl.Texture,
) {
	cached_texture, ok := image_cache_map[new_image_name]
	if ok {
		image_cache_map[original_image_name] = cached_texture
	} else {
		texture := acquire_texture(new_image_name)
		image_cache_map[new_image_name] = texture
		image_cache_map[original_image_name] = texture
	}
}

pull_texture :: proc(
	image_name: string,
	image_cache_map: ^map[string]rl.Texture,
	size: f32,
) -> rl.Texture {
	cached_texture, ok := image_cache_map[image_name]
	if ok {
		return cached_texture
	} else {
		texture := acquire_texture(image_name)
		image_cache_map[image_name] = texture
		return texture
	}
}

in_hitbox :: proc(pos: Coord, size: Coord, mouse: Mouse_Data) -> bool {
	delta := mouse.pos - pos
	return (0 < delta.x && delta.x < size.x) && (0 < delta.y && delta.y < size.y)


}

in_hitbox_v :: proc(x: i32, y: i32, width: i32, height: i32, mouse: Mouse_Data) -> bool {
	return(
		(0 < (mouse.virtual_pos.x - x) && (mouse.virtual_pos.x - x) < width) &&
		(0 < (mouse.virtual_pos.y - y) && (mouse.virtual_pos.y - y) < height) \
	)
}

draw_text :: proc(
	text: string,
	position: Coord,
	spacing: f32,
	color: rl.Color,
	fontSize: f32,
	window: Window_Data,
) {
	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window)
	text_c: cstring = strings.clone_to_cstring(text)
	rl.DrawTextEx(
		font = window.font,
		text = text_c,
		position = rl.Vector2{f32(virtual_pos.x), f32(virtual_pos.y)},
		fontSize = fontSize * f32(virtual_ratio),
		spacing = spacing * f32(virtual_ratio),
		tint = color,
	)
	delete(text_c)
}


draw_text_centered :: proc(
	text: string,
	position: Coord,
	spacing: f32,
	color: rl.Color,
	fontSize: f32,
	window: Window_Data,
) {
	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window)
	text_c: cstring = strings.clone_to_cstring(text)
  text_size := rl.MeasureTextEx(
		font = window.font,
		text = text_c,
		fontSize = fontSize * f32(virtual_ratio),
		spacing = spacing * f32(virtual_ratio),
  )
	rl.DrawTextEx(
		font = window.font,
		text = text_c,
		position = rl.Vector2{f32(virtual_pos.x)-text_size.x/4, f32(virtual_pos.y)},
		fontSize = fontSize * f32(virtual_ratio),
		spacing = spacing * f32(virtual_ratio),
		tint = color,
	)
	delete(text_c)
}


draw_rectangle :: proc(position: Coord, size: Coord, window: Window_Data, color: rl.Color) {
	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window)
	rl.DrawRectangle(
		i32(virtual_pos.x),
		i32(virtual_pos.y),
		i32(f64(size.x) * virtual_ratio),
		i32(f64(size.y) * virtual_ratio),
		color,
	)
}

draw_borders :: proc(window: Window_Data) {
	virtual_size, virtual_ratio := get_virtual_window(window)
	padding := get_padding(window = window, virtual_size = virtual_size)
	rl.DrawRectangle(0, 0, padding.x, window.present_size.y, rl.Color{0, 0, 0, 255})
	rl.DrawRectangle(
		window.present_size.x - padding.x,
		0,
		padding.x,
		window.present_size.y,
		rl.Color{0, 0, 0, 255},
	)
	rl.DrawRectangle(0, 0, window.present_size.x, padding.y, rl.Color{0, 0, 0, 255})
	rl.DrawRectangle(
		0,
		window.present_size.y - padding.y,
		window.present_size.x,
		padding.y,
		rl.Color{0, 0, 0, 255},
	)
}


draw_slider :: proc(
	position: Coord,
	size: Coord,
	window: Window_Data,
	mouse: Mouse_Data,
	slider_percentage: ^f64,
	color: rl.Color,
) {
	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window)

	if in_hitbox(position, size, mouse) && mouse.clicking {
		slider_percentage^ = f64(mouse.pos.x - position.x) / f64(size.x)
	}
	rl.DrawRectangle(
		i32(virtual_pos.x),
		i32(virtual_pos.y),
		i32(f64(size.x) * virtual_ratio),
		i32(f64(size.y) * virtual_ratio),
		rl.Color{50, 50, 50, 105},
	)
	rl.DrawRectangle(
		i32(virtual_pos.x),
		i32(virtual_pos.y),
		i32(f64(size.x) * virtual_ratio * slider_percentage^),
		i32(f64(size.y) * virtual_ratio),
		color,
	)
	rl.DrawRectangleLinesEx(
		rl.Rectangle {
			f32(virtual_pos.x),
			f32(virtual_pos.y),
			f32(f64(size.x) * virtual_ratio),
			f32(f64(size.y) * virtual_ratio),
		},
		2,
		rl.Color{255, 255, 255, 105},
	)
}

draw_png :: proc(
	position: Coord,
	png_name: string,
	window: ^Window_Data,
	size: f32 = 1,
	rotation: f32 = 0,
	color: rl.Color = rl.Color{255, 255, 255, 255},
) {
	draw := true
	if (position.x > window.original_size.x) {draw = false}
	if (position.y > window.original_size.y) {draw = false}
	if (png_name != "") {
		texture: rl.Texture = pull_texture(png_name, &window.image_cache_map, size)
		virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window^)
		rl.DrawTextureEx(
			texture,
			rl.Vector2{f32(virtual_pos.x), f32(virtual_pos.y)},
			rotation,
			size * f32(virtual_ratio),
			color,
		)
	}
}

draw_png_centered :: proc(
	position: Coord,
	png_name: string,
	window: ^Window_Data,
	size: f32 = 1,
	rotation: f32 = 0,
	color: rl.Color = rl.Color{255, 255, 255, 255},
) {
	draw := true
	if (position.x > window.original_size.x) {draw = false}
	if (position.y > window.original_size.y) {draw = false}
	if (png_name != "") {
		texture: rl.Texture = pull_texture(png_name, &window.image_cache_map, size)
		virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window^)
		rl.DrawTextureEx(
			texture,
			rl.Vector2 {
				f32(virtual_pos.x) - f32(texture.width) / 2 * f32(virtual_ratio),
				f32(virtual_pos.y) - f32(texture.height) / 2 * f32(virtual_ratio),
			},
			rotation,
			size * f32(virtual_ratio),
			color,
		)
	}
}

spline_2p :: proc(p1, p2: Coord, n: f64) -> Coord {
	x := f64(p1.x) * (n - 1) + f64(p2.x) * n
	y := f64(p1.y) * (n - 1) + f64(p2.y) * n
	return Coord{i32(x), i32(y)}
}

spline_3p :: proc(p1, p2, p3: Coord, n: f64) -> Coord {
	x :=
		(f64(p1.x) * (1 - n) + f64(p2.x) * n) * (1 - n) + (f64(p2.x) * (1 - n) + f64(p3.x) * n) * n
	y :=                                                                   
		(f64(p1.y) * (1 - n) + f64(p2.y) * n) * (1 - n) + (f64(p2.y) * (1 - n) + f64(p3.y) * n) * n
  return Coord{i32(x), i32(y)}
}

button_png :: proc(
	position: Coord,
	hitbox: Coord,
	png_name: string,
	window: ^Window_Data,
	mouse: Mouse_Data,
	rotation: f32 = 0,
	size: f32 = 1,
) -> (
	bool,
	bool,
) {

	on_button := in_hitbox(position, hitbox, mouse)
	button_clicked := on_button && mouse.clicking
	which_texture: int = 0

	if on_button {which_texture = 1}
	if button_clicked {which_texture = 2}

	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window^)
	texture: rl.Texture = pull_texture(png_name, &window.image_cache_map, size)

	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(virtual_pos.x), f32(virtual_pos.y)},
		rotation,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)

	return button_clicked, on_button
}

button_png_d_shake :: proc(
	position: Coord,
	hitbox: Coord,
	png_name: [2]string,
	window: ^Window_Data,
	mouse: Mouse_Data,
	shake: i32 = 2,
	seed: ^i32,
	rotation: f32 = 0,
	size: f32 = 1,
) -> (
	bool,
	bool,
) {
	t_pos: Coord = position
	on_button := in_hitbox(position, hitbox, mouse)
	button_clicked := on_button && mouse.clicking
	which_texture: int = 0
	if on_button {
		shake_pos := position
		seed^ = i32(((int(seed^) << 10 ~ 2151254221) >> 3) % 1241425)
		t_pos.x += ((seed^) % (shake * 2) - shake) * (1 + i32(button_clicked) * 5)
		seed^ = i32(((int(seed^) << 10 ~ 2151254221) >> 3) % 1241425)
		t_pos.y += ((seed^) % (shake * 2) - shake) * (1 + i32(button_clicked) * 5)
	}
	if button_clicked {which_texture = 1}
	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(t_pos, window^)
	texture: rl.Texture = pull_texture(png_name[which_texture], &window.image_cache_map, size)

	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(virtual_pos.x), f32(virtual_pos.y)},
		rotation,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)

	return button_clicked, on_button
}

button_png_t :: proc(
	position: Coord,
	hitbox: Coord,
	png_name: [3]string,
	window: ^Window_Data,
	mouse: Mouse_Data,
	rotation: f32 = 0,
	size: f32 = 1,
) -> bool {

	on_button := in_hitbox(position, hitbox, mouse)
	button_clicked := on_button && mouse.clicking
	which_texture: int = 0

	if on_button {which_texture = 1}
	if button_clicked {which_texture = 2}

	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window^)
	texture: rl.Texture = pull_texture(png_name[which_texture], &window.image_cache_map, size)

	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(virtual_pos.x), f32(virtual_pos.y)},
		rotation,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)

	return button_clicked
}

button_png_auto_shake :: proc(
	position: Coord,
	hitbox: Coord,
	png_name: string,
	window: ^Window_Data,
	mouse: Mouse_Data,
	rotation: f32 = 0,
	shake: i32 = 2,
	seed: ^i32,
	size: f32 = 1,
) -> (
	bool,
	bool,
) {
	t_pos: Coord = position
	on_button := in_hitbox(position, hitbox, mouse)
	button_clicked := on_button && mouse.clicking
	which_texture: int = 0

	if on_button {which_texture = 1}
	if button_clicked {which_texture = 2}
	if on_button {
		shake_pos := position
		seed^ = i32(((int(seed^) << 10 ~ 2151254221) >> 3) % 1241425)
		t_pos.x += ((seed^) % (shake * 2) - shake) * (1 + i32(button_clicked) * 5)
		seed^ = i32(((int(seed^) << 10 ~ 2151254221) >> 3) % 1241425)
		t_pos.y += ((seed^) % (shake * 2) - shake) * (1 + i32(button_clicked) * 5)
	}
	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(t_pos, window^)
	buf: [32]u8
	new_string := fmt.bprintf(buf[:], "%s%d.png", png_name, which_texture + 1)
	texture: rl.Texture = pull_texture(new_string, &window.image_cache_map, size)

	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(virtual_pos.x), f32(virtual_pos.y)},
		rotation,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)

	return button_clicked, on_button
}

button_png_auto :: proc(
	position: Coord,
	hitbox: Coord,
	png_name: string,
	window: ^Window_Data,
	mouse: Mouse_Data,
	rotation: f32 = 0,
	size: f32 = 1,
) -> (
	bool,
	bool,
) {

	on_button := in_hitbox(position, hitbox, mouse)
	button_clicked := on_button && mouse.clicking
	which_texture: int = 0

	if on_button {which_texture = 1}
	if button_clicked {which_texture = 2}

	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(position, window^)
	buf: [32]u8
	new_string := fmt.bprintf(buf[:], "%s%d.png", png_name, which_texture + 1)
	texture: rl.Texture = pull_texture(new_string, &window.image_cache_map, size)

	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(virtual_pos.x), f32(virtual_pos.y)},
		rotation,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)

	return button_clicked, on_button
}

begin_draw_area :: proc(pos: Coord, size: Coord, window: Window_Data) {
	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(pos, window)
	rl.BeginScissorMode(
		virtual_pos.x,
		virtual_pos.y,
		i32(f64(size.x) * virtual_ratio),
		i32(f64(size.y) * virtual_ratio),
	)
}

mouse_cursor :: proc(window: ^Window_Data, mouse: Mouse_Data, rotation: f32 = 0, size: f32 = 1) {

	virtual_pos, virtual_ratio := get_virtual_x_y_ratio(mouse.pos, window^)
	texture: rl.Texture
	buf: [32]u8
	if !mouse.hold && mouse.clicking {
		texture = pull_texture("mouse\\click.png", &window.image_cache_map, size)
	} else if mouse.hold {
		texture = pull_texture("mouse\\hold.png", &window.image_cache_map, size)
	} else {
		texture = pull_texture("mouse\\idle.png", &window.image_cache_map, size)
	}

	rl.DrawTextureEx(
		texture,
		rl.Vector2{f32(mouse.virtual_pos.x), f32(mouse.virtual_pos.y)},
		rotation,
		size * f32(virtual_ratio),
		rl.Color{255, 255, 255, 255},
	)
}
