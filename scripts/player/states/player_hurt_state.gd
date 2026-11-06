class_name PlayerHurtState
extends State

## PlayerHurtState.gd
## Manages Player reaction when receiving damage and knockback.
## Features brief stagger, deceleration, responsive dodge-cancel,
## and clean transition back to Move or Idle without locking player control.

@export var hurt_duration: float = 0.15

var player: Player
var _elapsed: float = 0.0


func _ready() -> void:
	if owner:
		if not owner.is_node_ready():
			await owner.ready
		player = owner as Player
	elif not player:
		var p := get_parent()
		while p and not (p is Player):
			p = p.get_parent()
		player = p as Player


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0

	# Disable attack hitbox if hit during an attack swing
	if player and player.hitbox_component:
		player.hitbox_component.is_active = false
		player.hitbox_component.reset_hit_targets()

	# Play hurt visual animation if available
	if player and player.modular_visuals:
		player.modular_visuals.play_animation(&"hurt", player.get_facing_direction_name())


func physics_update(delta: float) -> void:
	if not player:
		return

	_elapsed += delta

	# Responsive dodge cancel: player can roll out of danger during stagger
	if Input.is_action_just_pressed("dodge"):
		state_machine.transition_to(&"roll")
		return

	# Maintain deceleration and process knockback physics with delta
	if player.velocity_component:
		player.velocity_component.decelerate(delta)
		player.velocity_component.apply_to_body(player, delta)

	# Transition back to movement or idle upon completion
	if _elapsed >= hurt_duration:
		player.current_input_direction = player.get_movement_input()
		if player.current_input_direction != Vector2.ZERO:
			state_machine.transition_to(&"move")
		else:
			state_machine.transition_to(&"idle")
