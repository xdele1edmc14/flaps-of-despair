extends Node2D

const LEAF_COUNT: = 22
const COLORS: = [Color("e3a13b"), Color("c46b25"), Color("b34b23"), Color("e5b653")]
var field_size: = Vector2(540, 800)
var rng: = RandomNumberGenerator.new()
var leaves: Array[Dictionary] = []
var intensity: = 0.0


func _ready() -> void :
	rng.randomize()
	for i in LEAF_COUNT:
		var leaf: = Polygon2D.new()
		leaf.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -2), Vector2(5, 0), Vector2(1, 3), Vector2(-2, 2)])
		leaf.color = COLORS[i % COLORS.size()]
		leaf.scale = Vector2.ONE * rng.randf_range(0.65, 1.1)
		add_child(leaf)
		var data: = {"node": leaf, "speed": rng.randf_range(28, 58), "drift": rng.randf_range(-24, -9), "phase": rng.randf_range(0, TAU), "spin": rng.randf_range(-1.2, 1.2)}
		leaves.append(data)
		_reset_leaf(data, true)
	set_intensity(0.0)


func configure_canvas(size: Vector2) -> void :
	field_size = size


func set_intensity(value: float) -> void :
	intensity = clampf(value, 0.0, 1.0)
	modulate.a = intensity * 0.75
	visible = intensity > 0.0


func _process(delta: float) -> void :
	if intensity <= 0.0:
		return
	for data in leaves:
		var leaf: Polygon2D = data.node
		data.phase += delta * 1.8
		leaf.position += Vector2(data.drift + sin(data.phase) * 16.0, data.speed) * delta
		leaf.rotation += data.spin * delta
		leaf.scale.y = 0.55 + absf(cos(data.phase)) * 0.45
		if leaf.position.y > field_size.y + 12 or leaf.position.x < -24:
			_reset_leaf(data, false)


func _reset_leaf(data: Dictionary, scatter: bool) -> void :
	var leaf: Polygon2D = data.node
	leaf.position = Vector2(rng.randf_range(0, field_size.x + 40), rng.randf_range(0, field_size.y) if scatter else -12.0)
	leaf.rotation = rng.randf_range(0, TAU)
