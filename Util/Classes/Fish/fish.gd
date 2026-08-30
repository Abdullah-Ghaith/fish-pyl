class_name Fish extends Area2D
## A spawned fish. Swims horizontally across its spawn band and frees itself on
## the far side - unless a hook catches it, after which it just tags along.

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D

@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 1.5
## How quickly a caught fish settles into its slot on the hook (1/seconds).
@export var catch_follow_speed: float = 8.0

var data: FishData = null
var is_caught: bool = false

var _direction: float = 1.0
var _spawn_position: Vector2 = Vector2.ZERO
var _despawn_x: float = 0.0
var _bob_phase: float = 0.0
var _home_y: float = 0.0
var _captor: Node2D = null
var _slot_offset: Vector2 = Vector2.ZERO


## Call immediately after instancing, before adding to the tree.
func setup(fish_data: FishData, direction: float, spawn_position: Vector2, despawn_x: float) -> void:
	data = fish_data
	_direction = signf(direction)
	if _direction == 0.0:
		_direction = 1.0
	_spawn_position = spawn_position
	_despawn_x = despawn_x
	_bob_phase = randf() * TAU


func _ready() -> void:
	# Positioned here, not by the spawner - add_child() runs _ready immediately,
	# so anything the spawner sets afterwards would arrive too late for _home_y.
	global_position = _spawn_position
	_home_y = _spawn_position.y
	if data and sprite:
		sprite.texture = data.texture
		sprite.flip_h = _direction < 0.0
	_build_hitbox()


## Per-species shape when the FishData supplies one, otherwise a rectangle fitted
## to the sprite. The exported shape is shared across every fish of the species,
## so don't mutate it at runtime.
func _build_hitbox() -> void:
	if hitbox == null or data == null:
		return
	if data.hitbox:
		hitbox.shape = data.hitbox
	elif data.texture:
		var rect := RectangleShape2D.new()
		rect.size = data.texture.get_size() * data.hitbox_scale
		hitbox.shape = rect


func _process(delta: float) -> void:
	if is_caught:
		# Ease into the slot on the hook. Only once the deferred reparent has
		# landed, or we'd be lerping in the spawn area's coordinate space.
		if get_parent() == _captor:
			position = position.lerp(_slot_offset, 1.0 - exp(-catch_follow_speed * delta))
		return

	if not data:
		return
	global_position.x += data.speed * _direction * delta
	_bob_phase += bob_speed * delta
	global_position.y = _home_y + sin(_bob_phase) * bob_amplitude

	if (_direction > 0.0 and global_position.x > _despawn_x) \
			or (_direction < 0.0 and global_position.x < _despawn_x):
		queue_free()


## Called by the hook. Stops the fish swimming and takes it out of the running
## for any further catches.
func on_caught(by: Node2D, slot: Vector2) -> void:
	if is_caught:
		return
	is_caught = true
	_captor = by
	_slot_offset = slot
	# Deferred: this runs inside a physics callback, where flipping collision
	# state directly is not allowed.
	set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("disabled", true)
