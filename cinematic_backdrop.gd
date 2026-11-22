extends Control

const PARALLAX_BACKGROUND: = preload("res://panorama_background.gd")
const MENU_SCROLL_SPEED: = 105.0

var panorama


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panorama = PARALLAX_BACKGROUND.new()
	panorama.name = "MenuParallax"
	panorama.position = Vector2(-24, -24)
	add_child(panorama)
	resized.connect(_layout_panorama)
	_layout_panorama()


func _process(delta: float) -> void :
	if is_instance_valid(panorama):
		panorama.advance(delta)


func get_scroll_offset() -> float:
	if not is_instance_valid(panorama):
		return 0.0
	return panorama.get_parallax_offset(4)


func _layout_panorama() -> void :
	if is_instance_valid(panorama):
		panorama.configure_canvas(size + Vector2(48, 48), MENU_SCROLL_SPEED)
