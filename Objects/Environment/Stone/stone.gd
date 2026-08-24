# A stone that will simply fall into the water
extends RigidBody2D

var in_water_speed_limit = 200.0

func _ready():
	# Ensure the body uses regular gravity and physics
	freeze = false
	# Lock rotation if you don't want the stone to spin when falling
	lock_rotation = true 

func _physics_process(delta):
	# If the stone is falling too fast in water, cap its velocity
	if linear_velocity.y > in_water_speed_limit and gravity_scale < 1.0:
		linear_velocity.y = in_water_speed_limit

# Initializes the stone at a set position
func initialize(pos):
	global_position = pos

func in_water():
	# Lower gravity_scale so the engine naturally makes it fall slower in water
	gravity_scale = 0.3
	
	# Increase linear damping to simulate water resistance (creates a smooth slowdown)
	linear_damp = 3.0
