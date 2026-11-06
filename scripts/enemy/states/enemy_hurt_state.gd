class_name EnemyHurtState
extends State

## EnemyHurtState.gd
## Enemy is staggered momentarily by hit reception and knockback physics.

@export var hurt_duration: float = 0.25

var enemy: BaseEnemy
var _hurt_elapsed: float = 0.0


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
	_hurt_elapsed = 0.0
	if enemy and enemy.hitbox_component:
		enemy.hitbox_component.is_active = false


func physics_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return

	_hurt_elapsed += delta

	# Process knockback momentum dissipation through standard velocity physics
	if enemy.velocity_component:
		enemy.velocity_component.apply_to_body(enemy, delta)

	if _hurt_elapsed >= hurt_duration:
		var target := enemy.find_target_player()
		if target and is_instance_valid(target):
			var dist: float = enemy.global_position.distance_to(target.global_position)
			if dist <= enemy.deaggro_radius:
				state_machine.transition_to(&"chase")
				return

		state_machine.transition_to(&"idle")
