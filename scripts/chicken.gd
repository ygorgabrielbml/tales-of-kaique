extends CharacterBody2D

const SPEED: float = 70.0
const KNOCKBACK_FORCE: int = 100
const ATTACK_RANGE: float = 30.0
const ATTACK_DAMAGE: int = 10
const ATTACK_COOLDOWN: float = 1.2
const LUNGE_DISTANCE: float = 14.0

const IDLE_CLUCK_MIN: float = 2.0
const IDLE_CLUCK_MAX: float = 5.0

# Loot (chicken drops very little)
@export var gold_drop: int = 4
@export var coin_scene: PackedScene

var is_alive: bool = true
var is_attacking: bool = false
var health: int = 100
var target: Node2D = null
var attack_timer: float = 0.0
var idle_cluck_timer: float = 0.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_sound: AudioStreamPlayer2D = $IdleSound
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var health_bar: Node2D = $HealthBar

func _ready() -> void:
	add_to_group("enemies")
	idle_cluck_timer = randf_range(IDLE_CLUCK_MIN, IDLE_CLUCK_MAX)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	# Stop chasing/attacking a dead player
	if target and _target_is_dead():
		target = null

	# Don't interrupt an in-progress peck
	if is_attacking:
		return

	if target:
		_chase(delta)
	else:
		animated_sprite_2d.play("idle")
		_idle_clucks(delta)

func _target_is_dead() -> bool:
	return "is_dead" in target and target.is_dead

func _idle_clucks(delta: float) -> void:
	idle_cluck_timer -= delta
	if idle_cluck_timer <= 0.0:
		idle_cluck_timer = randf_range(IDLE_CLUCK_MIN, IDLE_CLUCK_MAX)
		idle_sound.pitch_scale = randf_range(0.9, 1.1)
		idle_sound.play()

func _chase(delta: float) -> void:
	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var direction: Vector2 = to_target.normalized()

	# Face the player (sprite faces left by default)
	if abs(direction.x) > 0.01:
		animated_sprite_2d.flip_h = direction.x > 0

	if distance > ATTACK_RANGE:
		animated_sprite_2d.play("walk")
		position += direction * SPEED * delta
	elif attack_timer <= 0.0:
		_attack(direction)
	else:
		animated_sprite_2d.play("idle")

func _attack(direction: Vector2) -> void:
	is_attacking = true
	attack_timer = ATTACK_COOLDOWN
	animated_sprite_2d.play("attack")
	attack_sound.play()

	# Quick peck: lunge toward the player, deal damage at the apex, then recoil
	var origin: Vector2 = position
	var lunge_target: Vector2 = origin + direction * LUNGE_DISTANCE

	var tween = create_tween()
	tween.tween_property(self, "position", lunge_target, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_deal_damage)
	tween.tween_property(self, "position", origin, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: is_attacking = false)

func _deal_damage() -> void:
	if not is_alive or target == null:
		return
	if not target.has_method("take_damage"):
		return
	if global_position.distance_to(target.global_position) <= ATTACK_RANGE * 1.6:
		target.take_damage(ATTACK_DAMAGE)

func take_damage(damage: int, attacker_position: Vector2) -> void:
	if not is_alive:
		return

	health -= damage
	health_bar.update_health(health)

	if health <= 0:
		_die()
		return

	hurt_sound.play()
	_flash()

	# Knockback
	var knockback_direction = (position - attacker_position).normalized()
	var target_position = position + knockback_direction * KNOCKBACK_FORCE

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", target_position, 0.5)

func _flash() -> void:
	animated_sprite_2d.modulate = Color(1.0, 0.4, 0.4)
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.25)

func _die() -> void:
	is_alive = false
	is_attacking = false
	target = null

	_drop_coins()
	death_sound.play()

	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)
	$Sight/CollisionShape2D.set_deferred("disabled", true)

	animated_sprite_2d.play("die")
	animated_sprite_2d.modulate = Color.WHITE

	# Fall over and fade out, then remove
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "rotation_degrees", 90.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(animated_sprite_2d, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.chain().tween_callback(queue_free)

func _drop_coins() -> void:
	if coin_scene == null or gold_drop <= 0:
		return
	var coin = coin_scene.instantiate()
	get_parent().call_deferred("add_child", coin)
	coin.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-6, 12))
	if coin.has_method("setup"):
		coin.setup(gold_drop)

func _on_sight_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		target = body

func _on_sight_body_exited(body: Node2D) -> void:
	if body.name == "Player" and is_alive:
		target = null
		animated_sprite_2d.play("idle")
