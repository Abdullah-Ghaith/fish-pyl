class_name Hook extends CharacterBody2D

@export var bounce_factor := 0.6
@export var speed: float = 1200.0
@export var gravity: float = 1000.0

@export_group("In Water")
## Fraction of speed kept on impact with the surface.
@export var splash_slowdown: float = 0.45
## Much weaker than air gravity, so the hook sinks slowly and readably.
@export var sink_gravity: float = 140.0
## Per-second drag, so the hook settles into a steady sink rate.
@export var water_drag: float = 2.2

## Emitted when the hook breaks the surface. `surface_y` is the global y of the
## waterline (NAN when the emitter doesn't know it).
signal entered_water(surface_y: float)

var dir: Vector2 = Vector2.ZERO
var in_water := false


func _ready() -> void:
	velocity = dir * speed
	entered_water.connect(_on_entered_water)


func _physics_process(delta: float) -> void:
	if in_water:
		velocity.y += sink_gravity * delta
		velocity *= maxf(0.0, 1.0 - water_drag * delta)
	else:
		velocity.y += gravity * delta

	var collision := move_and_collide(velocity * delta)
	if not collision:
		return
	velocity = velocity.bounce(collision.get_normal()) * bounce_factor


func _on_entered_water(_surface_y: float) -> void:
	if in_water:
		return
	in_water = true
	velocity *= splash_slowdown
