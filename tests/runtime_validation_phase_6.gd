extends SceneTree

## runtime_validation_phase_6.gd
## Multi-frame physics & runtime simulation suite for Phase 6: Quest & Dungeon System.
## Simulates NPC conversation with player input lock, quest acceptance, event-driven objective tracking,
## atomic reward claims, dungeon door unlocking via dungeon_key, and 2-phase boss combat.

var _tests_passed: int = 0
var _tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_runtime_suite, CONNECT_ONE_SHOT)


func _run_runtime_suite() -> void:
	print("=======================================================")
	print(">>> STARTING PHASE 6 RUNTIME SIMULATION SUITE <<<")
	print("=======================================================")

	await test_runtime_npc_dialogue_and_input_lock()
	await test_runtime_quest_objective_kill_and_collect()
	await test_runtime_reward_claim_and_dungeon_key()
	await test_runtime_dungeon_door_unlock_and_transition()
	await test_runtime_boss_two_phases_and_defeat()

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


func test_runtime_npc_dialogue_and_input_lock() -> void:
	print("\n--- 1. Testing Runtime NPC Dialogue & Player Input Locking ---")

	var outdoor_scene: PackedScene = load("res://scenes/world/outdoor_test.tscn")
	var world: WorldBase = outdoor_scene.instantiate() as WorldBase
	get_root().add_child(world)
	await _wait_physics_frames(4)

	var player: Player = world.player
	var npc: NPC = world.get_node_or_null("YSortEntities/Interactables/GuideNPC") as NPC
	var dialogue_ui: DialogueUI = world.get_node_or_null("HUD/DialogueUI") as DialogueUI

	_assert_test(player != null, "Player exists in Outdoor scene")
	_assert_test(npc != null, "GuideNPC exists in Outdoor scene")
	_assert_test(dialogue_ui != null, "DialogueUI exists in HUD layer")

	# Position player at NPC to interact
	player.global_position = npc.global_position + Vector2(0, 16)
	await _wait_physics_frames(2)

	# Trigger interaction
	npc._on_interacted(player)
	await _wait_physics_frames(3)

	_assert_test(dialogue_ui.is_active(), "DialogueUI opened upon talking to NPC")
	_assert_test(player.is_input_locked, "Player input is locked during dialogue")

	# Test player cannot move while input is locked
	player.set_touch_input(Vector2.RIGHT)
	await _wait_physics_frames(3)
	_assert_test(player.velocity == Vector2.ZERO, "Player movement velocity is 0 while input locked")

	# Progress dialogue lines to completion
	while dialogue_ui.is_active():
		dialogue_ui.advance_dialogue()
		await _wait_physics_frames(2)

	_assert_test(not dialogue_ui.is_active(), "DialogueUI closed after finishing dialogue")
	_assert_test(not player.is_input_locked, "Player input unlocked after dialogue ended")

	var qm := QuestManager.get_instance()
	_assert_test(qm != null and qm.is_quest_active(&"quest_first_steps"), "Quest 'quest_first_steps' accepted from dialogue")

	world.queue_free()
	await _wait_physics_frames(4)


func test_runtime_quest_objective_kill_and_collect() -> void:
	print("\n--- 2. Testing Event-Driven Quest Objectives (Kill, Collect, Talk) ---")

	var qm := QuestManager.new()
	get_root().add_child(qm)
	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	qm.register_quest(q1)
	qm.accept_quest(&"quest_first_steps")

	var event_bus: Node = get_root().get_node_or_null("EventBus")

	# 1. Kill first slime
	event_bus.enemy_defeated_at.emit(&"dummy_slime", Vector2.ZERO, 35, null, 2001)
	await _wait_physics_frames(1)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"kill_slimes") == 1, "Kill progress is 1/2")

	# 2. Duplicate kill event with same instance ID (must not increment)
	event_bus.enemy_defeated_at.emit(&"dummy_slime", Vector2.ZERO, 35, null, 2001)
	await _wait_physics_frames(1)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"kill_slimes") == 1, "Duplicate kill event ignored")

	# 3. Kill second slime with distinct instance ID
	event_bus.enemy_defeated_at.emit(&"dummy_slime", Vector2.ZERO, 35, null, 2002)
	await _wait_physics_frames(1)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"kill_slimes") == 2, "Kill progress completed at 2/2")

	# 4. Collect items (slime jelly)
	event_bus.item_collected.emit(&"slime_jelly", 2)
	await _wait_physics_frames(1)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"collect_jelly") == 2, "Item collection completed at 2/2")

	# 5. Talk to NPC guide
	event_bus.npc_interacted.emit(&"npc_guide")
	await _wait_physics_frames(1)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"talk_guide") == 1, "Talk objective completed at 1/1")

	_assert_test(qm.is_quest_completed(&"quest_first_steps"), "Quest auto-completed upon all objectives met")

	qm.queue_free()
	await _wait_physics_frames(2)


func test_runtime_reward_claim_and_dungeon_key() -> void:
	print("\n--- 3. Testing QuestUI Reward Claiming & Dungeon Key Grant ---")

	var qm := QuestManager.new()
	get_root().add_child(qm)
	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	qm.register_quest(q1)
	qm.accept_quest(&"quest_first_steps")
	qm.set_objective_progress(&"quest_first_steps", &"kill_slimes", 2)
	qm.set_objective_progress(&"quest_first_steps", &"collect_jelly", 2)
	qm.set_objective_progress(&"quest_first_steps", &"talk_guide", 1)

	var player := Player.new()
	var inv := InventoryManager.new()
	inv.slot_capacity = 20
	inv.initialize_slots()
	var stats := CharacterStats.new()
	player.inventory_manager = inv
	player.character_stats = stats
	qm.player = player

	var quest_ui_scene: PackedScene = load("res://scenes/ui/quest_ui.tscn")
	var quest_ui: QuestUI = quest_ui_scene.instantiate() as QuestUI
	get_root().add_child(quest_ui)
	await _wait_physics_frames(2)

	quest_ui.open_ui()
	await _wait_physics_frames(2)

	_assert_test(quest_ui.is_open(), "QuestUI opened")
	_assert_test(qm.is_quest_completed(&"quest_first_steps"), "Quest 1 is COMPLETED")

	# Claim reward via QuestManager
	var success := qm.claim_reward(&"quest_first_steps")
	await _wait_physics_frames(2)

	_assert_test(success, "Reward claimed successfully")
	_assert_test(qm.is_quest_reward_claimed(&"quest_first_steps"), "Quest status is REWARD_CLAIMED")
	_assert_test(inv.has_item(&"dungeon_key"), "Dungeon Key added to player inventory")
	_assert_test(inv.has_item(&"health_potion"), "Health Potion added to player inventory")
	_assert_test(stats.level == 2, "Player leveled up to Level 2 from quest EXP")

	quest_ui.close_ui()
	quest_ui.queue_free()
	player.free()
	inv.free()
	stats.free()
	qm.queue_free()
	await _wait_physics_frames(2)


func test_runtime_dungeon_door_unlock_and_transition() -> void:
	print("\n--- 4. Testing DungeonDoor Key Validation & Unlock ---")

	var door_scene: PackedScene = load("res://scenes/objects/dungeon_door.tscn")
	var door: DungeonDoor = door_scene.instantiate() as DungeonDoor
	get_root().add_child(door)
	await _wait_physics_frames(2)

	_assert_test(door.is_locked, "Dungeon door starts locked")

	var player := Player.new()
	var inv := InventoryManager.new()
	inv.slot_capacity = 10
	inv.initialize_slots()
	player.inventory_manager = inv

	# 1. Attempt to unlock without key
	_assert_test(not door.can_unlock(inv), "Cannot unlock door without key")
	door._on_interacted(player)
	_assert_test(door.is_locked, "Door remains locked when interacting without key")

	# 2. Add dungeon key to inventory
	var key_res: ItemData = load("res://resources/items/dungeon_key.tres")
	inv.add_item(key_res, 1)
	_assert_test(inv.has_item(&"dungeon_key"), "Dungeon key in inventory")
	_assert_test(door.can_unlock(inv), "Door can now be unlocked")

	# 3. Unlock door
	var unlock_success := door.unlock(inv)
	_assert_test(unlock_success, "Door unlock returned true")
	_assert_test(not door.is_locked, "Door is now unlocked")
	_assert_test(not inv.has_item(&"dungeon_key"), "Dungeon key was consumed upon unlock")

	door.queue_free()
	player.free()
	inv.free()
	await _wait_physics_frames(2)


func test_runtime_boss_two_phases_and_defeat() -> void:
	print("\n--- 5. Testing Boss Gorgon Two Phases, Enrage & Defeat ---")

	var dungeon_scene: PackedScene = load("res://scenes/dungeon/dungeon_room.tscn")
	var dungeon: DungeonRoom = dungeon_scene.instantiate() as DungeonRoom
	get_root().add_child(dungeon)
	await _wait_physics_frames(4)

	var boss: BossEnemy = dungeon.boss_enemy
	var player: Player = dungeon.player

	_assert_test(boss != null, "Boss Gorgon exists in DungeonRoom")
	_assert_test(boss.current_phase == 1, "Boss starts in Phase 1")
	_assert_test(boss.health_component.current_health == 200, "Boss starts with 200 HP")
	_assert_test(not boss.is_enraged, "Boss is not enraged")

	var signal_data := {
		"enraged": false,
		"new_phase": 0,
		"defeated_id": &""
	}
	boss.enraged.connect(func(): signal_data["enraged"] = true)
	boss.phase_changed.connect(func(p: int): signal_data["new_phase"] = p)

	var event_bus: Node = get_root().get_node_or_null("EventBus")
	if event_bus:
		event_bus.enemy_defeated.connect(func(id: StringName): signal_data["defeated_id"] = id)

	# Damage boss to 110 HP (> 50%) -> Phase 1
	boss.health_component.take_damage(90)
	await _wait_physics_frames(2)
	_assert_test(not boss.is_enraged, "Boss still in Phase 1 at 110 HP (> 50%)")

	# Damage boss to 90 HP (<= 50%) -> Triggers Enrage into Phase 2
	boss.health_component.take_damage(20)
	await _wait_physics_frames(4)

	_assert_test(boss.is_enraged, "Boss is enraged at 90 HP (<= 50%)")
	_assert_test(boss.current_phase == 2, "Boss transitioned to Phase 2")
	_assert_test(signal_data["enraged"], "Boss fired 'enraged' signal")
	_assert_test(signal_data["new_phase"] == 2, "Boss fired 'phase_changed(2)' signal")
	_assert_test(boss.move_speed == 75.0, "Boss move speed boosted to 75.0 px/s")
	_assert_test(boss.base_damage == 30, "Boss damage boosted to 30")

	# Lethal blow to Boss
	boss.health_component.take_damage(100)
	await _wait_physics_frames(4)

	_assert_test(boss.is_dead, "Boss killed by lethal damage")
	_assert_test(signal_data["defeated_id"] == &"boss_gorgon", "EventBus received defeat event for boss_gorgon")

	# Verify loot dropped in room
	await _wait_physics_frames(4)
	var world_items := get_root().get_tree().get_nodes_in_group(&"world_item")
	_assert_test(not world_items.is_empty(), "Boss dropped loot items on death")

	dungeon.queue_free()
	await _wait_physics_frames(4)


func _print_summary() -> void:
	print("\n=======================================================")
	print(">>> PHASE 6 RUNTIME SIMULATION SUMMARY <<<")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("=======================================================\n")

	if _tests_failed == 0:
		print("[SUCCESS] All Phase 6 runtime simulations passed with 0 errors!\n")
		quit(0)
	else:
		printerr("[ERROR] Phase 6 runtime simulations failed with %d errors!\n" % _tests_failed)
		quit(1)
