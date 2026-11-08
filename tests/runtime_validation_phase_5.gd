extends SceneTree

## runtime_validation_phase_5.gd
## Multi-frame physics & runtime simulation suite for Phase 5: Loot, Inventory, Equipment, and Progression.
## Simulates combat lethal hits, loot table drop spawning, ground item physics pickup, live gear equipping,
## dynamic combat damage scaling, runtime EXP progression, and UI synchronization.

var _tests_passed: int = 0
var _tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_runtime_suite, CONNECT_ONE_SHOT)


func _run_runtime_suite() -> void:
	print("=======================================================")
	print(">>> STARTING PHASE 5 RUNTIME SIMULATION SUITE <<<")
	print("=======================================================")

	await test_runtime_enemy_defeat_and_loot_spawn()
	await test_runtime_world_item_pickup_into_inventory()
	await test_runtime_equipment_and_combat_impact()
	await test_runtime_exp_gain_and_level_up()
	await test_runtime_full_inventory_pickup_rejection()
	await test_runtime_partial_pickup_and_remainder()
	await test_runtime_dual_enemy_defeat_same_id()
	await test_runtime_ui_toggle_and_sync()
	await test_runtime_health_potion_synchronization()

	_print_summary()


func _assert_test(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		_tests_passed += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		_tests_failed += 1


func _wait_physics_frames(frames: int) -> void:
	for i in range(frames):
		await physics_frame


func test_runtime_enemy_defeat_and_loot_spawn() -> void:
	print("\n--- 1. Testing Runtime Enemy Defeat & World Item Drop Spawning ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime1") as BaseEnemy
	_assert_test(enemy != null and player != null, "CombatArena spawned with Player and DummySlime1")

	# Ensure LootSpawner is attached and registered
	var spawner: LootSpawner = arena.get_node_or_null("LootSpawner") as LootSpawner
	if not spawner:
		spawner = LootSpawner.new()
		spawner.name = "LootSpawner"
		arena.add_child(spawner)

	# Configure deterministic drop: 100% chance for testing
	var test_table := LootTable.new()
	var jelly_res: ItemData = load("res://resources/items/slime_jelly.tres") as ItemData
	test_table.entries.append(LootDropEntry.new(jelly_res, 1.0, 2, 2, 100))
	enemy.loot_table = test_table
	enemy.exp_reward = 40
	spawner.register_loot_table(enemy.enemy_id, test_table, 40)

	# Position player right in front of enemy
	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(16, 0)
	player.last_movement_direction = Vector2.RIGHT

	# Reduce enemy HP so next attack is lethal
	enemy.health_component.current_health = 10

	var defeat_emitted: Array[bool] = [false]
	var defeat_handler := func(_id): defeat_emitted[0] = true
	var event_bus: Node = get_root().get_node_or_null("EventBus")
	if event_bus:
		event_bus.enemy_defeated.connect(defeat_handler)

	# Player attacks with lethal hit
	player.trigger_attack()
	await _wait_physics_frames(12)

	_assert_test(enemy.is_dead, "Enemy killed by runtime attack hit")
	_assert_test(defeat_emitted[0], "EventBus emitted enemy_defeated on runtime death")

	# Allow 4 frames for loot spawner to instantiate ground items
	await _wait_physics_frames(4)

	var world_items := get_root().get_tree().get_nodes_in_group(&"world_item")
	_assert_test(not world_items.is_empty(), "WorldItem spawned on the ground upon enemy defeat")

	if not world_items.is_empty():
		var first_item := world_items[0] as WorldItem
		_assert_test(first_item.item_data.item_id == &"slime_jelly", "Spawned WorldItem matches loot table (Slime Jelly)")
		_assert_test(first_item.quantity == 2, "Spawned WorldItem carries correct quantity (2)")

	if event_bus:
		event_bus.enemy_defeated.disconnect(defeat_handler)
	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_world_item_pickup_into_inventory() -> void:
	print("\n--- 2. Testing Runtime WorldItem Physics Pickup & Inventory Addition ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	player.global_position = Vector2(0, 0)

	# Instantiate a WorldItem at (24, 0)
	var world_item_scene: PackedScene = load("res://scenes/objects/world_item.tscn")
	var world_item: WorldItem = world_item_scene.instantiate() as WorldItem
	var potion_res: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	world_item.item_data = potion_res
	world_item.quantity = 5
	world_item.pickup_cooldown = 0.05
	world_item.global_position = Vector2(24, 0)
	arena.get_node("YSortEntities").add_child(world_item)
	await _wait_physics_frames(3)

	var initial_potion_count := player.inventory_manager.get_item_count(&"health_potion")

	# Move player toward the world item to trigger Area2D body overlap
	player.global_position = Vector2(24, 0)
	await _wait_physics_frames(10)

	_assert_test(player.inventory_manager.get_item_count(&"health_potion") == initial_potion_count + 5, "Potions entered player inventory upon physical overlap")

	# Wait for pickup tween to finish queue_free
	await _wait_physics_frames(15)
	_assert_test(not is_instance_valid(world_item) or world_item.is_queued_for_deletion(), "WorldItem node safely cleaned up from world tree")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_equipment_and_combat_impact() -> void:
	print("\n--- 3. Testing Live Equipment Swapping & Dynamic Combat Damage Scaling ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime2") as BaseEnemy
	_assert_test(enemy != null, "DummySlime2 located in arena")

	# Baseline attack without equipment: Attack is 15. Enemy defense is 2.
	# Expected damage: 15 - 2 = 13.
	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(16, 0)
	player.last_movement_direction = Vector2.RIGHT

	var enemy_hp_before := enemy.health_component.current_health
	player.trigger_attack()
	await _wait_physics_frames(12)

	var dmg_baseline := enemy_hp_before - enemy.health_component.current_health
	_assert_test(dmg_baseline == 13, "Baseline attack hit dealt 13 damage (15 ATK - 2 DEF)")

	# Ensure player and enemy are reset to Idle before sword test
	await _wait_physics_frames(25)
	player.state_machine.transition_to(&"idle")
	enemy.state_machine.transition_to(&"idle")
	if enemy.hitbox_component:
		enemy.hitbox_component.is_active = false
	enemy.attack_cooldown_timer = 10.0

	# Now equip Iron Sword (+12 Attack, total 27 ATK)
	var iron_sword: EquipmentData = load("res://resources/equipment/iron_sword.tres") as EquipmentData
	player.inventory_manager.add_item(iron_sword, 1)
	player.equipment_manager.equip_from_inventory(0)
	_assert_test(player.character_stats.attack == 27, "Player attack elevated to 27")

	enemy.global_position = Vector2(16, 0)
	enemy.velocity_component.stop()
	enemy.health_component.current_health = 50
	player.global_position = Vector2(0, 0)
	player.last_movement_direction = Vector2.RIGHT

	player.trigger_attack()
	await _wait_physics_frames(15)

	# Expected damage: 27 - 2 = 25!
	var dmg_with_sword := 50 - enemy.health_component.current_health
	_assert_test(dmg_with_sword == 25, "Iron Sword attack hit dealt 25 damage (27 ATK - 2 DEF, +12 dmg increase)")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_exp_gain_and_level_up() -> void:
	print("\n--- 4. Testing Runtime Enemy Defeat EXP Reward & Level Up Event ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var enemy: BaseEnemy = arena.get_node_or_null("YSortEntities/DummySlime1") as BaseEnemy
	_assert_test(enemy != null, "DummySlime1 found for EXP test")

	var spawner: LootSpawner = arena.get_node_or_null("LootSpawner") as LootSpawner
	if not spawner:
		spawner = LootSpawner.new()
		spawner.name = "LootSpawner"
		arena.add_child(spawner)

	# Register enemy EXP reward
	enemy.exp_reward = 50
	spawner.exp_rewards[enemy.enemy_id] = 50

	player.character_stats.reset_all()
	_assert_test(player.character_stats.level == 1, "Player initial level is 1")
	_assert_test(player.character_stats.current_exp == 0, "Player initial EXP is 0")

	# Kill enemy
	player.global_position = Vector2(0, 0)
	enemy.global_position = Vector2(16, 0)
	player.last_movement_direction = Vector2.RIGHT
	enemy.health_component.current_health = 5

	player.trigger_attack()
	await _wait_physics_frames(15)

	# Verify EXP awarded
	_assert_test(player.character_stats.current_exp == 50, "Player awarded 50 EXP from defeated enemy")

	# Award remaining 50 EXP to trigger Level Up
	player.character_stats.add_experience(50)
	_assert_test(player.character_stats.level == 2, "Player reached Level 2")
	_assert_test(player.character_stats.available_stat_points == 3, "Player received 3 stat points on Level Up")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_full_inventory_pickup_rejection() -> void:
	print("\n--- 5. Testing Runtime Full Inventory Ground Rejection ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	player.global_position = Vector2(0, 0)

	# Completely fill player's 20 inventory slots with dummy items
	var sword_res: ItemData = load("res://resources/equipment/wooden_sword.tres") as ItemData
	for i in range(20):
		player.inventory_manager.add_item(sword_res, 1)
	_assert_test(player.inventory_manager.is_full(), "Player inventory is 100% full (20/20 slots)")

	# Drop a potion right under the player
	var world_item_scene: PackedScene = load("res://scenes/objects/world_item.tscn")
	var ground_item: WorldItem = world_item_scene.instantiate() as WorldItem
	var potion_res: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	ground_item.item_data = potion_res
	ground_item.quantity = 1
	ground_item.pickup_cooldown = 0.05
	ground_item.global_position = Vector2(0, 0)
	arena.get_node("YSortEntities").add_child(ground_item)

	# Advance physics frames while player stands on item
	await _wait_physics_frames(8)

	_assert_test(is_instance_valid(ground_item) and not ground_item._is_picked_up, "Item remains untouched on ground because inventory is full")

	# Free 1 slot in inventory
	player.inventory_manager.remove_item_from_slot(0, 1)
	_assert_test(not player.inventory_manager.is_full(), "Inventory has 1 open slot now")

	# Retrigger pickup by slight step
	ground_item.pickup(player)
	await _wait_physics_frames(6)

	_assert_test(ground_item._is_picked_up, "Item successfully picked up once slot became available")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_partial_pickup_and_remainder() -> void:
	print("\n--- 6. Testing Runtime Partial Pickup & Remainder Collection ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	player.global_position = Vector2(0, 0)
	player.inventory_manager.clear_inventory()

	# Fill 19 slots with swords, and 1 slot with 16 potions (so exactly 4 spaces remain)
	var sword_res: ItemData = load("res://resources/equipment/wooden_sword.tres") as ItemData
	for i in range(19):
		player.inventory_manager.add_item(sword_res, 1)
	var potion_res: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	player.inventory_manager.add_item(potion_res, 16)

	_assert_test(player.inventory_manager.get_available_space_for(potion_res) == 4, "Inventory has exactly 4 spaces for potions")

	# Drop WorldItem with 10 potions at (32, 0)
	var world_item_scene: PackedScene = load("res://scenes/objects/world_item.tscn")
	var ground_item: WorldItem = world_item_scene.instantiate() as WorldItem
	ground_item.item_data = potion_res
	ground_item.quantity = 10
	ground_item.pickup_cooldown = 0.05
	ground_item.global_position = Vector2(32, 0)
	arena.get_node("YSortEntities").add_child(ground_item)
	await _wait_physics_frames(3)

	# Move player toward ground item to trigger physical partial pickup
	player.global_position = Vector2(32, 0)
	await _wait_physics_frames(8)

	_assert_test(player.inventory_manager.get_item_count(&"health_potion") == 20, "Inventory received 4 potions via partial physical pickup (filled slot to 20)")
	_assert_test(ground_item.quantity == 6, "Ground item retained 6 remaining potions (10 - 4 = 6)")
	_assert_test(not ground_item._is_picked_up and is_instance_valid(ground_item), "Ground item still active in world after partial pickup")

	# Clear swords to make room for remaining 6 potions
	for i in range(19):
		player.inventory_manager.clear_slot(i)

	# Pickup remaining 6 potions
	ground_item.pickup_cooldown = 0.0
	ground_item.pickup(player)
	await _wait_physics_frames(6)

	_assert_test(player.inventory_manager.get_item_count(&"health_potion") == 26, "Inventory received remaining 6 potions (total 26)")
	_assert_test(ground_item.quantity == 0, "Ground item quantity reached 0")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_dual_enemy_defeat_same_id() -> void:
	print("\n--- 7. Testing Runtime Dual Enemy Defeat with Same Enemy ID ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	player.character_stats.reset_all()

	var spawner: LootSpawner = arena.get_node_or_null("LootSpawner") as LootSpawner
	if not spawner:
		spawner = LootSpawner.new()
		spawner.name = "LootSpawner"
		arena.add_child(spawner)

	var slime_scene: PackedScene = load("res://scenes/enemy/base_enemy.tscn")
	var enemy_a: BaseEnemy = slime_scene.instantiate() as BaseEnemy
	var enemy_b: BaseEnemy = slime_scene.instantiate() as BaseEnemy

	enemy_a.enemy_id = &"shared_slime"
	enemy_b.enemy_id = &"shared_slime"
	enemy_a.exp_reward = 30
	enemy_b.exp_reward = 30

	var test_loot := LootTable.new()
	var jelly_res: ItemData = load("res://resources/items/slime_jelly.tres") as ItemData
	test_loot.entries.append(LootDropEntry.new(jelly_res, 1.0, 1, 1, 100))
	enemy_a.loot_table = test_loot
	enemy_b.loot_table = test_loot

	enemy_a.global_position = Vector2(-20, 0)
	enemy_b.global_position = Vector2(20, 0)

	arena.get_node("YSortEntities").add_child(enemy_a)
	arena.get_node("YSortEntities").add_child(enemy_b)
	await _wait_physics_frames(3)

	var inst_a := enemy_a.get_instance_id()
	var inst_b := enemy_b.get_instance_id()
	_assert_test(inst_a != inst_b, "Two runtime enemies have distinct instance IDs")

	# Kill both enemies in close succession
	enemy_a._on_died()
	enemy_b._on_died()
	await _wait_physics_frames(6)

	_assert_test(player.character_stats.current_exp == 60, "Both enemies with shared ID granted EXP (30 + 30 = 60)")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_ui_toggle_and_sync() -> void:
	print("\n--- 8. Testing Runtime Inventory UI Toggle & Display Synchronization ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var hud := arena.get_node_or_null("HUD")
	_assert_test(hud != null, "HUD node exists in CombatArena")

	var inv_ui: InventoryUI = hud.get_node_or_null("InventoryUI") as InventoryUI
	_assert_test(inv_ui != null, "InventoryUI automatically instantiated in HUD")
	_assert_test(not inv_ui.visible, "InventoryUI is hidden by default")

	# Toggle UI open
	inv_ui.open_ui()
	await _wait_physics_frames(2)
	_assert_test(inv_ui.visible, "InventoryUI is visible after open_ui()")

	# Verify Level label reflects player stats
	var player: Player = arena.player
	_assert_test(inv_ui.level_label.text.contains("Level"), "UI Level display shows correct text")
	_assert_test(inv_ui.hp_label.text.contains("HP:"), "UI HP display shows correct text")

	# Close UI
	inv_ui.close_ui()
	await _wait_physics_frames(2)
	_assert_test(not inv_ui.visible, "InventoryUI is closed after close_ui()")

	arena.queue_free()
	await _wait_physics_frames(2)


func test_runtime_health_potion_synchronization() -> void:
	print("\n--- 9. Testing Runtime Health Potion Synchronization & HP Invariants ---")

	var arena_scene: PackedScene = load("res://scenes/world/combat_arena.tscn")
	var arena: CombatArena = arena_scene.instantiate() as CombatArena
	get_root().add_child(arena)
	await _wait_physics_frames(4)

	var player: Player = arena.player
	var hud := arena.get_node_or_null("HUD")
	var inv_ui: InventoryUI = hud.get_node_or_null("InventoryUI") as InventoryUI
	if inv_ui:
		inv_ui.open_ui()
		await _wait_physics_frames(2)

	var potion: ItemData = load("res://resources/items/health_potion.tres") as ItemData

	# 1. Player begins with 100 HP
	_assert_test(player.health_component.current_health == 100, "Step 1: HealthComponent starts at 100 HP")
	_assert_test(player.character_stats.current_health == 100, "Step 1: CharacterStats starts at 100 HP")
	_assert_test(player.health_component.max_health == 100, "Step 1: HealthComponent max_health is 100")
	_assert_test(player.character_stats.max_health == 100, "Step 1: CharacterStats max_health is 100")

	# Add 3 Health Potions to inventory
	player.inventory_manager.add_item(potion, 3)
	var initial_potions := player.inventory_manager.get_item_count(&"health_potion")
	_assert_test(initial_potions == 3, "Inventory successfully stocked with 3 Health Potions")

	# 2. Player receives damage down to 60 HP (40 damage applied)
	player.health_component.take_damage(40)
	await _wait_physics_frames(2)
	_assert_test(player.health_component.current_health == 60, "Step 2: HealthComponent reduced to 60 HP")
	_assert_test(player.character_stats.current_health == 60, "Step 2: CharacterStats synchronized to 60 HP")

	# 3. Player consumes one Health Potion (+30 HP)
	if inv_ui:
		inv_ui._selected_slot_index = 0
		inv_ui._on_equip_pressed()
	else:
		player.character_stats.heal(30)
		player.inventory_manager.remove_item(&"health_potion", 1)
	await _wait_physics_frames(2)

	# 4. HealthComponent and CharacterStats show 90 HP
	_assert_test(player.health_component.current_health == 90, "Step 4: HealthComponent shows 90 HP after potion heal")
	_assert_test(player.character_stats.current_health == 90, "Step 4: CharacterStats shows 90 HP after potion heal")

	# 5. One potion reduced from inventory
	_assert_test(player.inventory_manager.get_item_count(&"health_potion") == initial_potions - 1, "Step 5: Exactly 1 potion deducted from inventory")

	# 7. Using potion cannot produce HP exceeding Max Health (90 + 30 = 120 -> clamped to 100)
	if inv_ui:
		inv_ui._selected_slot_index = 0
		inv_ui._on_equip_pressed()
	else:
		player.character_stats.heal(30)
		player.inventory_manager.remove_item(&"health_potion", 1)
	await _wait_physics_frames(2)
	_assert_test(player.health_component.current_health == 100, "Step 7: HealthComponent clamped to Max Health (100 HP, cannot exceed 100)")
	_assert_test(player.character_stats.current_health == 100, "Step 7: CharacterStats clamped to Max Health (100 HP, cannot exceed 100)")

	# 6. Using potion when HP is full does not change HP
	var hp_before_full := player.health_component.current_health
	if inv_ui:
		inv_ui._selected_slot_index = 0
		inv_ui._on_equip_pressed()
	else:
		player.character_stats.heal(30)
	await _wait_physics_frames(2)
	_assert_test(player.health_component.current_health == hp_before_full, "Step 6: HealthComponent HP unchanged when using potion at full HP (remains 100)")
	_assert_test(player.character_stats.current_health == hp_before_full, "Step 6: CharacterStats HP unchanged when using potion at full HP (remains 100)")

	# Additional: Equipment Max Health bonus does NOT cause auto-heal
	player.health_component.take_damage(30) # Player is now at 70 / 100 HP
	await _wait_physics_frames(2)
	_assert_test(player.health_component.current_health == 70, "Player damaged to 70 HP before equipment test")
	var armor: EquipmentData = load("res://resources/equipment/cloth_armor.tres") as EquipmentData
	player.equipment_manager.equip_item_direct(armor) # +10 HP bonus
	await _wait_physics_frames(2)
	_assert_test(player.character_stats.max_health == 110, "Max health increased to 110 with cloth armor")
	_assert_test(player.health_component.max_health == 110, "HealthComponent max_health increased to 110")
	_assert_test(player.health_component.current_health == 70, "HealthComponent current HP stays at 70 (NO auto-heal on equip)")
	_assert_test(player.character_stats.current_health == 70, "CharacterStats current HP stays at 70 (NO auto-heal on equip)")

	# Additional: Combat hurt reaction, knockback, and i-frames integrity
	var dummy_hitbox := HitboxComponent.new()
	dummy_hitbox.collision_layer = 64
	dummy_hitbox.faction = HitboxComponent.Faction.ENEMY
	dummy_hitbox.damage = 10
	dummy_hitbox.knockback_force = 100.0
	arena.add_child(dummy_hitbox)
	dummy_hitbox.global_position = player.global_position + Vector2(16, 0)
	player.hurtbox_component.receive_hit(dummy_hitbox)
	await _wait_physics_frames(2)
	_assert_test(player.hurtbox_component.is_invulnerable, "Hurtbox entered i-frames after hit")
	_assert_test(player.state_machine.get_current_state_name() == &"hurt", "Player transitioned to Hurt state upon receiving damage")
	dummy_hitbox.queue_free()

	arena.queue_free()
	await _wait_physics_frames(2)


func _print_summary() -> void:
	print("\n=======================================================")
	print(">>> RUNTIME SIMULATION SUMMARY <<<")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("=======================================================\n")

	if _tests_failed == 0:
		print("[SUCCESS] All Phase 5 runtime simulations passed with 0 errors!\n")
		quit(0)
	else:
		printerr("[ERROR] Phase 5 runtime simulation failed with %d errors!\n" % _tests_failed)
		quit(1)
