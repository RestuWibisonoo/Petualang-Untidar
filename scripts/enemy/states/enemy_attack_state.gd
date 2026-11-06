class_name EnemyAttackState
extends State

## EnemyAttackState.gd
## Enemy executes a melee attack with startup, active hit window, and recovery.

@export var startup_duration: float = 0.15
@export var active_duration: float = 0.15
@export var recovery_duration: float = 0.20
@export var attack_reach: float = 14.0

var enemy: BaseEnemy
var _attack_elapsed: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	if owner:
		if not owner.is_node_ready():
			await owner.ready
		enemy = owner as BaseEnemy
	elif not enemy:
		var p := get_parent()
		while p and not (p is BaseEnemy):
			p = p.get_parent()
		enemy = p as BaseEnemy


func enter(_msg: Dictionary = {}) -> void:
	if not enemy or enemy.is_dead:
		return

	_attack_elapsed = 0.0

	# 1. Decelerate movement during attack
	if enemy.velocity_component:
		enemy.velocity_component.stop()

	# 2. Orient attack toward target player
	var target := enemy.find_target_player()
	if target and is_instance_valid(target):
		var to_target: Vector2 = target.global_position - enemy.global_position
		if to_target.length_squared() > 0.01:
			_attack_direction = to_target.normalized()
		else:
			_attack_direction = Vector2.DOWN
	else:
		_attack_direction = Vector2.DOWN

	if enemy.sprite and absf(_attack_direction.x) > 0.05:
		enemy.sprite.flip_h = _attack_direction.x < 0.0

	# 3. Position and configure enemy Hitbox
	if enemy.hitbox_component:
		enemy.hitbox_component.position = _attack_direction * attack_reach
		enemy.hitbox_component.reset_hit_targets()
		enemy.hitbox_component.is_active = false


func physics_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		if enemy and enemy.hitbox_component:
			enemy.hitbox_component.is_active = false
		return

	_attack_elapsed += delta

	# Maintain deceleration
	if enemy.velocity_component:
		enemy.velocity_component.decelerate(delta)
		enemy.velocity_component.apply_to_body(enemy)

	var hitbox := enemy.hitbox_component
	var total_duration: float = startup_duration + active_duration + recovery_duration

	# Phase 1: Startup
	if _attack_elapsed < startup_duration:
		if hitbox and hitbox.is_active:
			hitbox.is_active = false

	# Phase 2: Active Window
	elif _attack_elapsed < (startup_duration + active_duration):
		if hitbox and not hitbox.is_active:
			hitbox.is_active = true

	# Phase 3: Recovery
	elif _attack_elapsed < total_duration:
		if hitbox and hitbox.is_active:
			hitbox.is_active = false

	# Attack Cycle Finished
	else:
		if hitbox and hitbox.is_active:
			hitbox.is_active = false

		enemy.start_attack_cooldown()

		var target := enemy.find_target_player()
		if target and is_instance_valid(target):
			var dist: float = enemy.global_position.distance_to(target.global_position)
			if dist <= enemy.deaggro_radius:
				state_machine.transition_to(&"chase")
				return

		state_machine.transition_to(&"idle")


func exit() -> void:
	if enemy and enemy.hitbox_component:
		enemy.hitbox_component.is_active = false
		enemy.hitbox_component.reset_hit_targets()
