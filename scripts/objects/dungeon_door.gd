class_name DungeonDoor
extends Node2D

## DungeonDoor.gd
## Locked dungeon gateway requiring key item validation from InventoryManager.
## Supports configurable key consumption, transition safety, and informative prompts.

signal unlocked(actor: Node)
signal unlock_failed(actor: Node, reason: String)
signal door_entered(actor: Node, target_scene: String)

@export_file("*.tscn") var target_scene_path: String = "res://scenes/dungeon/dungeon_room.tscn"
@export var target_spawn_id: StringName = &"dungeon_entrance"
@export var required_key_id: StringName = &"dungeon_key"
@export var required_key_name: String = "Kunci Labirin"
@export var consumes_key: bool = true
@export var is_locked: bool = true
@export var door_label: String = "Pintu Labirin"

@onready var interactable: Interactable = get_node_or_null("Interactable") as Interactable


func _ready() -> void:
	_setup_interactable()


func _setup_interactable() -> void:
	if not interactable and has_node("Interactable"):
		interactable = $Interactable as Interactable
	if not interactable:
		interactable = Interactable.new()
		interactable.name = "Interactable"
		interactable.collision_layer = 128
		interactable.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24.0
		shape.shape = circle
		interactable.add_child(shape)
		add_child(interactable)

	if interactable:
		_update_prompt_text()
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)


func _update_prompt_text() -> void:
	if interactable:
		if is_locked:
			interactable.interaction_text = "Buka %s (Terkunci)" % door_label
		else:
			interactable.interaction_text = "Masuk %s" % door_label


func can_unlock(inv: InventoryManager) -> bool:
	if not is_locked:
		return true
	return inv != null and inv.has_item(required_key_id)


func unlock(inv: InventoryManager) -> bool:
	if not is_locked:
		return true
	if not can_unlock(inv):
		return false
	if consumes_key and inv:
		var removed: bool = inv.remove_item(required_key_id, 1)
		if not removed:
			return false
	is_locked = false
	_update_prompt_text()
	unlocked.emit(null)
	return true


func _on_interacted(actor: Node) -> void:
	var scene_mgr := get_node_or_null("/root/SceneManager")
	var event_bus := get_node_or_null("/root/EventBus")

	# Prevent multiple activations during an active transition
	if scene_mgr and scene_mgr.has_method("is_transitioning") and scene_mgr.is_transitioning():
		return

	# Handle lock & key validation
	if is_locked:
		var inv: InventoryManager = null
		if actor and "inventory_manager" in actor and actor.inventory_manager:
			inv = actor.inventory_manager as InventoryManager
		if not inv:
			inv = InventoryManager.get_default()

		if not inv or not inv.has_item(required_key_id, 1):
			var msg := "Pintu terkunci! Membutuhkan %s." % required_key_name
			if event_bus and event_bus.has_signal("show_floating_text"):
				event_bus.show_floating_text.emit(msg, global_position + Vector2(0, -20), Color(0.95, 0.35, 0.35))
			unlock_failed.emit(actor, "missing_key")
			return

		# Verify target scene exists before consuming key
		if target_scene_path == "" or not ResourceLoader.exists(target_scene_path):
			push_warning("[DungeonDoor] Cannot unlock: target scene '%s' not found." % target_scene_path)
			unlock_failed.emit(actor, "invalid_scene")
			return

		# Consume key if configured
		if consumes_key:
			var removed := inv.remove_item(required_key_id, 1)
			if not removed:
				unlock_failed.emit(actor, "failed_to_consume")
				return

		is_locked = false
		_update_prompt_text()
		unlocked.emit(actor)

		if event_bus and event_bus.has_signal("show_floating_text"):
			var unlock_msg := "Pintu berhasil dibuka dengan %s!" % required_key_name
			event_bus.show_floating_text.emit(unlock_msg, global_position + Vector2(0, -20), Color(0.3, 0.9, 0.4))

	# Transition to target dungeon scene
	if target_scene_path != "" and ResourceLoader.exists(target_scene_path):
		door_entered.emit(actor, target_scene_path)
		print("[DungeonDoor] %s transition to: %s (spawn: %s)" % [name, target_scene_path, target_spawn_id])
		if scene_mgr and scene_mgr.has_method("change_scene_with_spawn"):
			scene_mgr.change_scene_with_spawn(target_scene_path, target_spawn_id, true)
	else:
		push_warning("[DungeonDoor] Cannot transition: target scene path invalid '%s'" % target_scene_path)
