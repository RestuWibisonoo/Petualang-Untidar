class_name InteractionComponent
extends Area2D

## InteractionComponent.gd
## Attached to Player to scan for nearby Interactable areas, select the closest,
## display prompts, and trigger interactions via the "interact" action.

signal target_changed(new_target: Interactable)
signal interaction_performed(target: Interactable)

@export var interaction_radius: float = 24.0

var current_target: Interactable = null
var _candidates: Array[Interactable] = []


func _ready() -> void:
	# Layer 0 (doesn't be scanned), Mask 128 (Layer 8: Interactables)
	collision_layer = 0
	collision_mask = 128

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	_setup_collision_shape()


func _setup_collision_shape() -> void:
	if not has_node("CollisionShape2D"):
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = interaction_radius
		col.shape = circle
		add_child(col)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if current_target and current_target.can_interact(owner):
			interact_with_current_target()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_closest_target()


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable and not _candidates.has(area):
		_candidates.append(area)
		if not area.availability_changed.is_connected(_on_candidate_availability_changed):
			area.availability_changed.connect(_on_candidate_availability_changed)
		_update_closest_target()


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_candidates.erase(area)
		if area.availability_changed.is_connected(_on_candidate_availability_changed):
			area.availability_changed.disconnect(_on_candidate_availability_changed)
		if current_target == area:
			_set_target(null)
		_update_closest_target()


func _on_candidate_availability_changed(_available: bool) -> void:
	_update_closest_target()


func _update_closest_target() -> void:
	# Remove candidates that are no longer valid or freed
	var valid_candidates: Array[Interactable] = []
	for candidate in _candidates:
		if is_instance_valid(candidate) and candidate.can_interact(owner):
			valid_candidates.append(candidate)
	_candidates = valid_candidates

	if _candidates.is_empty():
		if current_target != null:
			_set_target(null)
		return

	var closest: Interactable = null
	var min_dist_sq: float = INF
	var my_pos := global_position

	for candidate in _candidates:
		var dist_sq := my_pos.distance_squared_to(candidate.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest = candidate

	if closest != current_target:
		_set_target(closest)


func _set_target(target: Interactable) -> void:
	current_target = target
	target_changed.emit(current_target)


func interact_with_current_target() -> void:
	if current_target and current_target.can_interact(owner):
		var target := current_target
		target.interact(owner)
		interaction_performed.emit(target)
		_update_closest_target()


func trigger_interact() -> void:
	interact_with_current_target()


func get_current_target() -> Interactable:
	return current_target
