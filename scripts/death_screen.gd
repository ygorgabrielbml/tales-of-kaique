extends CanvasLayer

# Death sequence overlay. Three scripted beats, kept short:
#   1. the screen goes black with the red "MORREU HOJE" text and a white cross
#   2. the cross flips upside-down (inverts)
#   3. an 8-bit fire rises from the bottom and consumes the whole screen
#
# Self-contained: instance the scene, add it to the tree and it plays on _ready.
# Emits `finished` once the fire has covered everything.

signal finished

# Low-res fire grid; upscaled with nearest-neighbour for the chunky 8-bit look.
const FIRE_W: int = 96
const FIRE_H: int = 54
const FIRE_MAX: int = 36   # hottest palette index (white-yellow)

# --- Cross design -----------------------------------------------------------
# Edit this grid BY HAND to change the cross. Each string is one row; "X" is a
# white pixel and any other character (use ".") is transparent. All rows must be
# the same length. It is drawn tiny and scaled up (nearest filter) for the 8-bit
# look, so keep it small. Keep the shape vertically centred so the inversion
# flip looks symmetric. Tweak CROSS_SCALE below to change its size on screen.
const CROSS_PIXELS: PackedStringArray = [
	"...XXX...",
	"...XXX...",
	"...XXX...",
	"XXXXXXXXX",
	"XXXXXXXXX",
	"...XXX...",
	"...XXX...",
	"...XXX...",
	"...XXX...",
	"...XXX...",
	"...XXX...",
]
const CROSS_SCALE: float = 11.0

# Plays under the fire beat.
const FIRE_SOUND_PATH: String = "res://assets/sounds/fire_8bit.wav"

# Timing (seconds) — the whole thing is meant to be quick.
const FADE_IN: float = 0.6
const HOLD_1: float = 0.4
const FLIP: float = 0.5
const HOLD_2: float = 1.5    # pause after the flip so the player can read
const BURN: float = 1.3
const END_HOLD: float = 0.15

var _black: ColorRect
var _label: Label
var _cross: Node2D
var _fire_rect: TextureRect
var _fire_tex: ImageTexture

var _pixels: PackedByteArray = PackedByteArray()   # fire intensity grid, 0..FIRE_MAX
var _rgba: PackedByteArray = PackedByteArray()      # output pixels for the texture
var _palette: PackedColorArray = PackedColorArray()

var _burning: bool = false
var _burn_t: float = 0.0


func _ready() -> void:
	_build()
	_play()


func _build() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = vp * 0.5

	# 1. Full-screen black backdrop.
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	# Red "MORREU HOJE" text, sitting left of centre like the reference.
	_label = Label.new()
	_label.text = "MORREU HOJE"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 52)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.size = Vector2(420, 70)
	_label.position = center + Vector2(-90, 0) - _label.size * 0.5
	add_child(_label)

	# White cross to the right of the text. Drawn as a single pixel-art texture
	# (chunky 8-bit look) on a Sprite2D, wrapped in a Node2D so the whole thing
	# can be flipped on Y to invert it without changing its size.
	_cross = Node2D.new()
	_cross.position = center + Vector2(250, 0)
	add_child(_cross)

	var cross_sprite := Sprite2D.new()
	cross_sprite.texture = _make_cross_texture()
	cross_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cross_sprite.scale = Vector2(CROSS_SCALE, CROSS_SCALE)
	_cross.add_child(cross_sprite)

	# 3. Fire layer on top of everything (transparent until it ignites).
	_fire_rect = TextureRect.new()
	_fire_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fire_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_fire_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fire_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fire_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fire_rect)

	_build_palette()
	_pixels.resize(FIRE_W * FIRE_H)
	_pixels.fill(0)
	_rgba.resize(FIRE_W * FIRE_H * 4)
	set_process(false)


# Builds the cross texture from the hand-editable CROSS_PIXELS grid above.
func _make_cross_texture() -> ImageTexture:
	var h: int = CROSS_PIXELS.size()
	var w: int = CROSS_PIXELS[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var row: String = CROSS_PIXELS[y]
		for x in range(mini(w, row.length())):
			if row[x] == "X":
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


# Black -> dark red -> red -> orange -> yellow -> white. Index 0 is transparent
# so the black backdrop shows through wherever the fire has not reached.
func _build_palette() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.08, 0.30, 0.55, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(0, 0, 0, 0),
		Color(0.12, 0.02, 0.02, 1),
		Color(0.6, 0.06, 0.03, 1),
		Color(0.92, 0.3, 0.05, 1),
		Color(1.0, 0.66, 0.1, 1),
		Color(1.0, 0.95, 0.7, 1),
	])
	for i in range(FIRE_MAX + 1):
		_palette.append(grad.sample(float(i) / float(FIRE_MAX)))


func _play() -> void:
	_black.modulate.a = 0.0
	_label.modulate.a = 0.0
	_cross.modulate.a = 0.0

	# Beat 1: fade in the black screen, text and cross.
	var t1 := create_tween()
	t1.tween_property(_black, "modulate:a", 1.0, FADE_IN)
	t1.parallel().tween_property(_label, "modulate:a", 1.0, FADE_IN)
	t1.parallel().tween_property(_cross, "modulate:a", 1.0, FADE_IN)
	await t1.finished
	await get_tree().create_timer(HOLD_1).timeout

	# Beat 2: invert the cross (flip vertically) while the white text and cross
	# bleed to red.
	var red := Color(0.85, 0.1, 0.08, 1.0)
	var t2 := create_tween()
	t2.tween_property(_cross, "scale:y", -1.0, FLIP) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	t2.parallel().tween_property(_label, "modulate", red, FLIP)
	t2.parallel().tween_property(_cross, "modulate", red, FLIP)
	await t2.finished
	await get_tree().create_timer(HOLD_2).timeout

	# Beat 3: ignite. The fire rises and swallows the screen, with crackle.
	_play_fire_sound()
	_burning = true
	_burn_t = 0.0
	set_process(true)
	await get_tree().create_timer(BURN + END_HOLD).timeout

	finished.emit()
	_show_menu()


func _play_fire_sound() -> void:
	var stream: AudioStream = load(FIRE_SOUND_PATH)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -9.0
	add_child(player)
	player.play()


# Transition menu shown once the fire has consumed the screen: revive (reload
# the scene the player died in) or quit the game.
func _show_menu() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	# Dim the fire behind the menu so the options stay readable.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	var title := Label.new()
	title.text = "MORREU HOJE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.85, 0.1, 0.08))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	var revive := Button.new()
	revive.text = "RENASCER"
	revive.custom_minimum_size = Vector2(260, 56)
	revive.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	revive.pressed.connect(_on_revive)
	box.add_child(revive)

	var quit := Button.new()
	quit.text = "FECHAR O JOGO"
	quit.custom_minimum_size = Vector2(260, 56)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(_on_quit)
	box.add_child(quit)

	revive.grab_focus()

	# Fade the menu in.
	dim.modulate.a = 0.0
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.3)


func _on_revive() -> void:
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().quit()


func _process(delta: float) -> void:
	if not _burning:
		return

	_burn_t += delta
	var frac: float = clampf(_burn_t / BURN, 0.0, 1.0)

	# A solid wall of fire (the "source") climbs from the bottom row up to the
	# top as `frac` goes 0 -> 1, so the flames consume the whole screen.
	var front: int = int(round(lerpf(float(FIRE_H), 0.0, frac)))
	var src_top: int = mini(front, FIRE_H - 1)
	for y in range(src_top, FIRE_H):
		var row: int = y * FIRE_W
		for x in range(FIRE_W):
			_pixels[row + x] = FIRE_MAX

	_spread()
	_render()


# Classic "doom fire" propagation: each pixel cools a little and drifts upward
# with a touch of random horizontal wind.
func _spread() -> void:
	for x in range(FIRE_W):
		for y in range(1, FIRE_H):
			var below: int = y * FIRE_W + x
			var rand: int = randi() % 3            # 0, 1, 2
			var dst_x: int = clampi(x - rand + 1, 0, FIRE_W - 1)
			var dst: int = (y - 1) * FIRE_W + dst_x
			_pixels[dst] = maxi(0, int(_pixels[below]) - (rand & 1))


func _render() -> void:
	for i in range(FIRE_W * FIRE_H):
		var c: Color = _palette[_pixels[i]]
		var o: int = i * 4
		_rgba[o] = int(c.r * 255.0)
		_rgba[o + 1] = int(c.g * 255.0)
		_rgba[o + 2] = int(c.b * 255.0)
		_rgba[o + 3] = int(c.a * 255.0)

	var img := Image.create_from_data(FIRE_W, FIRE_H, false, Image.FORMAT_RGBA8, _rgba)
	if _fire_tex == null:
		_fire_tex = ImageTexture.create_from_image(img)
		_fire_rect.texture = _fire_tex
	else:
		_fire_tex.update(img)
