class_name StateMachine
extends Node

@export var initial_state : State

var current_state: State
var states : Dictionary[String, State]

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(on_child_transition)
			
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func on_child_transition(state: State, new_state_name: String) -> void:
	if state != current_state:
		return
		
	var new_state : State = states.get(new_state_name.to_lower())
	if !new_state:
		return
		
	if current_state:
		current_state.exit()
		
	new_state.enter()
	current_state = new_state

## Safely transitions to a new state by name from external scripts.
func force_change_state(new_state_name: String) -> void:
	var target_state : State = states.get(new_state_name.to_lower())
	
	if !target_state:
		push_warning("StateMachine: Attempted to transition to non-existent state: ", new_state_name)
		return
		
	if target_state == current_state:
		return # Already in this state
		
	if current_state:
		current_state.exit()
		
	target_state.enter()
	current_state = target_state
