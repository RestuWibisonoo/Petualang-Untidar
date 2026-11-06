extends SceneTree

## test_phase_2.gd
## Automated validation suite for Phase 2: Character Foundation.

var tests_passed: int = 0
var tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)


func _run_all_tests() -> void:
	print("\n=======================================================")
	print(">>> STARTING PHASE 2 AUTOMATED VALIDATION SUITE <<<")
	print("=======================================================\n")

	test_player_scene_structure()
	test_player_movement_physics()
	test_player_state_machine()
	test_modular_visuals_system()
	test_camera_system()
	test_touch_controls_system()

	print("\n=======================================================")
	print(">>> PHASE 2 VALIDATION SUMMARY <<<")
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("=======================================================")

	if tests_failed == 0:
		print("\n[SUCCESS] All Phase 2 character foundation components validated with 0 errors!\n")
	else:
		push_error("\n[FAILURE] %d Phase 2 tests failed!\n" % tests_failed)

	quit(0 if tests_failed == 0 else 1)


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		tests_failed += 1
		printerr("  [FAIL] %s" % test_name)


func test_player_scene_structure() -> void:
	print("--- 1. Testing Player Scene Structure ---")
	var packed: PackedScene = load("res://scenes/player/player.tscn")
	assert_true(packed != null, "Player scene file loaded successfully")

	var player: Node = packed.instantiate()
	get_root().add_child(player)

	assert_true(player is CharacterBody2D, "Player root node is CharacterBody2D")
	assert_true(player is Player, "Player root script is Player class")
	assert_true(player.has_node("CollisionShape2D"), "Player contains CollisionShape2D")
	assert_true(player.has_node("ModularVisuals"), "Player contains ModularVisuals")
	assert_true(player.has_node("AnimationPlayer"), "Player contains AnimationPlayer")
	assert_true(player.has_node("StateMachine"), "Player contains StateMachine")
	assert_true(player.has_node("HealthComponent"), "Player contains HealthComponent")
	assert_true(player.has_node("VelocityComponent"), "Player contains VelocityComponent")
	assert_true(player.has_node("Camera2D"), "Player contains Camera2D")

	player.queue_free()


func test_player_movement_physics() -> void:
	print("\n--- 2. Testing Player Movement & Physics ---")
	var packed: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = packed.instantiate() as Player
	get_root().add_child(player)

	# Test 8-direction diagonal normalization
	var diagonal_input := Vector2(1, 1).normalized()
	assert_true(is_equal_approx(diagonal_input.length(), 1.0), "Diagonal vector length is normalized to 1.0")

	# Test VelocityComponent integration
	var vel_comp: VelocityComponent = player.velocity_component
	assert_true(vel_comp != null, "VelocityComponent is connected to Player")

	vel_comp.accelerate_in_direction(diagonal_input, 0.5)
	assert_true(vel_comp.velocity.length() <= player.walk_speed, "Velocity does not exceed walk_speed")
	assert_true(vel_comp.velocity.x > 0.0 and vel_comp.velocity.y > 0.0, "Velocity accelerates diagonally")

	vel_comp.stop()
	assert_true(vel_comp.velocity == Vector2.ZERO, "VelocityComponent stop() resets velocity to zero")

	# Test cardinal direction naming from movement
	player.last_movement_direction = Vector2(0, 1)
	assert_true(player.get_facing_direction_name() == &"down", "Facing direction (0, 1) is 'down'")
	player.last_movement_direction = Vector2(0, -1)
	assert_true(player.get_facing_direction_name() == &"up", "Facing direction (0, -1) is 'up'")
	player.last_movement_direction = Vector2(1, 0)
	assert_true(player.get_facing_direction_name() == &"right", "Facing direction (1, 0) is 'right'")
	player.last_movement_direction = Vector2(-1, 0)
	assert_true(player.get_facing_direction_name() == &"left", "Facing direction (-1, 0) is 'left'")

	player.queue_free()


func test_player_state_machine() -> void:
	print("\n--- 3. Testing Player State Machine ---")
	var packed: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = packed.instantiate() as Player
	get_root().add_child(player)

	var sm: StateMachine = player.state_machine
	assert_true(sm != null, "StateMachine exists on Player")
	assert_true(sm.get_current_state_name() == &"idle", "Initial state is 'Idle'")

	# Transition Idle -> Move
	sm.transition_to(&"move")
	assert_true(sm.get_current_state_name() == &"move", "State transitioned to 'Move'")

	# Transition Move -> Roll
	sm.transition_to(&"roll")
	assert_true(sm.get_current_state_name() == &"roll", "State transitioned to 'Roll'")

	# Simulate Roll physics update completing roll duration
	var roll_state: PlayerRollState = sm.current_state as PlayerRollState
	assert_true(roll_state != null, "Active state is PlayerRollState instance")

	# Set input direction to ZERO to ensure roll returns to Idle
	player.current_input_direction = Vector2.ZERO
	player.touch_input_direction = Vector2.ZERO
	roll_state.physics_update(player.roll_duration + 0.1)

	assert_true(sm.get_current_state_name() == &"idle", "State returned to 'Idle' after roll duration elapsed")

	# Test Roll while Moving
	sm.transition_to(&"move")
	sm.transition_to(&"roll")
	roll_state = sm.current_state as PlayerRollState
	# Simulate active movement input on roll exit -> should transition to Move
	player.touch_input_direction = Vector2.RIGHT
	roll_state.physics_update(player.roll_duration + 0.1)
	assert_true(sm.get_current_state_name() == &"move", "State returned to 'Move' when movement input active after roll")

	player.queue_free()


func test_modular_visuals_system() -> void:
	print("\n--- 4. Testing Modular Visuals System ---")
	var packed: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = packed.instantiate() as Player
	get_root().add_child(player)

	var visuals: ModularVisuals = player.modular_visuals
	assert_true(visuals != null, "ModularVisuals exists on Player")

	# Check all 10 layers exist
	for layer_name in ModularVisuals.ALL_LAYERS:
		assert_true(visuals.has_layer(layer_name), "ModularVisuals has layer: '%s'" % layer_name)
		var sprite := visuals.get_layer_node(layer_name)
		assert_true(sprite is Sprite2D, "Layer '%s' is a Sprite2D node" % layer_name)

	# Test visibility toggling
	visuals.set_layer_visible(ModularVisuals.LAYER_ARMOR, false)
	assert_true(visuals.is_layer_visible(ModularVisuals.LAYER_ARMOR) == false, "Armor layer can be hidden")
	visuals.set_layer_visible(ModularVisuals.LAYER_ARMOR, true)
	assert_true(visuals.is_layer_visible(ModularVisuals.LAYER_ARMOR) == true, "Armor layer can be shown")

	# Test texture swapping
	var original_tex: Texture2D = visuals.get_layer_texture(ModularVisuals.LAYER_WEAPON)
	var new_tex := ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	visuals.set_layer_texture(ModularVisuals.LAYER_WEAPON, new_tex)
	assert_true(visuals.get_layer_texture(ModularVisuals.LAYER_WEAPON) == new_tex, "Layer texture can be swapped dynamically")
	visuals.set_layer_texture(ModularVisuals.LAYER_WEAPON, original_tex)

	# Test animation playback for all 12 animations
	var anim_player: AnimationPlayer = player.get_node("AnimationPlayer") as AnimationPlayer
	assert_true(anim_player != null, "AnimationPlayer exists")

	var anim_list := anim_player.get_animation_list()
	var expected_anims: Array[String] = [
		"idle_down", "idle_up", "idle_left", "idle_right",
		"walk_down", "walk_up", "walk_left", "walk_right",
		"roll_down", "roll_up", "roll_left", "roll_right"
	]

	for anim in expected_anims:
		assert_true(anim_list.has(anim), "AnimationPlayer has animation: '%s'" % anim)

	# Play animation via ModularVisuals API
	visuals.play_animation(&"walk", &"right")
	assert_true(anim_player.current_animation == "walk_right", "ModularVisuals plays 'walk_right' animation")
	assert_true(visuals.get_facing_direction() == &"right", "ModularVisuals facing direction updated to 'right'")

	player.queue_free()


func test_camera_system() -> void:
	print("\n--- 5. Testing Camera System ---")
	var packed: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = packed.instantiate() as Player
	get_root().add_child(player)

	var cam: Camera2D = player.camera
	assert_true(cam != null, "Camera2D exists on Player")
	assert_true(cam.position_smoothing_enabled == true, "Camera position smoothing is enabled")
	assert_true(cam.position_smoothing_speed > 0.0, "Camera position smoothing speed is positive")

	player.queue_free()


func test_touch_controls_system() -> void:
	print("\n--- 6. Testing Touch Controls System ---")
	var packed: PackedScene = load("res://scenes/ui/touch_controls.tscn")
	assert_true(packed != null, "TouchControls scene loaded successfully")

	var touch_controls: TouchControls = packed.instantiate() as TouchControls
	touch_controls.force_visible = true
	get_root().add_child(touch_controls)

	assert_true(touch_controls.visible == true, "TouchControls is visible with force_visible")

	var joystick: TouchVirtualJoystick = touch_controls.virtual_joystick
	assert_true(joystick != null, "VirtualJoystick is present in TouchControls")

	# Test joystick drag vector simulation
	# Center is at size / 2.0 (50, 50). Dragging to (90, 50) is rightward
	var center := joystick.size / 2.0
	joystick._start_touch(0, center + Vector2(40, 0))
	var vec := joystick.get_current_vector()
	assert_true(vec.x > 0.8 and is_equal_approx(vec.y, 0.0), "Joystick produces normalized rightward vector on right drag")

	# Test release
	joystick._end_touch()
	assert_true(joystick.get_current_vector() == Vector2.ZERO, "Joystick resets vector to Vector2.ZERO on release")

	touch_controls.queue_free()
