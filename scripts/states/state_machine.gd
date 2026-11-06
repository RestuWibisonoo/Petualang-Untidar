class_name StateMachine
extends Node

## StateMachine.gd
## Generic finite state machine that manages State child nodes.
## Ensures only the currently active state receives update callbacks.

signal transitioned(state_name: StringName)

@export var initial_state: State

var current_state: State = null
var states: Dictionary = {}


func _ready() -> void:
	if owner:
		await owner.ready
	
	_setup_states()


func _setup_states() -> void:
	states.clear()
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
	
	if initial_state:
		transition_to(initial_state.name.to_lower())
	elif get_child_count() > 0 and get_child(0) is State:
		transition_to(get_child(0).name.to_lower())


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(target_state_name: StringName, msg: Dictionary = {}) -> void:
	var key: String = String(target_state_name).to_lower()
	if not states.has(key):
		push_warning("[StateMachine] Target state '%s' does not exist." % target_state_name)
		return

	var new_state: State = states[key]
	if current_state:
		current_state.exit()

	current_state = new_state
	current_state.enter(msg)
	transitioned.emit(target_state_name)


func get_current_state_name() -> StringName:
	return current_state.name if current_state else &""
