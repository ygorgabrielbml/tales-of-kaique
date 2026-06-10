extends CharacterBody2D

const SPEED = 300.0
const MAX_HEALTH: int = 100
const DEATH_SCREEN := preload("res://scenes/death_screen.tscn")
var last_direction: Vector2 = Vector2.RIGHT
var is_attacking = false
var is_dead = false
var is_hurt = false
var speed_multiplier: float = 1.0
var _slow_count: int = 0
var hitbox_offset: Vector2
var strength: int = 20
var health: int = MAX_HEALTH

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var swing_sword: AudioStreamPlayer2D = $SwingSword
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	hitbox_offset = hitbox.position
	add_to_group("player")
	GameState.set_health(health, MAX_HEALTH)

func take_damage(damage: int) -> void:
	if is_dead:
		return
	health = max(0, health - damage)
	GameState.set_health(health, MAX_HEALTH)
	if health <= 0:
		_die()
	else:
		_play_hurt()

# Damage feedback: red flash + quick blink (no dedicated hurt sprite exists)
func _play_hurt() -> void:
	if is_hurt:
		return
	is_hurt = true
	hurt_sound.play()
	animated_sprite_2d.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate:a", 0.3, 0.08)
	tween.tween_property(animated_sprite_2d, "modulate:a", 1.0, 0.08)
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.2)
	tween.tween_callback(func() -> void: is_hurt = false)

func _die() -> void:
	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	hitbox.monitoring = false
	animated_sprite_2d.modulate = Color.WHITE
	animated_sprite_2d.play("dying")
	death_sound.play()

	# Death sequence overlay: black screen + "MORREU HOJE" -> cross flips -> fire,
	# then a menu to revive (reload this scene) or quit. The overlay handles it.
	var screen := DEATH_SCREEN.instantiate()
	get_tree().current_scene.add_child(screen)

func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Disable hitbox until an attack is triggered
	hitbox.monitoring = false
	
	
	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()
	
	# Skip move if attacking
	if is_attacking:
		velocity = Vector2.ZERO
		return
	
	process_movement()
	process_animation()
	move_and_slide()

# Movement & Animation
func process_movement() -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_vector("left", "right", "up", "down")
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED * speed_multiplier
		last_direction = direction
		update_hitbox_offset()
	else:
		velocity = Vector2.ZERO

# Slow effects (e.g. José's ice zone). Stacks so overlapping zones are safe.
func add_slow() -> void:
	_slow_count += 1
	speed_multiplier = 0.45

func remove_slow() -> void:
	_slow_count = max(0, _slow_count - 1)
	if _slow_count == 0:
		speed_multiplier = 1.0
	
func process_animation() -> void:
	if is_attacking:
		return
	if velocity != Vector2.ZERO:
		play_animation("run", last_direction)
	else:
		play_animation("idle", last_direction)
	
func play_animation(prefix: String, dir: Vector2) -> void:
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_right")
	elif dir.y < 0:
		animated_sprite_2d.play(prefix + "_up")
	elif dir.y > 0:
		animated_sprite_2d.play(prefix + "_down")
		

# Attacking
func attack() -> void:
	is_attacking = true
	hitbox.monitoring = true
	swing_sword.play()
	play_animation("attack", last_direction)
	
	
func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		
# Hitbox 
func update_hitbox_offset() -> void:
	var x := hitbox_offset.x
	var y := hitbox_offset.y
	
	match last_direction:
		Vector2.LEFT:
			hitbox.position = Vector2(-x, y)
		Vector2.RIGHT:
			hitbox.position = Vector2(x, y)
		Vector2.UP:
			hitbox.position = Vector2(y, -x)
		Vector2.DOWN:
			hitbox.position = Vector2(-y, x)
	


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_attacking and body.is_in_group("enemies"):
		body.take_damage(strength, position)
		
