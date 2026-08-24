class_name Hook extends CharacterBody2D

@export var bounce_factor = 0.6
@export var speed: float = 1200.0
@export var gravity: float = 1000.0

var dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	self.velocity = dir * speed
	
func _physics_process(delta: float) -> void:
	self.velocity.y += gravity * delta
	
	var collision = move_and_collide(self.velocity * delta)
	if not collision: return

	self.velocity = velocity.bounce(collision.get_normal()) * bounce_factor
