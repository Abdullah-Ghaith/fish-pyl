class_name WaterSpring extends Node2D

# how much an external object's movement will affect this spring
@export var motion_factor = 0.02

@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var velocity : float = 0
var force : float = 0

var height : float = 0
var target_height : float = 0

var index = 0

var last_collided_with : PhysicsBody2D = null

signal splash(index: int, speed: float)

func water_update(spring_constant : float, dampening: float):
	
	height = position.y
	
	var x = height - target_height
	var loss = -dampening*velocity
	
	# Hookes law 
	force = -spring_constant*x + loss
	
	velocity += force
	position.y += velocity 

func initialize(x_pos : float, index: int):
	self.height = self.position.y
	self.target_height = self.position.y
	self.velocity = 0
	self.position.x = x_pos
	self.index = index

func set_collision_width(value):
	collision_shape.shape.size =  Vector2(value, collision_shape.shape.size.y)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == last_collided_with:
		return
	last_collided_with = body

	var body_speed: float = 0.0
	if body is CharacterBody2D:
		body_speed = body.velocity.y * motion_factor
	elif body is RigidBody2D:
		body_speed = body.linear_velocity.y * motion_factor
	
	splash.emit(index, body_speed)
