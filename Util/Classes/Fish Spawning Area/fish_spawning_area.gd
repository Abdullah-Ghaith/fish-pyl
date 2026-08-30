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
## Shifts the whole curve toward the rare end. Each tier above Common gets
## multiplied by luck one more time than the tier below it, so a single number
## makes rare fish rarer or commoner in a smooth, monotonic way.
## 1.0 = the weights above verbatim.
@export var luck: float = 1.0

## Runtime upgrade hooks - set these from your upgrade system, not the inspector.
var spawn_rate_multiplier: float = 1.0
var luck_bonus: float = 0.0

var _spawn_accumulator: float = 0.0
var _fish: Array[Fish] = []
var _resolving: bool = false   # cycle guard for the previous_area chain


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

	# Validate the species list once here rather than per-instance at spawn time.
	for f in spawnable_fish:
		if f == null:
			printerr("%s: FishSpawnArea has an empty slot in spawnable_fish" % name)
		else:
			f.validate(name)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	for i in range(_fish.size() - 1, -1, -1):
		if not is_instance_valid(_fish[i]):
			_fish.remove_at(i)

	# Accumulator rather than a Timer, so an upgrade to spawn_rate takes effect
	# immediately and rates above one-per-frame still work.
	_spawn_accumulator += get_spawn_rate() * delta
	while _spawn_accumulator >= 1.0 and _fish.size() < max_fish:
		_spawn_accumulator -= 1.0
		_spawn_one()


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


## Pull weight for one species. Rarity tier sets the base; luck raises each tier
## above Common by one more power of luck than the tier below it.
func get_weight(fish: FishData) -> float:
	if fish == null:
		return 0.0
	var tier: int = int(fish.rarity)
	if tier <= 0 or tier >= rarity_weights.size():
		return 0.0
	return rarity_weights[tier] * pow(get_luck(), tier - 1) * fish.weight_multiplier


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

	var fish: Fish = fish_scene.instantiate()
	fish.setup(data, 1.0 if swims_right else -1.0,
			Vector2(start_x, randf_range(get_top_y(), get_bottom_y())), end_x)
	add_child(fish)
	_fish.append(fish)


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
