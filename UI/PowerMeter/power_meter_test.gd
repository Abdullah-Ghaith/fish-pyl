extends Node2D
## Throwaway harness for feeling out the power meter before wiring it to a cast.
##
## New Scene -> Node2D root -> attach this -> instance PowerMeter.tscn as a
## child -> F6. Space starts and stops, Esc cancels. Tune sweep_time,
## sharpness and the Sweet markers while watching the hit rate.

@export var meter: PowerMeter

var _readout: Label
var _attempts: int = 0
var _perfects: int = 0
var _best: float = 0.0
var _total: float = 0.0
var _last: String = "-"


func _ready() -> void:
	if meter == null:
		for c in get_children():
			if c is PowerMeter:
				meter = c
				break
	if meter == null:
		push_error("PowerMeterTest: no PowerMeter child found.")
		return

	meter.locked_in.connect(_on_locked)
	meter.cancelled.connect( func() -> void: _last = "cancelled")

	var layer := CanvasLayer.new()
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(16, 16)
	layer.add_child(_readout)


func _unhandled_input(event: InputEvent) -> void:
	if meter == null:
		return
	if event.is_action_pressed("ui_accept"):
		if meter.is_running:
			meter.stop()
		else:
			meter.start()
	elif event.is_action_pressed("ui_cancel"):
		meter.cancel()


func _process(_delta: float) -> void:
	if meter == null or _readout == null:
		return
	var live: float = meter.score_at(meter.progress)
	var average: float = _total / float(_attempts) if _attempts > 0 else 0.0
	_readout.text = "\n".join([
		"space = start / stop      esc = cancel",
		"",
		"running   %s" % ("yes" if meter.is_running else "no"),
		"t         %.3f" % meter.progress,
		"live      %.1f%s" % [live, "  PERFECT" if meter.is_perfect(meter.progress) else ""],
		"",
		"sweet spot %.3f   band %.3f   sweep %.2fs" % [
				meter.get_sweet_spot(), meter.get_sweet_band(), meter.get_sweep_time()],
		"",
		"last      %s" % _last,
		"attempts  %d" % _attempts,
		"perfect   %d  (%.0f%%)" % [_perfects,
				100.0 * float(_perfects) / float(maxi(_attempts, 1))],
		"best      %.1f" % _best,
		"average   %.1f" % average,
	])


func _on_locked(score: float, t: float, perfect: bool) -> void:
	_attempts += 1
	_total += score
	_best = maxf(_best, score)
	if perfect:
		_perfects += 1
	_last = "%.1f at t=%.3f%s" % [score, t, "  PERFECT" if perfect else ""]
