extends Node

const FeatherTrail = preload("res://feather_trail.gd")
const STORY_BRANCH_TEXTURE = preload("res://assets/treebranch.png")
const STORY_MUSIC: = preload("res://assets/audio/music/music_ch1_loop.ogg")
const ARCADE_MUSIC: = preload("res://assets/audio/music/ARCADE_MENU_CREDIT_MOODMODE_DURING_ENDNING_CREDITS.mp3")
const MUSIC_SILENCE_DB: = -60.0

signal score_changed(value: int)
signal run_ended(final_score: int)
signal death_landed(final_score: int)

@export var pipe_scene: PackedScene


var game_running: bool = false
var game_over: bool = false
var scroll: float = 0.0
var score: int = 0
var screen_size: Vector2
var ground_height: int
var pipes: Array = []
var death_sound_played: bool = false
var boundary_feathers: Node2D
var pipe_impact_feathers: Node2D
var story_lobby_active: bool = false
var story_lobby_pipe
var story_lobby_branch: Sprite2D
var arcade_idle_time: = 0.0
var arcade_idle_origin: = Vector2.ZERO
var music_fade: Tween
@export var mode: StringName = &"arcade"
@export var managed_by_shell: bool = false


var autoplay: bool = false
const AUTOPLAY_FLAP_Y: = 380


const SCROLL_SPEED: float = 240.0
const PIPE_DELAY: int = 100
const PIPE_RANGE: int = 140


@onready var bird = $Bird
@onready var ground = $Ground
@onready var pipe_timer = $PipeTimer
@onready var score_label = $ScoreLabel
@onready var impact_camera = $ImpactCamera
@onready var background = $Backround
@onready var leaves = $Leaves


@onready var sfx_flap = $SFXFlap
@onready var sfx_pipe_hit = $SFXPipeHit
@onready var sfx_ground_hit = $SFXGroundHit
@onready var sfx_score = $SFXScore
@onready var sfx_death_sigh = $SFXDeathSigh
@onready var music_player = $MusicPlayer
@onready var message_popup = $MessagePopup

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	background.set_mode(mode)
	ground.hit.connect(on_ground_hit)
	get_viewport().size_changed.connect(_layout_playfield)
	_layout_playfield()

	if music_player:
		music_player.stream = ARCADE_MUSIC if mode == &"arcade" else STORY_MUSIC
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS

	new_game()
	if managed_by_shell:
		$GameOver.hide()

func new_game():
	story_lobby_active = false
	story_lobby_pipe = null
	if is_instance_valid(story_lobby_branch):
		story_lobby_branch.queue_free()
	story_lobby_branch = null
	if is_instance_valid(boundary_feathers):
		boundary_feathers.queue_free()
	boundary_feathers = null
	if is_instance_valid(pipe_impact_feathers):
		pipe_impact_feathers.queue_free()
	pipe_impact_feathers = null
	game_running = false
	game_over = false
	score = 0
	scroll = 0
	death_sound_played = false
	arcade_idle_time = 0.0
	impact_camera.reset_shake()
	background.set_score(0, true)
	$GameOver.hide()
	if score_label:
		score_label.show()
		score_label.text = "YOUR SCORE: " + str(score)

	for pipe in pipes:
		if pipe.is_inside_tree():
			pipe.queue_free()
	pipes.clear()
	_apply_level_visuals()

	if music_player and not managed_by_shell and not music_player.playing:
		fade_music_in()

	bird.reset()
	bird.get_node("CollisionShape2D").disabled = false
	arcade_idle_origin = bird.position
	if mode == &"arcade":
		bird.set_physics_process(false)
		bird.get_node("AnimatedSprite2D").play(&"flying")
	else:
		bird.set_physics_process(true)

func _unhandled_input(event):
	if game_over or story_lobby_active:
		return

	var touch_press: bool = event is InputEventScreenTouch and event.pressed and event.index == 0
	var mouse_press: bool = event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if OS.is_debug_build() and (touch_press or mouse_press) and score_label.get_global_rect().has_point(event.position):
		skip_points()
		get_viewport().set_input_as_handled()
		return
	if touch_press or mouse_press:
		if not game_running:
			start_game()
		elif bird.flying:
			bird.flap()
			if sfx_flap:
				sfx_flap.play()
			check_top()
		get_viewport().set_input_as_handled()


	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			autoplay = !autoplay
			print("AUTOPLAY:", autoplay)


		if event.keycode == KEY_F2:
			skip_points(1 if event.shift_pressed else 10)


func skip_points(amount: int = 10) -> int:
	if not OS.is_debug_build():
		return score
	score = maxi(0, score + amount)
	background.set_score(score, score == 0)
	score_label.text = "YOUR SCORE: " + str(score)
	return score

func start_game():
	game_running = true
	bird.set_physics_process(true)
	bird.flying = true
	bird.get_node("AnimatedSprite2D").play(&"flying")
	bird.flap()
	if sfx_flap:
		sfx_flap.play()

	generate_pipes()
	pipe_timer.start()


func prepare_story_lobby(checkpoint_score: int = 0, use_branch: bool = true) -> void :
	new_game()
	score = maxi(0, checkpoint_score)
	score_label.text = "YOUR SCORE: " + str(score)
	background.set_score(score, true)
	_apply_level_visuals()
	story_lobby_active = true
	score_label.hide()
	bird.set_physics_process(false)
	bird.get_node("CollisionShape2D").disabled = true
	var sprite: AnimatedSprite2D = bird.get_node("AnimatedSprite2D")
	sprite.play(&"idle")
	if use_branch:
		story_lobby_branch = Sprite2D.new()
		story_lobby_branch.name = "TreeBranch"
		story_lobby_branch.texture = STORY_BRANCH_TEXTURE
		story_lobby_branch.centered = false
		story_lobby_branch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(story_lobby_branch)
	else:
		story_lobby_pipe = pipe_scene.instantiate()
		story_lobby_pipe.name = "StoryLobbyPipe"
		story_lobby_pipe.collision_layer = 0
		story_lobby_pipe.collision_mask = 0
		story_lobby_pipe.monitoring = false
		story_lobby_pipe.monitorable = false
		var score_area: Area2D = story_lobby_pipe.get_node("ScoreArea")
		score_area.monitoring = false
		score_area.monitorable = false
		add_child(story_lobby_pipe)
		pipes.append(story_lobby_pipe)
	_layout_story_lobby()


func begin_story_from_lobby() -> void :
	if not story_lobby_active:
		return
	story_lobby_active = false
	if is_instance_valid(story_lobby_branch):
		var branch_exit: = create_tween()
		branch_exit.set_parallel(true)
		branch_exit.tween_property(story_lobby_branch, "position:x", story_lobby_branch.position.x - screen_size.x * 0.46, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		branch_exit.tween_property(story_lobby_branch, "modulate:a", 0.0, 0.65).set_delay(0.2)
		branch_exit.chain().tween_callback(story_lobby_branch.queue_free)
	score_label.show()
	bird.get_node("CollisionShape2D").disabled = false
	bird.set_physics_process(true)
	bird.get_node("AnimatedSprite2D").play(&"flying")
	start_game()

func _process(delta):
	var arcade_waiting: = mode == &"arcade" and not game_running and not game_over and not story_lobby_active
	if game_running and not game_over:
		scroll = fmod(scroll + SCROLL_SPEED * delta, screen_size.x)

	if game_running or arcade_waiting:
		background.advance(delta)
		_apply_level_visuals()

	if arcade_waiting:
		arcade_idle_time += delta
		bird.position = arcade_idle_origin + Vector2(0.0, sin(arcade_idle_time * 2.6) * 8.0)
		bird.rotation = sin(arcade_idle_time * 2.6) * 0.04

	if game_running:
		for i in range(pipes.size() - 1, -1, -1):
			var pipe = pipes[i]
			pipe.position.x -= SCROLL_SPEED * delta
			if pipe.position.x < -160.0:
				pipes.remove_at(i)
				pipe.queue_free()
		check_top()


	if autoplay and game_running:
		if bird.position.y > AUTOPLAY_FLAP_Y and bird.flying:
			bird.flap()
			if sfx_flap:
				sfx_flap.play()

func _on_pipe_timer_timeout():
	generate_pipes()

func generate_pipes():
	var pipe = pipe_scene.instantiate()
	pipe.position.x = screen_size.x + PIPE_DELAY
	pipe.position.y = (screen_size.y - ground_height) / 2 + randi_range( - PIPE_RANGE, PIPE_RANGE)
	pipe.hit.connect(bird_hit)
	pipe.scored.connect(increase_score)
	add_child(pipe)
	var surface_y: float = ground.get_surface_y()
	pipe.fit_to_playfield(0.0, surface_y)
	pipe.set_level_mix(0.0)
	pipes.append(pipe)

func increase_score():
	if not game_running or game_over:
		return
	score += 1
	score_changed.emit(score)
	background.set_score(score)
	if score_label:
		score_label.text = "YOUR SCORE: " + str(score)


	if sfx_score:
		sfx_score.play()


	if message_popup and mode == &"story":
		message_popup.show_message(score)


func check_top():
	if not game_running or game_over or bird.position.y >= 0.0:
		return
	if not bird.start_boundary_fall():
		return
	boundary_feathers = FeatherTrail.new()
	boundary_feathers.name = "BoundaryFeathers"
	boundary_feathers.source = bird
	add_child(boundary_feathers)
	stop_game()

func stop_game():
	if not pipe_timer.is_stopped():
		pipe_timer.stop()

	for pipe in pipes:
		pipe.set_process(false)
		pipe.set_physics_process(false)

	bird.flying = false
	if not managed_by_shell:
		$GameOver.show()
	game_running = false
	game_over = true
	run_ended.emit(score)

	if music_player:
		fade_music_out(0.5)


func fade_music_in(duration: float = 0.4, start_position: float = -1.0) -> Tween:
	_kill_music_fade()
	music_player.stream_paused = false
	if not music_player.playing:
		music_player.volume_db = MUSIC_SILENCE_DB
		music_player.play(maxf(start_position, 0.0))
	music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_fade.tween_property(music_player, "volume_db", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return music_fade


func fade_music_out(duration: float = 0.4, stop_after: bool = true, pause_after: bool = false) -> Tween:
	_kill_music_fade()
	music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_fade.tween_property(music_player, "volume_db", MUSIC_SILENCE_DB, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if stop_after:
		music_fade.tween_callback(music_player.stop)
	elif pause_after:
		music_fade.tween_callback( func(): music_player.stream_paused = true)
	return music_fade


func _kill_music_fade() -> void :
	if music_fade and music_fade.is_valid():
		music_fade.kill()
	music_fade = null

func bird_hit():
	if game_over or not bird.start_death_tumble():
		return

	death_sound_played = true
	impact_camera.shake(10.0, 0.16)
	pipe_impact_feathers = FeatherTrail.new()
	pipe_impact_feathers.name = "PipeImpactFeathers"
	pipe_impact_feathers.source = bird
	pipe_impact_feathers.pipe_impact = true
	add_child(pipe_impact_feathers)

	if sfx_pipe_hit:
		sfx_pipe_hit.play()

	stop_game()
	play_delayed_death_sigh(0.3)

func on_ground_hit():
	var surface_y: float = ground.get_surface_y()
	if not bird.play_ground_impact(_ground_contact_y(), surface_y):
		return

	impact_camera.shake(18.0, 0.28)

	if sfx_ground_hit:
		sfx_ground_hit.play()

	if not game_over:
		death_sound_played = true
		stop_game()
	death_landed.emit(score)


func _ground_contact_y() -> float:
	var ground_collision: CollisionShape2D = ground.get_node("CollisionShape2D")
	var bird_collision: CollisionShape2D = bird.get_node("CollisionShape2D")
	var ground_top: = ground_collision.global_position.y - _vertical_half_extent(ground_collision)
	return ground_top - _vertical_half_extent(bird_collision)


func _vertical_half_extent(collision: CollisionShape2D) -> float:
	var half_size: = collision.shape.get_rect().size / 2.0
	var world_transform: = collision.global_transform
	return absf(world_transform.x.y) * half_size.x + absf(world_transform.y.y) * half_size.y

func play_delayed_death_sigh(delay: float):
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect( func():
		if game_over and sfx_death_sigh:
			sfx_death_sigh.play()
	)

func _on_game_over_restart() -> void :
	new_game()


func _layout_playfield() -> void :
	screen_size = get_viewport().get_visible_rect().size
	impact_camera.position = screen_size / 2.0
	background.position = Vector2(-24, -24)
	background.configure_canvas(Vector2(screen_size.x + 48, screen_size.y + 48), SCROLL_SPEED, pipe_timer.wait_time)
	var surface_y: float = background.get_level1_ground_y()
	ground.configure_canvas(screen_size, surface_y)
	ground_height = roundi(screen_size.y - surface_y)
	leaves.configure_canvas(Vector2(screen_size.x, surface_y))
	for pipe in pipes:
		if is_instance_valid(pipe) and pipe.is_inside_tree():
			pipe.fit_to_playfield(0.0, surface_y)
	if story_lobby_active:
		_layout_story_lobby()
	var safe_top: = 20.0
	if OS.has_feature("android"):
		var safe_area: = DisplayServer.get_display_safe_area()
		var physical_size: = DisplayServer.window_get_size()
		if physical_size.y > 0:
			safe_top = maxf(safe_top, float(safe_area.position.y) * screen_size.y / physical_size.y + 12.0)
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	score_label.offset_left = 16
	score_label.offset_right = -16
	score_label.offset_top = safe_top
	score_label.offset_bottom = safe_top + 60
	if managed_by_shell:
		score_label.offset_top = safe_top + 68
		score_label.offset_bottom = safe_top + 128
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.add_theme_font_size_override("font_size", 32)
	$GameOver.offset = Vector2(screen_size.x / 2.0 - 95.0, screen_size.y * 0.45)
	var retry: Button = $GameOver / RestartButton
	retry.size = Vector2(190, 80)
	var panel: Panel = message_popup.get_node("Panel")
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -190
	panel.offset_bottom = -60
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_popup.get_node("Panel/Label").mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout_story_lobby() -> void :
	if not story_lobby_active:
		return
	var surface_y: float = ground.get_surface_y()
	if is_instance_valid(story_lobby_branch):
		var branch_scale: = clampf(screen_size.y / 2095.0, 0.4, 0.58)
		story_lobby_branch.scale = Vector2.ONE * branch_scale
		story_lobby_branch.position = Vector2( - screen_size.x * 0.25, screen_size.y * 0.28)
		bird.position = Vector2(screen_size.x * 0.32, screen_size.y * 0.43)
	elif is_instance_valid(story_lobby_pipe):
		story_lobby_pipe.position = Vector2(screen_size.x * 0.3, surface_y * 0.44)
		story_lobby_pipe.fit_to_playfield(0.0, surface_y)
		var lower_cap: Sprite2D = story_lobby_pipe.get_node("LowerCap")
		bird.position = Vector2(story_lobby_pipe.position.x, story_lobby_pipe.position.y + lower_cap.position.y - 53.0)
	bird.rotation = 0.0


func _apply_level_visuals() -> void :
	ground.set_level_mix(0.0, false)
	for pipe in pipes:
		if is_instance_valid(pipe):
			pipe.set_level_mix(0.0)
	leaves.set_intensity(0.0)
