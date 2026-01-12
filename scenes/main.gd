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

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	ground_height = ground.get_node("Sprite2D").texture.get_height()
	
	# Connect ground signal
	ground.hit.connect(on_ground_hit)
	
	# Start music
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
	
	# Clear old pipes
	for pipe in pipes:
		if pipe.is_inside_tree():
			pipe.queue_free()
	pipes.clear()
	
	# Restart music if stopped
	if music_player and not music_player.playing:
		music_player.play()
	
	bird.reset()
	# DON'T generate pipes until game starts

func _input(event):
	if game_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not game_running:
			start_game()
		elif bird.flying:
			bird.flap()
			# Play flap sound
			if sfx_flap:
				sfx_flap.play()
			check_top()

func start_game():
	game_running = true
	bird.flying = true
	bird.flap()
	# Play flap sound on game start
	if sfx_flap:
		sfx_flap.play()
	
	# Start generating pipes
	generate_pipes()
	pipe_timer.start()

func _process(delta):
	# Only scroll ground when game is NOT over
	if not game_over:
		scroll += SCROLL_SPEED
		if scroll >= screen_size.x:
			scroll = 0
		ground.position.x = -scroll
	
	# Only move pipes when game is running
	if game_running:
		for pipe in pipes:
			pipe.position.x -= SCROLL_SPEED

func _on_pipe_timer_timeout():
	generate_pipes()

func generate_pipes():
	var pipe = pipe_scene.instantiate()
	pipe.position.x = screen_size.x + PIPE_DELAY
	pipe.position.y = (screen_size.y - ground_height) / 2 + randi_range(-PIPE_RANGE, PIPE_RANGE)
	
	# Connect pipe signals
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

func check_top():
	if bird.position.y < 0:
		bird.falling = true
		stop_game()

func stop_game():
	if not pipe_timer.is_stopped():
		pipe_timer.stop()
	bird.flying = false
	$GameOver.show()
	game_running = false
	game_over = true
	
	# Stop music immediately for sudden silence effect
	if music_player:
		music_player.stop()

func bird_hit():
	# Check if death sound already played (prevent double trigger)
	if death_sound_played:
		return
	
	death_sound_played = true
	bird.falling = true
	
	# Play pipe hit sound immediately (before stop_game)
	if sfx_pipe_hit:
		sfx_pipe_hit.play()
	
	stop_game()
	
	# Play death sigh 0.5s after pipe hit (only for pipe deaths)
	play_delayed_death_sigh(0.3)

func on_ground_hit():
	# Always position the bird correctly, even if sound already played
	bird.falling = false
	bird.flying = false
	bird.velocity = Vector2.ZERO
	
	# Position bird on top of ground
	var bird_shape = bird.get_node("CollisionShape2D").shape
	var bird_height = 0
	if bird_shape is RectangleShape2D:
		bird_height = bird_shape.extents.y * 2
	elif bird_shape is CapsuleShape2D:
		bird_height = bird_shape.height
	
	bird.position.y = screen_size.y - ground_height - (bird_height / 2)
	
	# Check if death sound already played (only affects sound, not positioning)
	if death_sound_played:
		return
	
	death_sound_played = true
	
	stop_game()
	
	# Play ground hit sound immediately
	if sfx_ground_hit:
		sfx_ground_hit.play()
	
	# NO death sigh for ground deaths (removed)

func play_delayed_death_sigh(delay: float):
	# Create a timer for delayed death sigh without blocking
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(func(): 
		if sfx_death_sigh:
			sfx_death_sigh.play()
	)

func _on_game_over_restart() -> void:
	new_game()
