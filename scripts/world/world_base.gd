class_name WorldBase
extends Node2D

## WorldBase.gd
## Base controller for all game levels and exploration zones.
## Manages TileMapLayers, Y-Sort entity containers, spawn points, and feedback.

@export var level_name: String = "Campus Zone"

@onready var ground_layer: TileMapLayer = get_node_or_null("GroundLayer") as TileMapLayer
@onready var wall_deco_layer: TileMapLayer = get_node_or_null("WallDecorationLayer") as TileMapLayer
@onready var y_sort_entities: Node2D = get_node_or_null("YSortEntities") as Node2D
@onready var overhead_layer: TileMapLayer = get_node_or_null("OverheadLayer") as TileMapLayer
@onready var world_boundaries: StaticBody2D = get_node_or_null("WorldBoundaries") as StaticBody2D
@onready var player: Player = get_node_or_null("YSortEntities/Player") as Player
@onready var spawn_points: Node2D = get_node_or_null("SpawnPoints") as Node2D
@onready var touch_controls: TouchControls = get_node_or_null("TouchControls") as TouchControls
@onready var prompt_label: Label = get_node_or_null("HUD/PromptLabel") as Label
@onready var title_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/VBoxLeft/TitleLabel") as Label
@onready var zone_label: Label = get_node_or_null("HUD/ZoneLabel") as Label
@onready var state_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/VBoxLeft/StateLabel") as Label
@onready var speed_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/VBoxLeft/SpeedLabel") as Label
@onready var facing_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/VBoxLeft/FacingLabel") as Label
@onready var pause_indicator: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/VBoxRight/PauseIndicator") as Label
@onready var info_dialog: InfoDialogPanel = get_node_or_null("HUD/InfoDialogPanel") as InfoDialogPanel


func _ready() -> void:
	print("=================================================")
	print("   PETUALANG UNTIDAR - LEVEL: %s" % level_name)
	print("=================================================")

	if title_label:
		title_label.text = "PETUALANG UNTIDAR - %s" % level_name.to_upper()
	if zone_label:
		zone_label.text = level_name

	_handle_spawn_point()

	if player and touch_controls:
		touch_controls.set_target_player(player)

	if player and player.interaction_component:
		player.interaction_component.target_changed.connect(_on_interaction_target_changed)

	# Ensure InfoDialogPanel exists in HUD
	if not info_dialog and has_node("HUD"):
		var panel_scene: PackedScene = load("res://scenes/ui/info_dialog_panel.tscn")
		if panel_scene:
			info_dialog = panel_scene.instantiate() as InfoDialogPanel
			$HUD.add_child(info_dialog)

	# Ensure InventoryUI exists in HUD
	if not get_node_or_null("HUD/InventoryUI") and has_node("HUD"):
		var inv_scene: PackedScene = load("res://scenes/ui/inventory_ui.tscn")
		if inv_scene:
			var inv_ui := inv_scene.instantiate()
			$HUD.add_child(inv_ui)

	# Ensure DialogueUI exists in HUD
	if not get_node_or_null("HUD/DialogueUI") and has_node("HUD"):
		var dia_scene: PackedScene = load("res://scenes/ui/dialogue_ui.tscn")
		if dia_scene:
			var dia_ui := dia_scene.instantiate()
			$HUD.add_child(dia_ui)

	# Ensure QuestUI exists in HUD
	if not get_node_or_null("HUD/QuestUI") and has_node("HUD"):
		var quest_scene: PackedScene = load("res://scenes/ui/quest_ui.tscn")
		if quest_scene:
			var quest_ui := quest_scene.instantiate()
			$HUD.add_child(quest_ui)

	# Register default quests into QuestManager if empty
	var qm := QuestManager.get_instance()
	if qm and qm.get_all_quests().is_empty():
		var q1: QuestData = load("res://resources/quests/quest_first_steps.tres")
		if q1:
			qm.register_quest(q1)
		var q2: QuestData = load("res://resources/quests/quest_dungeon_boss.tres")
		if q2:
			qm.register_quest(q2)

	# Ensure LootSpawner exists in level
	if not get_node_or_null("LootSpawner"):
		var spawner := LootSpawner.new()
		spawner.name = "LootSpawner"
		add_child(spawner)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("show_floating_text"):
			event_bus.show_floating_text.connect(_on_show_floating_text)
		if event_bus.has_signal("info_panel_requested"):
			event_bus.info_panel_requested.connect(_on_info_panel_requested)
		if event_bus.has_signal("info_panel_closed"):
			event_bus.info_panel_closed.connect(_on_info_panel_closed)

	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager and "current_state" in game_manager:
		if game_manager.current_state == 0: # GameState.BOOT
			game_manager.change_state(2) # GameState.PLAYING


func _process(_delta: float) -> void:
	if not player:
		return

	if state_label and player.state_machine:
		state_label.text = "State: %s" % String(player.state_machine.get_current_state_name()).to_upper()

	if speed_label:
		speed_label.text = "Speed: %.1f px/s" % player.velocity.length()

	if facing_label:
		facing_label.text = "Facing: %s" % String(player.get_facing_direction_name()).to_upper()

	if pause_indicator:
		var game_manager := get_node_or_null("/root/GameManager")
		if game_manager and game_manager.has_method("is_paused"):
			pause_indicator.visible = game_manager.is_paused()


func _unhandled_input(event: InputEvent) -> void:
	if info_dialog and info_dialog.is_open():
		return

	if event.is_action_pressed("pause"):
		var game_manager := get_node_or_null("/root/GameManager")
		if game_manager and game_manager.has_method("toggle_pause"):
			game_manager.toggle_pause()
		get_viewport().set_input_as_handled()


func _on_info_panel_requested(title: String, content: String) -> void:
	if info_dialog:
		info_dialog.open_panel(title, content)
		if prompt_label:
			prompt_label.visible = false
		if player:
			player.velocity = Vector2.ZERO
			player.set_physics_process(false)


func _on_info_panel_closed() -> void:
	if player:
		player.set_physics_process(true)


func _handle_spawn_point() -> void:
	if not player or not spawn_points:
		return

	var target_spawn_id: StringName = &""
	var scene_mgr := get_node_or_null("/root/SceneManager")
	if scene_mgr and scene_mgr.has_method("get_and_clear_spawn_point"):
		target_spawn_id = scene_mgr.get_and_clear_spawn_point()
	if target_spawn_id == &"":
		target_spawn_id = &"default"

	var spawn_node: Marker2D = null
	for child in spawn_points.get_children():
		if child is Marker2D:
			if child.name.to_lower() == String(target_spawn_id).to_lower():
				spawn_node = child
				break

	if not spawn_node and spawn_points.get_child_count() > 0:
		spawn_node = spawn_points.get_child(0) as Marker2D

	if spawn_node:
		player.global_position = spawn_node.global_position
		print("[WorldBase] Player spawned at '%s': %s" % [spawn_node.name, spawn_node.global_position])


func _on_interaction_target_changed(target: Interactable) -> void:
	if prompt_label:
		if target:
			prompt_label.text = "[E] %s" % target.get_interaction_text()
			prompt_label.visible = true
		else:
			prompt_label.visible = false


func _on_show_floating_text(text: String, world_pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.top_level = true
	label.global_position = world_pos + Vector2(-40, -10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
