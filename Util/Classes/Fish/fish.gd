class_name Fish extends Node2D
## A spawned fish. Swims horizontally across its spawn band and frees itself
## on the far side. Built from a FishData by FishSpawnArea.

@onready var sprite: Sprite2D = $Sprite2D

var data: FishData = null

var _direction: float = 1.0      # +1 swims right, -1 swims left
var _despawn_x: float = 0.0
var _bob_phase: float = 0.0
var _home_y: float = 0.0

@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 1.5


var _spawn_position: Vector2 = Vector2.ZERO

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
	global_position = _spawn_position
	_home_y = _spawn_position.y
	if data and sprite:
		sprite.texture = data.texture
		sprite.flip_h = _direction < 0.0


func _process(delta: float) -> void:
	if not data:
		return
	global_position.x += data.speed * _direction * delta
	_bob_phase += bob_speed * delta
	global_position.y = _home_y + sin(_bob_phase) * bob_amplitude

	# Despawn the bad boy when its past the far edge
	if (_direction > 0.0 and global_position.x > _despawn_x) \
			or (_direction < 0.0 and global_position.x < _despawn_x):
		queue_free()
