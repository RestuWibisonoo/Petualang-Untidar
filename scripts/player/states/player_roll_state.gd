class_name PlayerRollState
extends State

## PlayerRollState.gd
## Performs a directional dodge/roll maneuver with fixed speed and duration.

var player: Player
var _roll_timer: float = 0.0
var _roll_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	await owner.ready
	player = owner as Player


func enter(_msg: Dictionary = {}) -> void:
	if not player:
		return

	# Determine roll direction: use current input direction, or fallback to last movement direction
	if player.current_input_direction != Vector2.ZERO:
		_roll_direction = player.current_input_direction.normalized()
	elif player.last_movement_direction != Vector2.ZERO:
		_roll_direction = player.last_movement_direction.normalized()
	else:
		_roll_direction = Vector2.DOWN

	player.last_movement_direction = _roll_direction
	_roll_timer = player.roll_duration

	if player.velocity_component:
		player.velocity_component.velocity = _roll_direction * player.roll_speed

	if player.modular_visuals:
		player.modular_visuals.play_animation(&"roll", player.get_facing_direction_name())


func physics_update(delta: float) -> void:
	if not player:
		return

	_roll_timer -= delta

	if player.velocity_component:
		player.velocity_component.apply_to_body(player, delta)

	if _roll_timer <= 0.0:
		player.current_input_direction = player.get_movement_input()
		if player.current_input_direction != Vector2.ZERO:
			state_machine.transition_to(&"move")
		else:
			state_machine.transition_to(&"idle")
