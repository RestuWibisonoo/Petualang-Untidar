class_name QuestObjectiveData
extends Resource

## QuestObjectiveData.gd
## Configurable objective entry within a QuestData resource.
## Defines the objective type, target entity ID, required amount, and description.

enum ObjectiveType {
	KILL_ENEMY = 0,
	COLLECT_ITEM = 1,
	TALK_TO_NPC = 2
}

@export var objective_id: StringName = &""
@export var objective_type: ObjectiveType = ObjectiveType.KILL_ENEMY
@export var target_id: StringName = &""
@export var required_amount: int = 1
@export var description: String = ""


func _init(
	p_id: StringName = &"",
	p_type: ObjectiveType = ObjectiveType.KILL_ENEMY,
	p_target: StringName = &"",
	p_amount: int = 1,
	p_desc: String = ""
) -> void:
	objective_id = p_id
	objective_type = p_type
	target_id = p_target
	required_amount = maxi(1, p_amount)
	description = p_desc


func is_valid() -> bool:
	return objective_id != &"" and target_id != &"" and required_amount > 0
