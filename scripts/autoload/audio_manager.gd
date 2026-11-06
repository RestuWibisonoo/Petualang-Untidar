extends Node

## AudioManager.gd
## Manages BGM and SFX playback, volume control, and browser audio unlocking.
## Runs in PROCESS_MODE_ALWAYS so audio keeps playing regardless of pause state.

const SFX_POOL_SIZE: int = 8

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _audio_unlocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	print("[AudioManager] Initialized with %d SFX pool channels." % SFX_POOL_SIZE)


func _setup_audio_players() -> void:
	# BGM player setup
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = &"Master" # Default fallback bus
	add_child(_bgm_player)

	# SFX pool setup
	for i in range(SFX_POOL_SIZE):
		var sfx := AudioStreamPlayer.new()
		sfx.name = "SFXPlayer_%d" % i
		sfx.bus = &"Master"
		add_child(sfx)
		_sfx_players.append(sfx)


func play_bgm(stream: AudioStream, fade_duration: float = 0.5) -> void:
	if not stream:
		push_warning("[AudioManager] Attempted to play null BGM stream.")
		return

	if _bgm_player.stream == stream and _bgm_player.playing:
		return

	if fade_duration > 0.0 and _bgm_player.playing:
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db", -40.0, fade_duration)
		tween.tween_callback(func() -> void:
			_bgm_player.stream = stream
			_bgm_player.play()
			var fade_in := create_tween()
			fade_in.tween_property(_bgm_player, "volume_db", 0.0, fade_duration)
		)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = 0.0
		_bgm_player.play()


func stop_bgm(fade_duration: float = 0.5) -> void:
	if not _bgm_player.playing:
		return

	if fade_duration > 0.0:
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db", -40.0, fade_duration)
		tween.tween_callback(func() -> void:
			_bgm_player.stop()
			_bgm_player.volume_db = 0.0
		)
	else:
		_bgm_player.stop()


func play_sfx(stream: AudioStream, pitch_variance: float = 0.0) -> void:
	if not stream:
		push_warning("[AudioManager] Attempted to play null SFX stream.")
		return

	var player: AudioStreamPlayer = _sfx_players[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

	player.stream = stream
	if pitch_variance > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0

	player.play()


func set_bus_volume(bus_name: StringName, volume_percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("[AudioManager] Audio bus not found: %s" % bus_name)
		return

	var clamped := clampf(volume_percent, 0.0, 1.0)
	if clamped <= 0.001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped))


func unlock_audio() -> void:
	if _audio_unlocked:
		return
	_audio_unlocked = true
	print("[AudioManager] Web/Mobile Audio context unlocked.")


func is_audio_unlocked() -> bool:
	return _audio_unlocked

