class_name QuestData
extends Resource

## QuestData.gd
## Static definition of a quest in Petualang Untidar.
## Kept immutable at runtime; state and progress are managed by QuestRuntimeState.

@export var quest_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var quest_giver_id: StringName = &""
@export var objectives: Array[QuestObjectiveData] = []
@export var reward_exp: int = 0
@export var reward_items: Array[Dictionary] = [] # [ { "item": ItemData, "quantity": int } ]
@export var prerequisite_quest_ids: Array[StringName] = []


func get_objective(obj_id: StringName) -> QuestObjectiveData:
	for obj in objectives:
		if obj and obj.objective_id == obj_id:
			return obj
	return null


func is_valid() -> bool:
	if quest_id == &"" or title == "":
		return false
	if objectives.is_empty():
		return false
	for obj in objectives:
		if obj == null or not obj.is_valid():
			return false
	return true
