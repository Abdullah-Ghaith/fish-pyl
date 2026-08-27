extends Node2D

#TODO: consider having this be a mechanic?
const STONE = preload("uid://c3i2cxaqk3n1j")

#called when there's an input
func _input(event):
	#if there's any mouse button press
	if event is InputEventMouseButton and event.is_pressed():
		#makes an instance of the stone scene
		var s = STONE.instantiate()
		
		#adds the stone to the current scene
		get_tree().current_scene.add_child(s)

		#initializes the stone at the mouse position
		s.initialize(get_global_mouse_position())
		
