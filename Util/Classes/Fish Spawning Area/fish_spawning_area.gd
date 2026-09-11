@tool
class_name FishSpawnArea extends Node2D
## A horizontal band of water that spawns fish. Bands chain vertically: each
## one starts where its previous_area ends, so you only set a depth per band
## and the stack resolves itself.

@export var fish_scene: PackedScene
@export var spawnable_fish: Array[FishData] = []

@export_group("Band")
## How far down this band extends from its top edge, in pixels.
@export var depth: float = 0.0:
	set(v):
		depth = v
		queue_redraw()
## How wide the band is, centred on this node's x.
@export var width: float = 512.0:
	set(v):
		width = v
		queue_redraw()
## The band directly above this one. Its bottom edge becomes this band's top
## edge. Leave empty for the topmost band, which starts at this node's own y.
@export var previous_area: FishSpawnArea = null:
	set(v):
		previous_area = v
		queue_redraw()
## Fish spawn and despawn this far outside the band's horizontal edges, so they
## swim in rather than popping into view.
@export var edge_margin: float = 48.0

@export_group("Spawning")
## Fish per second. Upgrades scale this via spawn_rate_multiplier.
@export var spawn_rate: float = 0.0
## Hard population cap for this band.
@export var max_fish: int = 12
## Pull weight per rarity, indexed to match FishData.Rarity:
## [None, Common, Rare, Bepic, Legendary]. Higher = more common.
@export var rarity_weights: PackedFloat32Array = [0.0, 100.0, 25.0, 6.0, 1.0]
## Never spawn twice inside this many seconds, whatever the rate says. The
## backstop against a burst.
@export var min_spawn_gap: float = 0.35
## Randomness on the gap between spawns, as a fraction of it. 0 = metronomic,
## which reads as artificial; 0.4 = each gap is 60-140% of the average.
@export_range(0.0, 0.9, 0.05) var interval_jitter: float = 0.4
## Refuse to spawn a fish within this many pixels of one already in the band.
## Set it to roughly a fish and a half.
@export var min_spawn_distance: float = 90.0
## How many depths to try before giving up on a spawn. Giving up is fine - it
## just means the band is busy right now.
@export_range(1, 20) var spawn_attempts: int = 6
## Prints this band's real density numbers on startup: spawn_rate on its own
## says nothing, what matters is speed x interval against the size of a fish.
@export var report_density: bool = true
## Shifts the whole curve toward the rare end. Each tier above Common gets
## multiplied by luck one more time than the tier below it, so a single number
## makes rare fish rarer or commoner in a smooth, monotonic way.
## 1.0 = the weights above verbatim.
@export var luck: float = 1.0
## Ignore the clock in this band - every fish keeps its noon odds all night.
## For a cave, an aquarium, or anywhere the sun does not reach.
@export var ignore_time_of_day: bool = false

## Runtime upgrade hooks - set these from your upgrade system, not the inspector.
var spawn_rate_multiplier: float = 1.0
var luck_bonus: float = 0.0

var _next_spawn: float = 0.0
var _fish: Array[Fish] = []
var _resolving: bool = false   # cycle guard for the previous_area chain
## The TimeOfDay autoload, looked up once. Null is a supported state: without
## the autoload the band falls back to its plain rarity weights, so the game
## still runs if the cycle is not installed.
var _clock: Node = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if depth == 0.0:
		printerr("%s: FishSpawnArea failed to set depth" % name)
	if spawn_rate == 0.0:
		printerr("%s: FishSpawnArea failed to set spawn_rate" % name)
	if fish_scene == null:
		printerr("%s: FishSpawnArea failed to set fish_scene" % name)
	if spawnable_fish.is_empty():
		printerr("%s: FishSpawnArea has no spawnable_fish" % name)

	if not ignore_time_of_day:
		_clock = get_node_or_null(^"/root/TimeOfDay")

	# Validate the species list once here rather than per-instance at spawn time.
	for f in spawnable_fish:
		if f == null:
			printerr("%s: FishSpawnArea has an empty slot in spawnable_fish" % name)
		else:
			f.validate(name)

	# Skill upgrades feed the two runtime hooks above. get_spawn_rate() and
	# get_luck() read them live, so re-applying on change is the whole story -
	# a skill bought mid-cast affects the very next spawn.
	if Progression.stats != null:
		Progression.stats.changed.connect(_apply_upgrades)
		_apply_upgrades()

	_next_spawn = _roll_interval()
	if report_density:
		_report_density()


func _apply_upgrades() -> void:
	# Base 1.0 so both mod modes work: ADD 0.5 and MULTIPLY 1.5 both land as
	# "half again as many fish".
	spawn_rate_multiplier = Progression.stat(SkillStats.SPAWN_RATE, 1.0)
	luck_bonus = Progression.stats.bonus(SkillStats.LUCK)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	for i in range(_fish.size() - 1, -1, -1):
		var f: Fish = _fish[i]
		if not is_instance_valid(f) or f.get_parent() != self:
			_fish.remove_at(i)

	# A countdown rather than an accumulator, and re-rolled whether or not the
	# spawn actually happens. The old accumulator kept banking credit while the
	# band sat at max_fish, then the whole backlog fired in one frame the moment
	# a slot freed - every one of those fish landing on the same entry point.
	# That was the clumping.
	_next_spawn -= delta
	if _next_spawn > 0.0:
		return
	_next_spawn = _roll_interval()
	if _fish.size() >= max_fish:
		return
	_spawn_one()


## Seconds until the next attempt: the average gap, jittered, never below
## min_spawn_gap. Re-read every time, so a mid-game upgrade lands immediately.
func _roll_interval() -> float:
	var rate: float = get_spawn_rate()
	if rate <= 0.0:
		return 1.0
	var gap: float = 1.0 / rate
	return maxf(min_spawn_gap,
			gap * randf_range(1.0 - interval_jitter, 1.0 + interval_jitter))


## What actually decides how crowded this band looks. Spacing is speed x
## interval - compare it to the width of a fish sprite - and the steady-state
## population is the crossing time divided by the interval, which is what
## max_fish has to be above or the cap does the deciding instead of the rate.
func _report_density() -> void:
	var rate: float = get_spawn_rate()
	if rate <= 0.0 or spawnable_fish.is_empty():
		return
	var slowest: float = INF
	for f in spawnable_fish:
		if f != null and f.speed > 0.0:
			slowest = minf(slowest, f.speed)
	if is_inf(slowest):
		return
	var span: float = width + edge_margin * 2.0
	var gap: float = 1.0 / rate
	print("%s: a fish every %.1fs, ~%.0fpx apart, %.0fs to cross, ~%.1f on screen (cap %d)"
			% [name, gap, slowest * gap, span / slowest, (span / slowest) / gap, max_fish])


# --- band geometry -----------------------------------------------------------

## Global y of this band's top edge - the bottom of the band above, or this
## node's own y if it's the topmost.
func get_top_y() -> float:
	if not is_instance_valid(previous_area):
		return global_position.y
	if _resolving:
		printerr("%s: previous_area chain forms a cycle" % name)
		return global_position.y
	_resolving = true
	var y: float = previous_area.get_bottom_y()
	_resolving = false
	return y


func get_bottom_y() -> float:
	return get_top_y() + depth


# --- spawning ----------------------------------------------------------------

func get_spawn_rate() -> float:
	return maxf(0.0, spawn_rate * spawn_rate_multiplier)


func get_luck() -> float:
	return maxf(0.01, luck + luck_bonus)


## This species' time-of-day multiplier right now. 1.0 whenever the clock is
## missing or the band opts out, so this is always safe to multiply in.
func get_time_weight(fish: FishData) -> float:
	if fish == null or _clock == null:
		return 1.0
	# A species with four identical weights is constant across the day, but the
	# constant still counts - blending it would give the same answer the long
	# way round, so take it directly.
	if fish.is_time_agnostic():
		return fish.dawn_weight
	return _clock.blend(fish.phase_weights())


## Pull weight for one species. Rarity tier sets the base; luck raises each tier
## above Common by one more power of luck than the tier below it, and the clock
## scales the result - which is why a night fish competes against the same
## rarity curve rather than sitting outside it.
func get_weight(fish: FishData) -> float:
	if fish == null:
		return 0.0
	var tier: int = int(fish.rarity)
	if tier <= 0 or tier >= rarity_weights.size():
		return 0.0
	return rarity_weights[tier] * pow(get_luck(), tier - 1) \
			* fish.weight_multiplier * get_time_weight(fish)


func pick_fish() -> FishData:
	var total: float = 0.0
	for f in spawnable_fish:
		total += get_weight(f)
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for f in spawnable_fish:
		roll -= get_weight(f)
		if roll <= 0.0:
			return f
	return spawnable_fish[spawnable_fish.size() - 1]


func _spawn_one() -> void:
	if fish_scene == null:
		return
	var data: FishData = pick_fish()
	if data == null:
		return

	var half: float = width * 0.5
	var swims_right: bool = randf() < 0.5
	var start_x: float = global_position.x - half - edge_margin
	var end_x: float = global_position.x + half + edge_margin
	if not swims_right:
		var t: float = start_x
		start_x = end_x
		end_x = t

	# Try a few depths and take the first that is not already occupied, rather
	# than dropping a fish wherever the die lands. Giving up when none is clear
	# is deliberate: it thins the band out exactly when it is busiest.
	var y: float = NAN
	for _i in spawn_attempts:
		var candidate: float = randf_range(get_top_y(), get_bottom_y())
		if _entry_is_clear(Vector2(start_x, candidate)):
			y = candidate
			break
	if is_nan(y):
		return

	var fish: Fish = fish_scene.instantiate()
	fish.setup(data, 1.0 if swims_right else -1.0, Vector2(start_x, y), end_x)
	add_child(fish)
	_fish.append(fish)


func _entry_is_clear(at: Vector2) -> bool:
	if min_spawn_distance <= 0.0:
		return true
	for f in _fish:
		if is_instance_valid(f) and not f.is_caught \
				and f.global_position.distance_to(at) < min_spawn_distance:
			return false
	return true


# --- editor visualisation ----------------------------------------------------

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var top: float = get_top_y()
	var rect := Rect2(
		to_local(Vector2(global_position.x - width * 0.5, top)),
		Vector2(width, depth)
	)
	draw_rect(rect, Color(0.2, 0.7, 1.0, 0.12))
	draw_rect(rect, Color(0.2, 0.7, 1.0, 0.6), false, 1.0)
