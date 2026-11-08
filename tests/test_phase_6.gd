extends SceneTree

## test_phase_6.gd
## Comprehensive automated unit test suite for Phase 6: Quest & Dungeon System.
## Validates QuestData, QuestObjectiveData, QuestRuntimeState, QuestManager, DialogueData,
## NPC, DungeonDoor, BossEnemy, and QuestUI.

var _tests_passed: int = 0
var _tests_failed: int = 0


func _init() -> void:
	process_frame.connect(_run_all_tests, CONNECT_ONE_SHOT)


func _run_all_tests() -> void:
	print("=======================================================")
	print(">>> STARTING PHASE 6 AUTOMATED VALIDATION SUITE <<<")
	print("=======================================================")

	test_quest_resources_and_validation()
	test_quest_runtime_state()
	test_quest_manager_lifecycle_and_prerequisites()
	test_event_driven_quest_progress_and_idempotency()
	test_quest_reward_atomic_claims()
	test_dialogue_data_and_npc_interaction()
	test_dungeon_key_and_door_mechanics()
	test_boss_enemy_phases_and_combat()
	test_quest_ui_representation()

	_print_summary()


func _assert_test(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		_tests_passed += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		_tests_failed += 1


func test_quest_resources_and_validation() -> void:
	print("\n--- 1. Testing Quest Resources & Validation ---")

	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	var q2: QuestData = load("res://resources/quests/quest_dungeon_boss.tres") as QuestData
	var key_item: ItemData = load("res://resources/items/dungeon_key.tres") as ItemData

	_assert_test(q1 != null, "Quest 1 (First Steps) resource loaded")
	_assert_test(q2 != null, "Quest 2 (Dungeon Boss) resource loaded")
	_assert_test(key_item != null, "Dungeon Key item resource loaded")

	_assert_test(q1.is_valid(), "Quest 1 passes internal validation")
	_assert_test(q2.is_valid(), "Quest 2 passes internal validation")

	_assert_test(q1.quest_id == &"quest_first_steps", "Quest 1 ID is 'quest_first_steps'")
	_assert_test(q2.quest_id == &"quest_dungeon_boss", "Quest 2 ID is 'quest_dungeon_boss'")
	_assert_test(q2.prerequisite_quest_ids.has(&"quest_first_steps"), "Quest 2 requires Quest 1 as prerequisite")

	_assert_test(q1.objectives.size() == 3, "Quest 1 has 3 objectives (kill, collect, talk)")
	_assert_test(q2.objectives.size() == 1, "Quest 2 has 1 objective (kill boss)")

	_assert_test(q1.reward_exp == 150, "Quest 1 rewards 150 EXP")
	_assert_test(q2.reward_exp == 500, "Quest 2 rewards 500 EXP")

	# Test invalid quest
	var invalid_q := QuestData.new()
	_assert_test(not invalid_q.is_valid(), "Empty QuestData is invalid")
	invalid_q.quest_id = &"bad_q"
	_assert_test(not invalid_q.is_valid(), "Quest without objectives is invalid")


func test_quest_runtime_state() -> void:
	print("\n--- 2. Testing QuestRuntimeState Decoupling & Clamping ---")

	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	var state := QuestRuntimeState.new()
	state.initialize_from_quest(q1)

	_assert_test(state.quest_id == q1.quest_id, "State initialized with correct quest_id")
	_assert_test(state.status == QuestRuntimeState.QuestStatus.NOT_STARTED, "Initial status is NOT_STARTED")
	_assert_test(state.get_progress(&"kill_slimes") == 0, "Initial progress for kill_slimes is 0")

	# Update progress
	state.status = QuestRuntimeState.QuestStatus.ACTIVE
	var new_prog: int = state.add_progress(&"kill_slimes", 1, 2)
	_assert_test(new_prog == 1, "add_progress returned 1 on increment")
	_assert_test(state.get_progress(&"kill_slimes") == 1, "Progress is now 1")
	_assert_test(not state.is_objective_completed(&"kill_slimes", 2), "Objective not yet completed at 1/2")

	# Progress clamping
	state.add_progress(&"kill_slimes", 5, 2)
	_assert_test(state.get_progress(&"kill_slimes") == 2, "Progress clamped to required_amount (2)")
	_assert_test(state.is_objective_completed(&"kill_slimes", 2), "Objective completed at 2/2")

	# Negative delta clamping
	state.add_progress(&"kill_slimes", -10, 2)
	_assert_test(state.get_progress(&"kill_slimes") == 0, "Progress clamped to minimum 0")

	# Serialization
	state.set_progress(&"kill_slimes", 2, 2)
	state.set_progress(&"collect_jelly", 2, 2)
	state.set_progress(&"talk_guide", 1, 1)
	state.status = QuestRuntimeState.QuestStatus.COMPLETED

	var dict := state.to_dict()
	var restored := QuestRuntimeState.from_dict(dict)

	_assert_test(restored.quest_id == q1.quest_id, "Serialized state preserves quest_id")
	_assert_test(restored.status == QuestRuntimeState.QuestStatus.COMPLETED, "Serialized state preserves status")
	_assert_test(restored.get_progress(&"kill_slimes") == 2, "Serialized state preserves objective progress")


func test_quest_manager_lifecycle_and_prerequisites() -> void:
	print("\n--- 3. Testing QuestManager Lifecycle & Prerequisites ---")

	var qm := QuestManager.new()
	qm.name = "TestQuestManager"

	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	var q2: QuestData = load("res://resources/quests/quest_dungeon_boss.tres") as QuestData

	qm.register_quest(q1)
	qm.register_quest(q2)

	_assert_test(qm.get_all_quests().size() == 2, "QuestManager registered 2 quests")
	_assert_test(qm.get_quest_data(&"quest_first_steps") == q1, "Quest 1 retrieved correctly")

	# Prerequisite validation
	_assert_test(qm.can_accept_quest(&"quest_first_steps"), "Can accept Quest 1 (no prerequisites)")
	_assert_test(not qm.can_accept_quest(&"quest_dungeon_boss"), "Cannot accept Quest 2 before Quest 1 completion")

	# Accept Quest 1
	var accepted := qm.accept_quest(&"quest_first_steps")
	_assert_test(accepted, "Quest 1 accepted successfully")
	_assert_test(qm.is_quest_active(&"quest_first_steps"), "Quest 1 is now ACTIVE")
	_assert_test(not qm.can_accept_quest(&"quest_first_steps"), "Cannot accept already active quest")

	# Progress and complete Quest 1
	qm.set_objective_progress(&"quest_first_steps", &"kill_slimes", 2)
	qm.set_objective_progress(&"quest_first_steps", &"collect_jelly", 2)
	qm.set_objective_progress(&"quest_first_steps", &"talk_guide", 1)

	_assert_test(qm.is_quest_completed(&"quest_first_steps"), "Quest 1 status is COMPLETED")
	_assert_test(qm.can_accept_quest(&"quest_dungeon_boss"), "Can now accept Quest 2 after Quest 1 completed")

	# Accept Quest 2
	var accepted_2 := qm.accept_quest(&"quest_dungeon_boss")
	_assert_test(accepted_2, "Quest 2 accepted successfully")
	_assert_test(qm.is_quest_active(&"quest_dungeon_boss"), "Quest 2 is now ACTIVE")

	qm.free()


func test_event_driven_quest_progress_and_idempotency() -> void:
	print("\n--- 4. Testing Event-Driven Quest Progress & Deduplication ---")

	var qm := QuestManager.new()
	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	qm.register_quest(q1)
	qm.accept_quest(&"quest_first_steps")

	var event_bus := Node.new()
	event_bus.name = "EventBus"
	# Add signals dynamically to test event bus
	event_bus.add_user_signal("enemy_defeated_at", [{"name": "enemy_id", "type": TYPE_STRING_NAME}, {"name": "pos", "type": TYPE_VECTOR2}, {"name": "exp_rew", "type": TYPE_INT}, {"name": "table", "type": TYPE_OBJECT}, {"name": "inst_id", "type": TYPE_INT}])
	event_bus.add_user_signal("item_collected", [{"name": "item_id", "type": TYPE_STRING_NAME}, {"name": "quantity", "type": TYPE_INT}])
	event_bus.add_user_signal("npc_interacted", [{"name": "npc_id", "type": TYPE_STRING_NAME}])

	# Connect qm directly
	event_bus.connect("enemy_defeated_at", Callable(qm, "_on_event_bus_enemy_defeated_at"))
	event_bus.connect("item_collected", Callable(qm, "_on_event_bus_item_collected"))
	event_bus.connect("npc_interacted", Callable(qm, "_on_event_bus_npc_interacted"))

	# Emit kill event from instance 101
	event_bus.emit_signal("enemy_defeated_at", &"dummy_slime", Vector2.ZERO, 35, null, 101)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"kill_slimes") == 1, "Kill progress incremented to 1")

	# Re-emit with same instance 101 (duplicate event) -> should be deduplicated
	event_bus.emit_signal("enemy_defeated_at", &"dummy_slime", Vector2.ZERO, 35, null, 101)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"kill_slimes") == 1, "Duplicate kill event from same instance ignored")

	# Emit kill event from different instance 102
	event_bus.emit_signal("enemy_defeated_at", &"dummy_slime", Vector2.ZERO, 35, null, 102)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"kill_slimes") == 2, "Second kill event from different instance progressed to 2")

	# Emit item collected event
	event_bus.emit_signal("item_collected", &"slime_jelly", 2)
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"collect_jelly") == 2, "Item collection progressed to 2")

	# Emit NPC talk event
	event_bus.emit_signal("npc_interacted", &"npc_guide")
	_assert_test(qm.get_objective_progress(&"quest_first_steps", &"talk_guide") == 1, "NPC talk progressed to 1")

	_assert_test(qm.is_quest_completed(&"quest_first_steps"), "Quest auto-completed after all event progress")

	event_bus.free()
	qm.free()


func test_quest_reward_atomic_claims() -> void:
	print("\n--- 5. Testing Quest Reward Atomic Claims ---")

	var qm := QuestManager.new()
	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	qm.register_quest(q1)
	qm.accept_quest(&"quest_first_steps")
	qm.set_objective_progress(&"quest_first_steps", &"kill_slimes", 2)
	qm.set_objective_progress(&"quest_first_steps", &"collect_jelly", 2)
	qm.set_objective_progress(&"quest_first_steps", &"talk_guide", 1)

	# Setup mock Player with InventoryManager and CharacterStats
	var player := Player.new()
	var inv := InventoryManager.new()
	inv.slot_capacity = 2
	inv._ready()
	var stats := CharacterStats.new()
	player.inventory_manager = inv
	player.character_stats = stats
	qm.player = player

	# Fill inventory to capacity with dummy items
	var wooden_sword: ItemData = load("res://resources/equipment/wooden_sword.tres")
	inv.add_item(wooden_sword, 1)
	inv.add_item(wooden_sword, 1)
	_assert_test(inv.get_free_slot_count() == 0, "Inventory completely full (0 free slots)")

	# Claim should fail atomically because quest rewards 2 distinct items (potion + dungeon key)
	var claim_failed := qm.claim_reward(&"quest_first_steps")
	_assert_test(not claim_failed, "Claim rejected due to full inventory")
	_assert_test(qm.get_quest_state(&"quest_first_steps").status == QuestRuntimeState.QuestStatus.COMPLETED, "Quest status remains COMPLETED (not claimed)")
	_assert_test(stats.current_exp == 0, "No EXP granted on failed claim")

	# Clear one slot -> still needs 2 slots!
	inv.clear_slot(0)
	_assert_test(inv.get_free_slot_count() == 1, "Inventory has only 1 free slot (needs 2)")
	claim_failed = qm.claim_reward(&"quest_first_steps")
	_assert_test(not claim_failed, "Claim still rejected with only 1 slot available")

	# Clear second slot -> now 2 slots available
	inv.clear_slot(1)
	_assert_test(inv.get_free_slot_count() == 2, "Inventory has 2 free slots")

	var claim_success := qm.claim_reward(&"quest_first_steps")
	_assert_test(claim_success, "Claim succeeds with sufficient space")
	_assert_test(qm.get_quest_state(&"quest_first_steps").status == QuestRuntimeState.QuestStatus.REWARD_CLAIMED, "Quest status transitioned to REWARD_CLAIMED")
	_assert_test(stats.level == 2 and stats.current_exp == 50, "EXP granted (+150, leveled up to Level 2 with 50 carryover EXP)")
	_assert_test(inv.has_item(&"health_potion"), "Health potion added to inventory")
	_assert_test(inv.has_item(&"dungeon_key"), "Dungeon key added to inventory")

	# Cannot claim twice
	var claim_again := qm.claim_reward(&"quest_first_steps")
	_assert_test(not claim_again, "Second claim attempt safely rejected")

	player.free()
	inv.free()
	stats.free()
	qm.free()


func test_dialogue_data_and_npc_interaction() -> void:
	print("\n--- 6. Testing DialogueData & NPC Interaction ---")

	var q1: QuestData = load("res://resources/quests/quest_first_steps.tres") as QuestData
	var dia := DialogueData.new()
	dia.dialogue_id = &"test_dia"
	dia.speaker_name = "Prof. Untidar"
	dia.lines = ["Halo Petualang!", "Selamat datang di kampus Untidar."]
	dia.quest_to_give = q1

	_assert_test(dia.dialogue_id == &"test_dia", "Dialogue ID set correctly")
	_assert_test(dia.lines.size() == 2, "Dialogue has 2 lines")
	_assert_test(dia.quest_to_give == q1, "Dialogue triggers quest_first_steps")

	# NPC entity
	var npc := NPC.new()
	npc.npc_id = &"npc_guide"
	npc.npc_name = "Pemandu Kampus"
	npc.default_dialogue = dia

	# Emulate tree ready
	npc._setup_interactable()
	_assert_test(npc.interactable != null, "NPC created Interactable component")
	_assert_test(npc.interactable.interaction_text == "Bicara dengan Pemandu Kampus", "Interaction text matches NPC name")
	_assert_test(npc.interactable.collision_layer == 128, "Interactable on layer 8 (128)")

	npc.free()


func test_dungeon_key_and_door_mechanics() -> void:
	print("\n--- 7. Testing Dungeon Key & DungeonDoor Mechanics ---")

	var door := DungeonDoor.new()
	door.required_key_id = &"dungeon_key"
	door.consumes_key = true
	door.target_scene_path = "res://scenes/dungeon/dungeon_room.tscn"
	door.target_spawn_id = &"dungeon_entrance"
	door._setup_interactable()

	_assert_test(door.interactable != null, "DungeonDoor has Interactable component")
	_assert_test(door.is_locked, "DungeonDoor starts locked")

	var player := Player.new()
	var inv := InventoryManager.new()
	inv.initialize_slots()
	player.inventory_manager = inv

	# Try open without key
	_assert_test(not door.can_unlock(inv), "Cannot unlock without key in inventory")

	# Add key to inventory
	var key_item: ItemData = load("res://resources/items/dungeon_key.tres")
	inv.add_item(key_item, 1)
	_assert_test(door.can_unlock(inv), "Can unlock when dungeon_key is in inventory")

	# Unlock door
	var unlocked: bool = door.unlock(inv)
	_assert_test(unlocked, "Door unlocked successfully")
	_assert_test(not door.is_locked, "Door state updated to unlocked")
	_assert_test(not inv.has_item(&"dungeon_key"), "Dungeon key was consumed from inventory")

	door.free()
	player.free()
	inv.free()


func test_boss_enemy_phases_and_combat() -> void:
	print("\n--- 8. Testing BossEnemy Two-Phase Mechanics ---")

	var boss := BossEnemy.new()
	boss._ready()

	_assert_test(boss.enemy_id == &"boss_gorgon", "Boss ID is 'boss_gorgon'")
	_assert_test(boss.max_health == 200, "Boss max health is 200")
	_assert_test(boss.current_phase == 1, "Boss starts in Phase 1")
	_assert_test(not boss.is_enraged, "Boss is not enraged initially")
	_assert_test(boss.move_speed == 50.0, "Phase 1 move speed is 50.0")
	_assert_test(boss.base_damage == 20, "Phase 1 base damage is 20")
	_assert_test(boss.exp_reward == 500, "Boss rewards 500 EXP")

	# Track signals via reference Dictionary
	var signal_state := {
		"enraged_fired": false,
		"new_phase_val": 0,
		"defeat_count": 0
	}
	boss.enraged.connect(func(): signal_state["enraged_fired"] = true)
	boss.phase_changed.connect(func(p: int): signal_state["new_phase_val"] = p)

	# Damage boss to 110 HP (> 50%) -> should NOT enrage
	boss.health_component.take_damage(90)
	_assert_test(boss.health_component.current_health == 110, "Boss HP reduced to 110")
	_assert_test(not boss.is_enraged, "Boss not enraged at 110 HP (> 50%)")

	# Damage boss to 90 HP (<= 50%) -> should ENRAGE into Phase 2
	boss.health_component.take_damage(20)
	_assert_test(boss.health_component.current_health == 90, "Boss HP reduced to 90 (<= 50%)")
	_assert_test(boss.is_enraged, "Boss is now enraged")
	_assert_test(boss.current_phase == 2, "Boss transitioned to Phase 2")
	_assert_test(signal_state["enraged_fired"], "enraged signal fired")
	_assert_test(signal_state["new_phase_val"] == 2, "phase_changed(2) signal fired")
	_assert_test(boss.move_speed == 75.0, "Phase 2 speed boosted to 75.0")
	_assert_test(boss.base_damage == 30, "Phase 2 damage boosted to 30")
	_assert_test(boss.attack_cooldown == 0.7, "Phase 2 attack cooldown reduced to 0.7s")

	# Further damage should not re-trigger enrage
	signal_state["enraged_fired"] = false
	boss.health_component.take_damage(40)
	_assert_test(not signal_state["enraged_fired"], "Enrage is not triggered repeatedly")

	# Kill boss -> verify single death emission
	boss.defeated.connect(func(_id, _pos): signal_state["defeat_count"] += 1)
	boss.health_component.take_damage(100)
	_assert_test(boss.is_dead, "Boss is dead")
	_assert_test(signal_state["defeat_count"] == 1, "Single defeat signal emitted")

	boss.free()


func test_quest_ui_representation() -> void:
	print("\n--- 9. Testing QuestUI Representation ---")

	var quest_ui_scene: PackedScene = load("res://scenes/ui/quest_ui.tscn")
	var quest_ui: QuestUI = quest_ui_scene.instantiate() as QuestUI
	root.add_child(quest_ui)

	_assert_test(quest_ui.layer == 24, "QuestUI resides on CanvasLayer 24")
	_assert_test(not quest_ui.is_open(), "QuestUI starts closed")

	quest_ui.open_ui()
	_assert_test(quest_ui.is_open(), "QuestUI opens on open_ui()")

	quest_ui.close_ui()
	_assert_test(not quest_ui.is_open(), "QuestUI closes on close_ui()")

	quest_ui.queue_free()


func _print_summary() -> void:
	print("\n=======================================================")
	print(">>> PHASE 6 VALIDATION SUMMARY <<<")
	print("Passed: %d" % _tests_passed)
	print("Failed: %d" % _tests_failed)
	print("=======================================================\n")

	if _tests_failed == 0:
		print("[SUCCESS] All Phase 6 quest & dungeon systems validated with 0 errors!\n")
		quit(0)
	else:
		printerr("[ERROR] Phase 6 validation failed with %d errors!\n" % _tests_failed)
		quit(1)
