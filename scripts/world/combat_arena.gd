class_name CombatArena
extends WorldBase

## CombatArena.gd
## Dedicated test and training arena for combat system validation.
## Features player, hostile training dummies (BaseEnemy slimes), and real-time status diagnostics.

@onready var enemy_count_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/VBoxRight/EnemyCountLabel") as Label
@onready var player_hp_label: Label = get_node_or_null("HUD/MarginContainer/HBoxContainer/VBoxLeft/PlayerHPLabel") as Label


func _ready() -> void:
	level_name = "Arena Latihan Tempur Untidar"
	super._ready()

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("enemy_defeated"):
		event_bus.enemy_defeated.connect(_on_enemy_defeated)


func _process(delta: float) -> void:
	super._process(delta)
	_update_combat_hud()


func _update_combat_hud() -> void:
	if player and player.health_component and player_hp_label:
		player_hp_label.text = "Player HP: %d / %d" % [player.health_component.current_health, player.health_component.max_health]

	if enemy_count_label and is_inside_tree():
		var enemies := get_tree().get_nodes_in_group(&"enemy")
		var living_count: int = 0
		for e in enemies:
			if e is BaseEnemy and not (e as BaseEnemy).is_dead:
				living_count += 1
		enemy_count_label.text = "Musuh Aktif: %d" % living_count


func _on_enemy_defeated(enemy_id: StringName) -> void:
	print("[CombatArena] Musuh dikalahkan: %s" % enemy_id)
	_update_combat_hud()
