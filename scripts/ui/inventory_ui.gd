class_name InventoryUI
extends CanvasLayer

## InventoryUI.gd
## Unified UI for Inventory Grid, Item Details, Equipment Slots, and Character Progression.
## Designed for 640x360 base viewport with pixel-art styling, keyboard shortcuts, and touch controls.

signal opened
signal closed

@export var inventory_manager: InventoryManager
@export var equipment_manager: EquipmentManager
@export var character_stats: CharacterStats

@onready var main_panel: Control = $MainPanel
@onready var grid_container: GridContainer = %GridContainer
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_type_label: Label = %ItemTypeLabel
@onready var item_desc_label: Label = %ItemDescLabel
@onready var item_stats_label: Label = %ItemStatsLabel
@onready var equip_button: Button = %EquipButton
@onready var drop_button: Button = %DropButton

@onready var weapon_btn: Button = %WeaponSlotBtn
@onready var body_btn: Button = %BodySlotBtn
@onready var head_btn: Button = %HeadSlotBtn
@onready var accessory_btn: Button = %AccessorySlotBtn

@onready var level_label: Label = %LevelLabel
@onready var exp_bar: ProgressBar = %ExpBar
@onready var exp_label: Label = %ExpLabel
@onready var hp_label: Label = %HpLabel
@onready var atk_label: Label = %AtkLabel
@onready var def_label: Label = %DefLabel
@onready var spd_label: Label = %SpdLabel
@onready var stat_points_label: Label = %StatPointsLabel

@onready var add_hp_btn: Button = %AddHpBtn
@onready var add_atk_btn: Button = %AddAtkBtn
@onready var add_def_btn: Button = %AddDefBtn
@onready var close_btn: Button = %CloseButton

var _selected_slot_index: int = -1
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	layer = 25
	visible = false

	if close_btn:
		close_btn.pressed.connect(close_ui)

	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)
	if drop_button:
		drop_button.pressed.connect(_on_drop_pressed)

	if weapon_btn:
		weapon_btn.pressed.connect(func(): _on_unequip_slot(EquipmentData.EquipmentSlot.WEAPON))
	if body_btn:
		body_btn.pressed.connect(func(): _on_unequip_slot(EquipmentData.EquipmentSlot.BODY))
	if head_btn:
		head_btn.pressed.connect(func(): _on_unequip_slot(EquipmentData.EquipmentSlot.HEAD))
	if accessory_btn:
		accessory_btn.pressed.connect(func(): _on_unequip_slot(EquipmentData.EquipmentSlot.ACCESSORY))

	if add_hp_btn:
		add_hp_btn.pressed.connect(func(): _on_allocate_point(&"health"))
	if add_atk_btn:
		add_atk_btn.pressed.connect(func(): _on_allocate_point(&"attack"))
	if add_def_btn:
		add_def_btn.pressed.connect(func(): _on_allocate_point(&"defense"))

	_build_slot_grid()
	_connect_managers()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("character"):
		toggle_ui()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()


func _connect_managers() -> void:
	var inv := _get_inv()
	if inv:
		if not inv.inventory_changed.is_connected(refresh_all):
			inv.inventory_changed.connect(refresh_all)

	var equip := _get_equip()
	if equip:
		if not equip.equipment_changed.is_connected(func(_s, _i): refresh_all()):
			equip.equipment_changed.connect(func(_s, _i): refresh_all())

	var stats := _get_stats()
	if stats:
		if not stats.stats_changed.is_connected(refresh_stats):
			stats.stats_changed.connect(refresh_stats)
		if not stats.health_changed.is_connected(func(_c, _m): refresh_stats()):
			stats.health_changed.connect(func(_c, _m): refresh_stats())
		if not stats.exp_changed.is_connected(func(_c, _m): refresh_stats()):
			stats.exp_changed.connect(func(_c, _m): refresh_stats())


func toggle_ui() -> void:
	if visible:
		close_ui()
	else:
		open_ui()


func open_ui() -> void:
	visible = true
	_connect_managers()
	refresh_all()
	opened.emit()


func close_ui() -> void:
	visible = false
	closed.emit()


func _build_slot_grid() -> void:
	if not grid_container:
		return

	for child in grid_container.get_children():
		child.queue_free()
	_slot_buttons.clear()

	var inv := _get_inv()
	var cap: int = inv.slot_capacity if inv else 20

	for i in range(cap):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(34, 34)
		btn.clip_text = true
		btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)

		var qty_lbl := Label.new()
		qty_lbl.name = "Qty"
		qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		qty_lbl.position = Vector2(-22, -14)
		qty_lbl.size = Vector2(20, 12)
		qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qty_lbl.add_theme_font_size_override("font_size", 9)
		qty_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
		qty_lbl.add_theme_constant_override("shadow_offset_x", 1)
		qty_lbl.add_theme_constant_override("shadow_offset_y", 1)
		btn.add_child(qty_lbl)

		var slot_idx := i
		btn.pressed.connect(func(): _on_slot_clicked(slot_idx))

		grid_container.add_child(btn)
		_slot_buttons.append(btn)


func refresh_all() -> void:
	refresh_grid()
	refresh_equipment()
	refresh_stats()
	_update_detail_panel()


func refresh_grid() -> void:
	var inv := _get_inv()
	if not inv:
		return

	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]
		var icon_rect := btn.get_node_or_null("Icon") as TextureRect
		var qty_lbl := btn.get_node_or_null("Qty") as Label

		var data := inv.get_slot_data(i)
		if not data.is_empty() and not data.get("is_empty", true):
			var item: ItemData = data.get("item_data") as ItemData
			var qty: int = int(data.get("quantity", 1))
			if icon_rect:
				icon_rect.texture = item.icon if item else null
				icon_rect.visible = item != null
			if qty_lbl:
				qty_lbl.text = str(qty) if qty > 1 else ""
				qty_lbl.visible = true
		else:
			if icon_rect:
				icon_rect.texture = null
				icon_rect.visible = false
			if qty_lbl:
				qty_lbl.text = ""
				qty_lbl.visible = false


func refresh_equipment() -> void:
	var equip := _get_equip()
	if not equip:
		return

	_update_equip_slot_btn(weapon_btn, equip.get_equipped_item(EquipmentData.EquipmentSlot.WEAPON), "Senjata: Kosong")
	_update_equip_slot_btn(body_btn, equip.get_equipped_item(EquipmentData.EquipmentSlot.BODY), "Zirah: Kosong")
	_update_equip_slot_btn(head_btn, equip.get_equipped_item(EquipmentData.EquipmentSlot.HEAD), "Kepala: Kosong")
	_update_equip_slot_btn(accessory_btn, equip.get_equipped_item(EquipmentData.EquipmentSlot.ACCESSORY), "Aksesoris: Kosong")


func _update_equip_slot_btn(btn: Button, item: EquipmentData, fallback: String) -> void:
	if not btn:
		return
	if item:
		btn.text = item.item_name
		btn.tooltip_text = "%s (+%d ATK, +%d DEF, +%d HP)" % [item.item_name, item.attack_bonus, item.defense_bonus, item.health_bonus]
	else:
		btn.text = fallback
		btn.tooltip_text = "Klik untuk melepas perlengkapan."


func refresh_stats() -> void:
	var stats := _get_stats()
	if not stats:
		return

	if level_label:
		level_label.text = "Level %d" % stats.level
	if exp_bar:
		exp_bar.max_value = stats.exp_to_next_level
		exp_bar.value = stats.current_exp
	if exp_label:
		exp_label.text = "%d / %d EXP" % [stats.current_exp, stats.exp_to_next_level]

	if hp_label:
		hp_label.text = "HP: %d / %d" % [stats.current_health, stats.max_health]
	if atk_label:
		atk_label.text = "Serangan: %d" % stats.attack
	if def_label:
		def_label.text = "Pertahanan: %d" % stats.defense
	if spd_label:
		spd_label.text = "Kecepatan: %.0f" % stats.movement_speed
	if stat_points_label:
		stat_points_label.text = "Poin Tersedia: %d" % stats.available_stat_points

	var can_alloc := stats.available_stat_points > 0
	if add_hp_btn:
		add_hp_btn.disabled = not can_alloc
	if add_atk_btn:
		add_atk_btn.disabled = not can_alloc
	if add_def_btn:
		add_def_btn.disabled = not can_alloc


func _on_slot_clicked(slot_index: int) -> void:
	_selected_slot_index = slot_index
	_update_detail_panel()


func _update_detail_panel() -> void:
	var inv := _get_inv()
	if not inv or not inv.is_valid_slot(_selected_slot_index):
		_clear_detail_panel()
		return

	var slot_data := inv.get_slot_data(_selected_slot_index)
	if slot_data.is_empty() or slot_data.get("is_empty", true):
		_clear_detail_panel()
		return

	var item := slot_data.get("item_data") as ItemData
	if not item:
		_clear_detail_panel()
		return
	if item_icon:
		item_icon.texture = item.icon
		item_icon.visible = true
	if item_name_label:
		item_name_label.text = item.item_name
		item_name_label.modulate = item.get_rarity_color()
	if item_type_label:
		item_type_label.text = "%s | %s" % [item.get_type_name(), item.get_rarity_name()]
	if item_desc_label:
		item_desc_label.text = item.description

	if item_stats_label:
		if item is EquipmentData:
			var eq := item as EquipmentData
			var stat_txt := ""
			if eq.attack_bonus > 0: stat_txt += "+%d ATK  " % eq.attack_bonus
			if eq.defense_bonus > 0: stat_txt += "+%d DEF  " % eq.defense_bonus
			if eq.health_bonus > 0: stat_txt += "+%d HP  " % eq.health_bonus
			if eq.movement_speed_bonus > 0.0: stat_txt += "+%.0f SPD  " % eq.movement_speed_bonus
			item_stats_label.text = stat_txt
		elif item.item_type == ItemData.ItemType.CONSUMABLE:
			item_stats_label.text = "Memulihkan 30 HP saat digunakan."
		else:
			item_stats_label.text = "Nilai Jual: %d Koin" % item.sell_value

	if equip_button:
		equip_button.visible = true
		if item is EquipmentData:
			equip_button.text = "Pasang"
			equip_button.disabled = false
		elif item.item_type == ItemData.ItemType.CONSUMABLE:
			equip_button.text = "Gunakan"
			equip_button.disabled = false
		else:
			equip_button.text = "Gunakan"
			equip_button.disabled = true

	if drop_button:
		drop_button.visible = true


func _clear_detail_panel() -> void:
	if item_icon:
		item_icon.texture = null
		item_icon.visible = false
	if item_name_label:
		item_name_label.text = "Pilih Barang"
		item_name_label.modulate = Color.WHITE
	if item_type_label:
		item_type_label.text = "Pilih slot di inventaris untuk melihat info."
	if item_desc_label:
		item_desc_label.text = ""
	if item_stats_label:
		item_stats_label.text = ""
	if equip_button:
		equip_button.visible = false
	if drop_button:
		drop_button.visible = false


func _on_equip_pressed() -> void:
	var inv := _get_inv()
	if not inv or not inv.is_valid_slot(_selected_slot_index):
		return

	var slot_data := inv.get_slot_data(_selected_slot_index)
	if slot_data.is_empty() or slot_data.get("is_empty", true):
		return

	var item := slot_data.get("item_data") as ItemData
	if not item:
		return

	if item is EquipmentData:
		var equip := _get_equip()
		if equip:
			equip.equip_from_inventory(_selected_slot_index)
	elif item.item_type == ItemData.ItemType.CONSUMABLE:
		# Use potion
		var stats := _get_stats()
		if stats:
			stats.heal(30)
		inv.remove_item_from_slot(_selected_slot_index, 1)

	refresh_all()


func _on_drop_pressed() -> void:
	var inv := _get_inv()
	if inv and inv.is_valid_slot(_selected_slot_index):
		inv.remove_item_from_slot(_selected_slot_index, 1)
		refresh_all()


func _on_unequip_slot(slot_type: EquipmentData.EquipmentSlot) -> void:
	var equip := _get_equip()
	if equip:
		equip.unequip_to_inventory(slot_type)
		refresh_all()


func _on_allocate_point(stat_name: StringName) -> void:
	var stats := _get_stats()
	if stats:
		stats.allocate_stat_point(stat_name, 1)
		refresh_stats()


func _get_inv() -> InventoryManager:
	if inventory_manager:
		return inventory_manager
	return InventoryManager.get_default()


func _get_equip() -> EquipmentManager:
	if equipment_manager:
		return equipment_manager
	return EquipmentManager.get_default()


func _get_stats() -> CharacterStats:
	if character_stats:
		return character_stats
	return CharacterStats.get_default()

