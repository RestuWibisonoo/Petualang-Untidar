class_name TouchControls
extends CanvasLayer

## TouchControls.gd
## Touchscreen HUD containing VirtualJoystick and action buttons.
## Automatically toggles visibility based on touchscreen availability.

@export var target_player: Player
@export var auto_detect_touch: bool = true
@export var force_visible: bool = false

@onready var virtual_joystick: TouchVirtualJoystick = %VirtualJoystick
@onready var dodge_button: Button = %DodgeButton


func _ready() -> void:
	layer = 10 # Above gameplay, beneath full-screen transitions
	_check_touch_visibility()

	if virtual_joystick:
		virtual_joystick.movement_vector_changed.connect(_on_joystick_movement_vector_changed)

	if dodge_button:
		dodge_button.button_down.connect(_on_dodge_button_down)
		dodge_button.button_up.connect(_on_dodge_button_up)


func _check_touch_visibility() -> void:
	if force_visible:
		visible = true
		return

	if auto_detect_touch:
		var has_touch: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
		visible = has_touch
	else:
		visible = true


func set_target_player(player: Player) -> void:
	target_player = player


func _on_joystick_movement_vector_changed(vector: Vector2) -> void:
	if target_player:
		target_player.set_touch_input(vector)


func _on_dodge_button_down() -> void:
	Input.action_press("dodge")
	if target_player:
		target_player.trigger_dodge()


func _on_dodge_button_up() -> void:
	Input.action_release("dodge")
