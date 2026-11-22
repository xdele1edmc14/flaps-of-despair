extends Node2D

const LEAF_COLORS: = [Color("6daf3c"), Color("8ac94c"), Color("d5bf45"), Color("4b8c35")]
const LEAF_COUNT: = 14
const POLLEN_COUNT: = 16
var rng: = RandomNumberGenerator.new()
var motes: Array[Dictionary] = []


func _ready() -> void :
	rng.seed = 7331
	for i in LEAF_COUNT:
		var leaf: = Polygon2D.new()
		leaf.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -2.5), Vector2(5, 0), Vector2(0, 2.5)])
		leaf.color = LEAF_COLORS[i % LEAF_COLORS.size()]
		leaf.modulate.a = rng.randf_range(0.35, 0.72)
		leaf.scale = Vector2.ONE * rng.randf_range(0.55, 1.15)
		add_child(leaf)
		motes.append(_seed_mote(leaf, true))
	for i in POLLEN_COUNT:
		var pollen: = Polygon2D.new()
		pollen.polygon = PackedVector2Array([Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
		pollen.color = Color("fff1a8")
		pollen.modulate.a = rng.randf_range(0.28, 0.68)
		add_child(pollen)
		motes.append(_seed_mote(pollen, false))


func _seed_mote(node: Node2D, leaf: bool) -> Dictionary:
	var size: = get_viewport_rect().size
	node.position = Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
	return {
		"node": node,
		"leaf": leaf,
		"speed": rng.randf_range(16.0, 36.0) if leaf else rng.randf_range(5.0, 13.0),
		"sway": rng.randf_range(10.0, 28.0),
		"phase": rng.randf_range(0, TAU),
		"spin": rng.randf_range(-1.6, 1.6)
	}


func _process(delta: float) -> void :
	var size: = get_viewport_rect().size
	var now: = Time.get_ticks_msec() * 0.001
	for data in motes:
		var node: Node2D = data.node
		node.position += Vector2(sin(now * 1.2 + data.phase) * data.sway * delta, data.speed * delta)
		node.rotation += data.spin * delta
		if node.position.y > size.y + 16.0:
			node.position = Vector2(rng.randf_range(0, size.x), -16.0)
