class_name ModularVisuals
extends Node2D

## ModularVisuals.gd
## Manages a 10-layer modular character sprite stack with unified animation control.
## Layers are rendered in ordered Z-depth from back to front.

const LAYER_ACCESSORY_BACK: StringName = &"AccessoryBack"
const LAYER_BODY: StringName = &"Body"
const LAYER_LEGWEAR: StringName = &"Legwear"
const LAYER_CLOTHING: StringName = &"Clothing"
const LAYER_ARMOR: StringName = &"Armor"
const LAYER_HEADGEAR: StringName = &"Headgear"
const LAYER_HAIR: StringName = &"Hair"
const LAYER_ACCESSORY_FRONT: StringName = &"AccessoryFront"
const LAYER_WEAPON: StringName = &"Weapon"
const LAYER_EFFECTS: StringName = &"Effects"

const ALL_LAYERS: Array[StringName] = [
	LAYER_ACCESSORY_BACK,
	LAYER_BODY,
	LAYER_LEGWEAR,
	LAYER_CLOTHING,
	LAYER_ARMOR,
	LAYER_HEADGEAR,
	LAYER_HAIR,
	LAYER_ACCESSORY_FRONT,
	LAYER_WEAPON,
	LAYER_EFFECTS
]

@export var animation_player: AnimationPlayer

var _layers: Dictionary = {} # StringName -> Sprite2D
var _facing_direction: StringName = &"down"
var _current_action: StringName = &"idle"


func _ready() -> void:
	_init_layers()
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if not animation_player and get_parent():
			animation_player = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer


func _init_layers() -> void:
	_layers.clear()
	for child in get_children():
		if child is Sprite2D:
			var key: StringName = StringName(child.name)
			_layers[key] = child


func has_layer(layer_name: StringName) -> bool:
	return _layers.has(layer_name)


func get_layer_node(layer_name: StringName) -> Sprite2D:
	return _layers.get(layer_name, null)


func set_layer_visible(layer_name: StringName, is_layer_vis: bool) -> void:
	var sprite: Sprite2D = get_layer_node(layer_name)
	if sprite:
		sprite.visible = is_layer_vis


func is_layer_visible(layer_name: StringName) -> bool:
	var sprite: Sprite2D = get_layer_node(layer_name)
	return sprite.visible if sprite else false


func set_layer_texture(layer_name: StringName, texture: Texture2D) -> void:
	var sprite: Sprite2D = get_layer_node(layer_name)
	if sprite:
		sprite.texture = texture


func get_layer_texture(layer_name: StringName) -> Texture2D:
	var sprite: Sprite2D = get_layer_node(layer_name)
	return sprite.texture if sprite else null


func set_facing_direction(dir: StringName) -> void:
	if dir != &"" and dir != _facing_direction:
		_facing_direction = dir


func get_facing_direction() -> StringName:
	return _facing_direction


func play_animation(action: StringName, direction: StringName = &"") -> void:
	_current_action = action
	if direction != &"":
		_facing_direction = direction

	var anim_name: String = "%s_%s" % [_current_action, _facing_direction]

	if animation_player:
		if animation_player.has_animation(anim_name):
			if animation_player.current_animation != anim_name:
				animation_player.play(anim_name)
		else:
			# Fallback if specific direction missing: try action_down
			var fallback: String = "%s_down" % _current_action
			if animation_player.has_animation(fallback):
				if animation_player.current_animation != fallback:
					animation_player.play(fallback)
			else:
				push_warning("[ModularVisuals] Animation '%s' (fallback '%s') not found." % [anim_name, fallback])


func sync_frame_to_all_layers(frame_index: int) -> void:
	for layer_name in ALL_LAYERS:
		var sprite: Sprite2D = get_layer_node(layer_name)
		if sprite and sprite.texture:
			sprite.frame = frame_index
