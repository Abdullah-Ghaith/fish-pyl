class_name eToInteract extends Node2D

@onready var animation_player: AnimationPlayer = %AnimationPlayer


func reveal() -> void:
	self.show()
	animation_player.play("pulse")
