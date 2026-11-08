class_name BossEnemy
extends BaseEnemy

## BossEnemy.gd
## Two-phase boss encounter entity for Petualang Untidar.
## Extends BaseEnemy, adding an Enrage mechanic when health drops <= 50%.
## Emits enraged and phase_changed signals, and rewards 500 EXP upon defeat.

signal phase_changed(new_phase: int)
signal enraged()

@export var phase_2_health_threshold: float = 0.5
@export var phase_2_speed: float = 75.0
@export var phase_2_damage: int = 30
@export var phase_2_attack_cooldown: float = 0.7
@export var phase_2_modulate: Color = Color(1.3, 0.45, 0.45, 1.0)

var current_phase: int = 1
var is_enraged: bool = false


func _init() -> void:
	enemy_id = &"boss_gorgon"
	enemy_name = "Gorgon Penjaga Labirin"
	max_health = 200
	defense = 4
	move_speed = 50.0
	aggro_radius = 200.0
	deaggro_radius = 320.0
	attack_range = 36.0
	attack_cooldown = 1.2
	base_damage = 20
	knockback_force = 140.0
	exp_reward = 500


func _ready() -> void:
	super._ready()

	# Connect to health_changed to detect enrage threshold
	if health_component and not health_component.health_changed.is_connected(_on_boss_health_changed):
		health_component.health_changed.connect(_on_boss_health_changed)

	# Verify if already below threshold (e.g., if spawned with reduced health)
	if health_component and health_component.get_health_ratio() <= phase_2_health_threshold:
		trigger_enrage()


func _on_boss_health_changed(cur_hp: int, max_hp: int) -> void:
	if is_dead or is_enraged or max_hp <= 0:
		return

	var ratio: float = float(cur_hp) / float(max_hp)
	if ratio <= phase_2_health_threshold:
		trigger_enrage()


func trigger_enrage() -> void:
	if is_enraged:
		return

	is_enraged = true
	current_phase = 2

	# Stat boosts
	move_speed = phase_2_speed
	if velocity_component:
		velocity_component.max_speed = phase_2_speed

	base_damage = phase_2_damage
	if hitbox_component:
		hitbox_component.damage = phase_2_damage

	attack_cooldown = phase_2_attack_cooldown

	# Visual enrage feedback
	if sprite:
		if is_inside_tree():
			var tween: Tween = create_tween()
			if tween:
				tween.tween_property(sprite, "modulate", phase_2_modulate, 0.3)
			else:
				sprite.modulate = phase_2_modulate
		else:
			sprite.modulate = phase_2_modulate
	else:
		modulate = phase_2_modulate

	enraged.emit()
	phase_changed.emit(current_phase)
