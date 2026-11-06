class_name BaseEnemy
extends CharacterBody2D

## BaseEnemy.gd
## Base entity class for enemy units in Petualang Untidar.
## Implements AI StateMachine, health, hurtbox, hitbox, velocity, and death lifecycle.

signal defeated(enemy_id: StringName, position: Vector2)

@export var enemy_id: StringName = &"dummy_slime"
@export var enemy_name: String = "Dummy Slime"
@export var max_health: int = 50
@export var defense: int = 2
@export var move_speed: float = 50.0
@export var aggro_radius: float = 120.0
@export var deaggro_radius: float = 180.0
@export var attack_range: float = 24.0
@export var attack_cooldown: float = 1.0
@export var base_damage: int = 10
@export var knockback_force: float = 100.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var velocity_component: VelocityComponent = get_node_or_null("VelocityComponent") as VelocityComponent
@onready var hurtbox_component: HurtboxComponent = get_node_or_null("HurtboxComponent") as HurtboxComponent
@onready var hitbox_component: HitboxComponent = get_node_or_null("HitboxComponent") as HitboxComponent
@onready var state_machine: StateMachine = get_node_or_null("StateMachine") as StateMachine

var target_player: CharacterBody2D = null
var attack_cooldown_timer: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	add_to_group(&"enemy")

	# Physics Layer: Layer 5 (Enemy Body: 16), Mask 1 (World: 1) | 2 (Player Body: 2) | 16 (Enemy Body: 16) = 19
	collision_layer = 16
	collision_mask = 19

	y_sort_enabled = true

	_setup_components()

	if health_component:
		health_component.max_health = max_health
		health_component.current_health = max_health
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)

	if velocity_component:
		velocity_component.max_speed = move_speed

	if hurtbox_component and not hurtbox_component.hit_received.is_connected(_on_hit_received):
		hurtbox_component.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer = maxf(0.0, attack_cooldown_timer - delta)


func _setup_components() -> void:
	# Fallback HealthComponent
	if not health_component:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = max_health
		health_component.current_health = max_health
		add_child(health_component)

	# Fallback VelocityComponent
	if not velocity_component:
		velocity_component = VelocityComponent.new()
		velocity_component.name = "VelocityComponent"
		velocity_component.max_speed = move_speed
		velocity_component.knockback_friction = 800.0
		add_child(velocity_component)

	# Fallback Hurtbox: Layer 6 (Enemy Hurtbox: 32), Mask 4 (Player Hitbox: 8)
	if not hurtbox_component:
		hurtbox_component = HurtboxComponent.new()
		hurtbox_component.name = "HurtboxComponent"
		hurtbox_component.collision_layer = 32
		hurtbox_component.collision_mask = 8
		hurtbox_component.faction = HurtboxComponent.Faction.ENEMY
		hurtbox_component.defense = defense
		hurtbox_component.health_component = health_component
		hurtbox_component.velocity_component = velocity_component
		hurtbox_component.invulnerability_duration = 0.2
		var h_shape := CollisionShape2D.new()
		var h_circle := CircleShape2D.new()
		h_circle.radius = 9.0
		h_shape.shape = h_circle
		hurtbox_component.add_child(h_shape)
		add_child(hurtbox_component)

	# Fallback Hitbox: Layer 7 (Enemy Hitbox: 64), Mask 3 (Player Hurtbox: 4)
	if not hitbox_component:
		hitbox_component = HitboxComponent.new()
		hitbox_component.name = "HitboxComponent"
		hitbox_component.collision_layer = 64
		hitbox_component.collision_mask = 4
		hitbox_component.faction = HitboxComponent.Faction.ENEMY
		hitbox_component.damage = base_damage
		hitbox_component.knockback_force = knockback_force
		hitbox_component.is_active = false
		var a_shape := CollisionShape2D.new()
		var a_circle := CircleShape2D.new()
		a_circle.radius = 8.0
		a_shape.shape = a_circle
		hitbox_component.add_child(a_shape)
		add_child(hitbox_component)

	# Fallback StateMachine
	if not state_machine:
		state_machine = StateMachine.new()
		state_machine.name = "StateMachine"
		add_child(state_machine)

		var idle := EnemyIdleState.new()
		idle.name = "Idle"
		state_machine.add_child(idle)

		var chase := EnemyChaseState.new()
		chase.name = "Chase"
		state_machine.add_child(chase)

		var attack := EnemyAttackState.new()
		attack.name = "Attack"
		state_machine.add_child(attack)

		var hurt := EnemyHurtState.new()
		hurt.name = "Hurt"
		state_machine.add_child(hurt)

		state_machine.initial_state = idle


func find_target_player() -> CharacterBody2D:
	if is_instance_valid(target_player):
		return target_player

	if not is_inside_tree():
		return null

	var players := get_tree().get_nodes_in_group(&"player")
	if not players.is_empty():
		target_player = players[0] as CharacterBody2D
		return target_player

	var p := get_parent()
	if p:
		for child in p.get_children():
			if child is Player:
				target_player = child
				return target_player

	return null


func can_attack() -> bool:
	return attack_cooldown_timer <= 0.0


func start_attack_cooldown() -> void:
	attack_cooldown_timer = attack_cooldown


func _on_hit_received(_hitbox: HitboxComponent) -> void:
	if is_dead:
		return

	if state_machine:
		var cur_name := state_machine.get_current_state_name()
		if cur_name != &"hurt":
			state_machine.transition_to(&"hurt")


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true

	# Disable AI processing
	if state_machine:
		state_machine.set_physics_process(false)
		state_machine.set_process(false)

	# Disable collision physics
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Disable Hitbox & Hurtbox
	if hitbox_component:
		hitbox_component.is_active = false
		hitbox_component.set_deferred("monitoring", false)
		hitbox_component.set_deferred("monitorable", false)

	if hurtbox_component:
		hurtbox_component.set_deferred("monitoring", false)
		hurtbox_component.set_deferred("monitorable", false)

	# Single emission of enemy_defeated
	var pos := global_position
	defeated.emit(enemy_id, pos)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.has_signal("enemy_defeated_at"):
			event_bus.enemy_defeated_at.emit(enemy_id, pos)
		if event_bus.has_signal("enemy_defeated"):
			event_bus.enemy_defeated.emit(enemy_id)

	# Visual death feedback
	if is_inside_tree():
		var tween := create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(self, "modulate:a", 0.0, 0.3)
			tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
			tween.chain().tween_callback(queue_free)
		else:
			queue_free()
	else:
		queue_free()
