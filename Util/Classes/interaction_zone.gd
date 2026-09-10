class_name InteractionZone extends Area2D
@onready var e_to_interact: eToInteract = $"E-to-interact"



func _on_body_entered(body: Node2D) -> void:
	print("body entered~~~!")
	print(body)
	if body is not Player:
		return
	e_to_interact.reveal()


func _on_body_exited(body: Node2D) -> void:
	if body is not Player:
		return
	e_to_interact.hide()

func interaction() -> void:
	print("interaction not implemented on " + str(self.name))
