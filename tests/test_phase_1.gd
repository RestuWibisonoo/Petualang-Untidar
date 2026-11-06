extends SceneTree

## test_phase_1.gd
## Automated validation suite for Phase 1: Project Foundation.

var tests_passed: int = 0
var tests_failed: int = 0


func _init() -> void:
	# Wait for the first frame so Autoload singletons are mounted in the SceneTree
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)


func _run_all_tests() -> void:
	print("\n=======================================================")
	print(">>> STARTING PHASE 1 AUTOMATED VALIDATION SUITE <<<")
	print("=======================================================\n")

	test_project_settings()
	test_input_map()
	test_autoloads()
	test_health_component()
	test_velocity_component()
	test_hitbox_hurtbox()
	test_state_machine()

	print("\n=======================================================")
	print(">>> VALIDATION SUMMARY <<<")
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("=======================================================")

	if tests_failed == 0:
		print("\n[SUCCESS] All Phase 1 foundation components validated with 0 errors!\n")
	else:
		push_error("\n[FAILURE] %d tests failed!\n" % tests_failed)

	quit(0 if tests_failed == 0 else 1)


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		tests_failed += 1
		printerr("  [FAIL] %s" % test_name)


func test_project_settings() -> void:
	print("--- 1. Testing Project Settings ---")
	assert_true(ProjectSettings.get_setting("display/window/size/viewport_width") == 640, "Viewport width is 640")
	assert_true(ProjectSettings.get_setting("display/window/size/viewport_height") == 360, "Viewport height is 360")
	assert_true(ProjectSettings.get_setting("display/window/stretch/mode") == "viewport", "Stretch mode is 'viewport'")
	assert_true(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "Stretch aspect is 'keep'")
	assert_true(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "Default texture filter is Nearest (0)")
	assert_true(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel") == true, "Snap 2D transforms to pixel is enabled")
	assert_true(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel") == true, "Snap 2D vertices to pixel is enabled")
	assert_true(ProjectSettings.get_setting("display/window/handheld/orientation") == 6, "Orientation is sensor_landscape (6)")
	assert_true(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Renderer is gl_compatibility")


func test_input_map() -> void:
	print("\n--- 2. Testing Input Map Actions ---")
	var required_actions: Array[StringName] = [
		&"move_up", &"move_down", &"move_left", &"move_right",
		&"interact", &"attack", &"dodge", &"skill_primary", &"skill_secondary",
		&"inventory", &"character", &"quest_log", &"map", &"pause"
	]

	for action in required_actions:
		assert_true(InputMap.has_action(action), "InputMap contains action: '%s'" % action)


func test_autoloads() -> void:
	print("\n--- 3. Testing Autoloads ---")
	var tree_root := get_root()
	assert_true(tree_root.has_node("EventBus"), "Root has EventBus singleton")
	assert_true(tree_root.has_node("GameManager"), "Root has GameManager singleton")
	assert_true(tree_root.has_node("AudioManager"), "Root has AudioManager singleton")
	assert_true(tree_root.has_node("SceneManager"), "Root has SceneManager singleton")

	# Test GameManager state change & pause
	var gm: Node = tree_root.get_node("GameManager")
	gm.change_state(gm.GameState.PLAYING)
	assert_true(gm.current_state == gm.GameState.PLAYING, "GameManager state set to PLAYING")
	gm.pause_game()
	assert_true(gm.current_state == gm.GameState.PAUSED, "GameManager pause_game() sets state to PAUSED")
	assert_true(gm.is_paused() == true, "GameManager.is_paused() returns true")
	gm.resume_game()
	assert_true(gm.current_state == gm.GameState.PLAYING, "GameManager resume_game() restores state")


func test_health_component() -> void:
	print("\n--- 4. Testing HealthComponent ---")
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100

	var flags := {
		"health_changed": false,
		"damage_taken": false,
		"healed": false,
		"died": false
	}

	health.health_changed.connect(func(_cur: int, _max: int) -> void: flags["health_changed"] = true)
	health.damage_taken.connect(func(_amount: int) -> void: flags["damage_taken"] = true)
	health.healed.connect(func(_amount: int) -> void: flags["healed"] = true)
	health.died.connect(func() -> void: flags["died"] = true)

	health.take_damage(30)
	assert_true(health.current_health == 70, "Health reduced to 70 after 30 damage")
	assert_true(flags["health_changed"] and flags["damage_taken"], "Damage signals fired correctly")

	health.heal(20)
	assert_true(health.current_health == 90, "Health increased to 90 after 20 heal")
	assert_true(flags["healed"], "Heal signal fired correctly")

	health.take_damage(100)
	assert_true(health.current_health == 0, "Health clamped to 0 after lethal damage")
	assert_true(flags["died"], "Died signal fired on lethal damage")
	assert_true(health.is_alive() == false, "is_alive() returns false when HP is 0")
	health.free()


func test_velocity_component() -> void:
	print("\n--- 5. Testing VelocityComponent ---")
	var velocity_comp := VelocityComponent.new()
	velocity_comp.max_speed = 100.0
	velocity_comp.acceleration = 1000.0
	velocity_comp.friction = 500.0

	velocity_comp.accelerate_in_direction(Vector2.RIGHT, 0.1)
	assert_true(velocity_comp.velocity.x > 0.0, "Velocity accelerates rightward")

	velocity_comp.stop()
	assert_true(velocity_comp.velocity == Vector2.ZERO, "VelocityComponent stop() resets velocity")
	velocity_comp.free()


func test_hitbox_hurtbox() -> void:
	print("\n--- 6. Testing Hitbox & Hurtbox Components ---")
	var hitbox := HitboxComponent.new()
	hitbox.damage = 25
	hitbox.is_active = true

	var hurtbox := HurtboxComponent.new()
	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100
	hurtbox.health_component = health
	hurtbox.invulnerability_duration = 0.0 # Instant for test

	get_root().add_child(hitbox)
	get_root().add_child(hurtbox)

	var flags := {"hit_detected": false}
	hurtbox.hit_received.connect(func(_hb: HitboxComponent) -> void: flags["hit_detected"] = true)

	hurtbox.receive_hit(hitbox)
	assert_true(flags["hit_detected"], "Hurtbox received hit signal")
	assert_true(health.current_health == 75, "Damage correctly forwarded from Hurtbox to HealthComponent (100 -> 75)")

	hitbox.queue_free()
	hurtbox.queue_free()
	health.queue_free()


func test_state_machine() -> void:
	print("\n--- 7. Testing StateMachine & State ---")
	var sm := StateMachine.new()
	var dummy_owner := Node2D.new()
	get_root().add_child(dummy_owner)
	dummy_owner.add_child(sm)

	# Create two mock states
	var state_a := State.new()
	state_a.name = "Idle"
	var state_b := State.new()
	state_b.name = "Move"

	sm.add_child(state_a)
	sm.add_child(state_b)
	sm.initial_state = state_a

	# Re-trigger state registration
	sm._setup_states()

	assert_true(sm.current_state == state_a, "StateMachine initial state is 'Idle'")

	var flags := {"transitioned": false}
	sm.transitioned.connect(func(st_name: StringName) -> void:
		if st_name == &"move":
			flags["transitioned"] = true
	)

	sm.transition_to(&"move")
	assert_true(sm.current_state == state_b, "StateMachine transitioned to 'Move'")
	assert_true(flags["transitioned"], "transitioned signal emitted on state change")

	dummy_owner.queue_free()
