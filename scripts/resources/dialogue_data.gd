class_name DialogueData
extends Resource

## DialogueData.gd
## Configurable dialogue script resource for NPCs and narrative events.
## Supports sequential dialogue lines and quest trigger integration.

@export var dialogue_id: StringName = &""
@export var speaker_name: String = "NPC"
@export var lines: Array[String] = []
@export var quest_to_give: QuestData = null
@export var quest_to_complete: QuestData = null


func _init(
	p_id: StringName = &"",
	p_speaker: String = "NPC",
	p_lines: Array[String] = [],
	p_quest: QuestData = null
) -> void:
	dialogue_id = p_id
	speaker_name = p_speaker
	lines = p_lines
	quest_to_give = p_quest


func get_line_count() -> int:
	return lines.size()


func get_line(index: int) -> String:
	if index >= 0 and index < lines.size():
		return lines[index]
	return ""
