class_name GameStateManager extends Node

@onready var player: Player = %Player

func _on_fishing_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player.enter_aiming_fishing_rod_state()

func _on_fishing_area_body_exited(body: Node2D) -> void:
	if body is Player:
		player.enter_walking_state()

func _on_water_body_entered_water() -> void:
	player.enter_fishing_state()
