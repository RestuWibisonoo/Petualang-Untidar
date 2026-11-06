extends Node2D

## main.gd
## Main entry point and test harness for Phase 2: Character Foundation.
## Hosts Player, test arena, camera bounds, touch controls, and diagnostic HUD.

@onready var player: Player = $Player
@onready var touch_controls: TouchControls = $TouchControls
@onready var state_label: Label = %StateLabel
@onready var speed_label: Label = %SpeedLabel
@onready var facing_label: Label = %FacingLabel
@onready var pause_indicator: Label = %PauseIndicator


func _ready() -> void:
	print("=================================================")
	print("   PETUALANG UNTIDAR - PHASE 2: CHARACTER FOUNDATION")
	print("=================================================")
	print("[Main] Engine Version : %s" % Engine.get_version_info().string)

	if player and touch_controls:
		touch_controls.set_target_player(player)

	EventBus.game_state_changed.connect(_on_game_state_changed)

	if GameManager.current_state == GameManager.GameState.BOOT:
		GameManager.change_state(GameManager.GameState.PLAYING)


func _process(_delta: float) -> void:
	if not player:
		return

	if state_label and player.state_machine:
		var st_name := String(player.state_machine.get_current_state_name()).to_upper()
		state_label.text = "Player State: %s" % st_name

	if speed_label:
		speed_label.text = "Speed: %.1f px/s" % player.velocity.length()

	if facing_label:
		facing_label.text = "Facing: %s" % String(player.get_facing_direction_name()).to_upper()

	if pause_indicator:
		pause_indicator.visible = GameManager.is_paused()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


func _on_game_state_changed(_prev: int, new_state: int) -> void:
	print("[Main] GameState: %s" % GameManager.get_state_name(new_state as GameManager.GameState))
