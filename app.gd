extends Node

const GAME_SCENE: = preload("res://scenes/main.tscn")
const BIRD_SCENE: = preload("res://scenes/bird.tscn")
const PROFILE_STORE: = preload("res://profile_store.gd")
const FONT: = preload("res://assets/Silkscreen-Bold.ttf")
const PIPE_TEXTURE: = preload("res://assets/pipe.png")
const CINEMATIC_BACKDROP: = preload("res://cinematic_backdrop.gd")
const CINEMATIC_AMBIENCE: = preload("res://cinematic_ambience.gd")
const MAIN_MENU_MUSIC: = preload("res://assets/audio/music/main_menu.mp3")
const ARCADE_MUSIC: = preload("res://assets/audio/music/ARCADE_MENU_CREDIT_MOODMODE_DURING_ENDNING_CREDITS.mp3")
const MENU_MUSIC_DB: = -7.0
const MUSIC_SILENCE_DB: = -60.0
const PURPLE: = Color("a970ff")
const CREAM: = Color("fff3d1")
const INK: = Color("21172b")
const ORANGE: = Color("ef6536")
const GREEN: = Color("63c74d")

var profile
var session
var ui: CanvasLayer
var screen: StringName = &""
var current_mode: StringName = &"story"
var record_announced: = false
var record_effect: Control
var _screen_serial: = 0
var _settings_return: StringName = &"main_menu"
var _menu_motion_time: = 0.0
var _transitioning: = false
var story_launching: = false
var story_bird
var _menu_music_fade: Tween
@onready var menu_music: AudioStreamPlayer = $MenuMusic
@onready var fade_rect: ColorRect = $TransitionLayer / Fade


func _ready() -> void :
	if profile == null:
		profile = PROFILE_STORE.new()
	_apply_audio_settings()
	show_splash()


func _process(delta: float) -> void :
	if screen not in [&"main_menu", &"arcade_lobby"] or not is_instance_valid(ui):
		return
	var bird = ui.find_child("MenuBird", true, false)
	if not is_instance_valid(bird):
		return
	var stage: = bird.get_parent() as Control
	_menu_motion_time += delta
	if screen == &"main_menu":
		var center: = stage.size * Vector2(0.5, 0.52)
		bird.position = center + Vector2(sin(_menu_motion_time * 0.75) * 38.0, sin(_menu_motion_time * 1.7) * 13.0)
		bird.rotation = sin(_menu_motion_time * 1.7) * 0.07
	else:
		var perch_y: float = bird.get_meta("perch_y", stage.size.y - 117.0)
		bird.position = Vector2(stage.size.x * 0.5, perch_y + sin(_menu_motion_time * 2.2) * 2.5)
		bird.rotation = sin(_menu_motion_time * 2.2) * 0.025


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if handle_back():
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not handle_back():
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and screen == &"gameplay":
		pause_session()


func handle_back() -> bool:
	match screen:
		&"splash": finish_splash()
		&"gameplay": pause_session()
		&"paused": resume_session()
		&"settings": _close_settings()
		&"story_hub", &"arcade_lobby", &"results": show_main_menu()
		&"main_menu": return false
		_: show_main_menu()
	return true


func show_splash() -> void :
	_set_menu_music(MAIN_MENU_MUSIC, 1.0)
	screen = &"splash"
	_screen_serial += 1
	_new_ui(false)
	var serial: = _screen_serial
	var content: = ui.get_node("Content") as Control
	content.add_child(_color_rect("Void", Color("100d19"), true))
	var logo: = RichTextLabel.new()
	logo.name = "StudioLogo"
	logo.bbcode_enabled = true
	logo.fit_content = true
	logo.scroll_active = false
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.text = "[center][color=#a970ff]>∅[/color] [color=#fffaf1]NullPointer[/color] [color=#a970ff]Studios[/color][/center]"
	logo.add_theme_font_size_override("normal_font_size", 27)
	logo.set_anchors_preset(Control.PRESET_CENTER)
	logo.position = Vector2(-245, -30)
	logo.size = Vector2(490, 60)
	logo.modulate.a = 0.0
	content.add_child(logo)
	var tween: = create_tween()
	tween.tween_property(logo, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(3.0).timeout
	if screen == &"splash" and serial == _screen_serial:
		finish_splash()


func finish_splash() -> void :
	if screen != &"splash" or _transitioning:
		return
	await _fade_switch(show_main_menu, 0.45, 0.55)


func show_main_menu() -> void :
	_discard_session()
	screen = &"main_menu"
	current_mode = &"story"
	_new_ui()
	_set_menu_music(MAIN_MENU_MUSIC, 1.0)
	var box: = _page_box()
	_add_brand(box)
	box.add_child(_spacer(8))
	var title: = _label("FLAPS OF\nDESPAIR", 47, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("line_spacing", -8)
	box.add_child(title)
	var tagline: = _label("KEEP FLAPPING.", 15, Color("d4c1e8"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)
	box.add_child(_bird_showcase(170, false))
	var story: = _button("STORY", "StoryButton", Vector2(0, 82), ORANGE, true)
	story.pressed.connect(select_story)
	box.add_child(story)
	var arcade: = _button("ARCADE", "ArcadeButton", Vector2(0, 68), GREEN)
	arcade.pressed.connect(select_arcade)
	box.add_child(arcade)
	var settings: = _button("SETTINGS", "SettingsButton", Vector2(0, 54), PURPLE)
	settings.pressed.connect( func(): open_settings(&"main_menu"))
	box.add_child(settings)
	var version: = _label("ANDROID FIRST  •  EARLY BUILD", 11, Color("b7a9c6"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version)


func select_story() -> void :
	if _transitioning:
		return
	await _fade_switch(open_story_hub, 0.28, 0.46)


func select_arcade() -> void :
	if _transitioning:
		return
	await _fade_switch(open_arcade_lobby, 0.24, 0.34)


func open_story_hub() -> void :
	_discard_session()
	screen = &"story_hub"
	current_mode = &"story"
	story_launching = false
	session = GAME_SCENE.instantiate()
	session.mode = &"story"
	session.managed_by_shell = true
	add_child(session)
	session.score_changed.connect(_on_score_changed)
	session.run_ended.connect(_on_run_ended)
	var checkpoint: int = profile.story_checkpoint
	var use_branch: = checkpoint < PROFILE_STORE.STORY_CHECKPOINT_INTERVAL
	session.prepare_story_lobby(checkpoint, use_branch)
	session.music_player.stop()
	story_bird = session.bird
	_new_ui(false)
	_set_menu_music(MAIN_MENU_MUSIC, 0.94)
	var content: = ui.get_node("Content") as Control
	var ambience: = CINEMATIC_AMBIENCE.new()
	ambience.name = "StoryAmbience"
	content.add_child(ambience)
	var brand: = _floating_brand()
	brand.set_anchors_preset(Control.PRESET_TOP_WIDE)
	brand.offset_top = 28
	brand.offset_bottom = 66
	content.add_child(brand)
	var chapter: = _label("CHAPTER I  •  THE MEADOW OF INNOCENCE", 13, Color("f2e6c8"))
	chapter.name = "ChapterTitle"
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter.set_anchors_preset(Control.PRESET_TOP_WIDE)
	chapter.offset_top = 78
	chapter.offset_bottom = 112
	content.add_child(chapter)
	var currency: = _label("COINS  0    ◆  0", 13, CREAM)
	currency.name = "Currency"
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	currency.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	currency.position = Vector2(-238, 126)
	currency.size = Vector2(210, 44)
	content.add_child(currency)
	var side: = VBoxContainer.new()
	side.name = "StoryTools"
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.position = Vector2(-102, 182)
	side.size = Vector2(82, 190)
	side.add_theme_constant_override("separation", 10)
	content.add_child(side)
	var shop: = _quiet_button("SHOP", "ShopButton")
	shop.pressed.connect( func(): show_notice("SHOP", "Cosmetics and trails are coming later."))
	side.add_child(shop)
	var collection: = _quiet_button("SKINS", "CollectionButton")
	collection.pressed.connect( func(): show_notice("BIRD COLLECTION", "Your collection will live here."))
	side.add_child(collection)
	var settings: = _quiet_button("SET", "SettingsButton")
	settings.pressed.connect( func(): open_settings(&"story_hub"))
	side.add_child(settings)
	var start_zone: = Button.new()
	start_zone.name = "StoryStartZone"
	start_zone.text = "TAP TO START YOUR JOURNEY"
	start_zone.flat = true
	start_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_zone.anchor_left = 0.12
	start_zone.anchor_right = 0.88
	start_zone.anchor_top = 0.5
	start_zone.anchor_bottom = 0.78
	start_zone.offset_left = 0
	start_zone.offset_right = 0
	start_zone.offset_top = 0
	start_zone.offset_bottom = 0
	start_zone.add_theme_font_override("font", FONT)
	start_zone.add_theme_font_size_override("font_size", 20)
	start_zone.add_theme_color_override("font_color", CREAM)
	start_zone.add_theme_color_override("font_hover_color", Color.WHITE)
	start_zone.pressed.connect(launch_story_from_lobby)
	content.add_child(start_zone)
	var next_checkpoint: = (floori(float(checkpoint) / PROFILE_STORE.STORY_CHECKPOINT_INTERVAL) + 1) * PROFILE_STORE.STORY_CHECKPOINT_INTERVAL
	var progress: = _label("NEXT AUTOSAVE  •  %d" % next_checkpoint, 11, Color("d9cfb7"))
	progress.name = "Checkpoint"
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	progress.offset_top = -98
	progress.offset_bottom = -66
	content.add_child(progress)
	var back: = _quiet_button("MAIN MENU", "BackButton")
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.position = Vector2(22, -74)
	back.size = Vector2(142, 54)
	back.pressed.connect(show_main_menu)
	content.add_child(back)


func open_arcade_lobby() -> void :
	_discard_session()
	screen = &"arcade_lobby"
	current_mode = &"arcade"
	_new_ui()
	_set_menu_music(ARCADE_MUSIC, 1.0)
	var box: = _page_box()
	_add_brand(box)
	box.add_child(_spacer(20))
	var title: = _label("ARCADE", 46, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle: = _label("ONE BIRD. NO END.", 15, Color("cfe9c8"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_bird_showcase(190, true))
	var record_panel: = PanelContainer.new()
	record_panel.name = "HighScoreCard"
	record_panel.add_theme_stylebox_override("panel", _panel_style(Color("231b38"), PURPLE, 16, 3))
	var record: = _label("LOCAL HIGH SCORE\n%d" % profile.arcade_high_score, 23, CREAM)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_panel.add_child(record)
	box.add_child(record_panel)
	var play: = _button("PLAY ENDLESS", "PlayButton", Vector2(0, 82), GREEN, true)
	play.pressed.connect( func(): start_session(&"arcade"))
	box.add_child(play)
	var leaderboard: = _button("LEADERBOARD  •  COMING LATER", "LeaderboardButton", Vector2(0, 62), PURPLE)
	leaderboard.pressed.connect( func(): show_notice("LEADERBOARD", "Online rankings are coming later. Your local record is saved."))
	box.add_child(leaderboard)
	var bottom: = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	box.add_child(bottom)
	var settings: = _button("SETTINGS", "SettingsButton", Vector2(0, 54), Color("755c9f"))
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect( func(): open_settings(&"arcade_lobby"))
	bottom.add_child(settings)
	var back: = _button("MAIN MENU", "BackButton", Vector2(0, 54), Color("755c9f"))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(show_main_menu)
	bottom.add_child(back)


func start_session(mode: StringName) -> void :
	_discard_session()
	var arcade_music_position: = menu_music.get_playback_position() if mode == &"arcade" and menu_music.stream == ARCADE_MUSIC else 0.0
	_fade_out_menu_music(0.3)
	current_mode = mode
	record_announced = false
	record_effect = null
	session = GAME_SCENE.instantiate()
	session.mode = mode
	session.managed_by_shell = true
	add_child(session)
	session.fade_music_in(0.45, arcade_music_position if mode == &"arcade" else 0.0)
	session.score_changed.connect(_on_score_changed)
	session.run_ended.connect(_on_run_ended)
	screen = &"gameplay"
	_show_gameplay_hud()


func pause_session() -> void :
	if not is_instance_valid(session) or screen != &"gameplay":
		return
	session.fade_music_out(0.2, false, true)
	session.process_mode = Node.PROCESS_MODE_DISABLED
	screen = &"paused"
	_new_ui(false)
	var content: = ui.get_node("Content") as Control
	content.add_child(_color_rect("PauseVeil", Color(0.04, 0.03, 0.08, 0.82), true))
	var box: = _page_box(0.12, 0.88, 0.25, 0.78)
	var title: = _label("PAUSED", 42, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_spacer(30))
	var resume: = _button("RESUME", "ResumeButton", Vector2(0, 76), ORANGE, true)
	resume.pressed.connect(resume_session)
	box.add_child(resume)
	var settings: = _button("SETTINGS", "SettingsButton", Vector2(0, 62), PURPLE)
	settings.pressed.connect( func(): open_settings(&"paused"))
	box.add_child(settings)
	var menu: = _button("MAIN MENU", "MenuButton", Vector2(0, 58), Color("6b526e"))
	menu.pressed.connect(show_main_menu)
	box.add_child(menu)


func resume_session() -> void :
	if not is_instance_valid(session):
		show_main_menu()
		return
	session.process_mode = Node.PROCESS_MODE_INHERIT
	session.fade_music_in(0.24)
	screen = &"gameplay"
	_show_gameplay_hud()


func retry_session() -> void :
	if current_mode == &"story":
		open_story_hub()
	else:
		start_session(&"arcade")


func _show_gameplay_hud() -> void :
	_new_ui(false)
	var content: = ui.get_node("Content") as Control
	var pause: = _button("Ⅱ", "PauseButton", Vector2(66, 66), Color("2a213b"))
	pause.position = Vector2(18, 18)
	pause.pressed.connect(pause_session)
	content.add_child(pause)
	var mode_tag: = _label("STORY" if current_mode == &"story" else "ARCADE", 12, CREAM)
	mode_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mode_tag.position = Vector2(-150, 26)
	mode_tag.size = Vector2(130, 30)
	content.add_child(mode_tag)


func _on_score_changed(value: int) -> void :
	if current_mode == &"story":
		profile.record_story_score(value)
		return
	if current_mode != &"arcade":
		return
	var broke_record: bool = profile.record_arcade_score(value)
	if broke_record and not record_announced:
		record_announced = true
		_play_record_celebration(value)


func _play_record_celebration(value: int) -> void :
	if not is_instance_valid(ui):
		return
	var content: = ui.get_node("Content") as Control
	var card: = PanelContainer.new()
	card.name = "RecordCelebration"
	card.z_index = 100
	card.set_anchors_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 58
	card.offset_right = -58
	card.offset_top = 98
	card.offset_bottom = 190
	card.pivot_offset = Vector2(212, 46)
	card.scale = Vector2(0.25, 0.25)
	card.add_theme_stylebox_override("panel", _panel_style(Color("fff0bd"), ORANGE, 18, 5))
	var text: = _label("NEW HIGH SCORE!\n%d" % value, 22, INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(text)
	content.add_child(card)
	record_effect = card
	var tween: = create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation", deg_to_rad(-2.0), 0.08)
	tween.tween_property(card, "rotation", deg_to_rad(2.0), 0.08)
	tween.tween_property(card, "rotation", 0.0, 0.08)
	tween.tween_interval(0.65)
	tween.tween_property(card, "modulate:a", 0.0, 0.3)
	tween.tween_callback(card.queue_free)
	for i in 12:
		var bit: = ColorRect.new()
		bit.color = [PURPLE, ORANGE, GREEN, CREAM][i % 4]
		bit.size = Vector2(8, 8)
		bit.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 145)
		bit.rotation = i * 0.7
		bit.z_index = 99
		content.add_child(bit)
		var angle: = TAU * float(i) / 12.0
		var target: = bit.position + Vector2(cos(angle), sin(angle)) * (85.0 + (i % 3) * 18.0)
		var sparkle: = create_tween()
		sparkle.set_parallel(true)
		sparkle.tween_property(bit, "position", target, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sparkle.tween_property(bit, "rotation", bit.rotation + 4.0, 0.65)
		sparkle.tween_property(bit, "modulate:a", 0.0, 0.65).set_delay(0.25)
		sparkle.chain().tween_callback(bit.queue_free)


func _on_run_ended(final_score: int) -> void :
	var ended_session = session
	var serial: = _screen_serial
	var landed_score: int = await ended_session.death_landed
	if ended_session != session or screen != &"gameplay" or serial != _screen_serial:
		return
	var content: = ui.get_node("Content") as Control
	var veil: = _color_rect("LandingVeil", Color(0.025, 0.018, 0.04, 0.0), true)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(veil)
	var hush: = create_tween()
	hush.tween_property(veil, "color:a", 0.68, 0.68).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hush.tween_interval(0.24)
	await hush.finished
	if ended_session != session or screen != &"gameplay" or serial != _screen_serial:
		return
	show_results(landed_score if landed_score >= 0 else final_score)


func show_results(final_score: int) -> void :
	if is_instance_valid(session):
		session.process_mode = Node.PROCESS_MODE_DISABLED
	screen = &"results"
	_new_ui(false)
	var content: = ui.get_node("Content") as Control
	content.add_child(_color_rect("ResultVeil", Color(0.025, 0.018, 0.04, 0.76), true))
	var box: = _page_box(0.14, 0.86, 0.56, 0.92)
	var result_text: = "SCORE  •  %d" % final_score
	if current_mode == &"arcade":
		result_text += "\nBEST  •  %d" % profile.arcade_high_score
	var score: = _label(result_text, 18, Color("ead9b1"))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(score)
	box.add_child(_spacer(18))
	var retry: = _quiet_button("TRY AGAIN", "RetryButton")
	retry.custom_minimum_size.y = 66
	retry.pressed.connect(retry_session)
	box.add_child(retry)
	var menu: = _quiet_button("LEAVE", "MenuButton")
	menu.custom_minimum_size.y = 54
	menu.pressed.connect(show_main_menu)
	box.add_child(menu)


func open_settings(return_to: StringName) -> void :
	_settings_return = return_to
	if return_to == &"paused" and is_instance_valid(session):
		session.process_mode = Node.PROCESS_MODE_DISABLED
	screen = &"settings"
	_new_ui(false)
	var content: = ui.get_node("Content") as Control
	content.add_child(_color_rect("SettingsVeil", Color(0.04, 0.03, 0.08, 0.9), true))
	var box: = _page_box(0.1, 0.9, 0.15, 0.86)
	var title: = _label("SETTINGS", 38, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_label("MUSIC", 16, CREAM))
	var music: = HSlider.new()
	music.name = "MusicSlider"
	music.min_value = 0
	music.max_value = 1
	music.step = 0.05
	music.value = profile.music_volume
	music.custom_minimum_size.y = 50
	music.value_changed.connect( func(value: float): _save_audio(value, profile.sfx_volume))
	box.add_child(music)
	box.add_child(_label("SOUND EFFECTS", 16, CREAM))
	var sfx: = HSlider.new()
	sfx.name = "SFXSlider"
	sfx.min_value = 0
	sfx.max_value = 1
	sfx.step = 0.05
	sfx.value = profile.sfx_volume
	sfx.custom_minimum_size.y = 50
	sfx.value_changed.connect( func(value: float): _save_audio(profile.music_volume, value))
	box.add_child(sfx)
	var note: = _label("SCREEN SHAKE • HAPTICS • ACCESSIBILITY\nCOMING IN THE NEXT SETTINGS PASS", 12, Color("c8bad9"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var back: = _button("BACK", "BackButton", Vector2(0, 66), PURPLE, true)
	back.pressed.connect(_close_settings)
	box.add_child(back)


func _close_settings() -> void :
	match _settings_return:
		&"story_hub": open_story_hub()
		&"arcade_lobby": open_arcade_lobby()
		&"paused":
			screen = &"paused"
			pause_session_from_settings()
		_: show_main_menu()


func pause_session_from_settings() -> void :
	if not is_instance_valid(session):
		show_main_menu()
		return
	screen = &"gameplay"
	pause_session()


func show_notice(title_text: String, body_text: String) -> void :
	if not is_instance_valid(ui):
		return
	var content: = ui.get_node("Content") as Control
	var veil: = _color_rect("NoticeVeil", Color(0.03, 0.02, 0.06, 0.78), true)
	veil.z_index = 200
	content.add_child(veil)
	var panel: = PanelContainer.new()
	panel.name = "Notice"
	panel.z_index = 201
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-205, -150)
	panel.size = Vector2(410, 300)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("21182e"), PURPLE, 20, 4))
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title: = _label(title_text, 27, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body: = _label(body_text, 15, Color("d7cbe3"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var close: = _button("GOT IT", "CloseButton", Vector2(0, 60), PURPLE)
	close.pressed.connect( func(): panel.queue_free();veil.queue_free())
	box.add_child(close)
	content.add_child(panel)


func _discard_session() -> void :
	_screen_serial += 1
	if is_instance_valid(session):
		var old_session = session
		old_session.process_mode = Node.PROCESS_MODE_DISABLED
		for child in old_session.get_children():
			if child is AudioStreamPlayer2D and child != old_session.music_player:
				child.stop()
		if old_session.music_player.playing and not old_session.music_player.stream_paused:
			var fade: Tween = old_session.fade_music_out(0.3, true)
			fade.finished.connect(old_session.queue_free)
		else:
			old_session.queue_free()
	session = null
	record_effect = null


func _new_ui(with_background: bool = true) -> void :
	_screen_serial += 1
	if is_instance_valid(ui):
		ui.queue_free()
	ui = CanvasLayer.new()
	ui.name = "Interface"
	ui.layer = 50
	add_child(ui)
	var content: = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(content)
	if with_background:
		var background = CINEMATIC_BACKDROP.new()
		background.name = "CinematicBackdrop"
		content.add_child(background)
		content.add_child(_color_rect("Tint", Color(0.07, 0.04, 0.14, 0.42), true))
		content.move_child(background, 0)


func _page_box(left: = 0.08, right: = 0.92, top: = 0.055, bottom: = 0.95) -> VBoxContainer:
	var box: = VBoxContainer.new()
	box.name = "Page"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.anchor_left = left
	box.anchor_right = right
	box.anchor_top = top
	box.anchor_bottom = bottom
	box.offset_left = 0
	box.offset_right = 0
	box.offset_top = 0
	box.offset_bottom = 0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	ui.get_node("Content").add_child(box)
	return box


func _add_brand(box: VBoxContainer) -> void :
	var brand: = RichTextLabel.new()
	brand.name = "Brand"
	brand.bbcode_enabled = true
	brand.fit_content = true
	brand.scroll_active = false
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.text = "[center][color=#a970ff]>∅[/color] [color=#fffaf1]NullPointer[/color] [color=#a970ff]Studios[/color][/center]"
	brand.add_theme_font_size_override("normal_font_size", 14)
	brand.custom_minimum_size.y = 30
	box.add_child(brand)


func _bird_showcase(height: float, perched: bool) -> Control:
	var stage: = Control.new()
	stage.name = "BirdShowcase"
	stage.custom_minimum_size.y = height
	stage.clip_contents = true
	var bird = BIRD_SCENE.instantiate()
	bird.name = "MenuBird"
	stage.add_child(bird)
	bird.set_physics_process(false)
	var desired_animation: StringName = &"idle" if perched else &"flying"
	bird.ready.connect( func():
		bird.set_physics_process(false)
		bird.get_node("AnimatedSprite2D").play(desired_animation)
	, CONNECT_ONE_SHOT)
	if perched:
		bird.set_meta("perch_y", height - 117.0)
		var shaft: = TextureRect.new()
		shaft.name = "PerchShaft"
		shaft.texture = _atlas_texture(Rect2(3, 36, 72, 524))
		shaft.size = Vector2(66, 115)
		shaft.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shaft.stretch_mode = TextureRect.STRETCH_SCALE
		shaft.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stage.add_child(shaft)
		var cap: = TextureRect.new()
		cap.name = "PerchCap"
		cap.texture = _atlas_texture(Rect2(0, 0, 78, 36))
		cap.size = Vector2(104, 48)
		cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cap.stretch_mode = TextureRect.STRETCH_SCALE
		cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stage.add_child(cap)
		stage.resized.connect( func():
			var center: = stage.size.x * 0.5
			cap.position = Vector2(center - 52, height - 86)
			shaft.position = Vector2(center - 33, height - 38)
			bird.position = Vector2(center, height - 117)
		)
	else:
		stage.resized.connect( func(): bird.position = stage.size * Vector2(0.5, 0.52))
	return stage


func _floating_brand() -> RichTextLabel:
	var brand: = RichTextLabel.new()
	brand.name = "Brand"
	brand.bbcode_enabled = true
	brand.fit_content = true
	brand.scroll_active = false
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.text = "[center][color=#a970ff]>∅[/color] [color=#fffaf1]NullPointer[/color] [color=#a970ff]Studios[/color][/center]"
	brand.add_theme_font_size_override("normal_font_size", 14)
	return brand


func _quiet_button(text_value: String, node_name: String) -> Button:
	var button: = Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(78, 52)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("eee2c8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.06, 0.04, 0.1, 0.46), Color(0.85, 0.77, 0.62, 0.22), 10, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.1, 0.07, 0.15, 0.72), Color(0.96, 0.88, 0.7, 0.5), 10, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.03, 0.02, 0.06, 0.82), Color(0.96, 0.88, 0.7, 0.72), 10, 1))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, Color(0.96, 0.88, 0.7, 0.65), 10, 1))
	return button


func launch_story_from_lobby() -> void :
	if story_launching or screen != &"story_hub" or not is_instance_valid(session) or not is_instance_valid(story_bird):
		return
	story_launching = true
	var start_zone: = ui.find_child("StoryStartZone", true, false) as Button
	if start_zone != null:
		start_zone.disabled = true
		var prompt_fade: = create_tween()
		prompt_fade.tween_property(start_zone, "modulate:a", 0.0, 0.18)
	var bird = story_bird
	var sprite: = bird.get_node("AnimatedSprite2D") as AnimatedSprite2D
	sprite.animation = &"flying"
	sprite.stop()
	sprite.frame = 5
	await get_tree().create_timer(0.16).timeout
	if not is_instance_valid(bird) or screen != &"story_hub":
		return
	sprite.animation = &"east"
	sprite.frame = 0
	sprite.stop()
	var ready_pose: = create_tween()
	ready_pose.set_parallel(true)
	ready_pose.tween_property(bird, "position", bird.position + Vector2(-4, 5), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	ready_pose.tween_property(bird, "rotation", deg_to_rad(-8.0), 0.14)
	await ready_pose.finished
	if not is_instance_valid(bird) or screen != &"story_hub":
		return
	_fade_out_menu_music(0.3)
	session.fade_music_in(0.45)
	session.begin_story_from_lobby()
	screen = &"gameplay"
	_show_gameplay_hud()
	story_launching = false


func _fade_switch(callback: Callable, fade_out_duration: float, fade_in_duration: float) -> void :
	if _transitioning:
		return
	_transitioning = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_rect.color.a = 0.0
	var fade_out: = create_tween()
	fade_out.tween_property(fade_rect, "color:a", 1.0, fade_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished
	callback.call()
	var fade_in: = create_tween()
	fade_in.tween_property(fade_rect, "color:a", 0.0, fade_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false


func _button(text_value: String, node_name: String, minimum: Vector2, accent: Color, primary: = false) -> Button:
	var button: = Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22 if primary else 15)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(accent.darkened(0.42), accent, 14, 3))
	button.add_theme_stylebox_override("hover", _panel_style(accent.darkened(0.28), accent.lightened(0.18), 14, 4))
	button.add_theme_stylebox_override("pressed", _panel_style(accent.darkened(0.52), CREAM, 14, 3))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, CREAM, 14, 3))
	return button


func _label(text_value: String, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = text_value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _spacer(height: float) -> Control:
	var spacer: = Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _color_rect(node_name: String, color: Color, full: bool) -> ColorRect:
	var rect: = ColorRect.new()
	rect.name = node_name
	rect.color = color
	if full:
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _panel_style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _atlas_texture(region: Rect2) -> AtlasTexture:
	var atlas: = AtlasTexture.new()
	atlas.atlas = PIPE_TEXTURE
	atlas.region = region
	return atlas


func _save_audio(music: float, sfx: float) -> void :
	profile.set_audio(music, sfx)
	_apply_audio_settings()


func _apply_audio_settings() -> void :
	var music_bus: = AudioServer.get_bus_index("Music")
	var sfx_bus: = AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(profile.music_volume, 0.0001)))
		AudioServer.set_bus_mute(music_bus, is_zero_approx(profile.music_volume))
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(profile.sfx_volume, 0.0001)))
		AudioServer.set_bus_mute(sfx_bus, is_zero_approx(profile.sfx_volume))


func _set_menu_music(stream: AudioStream, pitch: float) -> void :
	_kill_menu_music_fade()
	if menu_music.stream == stream and menu_music.playing:
		menu_music.pitch_scale = pitch
		if menu_music.volume_db < MENU_MUSIC_DB:
			_menu_music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_menu_music_fade.tween_property(menu_music, "volume_db", MENU_MUSIC_DB, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	if menu_music.playing:
		_menu_music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_menu_music_fade.tween_property(menu_music, "volume_db", MUSIC_SILENCE_DB, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_menu_music_fade.tween_callback( func(): _start_menu_track(stream, pitch))
		_menu_music_fade.tween_property(menu_music, "volume_db", MENU_MUSIC_DB, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	_start_menu_track(stream, pitch)
	_menu_music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_menu_music_fade.tween_property(menu_music, "volume_db", MENU_MUSIC_DB, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_menu_track(stream: AudioStream, pitch: float) -> void :
	menu_music.stop()
	menu_music.stream = stream
	menu_music.pitch_scale = pitch
	menu_music.volume_db = MUSIC_SILENCE_DB
	menu_music.play()


func _fade_out_menu_music(duration: float) -> void :
	if not menu_music.playing:
		return
	_kill_menu_music_fade()
	_menu_music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_menu_music_fade.tween_property(menu_music, "volume_db", MUSIC_SILENCE_DB, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_menu_music_fade.tween_callback(menu_music.stop)


func _kill_menu_music_fade() -> void :
	if _menu_music_fade and _menu_music_fade.is_valid():
		_menu_music_fade.kill()
	_menu_music_fade = null
