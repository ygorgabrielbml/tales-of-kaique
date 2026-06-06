extends Node2D

# --- Room layout (in tiles, 16px each; the TileMapLayers are scaled 4x in the scene) ---
const ROOM_W: int = 16
const ROOM_H: int = 10

const FLOOR_SRC: int = 0
const FLOOR_ATLAS: Vector2i = Vector2i(8, 4)

const WALL_SRC: int = 1
const WALL_TL: Vector2i = Vector2i(0, 6)
const WALL_T: Vector2i = Vector2i(2, 6)
const WALL_TR: Vector2i = Vector2i(4, 6)
const WALL_L: Vector2i = Vector2i(0, 8)
const WALL_R: Vector2i = Vector2i(4, 8)
const WALL_BL: Vector2i = Vector2i(0, 10)
const WALL_B: Vector2i = Vector2i(2, 10)
const WALL_BR: Vector2i = Vector2i(4, 10)

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $Walls
@onready var chest_area: Area2D = $Chest/InteractArea
@onready var hint_panel: PanelContainer = $Tutorial/HintPanel
@onready var hint_label: Label = $Tutorial/HintPanel/HintLabel

var _moved: bool = false
var _near_chest: bool = false
var _chest_opened: bool = false
var _message_active: bool = false

func _ready() -> void:
	_paint_room()
	chest_area.body_entered.connect(_on_chest_body_entered)
	chest_area.body_exited.connect(_on_chest_body_exited)
	_update_hint()

func _process(_delta: float) -> void:
	# Dismiss the movement tip once the player actually moves.
	if not _moved and Input.get_vector("left", "right", "up", "down") != Vector2.ZERO:
		_moved = true
		_update_hint()
	# Interaction with the chest.
	if _near_chest and not _chest_opened and Input.is_action_just_pressed("interact"):
		_open_chest()

# --- Tilemap painting ---

func _paint_room() -> void:
	for y in ROOM_H:
		for x in ROOM_W:
			floor_layer.set_cell(Vector2i(x, y), FLOOR_SRC, FLOOR_ATLAS)
			var wall_atlas := _wall_atlas_for(x, y)
			if wall_atlas != Vector2i(-1, -1):
				walls_layer.set_cell(Vector2i(x, y), WALL_SRC, wall_atlas)

func _wall_atlas_for(x: int, y: int) -> Vector2i:
	var left := x == 0
	var right := x == ROOM_W - 1
	var top := y == 0
	var bottom := y == ROOM_H - 1
	if top and left: return WALL_TL
	if top and right: return WALL_TR
	if bottom and left: return WALL_BL
	if bottom and right: return WALL_BR
	if top: return WALL_T
	if bottom: return WALL_B
	if left: return WALL_L
	if right: return WALL_R
	return Vector2i(-1, -1)

# --- Contextual hints ---

func _update_hint() -> void:
	if _message_active:
		return
	if _near_chest and not _chest_opened:
		_show_hint("Pressione E para interagir com o baú")
	elif not _moved:
		_show_hint("Use WASD ou as setas do teclado para se mover")
	else:
		_hide_hint()

func _show_hint(text: String) -> void:
	hint_label.text = text
	if not hint_panel.visible:
		hint_panel.visible = true
		hint_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(hint_panel, "modulate:a", 1.0, 0.2)

func _hide_hint() -> void:
	if not hint_panel.visible:
		return
	var tween := create_tween()
	tween.tween_property(hint_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): hint_panel.visible = false)

# --- Chest interaction (demonstrates the core loop) ---

func _on_chest_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_chest = true
		_update_hint()

func _on_chest_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_chest = false
		_update_hint()

func _open_chest() -> void:
	_chest_opened = true
	GameState.add_gold(50)
	GameState.add_item("Troféu", "res://assets/ninja_pack/Items/Treasure/GoldCup.png")
	if GameState.objectives.size() > 1:
		GameState.complete_objective(1)
	_flash_message("Você abriu o baú! +50 de ouro")

func _flash_message(text: String) -> void:
	_message_active = true
	_show_hint(text)
	await get_tree().create_timer(3.0).timeout
	_message_active = false
	_update_hint()
