class_name EquipmentManager
extends Node

## EquipmentManager.gd
## Manages player equipment slots (Weapon, Head, Body, Accessory).
## Guarantees atomic equip/unequip swaps, stat recalculations, and modular visual synchronization.

signal equipment_changed(slot: EquipmentData.EquipmentSlot, item_data: EquipmentData)
signal stats_recalculated(bonuses: Dictionary)

@export var inventory_manager: InventoryManager
@export var character_stats: CharacterStats
@export var modular_visuals: ModularVisuals

var _equipped_items: Dictionary = {} # EquipmentData.EquipmentSlot -> EquipmentData

static var instance: EquipmentManager = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if not inventory_manager:
		inventory_manager = InventoryManager.get_default()
	if not character_stats:
		character_stats = CharacterStats.get_default()


static func get_default() -> EquipmentManager:
	return instance


func get_equipped_item(slot: EquipmentData.EquipmentSlot) -> EquipmentData:
	return _equipped_items.get(slot, null)


func has_equipped(slot: EquipmentData.EquipmentSlot) -> bool:
	return _equipped_items.has(slot) and _equipped_items[slot] != null


func get_all_equipped() -> Dictionary:
	return _equipped_items.duplicate()


func get_total_bonuses() -> Dictionary:
	var total_atk: int = 0
	var total_def: int = 0
	var total_hp: int = 0
	var total_spd: float = 0.0

	for slot in _equipped_items.keys():
		var item: EquipmentData = _equipped_items[slot]
		if item:
			total_atk += item.attack_bonus
			total_def += item.defense_bonus
			total_hp += item.health_bonus
			total_spd += item.movement_speed_bonus

	return {
		"attack": total_atk,
		"defense": total_def,
		"health": total_hp,
		"movement_speed": total_spd
	}


## Atomically equips an item from the specified inventory slot.
## Swaps with currently equipped item in-place if one already exists.
func equip_from_inventory(slot_index: int) -> bool:
	var inv := _get_inv()
	if not inv or not inv.is_valid_slot(slot_index):
		return false

	var slot_data := inv.get_slot_data(slot_index)
	if slot_data.is_empty() or slot_data.get("is_empty", true) or not (slot_data.get("item_data") is EquipmentData):
		return false

	var new_equip_preview := slot_data["item_data"] as EquipmentData
	var target_slot := new_equip_preview.equipment_slot
	var old_equip := get_equipped_item(target_slot)
	var old_qty := 1 if old_equip != null else 0

	# Atomic Swap via InventoryManager official mutation API:
	var new_equip := inv.replace_slot_item(slot_index, old_equip, old_qty) as EquipmentData
	if not new_equip:
		return false

	_equipped_items[target_slot] = new_equip
	_on_equipment_updated(target_slot, new_equip, old_equip)
	return true


## Directly equips an item (useful for initial loadout or testing).
## If an old item was equipped, attempts to return it to inventory.
## Rejects atomically if inventory cannot fit the old item.
func equip_item_direct(item_data: EquipmentData) -> bool:
	if item_data == null:
		return false

	var target_slot := item_data.equipment_slot
	if int(target_slot) < 0 or int(target_slot) > 3:
		return false

	var inv := _get_inv()
	var old_equip := get_equipped_item(target_slot)

	if old_equip != null:
		if inv and not inv.can_fit_item(old_equip, 1):
			# Inventory full: cannot unequip old item safely -> reject
			return false
		if inv:
			var added := inv.add_item(old_equip, 1)
			if added < 1:
				return false

	_equipped_items[target_slot] = item_data
	_on_equipment_updated(target_slot, item_data, old_equip)
	return true


## Atomically unequips an item to inventory.
## Rejects if inventory has no available space (item remains safely equipped).
func unequip_to_inventory(slot: EquipmentData.EquipmentSlot) -> bool:
	if not has_equipped(slot):
		return false

	var inv := _get_inv()
	var old_equip := get_equipped_item(slot)

	if inv:
		if not inv.can_fit_item(old_equip, 1):
			# Inventory full -> reject unequip atomically without losing item
			return false
		var added := inv.add_item(old_equip, 1)
		if added < 1:
			return false

	_equipped_items.erase(slot)
	_on_equipment_updated(slot, null, old_equip)
	return true


## Unequips directly without inventory interaction (for tests or dropping).
func unequip_direct(slot: EquipmentData.EquipmentSlot) -> EquipmentData:
	if not has_equipped(slot):
		return null

	var old_equip := get_equipped_item(slot)
	_equipped_items.erase(slot)
	_on_equipment_updated(slot, null, old_equip)
	return old_equip


func recalculate_stats() -> void:
	var stats := _get_stats()
	var bonuses := get_total_bonuses()

	if stats:
		stats.recalculate(bonuses)

	stats_recalculated.emit(bonuses)


func sync_modular_visuals(vis: ModularVisuals) -> void:
	if not vis:
		return

	# Clear all standard equipment layers first to remove any leftover textures from unequipped items
	var equipment_layers: Array[StringName] = [
		ModularVisuals.LAYER_WEAPON,
		ModularVisuals.LAYER_HEADGEAR,
		ModularVisuals.LAYER_ARMOR,
		ModularVisuals.LAYER_ACCESSORY_FRONT,
		ModularVisuals.LAYER_ACCESSORY_BACK
	]
	for layer_name in equipment_layers:
		if vis.has_layer(layer_name):
			vis.set_layer_texture(layer_name, null)
			vis.set_layer_visible(layer_name, false)

	# Apply all currently equipped items
	for slot in _equipped_items.keys():
		var equip: EquipmentData = _equipped_items[slot]
		_apply_visual_layer(vis, slot, equip)


func _on_equipment_updated(slot: EquipmentData.EquipmentSlot, item_data: EquipmentData, previous_item: EquipmentData = null) -> void:
	recalculate_stats()

	var vis := modular_visuals
	if not vis and get_parent():
		vis = get_parent().get_node_or_null("ModularVisuals") as ModularVisuals
	if vis:
		_apply_visual_layer(vis, slot, item_data, previous_item)

	equipment_changed.emit(slot, item_data)

	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("equipment_changed"):
		event_bus.equipment_changed.emit(get_slot_string_name(slot), item_data)


func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null


func _apply_visual_layer(vis: ModularVisuals, slot: EquipmentData.EquipmentSlot, item_data: EquipmentData, previous_item: EquipmentData = null) -> void:
	if not vis:
		return

	var default_layer := _get_default_layer_for_slot(slot)

	# If there was a previous item with a distinct custom visual layer, clean it up
	if previous_item and previous_item.visual_layer != &"" and previous_item.visual_layer != default_layer:
		if vis.has_layer(previous_item.visual_layer):
			vis.set_layer_texture(previous_item.visual_layer, null)
			vis.set_layer_visible(previous_item.visual_layer, false)

	var target_layer := default_layer
	if item_data and item_data.visual_layer != &"":
		target_layer = item_data.visual_layer

	if vis.has_layer(target_layer):
		if item_data != null:
			if item_data.visual_texture != null:
				vis.set_layer_texture(target_layer, item_data.visual_texture)
			vis.set_layer_visible(target_layer, true)
		else:
			vis.set_layer_texture(target_layer, null)
			vis.set_layer_visible(target_layer, false)

	# If the new item data used a custom layer different from default, also clear default layer
	if target_layer != default_layer and vis.has_layer(default_layer):
		vis.set_layer_texture(default_layer, null)
		vis.set_layer_visible(default_layer, false)


func _get_default_layer_for_slot(slot: EquipmentData.EquipmentSlot) -> StringName:
	match slot:
		EquipmentData.EquipmentSlot.WEAPON:
			return ModularVisuals.LAYER_WEAPON
		EquipmentData.EquipmentSlot.HEAD:
			return ModularVisuals.LAYER_HEADGEAR
		EquipmentData.EquipmentSlot.BODY:
			return ModularVisuals.LAYER_ARMOR
		EquipmentData.EquipmentSlot.ACCESSORY:
			return ModularVisuals.LAYER_ACCESSORY_FRONT
		_:
			return &""


func get_slot_string_name(slot: EquipmentData.EquipmentSlot) -> StringName:
	match slot:
		EquipmentData.EquipmentSlot.WEAPON:
			return &"weapon"
		EquipmentData.EquipmentSlot.HEAD:
			return &"head"
		EquipmentData.EquipmentSlot.BODY:
			return &"body"
		EquipmentData.EquipmentSlot.ACCESSORY:
			return &"accessory"
		_:
			return &"unknown"


func _get_inv() -> InventoryManager:
	if inventory_manager:
		return inventory_manager
	return InventoryManager.get_default()


func _get_stats() -> CharacterStats:
	if character_stats:
		return character_stats
	return CharacterStats.get_default()
