extends Node

## SceneManager.gd
## Manages scene transitions, reload, and visual screen fades.
## Runs in PROCESS_MODE_ALWAYS so transitions function even during pause.

var _is_transitioning: bool = false
var _overlay_layer: CanvasLayer
var _fade_rect: ColorRect
var target_spawn_point_id: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fade_overlay()
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	print("[SceneManager] Initialized.")


func _setup_fade_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "SceneTransitionOverlay"
	_overlay_layer.layer = 100 # High layer to render on top of UI
	add_child(_overlay_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_fade_rect)


func change_scene_with_spawn(scene_path: String, spawn_id: StringName = &"", with_fade: bool = true, duration: float = 0.3) -> void:
	if _is_transitioning:
		push_warning("[SceneManager] Scene change already in progress.")
		return

	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] Scene file does not exist: %s" % scene_path)
		return

	target_spawn_point_id = spawn_id
	_execute_scene_change_to_file(scene_path, with_fade, duration)


func get_and_clear_spawn_point() -> StringName:
	var spawn_id := target_spawn_point_id
	target_spawn_point_id = &""
	return spawn_id


func change_scene_to_file(scene_path: String, with_fade: bool = true, duration: float = 0.3) -> void:
	if _is_transitioning:
		push_warning("[SceneManager] Scene change already in progress.")
		return

	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] Scene file does not exist: %s" % scene_path)
		return

	target_spawn_point_id = &""
	_execute_scene_change_to_file(scene_path, with_fade, duration)


func _execute_scene_change_to_file(scene_path: String, with_fade: bool, duration: float) -> void:
	_is_transitioning = true

	if with_fade and duration > 0.0:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween := create_tween()
		tween.tween_property(_fade_rect, "color:a", 1.0, duration)
		tween.tween_callback(func() -> void:
			get_tree().change_scene_to_file(scene_path)
			var fade_in := create_tween()
			fade_in.tween_property(_fade_rect, "color:a", 0.0, duration)
			fade_in.tween_callback(func() -> void:
				_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_is_transitioning = false
			)
		)
	else:
		get_tree().change_scene_to_file(scene_path)
		_is_transitioning = false


func change_scene_to_packed(packed_scene: PackedScene, with_fade: bool = true, duration: float = 0.3) -> void:
	if _is_transitioning:
		push_warning("[SceneManager] Scene change already in progress.")
		return

	if not packed_scene:
		push_error("[SceneManager] PackedScene is null.")
		return

	target_spawn_point_id = &""
	_is_transitioning = true

	if with_fade and duration > 0.0:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween := create_tween()
		tween.tween_property(_fade_rect, "color:a", 1.0, duration)
		tween.tween_callback(func() -> void:
			get_tree().change_scene_to_packed(packed_scene)
			var fade_in := create_tween()
			fade_in.tween_property(_fade_rect, "color:a", 0.0, duration)
			fade_in.tween_callback(func() -> void:
				_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_is_transitioning = false
			)
		)
	else:
		get_tree().change_scene_to_packed(packed_scene)
		_is_transitioning = false


func reload_current_scene(with_fade: bool = true) -> void:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path != "":
		change_scene_to_file(current_scene.scene_file_path, with_fade)
	else:
		get_tree().reload_current_scene()


func is_transitioning() -> bool:
	return _is_transitioning


func _on_scene_change_requested(scene_path: String) -> void:
	change_scene_to_file(scene_path)

