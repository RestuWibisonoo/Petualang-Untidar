class_name Player
extends CharacterBody2D

## Player.gd
## Central controller for the Player entity.
## Integrates 8-direction movement, FSM, VelocityComponent, ModularVisuals, and Camera2D.

@export var walk_speed: float = 120.0
@export var roll_speed: float = 240.0
@export var roll_duration: float = 0.25

@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var state_machine: StateMachine = $StateMachine
@onready var modular_visuals: ModularVisuals = $ModularVisuals
@onready var camera: Camera2D = $Camera2D

var current_input_direction: Vector2 = Vector2.ZERO
var last_movement_direction: Vector2 = Vector2.DOWN
var touch_input_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	if velocity_component:
		velocity_component.max_speed = walk_speed


func get_movement_input() -> Vector2:
	# 1. Keyboard / Gamepad input (automatically deadzoned and normalized by Godot)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 2. Virtual touchscreen joystick input fallback
	if dir == Vector2.ZERO and touch_input_direction != Vector2.ZERO:
		dir = touch_input_direction.normalized()

	return dir


func get_facing_direction_name() -> StringName:
	var dir := last_movement_direction
	if absf(dir.x) > absf(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	else:
		return &"down" if dir.y >= 0.0 else &"up"


func set_touch_input(touch_dir: Vector2) -> void:
	touch_input_direction = touch_dir


func trigger_dodge() -> void:
	if state_machine and (state_machine.get_current_state_name() == &"idle" or state_machine.get_current_state_name() == &"move"):
		state_machine.transition_to(&"roll")
