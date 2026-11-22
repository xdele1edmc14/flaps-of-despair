@tool
extends Node2D

const PARALLAX_TEXTURES: = [
	preload("res://assets/level_1/Hills Layer 01.png"),
	preload("res://assets/level_1/Hills Layer 02.png"),
	preload("res://assets/level_1/Hills Layer 03.png"),
	preload("res://assets/level_1/Hills Layer 04.png"),
	preload("res://assets/level_1/Hills Layer 05.png"),
	preload("res://assets/level_1/Hills Layer 06.png"),
]
const PARALLAX_SPEED_FACTORS: = [0.02, 0.06, 0.12, 0.24, 1.0, 1.28]
const PARALLAX_GROUND_LAYER: = 4
const PARALLAX_GROUND_FALLBACK_ROW: = 236.0
const SOLID_GROUND_COVERAGE: = 0.95

var field_size: = Vector2(588, 826)
var world_speed: = 240.0
var mode: StringName = &"story"
var parallax_root: Node2D
var parallax_pairs: Array = []
var parallax_offsets: Array[float] = []
var parallax_widths: Array[float] = []
var parallax_ground_source_y: = PARALLAX_GROUND_FALLBACK_ROW


func _ready() -> void :
	_ensure_layers()


func configure_canvas(size: Vector2, speed: float = 240.0, _interval: float = 1.5) -> void :
	field_size = size
	world_speed = maxf(speed, 1.0)
	_ensure_layers()
	_layout_parallax()


func set_mode(value: StringName) -> void :
	mode = value


func set_score(_score: int, _immediate: bool = false) -> void :

	return


func advance(delta: float) -> void :
	_advance_parallax(maxf(delta, 0.0))


func get_parallax_layer_count() -> int:
	return parallax_pairs.size()


func get_parallax_copy_count(layer_index: int) -> int:
	if layer_index < 0 or layer_index >= parallax_pairs.size():
		return 0
	return parallax_pairs[layer_index].size()


func get_parallax_offset(layer_index: int) -> float:
	if layer_index < 0 or layer_index >= parallax_offsets.size():
		return 0.0
	return parallax_offsets[layer_index]


func is_parallax_pair_seamless(layer_index: int) -> bool:
	if get_parallax_copy_count(layer_index) != 2:
		return false
	var copies: Array = parallax_pairs[layer_index]
	return is_equal_approx(copies[1].position.x - copies[0].position.x, parallax_widths[layer_index])


func get_level1_ground_y() -> float:
	if get_parallax_copy_count(PARALLAX_GROUND_LAYER) == 0:
		return global_position.y + field_size.y * 0.92
	var ground_sprite: Sprite2D = parallax_pairs[PARALLAX_GROUND_LAYER][0]
	return ground_sprite.to_global(Vector2(0.0, parallax_ground_source_y)).y


func _ensure_layers() -> void :
	if is_instance_valid(parallax_root):
		return
	parallax_root = Node2D.new()
	parallax_root.name = "Level1Parallax"
	add_child(parallax_root)
	for layer_index in PARALLAX_TEXTURES.size():
		var pair: = Node2D.new()
		pair.name = "Layer%02d" % (layer_index + 1)
		if layer_index >= 4:
			pair.z_index = 2
		parallax_root.add_child(pair)
		var copies: Array[Sprite2D] = []
		for copy_index in 2:
			var sprite: = Sprite2D.new()
			sprite.name = "Copy%d" % (copy_index + 1)
			sprite.texture = PARALLAX_TEXTURES[layer_index]
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pair.add_child(sprite)
			copies.append(sprite)
		parallax_pairs.append(copies)
		parallax_offsets.append(0.0)
		parallax_widths.append(1.0)
	var ground_image: = PARALLAX_TEXTURES[PARALLAX_GROUND_LAYER].get_image()
	if ground_image != null:
		parallax_ground_source_y = _find_solid_ground_row(ground_image)
	_layout_parallax()


func _find_solid_ground_row(image: Image) -> float:
	var required_pixels: = ceili(image.get_width() * SOLID_GROUND_COVERAGE)
	for y in range(image.get_height()):
		var opaque_pixels: = 0
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.08:
				opaque_pixels += 1
		if opaque_pixels >= required_pixels:
			return float(y)
	var used: = image.get_used_rect()
	return float(used.position.y) if used.size != Vector2i.ZERO else PARALLAX_GROUND_FALLBACK_ROW


func _layout_parallax() -> void :
	if not is_instance_valid(parallax_root):
		return
	for layer_index in parallax_pairs.size():
		var texture: Texture2D = PARALLAX_TEXTURES[layer_index]
		var cover_scale: = maxf(field_size.x / texture.get_width(), field_size.y / texture.get_height())
		var tile_size: = texture.get_size() * cover_scale
		parallax_widths[layer_index] = tile_size.x
		parallax_offsets[layer_index] = fmod(parallax_offsets[layer_index], tile_size.x)
		var top: = (field_size.y - tile_size.y) * 0.5
		_position_parallax_pair(layer_index, top)


func _advance_parallax(delta: float) -> void :
	if not is_instance_valid(parallax_root):
		return
	for layer_index in parallax_pairs.size():
		var width: float = parallax_widths[layer_index]
		parallax_offsets[layer_index] = fmod(
			parallax_offsets[layer_index] + world_speed * PARALLAX_SPEED_FACTORS[layer_index] * delta,
			width
		)
		var copies: Array = parallax_pairs[layer_index]
		_position_parallax_pair(layer_index, copies[0].position.y)


func _position_parallax_pair(layer_index: int, top: float) -> void :
	var copies: Array = parallax_pairs[layer_index]
	var width: float = parallax_widths[layer_index]
	var offset: float = parallax_offsets[layer_index]
	for copy_index in copies.size():
		var sprite: Sprite2D = copies[copy_index]
		var texture: Texture2D = PARALLAX_TEXTURES[layer_index]
		var uniform_scale: = width / texture.get_width()
		sprite.scale = Vector2.ONE * uniform_scale
		sprite.position = Vector2(copy_index * width - offset, top)
