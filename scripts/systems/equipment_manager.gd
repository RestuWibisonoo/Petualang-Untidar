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

	# Atomic Swap via InventoryManager official mutation API:
	var new_equip := inv.replace_slot_item(slot_index, old_equip, 1) as EquipmentData
	if not new_equip:
		return false

	_equipped_items[target_slot] = new_equip
	_on_equipment_updated(target_slot, new_equip)
	return true


## Directly equips an item (useful for initial loadout or testing).
## If an old item was equipped, attempts to return it to inventory.
## Rejects atomically if inventory cannot fit the old item.
func equip_item_direct(item_data: EquipmentData) -> bool:
	if item_data == null:
		return false

	var inv := _get_inv()
	var target_slot := item_data.equipment_slot
	var old_equip := get_equipped_item(target_slot)

	if old_equip != null:
		if inv and not inv.can_fit_item(old_equip, 1):
			# Inventory full: cannot unequip old item safely -> reject
			return false
		if inv:
			inv.add_item(old_equip, 1)

	_equipped_items[target_slot] = item_data
	_on_equipment_updated(target_slot, item_data)
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
		inv.add_item(old_equip, 1)

	_equipped_items.erase(slot)
	_on_equipment_updated(slot, null)
	return true


## Unequips directly without inventory interaction (for tests or dropping).
func unequip_direct(slot: EquipmentData.EquipmentSlot) -> EquipmentData:
	if not has_equipped(slot):
		return null

	var old_equip := get_equipped_item(slot)
	_equipped_items.erase(slot)
	_on_equipment_updated(slot, null)
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

	for slot in _equipped_items.keys():
		var equip: EquipmentData = _equipped_items[slot]
		_apply_visual_layer(vis, slot, equip)


func _on_equipment_updated(slot: EquipmentData.EquipmentSlot, item_data: EquipmentData) -> void:
	recalculate_stats()

	var vis := modular_visuals
	if not vis and get_parent():
		vis = get_parent().get_node_or_null("ModularVisuals") as ModularVisuals
	if vis:
		_apply_visual_layer(vis, slot, item_data)

	equipment_changed.emit(slot, item_data)

	var event_bus := _get_event_bus()
	if event_bus and event_bus.has_signal("equipment_changed"):
		event_bus.equipment_changed.emit(get_slot_string_name(slot), item_data)


func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	return null


func _apply_visual_layer(vis: ModularVisuals, slot: EquipmentData.EquipmentSlot, item_data: EquipmentData) -> void:
	if not vis:
		return

	var layer_name := &""
	if item_data and item_data.visual_layer != &"":
		layer_name = item_data.visual_layer
	else:
		match slot:
			EquipmentData.EquipmentSlot.WEAPON:
				layer_name = ModularVisuals.LAYER_WEAPON
			EquipmentData.EquipmentSlot.HEAD:
				layer_name = ModularVisuals.LAYER_HEADGEAR
			EquipmentData.EquipmentSlot.BODY:
				layer_name = ModularVisuals.LAYER_ARMOR
			EquipmentData.EquipmentSlot.ACCESSORY:
				layer_name = ModularVisuals.LAYER_ACCESSORY_FRONT

	if vis.has_layer(layer_name):
		if item_data != null:
			if item_data.visual_texture != null:
				vis.set_layer_texture(layer_name, item_data.visual_texture)
			vis.set_layer_visible(layer_name, true)
		else:
			vis.set_layer_visible(layer_name, false)


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
