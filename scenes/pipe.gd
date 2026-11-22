extends Area2D

signal hit
signal scored

const EDGE_OVERDRAW: = 32.0
const LEVEL2_TEXTURE = preload("res://assets/pipe2.png")
var level2_layers: Array[Sprite2D] = []


func set_level_mix(value: float) -> void :
	if level2_layers.is_empty():
		for node_name in ["LowerBody", "LowerCap", "UpperBody", "UpperCap"]:
			var original: Sprite2D = get_node(node_name)
			var overlay: = Sprite2D.new()
			var atlas: = AtlasTexture.new()
			atlas.atlas = LEVEL2_TEXTURE
			atlas.region = original.texture.region
			overlay.texture = atlas
			overlay.name = node_name + "Level2"
			overlay.transform = original.transform
			overlay.flip_v = original.flip_v
			add_child(overlay)
			level2_layers.append(overlay)
	for overlay in level2_layers:
		overlay.modulate.a = clampf(value, 0.0, 1.0)


func fit_to_playfield(top_y: float, bottom_y: float) -> void :
	var local_top: = top_y - global_position.y - EDGE_OVERDRAW
	var local_bottom: = bottom_y - global_position.y + EDGE_OVERDRAW
	var lower_cap: CollisionShape2D = $CollisionShape2D
	var upper_cap: CollisionShape2D = $CollisionShape2D3
	var lower_body_collision: CollisionShape2D = $CollisionShape2D2
	var upper_body_collision: CollisionShape2D = $CollisionShape2D4
	var lower_body_top: = lower_cap.position.y + lower_cap.shape.get_rect().size.y / 2.0 - 1.0
	var upper_body_bottom: = upper_cap.position.y - upper_cap.shape.get_rect().size.y / 2.0 + 1.0
	var lower_height: = maxf(1.0, local_bottom - lower_body_top)
	var upper_height: = maxf(1.0, upper_body_bottom - local_top)

	$LowerBody.position.y = lower_body_top + lower_height / 2.0
	$LowerBody.scale.y = lower_height / $LowerBody.texture.get_height()
	lower_body_collision.position.y = $LowerBody.position.y
	lower_body_collision.shape.size.y = lower_height

	$UpperBody.position.y = local_top + upper_height / 2.0
	$UpperBody.scale.y = upper_height / $UpperBody.texture.get_height()
	upper_body_collision.position.y = $UpperBody.position.y
	upper_body_collision.shape.size.y = upper_height
	for overlay in level2_layers:
		var original: Sprite2D = get_node(String(overlay.name).trim_suffix("Level2"))
		overlay.transform = original.transform

func _on_body_entered(body):
	if body.name == "Bird":
		hit.emit()

func _on_score_area_body_entered(body):
	if body.name == "Bird":
		scored.emit()
