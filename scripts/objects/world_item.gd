class_name WorldItem
extends Node2D

## WorldItem.gd
## Physical ground item dropped in the game world.
## Supports floating bob animation, single pickup integrity, and auto/interact pickup.

signal picked_up(item_data: ItemData, quantity: int)

@export var item_data: ItemData:
	set(val):
		item_data = val
		_update_visuals()

@export var quantity: int = 1
@export var auto_pickup: bool = true
@export var pickup_cooldown: float = 0.2

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var shadow: Sprite2D = get_node_or_null("Shadow") as Sprite2D
@onready var pickup_area: Area2D = get_node_or_null("PickupArea") as Area2D
@onready var interactable: Interactable = get_node_or_null("Interactable") as Interactable

var _elapsed: float = 0.0
var _is_picked_up: bool = false
var _base_sprite_y: float = -6.0


func _ready() -> void:
	add_to_group(&"world_item")
	y_sort_enabled = true
	_setup_nodes_if_missing()
	_update_visuals()

	if pickup_area and not pickup_area.body_entered.is_connected(_on_body_entered):
		pickup_area.body_entered.connect(_on_body_entered)

	if interactable and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)


func _setup_nodes_if_missing() -> void:
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.position = Vector2(0, _base_sprite_y)
		add_child(sprite)

	if not pickup_area:
		pickup_area = Area2D.new()
		pickup_area.name = "PickupArea"
		# Layer 0, Mask 2 (Player Body)
		pickup_area.collision_layer = 0
		pickup_area.collision_mask = 2
		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		col.shape = circle
		pickup_area.add_child(col)
		add_child(pickup_area)


func _process(delta: float) -> void:
	if _is_picked_up:
		return

	_elapsed += delta
	if sprite:
		sprite.position.y = _base_sprite_y + sin(_elapsed * 4.5) * 2.0


func _update_visuals() -> void:
	if not is_inside_tree() or not sprite:
		return

	if item_data and item_data.icon:
		sprite.texture = item_data.icon
		sprite.visible = true
	else:
		sprite.texture = null


func _on_body_entered(body: Node2D) -> void:
	if not auto_pickup:
		return
	if body is Player or body.is_in_group(&"player"):
		pickup(body)


func _on_interacted(player: Player) -> void:
	pickup(player)


## Attempts to collect this item into inventory.
## Guarantees single pickup execution and stays in world if inventory is full.
func pickup(collector: Node2D = null) -> bool:
	if _is_picked_up or _elapsed < pickup_cooldown:
		return false

	if item_data == null or quantity <= 0:
		return false

	var inv: InventoryManager = null
	if collector and "inventory_manager" in collector and collector.inventory_manager:
		inv = collector.inventory_manager
	else:
		inv = InventoryManager.get_default()

	if not inv:
		return false

	if not inv.can_fit_item(item_data, quantity):
		# Inventory cannot accommodate this item: remain in world safely
		var event_bus := get_node_or_null("/root/EventBus")
		if event_bus and event_bus.has_signal("show_floating_text"):
			event_bus.show_floating_text.emit("Tas Penuh!", global_position + Vector2(0, -12), Color(1.0, 0.35, 0.35))
		return false

	# Single-pickup lock
	_is_picked_up = true

	var added := inv.add_item(item_data, quantity)
	picked_up.emit(item_data, added)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("show_floating_text"):
		var rarity_col := item_data.get_rarity_color()
		event_bus.show_floating_text.emit("+%d %s" % [added, item_data.item_name], global_position + Vector2(0, -14), rarity_col)

	# Visual collection feedback tween
	if is_inside_tree():
		var tween := create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(self, "position:y", position.y - 12.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.2)
			tween.tween_property(self, "modulate:a", 0.0, 0.2)
			tween.chain().tween_callback(queue_free)
		else:
			queue_free()
	else:
		queue_free()

	return true
