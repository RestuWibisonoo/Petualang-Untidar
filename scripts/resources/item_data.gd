class_name ItemData
extends Resource

## ItemData.gd
## Base custom Resource representing an item in Petualang Untidar.
## Uses strict typing, categorized enums, and support for stacking and rarity.

enum ItemType {
	CONSUMABLE,
	MATERIAL,
	WEAPON,
	ARMOR,
	QUEST_ITEM
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var item_id: StringName = &""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var item_type: ItemType = ItemType.MATERIAL
@export var rarity: Rarity = Rarity.COMMON
@export var max_stack: int = 99
@export var sell_value: int = 10
@export var is_stackable: bool = true


func can_stack_with(other: ItemData) -> bool:
	if not is_stackable or other == null:
		return false
	return item_id == other.item_id


func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.85, 0.85, 0.85, 1.0) # White / Light Gray
		Rarity.UNCOMMON:
			return Color(0.3, 0.85, 0.4, 1.0) # Vibrant Green
		Rarity.RARE:
			return Color(0.25, 0.65, 1.0, 1.0) # Bright Blue
		Rarity.EPIC:
			return Color(0.75, 0.35, 0.95, 1.0) # Mystical Purple
		Rarity.LEGENDARY:
			return Color(1.0, 0.75, 0.15, 1.0) # Radiant Gold
		_:
			return Color.WHITE


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


func get_type_name() -> String:
	match item_type:
		ItemType.CONSUMABLE:
			return "Consumable"
		ItemType.MATERIAL:
			return "Material"
		ItemType.WEAPON:
			return "Weapon"
		ItemType.ARMOR:
			return "Armor"
		ItemType.QUEST_ITEM:
			return "Quest Item"
		_:
			return "General"

