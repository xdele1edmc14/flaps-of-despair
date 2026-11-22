class_name ProfileStore
extends RefCounted

const STORY_CHECKPOINT_INTERVAL: = 20

var profile_path: String
var arcade_high_score: int = 0
var coins: int = 0
var gems: int = 0
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var story_started: bool = false
var story_checkpoint: int = 0


func _init(path: String = "user://profile.cfg") -> void :
	profile_path = path
	load_profile()


func load_profile() -> void :
	var config: = ConfigFile.new()
	var error: = config.load(profile_path)
	if error != OK:
		error = config.load(profile_path + ".bak")
	if error != OK:
		return
	arcade_high_score = maxi(0, int(config.get_value("arcade", "high_score", 0)))
	coins = maxi(0, int(config.get_value("wallet", "coins", 0)))
	gems = maxi(0, int(config.get_value("wallet", "gems", 0)))
	music_volume = clampf(float(config.get_value("audio", "music", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", 0.9)), 0.0, 1.0)
	story_started = bool(config.get_value("story", "started", false))
	story_checkpoint = maxi(0, int(config.get_value("story", "checkpoint", 0)))
	story_checkpoint = floori(float(story_checkpoint) / STORY_CHECKPOINT_INTERVAL) * STORY_CHECKPOINT_INTERVAL


func save_profile() -> bool:
	var config: = ConfigFile.new()
	config.set_value("profile", "version", 1)
	config.set_value("arcade", "high_score", arcade_high_score)
	config.set_value("wallet", "coins", coins)
	config.set_value("wallet", "gems", gems)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("story", "started", story_started)
	config.set_value("story", "checkpoint", story_checkpoint)
	var temp_path: = profile_path + ".tmp"
	if config.save(temp_path) != OK:
		return false
	var absolute: = ProjectSettings.globalize_path(profile_path)
	var temp_absolute: = ProjectSettings.globalize_path(temp_path)
	var backup_absolute: = ProjectSettings.globalize_path(profile_path + ".bak")
	if FileAccess.file_exists(profile_path):
		if FileAccess.file_exists(profile_path + ".bak"):
			DirAccess.remove_absolute(backup_absolute)
		if DirAccess.rename_absolute(absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			return false
	if DirAccess.rename_absolute(temp_absolute, absolute) != OK:
		if FileAccess.file_exists(profile_path + ".bak"):
			DirAccess.rename_absolute(backup_absolute, absolute)
		return false
	return true


func record_arcade_score(value: int) -> bool:
	if value <= arcade_high_score:
		return false
	arcade_high_score = value
	save_profile()
	return true


func record_story_score(value: int) -> bool:
	var reached_checkpoint: = floori(float(maxi(0, value)) / STORY_CHECKPOINT_INTERVAL) * STORY_CHECKPOINT_INTERVAL
	if reached_checkpoint < STORY_CHECKPOINT_INTERVAL or reached_checkpoint <= story_checkpoint:
		return false
	story_checkpoint = reached_checkpoint
	story_started = true
	save_profile()
	return true


func set_audio(music: float, sfx: float) -> void :
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	save_profile()
