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
## When the hook starts coming home the two sections merge back into a single
## rope that gets reeled in (see begin_return).
##
## Nothing here moves the hook. The hook flies, sinks and returns under its own
## script; this node only observes it.
##
## Wiring:
##   1. Add as a child of the rod / shooter, set `rod_tip` to the tip marker.
##   2. On cast:  fishing_line.attach_hook(hook_instance)
##   3. Connect the hook's signals:
##        entered_water     -> _on_hook_entered_water
##        started_returning -> begin_return
##   4. On reel-in / catch / despawn:  fishing_line.detach_hook()

enum FishingLineState { IDLE, FLIGHT, SUNK, RETURN }

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
## How deep the surface still "grips" line and floats it back up. Only points
## within this band get floated - anything deeper is line on its way down to the
## hook and must be left alone. Keep it a few segment-lengths wide: too small and
## line that dips through in one frame escapes, too large and it hauls the
## submerged run up to the waterline.
@export var surface_grip: float = 12.0
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
## Line pays out instantly when the hook swims away from the entry point, but
## slack is only taken up this fast (px/s) when it swims back toward it.
## Without this, steering the hook homeward would leave a bunched-up underwater
## section, because paid-out line has nowhere to go.
@export var water_reel_speed: float = 60.0

@export_group("Coming Home")
## How fast leftover slack is wound back onto the reel (px/s) once the hook heads
## home. This is a rate on the *slack*, not on the rope's total length - see the
## FishingLineState.RETURN branch for why that distinction is the whole ballgame.
@export var reel_speed: float = 220.0
## Rope length while being hauled in, as a multiple of the rod-tip -> hook
## distance. 1.0 is a dead-straight line; a little over gives it some weight.
@export var return_taut: float = 1.01

@export_group("Solver")
@export_range(1, 32) var iterations: int = 14
## Successive over-relaxation. Each constraint overshoots by this factor, which
## is what lets a length error travel the length of the rope in a handful of
## iterations instead of a few hundred. Plain Gauss-Seidel (1.0) diffuses a
## global error in O(n^2) iterations, so the ~39-point merged rope of the return
## phase sat ~11% overstretched forever and bellied out behind the hook.
##
## More iterations barely help; this does. There is a hard stability cliff just
## above 1.9 - at 1.95 the rope explodes - so do not raise it past the range.
@export_range(1.0, 1.9) var relaxation: float = 1.8

var state: FishingLineState = FishingLineState.IDLE
var hook: Node2D = null
## World position where the hook broke the surface. The air section's far end is
## pinned here for good once we're in FishingLineState.SUNK.
var entry_point: Vector2 = Vector2.ZERO
var surface_y: float = 0.0

var _air: Array[Vector2] = []
var _air_prev: Array[Vector2] = []
var _air_len: float = 0.0
var _air_len_target: float = 0.0

var _water: Array[Vector2] = []
var _water_prev: Array[Vector2] = []
var _water_len: float = 0.0

## Rope length in hand beyond taut, during FishingLineState.RETURN. Monotonically decreasing.
var _return_slack: float = 0.0


func _ready() -> void:
	# Run after the hook has moved this frame, so we pin to its current position.
	# (process_priority is for _process only; physics needs its own.)
	process_physics_priority = 100
	if line:
		# Points are written in global space; don't let the rod's rotation smear them.
		line.top_level = true
		line.visible = false
		# Appearance (texture, width, joints, caps, filter) is deliberately left to
		# the scene so it can be tuned in the inspector - the script no longer
		# overrides it.


func _physics_process(delta: float) -> void:
	if state == FishingLineState.IDLE:
		return
	if not is_instance_valid(hook):
		detach_hook()
		return

	var tip: Vector2 = rod_tip.global_position if rod_tip else global_position
	var hook_pos: Vector2 = hook.global_position
	var far_end: Vector2

	match state:
		FishingLineState.FLIGHT:
			# Pay line off the reel to keep up with the hook. Monotonic on purpose.
			_air_len = maxf(_air_len, tip.distance_to(hook_pos) * cast_slack)
			far_end = hook_pos
		FishingLineState.SUNK:
			# Feed in the leftover slack, then hold. The hook is irrelevant up here.
			_air_len = lerpf(_air_len, _air_len_target, minf(1.0, slack_ramp * delta))
			far_end = entry_point
		FishingLineState.RETURN:
			# One rope again. Its length is the straight-line distance plus a slack
			# allowance that only ever shrinks - so the hook can never outrun the
			# reel, however fast it travels home.
			#
			# Winding the total length in at a fixed px/s does NOT work: the hook
			# closes on the rod at its own speed, and the moment that exceeds
			# reel_speed the rope gains slack faster than the reel removes it. The
			# line bellies out and the hook reads as drifting home on its own
			# rather than being hauled.
			_return_slack = maxf(0.0, _return_slack - reel_speed * delta)
			_air_len = tip.distance_to(hook_pos) * return_taut + _return_slack
			far_end = hook_pos

	_integrate(_air, _air_prev, Vector2(0.0, air_gravity), air_damping, delta)
	# Alternate solving and surface contact so the slack settles onto the water
	# instead of solving its way through it.
	var half := maxi(1, iterations / 2)
	for _pass in 2:
		_solve(_air, _air_prev, _air_len, tip, far_end, half)
		if state != FishingLineState.FLIGHT:
			_float_on_surface()

	if state == FishingLineState.SUNK:
		# The hook drags line down through the entry point as it sinks and swims.
		# Pays out freely; slack is only taken back up at water_reel_speed.
		var want := entry_point.distance_to(hook_pos) * water_slack
		if want > _water_len:
			_water_len = want
		else:
			_water_len = move_toward(_water_len, want, water_reel_speed * delta)
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

	state = FishingLineState.FLIGHT
	if line:
		line.visible = true
	_redraw()


func detach_hook() -> void:
	hook = null
	state = FishingLineState.IDLE
	if line:
		line.visible = false
		line.clear_points()


## Connect the hook's splashdown signal here. `water_surface_y` is the global y of
## the water surface; pass NAN (or nothing) to just use the hook's own height.
func _on_hook_entered_water(water_surface_y: float = NAN) -> void:
	if state != FishingLineState.FLIGHT or not is_instance_valid(hook):
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

	state = FishingLineState.SUNK


## Call when the hook starts heading home (connect the hook's started_returning
## signal). The two sections merge back into one rope and it starts winding in.
##
## The merged rope traces exactly the polyline already on screen, so the shape
## doesn't change - only the bookkeeping does: one rest length instead of two,
## and the entry point stops being an anchor, which is what finally lets the
## slack lift off the water.
##
## The resample matters. Merging two sections that had different segment lengths
## (13 px above water, 29 px below, in the default setup) into one rope with a
## single uniform segment length makes the solver redistribute every point along
## the curve on the first frame - a visible ~40 px snap. Resampling to even
## arc-length spacing up front puts the points where that solve already wants
## them, so there's nothing to redistribute.
func begin_return() -> void:
	if state != FishingLineState.SUNK:
		return
	var n := _air.size() + maxi(0, _water.size() - 1)
	var merged := _resample(_combined(_air, _water), n)
	_air_prev = _resample(_combined(_air_prev, _water_prev), n)
	_air = merged
	_air_len = _arc_length(merged)

	# Everything the rope has beyond taut is slack to be wound in. Derived so the
	# first RETURN frame reproduces _air_len exactly - no jump in rope length.
	var tip: Vector2 = rod_tip.global_position if rod_tip else global_position
	var straight := tip.distance_to(merged[merged.size() - 1])
	_return_slack = maxf(0.0, _air_len - straight * return_taut)

	_water.clear()
	_water_prev.clear()
	_water_len = 0.0

	state = FishingLineState.RETURN


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
			var corr := diff * (0.5 * relaxation * (dist - seg) / dist)
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
##
## Only line inside the surface_grip band is floated. During FishingLineState.RETURN the
## whole rope lives in `_air`, submerged run included, and clamping all of it
## would haul the descent to the hook straight up to the waterline - which is
## exactly what made the merge snap ~40 px before this guard existed.
func _float_on_surface() -> void:
	var limit := surface_y + float_depth
	var deepest := limit + surface_grip
	for i in range(1, _air.size() - 1):
		var pt := _air[i]
		if pt.y <= limit or pt.y > deepest:
			continue
		var vx := (pt.x - _air_prev[i].x) * surface_glide
		_air[i] = Vector2(pt.x, limit)
		_air_prev[i] = Vector2(pt.x - vx, limit)


## Air section followed by the water section. b[0] is the same point as a[-1]
## (both are the entry point), so it's dropped.
func _combined(a: Array[Vector2], b: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.resize(a.size() + maxi(0, b.size() - 1))
	for i in a.size():
		out[i] = a[i]
	for i in range(1, b.size()):
		out[a.size() + i - 1] = b[i]
	return out


## Re-places `n` points at equal arc-length intervals along `p`, tracing the same
## shape. Used by begin_return; see the note there for why it's needed.
func _resample(p: Array[Vector2], n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if n < 2:
		return out
	out.resize(n)
	if p.is_empty():
		return out
	if p.size() < 2:
		out.fill(p[0])
		return out

	var total := _arc_length(p)
	if total < 0.0001:
		out.fill(p[0])
		return out

	var step := total / float(n - 1)
	out[0] = p[0]
	out[n - 1] = p[p.size() - 1]

	var seg := 0
	var walked := 0.0   # arc length of everything before segment `seg`
	for k in range(1, n - 1):
		var target := step * float(k)
		while seg < p.size() - 2:
			var seg_len := p[seg].distance_to(p[seg + 1])
			if walked + seg_len >= target:
				break
			walked += seg_len
			seg += 1
		var a := p[seg]
		var b := p[seg + 1]
		var here := a.distance_to(b)
		var t := 0.0
		if here >= 0.0001:
			t = clampf((target - walked) / here, 0.0, 1.0)
		out[k] = a.lerp(b, t)
	return out


func _arc_length(p: Array[Vector2]) -> float:
	var total := 0.0
	for i in p.size() - 1:
		total += p[i].distance_to(p[i + 1])
	return total


func _redraw() -> void:
	if not line:
		return
	var all := _combined(_air, _water)
	var pts := PackedVector2Array()
	pts.resize(all.size())
	for i in all.size():
		pts[i] = all[i]
	line.points = pts
