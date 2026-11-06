class_name PlayerIdleState
extends State

## PlayerIdleState.gd
## Active when the player entity has no movement velocity or directional input.

var player: Player


func _ready() -> void:
	await owner.ready
	player = owner as Player


func enter(_msg: Dictionary = {}) -> void:
	if player and player.modular_visuals:
		player.modular_visuals.play_animation(&"idle", player.get_facing_direction_name())


func physics_update(delta: float) -> void:
	if not player:
		return

	player.current_input_direction = player.get_movement_input()

	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to(&"attack")
		return

	if Input.is_action_just_pressed("dodge"):
		state_machine.transition_to(&"roll")
		return

	if player.current_input_direction != Vector2.ZERO:
		state_machine.transition_to(&"move")
		return

	if player.velocity_component:
		player.velocity_component.decelerate(delta)
		player.velocity_component.apply_to_body(player, delta)
