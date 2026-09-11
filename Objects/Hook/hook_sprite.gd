class_name WobblySprite2D extends Sprite2D

@export var amplitude_x: float = 0.1
@export var amplitude_y: float = 0.1
@export var frequency_x: float = 2.0
@export var frequency_y: float = 3.0

@export var rotation_amplitude_deg: float = 5.0
@export var rotation_frequency: float = 1.5

var base_scale: Vector2
var base_rotation: float
var time: float = 0.0

func _ready() -> void:
	base_scale = scale
	base_rotation = rotation

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time += delta
	scale.x = base_scale.x + ((sin(time * frequency_x) + 1.0) * 0.5) * amplitude_x
	scale.y = base_scale.y + ((sin(time * frequency_y) + 1.0) * 0.5) * amplitude_y
	rotation = base_rotation + sin(time * rotation_frequency) * deg_to_rad(rotation_amplitude_deg)
