class_name TreasureChest
extends StaticBody2D

## TreasureChest.gd
## Interactive chest object that can be opened once by the Player.

signal opened(actor: Node)

@export var chest_id: StringName = &"chest_01"
@export var reward_text: String = "Mendapatkan Buku Catatan Kuliah!"
@export var is_opened: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if interactable:
		interactable.interaction_text = "Buka Peti"
		interactable.interacted.connect(_on_interacted)
		interactable.is_interactable = not is_opened

	_update_visuals()


func _on_interacted(actor: Node) -> void:
	if is_opened:
		return

	open_chest(actor)


func open_chest(actor: Node) -> void:
	is_opened = true
	if interactable:
		interactable.is_interactable = false

	_update_visuals()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("show_floating_text"):
		event_bus.show_floating_text.emit(reward_text, global_position + Vector2(0, -20), Color(1.0, 0.85, 0.2))
	opened.emit(actor)
	print("[TreasureChest] Chest '%s' opened by %s. Reward: %s" % [chest_id, actor.name if actor else "Unknown", reward_text])


func _update_visuals() -> void:
	if sprite:
		sprite.frame = 1 if is_opened else 0
