extends Node

## GameManager.gd
## Manages global game lifecycle states and pause state.
## Runs in PROCESS_MODE_ALWAYS to receive input even when game tree is paused.

enum GameState {
	BOOT,
	MAIN_MENU,
	PLAYING,
	PAUSED,
	DIALOGUE,
	GAME_OVER
}

var current_state: GameState = GameState.BOOT
var previous_state: GameState = GameState.BOOT
var is_game_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GameManager] Initialized in state: %s" % get_state_name(current_state))


func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	previous_state = current_state
	current_state = new_state

	print("[GameManager] State transition: %s -> %s" % [
		get_state_name(previous_state),
		get_state_name(current_state)
	])

	# Handle tree pause state
	if current_state == GameState.PAUSED:
		get_tree().paused = true
	elif previous_state == GameState.PAUSED and current_state != GameState.PAUSED:
		get_tree().paused = false

	# Update active flag
	is_game_active = (current_state == GameState.PLAYING or current_state == GameState.DIALOGUE)

	EventBus.game_state_changed.emit(previous_state, current_state)


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		change_state(previous_state if previous_state != GameState.PAUSED else GameState.PLAYING)


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		change_state(previous_state if previous_state != GameState.PAUSED else GameState.PLAYING)


func is_paused() -> bool:
	return current_state == GameState.PAUSED


func get_state_name(state: GameState) -> String:
	match state:
		GameState.BOOT:
			return "BOOT"
		GameState.MAIN_MENU:
			return "MAIN_MENU"
		GameState.PLAYING:
			return "PLAYING"
		GameState.PAUSED:
			return "PAUSED"
		GameState.DIALOGUE:
			return "DIALOGUE"
		GameState.GAME_OVER:
			return "GAME_OVER"
		_:
			return "UNKNOWN"

