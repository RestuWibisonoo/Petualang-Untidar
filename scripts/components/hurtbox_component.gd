class_name HurtboxComponent
extends Area2D

## HurtboxComponent.gd
## Area2D that receives damage from HitboxComponents and forwards it to HealthComponent.
## Manages invulnerability frames (i-frames) upon receiving damage.

signal hit_received(hitbox: HitboxComponent)
signal invulnerability_started
signal invulnerability_ended

@export var health_component: HealthComponent
@export var invulnerability_duration: float = 0.5

var is_invulnerable: bool = false
var _invulnerability_timer: Timer


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_setup_timer()


func _setup_timer() -> void:
	_invulnerability_timer = Timer.new()
	_invulnerability_timer.name = "InvulnerabilityTimer"
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(_invulnerability_timer)


func _on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		receive_hit(area)


func receive_hit(hitbox: HitboxComponent) -> void:
	if is_invulnerable or not hitbox.is_active:
		return

	if health_component:
		health_component.take_damage(hitbox.get_damage())

	hitbox.notify_hit(self)
	hit_received.emit(hitbox)

	if invulnerability_duration > 0.0:
		start_invulnerability(invulnerability_duration)


func start_invulnerability(duration: float) -> void:
	is_invulnerable = true
	invulnerability_started.emit()
	_invulnerability_timer.start(duration)


func _on_invulnerability_timeout() -> void:
	is_invulnerable = false
	invulnerability_ended.emit()

