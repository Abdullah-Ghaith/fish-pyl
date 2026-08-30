class_name Hook extends CharacterBody2D
## Cast -> sink -> the player swims it around -> the dive timer runs out, or a
## fish is caught -> it comes home. The fishing line only listens to the signals
## below; it never drives the hook.

enum HookState { FLIGHT, SUBMERGED, RISING, REELING }

@export_group("Cast")
@export var speed: float = 1200.0
@export var gravity: float = 1000.0
@export var bounce_factor := 0.6

@export_group("In Water")
## Fraction of speed kept on impact with the surface.
@export var splash_slowdown: float = 0.45
## Much weaker than air gravity, so the hook sinks slowly and readably.
@export var sink_gravity: float = 140.0
## Per-second drag. Terminal sink rate is roughly sink_gravity / water_drag.
@export var water_drag: float = 2.2
## Seconds underwater before the hook starts coming back up.
@export var dive_time: float = 4.0

@export_group("Handling")
## THE upgrade coefficient. Scales the steering force and the sideways speed cap
## together, so handling = 2.0 really is "twice the handling".
@export var handling: float = 1.0
@export var steer_force: float = 260.0
@export var max_steer_speed: float = 80.0

@export_group("Catching")
## How many fish this cast can carry. FishingRod overwrites this at spawn time
## from its own upgradeable value, so treat the rod's copy as authoritative.
## Spacing between caught fish hanging off the hook.
@export var catch_slot_spacing: Vector2 = Vector2(0, 13)
## Sideways alternation, so a full stringer doesn't read as one column.
@export var catch_slot_stagger: float = 7.0

@export_group("Coming Home")
@export var rise_speed: float = 150.0
@export var reel_speed: float = 340.0
@export var return_ramp: float = 6.0
@export var arrive_radius: float = 6.0

@onready var catch_area: Area2D = $CatchArea

## True while a hook is submerged and steerable. The angler stops walking, so
## move_left / move_right unambiguously mean "swim the hook".
static var steering: bool = false

## Emitted when the hook breaks the surface. `surface_y` is the global y of the
## waterline (NAN when the emitter doesn't know it).
signal entered_water(surface_y: float)
## The hook is heading home - dive timer expired, or the first fish was caught.
signal started_returning
## Back at the rod tip, about to free itself. Carries the catch as data, because
## the Fish nodes are children of this hook and die with it.
signal returned(catch: Array[FishData])
## One fish landed. `total` of `room` now aboard - handy for a HUD.
signal caught_fish(fish: Fish, total: int, room: int)

var capacity: int = 1
var rod_tip: Node2D = null
var dir: Vector2 = Vector2.ZERO
var state: HookState = HookState.FLIGHT
## Counts down while submerged - read it for a HUD bar.
var dive_remaining: float = 0.0
## Live Fish nodes riding along. They are children of this hook.
var caught: Array[Fish] = []

var _surface_y: float = 0.0
var _entry_point: Vector2 = Vector2.ZERO
var _return_speed: float = 0.0


func _ready() -> void:
	velocity = dir * speed
	entered_water.connect(_on_entered_water)
	if catch_area:
		catch_area.area_entered.connect(_on_catch_area_entered)
	else:
		printerr("%s: Hook has no CatchArea child - it can't catch anything" % name)


func _exit_tree() -> void:
	# Never leave the angler frozen because a hook was freed mid-dive.
	steering = false


func _physics_process(delta: float) -> void:
	match state:
		HookState.FLIGHT:
			_fly(delta)
		HookState.SUBMERGED:
			_swim(delta)
		HookState.RISING:
			if _travel_to(_entry_point, rise_speed, delta):
				state = HookState.REELING
				_return_speed = 0.0
		HookState.REELING:
			var home: Vector2 = _entry_point
			if is_instance_valid(rod_tip):
				home = rod_tip.global_position
			if _travel_to(home, reel_speed, delta):
				returned.emit(get_catch_data())
				queue_free()


# --- phases ------------------------------------------------------------------

func _fly(delta: float) -> void:
	velocity.y += gravity * delta
	var collision := move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal()) * bounce_factor


func _swim(delta: float) -> void:
	dive_remaining = maxf(0.0, dive_remaining - delta)

	var steer := Input.get_axis("move_left", "move_right")
	# The cap limits how hard you can push, not how fast the hook may be moving -
	# otherwise the leftover cast momentum would snap to the cap on splashdown.
	var cap := max_steer_speed * handling
	if absf(velocity.x) < cap or signf(steer) != signf(velocity.x):
		velocity.x += steer * steer_force * handling * delta

	velocity.y += sink_gravity * delta
	velocity *= maxf(0.0, 1.0 - water_drag * delta)

	var collision := move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal()) * bounce_factor

	if dive_remaining <= 0.0:
		_begin_return()


func _begin_return() -> void:
	if state != HookState.SUBMERGED:
		return
	state = HookState.RISING
	steering = false
	_return_speed = 0.0
	started_returning.emit()


## Eases up to `speed_limit` and moves toward `target`. Returns true on arrival.
## Deliberately move_toward and not move_and_collide: a hook being hauled in
## shouldn't snag on the geometry it's dragged over.
func _travel_to(target: Vector2, speed_limit: float, delta: float) -> bool:
	_return_speed = lerpf(_return_speed, speed_limit, minf(1.0, return_ramp * delta))
	var before := global_position
	global_position = global_position.move_toward(target, _return_speed * delta)
	velocity = (global_position - before) / delta
	return global_position.distance_to(target) <= arrive_radius


func _on_entered_water(surface_y: float) -> void:
	if state != HookState.FLIGHT:
		return
	_surface_y = surface_y if is_finite(surface_y) else global_position.y
	_entry_point = Vector2(global_position.x, _surface_y)
	velocity *= splash_slowdown
	dive_remaining = dive_time
	state = HookState.SUBMERGED
	steering = true


# --- catching ----------------------------------------------------------------

func has_room() -> bool:
	return caught.size() < capacity


## The catch as plain data. Use this rather than the `caught` nodes for anything
## that outlives the hook - queue_free() takes its children with it.
func get_catch_data() -> Array[FishData]:
	var out: Array[FishData] = []
	for f in caught:
		if is_instance_valid(f) and f.data:
			out.append(f.data)
	return out


func _on_catch_area_entered(area: Area2D) -> void:
	if state == HookState.FLIGHT:
		return   # a hook still in the air shouldn't snag anything
	if not has_room():
		return
	var fish := area as Fish
	if fish == null or fish.is_caught:
		return

	fish.on_caught(self, _slot_for(caught.size()))
	caught.append(fish)
	# Reparenting is a tree edit, which is illegal inside a physics callback -
	# hand it to the next idle frame. keep_global_transform defaults true, so the
	# fish doesn't jump; it eases into its slot from wherever it was hooked.
	fish.reparent.call_deferred(self)
	caught_fish.emit(fish, caught.size(), capacity)

	# First catch on the bottom: come home now. Anything picked up on the way up
	# is a bonus and doesn't re-trigger anything (_begin_return guards on state).
	_begin_return()


func _slot_for(index: int) -> Vector2:
	var slot := catch_slot_spacing * float(index + 1)
	slot.x += catch_slot_stagger * (1.0 if index % 2 == 0 else -1.0)
	return slot
