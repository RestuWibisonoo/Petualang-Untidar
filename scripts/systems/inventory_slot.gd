class_name InventorySlot
extends RefCounted

## InventorySlot.gd
## Strongly-typed container for an inventory item stack.
## Tracks an ItemData reference and its integer quantity with bounds checking.

var item_data: ItemData = null
var quantity: int = 0


func _init(p_item: ItemData = null, p_qty: int = 0) -> void:
	item_data = p_item
	quantity = p_qty if p_item != null else 0


func is_empty() -> bool:
	return item_data == null or quantity <= 0


func clear() -> void:
	item_data = null
	quantity = 0


func can_add(p_item: ItemData, amount: int = 1) -> bool:
	if p_item == null or amount <= 0:
		return false
	if is_empty():
		return amount <= p_item.max_stack
	if item_data.item_id == p_item.item_id and item_data.is_stackable:
		return quantity + amount <= item_data.max_stack
	return false


func get_remaining_space() -> int:
	if is_empty():
		return 99
	if not item_data.is_stackable:
		return 0
	return maxi(0, item_data.max_stack - quantity)


func duplicate_slot() -> InventorySlot:
	var dup := InventorySlot.new(item_data, quantity)
	return dup

