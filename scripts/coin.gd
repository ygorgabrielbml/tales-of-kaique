extends Area2D

# Gold coin dropped by enemies. Adds its value to GameState when the player
# touches it.

@export var value: int = 1

var _collected: bool = false

@onready var sprite: Node2D = get_node_or_null("Sprite2D")
@onready var pickup_sound: AudioStreamPlayer2D = get_node_or_null("PickupSound")

func _ready() -> void:
	# Pop outward on spawn, then settle into a gentle bob.
	var origin := position
	var pop = create_tween()
	pop.tween_property(self, "position", origin + Vector2(randf_range(-14, 14), -16), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "position", origin, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pop.tween_callback(_start_bob)

func _start_bob() -> void:
	var y := position.y
	var bob = create_tween().set_loops()
	bob.tween_property(self, "position:y", y - 5, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", y, 0.6).set_trans(Tween.TRANS_SINE)

func setup(amount: int) -> void:
	value = amount

func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	GameState.add_gold(value)
	set_deferred("monitoring", false)
	if sprite:
		sprite.visible = false
	if pickup_sound:
		pickup_sound.play()
		await pickup_sound.finished
	queue_free()
