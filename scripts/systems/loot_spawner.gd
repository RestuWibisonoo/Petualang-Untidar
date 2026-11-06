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
var _processed_defeats: Dictionary = {} # StringName -> int (timestamp or count)

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

	_register_default_tables()
	_connect_event_bus()


static func get_default() -> LootSpawner:
	return instance


func set_rng(custom_rng: RandomNumberGenerator) -> void:
	rng = custom_rng


func register_loot_table(enemy_id: StringName, table: LootTable, exp_reward: int = 35) -> void:
	loot_tables[enemy_id] = table
	exp_rewards[enemy_id] = exp_reward


func _register_default_tables() -> void:
	var slime_loot: LootTable = load("res://resources/enemies/dummy_slime_loot.tres") as LootTable
	if slime_loot:
		register_loot_table(&"dummy_slime", slime_loot, 35)
		register_loot_table(&"dummy_slime_1", slime_loot, 35)
		register_loot_table(&"dummy_slime_2", slime_loot, 35)


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

	_process_defeat(enemy_id, spawn_pos)


func _on_enemy_defeated_at(enemy_id: StringName, world_pos: Vector2) -> void:
	_process_defeat(enemy_id, world_pos)


func _process_defeat(enemy_id: StringName, world_pos: Vector2) -> void:
	# Anti-duplicate guard: each specific defeat emission can only trigger once per physics tick
	var current_ticks := Time.get_ticks_msec()
	if _processed_defeats.has(enemy_id):
		var last_time: int = _processed_defeats[enemy_id]
		# If the same enemy_id was processed within 200ms, ignore duplicate
		if current_ticks - last_time < 200:
			return

	_processed_defeats[enemy_id] = current_ticks

	# 1. Distribute EXP reward
	var exp_amount: int = exp_rewards.get(enemy_id, 35)
	# Also check base enemy type key (e.g. dummy_slime_1 -> dummy_slime)
	if not exp_rewards.has(enemy_id):
		var base_key := StringName(String(enemy_id).split("_")[0] + "_" + String(enemy_id).split("_")[1]) if String(enemy_id).count("_") >= 2 else enemy_id
		exp_amount = exp_rewards.get(base_key, 35)

	var stats := CharacterStats.get_default()
	if stats:
		stats.add_experience(exp_amount)
	exp_awarded.emit(enemy_id, exp_amount)

	# 2. Spawn Loot
	spawn_loot_for_enemy(enemy_id, world_pos)


func spawn_loot_for_enemy(enemy_id: StringName, world_pos: Vector2) -> Array[WorldItem]:
	var spawned_items: Array[WorldItem] = []

	var table: LootTable = loot_tables.get(enemy_id, null)
	if not table:
		# Check prefix key fallback
		for key in loot_tables.keys():
			if String(enemy_id).begins_with(String(key)):
				table = loot_tables[key]
				break

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
