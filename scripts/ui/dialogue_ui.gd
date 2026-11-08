class_name DialogueUI
extends CanvasLayer

## DialogueUI.gd
## Narrative dialogue box supporting multi-line text, keyboard & touchscreen controls.
## Temporarily locks player input during conversation and safely restores it upon close.

signal opened(dialogue_id: StringName)
signal closed(dialogue_id: StringName)

@onready var panel_container: PanelContainer = $PanelContainer
@onready var speaker_label: Label = %SpeakerLabel
@onready var content_label: Label = %ContentLabel
@onready var next_button: Button = %NextButton
@onready var close_button: Button = %CloseButton

var _current_dialogue: DialogueData = null
var _current_line_idx: int = 0
var _target_player: Player = null
var _is_open: bool = false

static var instance: DialogueUI = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	layer = 25
	visible = false

	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if close_button:
		close_button.pressed.connect(close_dialogue)


static func get_default() -> DialogueUI:
	return instance


func is_dialogue_open() -> bool:
	return _is_open


func is_active() -> bool:
	return _is_open


func advance_dialogue() -> void:
	_on_next_pressed()


func open_dialogue(dialogue: DialogueData, player: Player = null) -> void:
	if not dialogue or dialogue.get_line_count() == 0:
		return

	_current_dialogue = dialogue
	_current_line_idx = 0
	_is_open = true
	visible = true

	# Cache and lock player input
	_target_player = player
	if not _target_player and is_inside_tree():
		var players := get_tree().get_nodes_in_group(&"player")
		if not players.is_empty():
			_target_player = players[0] as Player

	if _target_player:
		_target_player.is_input_locked = true
		_target_player.velocity = Vector2.ZERO

	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state"):
		gm.change_state(4) # GameState.DIALOGUE

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("dialogue_started"):
		event_bus.dialogue_started.emit(dialogue.dialogue_id)

	opened.emit(dialogue.dialogue_id)
	_display_current_line()


func _display_current_line() -> void:
	if not _current_dialogue:
		return

	if speaker_label:
		speaker_label.text = _current_dialogue.speaker_name

	if content_label:
		content_label.text = _current_dialogue.get_line(_current_line_idx)

	var is_last_line := (_current_line_idx >= _current_dialogue.get_line_count() - 1)
	if next_button:
		next_button.text = "Selesai" if is_last_line else "Lanjut [E]"


func _on_next_pressed() -> void:
	if not _is_open or not _current_dialogue:
		return

	if _current_line_idx + 1 < _current_dialogue.get_line_count():
		_current_line_idx += 1
		_display_current_line()
	else:
		close_dialogue()


func close_dialogue() -> void:
	if not _is_open:
		return

	var diag_id := _current_dialogue.dialogue_id if _current_dialogue else &""
	var quest_to_give := _current_dialogue.quest_to_give if _current_dialogue else null

	_is_open = false
	visible = false

	# Safely unlock player input
	if _target_player:
		_target_player.is_input_locked = false

	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_state"):
		gm.change_state(2) # GameState.PLAYING

	# Quest offer trigger upon dialogue completion
	if quest_to_give:
		var qm := QuestManager.get_default()
		if qm and qm.can_accept_quest(quest_to_give.quest_id):
			qm.accept_quest(quest_to_give.quest_id)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("dialogue_ended"):
		event_bus.dialogue_ended.emit()

	closed.emit(diag_id)
	_current_dialogue = null
	_target_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
