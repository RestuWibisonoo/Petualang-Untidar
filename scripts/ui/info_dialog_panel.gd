class_name InfoDialogPanel
extends Control

## info_dialog_panel.gd
## UI panel displaying information board or signpost title and content.
## Supports keyboard (ESC, E, Enter) and touchscreen (close button, backdrop tap).

signal opened
signal closed

@onready var backdrop: ColorRect = $Backdrop
@onready var title_label: Label = %TitleLabel
@onready var content_label: Label = %ContentLabel
@onready var close_button: Button = %CloseButton

var _is_open: bool = false


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close_panel)
	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)


func open_panel(title: String, content: String) -> void:
	if title_label:
		title_label.text = title
	if content_label:
		content_label.text = content

	_is_open = true
	visible = true
	opened.emit()
	print("[InfoDialogPanel] Opened: %s" % title)


func close_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("info_panel_closed"):
		event_bus.info_panel_closed.emit()

	print("[InfoDialogPanel] Closed.")


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_panel()
	elif event is InputEventScreenTouch and event.pressed:
		close_panel()

