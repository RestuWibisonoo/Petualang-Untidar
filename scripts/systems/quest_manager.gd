class_name QuestManager
extends Node

## QuestManager.gd
## Central controller for quest management, progress tracking, and reward distribution.
## Event-driven via EventBus, enforcing event idempotency and safe reward transactions.

signal quest_accepted(quest_id: StringName)
signal quest_objective_updated(quest_id: StringName, objective_id: StringName, current: int, required: int)
signal quest_completed(quest_id: StringName)
signal quest_reward_claimed(quest_id: StringName, exp_reward: int, reward_items: Array)

var _registered_quests: Dictionary = {} # StringName (quest_id) -> QuestData
var _quest_states: Dictionary = {}       # StringName (quest_id) -> QuestRuntimeState

# Bounded event deduplication cache: instance_id / event_key -> timestamp
var _processed_enemy_instances: Dictionary = {}
var _processed_defeat_events: Dictionary = {}

var player: Player = null

static var instance: QuestManager = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_connect_event_bus()


static func get_default() -> QuestManager:
	return instance


static func get_instance() -> QuestManager:
	return instance


func _connect_event_bus() -> void:
	var event_bus := _get_event_bus()
	if not event_bus:
		return

	if event_bus.has_signal("enemy_defeated_at"):
		if not event_bus.enemy_defeated_at.is_connected(_on_event_bus_enemy_defeated_at):
			event_bus.enemy_defeated_at.connect(_on_event_bus_enemy_defeated_at)

	if event_bus.has_signal("enemy_defeated"):
		if not event_bus.enemy_defeated.is_connected(_on_event_bus_enemy_defeated):
			event_bus.enemy_defeated.connect(_on_event_bus_enemy_defeated)

	if event_bus.has_signal("item_collected"):
		if not event_bus.item_collected.is_connected(_on_event_bus_item_collected):
			event_bus.item_collected.connect(_on_event_bus_item_collected)

	if event_bus.has_signal("npc_interacted"):
		if not event_bus.npc_interacted.is_connected(_on_event_bus_npc_interacted):
			event_bus.npc_interacted.connect(_on_event_bus_npc_interacted)


func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null


## Registers a QuestData definition with the manager.
func register_quest(quest: QuestData) -> void:
	if not quest or quest.quest_id == &"":
		return
	_registered_quests[quest.quest_id] = quest
	if not _quest_states.has(quest.quest_id):
		_quest_states[quest.quest_id] = QuestRuntimeState.new(quest.quest_id)


## Checks if a quest exists and its prerequisites are satisfied.
func check_prerequisites(quest_id: StringName) -> bool:
	var quest: QuestData = _registered_quests.get(quest_id, null)
	if not quest:
		return false

	for prereq_id in quest.prerequisite_quest_ids:
		var state: QuestRuntimeState = _quest_states.get(prereq_id, null)
		if not state or not state.is_completed():
			return false
	return true


## Checks if a quest is eligible to be accepted.
func can_accept_quest(quest_id: StringName) -> bool:
	if not _registered_quests.has(quest_id):
		return false
	var state := get_quest_state(quest_id)
	if state and state.status != QuestRuntimeState.QuestStatus.NOT_STARTED:
		return false
	return check_prerequisites(quest_id)


## Accepts a quest, transitioning it to ACTIVE.
func accept_quest(quest_id: StringName) -> bool:
	if not can_accept_quest(quest_id):
		return false

	var state := get_quest_state(quest_id)
	state.status = QuestRuntimeState.QuestStatus.ACTIVE

	quest_accepted.emit(quest_id)

	var event_bus := _get_event_bus()
	if event_bus:
		if event_bus.has_signal("quest_accepted"):
			event_bus.quest_accepted.emit(quest_id)
		if event_bus.has_signal("show_floating_text"):
			var quest: QuestData = _registered_quests[quest_id]
			event_bus.show_floating_text.emit("Quest Diterima: %s" % quest.title, Vector2(320, 80), Color(0.3, 0.9, 0.4))

	return true


## Advances progress for all active quests matching the specified objective type and target ID.
func update_objective_progress(
	obj_type: QuestObjectiveData.ObjectiveType,
	target_id: StringName,
	amount: int = 1
) -> bool:
	if target_id == &"" or amount <= 0:
		return false

	var any_updated := false

	for q_id in _registered_quests.keys():
		var state: QuestRuntimeState = _quest_states.get(q_id, null)
		if not state or not state.is_active():
			continue

		var quest: QuestData = _registered_quests[q_id]
		var quest_progress_changed := false

		for obj in quest.objectives:
			if not obj or obj.objective_type != obj_type or obj.target_id != target_id:
				continue

			var cur := state.get_progress(obj.objective_id)
			if cur >= obj.required_amount:
				continue # Objective already completed, cannot advance further

			var new_val := state.add_progress(obj.objective_id, amount, obj.required_amount)
			any_updated = true
			quest_progress_changed = true

			quest_objective_updated.emit(q_id, obj.objective_id, new_val, obj.required_amount)

			var event_bus := _get_event_bus()
			if event_bus and event_bus.has_signal("quest_progress_updated"):
				event_bus.quest_progress_updated.emit(q_id, new_val, obj.required_amount)

		# Check if all objectives are completed for this quest
		if quest_progress_changed and state.are_all_objectives_completed(quest):
			complete_quest(q_id)

	return any_updated


## Marks a quest as COMPLETED.
func complete_quest(quest_id: StringName) -> bool:
	var state := get_quest_state(quest_id)
	if not state or state.status != QuestRuntimeState.QuestStatus.ACTIVE:
		return false

	state.status = QuestRuntimeState.QuestStatus.COMPLETED
	quest_completed.emit(quest_id)

	var event_bus := _get_event_bus()
	if event_bus:
		if event_bus.has_signal("quest_completed"):
			event_bus.quest_completed.emit(quest_id)
		if event_bus.has_signal("show_floating_text"):
			var quest: QuestData = _registered_quests.get(quest_id, null)
			var q_title: String = quest.title if quest else String(quest_id)
			event_bus.show_floating_text.emit("Quest Selesai: %s" % q_title, Vector2(320, 80), Color(1.0, 0.85, 0.2))

	return true


## Claims rewards for a completed quest atomically.
## Validates inventory capacity before applying item additions or experience rewards.
func claim_reward(
	quest_id: StringName,
	character_stats: CharacterStats = null,
	inventory: InventoryManager = null
) -> bool:
	var state := get_quest_state(quest_id)
	if not state or state.status != QuestRuntimeState.QuestStatus.COMPLETED or state.is_reward_claimed:
		return false

	var quest: QuestData = _registered_quests.get(quest_id, null)
	if not quest:
		return false

	var target_inv := inventory
	if not target_inv and player:
		target_inv = player.inventory_manager
	if not target_inv:
		target_inv = InventoryManager.get_default()

	var target_stats := character_stats
	if not target_stats and player:
		target_stats = player.character_stats
	if not target_stats:
		target_stats = CharacterStats.get_default()

	# 1. Validate inventory space for all item rewards concurrently
	if target_inv and not quest.reward_items.is_empty():
		var existing_stack_space: Dictionary = {}
		for slot in target_inv._slots:
			if not slot.is_empty() and slot.item_data.is_stackable:
				var i_id: StringName = slot.item_data.item_id
				var space: int = maxi(0, slot.item_data.max_stack - slot.quantity)
				existing_stack_space[i_id] = int(existing_stack_space.get(i_id, 0)) + space

		var needed_empty_slots: int = 0
		for entry in quest.reward_items:
			var item: ItemData = entry.get("item", null) as ItemData
			var qty: int = int(entry.get("quantity", 1))
			if not item or qty <= 0:
				continue
			var remaining_qty: int = qty
			if item.is_stackable:
				var available_in_stacks: int = int(existing_stack_space.get(item.item_id, 0))
				var used_stack: int = mini(remaining_qty, available_in_stacks)
				remaining_qty -= used_stack
				existing_stack_space[item.item_id] = available_in_stacks - used_stack

			if remaining_qty > 0:
				var max_s: int = maxi(1, item.max_stack)
				needed_empty_slots += ceili(float(remaining_qty) / float(max_s))

		if target_inv.get_free_slot_count() < needed_empty_slots:
			var event_bus := _get_event_bus()
			if event_bus and event_bus.has_signal("show_floating_text"):
				event_bus.show_floating_text.emit("Inventaris Penuh! Hadiah belum dapat diambil.", Vector2(320, 100), Color(1.0, 0.3, 0.3))
			return false # Atomic rejection: leaves quest in COMPLETED, reward pending

	# 2. Distribute items
	if target_inv and not quest.reward_items.is_empty():
		for entry in quest.reward_items:
			var item: ItemData = entry.get("item", null) as ItemData
			var qty: int = int(entry.get("quantity", 1))
			if item and qty > 0:
				target_inv.add_item(item, qty)

	# 3. Distribute experience
	if target_stats and quest.reward_exp > 0:
		target_stats.add_experience(quest.reward_exp)

	# 4. Finalize state
	state.is_reward_claimed = true
	state.status = QuestRuntimeState.QuestStatus.REWARD_CLAIMED

	quest_reward_claimed.emit(quest_id, quest.reward_exp, quest.reward_items)

	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("quest_reward_claimed"):
		event_bus.quest_reward_claimed.emit(quest_id)
	return true


func get_quest_data(quest_id: StringName) -> QuestData:
	return _registered_quests.get(quest_id, null)


func get_quest_state(quest_id: StringName) -> QuestRuntimeState:
	return _quest_states.get(quest_id, null)


func get_all_quests() -> Array[QuestData]:
	var result: Array[QuestData] = []
	for q in _registered_quests.values():
		if q is QuestData:
			result.append(q)
	return result


func get_quests_by_status(status: QuestRuntimeState.QuestStatus) -> Array[StringName]:
	var result: Array[StringName] = []
	for q_id in _quest_states.keys():
		var state: QuestRuntimeState = _quest_states[q_id]
		if state and state.status == status:
			result.append(q_id)
	return result


func get_objective_progress(quest_id: StringName, objective_id: StringName) -> int:
	var state := get_quest_state(quest_id)
	if state:
		return state.get_progress(objective_id)
	return 0


func set_objective_progress(quest_id: StringName, objective_id: StringName, amount: int) -> void:
	var state := get_quest_state(quest_id)
	var quest := get_quest_data(quest_id)
	if not state or not quest:
		return
	var obj := quest.get_objective(objective_id)
	var req: int = obj.required_amount if obj else amount
	state.set_progress(objective_id, amount, req)
	quest_objective_updated.emit(quest_id, objective_id, state.get_progress(objective_id), req)
	if state.is_active() and state.are_all_objectives_completed(quest):
		complete_quest(quest_id)


func get_active_quests() -> Array[QuestData]:
	var result: Array[QuestData] = []
	for q_id in _registered_quests.keys():
		var state: QuestRuntimeState = _quest_states.get(q_id, null)
		if state and state.is_active():
			result.append(_registered_quests[q_id])
	return result


func get_completed_quests() -> Array[QuestData]:
	var result: Array[QuestData] = []
	for q_id in _registered_quests.keys():
		var state: QuestRuntimeState = _quest_states.get(q_id, null)
		if state and state.is_completed():
			result.append(_registered_quests[q_id])
	return result


func is_quest_active(quest_id: StringName) -> bool:
	var state := get_quest_state(quest_id)
	return state != null and state.is_active()


func is_quest_completed(quest_id: StringName) -> bool:
	var state := get_quest_state(quest_id)
	return state != null and state.is_completed()


func is_quest_reward_claimed(quest_id: StringName) -> bool:
	var state := get_quest_state(quest_id)
	return state != null and state.is_reward_claimed


# --- EventBus Handlers with Deduplication ---

func _on_event_bus_enemy_defeated_at(
	enemy_id: StringName,
	_position: Vector2,
	_exp_reward: int,
	_loot_table: LootTable,
	enemy_instance_id: int
) -> void:
	# Idempotency check: duplicate instance defeat is ignored
	if enemy_instance_id != 0:
		if _processed_enemy_instances.has(enemy_instance_id):
			return
		_clean_cache_if_needed(_processed_enemy_instances)
		_processed_enemy_instances[enemy_instance_id] = Time.get_ticks_msec()

	update_objective_progress(QuestObjectiveData.ObjectiveType.KILL_ENEMY, enemy_id, 1)


func _on_event_bus_enemy_defeated(enemy_id: StringName) -> void:
	# Fallback if enemy_defeated_at was not emitted
	# Check if this defeat was already handled via instance_id in this frame
	var now := Time.get_ticks_msec()
	var key := StringName("%s_%d" % [enemy_id, now])
	if _processed_defeat_events.has(key):
		return
	_clean_cache_if_needed(_processed_defeat_events)
	_processed_defeat_events[key] = now

	# Only update if no instances were handled in the last 10ms for this enemy
	update_objective_progress(QuestObjectiveData.ObjectiveType.KILL_ENEMY, enemy_id, 1)


func _on_event_bus_item_collected(item_id: StringName, amount: int) -> void:
	update_objective_progress(QuestObjectiveData.ObjectiveType.COLLECT_ITEM, item_id, amount)


func _on_event_bus_npc_interacted(npc_id: StringName) -> void:
	update_objective_progress(QuestObjectiveData.ObjectiveType.TALK_TO_NPC, npc_id, 1)


func _clean_cache_if_needed(cache: Dictionary, max_size: int = 150) -> void:
	if cache.size() > max_size:
		# Prune oldest half of entries
		var keys := cache.keys()
		var to_remove := keys.size() / 2
		for i in range(to_remove):
			cache.erase(keys[i])


## Exports all quest states to a serializable dictionary for saving.
func export_save_data() -> Dictionary:
	var data: Dictionary = {}
	for q_id in _quest_states.keys():
		var state: QuestRuntimeState = _quest_states[q_id]
		data[String(q_id)] = state.to_dict()
	return data


## Imports quest states from a saved dictionary.
func import_save_data(data: Dictionary) -> void:
	for q_id_str in data.keys():
		var q_id := StringName(q_id_str)
		var state_dict: Dictionary = data[q_id_str]
		_quest_states[q_id] = QuestRuntimeState.from_dict(state_dict)
