extends SceneTree

## test_phase_5.gd
## Automated validation suite for Phase 5: Loot, Inventory, Equipment, and Progression.
## Tests item resources, inventory mechanics, atomic equipment swaps, stat composition, loot tables, and leveling.

var _tests_passed: int = 0
var _tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)


func _run_all_tests() -> void:
	print("=======================================================")
	print(">>> STARTING PHASE 5 AUTOMATED VALIDATION SUITE <<<")
	print("=======================================================")

	test_item_data_resources()
	test_inventory_manager_stacking_and_capacity()
	test_inventory_move_swap_and_snapshots()
	test_equipment_manager_atomic_operations()
	test_character_stats_and_combat_integration()
	test_exp_leveling_and_stat_allocation()
	test_loot_table_and_probability_rolls()
	test_loot_spawner_and_world_item_pickup()

	_print_summary()


func _assert_test(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		_tests_passed += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		_tests_failed += 1


func test_item_data_resources() -> void:
	print("\n--- 1. Testing ItemData & EquipmentData Resources ---")

	var wooden_sword: EquipmentData = load("res://resources/equipment/wooden_sword.tres") as EquipmentData
	var iron_sword: EquipmentData = load("res://resources/equipment/iron_sword.tres") as EquipmentData
	var cloth_armor: EquipmentData = load("res://resources/equipment/cloth_armor.tres") as EquipmentData
	var leather_armor: EquipmentData = load("res://resources/equipment/leather_armor.tres") as EquipmentData
	var health_potion: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	var slime_jelly: ItemData = load("res://resources/items/slime_jelly.tres") as ItemData

	_assert_test(wooden_sword != null, "Wooden Sword resource loaded successfully")
	_assert_test(iron_sword != null, "Iron Sword resource loaded successfully")
	_assert_test(cloth_armor != null, "Cloth Armor resource loaded successfully")
	_assert_test(leather_armor != null, "Leather Armor resource loaded successfully")
	_assert_test(health_potion != null, "Health Potion resource loaded successfully")
	_assert_test(slime_jelly != null, "Slime Jelly resource loaded successfully")

	# Check uniqueness of IDs
	var ids: Array[StringName] = [
		wooden_sword.item_id, iron_sword.item_id,
		cloth_armor.item_id, leather_armor.item_id,
		health_potion.item_id, slime_jelly.item_id
	]
	var unique_ids: Dictionary = {}
	for id in ids:
		unique_ids[id] = true
	_assert_test(unique_ids.size() == 6, "All sample item IDs are unique")

	# Stacking & Equipment rules
	_assert_test(not wooden_sword.is_stackable and wooden_sword.max_stack == 1, "Weapons are non-stackable with max_stack = 1")
	_assert_test(not cloth_armor.is_stackable and cloth_armor.max_stack == 1, "Armors are non-stackable with max_stack = 1")
	_assert_test(health_potion.is_stackable and health_potion.max_stack == 20, "Health Potion is stackable up to 20")
	_assert_test(slime_jelly.is_stackable and slime_jelly.max_stack == 99, "Slime Jelly is stackable up to 99")

	# Equipment slot & bonuses
	_assert_test(wooden_sword.equipment_slot == EquipmentData.EquipmentSlot.WEAPON, "Wooden sword assigned to WEAPON slot")
	_assert_test(wooden_sword.attack_bonus == 5, "Wooden sword grants +5 attack bonus")
	_assert_test(iron_sword.attack_bonus == 12, "Iron sword grants +12 attack bonus")
	_assert_test(cloth_armor.equipment_slot == EquipmentData.EquipmentSlot.BODY, "Cloth armor assigned to BODY slot")
	_assert_test(cloth_armor.defense_bonus == 2 and cloth_armor.health_bonus == 10, "Cloth armor grants +2 DEF and +10 HP")
	_assert_test(leather_armor.defense_bonus == 5 and leather_armor.health_bonus == 25, "Leather armor grants +5 DEF and +25 HP")

	# can_stack_with logic
	_assert_test(health_potion.can_stack_with(health_potion), "Health Potion can stack with itself")
	_assert_test(not health_potion.can_stack_with(slime_jelly), "Different item types cannot stack")
	_assert_test(not wooden_sword.can_stack_with(wooden_sword), "Non-stackable equipment cannot stack")


func test_inventory_manager_stacking_and_capacity() -> void:
	print("\n--- 2. Testing InventoryManager Stacking, Capacity & Partial Insertion ---")

	var inv := InventoryManager.new()
	inv.slot_capacity = 4 # Small capacity for boundary testing
	inv.initialize_slots()

	var potion: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	var sword: EquipmentData = load("res://resources/equipment/wooden_sword.tres") as EquipmentData

	_assert_test(inv.get_slot_count() == 4, "Inventory initialized with 4 slots")
	_assert_test(inv.get_free_slot_count() == 4, "Initial free slot count is 4")
	_assert_test(not inv.is_full(), "Inventory is not full initially")

	# 1. Add single stackable item
	var added := inv.add_item(potion, 5)
	_assert_test(added == 5, "Successfully added 5 potions")
	_assert_test(inv.get_item_count(&"health_potion") == 5, "Item count is 5")
	_assert_test(inv.get_free_slot_count() == 3, "Only 1 slot consumed by stack")

	# 2. Add to existing stack
	inv.add_item(potion, 10)
	_assert_test(inv.get_item_count(&"health_potion") == 15, "Potions stacked in slot 0 to 15")
	_assert_test(inv.get_free_slot_count() == 3, "Existing stack topped up without consuming new slot")

	# 3. Stack overflow across slots (potion max_stack is 20)
	# Current stack has 15, adding 10 -> slot 0 fills to 20, slot 1 takes remaining 5
	inv.add_item(potion, 10)
	_assert_test(inv.get_item_count(&"health_potion") == 25, "Total potions is 25 after overflow")
	_assert_test(inv.get_slot(0).quantity == 20, "Slot 0 reached max_stack of 20")
	_assert_test(inv.get_slot(1).quantity == 5, "Slot 1 took overflow of 5")
	_assert_test(inv.get_free_slot_count() == 2, "2 slots remaining")

	# 4. Add non-stackable items
	inv.add_item(sword, 1)
	inv.add_item(sword, 1)
	_assert_test(inv.is_full(), "Inventory is full after filling all 4 slots")
	_assert_test(inv.get_free_slot_count() == 0, "0 free slots remaining")

	# 5. Adding to completely full inventory rejected
	var fail_add := inv.add_item(sword, 1)
	_assert_test(fail_add == 0, "Adding to full inventory returns 0 added")

	# 6. Partial insertion test:
	# Slot 0 has 20 potions, slot 1 has 5 potions, slot 2 has sword, slot 3 has sword.
	# Fill slot 1 to 20, and clear slot 3. Total space available is now exactly 20.
	inv.get_slot(1).quantity = 20
	inv.get_slot(3).clear()
	_assert_test(inv.get_available_space_for(potion) == 20, "Total available space in inventory is exactly 20")

	# Attempt to insert 30 items
	var partial := inv.add_item(potion, 30)
	_assert_test(partial == 20, "Partial insertion inserted 20 items (max slot capacity) and rejected 10")
	_assert_test(inv.is_full(), "Inventory full again after partial insertion")

	# 7. Remove item
	var total_potions := inv.get_item_count(&"health_potion")
	var rem_ok := inv.remove_item(&"health_potion", 20)
	_assert_test(rem_ok, "Successfully removed 20 potions")
	_assert_test(inv.get_item_count(&"health_potion") == total_potions - 20, "Remaining potions count decreased accurately by 20")

	# 8. Removing more than available rejected atomically
	var count_before := inv.get_item_count(&"health_potion")
	var fail_rem := inv.remove_item(&"health_potion", count_before + 50)
	_assert_test(not fail_rem, "Cannot remove more items than present in inventory")
	_assert_test(inv.get_item_count(&"health_potion") == count_before, "Count preserved after rejected removal")

	inv.free()


func test_inventory_move_swap_and_snapshots() -> void:
	print("\n--- 3. Testing InventoryManager Move, Swap & Snapshot Safety ---")

	var inv := InventoryManager.new()
	inv.slot_capacity = 6
	inv.initialize_slots()

	var potion: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	var jelly: ItemData = load("res://resources/items/slime_jelly.tres") as ItemData
	var sword: EquipmentData = load("res://resources/equipment/wooden_sword.tres") as EquipmentData

	inv.add_item(potion, 10) # Slot 0: 10 potions
	inv.add_item(jelly, 15)  # Slot 1: 15 jelly
	inv.add_item(sword, 1)   # Slot 2: 1 sword

	# 1. Clean move to empty slot
	var move_ok := inv.move_item(0, 3)
	_assert_test(move_ok, "Item cleanly moved to empty slot 3")
	_assert_test(inv.get_slot(0).is_empty(), "Source slot 0 is empty after move")
	_assert_test(inv.get_slot(3).item_data.item_id == &"health_potion" and inv.get_slot(3).quantity == 10, "Target slot 3 contains 10 potions")

	# 2. Swap between slots with different items
	var swap_ok := inv.swap_items(1, 2)
	_assert_test(swap_ok, "Swapped slot 1 (jelly) and slot 2 (sword)")
	_assert_test(inv.get_slot(1).item_data.item_id == &"wooden_sword", "Slot 1 now holds wooden sword")
	_assert_test(inv.get_slot(2).item_data.item_id == &"slime_jelly", "Slot 2 now holds slime jelly")

	# 3. Stack merge on move
	inv.add_item(potion, 5) # Placed in slot 0
	inv.move_item(0, 3)     # Move 5 potions from slot 0 into slot 3 (which has 10)
	_assert_test(inv.get_slot(3).quantity == 15, "Potions merged in slot 3 to quantity 15")
	_assert_test(inv.get_slot(0).is_empty(), "Slot 0 emptied after merge")

	# 4. Snapshot immutability: modifying snapshot dict cannot corrupt internal slots
	var snapshot := inv.get_inventory_snapshot()
	_assert_test(snapshot.size() == 6, "Snapshot returns 6 entries")
	snapshot[3]["quantity"] = 999
	_assert_test(inv.get_slot(3).quantity == 15, "Internal slot quantity unaffected by modifying external snapshot")

	inv.free()


func test_equipment_manager_atomic_operations() -> void:
	print("\n--- 4. Testing EquipmentManager Atomic Equip, Unequip & Slot Validation ---")

	var inv := InventoryManager.new()
	inv.slot_capacity = 2
	inv.initialize_slots()

	var stats := CharacterStats.new()
	stats.recalculate()

	var equip_mgr := EquipmentManager.new()
	equip_mgr.inventory_manager = inv
	equip_mgr.character_stats = stats

	var sword_wood: EquipmentData = load("res://resources/equipment/wooden_sword.tres") as EquipmentData
	var sword_iron: EquipmentData = load("res://resources/equipment/iron_sword.tres") as EquipmentData
	var armor_cloth: EquipmentData = load("res://resources/equipment/cloth_armor.tres") as EquipmentData

	# Put items in inventory
	inv.add_item(sword_wood, 1)  # Slot 0
	inv.add_item(sword_iron, 1)  # Slot 1
	_assert_test(inv.is_full(), "Inventory is full with 2 swords")

	# 1. Equip from inventory into empty WEAPON slot
	var eq_ok := equip_mgr.equip_from_inventory(0)
	_assert_test(eq_ok, "Equipped wooden sword from slot 0")
	_assert_test(equip_mgr.get_equipped_item(EquipmentData.EquipmentSlot.WEAPON) == sword_wood, "Wooden sword equipped in WEAPON slot")
	_assert_test(inv.get_slot(0).is_empty(), "Inventory slot 0 cleared after equip")
	_assert_test(stats.attack == 20, "Character attack elevated from base 15 to 20 (+5)")

	# 2. Replace equipment when inventory has no empty slots (Slot 0 is now empty, slot 1 has iron sword)
	# Swapping iron sword from slot 1 with equipped wooden sword:
	var replace_ok := equip_mgr.equip_from_inventory(1)
	_assert_test(replace_ok, "Equipped iron sword replacing wooden sword")
	_assert_test(equip_mgr.get_equipped_item(EquipmentData.EquipmentSlot.WEAPON) == sword_iron, "Iron sword now equipped in WEAPON slot")
	_assert_test(inv.get_slot(1).item_data == sword_wood, "Wooden sword returned to inventory slot 1")
	_assert_test(stats.attack == 27, "Character attack elevated to 27 (+12 iron sword)")

	# 3. Equip armor into BODY slot
	inv.add_item(armor_cloth, 1) # Placed into slot 0
	equip_mgr.equip_from_inventory(0)
	_assert_test(equip_mgr.get_equipped_item(EquipmentData.EquipmentSlot.BODY) == armor_cloth, "Cloth armor equipped in BODY slot")
	_assert_test(stats.defense == 2, "Character defense elevated to 2 (+2 cloth armor)")
	_assert_test(stats.max_health == 110, "Character max health elevated to 110 (+10 cloth armor)")

	# 4. Unequip failure when inventory is 100% full (Atomic rejection)
	inv.add_item(sword_wood, 1) # fill slot 0
	_assert_test(inv.is_full(), "Inventory full prior to unequip test")
	var unequip_fail := equip_mgr.unequip_to_inventory(EquipmentData.EquipmentSlot.WEAPON)
	_assert_test(not unequip_fail, "Unequip rejected when inventory is full")
	_assert_test(equip_mgr.get_equipped_item(EquipmentData.EquipmentSlot.WEAPON) == sword_iron, "Iron sword remained equipped without item loss")

	# 5. Successful unequip after freeing space
	inv.remove_item_from_slot(0, 1)
	var unequip_ok := equip_mgr.unequip_to_inventory(EquipmentData.EquipmentSlot.WEAPON)
	_assert_test(unequip_ok, "Unequip succeeded after inventory space freed")
	_assert_test(equip_mgr.get_equipped_item(EquipmentData.EquipmentSlot.WEAPON) == null, "WEAPON slot is empty")
	_assert_test(stats.attack == 15, "Character attack returned to base 15")

	equip_mgr.free()
	stats.free()
	inv.free()


func test_character_stats_and_combat_integration() -> void:
	print("\n--- 5. Testing CharacterStats Calculation & Dynamic Combat Scaling ---")

	var stats := CharacterStats.new()
	stats.recalculate()

	_assert_test(stats.level == 1, "Initial level is 1")
	_assert_test(stats.max_health == 100, "Initial max health is 100")
	_assert_test(stats.attack == 15, "Initial attack is 15")
	_assert_test(stats.defense == 0, "Initial defense is 0")
	_assert_test(stats.movement_speed == 120.0, "Initial movement speed is 120.0")

	# 1. Equipment bonuses recalculation
	var bonuses := {
		"attack": 12,
		"defense": 5,
		"health": 25,
		"movement_speed": 10.0
	}
	stats.recalculate(bonuses)
	_assert_test(stats.attack == 27, "Attack with bonuses: 15 + 12 = 27")
	_assert_test(stats.defense == 5, "Defense with bonuses: 0 + 5 = 5")
	_assert_test(stats.max_health == 125, "Max Health with bonuses: 100 + 25 = 125")
	_assert_test(stats.movement_speed == 130.0, "Movement speed with bonuses: 120 + 10 = 130")

	# 2. HP clamping and no auto-heal on gear swap
	stats.current_health = 125
	stats.recalculate({"attack": 0, "defense": 0, "health": 0, "movement_speed": 0.0})
	_assert_test(stats.max_health == 100, "Max health dropped back to 100")
	_assert_test(stats.current_health == 100, "Current health clamped down to 100 without exceed")

	# 3. Combat integration: Test Player Attack State damage dynamic scaling
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = player_scene.instantiate() as Player
	get_root().add_child(player)

	# Verify player initial combat nodes
	_assert_test(player.character_stats != null, "Player contains CharacterStats")
	_assert_test(player.equipment_manager != null, "Player contains EquipmentManager")
	_assert_test(player.inventory_manager != null, "Player contains InventoryManager")

	var fsm: StateMachine = player.state_machine
	var attack_state: PlayerAttackState = fsm.get_node_or_null("Attack") as PlayerAttackState

	# Baseline attack: combo 1 damage = 15
	fsm.transition_to(&"attack")
	_assert_test(player.hitbox_component.damage == 15, "Baseline combo stage 1 damage is 15")

	# Now equip iron sword (+12 attack) onto player
	var iron_sword: EquipmentData = load("res://resources/equipment/iron_sword.tres") as EquipmentData
	player.equipment_manager.equip_item_direct(iron_sword)
	_assert_test(player.character_stats.attack == 27, "Player character stats attack elevated to 27")

	# Test PlayerAttackState combo 1 damage with sword equipped
	fsm.transition_to(&"attack", {"combo_stage": 1})
	_assert_test(player.hitbox_component.damage == 27, "Hitbox damage dynamically scaled to 27 with iron sword (15 + 12)")

	# Test combo stage 2 damage with sword equipped
	fsm.transition_to(&"attack", {"combo_stage": 2})
	_assert_test(player.hitbox_component.damage == 37, "Hitbox combo stage 2 damage scaled to 37 (25 + 12)")

	# Defense scaling on player
	var leather_armor: EquipmentData = load("res://resources/equipment/leather_armor.tres") as EquipmentData
	player.equipment_manager.equip_item_direct(leather_armor)
	_assert_test(player.defense == 5, "Player defense synchronized to 5 from armor")
	_assert_test(player.hurtbox_component.defense == 5, "Player hurtbox defense synchronized to 5")

	player.queue_free()
	stats.free()


func test_exp_leveling_and_stat_allocation() -> void:
	print("\n--- 6. Testing EXP Progression, Leveling & Stat Allocation ---")

	var stats := CharacterStats.new()
	stats.reset_all()

	var level_ups_detected: Array[int] = []
	stats.level_up.connect(func(new_lvl, _pts): level_ups_detected.append(new_lvl))

	_assert_test(stats.level == 1, "Starts at level 1")
	_assert_test(stats.exp_to_next_level == 100, "Level 1 required EXP is 100")

	# 1. Partial EXP gain
	stats.add_experience(40)
	_assert_test(stats.current_exp == 40, "EXP accumulated to 40")
	_assert_test(stats.level == 1, "Level remains 1")
	_assert_test(level_ups_detected.is_empty(), "No level up triggered yet")

	# 2. Reaching exact threshold -> Level 2
	stats.add_experience(60) # 40 + 60 = 100
	_assert_test(stats.level == 2, "Level increased to 2")
	_assert_test(stats.current_exp == 0, "Current EXP reset to 0 remainder")
	_assert_test(stats.available_stat_points == 3, "Awarded 3 stat points on level up")
	_assert_test(level_ups_detected.size() == 1 and level_ups_detected[0] == 2, "Level up signal emitted for level 2")

	# 3. Multi-level overflow: Large EXP burst (e.g. 800 EXP)
	var prior_lvl := stats.level
	stats.add_experience(800)
	_assert_test(stats.level > prior_lvl + 1, "Multiple level ups triggered by large EXP overflow")
	_assert_test(stats.available_stat_points >= 6, "Accumulated stat points from multiple level ups")

	# 4. Stat allocation API
	var initial_atk := stats.attack
	var pts_before := stats.available_stat_points
	var alloc_ok := stats.allocate_stat_point(&"attack", 2)
	_assert_test(alloc_ok, "Allocated 2 points to Attack")
	_assert_test(stats.attack == initial_atk + 4, "Attack elevated by 4 (+2 per point)")
	_assert_test(stats.available_stat_points == pts_before - 2, "Available stat points deducted by 2")

	# Allocation validation: cannot allocate negative or zero or excessive points
	_assert_test(not stats.allocate_stat_point(&"attack", 0), "Allocation of 0 points rejected")
	_assert_test(not stats.allocate_stat_point(&"defense", -1), "Allocation of negative points rejected")
	_assert_test(not stats.allocate_stat_point(&"defense", 999), "Allocation exceeding available points rejected")

	stats.free()


func test_loot_table_and_probability_rolls() -> void:
	print("\n--- 7. Testing LootTable & Drop Probability Rolls ---")

	var slime_loot: LootTable = load("res://resources/enemies/dummy_slime_loot.tres") as LootTable
	_assert_test(slime_loot != null, "Dummy slime loot table resource loaded")
	_assert_test(slime_loot.entries.size() == 4, "Loot table contains 4 drop entries")

	# 1. Deterministic test using seeded RNG
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var drops := slime_loot.roll_loot(rng)
	_assert_test(drops is Array, "Loot roll returns an Array")
	_assert_test(not drops.is_empty(), "Loot roll produced drops")

	var has_valid_format := true
	for d in drops:
		if not d.has("item_data") or not d.has("quantity") or d["quantity"] <= 0:
			has_valid_format = false
			break
	_assert_test(has_valid_format, "All dropped items contain valid item_data and positive quantity")

	# 2. Test 100% drop chance guarantees drop
	var guaranteed_table := LootTable.new()
	var potion: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	var entry_100 := LootDropEntry.new(potion, 1.0, 2, 2, 100)
	guaranteed_table.entries.append(entry_100)

	var g_drops := guaranteed_table.roll_loot()
	_assert_test(g_drops.size() == 1, "100% drop chance entry always drops")
	_assert_test(g_drops[0]["quantity"] == 2, "Drop quantity matches configured range (2)")

	# 3. Test 0% drop chance never drops
	var zero_table := LootTable.new()
	var entry_0 := LootDropEntry.new(potion, 0.0, 1, 1, 10)
	zero_table.entries.append(entry_0)
	var z_drops := zero_table.roll_loot()
	_assert_test(z_drops.is_empty(), "0% drop chance entry never drops")

	# 4. Weighted selection pool test
	var weighted_table := LootTable.new()
	weighted_table.use_weighted_selection = true
	weighted_table.weighted_roll_count = 1
	var sword: EquipmentData = load("res://resources/equipment/wooden_sword.tres") as EquipmentData
	weighted_table.entries.append(LootDropEntry.new(potion, 1.0, 1, 1, 10))
	weighted_table.entries.append(LootDropEntry.new(sword, 1.0, 1, 1, 90))

	var w_drops := weighted_table.roll_loot(rng)
	_assert_test(w_drops.size() == 1, "Weighted pool returned exactly 1 item for roll count 1")


func test_loot_spawner_and_world_item_pickup() -> void:
	print("\n--- 8. Testing LootSpawner & WorldItem Single Pickup Integrity ---")

	var spawner := LootSpawner.new()
	get_root().add_child(spawner)

	var slime_loot: LootTable = load("res://resources/enemies/dummy_slime_loot.tres") as LootTable
	spawner.register_loot_table(&"test_enemy", slime_loot, 50)

	# 1. Spawn loot at position
	var spawned := spawner.spawn_loot_for_enemy(&"test_enemy", Vector2(100, 100))
	_assert_test(spawned is Array, "spawn_loot_for_enemy returns Array of WorldItem")

	# 2. Test WorldItem pickup mechanics
	var world_item_scene: PackedScene = load("res://scenes/objects/world_item.tscn")
	var world_item: WorldItem = world_item_scene.instantiate() as WorldItem
	var potion: ItemData = load("res://resources/items/health_potion.tres") as ItemData
	world_item.item_data = potion
	world_item.quantity = 3
	world_item.pickup_cooldown = 0.0
	get_root().add_child(world_item)

	var inv := InventoryManager.new()
	inv.slot_capacity = 2
	inv.initialize_slots()
	InventoryManager.instance = inv

	# Initial pickup -> Success
	var p_ok := world_item.pickup()
	_assert_test(p_ok, "WorldItem collected into inventory")
	_assert_test(inv.get_item_count(&"health_potion") == 3, "Inventory received 3 potions")

	# Second pickup on same world item -> Rejected (Single-pickup integrity)
	var p_double := world_item.pickup()
	_assert_test(not p_double, "Second pickup attempt rejected by single-pickup lock")

	# Full inventory pickup rejection test
	var full_item: WorldItem = world_item_scene.instantiate() as WorldItem
	full_item.item_data = load("res://resources/equipment/wooden_sword.tres") as ItemData
	full_item.quantity = 1
	full_item.pickup_cooldown = 0.0
	get_root().add_child(full_item)

	# Fill inventory to capacity
	var sword_res: ItemData = load("res://resources/equipment/iron_sword.tres") as ItemData
	inv.add_item(sword_res, 1)
	inv.add_item(sword_res, 1)
	_assert_test(inv.is_full(), "Inventory is completely full")

	var p_full_rejected := not full_item.pickup()
	_assert_test(p_full_rejected, "Item stays in world when inventory is full (pickup rejected)")

	# Cleanup
	InventoryManager.instance = null
	inv.free()
	for item in spawned:
		item.queue_free()
	world_item.queue_free()
	full_item.queue_free()
	spawner.queue_free()


func _print_summary() -> void:
	print("\n=======================================================")
	print(">>> PHASE 5 VALIDATION SUMMARY <<<")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("=======================================================\n")

	if _tests_failed == 0:
		print("[SUCCESS] All Phase 5 loot & progression systems validated with 0 errors!\n")
		quit(0)
	else:
		printerr("[ERROR] Phase 5 validation failed with %d errors!\n" % _tests_failed)
		quit(1)
