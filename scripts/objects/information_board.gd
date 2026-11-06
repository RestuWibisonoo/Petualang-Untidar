class_name InformationBoard
extends StaticBody2D

## InformationBoard.gd
## Interactive signpost displaying lore or navigational info when read.

signal read(actor: Node)

@export var board_title: String = "Papan Informasi Untidar"
@export_multiline var board_content: String = "Gedung Kuliah Bersama (GKB) - Universitas Tidar\nLantai 1: Ruang Akademik & Administrasi\nLantai 2-4: Ruang Perkuliahan & Laboratorium Komputer"

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if interactable:
		interactable.interaction_text = "Baca Papan Informasi"
		interactable.interacted.connect(_on_interacted)


func _on_interacted(actor: Node) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("show_floating_text"):
		event_bus.show_floating_text.emit(board_title, global_position + Vector2(0, -24), Color.WHITE)
	read.emit(actor)
	print("[InformationBoard] Read by %s: %s" % [actor.name if actor else "Unknown", board_title])
