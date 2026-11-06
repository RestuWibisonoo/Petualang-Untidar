class_name HitboxComponent
extends Area2D

## HitboxComponent.gd
## Area2D that transmits damage and knockback to HurtboxComponents.
## Supports faction filtering, knockback force, and single-hit per attack window tracking.

signal hit_landed(target_hurtbox: Area2D)

enum Faction {
	PLAYER = 0,
	ENEMY = 1,
	NEUTRAL = 2
}

@export var faction: Faction = Faction.PLAYER
@export var damage: int = 10
@export var knockback_force: float = 150.0
@export var is_active: bool = true:
	set(val):
		is_active = val
		set_deferred("monitoring", val)
		set_deferred("monitorable", val)
		if not val:
			_hit_targets.clear()

var _hit_targets: Array[Area2D] = []


func _ready() -> void:
	monitoring = is_active
	monitorable = is_active
	area_entered.connect(_on_area_entered)


func get_damage() -> int:
	return damage


func has_hit_target(target: Area2D) -> bool:
	return _hit_targets.has(target)


func notify_hit(target: Area2D) -> void:
	if not _hit_targets.has(target):
		_hit_targets.append(target)
	hit_landed.emit(target)


func reset_hit_targets() -> void:
	_hit_targets.clear()


func _on_area_entered(area: Area2D) -> void:
	if not is_active or _hit_targets.has(area):
		return

	if area is HurtboxComponent:
		var hurtbox: HurtboxComponent = area as HurtboxComponent
		if int(hurtbox.faction) != int(faction):
			hurtbox.receive_hit(self)
