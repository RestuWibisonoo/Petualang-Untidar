extends SceneTree

## test_phase_4.gd
## Automated validation suite for Phase 4: Combat System
## Validates combat collision matrix, damage calculations, defense absorption, knockback physics,
## I-Frames authority, faction filtering, 2-stage attack combos, and BaseEnemy lifecycle.

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0


func _init() -> void:
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)


func _run_all_tests() -> void:
	print("\n=======================================================")
	print(">>> STARTING PHASE 4 AUTOMATED VALIDATION SUITE <<<")
	print("=======================================================\n")

	test_combat_collision_matrix()
	test_damage_and_defense_calculations()
	test_knockback_physics_and_friction()
	test_iframes_and_single_hit_tracking()
	test_faction_filtering()
	test_player_attack_state_and_combo_system()
	test_base_enemy_instantiation_and_components()
	test_base_enemy_fsm_and_lifecycle()
	test_combat_arena_scene_structure()

	_print_summary()


func _assert_test(condition: bool, test_name: String) -> void:
	_total_tests += 1
	if condition:
		_passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed_tests += 1
		printerr("  [FAIL] %s" % test_name)


func test_combat_collision_matrix() -> void:
	print("--- 1. Testing Combat Collision Matrix & Layers ---")

	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	_assert_test(player_scene != null, "Player scene loaded")
	var player: Player = player_scene.instantiate() as Player
	get_root().add_child(player)

	# Player body: Layer 2 (Player Body), Mask 17 (World 1 | Enemy Body 16)
	_assert_test(player.collision_layer == 2, "Player body collision_layer is Layer 2 (bit 1: 2)")
	_assert_test((player.collision_mask & 1) != 0, "Player body detects Layer 1 (World)")
	_assert_test((player.collision_mask & 16) != 0, "Player body detects Layer 5 (Enemy Body: 16)")

	# Player Hurtbox & Hitbox
	_assert_test(player.hurtbox_component != null, "Player has HurtboxComponent")
	_assert_test(player.hurtbox_component.collision_layer == 4, "Player Hurtbox collision_layer is Layer 3 (bit 2: 4)")
	_assert_test(player.hurtbox_component.collision_mask == 64, "Player Hurtbox collision_mask is Layer 7 (Enemy Hitbox: 64)")

	_assert_test(player.hitbox_component != null, "Player has HitboxComponent")
	_assert_test(player.hitbox_component.collision_layer == 8, "Player Hitbox collision_layer is Layer 4 (bit 3: 8)")
	_assert_test(player.hitbox_component.collision_mask == 32, "Player Hitbox collision_mask is Layer 6 (Enemy Hurtbox: 32)")

	# Enemy
	var enemy_scene: PackedScene = load("res://scenes/enemy/base_enemy.tscn")
	_assert_test(enemy_scene != null, "BaseEnemy scene loaded")
	var enemy: BaseEnemy = enemy_scene.instantiate() as BaseEnemy
	get_root().add_child(enemy)

	# Enemy body: Layer 5 (16), Mask 19 (World 1 | Player Body 2 | Enemy Body 16)
	_assert_test(enemy.collision_layer == 16, "Enemy body collision_layer is Layer 5 (bit 4: 16)")
	_assert_test((enemy.collision_mask & 1) != 0, "Enemy body detects Layer 1 (World)")
	_assert_test((enemy.collision_mask & 2) != 0, "Enemy body detects Layer 2 (Player Body: 2)")
	_assert_test((enemy.collision_mask & 16) != 0, "Enemy body detects Layer 5 (Enemy Body: 16)")

	# Enemy Hurtbox & Hitbox
	_assert_test(enemy.hurtbox_component != null, "Enemy has HurtboxComponent")
	_assert_test(enemy.hurtbox_component.collision_layer == 32, "Enemy Hurtbox collision_layer is Layer 6 (bit 5: 32)")
	_assert_test(enemy.hurtbox_component.collision_mask == 8, "Enemy Hurtbox collision_mask is Layer 4 (Player Hitbox: 8)")

	_assert_test(enemy.hitbox_component != null, "Enemy has HitboxComponent")
	_assert_test(enemy.hitbox_component.collision_layer == 64, "Enemy Hitbox collision_layer is Layer 7 (bit 6: 64)")
	_assert_test(enemy.hitbox_component.collision_mask == 4, "Enemy Hitbox collision_mask is Layer 3 (Player Hurtbox: 4)")

	player.queue_free()
	enemy.queue_free()


func test_damage_and_defense_calculations() -> void:
	print("\n--- 2. Testing Damage & Defense Absorption ---")

	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100

	var hurtbox := HurtboxComponent.new()
	hurtbox.health_component = health
	hurtbox.defense = 5
	hurtbox.faction = HurtboxComponent.Faction.NEUTRAL

	var hitbox := HitboxComponent.new()
	hitbox.faction = HitboxComponent.Faction.PLAYER
	hitbox.damage = 20
	hitbox.is_active = true

	# Test 1: Standard damage absorption (20 raw - 5 defense = 15 final damage)
	hurtbox.receive_hit(hitbox)
	_assert_test(health.current_health == 85, "Damage correctly calculated: 20 raw - 5 defense = 15 taken (100 -> 85)")

	# Test 2: Damage less than or equal to defense is completely ignored
	hurtbox.is_invulnerable = false
	hitbox.reset_hit_targets()
	hitbox.damage = 4 # Less than 5 defense
	hurtbox.receive_hit(hitbox)
	_assert_test(health.current_health == 85, "Attacks where raw damage <= defense deal 0 damage and are ignored (HP stays 85)")

	# Test 3: Dead entity takes no damage
	health.current_health = 0
	hurtbox.is_invulnerable = false
	hitbox.reset_hit_targets()
	hitbox.damage = 50
	hurtbox.receive_hit(hitbox)
	_assert_test(health.current_health == 0, "Dead entity with 0 HP does not process hits")

	health.free()
	hurtbox.free()
	hitbox.free()


func test_knockback_physics_and_friction() -> void:
	print("\n--- 3. Testing Directional Knockback & Friction Decay ---")

	var body := CharacterBody2D.new()
	var velocity_comp := VelocityComponent.new()
	velocity_comp.knockback_friction = 1000.0
	body.add_child(velocity_comp)
	get_root().add_child(body)

	# Apply knockback vector
	var impulse := Vector2(200.0, 0.0)
	velocity_comp.apply_knockback(impulse)
	_assert_test(velocity_comp.knockback_velocity == impulse, "VelocityComponent.apply_knockback sets knockback_velocity accurately")

	# Apply to body includes knockback velocity
	velocity_comp.apply_to_body(body, 0.0)
	_assert_test(body.velocity == impulse, "apply_to_body integrates knockback into body.velocity")

	# Decay after 0.1s: 200 - (1000 * 0.1) = 100
	velocity_comp.update_knockback(0.1)
	_assert_test(is_equal_approx(velocity_comp.knockback_velocity.x, 100.0), "Knockback friction decays impulse: 200 - (1000 * 0.1) = 100")

	# Decay beyond threshold stops at zero
	velocity_comp.update_knockback(0.2)
	_assert_test(velocity_comp.knockback_velocity == Vector2.ZERO, "Knockback velocity cleanly stops at Vector2.ZERO when dissipated")

	body.queue_free()


func test_iframes_and_single_hit_tracking() -> void:
	print("\n--- 4. Testing I-Frames Authority & Single-Hit Tracking ---")

	var health := HealthComponent.new()
	health.max_health = 100
	health.current_health = 100

	var hurtbox := HurtboxComponent.new()
	hurtbox.health_component = health
	hurtbox.defense = 0
	hurtbox.invulnerability_duration = 0.5
	get_root().add_child(hurtbox)

	var hitbox := HitboxComponent.new()
	hitbox.damage = 15
	hitbox.is_active = true

	# First hit lands
	hurtbox.receive_hit(hitbox)
	_assert_test(health.current_health == 85, "First hit dealt 15 damage (100 -> 85)")
	_assert_test(hurtbox.is_invulnerable, "Hurtbox entered invulnerability state")
	_assert_test(health.is_invulnerable, "HealthComponent synchronized with Hurtbox invulnerability")
	_assert_test(hitbox.has_hit_target(hurtbox), "Hitbox registered target in _hit_targets list")

	# Repeated hit while in I-Frames is blocked
	hurtbox.receive_hit(hitbox)
	_assert_test(health.current_health == 85, "Repeated hit while invulnerable is blocked")

	# Even if hitbox resets target tracking, hurtbox invulnerability blocks damage
	hitbox.reset_hit_targets()
	hurtbox.receive_hit(hitbox)
	_assert_test(health.current_health == 85, "Hurtbox invulnerability protects against fresh hitbox swings while active")

	# Single-hit tracking check when not invulnerable
	hurtbox.is_invulnerable = false
	hitbox.notify_hit(hurtbox)
	hurtbox.receive_hit(hitbox)
	_assert_test(health.current_health == 85, "Hitbox single-hit tracking prevents multi-tick damage from the same attack swing")

	health.free()
	hurtbox.queue_free()
	hitbox.free()


func test_faction_filtering() -> void:
	print("\n--- 5. Testing Faction Filtering & Friendly Fire Prevention ---")

	var player_hurtbox := HurtboxComponent.new()
	var player_health := HealthComponent.new()
	player_health.max_health = 100
	player_health.current_health = 100
	player_hurtbox.health_component = player_health
	player_hurtbox.faction = HurtboxComponent.Faction.PLAYER

	var player_hitbox := HitboxComponent.new()
	player_hitbox.faction = HitboxComponent.Faction.PLAYER
	player_hitbox.damage = 25
	player_hitbox.is_active = true

	# Case A: Player vs Player (Friendly Fire)
	player_hurtbox.receive_hit(player_hitbox)
	_assert_test(player_health.current_health == 100, "Player Hitbox cannot damage Player Hurtbox (friendly fire blocked)")

	# Case B: Enemy vs Enemy (Friendly Fire)
	var enemy_hurtbox := HurtboxComponent.new()
	var enemy_health := HealthComponent.new()
	enemy_health.max_health = 50
	enemy_health.current_health = 50
	enemy_hurtbox.health_component = enemy_health
	enemy_hurtbox.faction = HurtboxComponent.Faction.ENEMY

	var enemy_hitbox := HitboxComponent.new()
	enemy_hitbox.faction = HitboxComponent.Faction.ENEMY
	enemy_hitbox.damage = 10
	enemy_hitbox.is_active = true

	enemy_hurtbox.receive_hit(enemy_hitbox)
	_assert_test(enemy_health.current_health == 50, "Enemy Hitbox cannot damage Enemy Hurtbox (friendly fire blocked)")

	# Case C: Player vs Enemy (Hostile hit allowed)
	player_hitbox.reset_hit_targets()
	enemy_hurtbox.receive_hit(player_hitbox)
	_assert_test(enemy_health.current_health == 25, "Player Hitbox successfully damages Enemy Hurtbox (50 -> 25)")

	# Case D: Enemy vs Player (Hostile hit allowed)
	enemy_hitbox.reset_hit_targets()
	player_hurtbox.receive_hit(enemy_hitbox)
	_assert_test(player_health.current_health == 90, "Enemy Hitbox successfully damages Player Hurtbox (100 -> 90)")

	player_hurtbox.free()
	player_health.free()
	player_hitbox.free()
	enemy_hurtbox.free()
	enemy_health.free()
	enemy_hitbox.free()


func test_player_attack_state_and_combo_system() -> void:
	print("\n--- 6. Testing Player Attack State & 2-Stage Combo System ---")

	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = player_scene.instantiate() as Player
	get_root().add_child(player)

	var fsm: StateMachine = player.state_machine
	var attack_state := fsm.get_node_or_null("Attack") as PlayerAttackState
	_assert_test(attack_state != null, "Player StateMachine contains PlayerAttackState")

	_assert_test(attack_state.stage_1_damage == 15, "Combo Stage 1 damage is 15")
	_assert_test(attack_state.stage_1_knockback == 120.0, "Combo Stage 1 knockback is 120.0")
	_assert_test(attack_state.stage_2_damage == 25, "Combo Stage 2 damage is 25")
	_assert_test(attack_state.stage_2_knockback == 200.0, "Combo Stage 2 knockback is 200.0")

	# Enter Attack State: Stage 1
	player.last_movement_direction = Vector2.RIGHT
	fsm.transition_to(&"attack")
	_assert_test(fsm.get_current_state_name() == &"attack", "Player transitioned to Attack state")
	_assert_test(attack_state.combo_stage == 1, "Initial attack combo stage is 1")
	_assert_test(player.hitbox_component.damage == 15, "Hitbox damage configured to 15 for stage 1")
	_assert_test(player.hitbox_component.knockback_force == 120.0, "Hitbox knockback configured to 120.0 for stage 1")
	_assert_test(player.hitbox_component.position.x > 0.0, "Hitbox oriented toward facing direction (right)")

	# Simulate active window
	attack_state.physics_update(attack_state.startup_duration + 0.01)
	_assert_test(player.hitbox_component.is_active, "Hitbox is active during attack active window")

	# Buffer combo input
	attack_state.buffer_combo_input()
	_assert_test(attack_state._combo_buffered, "Combo input buffered successfully during active window")

	# Complete stage 1 to trigger combo transition into Stage 2
	attack_state.physics_update(attack_state.active_duration + attack_state.recovery_duration + 0.05)
	_assert_test(attack_state.combo_stage == 2, "Attack successfully progressed to Combo Stage 2")
	_assert_test(player.hitbox_component.damage == 25, "Hitbox damage elevated to 25 for stage 2")
	_assert_test(player.hitbox_component.knockback_force == 200.0, "Hitbox knockback elevated to 200.0 for stage 2")

	# Exit attack back to Idle
	attack_state.physics_update(attack_state.startup_duration + attack_state.active_duration + attack_state.recovery_duration + 0.05)
	_assert_test(fsm.get_current_state_name() == &"idle", "Player cleanly returned to Idle state after combo completion")

	player.queue_free()


func test_base_enemy_instantiation_and_components() -> void:
	print("\n--- 7. Testing BaseEnemy Instantiation & Parameters ---")

	var enemy_scene: PackedScene = load("res://scenes/enemy/base_enemy.tscn")
	var enemy: BaseEnemy = enemy_scene.instantiate() as BaseEnemy
	get_root().add_child(enemy)

	_assert_test(enemy.enemy_id == &"dummy_slime", "BaseEnemy enemy_id is 'dummy_slime'")
	_assert_test(enemy.max_health == 50, "BaseEnemy max_health is 50")
	_assert_test(enemy.defense == 2, "BaseEnemy defense is 2")
	_assert_test(enemy.move_speed == 50.0, "BaseEnemy move_speed is 50.0")
	_assert_test(enemy.aggro_radius == 120.0, "BaseEnemy aggro_radius is 120.0")
	_assert_test(enemy.deaggro_radius == 180.0, "BaseEnemy deaggro_radius is 180.0")
	_assert_test(enemy.attack_range == 24.0, "BaseEnemy attack_range is 24.0")
	_assert_test(enemy.attack_cooldown == 1.0, "BaseEnemy attack_cooldown is 1.0")
	_assert_test(enemy.base_damage == 10, "BaseEnemy base_damage is 10")
	_assert_test(enemy.is_in_group(&"enemy"), "BaseEnemy is registered in 'enemy' group")

	enemy.queue_free()


func test_base_enemy_fsm_and_lifecycle() -> void:
	print("\n--- 8. Testing BaseEnemy FSM States & Death Lifecycle ---")

	var enemy_scene: PackedScene = load("res://scenes/enemy/base_enemy.tscn")
	var enemy: BaseEnemy = enemy_scene.instantiate() as BaseEnemy
	get_root().add_child(enemy)

	var fsm: StateMachine = enemy.state_machine
	_assert_test(fsm != null, "BaseEnemy contains StateMachine")
	_assert_test(fsm.get_current_state_name() == &"idle", "BaseEnemy initial state is 'idle'")
	_assert_test(fsm.has_node("Chase"), "StateMachine contains 'Chase' state")
	_assert_test(fsm.has_node("Attack"), "StateMachine contains 'Attack' state")
	_assert_test(fsm.has_node("Hurt"), "StateMachine contains 'Hurt' state")

	# Test Cooldown logic
	_assert_test(enemy.can_attack(), "BaseEnemy can_attack() is true initially")
	enemy.start_attack_cooldown()
	_assert_test(not enemy.can_attack(), "BaseEnemy can_attack() is false during cooldown")
	enemy._physics_process(1.1)
	_assert_test(enemy.can_attack(), "BaseEnemy can_attack() restored after cooldown expires")

	# Test Hurt transition on receiving damage
	var test_hitbox := HitboxComponent.new()
	test_hitbox.damage = 10
	test_hitbox.faction = HitboxComponent.Faction.PLAYER
	test_hitbox.is_active = true
	enemy.hurtbox_component.receive_hit(test_hitbox)
	_assert_test(fsm.get_current_state_name() == &"hurt", "BaseEnemy transitioned to 'hurt' state on receiving damage")

	# Test Death lifecycle and single defeat signal emission
	var defeat_signal_count: Array[int] = [0]
	var bus_signal_count: Array[int] = [0]
	enemy.defeated.connect(func(_id, _p): defeat_signal_count[0] += 1)
	var event_bus: Node = get_root().get_node_or_null("EventBus")
	if event_bus and event_bus.has_signal("enemy_defeated"):
		event_bus.enemy_defeated.connect(func(_id): bus_signal_count[0] += 1)

	# Deal lethal damage (clear i-frames from previous hit first)
	enemy.hurtbox_component.is_invulnerable = false
	enemy.health_component.is_invulnerable = false
	enemy.health_component.take_damage(100)
	_assert_test(enemy.is_dead, "BaseEnemy marked is_dead on lethal damage")
	_assert_test(defeat_signal_count[0] == 1, "BaseEnemy emitted defeated signal exactly once")
	_assert_test(bus_signal_count[0] == 1, "EventBus emitted enemy_defeated signal exactly once")

	# Secondary damage attempt on dead enemy
	enemy._on_died()
	_assert_test(defeat_signal_count[0] == 1, "Repeated death trigger does not emit duplicate defeated signal")

	test_hitbox.free()
	enemy.queue_free()


func test_combat_arena_scene_structure() -> void:
	print("\n--- 9. Testing Combat Arena Scene & Structure ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	_assert_test(arena_scene != null, "combat_arena.tscn loaded successfully")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)

	_assert_test(arena is WorldBase, "CombatArena root inherits WorldBase")
	_assert_test(arena.level_name == "Arena Latihan Tempur Untidar", "CombatArena level_name set correctly")
	_assert_test(arena.has_node("GroundLayer"), "CombatArena contains GroundLayer")
	_assert_test(arena.has_node("WorldBoundaries"), "CombatArena contains WorldBoundaries")
	_assert_test(arena.has_node("YSortEntities"), "CombatArena contains YSortEntities")
	_assert_test(arena.has_node("YSortEntities/Player"), "CombatArena contains Player in YSortEntities")
	_assert_test(arena.has_node("YSortEntities/DummySlime1"), "CombatArena contains DummySlime1")
	_assert_test(arena.has_node("YSortEntities/DummySlime2"), "CombatArena contains DummySlime2")
	_assert_test(arena.has_node("YSortEntities/Interactables/ExitDoor"), "CombatArena contains ExitDoor to Outdoor")
	_assert_test(arena.has_node("SpawnPoints/default"), "CombatArena contains default spawn point")
	_assert_test(arena.has_node("SpawnPoints/from_outdoor"), "CombatArena contains from_outdoor spawn point")
	_assert_test(arena.has_node("TouchControls"), "CombatArena contains TouchControls")
	_assert_test(arena.has_node("HUD"), "CombatArena contains HUD")

	arena.queue_free()


func _print_summary() -> void:
	print("\n=======================================================")
	print(">>> PHASE 4 VALIDATION SUMMARY <<<")
	print("Passed: %d" % _passed_tests)
	print("Failed: %d" % _failed_tests)
	print("=======================================================\n")

	if _failed_tests == 0:
		print("[SUCCESS] All Phase 4 combat foundation components validated with 0 errors!\n")
		quit(0)
	else:
		printerr("[ERROR] Phase 4 combat validation failed with %d errors!\n" % _failed_tests)
		quit(1)
