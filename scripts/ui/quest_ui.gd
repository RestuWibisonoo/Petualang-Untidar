class_name QuestUI
extends CanvasLayer

## QuestUI.gd
## Unified UI for Quest Log: active quests, completed quests, objective tracking,
## reward preview, and reward claiming.
## Pixel-art styled, supporting keyboard ('Q' / Esc) and touchscreen.

signal opened
signal closed

var _current_tab: int = 0 # 0: Active, 1: Completed
var _selected_quest_id: StringName = &""
var _toast_tween: Tween = null

@onready var main_panel: Control = $MainPanel
@onready var close_button: Button = %CloseButton
@onready var tab_active_btn: Button = %TabActiveButton
@onready var tab_completed_btn: Button = %TabCompletedButton
@onready var quest_list_container: VBoxContainer = %QuestListContainer
@onready var quest_title_label: Label = %QuestTitleLabel
@onready var quest_giver_label: Label = %QuestGiverLabel
@onready var quest_desc_label: Label = %QuestDescLabel
@onready var objectives_container: VBoxContainer = %ObjectivesContainer
@onready var rewards_container: VBoxContainer = %RewardsContainer
@onready var claim_button: Button = %ClaimRewardButton
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel


func _ready() -> void:
	layer = 24
	if main_panel:
		main_panel.visible = false

	if notification_panel:
		notification_panel.visible = false
		notification_panel.modulate.a = 0.0

	if close_button:
		close_button.pressed.connect(close_ui)

	if tab_active_btn:
		tab_active_btn.pressed.connect(func(): _switch_tab(0))
	if tab_completed_btn:
		tab_completed_btn.pressed.connect(func(): _switch_tab(1))

	if claim_button:
		claim_button.pressed.connect(_on_claim_button_pressed)

	_connect_event_bus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		toggle_ui()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close_ui()
		get_viewport().set_input_as_handled()


func _connect_event_bus() -> void:
	if not is_inside_tree():
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if not event_bus:
		return

	if event_bus.has_signal("quest_accepted") and not event_bus.quest_accepted.is_connected(_on_quest_accepted):
		event_bus.quest_accepted.connect(_on_quest_accepted)
	if event_bus.has_signal("quest_completed") and not event_bus.quest_completed.is_connected(_on_quest_completed):
		event_bus.quest_completed.connect(_on_quest_completed)
	if event_bus.has_signal("quest_reward_claimed") and not event_bus.quest_reward_claimed.is_connected(_on_quest_reward_claimed):
		event_bus.quest_reward_claimed.connect(_on_quest_reward_claimed)
	if event_bus.has_signal("quest_objective_updated") and not event_bus.quest_objective_updated.is_connected(_on_objective_updated):
		event_bus.quest_objective_updated.connect(_on_objective_updated)


func is_open() -> bool:
	return main_panel != null and main_panel.visible


func open_ui() -> void:
	if main_panel:
		main_panel.visible = true
	_refresh_all()
	opened.emit()


func close_ui() -> void:
	if main_panel:
		main_panel.visible = false
	closed.emit()


func toggle_ui() -> void:
	if is_open():
		close_ui()
	else:
		open_ui()


func _switch_tab(tab_idx: int) -> void:
	_current_tab = tab_idx
	if tab_active_btn:
		tab_active_btn.disabled = (_current_tab == 0)
	if tab_completed_btn:
		tab_completed_btn.disabled = (_current_tab == 1)
	_refresh_all()


func _refresh_all() -> void:
	var qm := QuestManager.get_instance()
	if not qm:
		return

	# Clear previous quest list
	if quest_list_container:
		for child in quest_list_container.get_children():
			child.queue_free()

	var quests: Array[QuestData] = []
	if _current_tab == 0:
		quests = qm.get_active_quests()
	else:
		# Both completed and claimed
		var completed_ids: Array[StringName] = qm.get_quests_by_status(QuestRuntimeState.QuestStatus.COMPLETED)
		var claimed_ids: Array[StringName] = qm.get_quests_by_status(QuestRuntimeState.QuestStatus.REWARD_CLAIMED)
		for qid in completed_ids:
			var q := qm.get_quest_data(qid)
			if q and not quests.has(q):
				quests.append(q)
		for qid in claimed_ids:
			var q := qm.get_quest_data(qid)
			if q and not quests.has(q):
				quests.append(q)

	if quests.is_empty():
		_selected_quest_id = &""
		_display_empty_details()
		return

	var found_selected := false
	for q in quests:
		var btn := Button.new()
		var state := qm.get_quest_state(q.quest_id)
		var status_str := ""
		if state:
			if state.status == QuestRuntimeState.QuestStatus.COMPLETED:
				status_str = " [SELESAI]"
			elif state.status == QuestRuntimeState.QuestStatus.REWARD_CLAIMED:
				status_str = " [KLAIM]"
		btn.text = "%s%s" % [q.title, status_str]
		btn.custom_minimum_size = Vector2(160, 28)
		btn.add_theme_font_size_override("font_size", 9)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var q_id := q.quest_id
		btn.pressed.connect(func(): _select_quest(q_id))
		quest_list_container.add_child(btn)

		if q.quest_id == _selected_quest_id:
			found_selected = true

	if not found_selected and not quests.is_empty():
		_select_quest(quests[0].quest_id)
	else:
		_select_quest(_selected_quest_id)


func _select_quest(quest_id: StringName) -> void:
	_selected_quest_id = quest_id
	var qm := QuestManager.get_instance()
	if not qm:
		return

	var q := qm.get_quest_data(quest_id)
	var state := qm.get_quest_state(quest_id)
	if not q or not state:
		_display_empty_details()
		return

	if quest_title_label:
		quest_title_label.text = q.title
	if quest_giver_label:
		quest_giver_label.text = "Pemberi: %s" % (q.quest_giver_id if q.quest_giver_id != &"" else "Misterius")
	if quest_desc_label:
		quest_desc_label.text = q.description

	# Objectives
	if objectives_container:
		for child in objectives_container.get_children():
			child.queue_free()

		for obj in q.objectives:
			var cur_amt: int = qm.get_objective_progress(quest_id, obj.objective_id)
			var req_amt: int = obj.required_amount
			var is_done: bool = cur_amt >= req_amt
			var mark: String = "[✓]" if is_done else "[ ]"

			var lbl := Label.new()
			lbl.text = "%s %s (%d/%d)" % [mark, obj.description, cur_amt, req_amt]
			lbl.add_theme_font_size_override("font_size", 9)
			if is_done:
				lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			else:
				lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			objectives_container.add_child(lbl)

	# Rewards
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()

		if q.reward_exp > 0:
			var exp_lbl := Label.new()
			exp_lbl.text = "+ %d EXP" % q.reward_exp
			exp_lbl.add_theme_font_size_override("font_size", 9)
			exp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			rewards_container.add_child(exp_lbl)

		for item_rew in q.reward_items:
			if item_rew and item_rew.item:
				var item_lbl := Label.new()
				item_lbl.text = "+ %dx %s" % [item_rew.quantity, item_rew.item.item_name]
				item_lbl.add_theme_font_size_override("font_size", 9)
				item_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
				rewards_container.add_child(item_lbl)

	# Claim button
	if claim_button:
		if state.status == QuestRuntimeState.QuestStatus.COMPLETED:
			claim_button.visible = true
			claim_button.disabled = false
			claim_button.text = "Klaim Hadiah"
		elif state.status == QuestRuntimeState.QuestStatus.REWARD_CLAIMED:
			claim_button.visible = true
			claim_button.disabled = true
			claim_button.text = "Hadiah Sudah Diklaim"
		else:
			claim_button.visible = false


func _display_empty_details() -> void:
	if quest_title_label:
		quest_title_label.text = "Pilih Quest"
	if quest_giver_label:
		quest_giver_label.text = ""
	if quest_desc_label:
		quest_desc_label.text = "Tidak ada quest yang dipilih."
	if objectives_container:
		for child in objectives_container.get_children():
			child.queue_free()
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()
	if claim_button:
		claim_button.visible = false


func _on_claim_button_pressed() -> void:
	if _selected_quest_id == &"":
		return

	var qm := QuestManager.get_instance()
	if not qm:
		return

	var success: bool = qm.claim_reward(_selected_quest_id)
	if success:
		var q := qm.get_quest_data(_selected_quest_id)
		var q_title := q.title if q else String(_selected_quest_id)
		show_notification("Hadiah Diklaim: %s" % q_title)
		_refresh_all()
	else:
		show_notification("Gagal mengklaim! Periksa ruang penyimpanan tas.")


func show_notification(message: String) -> void:
	if not notification_panel or not notification_label:
		return

	notification_label.text = message
	notification_panel.visible = true

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	notification_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(notification_panel, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(notification_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func(): notification_panel.visible = false)


func _on_quest_accepted(quest_id: StringName) -> void:
	var qm := QuestManager.get_instance()
	var title: String = String(quest_id)
	if qm:
		var q := qm.get_quest_data(quest_id)
		if q:
			title = q.title
	show_notification("Quest Baru Diterima: %s" % title)
	if is_open():
		_refresh_all()


func _on_quest_completed(quest_id: StringName) -> void:
	var qm := QuestManager.get_instance()
	var title: String = String(quest_id)
	if qm:
		var q := qm.get_quest_data(quest_id)
		if q:
			title = q.title
	show_notification("Quest Selesai: %s!" % title)
	if is_open():
		_refresh_all()


func _on_quest_reward_claimed(quest_id: StringName) -> void:
	if is_open():
		_refresh_all()


func _on_objective_updated(_quest_id: StringName, _obj_id: StringName, _cur: int, _req: int) -> void:
	if is_open() and _selected_quest_id == _quest_id:
		_select_quest(_selected_quest_id)
