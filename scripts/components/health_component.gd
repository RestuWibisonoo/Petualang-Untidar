class_name HealthComponent
extends Node

## HealthComponent.gd
## Reusable component managing health, damage intake, and healing.

signal health_changed(current: int, max_val: int)
signal damage_taken(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 100:
	set(val):
		max_health = maxi(1, val)
		current_health = mini(current_health, max_health)
		health_changed.emit(current_health, max_health)

var current_health: int = 100
var is_invulnerable: bool = false


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or is_invulnerable or current_health <= 0:
		return

	var applied_damage: int = mini(current_health, amount)
	current_health -= applied_damage

	damage_taken.emit(applied_damage)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	var applied_heal: int = mini(max_health - current_health, amount)
	current_health += applied_heal

	healed.emit(applied_heal)
	health_changed.emit(current_health, max_health)


func is_alive() -> bool:
	return current_health > 0


func get_health_ratio() -> float:
	return float(current_health) / float(max_health)

