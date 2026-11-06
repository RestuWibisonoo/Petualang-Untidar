class_name HurtboxComponent
extends Area2D

## HurtboxComponent.gd
## Area2D that receives damage from HitboxComponents and forwards it to HealthComponent.
## Manages faction filtering, defense calculation, knockback application, and i-frames.

signal hit_received(hitbox: HitboxComponent)
signal invulnerability_started
signal invulnerability_ended

enum Faction {
	PLAYER = 0,
	ENEMY = 1,
	NEUTRAL = 2
}

@export var faction: Faction = Faction.NEUTRAL
@export var health_component: HealthComponent
@export var velocity_component: VelocityComponent
@export var defense: int = 0
@export var invulnerability_duration: float = 0.5

var is_invulnerable: bool = false
var _invulnerability_timer: Timer


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_setup_timer()

	if not health_component and owner:
		health_component = owner.get_node_or_null("HealthComponent") as HealthComponent
	if not velocity_component and owner:
		velocity_component = owner.get_node_or_null("VelocityComponent") as VelocityComponent


func _setup_timer() -> void:
	_invulnerability_timer = Timer.new()
	_invulnerability_timer.name = "InvulnerabilityTimer"
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(_invulnerability_timer)


func _on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		receive_hit(area as HitboxComponent)


func receive_hit(hitbox: HitboxComponent) -> void:
	if is_invulnerable or not hitbox.is_active:
		return

	if hitbox.has_hit_target(self):
		return

	# Faction validation: cannot hit allies of the same faction (unless NEUTRAL)
	if faction != Faction.NEUTRAL and hitbox.faction != Faction.NEUTRAL and int(hitbox.faction) == int(faction):
		return

	if health_component and not health_component.is_alive():
		return

	var raw_damage: int = hitbox.get_damage()
	var effective_defense: int = defense
	if owner and "defense" in owner:
		effective_defense = int(owner.defense)
	elif get_parent() and "defense" in get_parent():
		effective_defense = int(get_parent().defense)

	var final_damage: int = raw_damage - effective_defense
	if final_damage <= 0:
		# Zero or negative damage is ignored
		return

	if health_component:
		health_component.take_damage(final_damage)

	# Apply directional physics knockback from attacker
	var attacker_pos: Vector2 = hitbox.global_position
	if hitbox.owner and hitbox.owner is Node2D:
		attacker_pos = (hitbox.owner as Node2D).global_position
	elif hitbox.get_parent() and hitbox.get_parent() is Node2D:
		attacker_pos = (hitbox.get_parent() as Node2D).global_position

	var knockback_dir: Vector2 = (global_position - attacker_pos).normalized()
	if knockback_dir == Vector2.ZERO or not knockback_dir.is_finite():
		knockback_dir = (global_position - hitbox.global_position).normalized()
	if knockback_dir == Vector2.ZERO or not knockback_dir.is_finite():
		knockback_dir = Vector2.DOWN

	if velocity_component and hitbox.knockback_force > 0.0:
		velocity_component.apply_knockback(knockback_dir * hitbox.knockback_force)

	# Visual hit flash
	_play_hit_flash()

	# Emit global combat events
	var event_bus: Node = null
	if is_inside_tree():
		event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		var target_node: Node2D = owner as Node2D if owner is Node2D else self
		if event_bus.has_signal("damage_dealt"):
			event_bus.damage_dealt.emit(target_node, final_damage, false)
		if event_bus.has_signal("show_floating_text"):
			event_bus.show_floating_text.emit(str(final_damage), global_position + Vector2(0, -16), Color(1.0, 0.25, 0.25))

	hitbox.notify_hit(self)
	hit_received.emit(hitbox)

	if invulnerability_duration > 0.0:
		start_invulnerability(invulnerability_duration)


func start_invulnerability(duration: float) -> void:
	is_invulnerable = true
	if health_component:
		health_component.is_invulnerable = true
	invulnerability_started.emit()
	if _invulnerability_timer:
		_invulnerability_timer.start(duration)


func _on_invulnerability_timeout() -> void:
	is_invulnerable = false
	if health_component:
		health_component.is_invulnerable = false
	invulnerability_ended.emit()


func _play_hit_flash() -> void:
	var target_item: CanvasItem = owner as CanvasItem if owner is CanvasItem else (get_parent() as CanvasItem if get_parent() is CanvasItem else self)
	if not target_item or not is_inside_tree():
		return
	var orig_color: Color = target_item.modulate
	target_item.modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	if tween:
		tween.tween_property(target_item, "modulate", orig_color, 0.15)
