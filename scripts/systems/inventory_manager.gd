class_name InventoryManager
extends Node

## InventoryManager.gd
## Central controller for player inventory management.
## Manages bounded slot capacity, item stacking, atomic slot operations, and signal events.

signal item_added(item_data: ItemData, quantity: int, slot_index: int)
signal item_removed(item_data: ItemData, quantity: int, slot_index: int)
signal inventory_changed
signal slot_updated(slot_index: int)

@export var slot_capacity: int = 20

var _slots: Array[InventorySlot] = []

static var instance: InventoryManager = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	initialize_slots()


static func get_default() -> InventoryManager:
	return instance


func initialize_slots() -> void:
	_slots.clear()
	for i in range(slot_capacity):
		_slots.append(InventorySlot.new())


func get_slot_count() -> int:
	return _slots.size()


## Safe slot reading API: returns an isolated copy of InventorySlot with a duplicated ItemData resource.
## Modifying the returned object or its item_data does NOT mutate internal inventory state.
func get_slot(index: int) -> InventorySlot:
	if not is_valid_slot(index):
		return null
	var internal := _slots[index]
	var copy := InventorySlot.new()
	copy.item_data = internal.item_data.duplicate(true) if internal.item_data else null
	copy.quantity = internal.quantity
	return copy


## Returns a read-only Dictionary containing slot state and a duplicated ItemData resource.
func get_slot_data(index: int) -> Dictionary:
	if not is_valid_slot(index):
		return {}
	var slot := _slots[index]
	return {
		"slot_index": index,
		"is_empty": slot.is_empty(),
		"quantity": slot.quantity,
		"item_data": slot.item_data.duplicate(true) if slot.item_data else null
	}


func is_valid_slot(index: int) -> bool:
	return index >= 0 and index < _slots.size()


func is_full() -> bool:
	return get_free_slot_count() == 0


func get_free_slot_count() -> int:
	var count: int = 0
	for slot in _slots:
		if slot.is_empty():
			count += 1
	return count


func get_available_space_for(item_data: ItemData) -> int:
	if item_data == null:
		return 0

	var total_space: int = 0
	for slot in _slots:
		if slot.is_empty():
			total_space += item_data.max_stack
		elif item_data.is_stackable and slot.item_data.item_id == item_data.item_id:
			total_space += maxi(0, item_data.max_stack - slot.quantity)

	return total_space


func can_fit_item(item_data: ItemData, quantity: int = 1) -> bool:
	if item_data == null or quantity <= 0:
		return false
	return get_available_space_for(item_data) >= quantity


## Adds an item to inventory, filling existing stacks first, then empty slots.
## Handles partial insertion if available capacity is less than requested quantity.
## Returns the actual quantity successfully added (0 <= return <= quantity).
func add_item(item_data: ItemData, quantity: int = 1) -> int:
	if item_data == null or quantity <= 0:
		return 0

	var remaining := quantity
	var added_total := 0

	# Step 1: If stackable, try to top up existing stacks of the same item
	if item_data.is_stackable:
		for i in range(_slots.size()):
			var slot := _slots[i]
			if not slot.is_empty() and slot.item_data.item_id == item_data.item_id:
				var space := slot.get_remaining_space()
				if space > 0:
					var to_add := mini(remaining, space)
					slot.quantity += to_add
					remaining -= to_add
					added_total += to_add
					slot_updated.emit(i)
					item_added.emit(item_data, to_add, i)
					if remaining <= 0:
						break

	# Step 2: Use empty slots for remaining quantity
	if remaining > 0:
		for i in range(_slots.size()):
			var slot := _slots[i]
			if slot.is_empty():
				var to_add := mini(remaining, item_data.max_stack)
				slot.item_data = item_data
				slot.quantity = to_add
				remaining -= to_add
				added_total += to_add
				slot_updated.emit(i)
				item_added.emit(item_data, to_add, i)
				if remaining <= 0:
					break

	if added_total > 0:
		inventory_changed.emit()
		var event_bus := _get_event_bus()
		if event_bus and event_bus.has_signal("inventory_updated"):
			event_bus.inventory_updated.emit()
		if event_bus and event_bus.has_signal("item_collected"):
			event_bus.item_collected.emit(item_data.item_id, added_total)

	return added_total


## Removes an amount of an item by item_id across all matching slots.
## Returns true if the full quantity was successfully removed, false otherwise (atomic).
func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0 or not has_item(item_id, quantity):
		return false

	var remaining := quantity
	for i in range(_slots.size()):
		var slot := _slots[i]
		if not slot.is_empty() and slot.item_data.item_id == item_id:
			var removed := mini(remaining, slot.quantity)
			var item_ref := slot.item_data
			slot.quantity -= removed
			remaining -= removed
			if slot.quantity <= 0:
				slot.clear()
			slot_updated.emit(i)
			item_removed.emit(item_ref, removed, i)
			if remaining <= 0:
				break

	inventory_changed.emit()
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("inventory_updated"):
		event_bus.inventory_updated.emit()

	return true


## Removes a quantity from a specific slot.
func remove_item_from_slot(slot_index: int, quantity: int = 1) -> bool:
	if not is_valid_slot(slot_index) or quantity <= 0:
		return false

	var slot := _slots[slot_index]
	if slot.is_empty() or slot.quantity < quantity:
		return false

	var item_ref := slot.item_data
	slot.quantity -= quantity
	if slot.quantity <= 0:
		slot.clear()

	slot_updated.emit(slot_index)
	item_removed.emit(item_ref, quantity, slot_index)
	inventory_changed.emit()

	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("inventory_updated"):
		event_bus.inventory_updated.emit()

	return true


func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null


func has_item(item_id: StringName, min_quantity: int = 1) -> bool:
	return get_item_count(item_id) >= min_quantity


func get_item_count(item_id: StringName) -> int:
	var total: int = 0
	for slot in _slots:
		if not slot.is_empty() and slot.item_data.item_id == item_id:
			total += slot.quantity
	return total


## Moves items from from_slot to to_slot.
## Merges stackable items; swaps slots if targets are different.
func move_item(from_slot: int, to_slot: int) -> bool:
	if not is_valid_slot(from_slot) or not is_valid_slot(to_slot) or from_slot == to_slot:
		return false

	var src := _slots[from_slot]
	var dst := _slots[to_slot]

	if src.is_empty():
		return false

	# Case 1: Target slot is empty -> clean move
	if dst.is_empty():
		dst.item_data = src.item_data
		dst.quantity = src.quantity
		src.clear()
		slot_updated.emit(from_slot)
		slot_updated.emit(to_slot)
		inventory_changed.emit()
		return true

	# Case 2: Target has same item and is stackable -> merge stack
	if src.item_data.is_stackable and dst.item_data.item_id == src.item_data.item_id:
		var space := dst.get_remaining_space()
		if space > 0:
			var to_transfer := mini(src.quantity, space)
			dst.quantity += to_transfer
			src.quantity -= to_transfer
			if src.quantity <= 0:
				src.clear()
			slot_updated.emit(from_slot)
			slot_updated.emit(to_slot)
			inventory_changed.emit()
			return true

	# Case 3: Target has different item or is non-stackable/full -> swap
	return swap_items(from_slot, to_slot)


## Atomically swaps two inventory slots without data duplication or loss.
func swap_items(slot_a: int, slot_b: int) -> bool:
	if not is_valid_slot(slot_a) or not is_valid_slot(slot_b) or slot_a == slot_b:
		return false

	var a := _slots[slot_a]
	var b := _slots[slot_b]

	var temp_item := a.item_data
	var temp_qty := a.quantity

	a.item_data = b.item_data
	a.quantity = b.quantity

	b.item_data = temp_item
	b.quantity = temp_qty

	slot_updated.emit(slot_a)
	slot_updated.emit(slot_b)
	inventory_changed.emit()
	return true


## Returns an immutable deep-copy snapshot of inventory slots.
## Each ItemData resource is duplicated to prevent external mutations.
func get_inventory_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for i in range(_slots.size()):
		var slot := _slots[i]
		snapshot.append({
			"slot_index": i,
			"is_empty": slot.is_empty(),
			"item_data": slot.item_data.duplicate(true) if slot.item_data else null,
			"quantity": slot.quantity
		})
	return snapshot


## Atomically replaces the item in slot_index with new_item and returns the previous internal ItemData.
## Official mutation API for external managers like EquipmentManager.
func replace_slot_item(slot_index: int, new_item: ItemData, new_quantity: int = 1) -> ItemData:
	if not is_valid_slot(slot_index):
		return null
	var slot := _slots[slot_index]
	var old_item := slot.item_data
	if new_item != null and new_quantity > 0:
		slot.item_data = new_item
		slot.quantity = new_quantity
	else:
		slot.clear()
	slot_updated.emit(slot_index)
	inventory_changed.emit()
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("inventory_updated"):
		event_bus.inventory_updated.emit()
	return old_item


## Atomically sets a slot's contents.
func set_slot(slot_index: int, item_data: ItemData, quantity: int = 1) -> bool:
	if not is_valid_slot(slot_index):
		return false
	var slot := _slots[slot_index]
	if item_data != null and quantity > 0:
		slot.item_data = item_data
		slot.quantity = quantity
	else:
		slot.clear()
	slot_updated.emit(slot_index)
	inventory_changed.emit()
	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("inventory_updated"):
		event_bus.inventory_updated.emit()
	return true


## Atomically clears a specific slot.
func clear_slot(slot_index: int) -> bool:
	return set_slot(slot_index, null, 0)


func clear_inventory() -> void:
	for i in range(_slots.size()):
		_slots[i].clear()
		slot_updated.emit(i)
	inventory_changed.emit()
