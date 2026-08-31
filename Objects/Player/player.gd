class_name Player extends CharacterBody2D

@export var SPEED = 100.0

@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var state_machine: StateMachine = %StateMachine

var can_right: bool = true
var can_left: bool = true
var can_fire: bool = false

var last_catch: Array[FishData] = []

func _physics_process(delta: float) -> void:
	pass

func enter_aiming_fishing_rod_state() -> void:
	state_machine.force_change_state("AimingFishingRodState")

func enter_fishing_state() -> void:
	state_machine.force_change_state("FishingState")

func enter_walking_state() -> void:
	state_machine.force_change_state("WalkingState")

func _on_fishing_rod_hook_fired() -> void:
	enter_fishing_state()
