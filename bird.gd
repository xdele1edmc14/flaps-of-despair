@tool
extends CharacterBody2D

const GRAVITY: int = 1000
const MAX_VEL: int = 600
const FLAP_SPEED: int = -500
const DEATH_KNOCKBACK: = Vector2(-40, -260)
const DEATH_SPIN_SPEED: float = 10.0
const BOUNDARY_GRAVITY: = 1600.0
const BOUNDARY_MAX_VEL: = 850.0
var flying: bool = false
var falling: bool = false
var grounded: bool = false
var death_tumbling: bool = false
var boundary_falling: bool = false
var angular_velocity: float = 0.0
const START_POS = Vector2(100, 400)
var rest_scale: Vector2 = Vector2.ONE
var impact_tween: Tween


func _ready():
	rest_scale = scale
	reset()

func reset():
	if impact_tween and impact_tween.is_valid():
		impact_tween.kill()
	impact_tween = null
	falling = false
	flying = false
	grounded = false
	death_tumbling = false
	boundary_falling = false
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	position = START_POS
	rotation = 0.0
	scale = rest_scale
	$AnimatedSprite2D.animation = &"flying"
	$AnimatedSprite2D.frame = 0


func _physics_process(delta):
	if flying or falling:
		var acceleration: float = BOUNDARY_GRAVITY if boundary_falling else GRAVITY
		var terminal_speed: float = BOUNDARY_MAX_VEL if boundary_falling else MAX_VEL
		velocity.y = minf(velocity.y + acceleration * delta, terminal_speed)

		if death_tumbling:
			rotation += angular_velocity * delta
			$AnimatedSprite2D.stop()
		elif flying:
			set_rotation(deg_to_rad(velocity.y * 0.05))
			$AnimatedSprite2D.play()
		elif falling:
			set_rotation(PI / 2)
			$AnimatedSprite2D.stop()

		move_and_collide(velocity * delta)
	else:
		if $AnimatedSprite2D.animation != &"dead":
			$AnimatedSprite2D.stop()

func flap():
	velocity.y = FLAP_SPEED


func start_death_tumble() -> bool:
	if death_tumbling or grounded:
		return false

	flying = false
	falling = true
	death_tumbling = true
	velocity = DEATH_KNOCKBACK
	angular_velocity = DEATH_SPIN_SPEED
	$AnimatedSprite2D.stop()
	return true


func start_boundary_fall() -> bool:
	if death_tumbling or grounded:
		return false
	flying = false
	falling = true
	boundary_falling = true
	death_tumbling = true
	velocity.x = 0.0
	angular_velocity = 5.0
	$AnimatedSprite2D.stop()
	return true


func play_ground_impact(ground_y: float, surface_y: float = NAN) -> bool:
	if grounded:
		return false

	var was_tumbling: = death_tumbling
	grounded = true
	death_tumbling = false
	boundary_falling = false
	falling = false
	flying = false
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	position.y = ground_y
	$AnimatedSprite2D.play(&"dead")

	if impact_tween and impact_tween.is_valid():
		impact_tween.kill()

	var squash_multiplier: = Vector2(1.22, 0.76) if was_tumbling else Vector2(1.1, 0.86)
	var squash_scale: = rest_scale * squash_multiplier
	var bounce_height: = 18.0 if was_tumbling else 7.0

	rotation = 0.0
	var rebound_rotation: = deg_to_rad(-6.0)
	var final_rotation: float = 0.0

	impact_tween = create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(self, "scale", squash_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.chain().tween_property(self, "position:y", ground_y - bounce_height, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.parallel().tween_property(self, "scale", rest_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.parallel().tween_property(self, "rotation", rebound_rotation, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.chain().tween_property(self, "position:y", ground_y, 0.13).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	impact_tween.parallel().tween_property(self, "rotation", final_rotation, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not is_nan(surface_y):
		impact_tween.chain().tween_callback( func(): _settle_on_surface(surface_y))
	return true


func _settle_on_surface(surface_y: float) -> void :
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	var texture: = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var image: = texture.get_image()
	var bottom: = - INF
	var origin: = sprite.offset
	if sprite.centered:
		origin -= texture.get_size() / 2.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.08:
				continue
			for corner in [Vector2(x, y), Vector2(x + 1, y), Vector2(x, y + 1), Vector2(x + 1, y + 1)]:
				bottom = maxf(bottom, sprite.to_global(origin + corner).y)
	if is_finite(bottom):
		global_position.y += surface_y - bottom
