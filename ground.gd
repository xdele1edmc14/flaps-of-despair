extends Area2D


signal hit

const LEVEL1_TEXTURE = preload("res://assets/ground.png")
const LEVEL2_TEXTURE = preload("res://assets/ground2.png")

const SURFACE_RATIO: = 0.8
const SCROLL_COVERAGE_MULTIPLIER: = 2.05

var level2_sprite: Sprite2D
var level1_region: Rect2
var level2_region: Rect2
var rendered_height: float = 0.0


func _ready() -> void :
	_ensure_sprites()


func configure_canvas(viewport_size: Vector2, surface_override: float = -1.0) -> void :
	_ensure_sprites()
	var surface_y: = viewport_size.y * SURFACE_RATIO if surface_override < 0.0 else surface_override
	position.y = surface_y

	var target_height: = viewport_size.y - surface_y
	var minimum_width: = viewport_size.x * SCROLL_COVERAGE_MULTIPLIER
	_configure_sprite($Sprite2D, level1_region, target_height, minimum_width)
	_configure_sprite(level2_sprite, level2_region, target_height, minimum_width)

	rendered_height = maxf(
		level1_region.size.y * $Sprite2D.scale.y,
		level2_region.size.y * level2_sprite.scale.y
	)
	_configure_collision(viewport_size, maxf(target_height, rendered_height))


func get_surface_y() -> float:
	return $Sprite2D.global_position.y


func get_rendered_height() -> float:
	return rendered_height


func set_level_mix(value: float, show_level1: bool = true) -> void :
	_ensure_sprites()
	var mix: = clampf(value, 0.0, 1.0)
	$Sprite2D.modulate.a = (1.0 - mix) if show_level1 else 0.0
	level2_sprite.modulate.a = mix


func _ensure_sprites() -> void :
	var original: Sprite2D = $Sprite2D
	if level1_region == Rect2():
		var level1_atlas: = _cropped_texture(LEVEL1_TEXTURE)
		original.texture = level1_atlas
		level1_region = level1_atlas.region
		original.centered = false
		original.offset = Vector2.ZERO
		original.position = Vector2.ZERO
		original.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if not is_instance_valid(level2_sprite):
		var level2_atlas: = _cropped_texture(LEVEL2_TEXTURE)
		level2_region = level2_atlas.region
		level2_sprite = Sprite2D.new()
		level2_sprite.name = "Level2Sprite"
		level2_sprite.texture = level2_atlas
		level2_sprite.centered = false
		level2_sprite.position = Vector2.ZERO
		level2_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(level2_sprite)


func _cropped_texture(source: Texture2D) -> AtlasTexture:
	var image: = source.get_image()
	var used: = image.get_used_rect() if image != null else Rect2i()
	if used.size == Vector2i.ZERO:
		used = Rect2i(Vector2i.ZERO, Vector2i(source.get_size()))
	var cropped: = AtlasTexture.new()
	cropped.atlas = source
	cropped.region = Rect2(Vector2(used.position), Vector2(used.size))
	return cropped


func _configure_sprite(sprite: Sprite2D, region: Rect2, target_height: float, minimum_width: float) -> void :
	var uniform_scale: = maxf(target_height / region.size.y, minimum_width / region.size.x)
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE * uniform_scale


func _configure_collision(viewport_size: Vector2, collision_height: float) -> void :
	var collision: CollisionShape2D = $CollisionShape2D
	var rectangle: = collision.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision.shape = rectangle
	rectangle.size = Vector2(viewport_size.x * 4.0, collision_height)
	collision.position = Vector2(viewport_size.x, collision_height * 0.5)

func _on_body_entered(body: Node2D) -> void :
	hit.emit()
