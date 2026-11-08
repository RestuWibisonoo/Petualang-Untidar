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
@onready var interact_button: Button = %InteractButton
@onready var attack_button: Button = get_node_or_null("%AttackButton") as Button
@onready var inventory_button: Button = get_node_or_null("%InventoryButton") as Button
@onready var quest_button: Button = get_node_or_null("%QuestButton") as Button


func _ready() -> void:
	layer = 10 # Above gameplay, beneath full-screen transitions
	_check_touch_visibility()

	if virtual_joystick:
		virtual_joystick.movement_vector_changed.connect(_on_joystick_movement_vector_changed)

	if dodge_button:
		dodge_button.button_down.connect(_on_dodge_button_down)
		dodge_button.button_up.connect(_on_dodge_button_up)

	if interact_button:
		interact_button.button_down.connect(_on_interact_button_down)
		interact_button.button_up.connect(_on_interact_button_up)

	if attack_button:
		attack_button.button_down.connect(_on_attack_button_down)
		attack_button.button_up.connect(_on_attack_button_up)

	if inventory_button:
		inventory_button.pressed.connect(_on_inventory_button_pressed)

	if quest_button:
		quest_button.pressed.connect(_on_quest_button_pressed)


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


func _on_interact_button_down() -> void:
	Input.action_press("interact")
	if target_player:
		target_player.trigger_interact()


func _on_interact_button_up() -> void:
	Input.action_release("interact")


func _on_attack_button_down() -> void:
	Input.action_press("attack")
	if target_player:
		target_player.trigger_attack()


func _on_attack_button_up() -> void:
	Input.action_release("attack")


func _on_inventory_button_pressed() -> void:
	var ev := InputEventAction.new()
	ev.action = &"inventory"
	ev.pressed = true
	Input.parse_input_event(ev)


func _on_quest_button_pressed() -> void:
	var ev := InputEventAction.new()
	ev.action = &"quest_log"
	ev.pressed = true
	Input.parse_input_event(ev)
