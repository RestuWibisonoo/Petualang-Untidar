class_name PlayerMoveState
extends State

## PlayerMoveState.gd
## Active when the player is moving in one of the 8 directions.

var player: Player


func _ready() -> void:
	await owner.ready
	player = owner as Player


func enter(_msg: Dictionary = {}) -> void:
	if player and player.modular_visuals:
		player.modular_visuals.play_animation(&"walk", player.get_facing_direction_name())


func physics_update(delta: float) -> void:
	if not player:
		return

	player.current_input_direction = player.get_movement_input()

	if Input.is_action_just_pressed("dodge"):
		state_machine.transition_to(&"roll")
		return

	if player.current_input_direction == Vector2.ZERO:
		state_machine.transition_to(&"idle")
		return

	player.last_movement_direction = player.current_input_direction

	if player.velocity_component:
		player.velocity_component.max_speed = player.walk_speed
		player.velocity_component.accelerate_in_direction(player.current_input_direction, delta)
		player.velocity_component.apply_to_body(player)

	if player.modular_visuals:
		player.modular_visuals.play_animation(&"walk", player.get_facing_direction_name())
