extends Node

## EventBus.gd
## Central global event bus for Petualang Untidar.
## Decouples systems by providing event-driven communication via signals.

# --- Player & Character Signals ---
signal player_health_changed(current: int, max_val: int)
signal player_stamina_changed(current: float, max_val: float)
signal player_died
signal player_leveled_up(new_level: int, stat_points: int)
signal exp_gained(amount: int, current_exp: int, required_exp: int)

# --- Combat & Feedback Signals ---
signal damage_dealt(target: Node2D, amount: int, is_critical: bool)
signal show_floating_text(text: String, world_pos: Vector2, color: Color)

# --- Inventory & Equipment Signals ---
signal item_collected(item_id: StringName, amount: int)
signal inventory_updated
signal equipment_changed(slot: StringName, item_data: Resource)

# --- Quest & World Signals ---
signal quest_progress_updated(quest_id: StringName, current_step: int, total_steps: int)
signal quest_completed(quest_id: StringName)
signal enemy_defeated(enemy_id: StringName)
signal enemy_defeated_at(enemy_id: StringName, position: Vector2, exp_reward: int, loot_table: LootTable, enemy_instance_id: int)

# --- State & Flow Signals ---
signal game_state_changed(previous_state: int, new_state: int)
signal scene_change_requested(scene_path: String)

# --- UI & Dialogue Signals ---
signal dialogue_started(dialogue_id: StringName)
signal dialogue_ended
signal info_panel_requested(title: String, content: String)
signal info_panel_closed


func _ready() -> void:
	print("[EventBus] Initialized.")

