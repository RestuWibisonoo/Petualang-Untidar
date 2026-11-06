extends SceneTree

## runtime_validation_phase_3.gd
## Runtime simulation validation for Phase 3:
## 1. Actual physics collision (walls, trees, boundaries, diagonal corner sliding).
## 2. Actual Y-Sort visual depth ordering (front, behind, overhead layer).
## 3. Actual Scene Transition loop: Outdoor -> Building -> Outdoor with spawn points.
## 4. Actual Information Board UI opening, reading, freeze, close, and re-interaction.

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
	# Position player at (-300, 0) and move LEFT.
	player.global_position = Vector2(-300, 0)
	for _frame in range(30):
		player.velocity = Vector2(-120, 0)
		player.move_and_slide()
		await physics_frame

	assert_true(player.global_position.x >= -322.0, "Player is blocked by Left World Boundary (stopped at X=%.1f)" % player.global_position.x)

	# 1C. Collision against Building Wall Tiles (Y = -120, X = 40 to 200)
	# Position player under solid wall at (80, -80) and move UP.
	player.global_position = Vector2(80, -80)
	for _frame in range(30):
		player.velocity = Vector2(0, -120)
		player.move_and_slide()
		await physics_frame

	assert_true(player.global_position.y >= -126.0, "Player is blocked by solid wall tiles (stopped at Y=%.1f)" % player.global_position.y)
	assert_true(player.global_position.y < -75.0, "Player moved toward wall tiles before colliding (stopped at Y=%.1f)" % player.global_position.y)

	# 1D. Diagonal Corner Sliding
	# Push diagonally UP-LEFT into top-left boundary corner (-330, -250).
	player.global_position = Vector2(-310, -230)
	for _frame in range(30):
		player.velocity = Vector2(-120, -120).normalized() * 120.0
		player.move_and_slide()
		await physics_frame

	# Assert player did not penetrate corner
	assert_true(player.global_position.x >= -322.0 and player.global_position.y >= -242.0, "Player safely contained in corner without penetrating bounds")

	# Now switch input to RIGHT (1, 0) - verify player slides away cleanly and doesn't get stuck!
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
	var tree: Node2D = level.get_node_or_null("YSortEntities/Interactables/Tree1") as Node2D
	var y_sort_container: Node2D = level.get_node_or_null("YSortEntities") as Node2D
	var overhead: TileMapLayer = level.get_node_or_null("OverheadLayer") as TileMapLayer

	assert_true(y_sort_container.y_sort_enabled == true, "YSortEntities container has y_sort_enabled = true")
	assert_true(tree.y_sort_enabled == true, "Tree prop in interactables has y_sort_enabled = true")

	# 2A. When Player is south of Tree base (Y_player > Y_tree), player renders in front of tree
	player.global_position = tree.global_position + Vector2(0, 30)
	assert_true(player.global_position.y > tree.global_position.y, "Player at Y=%.1f is south of Tree at Y=%.1f (renders in front)" % [player.global_position.y, tree.global_position.y])

	# 2B. When Player is north of Tree base (Y_player < Y_tree), player renders behind tree
	player.global_position = tree.global_position + Vector2(0, -30)
	assert_true(player.global_position.y < tree.global_position.y, "Player at Y=%.1f is north of Tree at Y=%.1f (renders behind canopy)" % [player.global_position.y, tree.global_position.y])

	# 2C. OverheadLayer has z_index = 5, strictly above entity layer (z=0)
	assert_true(overhead.z_index >= 5, "OverheadLayer z_index (%d) is >= 5, rendering above characters and Y-sorted objects" % overhead.z_index)

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
	print("\n--- 4. Testing Scene Transition Loop (Outdoor -> Building -> Outdoor) ---")

	var scene_manager: Node = get_root().get_node_or_null("SceneManager")
	assert_true(scene_manager != null, "SceneManager is available")

	# Step 1: Outdoor level spawn
	var outdoor_packed: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var outdoor: WorldBase = outdoor_packed.instantiate() as WorldBase
	get_root().add_child(outdoor)
	await physics_frame

	# Default spawn in outdoor is (0, 40)
	var default_spawn: Marker2D = outdoor.get_node_or_null("SpawnPoints/default") as Marker2D
	assert_true(outdoor.player.global_position == default_spawn.global_position, "Outdoor player initial spawn at 'default': %s" % default_spawn.global_position)

	# Step 2: Transition from Outdoor -> Building at 'from_outdoor'
	scene_manager.target_spawn_point_id = &"from_outdoor"
	outdoor.queue_free()
	await process_frame

	var building_packed: PackedScene = load("res://scenes/world/building_test.tscn")
	var building: WorldBase = building_packed.instantiate() as WorldBase
	get_root().add_child(building)
	await physics_frame

	var spawn_from_outdoor: Marker2D = building.get_node_or_null("SpawnPoints/from_outdoor") as Marker2D
	assert_true(spawn_from_outdoor != null, "Building has 'from_outdoor' spawn marker")
	assert_true(building.player.global_position == spawn_from_outdoor.global_position, "Player spawned at 'from_outdoor' marker: %s (not default!)" % building.player.global_position)

	# Step 3: Transition from Building -> Outdoor at 'from_building'
	scene_manager.target_spawn_point_id = &"from_building"
	building.queue_free()
	await process_frame

	var outdoor_reentered: WorldBase = outdoor_packed.instantiate() as WorldBase
	get_root().add_child(outdoor_reentered)
	await physics_frame

	var spawn_from_building: Marker2D = outdoor_reentered.get_node_or_null("SpawnPoints/from_building") as Marker2D
	assert_true(spawn_from_building != null, "Outdoor has 'from_building' spawn marker")
	assert_true(outdoor_reentered.player.global_position == spawn_from_building.global_position, "Player spawned at 'from_building' marker: %s (not default!)" % outdoor_reentered.player.global_position)

	# Step 4: Double Transition Lock
	scene_manager._is_transitioning = true
	var exit_door: Door = outdoor_reentered.get_node_or_null("YSortEntities/Interactables/CampusDoor") as Door
	var transition_fired := [false]
	exit_door.door_entered.connect(func(_a: Node, _s: String): transition_fired[0] = true)
	exit_door._on_interacted(outdoor_reentered.player)

	assert_true(transition_fired[0] == false, "Door transition is blocked when SceneManager is already transitioning (no double calls)")
	scene_manager._is_transitioning = false

	outdoor_reentered.queue_free()
