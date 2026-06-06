extends Area2D

# Shared projectile for enemy ranged attacks (ice spike, thrown chinela).

@export var lifetime: float = 3.0
@export var face_direction: bool = true   # rotate sprite to travel direction (ice)
@export var spin_speed: float = 0.0       # rad/s self-rotation (spinning chinela)

var velocity: Vector2 = Vector2.ZERO
var damage: int = 10

func launch(direction: Vector2, dmg: int, speed: float) -> void:
	damage = dmg
	velocity = direction.normalized() * speed
	if face_direction:
		rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if spin_speed != 0.0:
		rotation += spin_speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
