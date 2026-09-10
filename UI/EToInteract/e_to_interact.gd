class_name eToInteract extends Node2D

@onready var animation_player: AnimationPlayer = %AnimationPlayer


func reveal() -> void:
	show()
	animation_player.play("pulse")


func conceal() -> void:
	animation_player.stop()
	hide()
