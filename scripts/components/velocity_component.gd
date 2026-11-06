class_name VelocityComponent
extends Node

## VelocityComponent.gd
## Reusable component handling 2D movement physics (acceleration, friction, max speed).

@export var max_speed: float = 120.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0
@export var knockback_friction: float = 800.0

var velocity: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO


func accelerate_in_direction(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		var target_velocity := direction.normalized() * max_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
		if velocity.length_squared() > max_speed * max_speed:
			velocity = velocity.limit_length(max_speed)
	else:
		decelerate(delta)


func decelerate(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func apply_knockback(force_vector: Vector2) -> void:
	if not force_vector.is_finite():
		return
	knockback_velocity = force_vector


func update_knockback(delta: float) -> void:
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)


func apply_to_body(body: CharacterBody2D, delta: float = 0.0) -> void:
	if body:
		if delta > 0.0:
			update_knockback(delta)
		body.velocity = velocity + knockback_velocity
		if body.is_inside_tree() and body.get_world_2d():
			body.move_and_slide()
			velocity = body.velocity


func stop() -> void:
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO

