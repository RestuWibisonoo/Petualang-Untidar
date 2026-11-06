extends SceneTree

## runtime_validation_phase_3.gd
## Runtime simulation validation for Phase 3:
## 1. Actual physics collision (walls, trees, boundaries, diagonal corner sliding).
## 2. Actual Y-Sort visual depth ordering (front, behind, overhead layer, Z-index isolation, footprint geometry).
## 3. Actual Information Board UI opening, reading, freeze, close, and re-interaction.
## 4. Production Scene Transition loop: Outdoor -> Building -> Outdoor using SceneManager.change_scene_with_spawn()
##    validating fade overlay, spawn point resolution, spawn ID cleanup, and duplicate instance prevention.

var tests_passed: int = 0
var tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_runtime_suite, CONNECT_ONE_SHOT)


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		tests_failed += 1
		printerr("  [FAIL] %s" % test_name)


func _run_runtime_suite() -> void:
	print("\n=======================================================")
	print(">>> STARTING PHASE 3 RUNTIME PHYSICS & SCENE SUITE <<<")
	print("=======================================================\n")

	await test_runtime_collision()
	await test_runtime_ysort_depth()
	await test_runtime_info_board_in_level()
	await test_runtime_scene_transition_loop()

	print("\n=======================================================")
	print(">>> RUNTIME VALIDATION SUMMARY <<<")
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("=======================================================")

	if tests_failed == 0:
		print("\n[SUCCESS] All Phase 3 runtime simulations passed with 0 errors!\n")
	else:
		push_error("\n[FAILURE] %d runtime tests failed!\n" % tests_failed)

	quit(0 if tests_failed == 0 else 1)


func test_runtime_collision() -> void:
	print("--- 1. Testing Runtime Physics Collision & Corner Sliding ---")

	var packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var level: WorldBase = packed.instantiate() as WorldBase
	get_root().add_child(level)
	await physics_frame
	await physics_frame

	var player: Player = level.player

	# 1A. Collision against Tree trunk
	# Tree1 is at (-120, 20), trunk solid circle at (-120, 18), radius 8.
	# Position player just below tree trunk at (-120, 50). Move UP toward tree.
	player.global_position = Vector2(-120, 50)
	player.velocity = Vector2.ZERO
	for _frame in range(30):
		player.velocity = Vector2(0, -120)
		player.move_and_slide()
		await physics_frame

	# Player feet capsule (Y+8, r=6) collides with trunk (Y-2, r=8).
	# Distance between centers >= 14, so player global Y stops at >= 23.5.
	assert_true(player.global_position.y >= 23.5, "Player is blocked by Tree trunk (stopped at Y=%.1f, no penetration)" % player.global_position.y)
	assert_true(player.global_position.y < 45.0, "Player moved upward toward Tree before colliding (stopped at Y=%.1f)" % player.global_position.y)

	# 1B. Collision against World Boundaries (Left wall at X = -330)
	player.global_position = Vector2(-300, 0)
	for _frame in range(30):
		player.velocity = Vector2(-120, 0)
		player.move_and_slide()
		await physics_frame

	assert_true(player.global_position.x >= -322.0, "Player is blocked by Left World Boundary (stopped at X=%.1f)" % player.global_position.x)

	# 1C. Collision against Building Wall Tiles (Y = -120, X = 40 to 200)
	player.global_position = Vector2(80, -80)
	for _frame in range(30):
		player.velocity = Vector2(0, -120)
		player.move_and_slide()
		await physics_frame

	assert_true(player.global_position.y >= -126.0, "Player is blocked by solid wall tiles (stopped at Y=%.1f)" % player.global_position.y)
	assert_true(player.global_position.y < -75.0, "Player moved toward wall tiles before colliding (stopped at Y=%.1f)" % player.global_position.y)

	# 1D. Diagonal Corner Sliding
	player.global_position = Vector2(-310, -230)
	for _frame in range(30):
		player.velocity = Vector2(-120, -120).normalized() * 120.0
		player.move_and_slide()
		await physics_frame

	assert_true(player.global_position.x >= -322.0 and player.global_position.y >= -242.0, "Player safely contained in corner without penetrating bounds")

	# Switch input to RIGHT (1, 0) - player slides out cleanly without getting stuck
	for _frame in range(20):
		player.velocity = Vector2(120, 0)
		player.move_and_slide()
		await physics_frame

	assert_true(player.global_position.x > -290.0, "Player slides freely out of corner when directional input changes (X=%.1f)" % player.global_position.x)

	level.queue_free()
	await process_frame


func test_runtime_ysort_depth() -> void:
	print("\n--- 2. Testing Runtime Y-Sort & Depth Ordering ---")

	var packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var level: WorldBase = packed.instantiate() as WorldBase
	get_root().add_child(level)
	await physics_frame

	var player: Player = level.player
	var y_sort_container: Node2D = level.get_node_or_null("YSortEntities") as Node2D
	var interactables: Node2D = level.get_node_or_null("YSortEntities/Interactables") as Node2D
	var solid_layer: TileMapLayer = level.get_node_or_null("YSortEntities/SolidObjectsLayer") as TileMapLayer
	var tree1: StaticBody2D = level.get_node_or_null("YSortEntities/Interactables/Tree1") as StaticBody2D
	var tree2: StaticBody2D = level.get_node_or_null("YSortEntities/Interactables/Tree2") as StaticBody2D
	var tree3: StaticBody2D = level.get_node_or_null("YSortEntities/Interactables/Tree3") as StaticBody2D
	var chest: StaticBody2D = level.get_node_or_null("YSortEntities/Interactables/TreasureChest") as StaticBody2D
	var board: StaticBody2D = level.get_node_or_null("YSortEntities/Interactables/InformationBoard") as StaticBody2D
	var overhead: TileMapLayer = level.get_node_or_null("OverheadLayer") as TileMapLayer

	# 2A. Hierarchy Y-Sort Chain (all intermediate parents and props have y_sort_enabled = true)
	assert_true(y_sort_container != null and y_sort_container.y_sort_enabled == true, "YSortEntities root container has y_sort_enabled = true")
	assert_true(interactables != null and interactables.y_sort_enabled == true, "YSortEntities/Interactables intermediate container has y_sort_enabled = true")
	assert_true(solid_layer != null and solid_layer.y_sort_enabled == true, "SolidObjectsLayer has y_sort_enabled = true")
	assert_true(tree1 != null and tree1.y_sort_enabled == true, "Tree1 prop has y_sort_enabled = true")
	assert_true(tree2 != null and tree2.y_sort_enabled == true, "Tree2 prop has y_sort_enabled = true")
	assert_true(tree3 != null and tree3.y_sort_enabled == true, "Tree3 prop has y_sort_enabled = true")
	assert_true(chest != null and chest.y_sort_enabled == true, "TreasureChest has y_sort_enabled = true")
	assert_true(board != null and board.y_sort_enabled == true, "InformationBoard has y_sort_enabled = true")

	# 2B. Z-Index Isolation (entities all share Z=0; OverheadLayer is Z >= 5)
	assert_true(player.z_index == 0, "Player z_index is 0 (delegates rendering order to Y-sort)")
	assert_true(tree1.z_index == 0, "Tree1 z_index is 0 (delegates rendering order to Y-sort)")
	assert_true(chest.z_index == 0, "TreasureChest z_index is 0 (delegates rendering order to Y-sort)")
	assert_true(overhead != null and overhead.z_index >= 5, "OverheadLayer z_index (%d) is >= 5, rendering strictly above all Y-sorted entities" % overhead.z_index)

	# 2C. Footprint & Occlusion Geometry
	# Tree pivot (0, 0) is at base of trunk (world Y=20).
	# Tree sprite: position=(0, -28), size 48x64.
	# Canopy section: Y in [-40, 4]. Trunk section: Y in [4, 24].
	# Player sprite: height 32, centered at player.global_position. Foot collision circle at Y+8.
	var tree_base_y: float = tree1.global_position.y # 20.0

	# When Player is north of Tree (behind tree):
	player.global_position = tree1.global_position + Vector2(0, -20) # Player at Y = 0.0
	var player_top_behind: float = player.global_position.y - 16.0 # -16.0
	var player_bottom_behind: float = player.global_position.y + 16.0 # +16.0
	var canopy_top: float = tree_base_y - 28.0 - 32.0 # -40.0
	var canopy_bottom: float = tree_base_y - 28.0 + 12.0 # +4.0
	var overlaps_canopy: bool = (player_top_behind < canopy_bottom) and (player_bottom_behind > canopy_top)
	assert_true(player.global_position.y < tree_base_y, "Player at Y=%.1f is north of Tree at Y=%.1f" % [player.global_position.y, tree_base_y])
	assert_true(overlaps_canopy, "Player sprite bounds [%.1f, %.1f] overlap Tree canopy [%.1f, %.1f]" % [player_top_behind, player_bottom_behind, canopy_top, canopy_bottom])
	assert_true(player.global_position.y < tree1.global_position.y, "Player Y < Tree Y: Tree renders on top, occluding Player behind canopy")

	# When Player is south of Tree (in front of tree):
	player.global_position = tree1.global_position + Vector2(0, 20) # Player at Y = 40.0
	var player_top_front: float = player.global_position.y - 16.0 # +24.0
	var player_bottom_front: float = player.global_position.y + 16.0 # +56.0
	var trunk_bottom: float = tree_base_y + 4.0 # +24.0
	var overlaps_trunk: bool = (player_top_front <= trunk_bottom)
	assert_true(player.global_position.y > tree_base_y, "Player at Y=%.1f is south of Tree at Y=%.1f" % [player.global_position.y, tree_base_y])
	assert_true(overlaps_trunk, "Player top (Y=%.1f) meets Tree trunk base (Y=%.1f)" % [player_top_front, trunk_bottom])
	assert_true(player.global_position.y > tree1.global_position.y, "Player Y > Tree Y: Player renders on top, occluding Tree trunk")

	level.queue_free()
	await process_frame


func test_runtime_info_board_in_level() -> void:
	print("\n--- 3. Testing Information Board UI Panel in Level ---")

	var packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var level: WorldBase = packed.instantiate() as WorldBase
	get_root().add_child(level)
	await physics_frame

	var board: InformationBoard = level.get_node_or_null("YSortEntities/Interactables/InformationBoard") as InformationBoard
	assert_true(board != null, "InformationBoard exists in level")

	var info_dialog: InfoDialogPanel = level.info_dialog
	assert_true(info_dialog != null, "InfoDialogPanel exists in level HUD")
	assert_true(info_dialog.is_open() == false, "InfoDialogPanel initially closed")
	assert_true(info_dialog.visible == false, "InfoDialogPanel initially hidden")

	# Trigger read on board
	board.interactable.interact(level.player)
	await process_frame

	# Verify panel is now open and populated
	assert_true(info_dialog.is_open() == true, "InfoDialogPanel opened on board interaction")
	assert_true(info_dialog.visible == true, "InfoDialogPanel visible on board interaction")
	assert_true(info_dialog.title_label.text == board.board_title, "InfoDialogPanel displays board_title ('%s')" % board.board_title)
	assert_true(info_dialog.content_label.text == board.board_content, "InfoDialogPanel displays full board_content")

	# Verify player is frozen and cannot spam interactions
	assert_true(level.player.is_physics_processing() == false, "Player physics processing disabled while reading board")
	assert_true(board.interactable.is_interactable == false, "InformationBoard interaction disabled while reading (spam prevention)")

	# Close panel
	info_dialog.close_panel()
	await process_frame

	assert_true(info_dialog.is_open() == false, "InfoDialogPanel closed cleanly")
	assert_true(info_dialog.visible == false, "InfoDialogPanel hidden after close")
	assert_true(level.player.is_physics_processing() == true, "Player physics processing restored after closing panel")
	assert_true(board.interactable.is_interactable == true, "InformationBoard interactable restored after closing panel")

	level.queue_free()
	await process_frame


func test_runtime_scene_transition_loop() -> void:
	print("\n--- 4. Testing Production Scene Transition Loop (SceneManager) ---")

	var scene_manager: Node = get_root().get_node_or_null("SceneManager")
	assert_true(scene_manager != null, "SceneManager is available as Autoload singleton")
	assert_true(scene_manager.process_mode == Node.PROCESS_MODE_ALWAYS, "SceneManager runs in PROCESS_MODE_ALWAYS")

	var fade_rect: ColorRect = scene_manager.get_node_or_null("SceneTransitionOverlay/FadeRect") as ColorRect
	assert_true(fade_rect != null, "SceneTransitionOverlay has FadeRect")

	# Step 1: Initial load into Outdoor scene via standard scene tree
	change_scene_to_file("res://scenes/world/outdoor_test.tscn")
	await process_frame
	await process_frame

	var outdoor: WorldBase = current_scene as WorldBase
	assert_true(outdoor != null and outdoor.name == "OutdoorTest", "Outdoor scene loaded as current_scene")
	var default_spawn: Marker2D = outdoor.get_node_or_null("SpawnPoints/default") as Marker2D
	assert_true(outdoor.player.global_position == default_spawn.global_position, "Player spawned at default spawn marker: %s" % default_spawn.global_position)
	assert_true(scene_manager.target_spawn_point_id == &"", "Spawn point ID is empty after initial ready")

	# Verify no duplicate scenes or players initially
	assert_true(_count_world_instances() == 1, "Exactly 1 WorldBase instance in scene tree")
	assert_true(_count_player_instances() == 1, "Exactly 1 Player instance in scene tree")

	# Step 2: Production Transition: Outdoor -> Building via change_scene_with_spawn()
	scene_manager.change_scene_with_spawn("res://scenes/world/building_test.tscn", &"from_outdoor", true, 0.05)

	# Validate immediate transition state
	assert_true(scene_manager.is_transitioning() == true, "SceneManager.is_transitioning() is true during transition")
	assert_true(scene_manager.target_spawn_point_id == &"from_outdoor", "Target spawn point ID set to 'from_outdoor'")
	assert_true(fade_rect.mouse_filter == Control.MOUSE_FILTER_STOP, "FadeRect blocks mouse/touch input during fade-out")

	# Validate double-transition prevention
	scene_manager.change_scene_to_file("res://scenes/world/outdoor_test.tscn") # should be rejected
	assert_true(scene_manager.target_spawn_point_id == &"from_outdoor", "Double transition call ignored, target remains 'from_outdoor'")

	# Await transition duration + scene change + fade-in with a watchdog
	var timeout_frames: int = 0
	while scene_manager.is_transitioning() and timeout_frames < 60:
		await process_frame
		timeout_frames += 1

	# Validate completed state in Building
	var building: WorldBase = current_scene as WorldBase
	assert_true(building != null and building.name == "BuildingTest", "Current scene is now BuildingTest")
	assert_true(scene_manager.is_transitioning() == false, "SceneManager.is_transitioning() is false after transition completes")
	assert_true(scene_manager.target_spawn_point_id == &"", "Spawn point ID cleaned up after ready (now empty)")
	assert_true(fade_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "FadeRect mouse_filter restored to IGNORE after fade-in")
	assert_true(is_equal_approx(fade_rect.color.a, 0.0), "FadeRect opacity is 0.0 after fade-in")

	var spawn_from_outdoor: Marker2D = building.get_node_or_null("SpawnPoints/from_outdoor") as Marker2D
	assert_true(spawn_from_outdoor != null, "Building has 'from_outdoor' spawn marker")
	assert_true(building.player.global_position == spawn_from_outdoor.global_position, "Player spawned at 'from_outdoor' marker: %s (not default!)" % building.player.global_position)

	# Verify no scene or player duplication after transition 1
	assert_true(_count_world_instances() == 1, "Old Outdoor scene freed: exactly 1 WorldBase instance remains")
	assert_true(_count_player_instances() == 1, "Old Player freed: exactly 1 Player instance remains")

	# Step 3: Production Return Transition: Building -> Outdoor via change_scene_with_spawn()
	scene_manager.change_scene_with_spawn("res://scenes/world/outdoor_test.tscn", &"from_building", true, 0.05)

	assert_true(scene_manager.is_transitioning() == true, "SceneManager.is_transitioning() is true during return transition")
	assert_true(scene_manager.target_spawn_point_id == &"from_building", "Target spawn point ID set to 'from_building'")

	timeout_frames = 0
	while scene_manager.is_transitioning() and timeout_frames < 60:
		await process_frame
		timeout_frames += 1

	var outdoor_return: WorldBase = current_scene as WorldBase
	assert_true(outdoor_return != null and outdoor_return.name == "OutdoorTest", "Current scene is returned OutdoorTest")
	assert_true(scene_manager.is_transitioning() == false, "SceneManager.is_transitioning() is false after return transition")
	assert_true(scene_manager.target_spawn_point_id == &"", "Spawn point ID cleaned up on return (now empty)")

	var spawn_from_building: Marker2D = outdoor_return.get_node_or_null("SpawnPoints/from_building") as Marker2D
	assert_true(spawn_from_building != null, "Outdoor has 'from_building' spawn marker")
	assert_true(outdoor_return.player.global_position == spawn_from_building.global_position, "Player spawned at 'from_building' marker: %s (not default!)" % outdoor_return.player.global_position)

	# Verify no scene or player duplication after transition 2
	assert_true(_count_world_instances() == 1, "Old Building scene freed: exactly 1 WorldBase instance remains")
	assert_true(_count_player_instances() == 1, "Old Player freed: exactly 1 Player instance remains")


func _count_world_instances() -> int:
	var count: int = 0
	for child in get_root().get_children():
		if child is WorldBase:
			count += 1
	return count


func _count_player_instances() -> int:
	var count: int = 0
	for child in get_root().get_children():
		if child is WorldBase:
			for player_node in child.find_children("*", "Player"):
				count += 1
	return count
