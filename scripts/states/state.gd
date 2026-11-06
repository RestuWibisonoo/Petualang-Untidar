class_name State
extends Node

## State.gd
## Base class for all states used in the StateMachine.

var state_machine: StateMachine = null


## Called when the state is entered.
func enter(_msg: Dictionary = {}) -> void:
	pass


## Called when the state is exited.
func exit() -> void:
	pass


## Called every physics frame while this state is active.
func physics_update(_delta: float) -> void:
	pass


## Called every visual frame while this state is active.
func update(_delta: float) -> void:
	pass


## Called when input events occur while this state is active.
func handle_input(_event: InputEvent) -> void:
	pass
