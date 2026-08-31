class_name CatchDisplay extends Node2D
## Presents the fish a cast brought in, above the player's head.

@export var entry_scene: PackedScene
## Indexed to match FishData.Rarity: [None, Common, Rare, Bepic, Legendary].
## Element 0 is never used - it's there so the enum value IS the index.
@export var rarity_styles: Array[RarityStyle] = []

@export_group("Layout")
@export var spacing: float = 22.0
@export var rise_height: float = 14.0

@export_group("Timing")
@export var pop_time: float = 0.28
@export var stagger: float = 0.12
@export var fade_time: float = 0.3
## Floor for how long the row stays up. A rarer fish's hold_time can extend it.
@export var min_hold: float = 0.9

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

signal finished

var _entries: Array[CatchEntry] = []


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

	# The rarest fish in the haul sets the hold time and the sound, so one
	# legendary among commons still gets its moment.
	var hold: float = min_hold
	var best_tier: int = -1
	var sound: AudioStream = null

	for i in catch.size():
		var data: FishData = catch[i]
		var style: RarityStyle = style_for(data)
		if style:
			hold = maxf(hold, style.hold_time)
			if int(data.rarity) > best_tier:
				best_tier = int(data.rarity)
				sound = style.sound

		var entry: CatchEntry = entry_scene.instantiate()
		add_child(entry)           # runs _ready, so setup() can use @onready vars
		entry.setup(data, style)
		entry.position = Vector2(_slot_x(i, catch.size()), 0.0)
		_entries.append(entry)
		_pop_in(entry, i)

	if sound and audio:
		audio.stream = sound
		audio.play()

	var wait: float = pop_time + stagger * float(catch.size() - 1) + hold
	var t := create_tween()
	t.tween_interval(wait)
	t.tween_callback(_fade_out)


func clear() -> void:
	for e in _entries:
		if is_instance_valid(e):
			e.queue_free()
	_entries.clear()


func _slot_x(index: int, total: int) -> float:
	return (float(index) - (float(total) - 1.0) * 0.5) * spacing


func _pop_in(entry: CatchEntry, index: int) -> void:
	var rest_y: float = entry.position.y
	entry.scale = Vector2.ZERO
	entry.position.y = rest_y + rise_height
	var delay: float = stagger * float(index)
	# Bound to the entry, so a cleared entry kills its own tween.
	var t := entry.create_tween().set_parallel(true)
	t.tween_property(entry, "scale", Vector2.ONE, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(entry, "position:y", rest_y, pop_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)


func _fade_out() -> void:
	if _entries.is_empty():
		_finish()
		return
	var t := create_tween().set_parallel(true)
	for e in _entries:
		if is_instance_valid(e):
			t.tween_property(e, "modulate:a", 0.0, fade_time)
	t.chain().tween_callback(_finish)


func _finish() -> void:
	clear()
	finished.emit()
