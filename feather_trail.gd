extends Node2D

const EMIT_INTERVAL: = 0.09
const ACCELERATION: = 180.0
const LIFETIME: = 1.0
const PIPE_FEATHER_COUNT: = 8
const PIPE_ACCELERATION: = 420.0
const PIPE_LIFETIME: = 0.7
const COLORS: = [Color("b07549"), Color("e8c89b"), Color("8b4d2d")]
var source: CharacterBody2D
var pipe_impact: = false
var feathers: Array[Dictionary] = []
var emit_clock: = 0.0
var rng: = RandomNumberGenerator.new()


func _ready() -> void :
	z_index = 9
	rng.randomize()
	if pipe_impact:
		for i in PIPE_FEATHER_COUNT:
			_emit_feather()


func _emit_feather() -> void :
	var feather: = Node2D.new()
	feather.position = to_local(source.global_position) + Vector2(rng.randf_range(-14, 14), rng.randf_range(-12, 4))
	feather.rotation = rng.randf_range(0, TAU)
	feather.scale = Vector2.ONE * rng.randf_range(0.7, 1.1)
	var body: = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(-4, -3), Vector2(3, -2), Vector2(8, 0), Vector2(1, 3), Vector2(-4, 2)])
	body.color = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	feather.add_child(body)
	var spine: = Line2D.new()
	spine.points = PackedVector2Array([Vector2(-9, 0), Vector2(6, 0)])
	spine.width = 1.0
	spine.default_color = Color("f4ddbb")
	feather.add_child(spine)
	add_child(feather)
	var launch_velocity: = Vector2(rng.randf_range(-190, -65), rng.randf_range(-170, 40)) if pipe_impact else Vector2(rng.randf_range(-60, 60), minf(source.velocity.y * 0.15, 80.0))
	feathers.append({"node": feather, "age": 0.0, "velocity": launch_velocity, "spin": rng.randf_range(-4, 4), "phase": rng.randf_range(0, TAU)})


func _process(delta: float) -> void :
	var active: bool = not pipe_impact and is_instance_valid(source) and bool(source.get("boundary_falling"))
	var acceleration: float = PIPE_ACCELERATION if pipe_impact else ACCELERATION
	var lifetime: float = PIPE_LIFETIME if pipe_impact else LIFETIME
	var emitting: bool = active and source.velocity.y > 0.0 and source.global_position.y >= 0.0
	if emitting:
		emit_clock = minf(emit_clock + delta, EMIT_INTERVAL * 3.0)
		while emit_clock >= EMIT_INTERVAL:
			emit_clock -= EMIT_INTERVAL
			_emit_feather()
	else:
		emit_clock = 0.0
	for i in range(feathers.size() - 1, -1, -1):
		var data: Dictionary = feathers[i]
		var feather: Node2D = data.node
		data.age += delta
		var velocity: Vector2 = data.velocity
		velocity.y += acceleration * delta
		data.velocity = velocity
		feather.position += (velocity + Vector2(sin(data.age * 8.0 + data.phase) * 24.0, 0)) * delta
		feather.rotation += data.spin * delta
		feather.modulate.a = 1.0 - smoothstep(lifetime * 0.6, lifetime, data.age)
		if data.age >= lifetime:
			feather.queue_free()
			feathers.remove_at(i)
	if not active and feathers.is_empty():
		queue_free()
