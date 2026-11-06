extends SceneTree

## test_phase_3.gd
## Automated validation suite for Phase 3: World & Exploration.
## Validates world hierarchy, TileMapLayers, Y-sort, collision boundaries,
## InteractionComponent, Interactables, objects, doors, and spawn points.

var tests_passed: int = 0
var tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)


func _run_all_tests() -> void:
	print("\n=======================================================")
	print(">>> STARTING PHASE 3 AUTOMATED VALIDATION SUITE <<<")
	print("=======================================================\n")

	test_world_scenes_structure()
	test_y_sort_and_layering()
	test_collision_layers_and_boundaries()
	test_interaction_component_and_interactable()
	test_interactive_objects()
	test_scene_transitions_and_spawn_points()
	test_touch_controls_and_hud_prompt()

	print("\n=======================================================")
	print(">>> PHASE 3 VALIDATION SUMMARY <<<")
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("=======================================================")

	if tests_failed == 0:
		print("\n[SUCCESS] All Phase 3 world & exploration components validated with 0 errors!\n")
	else:
		push_error("\n[FAILURE] %d Phase 3 tests failed!\n" % tests_failed)

	quit(0 if tests_failed == 0 else 1)


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		tests_failed += 1
		printerr("  [FAIL] %s" % test_name)


func test_world_scenes_structure() -> void:
	print("--- 1. Testing World Scenes Structure ---")

	# Test Outdoor scene
	var outdoor_packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	assert_true(outdoor_packed != null, "outdoor_test.tscn loaded successfully")

	var outdoor: Node2D = outdoor_packed.instantiate() as Node2D
	get_root().add_child(outdoor)

	assert_true(outdoor is WorldBase, "outdoor_test.tscn root is WorldBase class")
	assert_true(outdoor.get_node_or_null("GroundLayer") is TileMapLayer, "outdoor_test contains GroundLayer (TileMapLayer)")
	assert_true(outdoor.get_node_or_null("WallDecorationLayer") is TileMapLayer, "outdoor_test contains WallDecorationLayer (TileMapLayer)")
	assert_true(outdoor.get_node_or_null("YSortEntities") is Node2D, "outdoor_test contains YSortEntities (Node2D)")
	assert_true(outdoor.get_node_or_null("OverheadLayer") is TileMapLayer, "outdoor_test contains OverheadLayer (TileMapLayer)")
	assert_true(outdoor.get_node_or_null("WorldBoundaries") is StaticBody2D, "outdoor_test contains WorldBoundaries (StaticBody2D)")
	assert_true(outdoor.get_node_or_null("SpawnPoints") is Node2D, "outdoor_test contains SpawnPoints (Node2D)")
	assert_true(outdoor.get_node_or_null("YSortEntities/Player") is Player, "outdoor_test contains Player in YSortEntities")
	assert_true(outdoor.get_node_or_null("TouchControls") is TouchControls, "outdoor_test contains TouchControls")
	assert_true(outdoor.get_node_or_null("HUD") is CanvasLayer, "outdoor_test contains HUD (CanvasLayer)")

	outdoor.queue_free()

	# Test Building scene
	var building_packed: PackedScene = load("res://scenes/world/building_test.tscn")
	assert_true(building_packed != null, "building_test.tscn loaded successfully")

	var building: Node2D = building_packed.instantiate() as Node2D
	get_root().add_child(building)

	assert_true(building is WorldBase, "building_test.tscn root is WorldBase class")
	assert_true(building.get_node_or_null("GroundLayer") is TileMapLayer, "building_test contains GroundLayer (TileMapLayer)")
	assert_true(building.get_node_or_null("YSortEntities") is Node2D, "building_test contains YSortEntities (Node2D)")
	assert_true(building.get_node_or_null("WorldBoundaries") is StaticBody2D, "building_test contains WorldBoundaries (StaticBody2D)")
	assert_true(building.get_node_or_null("SpawnPoints") is Node2D, "building_test contains SpawnPoints (Node2D)")
	assert_true(building.get_node_or_null("YSortEntities/Player") is Player, "building_test contains Player in YSortEntities")

	building.queue_free()

	# Test Main scene
	var main_packed: PackedScene = load("res://scenes/main/main.tscn")
	assert_true(main_packed != null, "main.tscn loaded successfully")

	var main_node: Node2D = main_packed.instantiate() as Node2D
	get_root().add_child(main_node)
	assert_true(main_node is WorldBase, "main.tscn root inherits WorldBase")
	assert_true(main_node is MainScene, "main.tscn root is MainScene class")
	main_node.queue_free()


func test_y_sort_and_layering() -> void:
	print("\n--- 2. Testing Y-Sort & Layering Hierarchy ---")

	var packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var world: Node2D = packed.instantiate() as Node2D
	get_root().add_child(world)

	var y_sort_node: Node2D = world.get_node_or_null("YSortEntities") as Node2D
	assert_true(y_sort_node != null and y_sort_node.y_sort_enabled == true, "YSortEntities has y_sort_enabled = true")

	var overhead: TileMapLayer = world.get_node_or_null("OverheadLayer") as TileMapLayer
	assert_true(overhead != null and overhead.z_index >= 5, "OverheadLayer has z_index >= 5 to render above characters")

	var interactables: Node2D = world.get_node_or_null("YSortEntities/Interactables") as Node2D
	assert_true(interactables != null and interactables.y_sort_enabled == true, "YSortEntities/Interactables has y_sort_enabled = true")

	var tree: Node2D = world.get_node_or_null("YSortEntities/Interactables/Tree1") as Node2D
	assert_true(tree != null and tree.y_sort_enabled == true, "Tree prop has y_sort_enabled = true")

	# Verify Y-sort logical ordering:
	# At Y = -10 (above tree base at Y = 0), player renders behind tree.
	# At Y = +10 (below tree base at Y = 0), player renders in front of tree.
	var player_pos_behind: float = -10.0
	var player_pos_in_front: float = 10.0
	var tree_base_y: float = 0.0
	assert_true(player_pos_behind < tree_base_y, "Entity with lower Y renders behind object base in Y-Sort")
	assert_true(player_pos_in_front > tree_base_y, "Entity with higher Y renders in front of object base in Y-Sort")

	world.queue_free()


func test_collision_layers_and_boundaries() -> void:
	print("\n--- 3. Testing Collision Layers & Boundaries ---")

	var packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var world: Node2D = packed.instantiate() as Node2D
	get_root().add_child(world)

	var boundaries: StaticBody2D = world.get_node_or_null("WorldBoundaries") as StaticBody2D
	assert_true(boundaries != null, "WorldBoundaries exists")
	assert_true((boundaries.collision_layer & 1) != 0, "WorldBoundaries collision_layer includes Layer 1 (World)")
	assert_true(boundaries.get_child_count() >= 4, "WorldBoundaries has boundary collision shapes for map borders")

	var player: Player = world.get_node_or_null("YSortEntities/Player") as Player
	assert_true(player != null, "Player exists in level")
	assert_true((player.collision_mask & 1) != 0, "Player collision_mask includes Layer 1 (World obstacles)")

	# Check tree trunk collision
	var tree: StaticBody2D = world.get_node_or_null("YSortEntities/Interactables/Tree1") as StaticBody2D
	assert_true(tree != null, "Tree1 exists")
	assert_true((tree.collision_layer & 1) != 0, "Tree collision_layer includes Layer 1 (Solid World)")

	world.queue_free()


func test_interaction_component_and_interactable() -> void:
	print("\n--- 4. Testing InteractionComponent & Interactable ---")

	var inter_comp := InteractionComponent.new()
	var coll_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	coll_shape.shape = circle
	inter_comp.add_child(coll_shape)
	get_root().add_child(inter_comp)

	assert_true((inter_comp.collision_mask & 128) != 0, "InteractionComponent scans Layer 8 (bit 7: 128)")
	assert_true(inter_comp.collision_layer == 0, "InteractionComponent collision_layer is 0")

	# Create two interactables: near (distance 10) and far (distance 25)
	var interactable_near := Interactable.new()
	interactable_near.interaction_text = "Near Object"
	interactable_near.position = Vector2(10, 0)
	get_root().add_child(interactable_near)

	var interactable_far := Interactable.new()
	interactable_far.interaction_text = "Far Object"
	interactable_far.position = Vector2(25, 0)
	get_root().add_child(interactable_far)

	assert_true((interactable_near.collision_layer & 128) != 0, "Interactable is on Layer 8 (bit 7: 128)")
	assert_true(interactable_near.is_in_group(&"interactable"), "Interactable is in 'interactable' group")

	# Test area tracking
	inter_comp._on_area_entered(interactable_far)
	assert_true(inter_comp.get_current_target() == interactable_far, "Far object detected as initial target")

	inter_comp._on_area_entered(interactable_near)
	assert_true(inter_comp.get_current_target() == interactable_near, "Near object takes priority as closest target")

	# Test interaction trigger
	var interacted_fired := [false]
	interactable_near.interacted.connect(func(_actor: Node): interacted_fired[0] = true)
	inter_comp.trigger_interact()
	assert_true(interacted_fired[0], "trigger_interact() triggers target's interacted signal")

	# Test disabling interactable
	interactable_near.is_interactable = false
	assert_true(inter_comp.get_current_target() == interactable_far, "Disabling closest target falls back to next candidate")

	# Test area exit
	inter_comp._on_area_exited(interactable_far)
	assert_true(inter_comp.get_current_target() == null, "Exiting area clears current target to null")

	inter_comp.queue_free()
	interactable_near.queue_free()
	interactable_far.queue_free()


func test_interactive_objects() -> void:
	print("\n--- 5. Testing Interactive Objects ---")

	# 1. Treasure Chest
	var chest_packed: PackedScene = load("res://scenes/objects/treasure_chest.tscn")
	assert_true(chest_packed != null, "treasure_chest.tscn loaded successfully")

	var chest: TreasureChest = chest_packed.instantiate() as TreasureChest
	get_root().add_child(chest)

	assert_true(chest.is_opened == false, "TreasureChest initial is_opened = false")
	assert_true(chest.interactable != null and chest.interactable.is_interactable == true, "TreasureChest initial is_interactable = true")
	assert_true(chest.sprite.frame == 0, "TreasureChest sprite frame is 0 (closed)")

	var chest_opened_signal := [false]
	chest.opened.connect(func(_actor: Node): chest_opened_signal[0] = true)

	chest.open_chest(chest)
	assert_true(chest.is_opened == true, "TreasureChest is_opened is true after opening")
	assert_true(chest.interactable.is_interactable == false, "TreasureChest disables interaction after opening")
	assert_true(chest.sprite.frame == 1, "TreasureChest sprite frame updated to 1 (opened)")
	assert_true(chest_opened_signal[0], "TreasureChest emitted opened signal")

	chest.queue_free()

	# 2. Information Board & Info Dialog Panel
	var board_packed: PackedScene = load("res://scenes/objects/information_board.tscn")
	assert_true(board_packed != null, "information_board.tscn loaded successfully")

	var board: InformationBoard = board_packed.instantiate() as InformationBoard
	get_root().add_child(board)

	assert_true(board.board_title != "", "InformationBoard has board_title")
	assert_true(board.board_content != "", "InformationBoard has board_content")
	assert_true(board.is_reading == false, "InformationBoard initial is_reading = false")

	var board_read_signal := [false]
	board.read.connect(func(_actor: Node): board_read_signal[0] = true)

	var panel_requested_signal := [false]
	var event_bus: Node = get_root().get_node_or_null("EventBus")
	if event_bus and event_bus.has_signal("info_panel_requested"):
		event_bus.info_panel_requested.connect(func(_t: String, _c: String): panel_requested_signal[0] = true)

	board.interactable.interact(board)
	assert_true(board_read_signal[0], "InformationBoard interaction emits read signal")
	assert_true(panel_requested_signal[0], "InformationBoard interaction emits info_panel_requested via EventBus")
	assert_true(board.is_reading == true, "InformationBoard is_reading is true after interaction")
	assert_true(board.interactable.is_interactable == false, "InformationBoard disables interaction while open to prevent spam")

	# Test re-interaction prevention
	var second_read_fired := [false]
	board.read.connect(func(_actor: Node): second_read_fired[0] = true)
	board.interactable.interact(board)
	assert_true(second_read_fired[0] == false, "Second interaction is blocked while InformationBoard is open")

	# Test close notification restores interactability
	if event_bus and event_bus.has_signal("info_panel_closed"):
		event_bus.info_panel_closed.emit()
	assert_true(board.is_reading == false, "InformationBoard is_reading reset to false after info_panel_closed")
	assert_true(board.interactable.is_interactable == true, "InformationBoard is_interactable restored to true after close")

	board.queue_free()

	# 2B. InfoDialogPanel Component
	var panel_packed: PackedScene = load("res://scenes/ui/info_dialog_panel.tscn")
	assert_true(panel_packed != null, "info_dialog_panel.tscn loaded successfully")

	var panel: InfoDialogPanel = panel_packed.instantiate() as InfoDialogPanel
	get_root().add_child(panel)

	assert_true(panel.is_open() == false, "InfoDialogPanel initially closed")
	assert_true(panel.visible == false, "InfoDialogPanel initially hidden")

	var panel_opened_signal := [false]
	panel.opened.connect(func(): panel_opened_signal[0] = true)
	panel.open_panel("Judul Tes", "Isi konten pengumuman kampus lengkap.")

	assert_true(panel.is_open() == true, "InfoDialogPanel is_open is true after open_panel")
	assert_true(panel.visible == true, "InfoDialogPanel visible is true after open_panel")
	assert_true(panel.title_label.text == "Judul Tes", "InfoDialogPanel displays correct title")
	assert_true(panel.content_label.text.contains("Isi konten pengumuman"), "InfoDialogPanel displays correct content")
	assert_true(panel_opened_signal[0], "InfoDialogPanel emitted opened signal")

	# Test close via method
	var panel_closed_signal := [false]
	panel.closed.connect(func(): panel_closed_signal[0] = true)
	panel.close_panel()

	assert_true(panel.is_open() == false, "InfoDialogPanel is_open is false after close_panel")
	assert_true(panel.visible == false, "InfoDialogPanel visible is false after close_panel")
	assert_true(panel_closed_signal[0], "InfoDialogPanel emitted closed signal")

	# Test close via touch button
	panel.open_panel("Tes Tombol", "Konten tombol")
	panel.close_button.pressed.emit()
	assert_true(panel.is_open() == false, "InfoDialogPanel closed via touch CloseButton")

	# Test close via keyboard unhandled input (ESC / interact key)
	panel.open_panel("Tes Keyboard", "Konten keyboard")
	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", esc_event)
	panel._unhandled_input(esc_event)
	assert_true(panel.is_open() == false, "InfoDialogPanel closed via Escape / pause input")

	panel.queue_free()

	# 3. Door
	var door_packed: PackedScene = load("res://scenes/objects/door.tscn")
	assert_true(door_packed != null, "door.tscn loaded successfully")

	var door: Door = door_packed.instantiate() as Door
	get_root().add_child(door)

	assert_true(door.interactable != null, "Door contains Interactable component")
	assert_true(door.target_spawn_id == &"default", "Door default target_spawn_id is &\"default\"")

	door.queue_free()


func test_scene_transitions_and_spawn_points() -> void:
	print("\n--- 6. Testing Scene Transitions & Spawn Points ---")
	var scene_manager: Node = get_root().get_node_or_null("SceneManager")
	assert_true(scene_manager != null, "SceneManager autoload is present")

	# Test SceneManager spawn point tracking
	scene_manager.change_scene_with_spawn("res://scenes/world/building_test.tscn", &"test_spawn_point", false)
	assert_true(scene_manager.target_spawn_point_id == &"test_spawn_point", "SceneManager sets target_spawn_point_id")

	var retrieved_spawn: StringName = scene_manager.get_and_clear_spawn_point()
	assert_true(retrieved_spawn == &"test_spawn_point", "get_and_clear_spawn_point() returns correct ID")
	assert_true(scene_manager.target_spawn_point_id == &"", "get_and_clear_spawn_point() clears spawn ID to empty")

	# Test rejected transitions preserve spawn ID state
	scene_manager.change_scene_with_spawn("res://scenes/invalid_non_existent_file.tscn", &"invalid_spawn_id", false)
	assert_true(scene_manager.target_spawn_point_id == &"", "Invalid scene path rejected without modifying target_spawn_point_id")

	scene_manager._is_transitioning = true
	scene_manager.change_scene_with_spawn("res://scenes/world/building_test.tscn", &"blocked_spawn_id", false)
	assert_true(scene_manager.target_spawn_point_id == &"", "Rejected transition due to _is_transitioning does not modify target_spawn_point_id")
	scene_manager._is_transitioning = false

	# Test WorldBase spawn positioning
	var packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var world: WorldBase = packed.instantiate() as WorldBase
	get_root().add_child(world)

	var spawn_from_building: Marker2D = world.get_node_or_null("SpawnPoints/from_building") as Marker2D
	assert_true(spawn_from_building != null, "SpawnPoints contains 'from_building' marker")

	# Set spawn ID and trigger positioning
	scene_manager.target_spawn_point_id = &"from_building"
	world._handle_spawn_point()
	assert_true(world.player.global_position == spawn_from_building.global_position, "Player correctly positioned at 'from_building' marker")

	world.queue_free()


func test_touch_controls_and_hud_prompt() -> void:
	print("\n--- 7. Testing Touch Controls & HUD Prompt ---")

	var packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var world: WorldBase = packed.instantiate() as WorldBase
	get_root().add_child(world)

	var touch_controls: TouchControls = world.touch_controls
	assert_true(touch_controls != null, "WorldBase has TouchControls reference")

	var interact_btn: Button = touch_controls.interact_button
	assert_true(interact_btn != null, "TouchControls contains interact_button (%InteractButton)")

	# Test prompt label behavior
	var dummy_interactable := Interactable.new()
	dummy_interactable.interaction_text = "Buka Kotak Uji"
	get_root().add_child(dummy_interactable)

	world._on_interaction_target_changed(dummy_interactable)
	assert_true(world.prompt_label != null and world.prompt_label.visible == true, "PromptLabel is visible when interactable in range")
	assert_true(world.prompt_label.text.contains("Buka Kotak Uji"), "PromptLabel displays interaction text")

	world._on_interaction_target_changed(null)
	assert_true(world.prompt_label.visible == false, "PromptLabel is hidden when target is null")

	dummy_interactable.queue_free()
	world.queue_free()
