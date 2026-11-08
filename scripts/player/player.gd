class_name Player
extends CharacterBody2D

## Player.gd
## Central controller for the Player entity.
## Integrates 8-direction movement, FSM, VelocityComponent, ModularVisuals, Camera2D, and Combat components.

@export var walk_speed: float = 120.0
@export var roll_speed: float = 240.0
@export var roll_duration: float = 0.25
@export var defense: int = 0

@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var state_machine: StateMachine = $StateMachine
@onready var modular_visuals: ModularVisuals = $ModularVisuals
@onready var camera: Camera2D = $Camera2D
@onready var interaction_component: InteractionComponent = get_node_or_null("InteractionComponent") as InteractionComponent
@onready var hurtbox_component: HurtboxComponent = get_node_or_null("HurtboxComponent") as HurtboxComponent
@onready var hitbox_component: HitboxComponent = get_node_or_null("HitboxComponent") as HitboxComponent
@onready var inventory_manager: InventoryManager = get_node_or_null("InventoryManager") as InventoryManager
@onready var equipment_manager: EquipmentManager = get_node_or_null("EquipmentManager") as EquipmentManager
@onready var character_stats: CharacterStats = get_node_or_null("CharacterStats") as CharacterStats
@onready var quest_manager: QuestManager = get_node_or_null("QuestManager") as QuestManager

var current_input_direction: Vector2 = Vector2.ZERO
var last_movement_direction: Vector2 = Vector2.DOWN
var touch_input_direction: Vector2 = Vector2.ZERO
var is_input_locked: bool = false


func _ready() -> void:
	add_to_group(&"player")

	# Configure player physical body collision: Layer 2 (Player Body), Mask 1 (World) | 16 (Enemy Body) = 17
	collision_layer = 2
	collision_mask = 17

	if velocity_component:
		velocity_component.max_speed = walk_speed

	_setup_combat_nodes()
	_setup_progression_nodes()


func _setup_combat_nodes() -> void:
	# Fallback Hurtbox setup: Layer 3 (Player Hurtbox: 4), Mask 7 (Enemy Hitbox: 64)
	if not hurtbox_component and has_node("HurtboxComponent"):
		hurtbox_component = $HurtboxComponent as HurtboxComponent

	if not hurtbox_component:
		hurtbox_component = HurtboxComponent.new()
		hurtbox_component.name = "HurtboxComponent"
		hurtbox_component.collision_layer = 4
		hurtbox_component.collision_mask = 64
		hurtbox_component.faction = HurtboxComponent.Faction.PLAYER
		hurtbox_component.health_component = health_component
		hurtbox_component.velocity_component = velocity_component
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		shape.position = Vector2(0, 4)
		hurtbox_component.add_child(shape)
		add_child(hurtbox_component)

	# Fallback Hitbox setup: Layer 4 (Player Hitbox: 8), Mask 6 (Enemy Hurtbox: 32)
	if not hitbox_component and has_node("HitboxComponent"):
		hitbox_component = $HitboxComponent as HitboxComponent

	if not hitbox_component:
		hitbox_component = HitboxComponent.new()
		hitbox_component.name = "HitboxComponent"
		hitbox_component.collision_layer = 8
		hitbox_component.collision_mask = 32
		hitbox_component.faction = HitboxComponent.Faction.PLAYER
		hitbox_component.damage = 15
		hitbox_component.is_active = false
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		shape.shape = circle
		hitbox_component.add_child(shape)
		add_child(hitbox_component)

	# Fallback Attack State in StateMachine if missing
	if state_machine and not state_machine.has_node("Attack"):
		var attack_state := PlayerAttackState.new()
		attack_state.name = "Attack"
		state_machine.add_child(attack_state)

	# Fallback Hurt State in StateMachine if missing
	if state_machine and not state_machine.has_node("Hurt"):
		var hurt_state := PlayerHurtState.new()
		hurt_state.name = "Hurt"
		state_machine.add_child(hurt_state)

	if hurtbox_component and not hurtbox_component.hit_received.is_connected(_on_hurtbox_hit_received):
		hurtbox_component.hit_received.connect(_on_hurtbox_hit_received)


func _on_hurtbox_hit_received(_hitbox: HitboxComponent) -> void:
	if state_machine:
		var cur := state_machine.get_current_state_name()
		if cur != &"roll" and cur != &"hurt":
			state_machine.transition_to(&"hurt")


func _setup_progression_nodes() -> void:
	if not inventory_manager and has_node("InventoryManager"):
		inventory_manager = $InventoryManager as InventoryManager
	if not inventory_manager:
		inventory_manager = InventoryManager.new()
		inventory_manager.name = "InventoryManager"
		add_child(inventory_manager)

	if not character_stats and has_node("CharacterStats"):
		character_stats = $CharacterStats as CharacterStats
	if not character_stats:
		character_stats = CharacterStats.new()
		character_stats.name = "CharacterStats"
		add_child(character_stats)

	if not equipment_manager and has_node("EquipmentManager"):
		equipment_manager = $EquipmentManager as EquipmentManager
	if not equipment_manager:
		equipment_manager = EquipmentManager.new()
		equipment_manager.name = "EquipmentManager"
		equipment_manager.inventory_manager = inventory_manager
		equipment_manager.character_stats = character_stats
		equipment_manager.modular_visuals = modular_visuals
		add_child(equipment_manager)
	else:
		equipment_manager.inventory_manager = inventory_manager
		equipment_manager.character_stats = character_stats
		equipment_manager.modular_visuals = modular_visuals

	if not quest_manager:
		var existing_qm := QuestManager.get_instance()
		if existing_qm:
			quest_manager = existing_qm
		elif has_node("QuestManager"):
			quest_manager = $QuestManager as QuestManager
		else:
			quest_manager = QuestManager.new()
			quest_manager.name = "QuestManager"
			add_child(quest_manager)

	if character_stats:
		if not character_stats.stats_changed.is_connected(_on_character_stats_changed):
			character_stats.stats_changed.connect(_on_character_stats_changed)
		character_stats.sync_with_player(self)

	if health_component and not health_component.health_changed.is_connected(_on_health_component_changed):
		health_component.health_changed.connect(_on_health_component_changed)


func _on_character_stats_changed() -> void:
	if character_stats:
		character_stats.sync_with_player(self)


func _on_health_component_changed(current: int, max_val: int) -> void:
	if character_stats:
		character_stats.set_health_from_component(current, max_val)


func heal(amount: int) -> void:
	if health_component:
		health_component.heal(amount)
	elif character_stats:
		character_stats.heal(amount)


func get_movement_input() -> Vector2:
	if is_input_locked:
		return Vector2.ZERO

	# 1. Keyboard / Gamepad input (automatically deadzoned and normalized by Godot)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 2. Virtual touchscreen joystick input fallback
	if dir == Vector2.ZERO and touch_input_direction != Vector2.ZERO:
		dir = touch_input_direction.normalized()

	return dir


func get_facing_direction_name() -> StringName:
	var dir := last_movement_direction
	if absf(dir.x) > absf(dir.y):
		return &"right" if dir.x > 0.0 else &"left"
	else:
		return &"down" if dir.y >= 0.0 else &"up"


func get_facing_direction_8way() -> StringName:
	var dir := last_movement_direction
	if dir == Vector2.ZERO:
		return &"down"
	var angle := dir.angle()
	var octant := int(round(angle / (PI / 4.0)))
	if octant < 0:
		octant += 8
	octant = octant % 8
	match octant:
		0: return &"right"
		1: return &"down_right"
		2: return &"down"
		3: return &"down_left"
		4: return &"left"
		5: return &"up_left"
		6: return &"up"
		7: return &"up_right"
		_: return &"down"


func set_touch_input(touch_dir: Vector2) -> void:
	touch_input_direction = touch_dir


func trigger_dodge() -> void:
	if is_input_locked:
		return
	if state_machine and (state_machine.get_current_state_name() == &"idle" or state_machine.get_current_state_name() == &"move"):
		state_machine.transition_to(&"roll")


func trigger_attack() -> void:
	if is_input_locked:
		return
	if state_machine:
		var cur := state_machine.get_current_state_name()
		if cur == &"idle" or cur == &"move":
			state_machine.transition_to(&"attack")
		elif cur == &"attack":
			var attack_state := state_machine.get_node_or_null("Attack") as PlayerAttackState
			if attack_state:
				attack_state.buffer_combo_input()


func trigger_interact() -> void:
	if is_input_locked:
		return
	if interaction_component:
		interaction_component.interact_with_current_target()
