extends Node

enum Feedback { TAP, DROP, MERGE, BIG_MERGE, POWERUP, DANGER, GAME_OVER, REWARD }

const DURATIONS := {
	Feedback.TAP: 14,
	Feedback.DROP: 22,
	Feedback.MERGE: 32,
	Feedback.BIG_MERGE: 55,
	Feedback.POWERUP: 65,
	Feedback.DANGER: 80,
	Feedback.GAME_OVER: 130,
	Feedback.REWARD: 90,
}
const AMPLITUDES := {
	Feedback.TAP: 0.22,
	Feedback.DROP: 0.30,
	Feedback.MERGE: 0.40,
	Feedback.BIG_MERGE: 0.65,
	Feedback.POWERUP: 0.72,
	Feedback.DANGER: 0.58,
	Feedback.GAME_OVER: 0.85,
	Feedback.REWARD: 0.75,
}

var _last_pulse_msec := 0


func pulse(feedback: Feedback) -> void:
	if not bool(SaveManager.get_setting("vibration_enabled", true)):
		return
	var now := Time.get_ticks_msec()
	if now - _last_pulse_msec < 12:
		return
	_last_pulse_msec = now
	var strength := clampf(float(SaveManager.get_setting("haptic_strength", 1.0)), 0.0, 1.0)
	if strength <= 0.01:
		return
	var duration := maxi(1, roundi(float(DURATIONS.get(feedback, 20)) * lerpf(0.65, 1.0, strength)))
	var amplitude := clampf(float(AMPLITUDES.get(feedback, 0.35)) * strength, 0.0, 1.0)
	Input.vibrate_handheld(duration, amplitude)


func merge_for_tier(tier: int) -> void:
	pulse(Feedback.BIG_MERGE if tier >= Enums.FruitTier.ORANGE else Feedback.MERGE)
