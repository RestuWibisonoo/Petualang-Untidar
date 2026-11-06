class_name HitboxComponent
extends Area2D

## HitboxComponent.gd
## Area2D that transmits damage and knockback to HurtboxComponents.

signal hit_landed(target_hurtbox: Area2D)

@export var damage: int = 10
@export var knockback_force: float = 150.0
@export var is_active: bool = true:
	set(val):
		is_active = val
		monitoring = val
		monitorable = val


func _ready() -> void:
	monitoring = is_active
	monitorable = is_active


func get_damage() -> int:
	return damage


func notify_hit(target: Area2D) -> void:
	hit_landed.emit(target)

