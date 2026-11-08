class_name NPC
extends CharacterBody2D

## NPC.gd
## Non-Player Character entity in Petualang Untidar.
## Implements Interactable conversation triggers, quest distribution, and stateful dialogues.

signal talked(player: Player)

@export var npc_id: StringName = &"npc_guide"
@export var npc_name: String = "Prof. Untidar"
@export var default_dialogue: DialogueData
@export var active_quest_dialogue: DialogueData
@export var completed_quest_dialogue: DialogueData
@export var quest_to_offer: QuestData

@onready var interactable: Interactable = get_node_or_null("Interactable") as Interactable
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	add_to_group(&"npc")
	y_sort_enabled = true

	# Layer 5 (NPC/Enemy Body: 16), Mask 1 (World) | 2 (Player)
	collision_layer = 16
	collision_mask = 3

	_setup_interactable()


func _setup_interactable() -> void:
	if not interactable:
		interactable = Interactable.new()
		interactable.name = "Interactable"
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24.0
		shape.shape = circle
		interactable.add_child(shape)
		add_child(interactable)

	interactable.collision_layer = 128
	interactable.collision_mask = 0
	interactable.interaction_text = "Bicara dengan %s" % npc_name
	if not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)


func _on_interacted(actor: Node) -> void:
	var player := actor as Player
	var qm := QuestManager.get_default()

	var selected_dialogue: DialogueData = default_dialogue

	if quest_to_offer and qm:
		if qm.is_quest_completed(quest_to_offer.quest_id):
			if completed_quest_dialogue:
				selected_dialogue = completed_quest_dialogue
		elif qm.is_quest_active(quest_to_offer.quest_id):
			if active_quest_dialogue:
				selected_dialogue = active_quest_dialogue
		else:
			if default_dialogue:
				selected_dialogue = default_dialogue
				if not selected_dialogue.quest_to_give:
					selected_dialogue.quest_to_give = quest_to_offer

	if not selected_dialogue:
		selected_dialogue = DialogueData.new()
		selected_dialogue.dialogue_id = StringName("%s_default" % npc_id)
		selected_dialogue.speaker_name = npc_name
		selected_dialogue.lines = [
			"Halo, Petualang! Selamat datang di Universitas Tidar.",
			"Ada tugas penting untukmu. Bisakah kamu membantu membersihkan monster di sekitar sini?"
		]
		if quest_to_offer and qm and not qm.is_quest_active(quest_to_offer.quest_id) and not qm.is_quest_completed(quest_to_offer.quest_id):
			selected_dialogue.quest_to_give = quest_to_offer

	# Open DialogueUI
	var diag_ui := DialogueUI.get_default()
	if not diag_ui and is_inside_tree():
		diag_ui = get_tree().root.find_child("DialogueUI", true, false) as DialogueUI

	if diag_ui and selected_dialogue:
		diag_ui.open_dialogue(selected_dialogue, player)

	# Emit events
	talked.emit(player)

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("npc_interacted"):
		event_bus.npc_interacted.emit(npc_id)
