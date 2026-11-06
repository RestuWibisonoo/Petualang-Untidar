extends Control

## main.gd
## Main entry scene script for validating project foundation, Autoloads, and InputMap.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var state_label: Label = %StateLabel
@onready var autoload_label: Label = %AutoloadLabel
@onready var input_test_label: Label = %InputTestLabel
@onready var pause_indicator: Label = %PauseIndicator


func _ready() -> void:
	print("=================================================")
	print("   PETUALANG UNTIDAR - PHASE 1 FOUNDATION")
	print("=================================================")
	print("[Main] Engine Version : %s" % Engine.get_version_info().string)
	print("[Main] Active Renderer: %s" % RenderingServer.get_video_adapter_name())
	
	_validate_autoloads()
	EventBus.game_state_changed.connect(_on_game_state_changed)

	# Transition to PLAYING state to demonstrate GameManager lifecycle
	if GameManager.current_state == GameManager.GameState.BOOT:
		GameManager.change_state(GameManager.GameState.PLAYING)

	_update_ui()


func _validate_autoloads() -> void:
	var ok: bool = true
	if not EventBus:
		push_error("[Main] EventBus Autoload missing!")
		ok = false
	if not GameManager:
		push_error("[Main] GameManager Autoload missing!")
		ok = false
	if not AudioManager:
		push_error("[Main] AudioManager Autoload missing!")
		ok = false
	if not SceneManager:
		push_error("[Main] SceneManager Autoload missing!")
		ok = false

	if ok:
		print("[Main] All core Autoloads verified successfully.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()
		_update_ui()
		get_viewport().set_input_as_handled()
		return

	# Test and display active input actions
	var tested_actions: Array[StringName] = [
		&"move_up", &"move_down", &"move_left", &"move_right",
		&"attack", &"dodge", &"interact", &"skill_primary", &"skill_secondary",
		&"inventory", &"character", &"quest_log", &"map"
	]

	for action in tested_actions:
		if event.is_action_pressed(action):
			if input_test_label:
				input_test_label.text = "Last Action Detected: %s" % action
			print("[Main] Input action detected: %s" % action)
			break


func _on_game_state_changed(_prev_state: int, new_state: int) -> void:
	_update_ui()
	print("[Main] Observed GameState change: %s" % GameManager.get_state_name(new_state as GameManager.GameState))


func _update_ui() -> void:
	if state_label:
		state_label.text = "GameState: %s" % GameManager.get_state_name(GameManager.current_state)
	if pause_indicator:
		pause_indicator.visible = GameManager.is_paused()
	if autoload_label:
		autoload_label.text = "Autoloads: EventBus, GameManager, AudioManager, SceneManager [ACTIVE]"
