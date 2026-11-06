class_name EnemyIdleState
extends State

## EnemyIdleState.gd
## Enemy stays stationary and scans for targets within aggro_radius.

var enemy: BaseEnemy


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
	if enemy and enemy.velocity_component:
		enemy.velocity_component.stop()


func physics_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return

	# Bring any remaining movement to a halt
	if enemy.velocity_component:
		enemy.velocity_component.decelerate(delta)
		enemy.velocity_component.apply_to_body(enemy, delta)

	var target := enemy.find_target_player()
	if target and is_instance_valid(target):
		var dist: float = enemy.global_position.distance_to(target.global_position)
		if dist <= enemy.aggro_radius:
			state_machine.transition_to(&"chase")

