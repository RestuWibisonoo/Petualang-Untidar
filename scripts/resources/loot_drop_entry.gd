class_name LootDropEntry
extends Resource

## LootDropEntry.gd
## Individual drop configuration within a LootTable.
## Supports independent percentage chance, quantity range, and weighted raffle scoring.

@export var item_data: ItemData
@export_range(0.0, 1.0) var drop_chance: float = 0.5
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export var weight: int = 1


func _init(p_item: ItemData = null, p_chance: float = 0.5, p_min: int = 1, p_max: int = 1, p_weight: int = 1) -> void:
	item_data = p_item
	drop_chance = p_chance
	min_quantity = p_min
	max_quantity = p_max
	weight = p_weight


## Validates entry configuration invariants.
func is_valid() -> bool:
	if item_data == null:
		return false
	if drop_chance < 0.0 or drop_chance > 1.0:
		return false
	if min_quantity <= 0:
		return false
	if max_quantity < min_quantity:
		return false
	if weight < 0:
		return false
	return true

