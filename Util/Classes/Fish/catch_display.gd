class_name CatchDisplay extends Node2D
## Presents the fish a cast brought in, above the player's head - one at a time,
## least rare first, so the haul builds toward its best fish.

@export var entry_scene: PackedScene
## Indexed to match FishData.Rarity: [None, Common, Rare, Bepic, Legendary].
## Element 0 is never used - it's there so the enum value IS the index.
@export var rarity_styles: Array[RarityStyle] = []

@export_group("Layout")
## How far below its resting spot a fish starts before popping up.
@export var rise_height: float = 14.0

@export_group("Timing")
@export var pop_time: float = 0.28
@export var fade_time: float = 0.3
## Floor for how long each fish stays up. Its tier's hold_time can extend it.
@export var min_hold: float = 0.9
## Beat between one fish leaving and the next arriving.
@export var gap: float = 0.15

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

signal finished
## Fires as each fish appears - hook a counter or running cash total to it.
signal presented(data: FishData, index: int, total: int)

var _entries: Array[CatchEntry] = []
## False once clear() has run. show_catch is a coroutine spanning several
## seconds; without this it would keep spawning fish after being cleared.
var _running: bool = false


func style_for(data: FishData) -> RarityStyle:
	if data == null:
		return null
	var tier: int = int(data.rarity)
	if tier >= 0 and tier < rarity_styles.size():
		return rarity_styles[tier]
	return null


func show_catch(catch: Array[FishData]) -> void:
	clear()
	if catch.is_empty():
		finished.emit()
		return
	_running = true

	# duplicate() first: sort_custom is in-place, and this array belongs to the
	# player - ShowingCatchState.exit() clears it out from under us.
	var order: Array[FishData] = catch.duplicate()
	order.sort_custom(func(a: FishData, b: FishData) -> bool:
		return int(a.rarity) < int(b.rarity))

	for i in order.size():
		presented.emit(order[i], i, order.size())
		await _present(order[i])
		if not _running:
			return

	_entries.clear()
	_running = false
	finished.emit()


func clear() -> void:
	_running = false
	for e in _entries:
		if is_instance_valid(e):
			e.queue_free()
	_entries.clear()


## Pops one fish up, holds it, fades it out.
## Awaits timers rather than tween.finished on purpose - a tween dies with its
## node, so if clear() frees the entry mid-animation the await never resumes.
func _present(data: FishData) -> void:
	var style: RarityStyle = style_for(data)

	var entry: CatchEntry = entry_scene.instantiate()
	add_child(entry)   # runs _ready, so setup() can use its @onready vars
	entry.setup(data, style)
	entry.position = Vector2(0.0, rise_height)
	entry.scale = Vector2.ZERO
	_entries.append(entry)

	if style and style.sound and audio:
		audio.stream = style.sound
		audio.play()

	var t_in := entry.create_tween().set_parallel(true)
	t_in.tween_property(entry, "scale", Vector2.ONE, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_in.tween_property(entry, "position:y", 0.0, pop_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(pop_time).timeout
	if not _running or not is_instance_valid(entry):
		return

	var hold: float = min_hold
	if style:
		hold = maxf(min_hold, style.hold_time)
	await get_tree().create_timer(hold).timeout
	if not _running or not is_instance_valid(entry):
		return

	entry.create_tween().tween_property(entry, "modulate:a", 0.0, fade_time)
	await get_tree().create_timer(fade_time).timeout
	if not _running:
		return

	if is_instance_valid(entry):
		_entries.erase(entry)
		entry.queue_free()

	if gap > 0.0:
		await get_tree().create_timer(gap).timeout
