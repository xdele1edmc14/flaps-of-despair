@tool
extends Camera2D

var _strength: float = 0.0
var _duration: float = 0.0
var _remaining: float = 0.0
var _elapsed: float = 0.0


func shake(strength: float, duration: float) -> void :
	if strength <= 0.0 or duration <= 0.0:
		return

	_strength = maxf(_strength, strength)
	_duration = maxf(_duration, duration)
	_remaining = maxf(_remaining, duration)
	_elapsed = 0.0


func reset_shake() -> void :
	_strength = 0.0
	_duration = 0.0
	_remaining = 0.0
	_elapsed = 0.0
	offset = Vector2.ZERO


func is_shaking() -> bool:
	return _remaining > 0.0


func _process(delta: float) -> void :
	if _remaining <= 0.0:
		offset = Vector2.ZERO
		return

	_elapsed += delta
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		reset_shake()
		return

	var weight: = _remaining / _duration
	var direction: = Vector2(sin(_elapsed * 83.0), cos(_elapsed * 67.0)).normalized()
	offset = direction * _strength * weight
