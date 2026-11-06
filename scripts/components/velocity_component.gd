class_name VelocityComponent
extends Node

## VelocityComponent.gd
## Reusable component handling 2D movement physics (acceleration, friction, max speed).

@export var max_speed: float = 120.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0

var velocity: Vector2 = Vector2.ZERO


func accelerate_in_direction(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		var target_velocity := direction.normalized() * max_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		decelerate(delta)


func decelerate(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func apply_to_body(body: CharacterBody2D) -> void:
	if body:
		body.velocity = velocity
		body.move_and_slide()
		velocity = body.velocity


func stop() -> void:
	velocity = Vector2.ZERO

