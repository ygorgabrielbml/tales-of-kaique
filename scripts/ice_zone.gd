extends Area2D

# Ground ice patch created by José's special attack. Slows the player while
# they stand on it, then melts away.

@export var duration: float = 15.0

var _player_inside: Node2D = null

func _ready() -> void:
	# Appear, hold, then fade out and disappear.
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	t.tween_interval(duration - 0.9)
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(_expire)

func _expire() -> void:
	_release_player()
	queue_free()

func _release_player() -> void:
	if _player_inside and is_instance_valid(_player_inside) and _player_inside.has_method("remove_slow"):
		_player_inside.remove_slow()
		_player_inside = null

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("add_slow"):
		_player_inside = body
		body.add_slow()

func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside and body.has_method("remove_slow"):
		body.remove_slow()
		_player_inside = null
