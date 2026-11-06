class_name EquipmentData
extends ItemData

## EquipmentData.gd
## Extended Resource representing wearable equipment (weapons, armor, accessories).
## Defines slot categorization, combat stat modifiers, and visual layer bindings.

enum EquipmentSlot {
	WEAPON,
	HEAD,
	BODY,
	ACCESSORY
}

@export var equipment_slot: EquipmentSlot = EquipmentSlot.WEAPON
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var health_bonus: int = 0
@export var movement_speed_bonus: float = 0.0
@export var visual_layer: StringName = &""
@export var visual_texture: Texture2D = null


func _init() -> void:
	is_stackable = false
	max_stack = 1
	if equipment_slot == EquipmentSlot.WEAPON:
		item_type = ItemType.WEAPON
	else:
		item_type = ItemType.ARMOR


func get_slot_name() -> String:
	match equipment_slot:
		EquipmentSlot.WEAPON:
			return "Weapon"
		EquipmentSlot.HEAD:
			return "Head"
		EquipmentSlot.BODY:
			return "Body"
		EquipmentSlot.ACCESSORY:
			return "Accessory"
		_:
			return "Unknown"
