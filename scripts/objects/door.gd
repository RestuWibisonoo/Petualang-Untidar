class_name Door
extends Node2D

## Door.gd
## Interactive doorway connecting rooms/levels via SceneManager.
## Supports configurable target scene and spawn point ID.

signal door_entered(actor: Node, target_scene: String)

@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_id: StringName = &"default"
@export var door_label: String = "Masuk Gedung"

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if interactable:
		interactable.interaction_text = door_label
		interactable.interacted.connect(_on_interacted)


func _on_interacted(actor: Node) -> void:
	var scene_mgr := get_node_or_null("/root/SceneManager")
	var event_bus := get_node_or_null("/root/EventBus")

	if scene_mgr and scene_mgr.has_method("is_transitioning") and scene_mgr.is_transitioning():
		return

	if target_scene_path != "" and ResourceLoader.exists(target_scene_path):
		door_entered.emit(actor, target_scene_path)
		print("[Door] %s triggered transition to: %s (spawn: %s)" % [name, target_scene_path, target_spawn_id])
		if scene_mgr and scene_mgr.has_method("change_scene_with_spawn"):
			scene_mgr.change_scene_with_spawn(target_scene_path, target_spawn_id, true)
	else:
		if event_bus and event_bus.has_signal("show_floating_text"):
			event_bus.show_floating_text.emit("Pintu terkunci.", global_position + Vector2(0, -20), Color(0.9, 0.3, 0.3))
		push_warning("[Door] Cannot transition: target scene path invalid or empty ('%s')" % target_scene_path)
