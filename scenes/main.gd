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

# Constants
const SCROLL_SPEED: int = 4
const PIPE_DELAY: int = 100
const PIPE_RANGE: int = 200

# Onready references
@onready var bird = $Bird
@onready var ground = $Ground
@onready var pipe_timer = $PipeTimer
@onready var score_label = $ScoreLabel

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	ground_height = ground.get_node("Sprite2D").texture.get_height()
	
	# Connect ground signal
	ground.hit.connect(on_ground_hit)
	
	new_game()

func new_game():
	game_running = false
	game_over = false
	score = 0
	scroll = 0
	$GameOver.hide()
	if score_label:
		score_label.text = "YOUR SCORE: " + str(score)
	
	# Clear old pipes
	for pipe in pipes:
		if pipe.is_inside_tree():
			pipe.queue_free()
	pipes.clear()
	
	bird.reset()
	generate_pipes()

func _input(event):
	if game_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not game_running:
			start_game()
		elif bird.flying:
			bird.flap()
			check_top()

func start_game():
	game_running = true
	bird.flying = true
	bird.flap()
	pipe_timer.start()

func _process(delta):
	if not game_running:
		return
	
	# Scroll ground
	scroll += SCROLL_SPEED
	if scroll >= screen_size.x:
		scroll = 0
	ground.position.x = -scroll
	
	# Move pipes
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

func bird_hit():
	bird.falling = true
	stop_game()

func on_ground_hit():
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
	
	stop_game()


func _on_game_over_restart() -> void:
	new_game()
