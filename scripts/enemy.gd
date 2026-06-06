class_name Enemy extends CharacterBody2D

# Generic human enemy. Behaviour is configured through the exported
# properties below, so the same script drives melee chasers (Etnan),
# ice mages (José) and slipper-throwers (Socorro).

@export var max_health: int = 100
@export var move_speed: float = 60.0
@export var can_move: bool = true            # chase the player (run animation)
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.4
@export var attack_damage: int = 12
@export var lunge_distance: float = 12.0     # melee hop toward the player

@export var is_ranged: bool = false
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 180.0

# Every Nth ranged attack spawns special_scene at the player instead of a
# normal projectile (José's ice zone). 0 disables.
@export var special_every: int = 0
@export var special_scene: PackedScene

# Loot
@export var gold_drop: int = 0
@export var coin_count: int = 1
@export var coin_scene: PackedScene
@export var clears_debt: bool = false   # José: killing him wipes the debt

const KNOCKBACK_FORCE: int = 90

var health: int
var is_alive: bool = true
var is_attacking: bool = false
var target: Node2D = null
var attack_timer: float = 0.0
var attack_count: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: Node2D = $HealthBar
@onready var hurt_sound: AudioStreamPlayer2D = get_node_or_null("HurtSound")
@onready var death_sound: AudioStreamPlayer2D = get_node_or_null("DeathSound")

func _ready() -> void:
	health = max_health
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	if target and _target_is_dead():
		target = null

	if is_attacking:
		return

	if target:
		_handle_target(delta)
	else:
		sprite.play("idle")

func _handle_target(delta: float) -> void:
	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var direction: Vector2 = to_target.normalized()

	if abs(direction.x) > 0.01:
		sprite.flip_h = direction.x > 0

	if can_move and distance > attack_range:
		sprite.play("walk")
		position += direction * move_speed * delta
	elif attack_timer <= 0.0:
		_start_attack(direction)
	else:
		sprite.play("idle")

func _start_attack(direction: Vector2) -> void:
	is_attacking = true
	attack_timer = attack_cooldown
	sprite.play("attack")

	if is_ranged and projectile_scene:
		_shoot(direction)
	else:
		_melee(direction)

	await get_tree().create_timer(_attack_duration()).timeout
	if is_instance_valid(self) and is_alive:
		is_attacking = false

func _attack_duration() -> float:
	var frames := sprite.sprite_frames
	if frames and frames.has_animation("attack"):
		var count := frames.get_frame_count("attack")
		var spd := frames.get_animation_speed("attack")
		if spd > 0.0:
			return count / spd
	return 0.5

# --- Melee ---
func _melee(direction: Vector2) -> void:
	var origin: Vector2 = position
	var lunge: Vector2 = origin + direction * lunge_distance
	var tween = create_tween()
	tween.tween_property(self, "position", lunge, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_melee_hit)
	tween.tween_property(self, "position", origin, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _melee_hit() -> void:
	if not is_alive or target == null or not target.has_method("take_damage"):
		return
	if global_position.distance_to(target.global_position) <= attack_range * 1.6:
		target.take_damage(attack_damage)

# --- Ranged ---
func _shoot(direction: Vector2) -> void:
	attack_count += 1

	# Every Nth attack: drop a slowing ice zone on the player instead.
	if special_every > 0 and special_scene and attack_count % special_every == 0:
		_spawn_special()
		return

	var proj = projectile_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + direction * 36.0
	if proj.has_method("launch"):
		proj.launch(direction, attack_damage, projectile_speed)

func _spawn_special() -> void:
	if target == null:
		return
	var zone = special_scene.instantiate()
	get_parent().add_child(zone)
	zone.global_position = target.global_position

# --- Damage / death ---
func take_damage(damage: int, attacker_position: Vector2) -> void:
	if not is_alive:
		return

	health -= damage
	health_bar.update_health(health)

	if health <= 0:
		_die()
		return

	if hurt_sound:
		hurt_sound.play()
	_flash()

	var knockback_direction = (position - attacker_position).normalized()
	var target_position = position + knockback_direction * KNOCKBACK_FORCE
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", target_position, 0.4)

func _flash() -> void:
	sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _drop_coins() -> void:
	if coin_scene == null or gold_drop <= 0:
		return
	var n: int = max(1, coin_count)
	var base: int = gold_drop / n
	var remainder: int = gold_drop - base * n
	for i in range(n):
		var coin = coin_scene.instantiate()
		get_parent().call_deferred("add_child", coin)
		coin.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-12, 24))
		var amount: int = base + (remainder if i == 0 else 0)
		if coin.has_method("setup"):
			coin.setup(amount)

func _die() -> void:
	is_alive = false
	is_attacking = false
	target = null

	# Killing José wipes Kaique's debt.
	if clears_debt:
		GameState.clear_debt()
	_drop_coins()

	if death_sound:
		death_sound.play()

	sprite.play("die")
	$CollisionShape2D.set_deferred("disabled", true)
	$Sight/CollisionShape2D.set_deferred("disabled", true)

	var bar := get_node_or_null("HealthBar")
	if bar:
		bar.visible = false

	# The "die" animation already shows the collapse; just fade out and remove.
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.7).set_delay(0.4)
	tween.tween_callback(queue_free)

func _target_is_dead() -> bool:
	return "is_dead" in target and target.is_dead

func _on_sight_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		target = body

func _on_sight_body_exited(body: Node2D) -> void:
	if body.name == "Player" and is_alive:
		target = null
		sprite.play("idle")
