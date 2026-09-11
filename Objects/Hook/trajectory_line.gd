class_name TrajectoryLine extends Line2D
## Preview of where a cast would go. Draws only the first `visible_steps` of
## the flight, so the player aims with limited sight rather than a full
## solution.

## How much of the flight to draw. This is the "how far can you see" number.
@export var visible_steps: int = 48
## Fixed timestep for the simulation.
@export var step: float = 1.0 / 60.0
## Ceiling, so an upgrade can't make the preview cost real frame time.
@export var max_steps: int = 400
@export var bounce_damping: float = 0.6

## Runtime upgrade hook.
var steps_multiplier: float = 1.0

@onready var collision_test: CharacterBody2D = $CollisionTest


func get_visible_steps() -> int:
	return clampi(roundi(float(visible_steps) * steps_multiplier), 2, max_steps)


func update_trajectory(dir: Vector2, speed: float, gravity: float) -> void:
	clear_points()
	var pos := Vector2.ZERO
	var vel: Vector2 = dir * speed
	# The probe has to start from the origin every time, or the first step's
	# collision test runs from wherever last frame's arc ended.
	collision_test.position = Vector2.ZERO

	for _i in get_visible_steps():
		add_point(pos)
		vel.y += gravity * step
		var hit := collision_test.move_and_collide(vel * step, false, true, true)
		if hit:
			vel = vel.bounce(hit.get_normal()) * bounce_damping
		pos += vel * step
		collision_test.position = pos
