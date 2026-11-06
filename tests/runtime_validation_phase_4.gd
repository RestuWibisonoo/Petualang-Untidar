extends SceneTree

## runtime_validation_phase_4.gd
## Comprehensive multi-frame runtime physics and combat simulation suite for Phase 4.
## Validates combat interactions, physics collisions, knockback against solid barriers,
## 2-stage combos, AI chase/attack behaviors, player I-frames, enemy death, and world transitions.

var _tests_passed: int = 0
var _tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_runtime_suite, CONNECT_ONE_SHOT)


func _run_runtime_suite() -> void:
	print("\n=======================================================")
	print(">>> STARTING PHASE 4 RUNTIME SIMULATION SUITE <<<")
	print("=======================================================\n")

	await _wait_frames(3)

	await test_runtime_player_attack_against_enemy()
	await test_runtime_knockback_obstacle_collision()
	await test_runtime_combo_chain_execution()
	await test_runtime_enemy_aggro_and_chase()
	await test_runtime_enemy_attack_and_player_iframes()
	await test_runtime_enemy_death_and_cleanup()
	await test_runtime_arena_scene_transition()

	_print_summary()


func _assert_test(condition: bool, test_name: String) -> void:
	_tests_passed if condition else _tests_failed
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % test_name)


func _wait_frames(count: int = 1) -> void:
	for i in range(count):
		await process_frame


func _wait_physics_frames(count: int = 1) -> void:
	for i in range(count):
		await physics_frame


func test_runtime_player_attack_against_enemy() -> void:
	print("--- 1. Testing Runtime Player Attack vs Enemy Interaction ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime1") as BaseEnemy

	_assert_test(player != null, "Player found in arena")
	_assert_test(enemy != null, "Enemy found in arena")

	# Position player facing enemy at close range
	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(16, 0)
	player.last_movement_direction = Vector2.RIGHT

	var floating_texts: Array[String] = []
	var event_bus: Node = get_root().get_node_or_null("EventBus")
	if event_bus and event_bus.has_signal("show_floating_text"):
		event_bus.show_floating_text.connect(func(text, _pos, _color): floating_texts.append(text))

	var initial_enemy_hp: int = enemy.health_component.current_health
	var initial_enemy_x: float = enemy.global_position.x

	# Trigger Player attack
	player.trigger_attack()
	_assert_test(player.state_machine.get_current_state_name() == &"attack", "Player entered Attack state")

	# Advance through startup into active window (approx 10 physics frames at 60 fps)
	await _wait_physics_frames(12)

	_assert_test(enemy.health_component.current_health < initial_enemy_hp, "Enemy HP decreased after player attack landed")
	_assert_test(enemy.health_component.current_health == initial_enemy_hp - (15 - enemy.defense), "Enemy damage correctly equals 15 raw - 2 def = 13")
	_assert_test(enemy.global_position.x > initial_enemy_x, "Enemy was physically displaced rightward by knockback")
	_assert_test(not floating_texts.is_empty(), "Combat emitted show_floating_text event")
	_assert_test(floating_texts.has("13"), "Floating text displayed exact damage value '13'")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_knockback_obstacle_collision() -> void:
	print("\n--- 2. Testing Knockback Obstacle Boundary Collision (Zero Clipping) ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime1") as BaseEnemy
	_assert_test(enemy != null, "Enemy located for obstacle collision test")

	# Position enemy right near the right world boundary (x = 160, boundary at x = 175)
	enemy.global_position = Vector2(160, 0)

	# Apply massive knockback directly into the wall (e.g. 800 px/s)
	enemy.velocity_component.apply_knockback(Vector2(800, 0))

	# Advance physics simulation for 30 frames
	for f in range(30):
		await _wait_physics_frames(1)

	# Verify enemy remained inside boundary (x must not exceed 165 px)
	_assert_test(enemy.global_position.x <= 165.0, "Enemy knockback cleanly halted by wall collider without clipping (x <= 165)")
	_assert_test(enemy.global_position.x >= 155.0, "Enemy remains flush against obstacle")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_combo_chain_execution() -> void:
	print("\n--- 3. Testing Runtime 2-Stage Combo Chain & Buffering ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime2") as BaseEnemy

	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(14, 0)
	player.last_movement_direction = Vector2.RIGHT

	# Stage 1: Trigger initial attack
	player.trigger_attack()
	var attack_state: PlayerAttackState = player.state_machine.get_node("Attack") as PlayerAttackState
	_assert_test(attack_state.combo_stage == 1, "Player started combo at Stage 1")

	# Wait until active window, then buffer second attack
	await _wait_physics_frames(7)
	player.trigger_attack() # Buffer combo attack
	_assert_test(attack_state._combo_buffered, "Second attack input buffered during Stage 1 window")

	# Wait for transition into Stage 2
	await _wait_physics_frames(14)
	_assert_test(attack_state.combo_stage == 2, "Attack successfully transitioned into Combo Stage 2")
	_assert_test(player.hitbox_component.damage == 25, "Combo Stage 2 delivers elevated damage (25)")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_enemy_aggro_and_chase() -> void:
	print("\n--- 4. Testing Runtime Enemy Aggro & Pursuit Behavior ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime1") as BaseEnemy

	# Place enemy within aggro radius (100 px away, aggro_radius = 120.0)
	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(80, 0)

	var initial_distance := enemy.global_position.distance_to(player.global_position)

	# Simulate AI decisions over 25 physics frames
	await _wait_physics_frames(25)

	_assert_test(enemy.state_machine.get_current_state_name() == &"chase", "Enemy detected player and entered Chase state")
	var current_distance := enemy.global_position.distance_to(player.global_position)
	_assert_test(current_distance < initial_distance, "Enemy pursued player (distance decreased from %.1f to %.1f)" % [initial_distance, current_distance])

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_enemy_attack_and_player_iframes() -> void:
	print("\n--- 5. Testing Runtime Enemy Attack & Player I-Frames Protection ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime1") as BaseEnemy

	# Position enemy right beside player (within attack_range = 24.0)
	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(16, 0)

	var initial_player_hp: int = player.health_component.current_health

	# Wait for enemy to transition from chase to attack
	await _wait_physics_frames(15)

	_assert_test(enemy.state_machine.get_current_state_name() == &"attack", "Enemy entered Attack state when adjacent to player")

	# Wait for active hit window
	await _wait_physics_frames(12)

	_assert_test(player.health_component.current_health < initial_player_hp, "Player received damage from enemy attack")
	_assert_test(player.hurtbox_component.is_invulnerable, "Player Hurtbox is currently invulnerable (I-Frames active)")

	var hp_after_first_hit := player.health_component.current_health

	# Simulate 5 more frames while in I-frames to ensure no repeated damage ticks
	await _wait_physics_frames(5)
	_assert_test(player.health_component.current_health == hp_after_first_hit, "Player I-Frames successfully prevented multi-tick damage during attack")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_enemy_death_and_cleanup() -> void:
	print("\n--- 6. Testing Runtime Enemy Death, Defeat Signal & Node Cleanup ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime1") as BaseEnemy

	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(14, 0)
	player.last_movement_direction = Vector2.RIGHT

	# Reduce enemy HP so the next player hit will be lethal
	enemy.health_component.current_health = 10

	var defeat_events: Array[StringName] = []
	var event_bus: Node = get_root().get_node_or_null("EventBus")
	if event_bus and event_bus.has_signal("enemy_defeated"):
		event_bus.enemy_defeated.connect(func(id): defeat_events.append(id))

	# Player attacks with lethal hit
	player.trigger_attack()
	await _wait_physics_frames(12)

	_assert_test(enemy.is_dead, "Enemy marked is_dead after lethal hit")
	_assert_test(defeat_events.size() == 1, "EventBus emitted enemy_defeated exactly once on runtime death")
	_assert_test(defeat_events[0] == &"dummy_slime_1", "enemy_defeated event carries correct enemy_id")

	# Wait for death animation tween and queue_free (approx 0.35s = ~25 frames)
	await _wait_physics_frames(30)
	_assert_test(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "Enemy node safely queued for deletion / freed from tree")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_arena_scene_transition() -> void:
	print("\n--- 7. Testing World Scene Transitions between Outdoor & Arena ---")

	var scene_manager: Node = get_root().get_node_or_null("SceneManager")
	_assert_test(scene_manager != null, "SceneManager autoload is accessible")

	# Initial load into Outdoor scene via standard scene tree
	change_scene_to_file("res://scenes/world/outdoor_test.tscn")
	await process_frame
	await process_frame

	var outdoor: WorldBase = current_scene as WorldBase
	_assert_test(outdoor != null, "Initial Outdoor scene loaded")

	# Initiate transition into Combat Arena with spawn marker 'default'
	scene_manager.change_scene_with_spawn("res://scenes/world/combat_arena.tscn", &"default", true, 0.05)
	
	var timeout: int = 0
	while scene_manager.is_transitioning() and timeout < 60:
		await process_frame
		timeout += 1

	var arena: WorldBase = current_scene as WorldBase
	_assert_test(arena is CombatArena, "Current active scene is CombatArena after transition")
	var arena_player: Player = arena.get_node_or_null("YSortEntities/Player") as Player if arena else null
	_assert_test(arena_player != null, "Player successfully spawned in CombatArena")
	_assert_test(not scene_manager.is_transitioning(), "Scene transition finished without blocking state")

	# Return to Outdoor Campus
	scene_manager.change_scene_with_spawn("res://scenes/world/outdoor_test.tscn", &"from_arena", true, 0.05)
	
	timeout = 0
	while scene_manager.is_transitioning() and timeout < 60:
		await process_frame
		timeout += 1

	var returned_outdoor: WorldBase = current_scene as WorldBase
	_assert_test(returned_outdoor is WorldBase and not (returned_outdoor is CombatArena), "Successfully returned to Outdoor Campus level")
	var outdoor_player: Player = returned_outdoor.get_node_or_null("YSortEntities/Player") as Player if returned_outdoor else null
	_assert_test(outdoor_player != null, "Player present in Outdoor scene after return transition")
	_assert_test(outdoor_player != null and is_equal_approx(outdoor_player.global_position.x, -150.0), "Player positioned at 'from_arena' spawn marker (-150, 40)")


func _print_summary() -> void:
	print("\n=======================================================")
	print(">>> RUNTIME SIMULATION SUMMARY <<<")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("=======================================================\n")

	if _tests_failed == 0:
		print("[SUCCESS] All Phase 4 runtime simulations passed with 0 errors!\n")
		quit(0)
	else:
		printerr("[ERROR] Phase 4 runtime simulation failed with %d errors!\n" % _tests_failed)
		quit(1)
