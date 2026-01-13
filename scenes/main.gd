extends Node

@export var pipe_scene: PackedScene

# Game state
var game_running: bool = false
var game_over: bool = false
var scroll: int = 0
var score: int = 0
var screen_size: Vector2
var ground_height: int
var pipes: Array = []
var death_sound_played: bool = false

# Debug features
var autoplay: bool = false
const AUTOPLAY_FLAP_Y := 380

# Constants
const SCROLL_SPEED: int = 4
const PIPE_DELAY: int = 100
const PIPE_RANGE: int = 200

# Onready references
@onready var bird = $Bird
@onready var ground = $Ground
@onready var pipe_timer = $PipeTimer
@onready var score_label = $ScoreLabel

# Audio references
@onready var sfx_flap = $SFXFlap
@onready var sfx_pipe_hit = $SFXPipeHit
@onready var sfx_ground_hit = $SFXGroundHit
@onready var sfx_score = $SFXScore
@onready var sfx_death_sigh = $SFXDeathSigh
@onready var music_player = $MusicPlayer
@onready var message_popup = $MessagePopup

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	ground_height = ground.get_node("Sprite2D").texture.get_height()
	ground.hit.connect(on_ground_hit)

	if music_player:
		music_player.play()

	new_game()

func new_game():
	game_running = false
	game_over = false
	score = 0
	scroll = 0
	death_sound_played = false
	$GameOver.hide()
	if score_label:
		score_label.text = "YOUR SCORE: " + str(score)

	for pipe in pipes:
		if pipe.is_inside_tree():
			pipe.queue_free()
	pipes.clear()

	if music_player and not music_player.playing:
		music_player.play()

	bird.reset()

func _input(event):
	if game_over:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not game_running:
			start_game()
		elif bird.flying:
			bird.flap()
			if sfx_flap:
				sfx_flap.play()
			check_top()

	# Toggle autoplay (F1)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			autoplay = !autoplay
			print("AUTOPLAY:", autoplay)

		# Skip +10 pipes (F2)
		if event.keycode == KEY_F2:
			score += 10
			if score_label:
				score_label.text = "YOUR SCORE: " + str(score)
			if score == 3 or score % 50 == 0:
				message_popup.show_message(score)

func start_game():
	game_running = true
	bird.flying = true
	bird.flap()
	if sfx_flap:
		sfx_flap.play()

	generate_pipes()
	pipe_timer.start()

func _process(delta):
	if not game_over:
		scroll += SCROLL_SPEED
		if scroll >= screen_size.x:
			scroll = 0
		ground.position.x = -scroll

	if game_running:
		for pipe in pipes:
			pipe.position.x -= SCROLL_SPEED

	# Autoplay logic
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
	pipe.position.y = (screen_size.y - ground_height) / 2 + randi_range(-PIPE_RANGE, PIPE_RANGE)
	pipe.hit.connect(bird_hit)
	pipe.scored.connect(increase_score)
	add_child(pipe)
	pipes.append(pipe)

func increase_score():
	score += 1
	if score_label:
		score_label.text = "YOUR SCORE: " + str(score)
	
	# Play score sound
	if sfx_score:
		sfx_score.play()
	
	# Show message if a message exists for this score
	if message_popup: 
		message_popup.show_message(score)


func check_top():
	if bird.position.y < 0:
		bird.falling = true
		stop_game()

func stop_game():
	if not pipe_timer.is_stopped():
		pipe_timer.stop()

	for pipe in pipes:
		pipe.set_process(false)
		pipe.set_physics_process(false)

	bird.flying = false
	$GameOver.show()
	game_running = false
	game_over = true

	if music_player:
		music_player.stop()

func bird_hit():
	if death_sound_played:
		return

	death_sound_played = true
	bird.falling = true

	if sfx_pipe_hit:
		sfx_pipe_hit.play()

	stop_game()
	play_delayed_death_sigh(0.3)

func on_ground_hit():
	bird.falling = false
	bird.flying = false
	bird.velocity = Vector2.ZERO

	var bird_shape = bird.get_node("CollisionShape2D").shape
	var bird_height = 0
	if bird_shape is RectangleShape2D:
		bird_height = bird_shape.extents.y * 2
	elif bird_shape is CapsuleShape2D:
		bird_height = bird_shape.height

	bird.position.y = screen_size.y - ground_height - (bird_height / 2)

	if death_sound_played:
		return

	death_sound_played = true
	stop_game()

	if sfx_ground_hit:
		sfx_ground_hit.play()

func play_delayed_death_sigh(delay: float):
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if sfx_death_sigh:
			sfx_death_sigh.play()
	)

func _on_game_over_restart() -> void:
	new_game()
