class_name LootSpawner
extends Node

## LootSpawner.gd
## Event-driven spawner that manages enemy drop tables, EXP distribution, and world item instantiation.
## Listens to EventBus defeat events, prevents duplicate processing, and provides injectable RNG for testing.

signal loot_spawned(enemy_id: StringName, items: Array[WorldItem])
signal exp_awarded(enemy_id: StringName, amount: int)

@export var world_item_scene: PackedScene = preload("res://scenes/objects/world_item.tscn")

var loot_tables: Dictionary = {} # StringName -> LootTable
var exp_rewards: Dictionary = {} # StringName -> int

var rng: RandomNumberGenerator = null
var _processed_instance_ids: Dictionary = {} # int (enemy_instance_id) -> int (timestamp)
var _processed_fallback_events: Dictionary = {} # StringName -> int (timestamp)

static var instance: LootSpawner = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	_connect_event_bus()


static func get_default() -> LootSpawner:
	return instance


func set_rng(custom_rng: RandomNumberGenerator) -> void:
	rng = custom_rng


func register_loot_table(enemy_id: StringName, table: LootTable, exp_reward: int = 0) -> void:
	loot_tables[enemy_id] = table
	if exp_reward > 0:
		exp_rewards[enemy_id] = exp_reward


func _connect_event_bus() -> void:
	if not is_inside_tree():
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if not event_bus:
		return

	if event_bus.has_signal("enemy_defeated_at") and not event_bus.enemy_defeated_at.is_connected(_on_enemy_defeated_at):
		event_bus.enemy_defeated_at.connect(_on_enemy_defeated_at)
	elif event_bus.has_signal("enemy_defeated") and not event_bus.enemy_defeated.is_connected(_on_enemy_defeated):
		event_bus.enemy_defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(enemy_id: StringName) -> void:
	# Fallback if position was not passed: find enemy position or player position
	var spawn_pos: Vector2 = Vector2.ZERO
	var tree := get_tree()
	if tree:
		var players := tree.get_nodes_in_group(&"player")
		if not players.is_empty() and players[0] is Node2D:
			spawn_pos = (players[0] as Node2D).global_position + Vector2(20, 0)

	_process_defeat(enemy_id, spawn_pos, 0, null, 0)


func _on_enemy_defeated_at(enemy_id: StringName, world_pos: Vector2, exp_reward: int = 0, loot_table: LootTable = null, enemy_instance_id: int = 0) -> void:
	_process_defeat(enemy_id, world_pos, exp_reward, loot_table, enemy_instance_id)


func _process_defeat(enemy_id: StringName, world_pos: Vector2, exp_amount: int = 0, table: LootTable = null, enemy_instance_id: int = 0) -> void:
	var current_ticks := Time.get_ticks_msec()

	# Anti-duplicate guard by enemy instance ID
	if enemy_instance_id != 0:
		if _processed_instance_ids.has(enemy_instance_id):
			return # Already processed this specific enemy instance!
		_processed_instance_ids[enemy_instance_id] = current_ticks
		if _processed_instance_ids.size() > 100:
			_prune_processed_defeats(current_ticks)
	else:
		if _processed_fallback_events.has(enemy_id):
			var last_time: int = _processed_fallback_events[enemy_id]
			if current_ticks - last_time < 200:
				return
		_processed_fallback_events[enemy_id] = current_ticks

	# 1. Distribute EXP reward (only if configured or registered)
	var final_exp := exp_amount
	if final_exp <= 0 and exp_rewards.has(enemy_id):
		final_exp = int(exp_rewards[enemy_id])

	if final_exp > 0:
		var stats := CharacterStats.get_default()
		if stats:
			stats.add_experience(final_exp)
		exp_awarded.emit(enemy_id, final_exp)

	# 2. Spawn Loot (only if table provided or registered)
	var final_table: LootTable = table
	if final_table == null and loot_tables.has(enemy_id):
		final_table = loot_tables[enemy_id] as LootTable

	if final_table:
		spawn_loot_from_table(enemy_id, world_pos, final_table)


func _prune_processed_defeats(current_ticks: int) -> void:
	var to_remove: Array[int] = []
	for id in _processed_instance_ids.keys():
		if current_ticks - _processed_instance_ids[id] > 30000:
			to_remove.append(id)
	for id in to_remove:
		_processed_instance_ids.erase(id)


func spawn_loot_for_enemy(enemy_id: StringName, world_pos: Vector2) -> Array[WorldItem]:
	var table: LootTable = loot_tables.get(enemy_id, null)
	if not table:
		return []
	return spawn_loot_from_table(enemy_id, world_pos, table)


func spawn_loot_from_table(enemy_id: StringName, world_pos: Vector2, table: LootTable) -> Array[WorldItem]:
	var spawned_items: Array[WorldItem] = []
	if not table:
		return spawned_items

	var drops := table.roll_loot(rng)
	if drops.is_empty():
		return spawned_items

	var parent_node: Node = _find_spawn_container()

	var angle_step := TAU / float(maxi(1, drops.size()))
	for i in range(drops.size()):
		var drop_info: Dictionary = drops[i]
		var item_data: ItemData = drop_info["item_data"]
		var qty: int = drop_info["quantity"]

		var world_item := _instantiate_world_item(item_data, qty)
		if world_item:
			# Radial scatter offset
			var offset_dist: float = 12.0 if drops.size() > 1 else 0.0
			var offset := Vector2.RIGHT.rotated(angle_step * i) * offset_dist
			world_item.global_position = world_pos + offset

			if parent_node:
				parent_node.call_deferred("add_child", world_item)
			else:
				call_deferred("add_child", world_item)

			spawned_items.append(world_item)

	loot_spawned.emit(enemy_id, spawned_items)
	return spawned_items


func _instantiate_world_item(item_data: ItemData, qty: int) -> WorldItem:
	if not world_item_scene:
		world_item_scene = load("res://scenes/objects/world_item.tscn") as PackedScene

	var inst := world_item_scene.instantiate() as WorldItem
	inst.item_data = item_data
	inst.quantity = qty
	return inst


func _find_spawn_container() -> Node:
	if not is_inside_tree():
		return self
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return self

	# Prefer YSortEntities container in current world level
	var ysort := tree.current_scene.get_node_or_null("YSortEntities")
	if ysort:
		var interactables := ysort.get_node_or_null("Interactables")
		if interactables:
			return interactables
		return ysort

	return tree.current_scene
