class_name InteractionZone extends Area2D
## Base for "walk up to a thing and press E".


const PROMPT_SCENE := preload("res://UI/EToInteract/e_to_interact.tscn")


## Where an auto-created prompt sits, relative to this node.
@export var prompt_offset: Vector2 = Vector2(0, -28)
## Turn off for a zone that should act without advertising itself.
@export var show_prompt: bool = true

var prompt: eToInteract = null
var player_inside: bool = false


func _ready() -> void:
	if show_prompt:
		prompt = get_node_or_null(^"E-to-interact") as eToInteract
		if prompt == null:
			prompt = PROMPT_SCENE.instantiate()
			prompt.name = "E-to-interact"
			add_child(prompt)
			prompt.position = prompt_offset
		prompt.conceal()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)



func _unhandled_input(event: InputEvent) -> void:
	if not player_inside:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interaction()


func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	player_inside = true
	if prompt != null:
		prompt.reveal()


func _on_body_exited(body: Node2D) -> void:
	if body is not Player:
		return
	player_inside = false
	if prompt != null:
		prompt.conceal()


## Override this. Called when the player presses `interact_action` inside.
func interaction() -> void:
	push_warning("InteractionZone: interaction() not implemented on %s" % name)
