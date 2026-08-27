class_name FishingLine extends Node2D
## Fishing line that goes slack above the water once the hook has splashed down.
##
## The rope is TWO independent verlet ropes that share one Line2D:
##
##   AIR    rod tip -> water entry point.
##          While the hook is in flight this section spans rod tip -> hook, and
##          its rest length is *paid out* as the hook flies away (it only ever
##          grows - line never gets sucked back onto the reel). The moment the
##          hook touches the water, the far end is re-pinned to the entry point
##          permanently and the rest length is frozen with a little extra slack
##          added. From then on this section neither knows nor cares where the
##          hook is: it sags, settles onto the water surface, and stays put.
##
##   WATER  water entry point -> hook.
##          Born at the entry point with zero length on splashdown, then grows
##          as the hook sinks - line being dragged off the reel down through the
##          entry point. Weak gravity + heavy damping, so it bows gently behind
##          the hook instead of snapping ruler-straight.
##
## Nothing here moves the hook. The hook flies and sinks under its own script;
## this node only observes it.

enum State { IDLE, FLIGHT, SUNK }

@export_group("Nodes")
@export var line: Line2D
@export var rod_tip: Node2D

@export_group("Above Water")
## Point count for the rod-tip -> entry-point section.
@export_range(4, 80) var air_points: int = 22
## Rest length while casting, as a multiple of the rod-tip -> hook distance.
## Just above 1.0 = the line trails the hook fairly taut. Raise for a loopier cast.
@export var cast_slack: float = 1.012
## Rest length after splashdown, as a multiple of the rod-tip -> entry distance.
## This is the knob for "how much slack is left lying on the water".
@export var entry_slack: float = 1.18
## How fast that extra slack is fed in after splashdown (1/seconds).
## Low = the line visibly relaxes over a moment instead of popping loose.
@export var slack_ramp: float = 2.5
@export var air_gravity: float = 900.0
@export_range(0.8, 1.0) var air_damping: float = 0.985
## Slack line floats: how far below the surface an air-section point may sink.
@export var float_depth: float = 2.0
## Fraction of sideways speed a point keeps once it's touching the water.
@export_range(0.0, 1.0) var surface_glide: float = 0.55

@export_group("Below Water")
## Point count for the entry-point -> hook section.
@export_range(4, 80) var water_points: int = 18
## Rest length as a multiple of entry -> hook distance. Keep this very near 1.0:
## the bow you see comes from the section lagging behind the hook, and real slack
## down here just kinks. Above ~1.01 it starts to look creased.
@export var water_slack: float = 1.0
## Much weaker than air gravity - the line is near-neutrally buoyant in water.
@export var water_gravity: float = 140.0
@export_range(0.5, 1.0) var water_damping: float = 0.88

@export_group("Solver")
@export_range(1, 32) var iterations: int = 14

var state: State = State.IDLE
var hook: Node2D = null
## World position where the hook broke the surface. The air section's far end is
## pinned here for good once we're in State.SUNK.
var entry_point: Vector2 = Vector2.ZERO
var surface_y: float = 0.0

var _air: Array[Vector2] = []
var _air_prev: Array[Vector2] = []
var _air_len: float = 0.0
var _air_len_target: float = 0.0

var _water: Array[Vector2] = []
var _water_prev: Array[Vector2] = []
var _water_len: float = 0.0


func _ready() -> void:
	# Run after the hook has moved this frame, so we pin to its current position.
	# (process_priority is for _process only; physics needs its own.)
	process_physics_priority = 100
	if line:
		# Points are written in global space; don't let the rod's rotation smear them.
		line.top_level = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		line.visible = false


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	if not is_instance_valid(hook):
		detach_hook()
		return

	var tip: Vector2 = rod_tip.global_position if rod_tip else global_position
	var hook_pos: Vector2 = hook.global_position
	var far_end: Vector2

	if state == State.FLIGHT:
		# Pay line off the reel to keep up with the hook. Monotonic on purpose.
		_air_len = maxf(_air_len, tip.distance_to(hook_pos) * cast_slack)
		far_end = hook_pos
	else:
		# Feed in the leftover slack, then hold. The hook is irrelevant up here.
		_air_len = lerpf(_air_len, _air_len_target, minf(1.0, slack_ramp * delta))
		far_end = entry_point

	_integrate(_air, _air_prev, Vector2(0.0, air_gravity), air_damping, delta)
	# Alternate solving and surface contact so the slack settles onto the water
	# instead of solving its way through it.
	var half := maxi(1, iterations / 2)
	for _pass in 2:
		_solve(_air, _air_prev, _air_len, tip, far_end, half)
		if state == State.SUNK:
			_float_on_surface()

	if state == State.SUNK:
		# The sinking hook drags more line down through the entry point.
		_water_len = maxf(_water_len, entry_point.distance_to(hook_pos) * water_slack)
		_integrate(_water, _water_prev, Vector2(0.0, water_gravity), water_damping, delta)
		_solve(_water, _water_prev, _water_len, entry_point, hook_pos, iterations)

	_redraw()


# --- public API ---------------------------------------------------------------

## Call right after spawning a new hook. Collapses the rope onto the rod tip so
## it doesn't whip across the screen from wherever the last hook was.
func attach_hook(new_hook: Node2D) -> void:
	hook = new_hook
	var tip: Vector2 = rod_tip.global_position if rod_tip else global_position

	_air = _filled(air_points, tip)
	_air_prev = _filled(air_points, tip)
	_air_len = 0.0
	_air_len_target = 0.0

	_water.clear()
	_water_prev.clear()
	_water_len = 0.0

	state = State.FLIGHT
	if line:
		line.visible = true
	_redraw()


func detach_hook() -> void:
	hook = null
	state = State.IDLE
	if line:
		line.visible = false
		line.clear_points()


## Connect the hook's splashdown signal here. `water_surface_y` is the global y of
## the water surface; pass NAN (or nothing) to just use the hook's own height.
func _on_hook_entered_water(water_surface_y: float = NAN) -> void:
	if state != State.FLIGHT or not is_instance_valid(hook):
		return

	surface_y = water_surface_y if is_finite(water_surface_y) else hook.global_position.y
	# Pin at where the hook crossed the surface, not where it was when the area
	# happened to report the overlap - keeps the plunge point on the waterline.
	entry_point = Vector2(hook.global_position.x, surface_y)

	var tip: Vector2 = rod_tip.global_position if rod_tip else global_position
	_air_len_target = maxf(_air_len, tip.distance_to(entry_point) * entry_slack)

	_water = _filled(water_points, entry_point)
	_water_prev = _filled(water_points, entry_point)
	_water_len = 0.0

	state = State.SUNK


# --- simulation --------------------------------------------------------------

func _filled(n: int, value: Vector2) -> Array[Vector2]:
	var a: Array[Vector2] = []
	a.resize(n)
	a.fill(value)
	return a


func _integrate(p: Array[Vector2], prev: Array[Vector2], g: Vector2,
		damping: float, delta: float) -> void:
	var accel := g * delta * delta
	for i in p.size():
		var cur := p[i]
		var vel := (cur - prev[i]) * damping
		prev[i] = cur
		p[i] = cur + vel + accel


## Inextensible-rope constraint with both ends pinned. Pinned points have zero
## inverse mass, so their neighbour absorbs the whole correction - that's what
## keeps the entry point rock steady while the rope hangs off it.
func _solve(p: Array[Vector2], prev: Array[Vector2], rest_len: float,
		pin_a: Vector2, pin_b: Vector2, iters: int) -> void:
	var n := p.size()
	if n < 2:
		return
	var seg := rest_len / float(n - 1)
	var last := n - 1

	for _iter in iters:
		p[0] = pin_a
		p[last] = pin_b
		for i in last:
			var a := p[i]
			var b := p[i + 1]
			var diff := b - a
			var dist := diff.length()
			if dist < 0.0001:
				continue
			var corr := diff * (0.5 * (dist - seg) / dist)
			var free_a := i != 0
			var free_b := i + 1 != last
			if free_a and free_b:
				p[i] = a + corr
				p[i + 1] = b - corr
			elif free_a:
				p[i] = a + corr * 2.0
			elif free_b:
				p[i + 1] = b - corr * 2.0

	p[0] = pin_a
	p[last] = pin_b
	# Pins carry no velocity into the next frame.
	prev[0] = pin_a
	prev[last] = pin_b


## Slack line can't sink under its own weight - it lies on the surface. Clamping
## here (rather than adding buoyancy) keeps it visually glued to the waterline.
func _float_on_surface() -> void:
	var limit := surface_y + float_depth
	for i in range(1, _air.size() - 1):
		var pt := _air[i]
		if pt.y <= limit:
			continue
		var vx := (pt.x - _air_prev[i].x) * surface_glide
		_air[i] = Vector2(pt.x, limit)
		_air_prev[i] = Vector2(pt.x - vx, limit)


func _redraw() -> void:
	if not line:
		return
	# _water[0] is the same point as _air[-1], so skip it.
	var total := _air.size() + maxi(0, _water.size() - 1)
	var pts := PackedVector2Array()
	pts.resize(total)
	for i in _air.size():
		pts[i] = _air[i]
	for i in range(1, _water.size()):
		pts[_air.size() + i - 1] = _water[i]
	line.points = pts
