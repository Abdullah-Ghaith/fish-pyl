class_name PowerMeter extends Node2D
## A sweeping power meter. The marker runs back and forth along the track and
## the player stops it; the closer to the sweet spot, the higher the score out
## of 100.

signal started
signal locked_in(score: float, t: float, perfect: bool)
signal cancelled

@export_group("Nodes")
@export var tracker: Node2D
@export var track_start: Node2D
@export var track_end: Node2D
## Set both and they replace sweet_spot / sweet_band below.
@export var sweet_start: Node2D
@export var sweet_end: Node2D


@export_group("Sweep")
## Seconds for one round trip. Lower is harder.
@export var sweep_time: float = 1.2
## Begin at a random phase, so the meter can't be beaten by tapping to a count.
@export var random_start: bool = true
@export var hide_when_idle: bool = true

@export_group("Scoring")
@export_range(0.0, 1.0, 0.01) var sweet_spot: float = 0.5
@export_range(0.0, 0.95, 0.01) var sweet_band: float = 0.06
## Falloff outside the band. 1 = linear, higher punishes misses harder.
@export_range(0.1, 5.0, 0.05) var sharpness: float = 1.6
## Overrides sharpness. Maps closeness (0 at the ends, 1 at the sweet spot) to
## score.
@export var power_curve: Curve

## Runtime upgrade hooks.
var sweep_time_multiplier: float = 1.0
var sweet_band_bonus: float = 0.0

var is_running: bool = false
var progress: float = 0.0

var _elapsed: float = 0.0


func _ready() -> void:
	set_process(false)
	_apply_tracker()
	if hide_when_idle:
		hide()


func start() -> void:
	is_running = true
	_elapsed = randf() * get_sweep_time() if random_start else 0.0
	_update_progress()
	_apply_tracker()
	show()
	set_process(true)
	started.emit()


func stop() -> float:
	if not is_running:
		return 0.0
	is_running = false
	set_process(false)
	var result: float = score_at(progress)
	locked_in.emit(result, progress, is_perfect(progress))
	if hide_when_idle:
		hide()
	return result


func cancel() -> void:
	if not is_running:
		return
	is_running = false
	set_process(false)
	if hide_when_idle:
		hide()
	cancelled.emit()


# --- track -------------------------------------------------------------------

func track_a() -> Vector2:
	if is_instance_valid(track_start):
		return to_local(track_start.global_position)
	return Vector2.ZERO


func track_b() -> Vector2:
	if is_instance_valid(track_end):
		return to_local(track_end.global_position)
	return Vector2.ZERO


func track_point(t: float) -> Vector2:
	return track_a().lerp(track_b(), clampf(t, 0.0, 1.0))


## Where a local-space point falls along the track, 0..1. Off-axis markers are
## projected onto it, so they don't have to sit exactly on the line.
func t_of(local_point: Vector2) -> float:
	var a: Vector2 = track_a()
	var ab: Vector2 = track_b() - a
	if is_zero_approx(ab.length_squared()):
		return 0.0
	return clampf((local_point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)


func t_of_node(n: Node2D) -> float:
	return t_of(to_local(n.global_position))


# --- scoring -----------------------------------------------------------------

func get_sweep_time() -> float:
	return maxf(0.05, sweep_time * sweep_time_multiplier)


func get_sweet_spot() -> float:
	if _has_sweet_nodes():
		return (t_of_node(sweet_start) + t_of_node(sweet_end)) * 0.5
	return clampf(sweet_spot, 0.0, 1.0)


func get_sweet_band() -> float:
	var band: float = sweet_band
	if _has_sweet_nodes():
		band = absf(t_of_node(sweet_end) - t_of_node(sweet_start)) * 0.5 / _reach()
	return clampf(band + sweet_band_bonus, 0.0, 0.95)


## 0 at the sweet spot, 1 at the far end.
func distance_at(t: float) -> float:
	return clampf(absf(clampf(t, 0.0, 1.0) - get_sweet_spot()) / _reach(), 0.0, 1.0)


func is_perfect(t: float) -> bool:
	return distance_at(t) <= get_sweet_band()


func score_at(t: float) -> float:
	var band: float = get_sweet_band()
	var d: float = distance_at(t)
	var miss: float = 0.0 if d <= band else (d - band) / maxf(0.001, 1.0 - band)
	var closeness: float = clampf(1.0 - miss, 0.0, 1.0)
	var q: float = power_curve.sample(closeness) if power_curve != null \
			else pow(closeness, sharpness)
	return clampf(q, 0.0, 1.0) * 100.0


func map_score(score: float, from_value: float, to_value: float) -> float:
	return lerpf(from_value, to_value, clampf(score, 0.0, 100.0) / 100.0)


# --- internals ---------------------------------------------------------------

func _has_sweet_nodes() -> bool:
	return is_instance_valid(sweet_start) and is_instance_valid(sweet_end)


func _reach() -> float:
	var s: float = get_sweet_spot()
	return maxf(maxf(s, 1.0 - s), 0.001)


func _process(delta: float) -> void:
	_elapsed += delta
	_update_progress()
	_apply_tracker()


func _update_progress() -> void:
	progress = pingpong(_elapsed * 2.0 / get_sweep_time(), 1.0)


func _apply_tracker() -> void:
	if is_instance_valid(tracker):
		tracker.position = track_point(progress)
