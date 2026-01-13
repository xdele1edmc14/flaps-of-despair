extends CanvasLayer

# References
@onready var panel = $Panel
@onready var label = $Panel/Label
@onready var blip_player = $BlipPlayer

# State
var is_showing: bool = false
var can_dismiss: bool = false
var typewriter_active: bool = false

# Constants
const CHAR_DELAY: float = 0.05  # seconds per character
const AUTO_DISMISS_TIME: float = 3.0  # seconds
const TARGET_ALPHA: float = 0.4  # panel opacity

# Message dictionary - Ember's journey
const MESSAGES = {
	3: "Alright. I've got this.",
	50: "The air feels good today.",
	100: "I'm flying better than before.",
	150: "This isn't so hard.",
	200: "I'll reach her soon.",
	250: "Just keep going.",
	300: "Why does it feel longer now?",
	350: "I don't remember taking breaks.",
	400: "I should be there by now.",
	450: "Maybe I took the long way.",
	500: "My wings feel heavier.",
	550: "I don't feel as light anymore.",
	600: "Am I flying… or just falling slower?",
	650: "I can't turn back now.",
	700: "I don't even know what I'm chasing.",
	750: "Stopping would hurt more.",
	800: "I'm tired.",
	850: "I think she stopped waiting.",
	900: "I knew this wouldn't end well.",
	950: "Wait… I see something.",
	998: "Almost there. Please."
}

func _ready():
	# Hide popup initially
	hide_popup()

func show_message(score: int) -> void:
	if is_showing or not MESSAGES.has(score):
		return

	is_showing = true
	can_dismiss = false
	typewriter_active = true

	var text = MESSAGES[score]
	label.text = ""
	panel.modulate.a = 0.0
	visible = true

	# Fade in
	var tween_in = create_tween()
	tween_in.tween_property(panel, "modulate:a", TARGET_ALPHA, 0.25)
	await tween_in.finished

	# Typewriter effect
	for i in text.length():
		label.text += text[i]
		if text[i] != " ":
			blip_player.play()
		await get_tree().create_timer(CHAR_DELAY).timeout

	typewriter_active = false
	can_dismiss = true

	# Auto-dismiss after AUTO_DISMISS_TIME
	await get_tree().create_timer(AUTO_DISMISS_TIME).timeout
	if is_showing:
		dismiss_popup()

func dismiss_popup() -> void:
	if not is_showing:
		return

	var tween_out = create_tween()
	tween_out.tween_property(panel, "modulate:a", 0.0, 0.25)
	await tween_out.finished
	hide_popup()

func hide_popup() -> void:
	visible = false
	is_showing = false
	can_dismiss = false
	typewriter_active = false
	label.text = ""

func _input(event):
	if is_showing and can_dismiss:
		if event is InputEventMouseButton and event.pressed:
			dismiss_popup()
