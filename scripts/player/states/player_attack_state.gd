class_name PlayerAttackState
extends State

## PlayerAttackState.gd
## Manages 8-directional player attacks with a 2-stage combo system,
## configurable startup/active/recovery windows, and hitbox orientation.

@export var startup_duration: float = 0.08
@export var active_duration: float = 0.12
@export var recovery_duration: float = 0.10
@export var attack_reach: float = 18.0

@export var stage_1_damage: int = 15
@export var stage_1_knockback: float = 120.0

@export var stage_2_damage: int = 25
@export var stage_2_knockback: float = 200.0

var player: Player
var combo_stage: int = 1
var _attack_elapsed: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN
var _combo_buffered: bool = false
var _combo_window_open: bool = false


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
	if not player:
		return

	# If coming from a combo continuation, msg may specify combo_stage
	if _msg.has("combo_stage"):
		combo_stage = int(_msg["combo_stage"])
	else:
		combo_stage = 1

	_attack_elapsed = 0.0
	_combo_buffered = false
	_combo_window_open = false

	# 1. Determine attack direction using 8-directional mapping
	if player.current_input_direction != Vector2.ZERO:
		_attack_direction = player.current_input_direction.normalized()
	elif player.last_movement_direction != Vector2.ZERO:
		_attack_direction = player.last_movement_direction.normalized()
	else:
		_attack_direction = Vector2.DOWN

	player.last_movement_direction = _attack_direction

	# 2. Position and configure player's HitboxComponent
	var hitbox := player.hitbox_component
	if hitbox:
		var bonus_atk: int = (player.character_stats.attack - 15) if (player and player.character_stats) else 0
		var base_dmg := stage_2_damage if combo_stage == 2 else stage_1_damage
		hitbox.damage = base_dmg + bonus_atk
		hitbox.knockback_force = stage_2_knockback if combo_stage == 2 else stage_1_knockback
		hitbox.faction = HitboxComponent.Faction.PLAYER
		hitbox.position = _attack_direction * attack_reach
		hitbox.reset_hit_targets()
		hitbox.is_active = false # Inactive during startup

	# 3. Play animation
	if player.modular_visuals:
		var dir_name: StringName = player.get_facing_direction_name()
		player.modular_visuals.play_animation(&"attack", dir_name)


func physics_update(delta: float) -> void:
	if not player:
		return

	_attack_elapsed += delta

	# Natural deceleration during attack swing
	if player.velocity_component:
		player.velocity_component.decelerate(delta)
		player.velocity_component.apply_to_body(player, delta)

	# Check for combo input buffer
	if Input.is_action_just_pressed("attack"):
		buffer_combo_input()

	var hitbox := player.hitbox_component
	var total_duration := startup_duration + active_duration + recovery_duration

	# Phase 1: Startup
	if _attack_elapsed < startup_duration:
		if hitbox and hitbox.is_active:
			hitbox.is_active = false

	# Phase 2: Active Hit Window
	elif _attack_elapsed < (startup_duration + active_duration):
		if hitbox and not hitbox.is_active:
			hitbox.is_active = true
		_combo_window_open = true

	# Phase 3: Recovery
	elif _attack_elapsed < total_duration:
		if hitbox and hitbox.is_active:
			hitbox.is_active = false
		_combo_window_open = true

	# Attack Finished
	else:
		if hitbox and hitbox.is_active:
			hitbox.is_active = false

		if combo_stage == 1 and _combo_buffered:
			# Advance to Combo Stage 2!
			state_machine.transition_to(&"attack", {"combo_stage": 2})
			return

		# End of attack combo: reset combo to stage 1 and return to movement or idle
		combo_stage = 1
		player.current_input_direction = player.get_movement_input()
		if player.current_input_direction != Vector2.ZERO:
			state_machine.transition_to(&"move")
		else:
			state_machine.transition_to(&"idle")


func exit() -> void:
	var hitbox := player.hitbox_component if player else null
	if hitbox:
		hitbox.is_active = false
		hitbox.reset_hit_targets()
	_combo_buffered = false
	_combo_window_open = false


func buffer_combo_input() -> void:
	if _combo_window_open and combo_stage < 2:
		_combo_buffered = true
