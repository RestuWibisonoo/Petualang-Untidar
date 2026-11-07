class_name LootTable
extends Resource

## LootTable.gd
## Configurable drop table resource for enemies, chests, and world spawners.
## Supports both independent probability chance evaluation and weighted pool selection.

@export var table_id: StringName = &""
@export var entries: Array[LootDropEntry] = []
@export var use_weighted_selection: bool = false
@export var weighted_roll_count: int = 1


## Evaluates loot rolls and returns an array of dropped items with quantities.
## Format: [ { "item_data": ItemData, "quantity": int }, ... ]
## Accepts an injectable RandomNumberGenerator for deterministic testing.
func roll_loot(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if entries.is_empty():
		return drops

	var active_rng := rng
	if active_rng == null:
		active_rng = RandomNumberGenerator.new()
		active_rng.randomize()

	if use_weighted_selection:
		# Weighted selection: chooses N guaranteed items from a weighted raffle pool
		var total_weight: int = 0
		for entry in entries:
			if entry and entry.item_data and entry.weight > 0:
				total_weight += entry.weight

		if total_weight > 0:
			for roll in range(weighted_roll_count):
				var pick_value: int = active_rng.randi_range(1, total_weight)
				var cumulative: int = 0
				for entry in entries:
					if not entry or not entry.item_data or entry.weight <= 0:
						continue
					cumulative += entry.weight
					if pick_value <= cumulative:
						var min_q := mini(entry.min_quantity, entry.max_quantity)
						var max_q := maxi(entry.min_quantity, entry.max_quantity)
						var qty := active_rng.randi_range(min_q, max_q)
						drops.append({
							"item_data": entry.item_data,
							"quantity": qty
						})
						break
	else:
		# Independent Drop Chance: rolls each entry independently
		for entry in entries:
			if not entry or not entry.item_data:
				continue
			var roll_chance := active_rng.randf()
			if roll_chance <= entry.drop_chance:
				var min_q := mini(entry.min_quantity, entry.max_quantity)
				var max_q := maxi(entry.min_quantity, entry.max_quantity)
				var qty := active_rng.randi_range(min_q, max_q)
				drops.append({
					"item_data": entry.item_data,
					"quantity": qty
				})

	return drops

