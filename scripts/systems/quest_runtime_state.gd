class_name QuestRuntimeState
extends RefCounted

## QuestRuntimeState.gd
## Serializable runtime progress and completion state for an individual quest.
## Decouples runtime progress from static QuestData resource definitions.

enum QuestStatus {
	NOT_STARTED = 0,
	ACTIVE = 1,
	COMPLETED = 2,
	REWARD_CLAIMED = 3
}

var quest_id: StringName = &""
var status: QuestStatus = QuestStatus.NOT_STARTED
var objective_progress: Dictionary = {} # StringName (objective_id) -> int (current_count)
var is_reward_claimed: bool = false


func _init(p_quest_id: StringName = &"") -> void:
	quest_id = p_quest_id


func initialize_from_quest(quest_data: QuestData) -> void:
	if not quest_data:
		return
	quest_id = quest_data.quest_id
	status = QuestStatus.NOT_STARTED
	is_reward_claimed = false
	objective_progress.clear()
	for obj in quest_data.objectives:
		if obj and obj.objective_id != &"":
			objective_progress[obj.objective_id] = 0


func is_active() -> bool:
	return status == QuestStatus.ACTIVE


func is_completed() -> bool:
	return status == QuestStatus.COMPLETED or status == QuestStatus.REWARD_CLAIMED


func get_progress(objective_id: StringName) -> int:
	return int(objective_progress.get(objective_id, 0))


func set_progress(objective_id: StringName, amount: int, required_amount: int) -> int:
	var clamped := mini(maxi(0, amount), required_amount)
	objective_progress[objective_id] = clamped
	return clamped


func add_progress(objective_id: StringName, delta: int, required_amount: int) -> int:
	var current := get_progress(objective_id)
	return set_progress(objective_id, current + delta, required_amount)


func is_objective_completed(objective_id: StringName, required_amount: int) -> bool:
	return get_progress(objective_id) >= required_amount


func are_all_objectives_completed(quest_data: QuestData) -> bool:
	if not quest_data or quest_data.objectives.is_empty():
		return false
	for obj in quest_data.objectives:
		if not obj:
			continue
		if not is_objective_completed(obj.objective_id, obj.required_amount):
			return false
	return true


func to_dict() -> Dictionary:
	var progress_dict: Dictionary = {}
	for k in objective_progress.keys():
		progress_dict[String(k)] = objective_progress[k]

	return {
		"quest_id": String(quest_id),
		"status": int(status),
		"is_reward_claimed": is_reward_claimed,
		"objective_progress": progress_dict
	}


static func from_dict(data: Dictionary) -> QuestRuntimeState:
	var q_id := StringName(data.get("quest_id", ""))
	var state := QuestRuntimeState.new(q_id)
	state.status = data.get("status", QuestStatus.NOT_STARTED) as QuestStatus
	state.is_reward_claimed = bool(data.get("is_reward_claimed", false))

	var raw_prog: Dictionary = data.get("objective_progress", {})
	for k in raw_prog.keys():
		state.objective_progress[StringName(k)] = int(raw_prog[k])

	return state
