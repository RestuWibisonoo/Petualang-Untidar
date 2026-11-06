class_name InformationBoard
extends StaticBody2D

## InformationBoard.gd
## Interactive signpost displaying lore or navigational info when read.

signal read(actor: Node)

@export var board_title: String = "Papan Informasi Untidar"
@export_multiline var board_content: String = "Gedung Kuliah Bersama (GKB) - Universitas Tidar\nLantai 1: Ruang Akademik & Administrasi\nLantai 2-4: Ruang Perkuliahan & Laboratorium Komputer"

@onready var interactable: Interactable = $Interactable

var is_reading: bool = false


func _ready() -> void:
	if interactable:
		interactable.interaction_text = "Baca Papan Informasi"
		interactable.interacted.connect(_on_interacted)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("info_panel_closed"):
		event_bus.info_panel_closed.connect(_on_info_panel_closed)


func _on_interacted(actor: Node) -> void:
	if is_reading:
		return

	is_reading = true
	if interactable:
		interactable.is_interactable = false

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("info_panel_requested"):
		event_bus.info_panel_requested.emit(board_title, board_content)
	elif event_bus and event_bus.has_signal("show_floating_text"):
		event_bus.show_floating_text.emit(board_title, global_position + Vector2(0, -24), Color.WHITE)

	read.emit(actor)
	print("[InformationBoard] Read by %s: %s" % [actor.name if actor else "Unknown", board_title])


func _on_info_panel_closed() -> void:
	is_reading = false
	if interactable:
		interactable.is_interactable = true
