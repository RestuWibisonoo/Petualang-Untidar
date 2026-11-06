class_name Interactable
extends Area2D

## Interactable.gd
## Base component / Area2D contract for objects that the Player can interact with.
## Dispatches interaction calls and provides text prompts for UI.

signal interacted(actor: Node)
signal availability_changed(available: bool)

@export var interaction_text: String = "Interaksi"
@export var is_interactable: bool = true:
	set(val):
		is_interactable = val
		availability_changed.emit(is_interactable)


func _ready() -> void:
	add_to_group(&"interactable")
	# Collision Layer 8 (bit 7: value 128) for Interactables, Mask 0
	collision_layer = 128
	collision_mask = 0


func can_interact(_actor: Node) -> bool:
	return is_interactable and monitorable


func interact(actor: Node) -> void:
	if can_interact(actor):
		interacted.emit(actor)


func get_interaction_text() -> String:
	return interaction_text
