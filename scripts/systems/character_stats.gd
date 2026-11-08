class_name CharacterStats
extends Node

## CharacterStats.gd
## Central character attributes, progression, and combat stats manager.
## Computes effective attributes from Base Stats + Equipment Bonuses + Allocated Stat Points.
## Manages EXP accumulation, level up thresholds, and stat point distributions.

signal stats_changed
signal exp_changed(current_exp: int, exp_to_next_level: int)
signal level_up(new_level: int, available_stat_points: int)
signal health_changed(current: int, max_val: int)

@export var base_max_health: int = 100
@export var base_attack: int = 15
@export var base_defense: int = 0
@export var base_movement_speed: float = 120.0

@export var health_per_point: int = 10
@export var attack_per_point: int = 2
@export var defense_per_point: int = 1
@export var stat_points_per_level: int = 3

@export var base_exp_requirement: int = 100
@export var exp_growth_factor: float = 1.4

var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 100
var available_stat_points: int = 0

var allocated_health_points: int = 0
var allocated_attack_points: int = 0
var allocated_defense_points: int = 0

var max_health: int = 100
var current_health: int = 100
var attack: int = 15
var defense: int = 0
var movement_speed: float = 120.0

var _last_equipment_bonuses: Dictionary = {}
var health_component_ref: HealthComponent = null

static var instance: CharacterStats = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	exp_to_next_level = get_exp_required_for_level(level)
	current_health = base_max_health
	recalculate()


static func get_default() -> CharacterStats:
	return instance


func get_exp_required_for_level(lvl: int) -> int:
	if lvl <= 1:
		return base_exp_requirement
	return int(base_exp_requirement * pow(float(lvl), exp_growth_factor))


func recalculate(equipment_bonuses: Dictionary = {}) -> void:
	if not equipment_bonuses.is_empty():
		_last_equipment_bonuses = equipment_bonuses

	var eq_hp: int = int(_last_equipment_bonuses.get("health", 0))
	var eq_atk: int = int(_last_equipment_bonuses.get("attack", 0))
	var eq_def: int = int(_last_equipment_bonuses.get("defense", 0))
	var eq_spd: float = float(_last_equipment_bonuses.get("movement_speed", 0.0))

	max_health = base_max_health + (allocated_health_points * health_per_point) + eq_hp
	attack = base_attack + (allocated_attack_points * attack_per_point) + eq_atk
	defense = base_defense + (allocated_defense_points * defense_per_point) + eq_def
	movement_speed = base_movement_speed + eq_spd

	# Current health must never exceed max_health
	if health_component_ref and is_instance_valid(health_component_ref):
		health_component_ref.max_health = max_health
		current_health = health_component_ref.current_health
	else:
		current_health = mini(current_health, max_health)

	stats_changed.emit()
	health_changed.emit(current_health, max_health)

	# Forward to global EventBus if available
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("player_health_changed"):
		event_bus.player_health_changed.emit(current_health, max_health)


func sync_with_player(player: Node2D) -> void:
	if not player:
		return

	if "defense" in player:
		player.defense = defense

	if "walk_speed" in player:
		player.walk_speed = movement_speed

	var vel_comp: Node = player.get_node_or_null("VelocityComponent")
	if vel_comp and "max_speed" in vel_comp:
		vel_comp.max_speed = movement_speed

	var health_comp: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp:
		health_component_ref = health_comp
		health_comp.max_health = max_health
		health_comp.current_health = mini(health_comp.current_health, max_health)
		current_health = health_comp.current_health

	var hurtbox: Node = player.get_node_or_null("HurtboxComponent")
	if hurtbox and "defense" in hurtbox:
		hurtbox.defense = defense


func set_health_from_component(current: int, max_val: int) -> void:
	var changed: bool = (current_health != current or max_health != max_val)
	current_health = current
	max_health = max_val
	if changed:
		health_changed.emit(current_health, max_health)
		var event_bus := _get_event_bus()
		if event_bus and event_bus.has_signal("player_health_changed"):
			event_bus.player_health_changed.emit(current_health, max_health)


func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	current_exp += amount
	var leveled_up_count: int = 0

	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level += 1
		available_stat_points += stat_points_per_level
		exp_to_next_level = get_exp_required_for_level(level)
		leveled_up_count += 1
		level_up.emit(level, available_stat_points)

		var event_bus := _get_event_bus()
		if event_bus and event_bus.has_signal("player_leveled_up"):
			event_bus.player_leveled_up.emit(level, available_stat_points)

	recalculate()
	exp_changed.emit(current_exp, exp_to_next_level)

	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("exp_gained"):
		event_bus.exp_gained.emit(amount, current_exp, exp_to_next_level)


func allocate_stat_point(stat_name: StringName, points: int = 1) -> bool:
	if points <= 0 or available_stat_points < points:
		return false

	match stat_name:
		&"health":
			allocated_health_points += points
		&"attack":
			allocated_attack_points += points
		&"defense":
			allocated_defense_points += points
		_:
			return false

	available_stat_points -= points
	recalculate()
	return true


func heal(amount: int) -> void:
	if amount <= 0:
		return
	if health_component_ref and is_instance_valid(health_component_ref):
		health_component_ref.heal(amount)
	else:
		current_health = mini(max_health, current_health + amount)
		health_changed.emit(current_health, max_health)
		var event_bus := _get_event_bus()
		if event_bus and event_bus.has_signal("player_health_changed"):
			event_bus.player_health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	if health_component_ref and is_instance_valid(health_component_ref):
		health_component_ref.take_damage(amount)
	else:
		current_health = maxi(0, current_health - amount)
		health_changed.emit(current_health, max_health)
		var event_bus := _get_event_bus()
		if event_bus and event_bus.has_signal("player_health_changed"):
			event_bus.player_health_changed.emit(current_health, max_health)


func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null


func reset_allocated_stats() -> void:
	var total_points: int = allocated_health_points + allocated_attack_points + allocated_defense_points
	available_stat_points += total_points
	allocated_health_points = 0
	allocated_attack_points = 0
	allocated_defense_points = 0
	recalculate()


func reset_all() -> void:
	level = 1
	current_exp = 0
	exp_to_next_level = get_exp_required_for_level(1)
	available_stat_points = 0
	allocated_health_points = 0
	allocated_attack_points = 0
	allocated_defense_points = 0
	_last_equipment_bonuses.clear()
	current_health = base_max_health
	recalculate()
