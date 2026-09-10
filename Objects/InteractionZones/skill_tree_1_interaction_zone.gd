extends InteractionZone


const SCREEN_SCENE := preload("res://Scenes/SkillTree/skill_tree_1.tscn")

var _screen: CanvasLayer = null


func interaction() -> void:
	if is_instance_valid(_screen):
		return
	# A CanvasLayer, so the screen's Control fills the viewport instead of
	# living in world space and sliding around with the camera.
	_screen = CanvasLayer.new()
	_screen.layer = 10
	_screen.add_child(SCREEN_SCENE.instantiate())
	add_child(_screen)
	if prompt != null:
		prompt.conceal()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_screen):
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close()
		return
	super(event)


func _close() -> void:
	_screen.queue_free()
	_screen = null
	if player_inside and prompt != null:
		prompt.reveal()
