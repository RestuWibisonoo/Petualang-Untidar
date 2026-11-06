class_name EnemyChaseState
extends State

## EnemyChaseState.gd
## Enemy pursues target player while within deaggro_radius.
## Transitions to attack when within attack_range and attack cooldown is ready.

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


func physics_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return

	var target := enemy.find_target_player()
	if not target or not is_instance_valid(target):
		state_machine.transition_to(&"idle")
		return

	var dist: float = enemy.global_position.distance_to(target.global_position)

	# 1. Target escaped beyond de-aggro threshold
	if dist > enemy.deaggro_radius:
		state_machine.transition_to(&"idle")
		return

	# 2. Within attack range and cooldown ready
	if dist <= enemy.attack_range and enemy.can_attack():
		state_machine.transition_to(&"attack")
		return

	# 3. Pursue target
	var dir: Vector2 = (target.global_position - enemy.global_position).normalized()
	if enemy.velocity_component:
		enemy.velocity_component.accelerate_in_direction(dir, delta)
		enemy.velocity_component.apply_to_body(enemy)

	if enemy.sprite and absf(dir.x) > 0.05:
		enemy.sprite.flip_h = dir.x < 0.0
