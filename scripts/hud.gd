extends CanvasLayer

# Status
var _health_bar: ProgressBar
var _health_label: Label
var _gold_label: Label

# Hotbar (bottom-center, 4 quick slots)
var _hotbar_icons: Array[TextureRect] = []

# Objectives phone (bottom-right, toggle C)
var _phone_panel: Control
var _objectives_container: VBoxContainer

# Full inventory window (center, toggle I)
var _inventory_window: Control
var _inventory_grid_icons: Array[TextureRect] = []

const HOTBAR_SLOTS: int = 4
const HOTBAR_SLOT_SIZE: int = 44
const INV_COLS: int = 4
const INV_ROWS: int = 4
const INV_SLOT_SIZE: int = 64

func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()
	_find_player.call_deferred()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_C:
			_phone_panel.visible = not _phone_panel.visible
			get_viewport().set_input_as_handled()
		KEY_I:
			_inventory_window.visible = not _inventory_window.visible
			if _inventory_window.visible:
				_refresh_inventory_grid()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _inventory_window.visible:
				_inventory_window.visible = false
				get_viewport().set_input_as_handled()

func _connect_signals() -> void:
	GameState.health_changed.connect(_on_health_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.objective_added.connect(_on_objective_added)
	GameState.objective_completed.connect(_on_objective_completed)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		_on_health_changed(p.health, p.MAX_HEALTH)

func _build_ui() -> void:
	var root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status_bar(root)
	_build_hotbar(root)
	_build_key_hints(root)
	_build_phone_widget(root)
	_build_inventory_window(root)

# Utility: build a StyleBoxFlat with common settings
func _style(bg: Color, radius: int = 5, bcolor: Color = Color.TRANSPARENT,
		bwidth: int = 0, pad: int = 6) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	if bwidth > 0:
		s.border_color = bcolor
		s.border_width_left = bwidth
		s.border_width_right = bwidth
		s.border_width_top = bwidth
		s.border_width_bottom = bwidth
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

# --- Status bar (top-left) ---

func _build_status_bar(root: Control) -> void:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.anchor_left = 0.0
	col.anchor_top = 0.0
	col.anchor_right = 0.0
	col.anchor_bottom = 0.0
	col.offset_left = 10
	col.offset_top = 10
	col.grow_horizontal = Control.GROW_DIRECTION_END
	col.grow_vertical = Control.GROW_DIRECTION_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	_build_health_panel(col)
	_build_gold_panel(col)

func _build_health_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.65)))
	parent.add_child(panel)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var heart = TextureRect.new()
	heart.texture = load("res://assets/ninja_pack/Ui/Receptacle/IconHeart.png")
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.custom_minimum_size = Vector2(24, 24)
	row.add_child(heart)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.custom_minimum_size = Vector2(140, 0)
	row.add_child(col)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(140, 14)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_bg = _style(Color(0.28, 0.04, 0.04), 3)
	bar_bg.content_margin_left = 0
	bar_bg.content_margin_right = 0
	bar_bg.content_margin_top = 0
	bar_bg.content_margin_bottom = 0
	_health_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = _style(Color(0.85, 0.12, 0.12), 3)
	bar_fill.content_margin_left = 0
	bar_fill.content_margin_right = 0
	bar_fill.content_margin_top = 0
	bar_fill.content_margin_bottom = 0
	_health_bar.add_theme_stylebox_override("fill", bar_fill)
	col.add_child(_health_bar)

	_health_label = Label.new()
	_health_label.text = "100 / 100"
	_health_label.add_theme_font_size_override("font_size", 14)
	_health_label.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(_health_label)

func _build_gold_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0.65)))
	parent.add_child(panel)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var coin = TextureRect.new()
	coin.texture = load("res://assets/ninja_pack/Items/Treasure/GoldCoin.png")
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.custom_minimum_size = Vector2(22, 22)
	row.add_child(coin)

	_gold_label = Label.new()
	_gold_label.text = "0"
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_gold_label.custom_minimum_size = Vector2(60, 0)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_gold_label)

# --- Hotbar (bottom-center) ---

func _build_hotbar(root: Control) -> void:
	const GAP = 4
	var total_w = float(HOTBAR_SLOTS * HOTBAR_SLOT_SIZE + (HOTBAR_SLOTS - 1) * GAP)

	var bar_root = Control.new()
	bar_root.anchor_left = 0.5
	bar_root.anchor_right = 0.5
	bar_root.anchor_top = 1.0
	bar_root.anchor_bottom = 1.0
	bar_root.offset_left = -total_w * 0.5
	bar_root.offset_right = total_w * 0.5
	bar_root.offset_top = -(HOTBAR_SLOT_SIZE + 10)
	bar_root.offset_bottom = -10
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_root)

	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(row)

	for i in HOTBAR_SLOTS:
		var slot = PanelContainer.new()
		slot.add_theme_stylebox_override("panel",
			_style(Color(0, 0, 0, 0.70), 5, Color(0.65, 0.55, 0.28, 0.85), 2, 4))
		slot.custom_minimum_size = Vector2(HOTBAR_SLOT_SIZE, HOTBAR_SLOT_SIZE)
		row.add_child(slot)

		var icon = TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_hotbar_icons.append(icon)

# --- Key hints (bottom-left) ---

func _build_key_hints(root: Control) -> void:
	var lbl = Label.new()
	lbl.text = "[C] Objetivos    [I] Inventário"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.85))
	lbl.anchor_left = 0.0
	lbl.anchor_right = 0.0
	lbl.anchor_top = 1.0
	lbl.anchor_bottom = 1.0
	lbl.offset_left = 10
	lbl.offset_top = -22
	lbl.offset_bottom = -4
	lbl.grow_horizontal = Control.GROW_DIRECTION_END
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)

# --- Objectives phone (bottom-right) ---

func _build_phone_widget(root: Control) -> void:
	var phone = PanelContainer.new()
	phone.add_theme_stylebox_override("panel",
		_style(Color(0.13, 0.13, 0.16), 22, Color(0.32, 0.32, 0.38), 4, 7))
	phone.anchor_left = 1.0
	phone.anchor_right = 1.0
	phone.anchor_top = 1.0
	phone.anchor_bottom = 1.0
	phone.offset_left = -234
	phone.offset_right = -12
	phone.offset_top = -404
	phone.offset_bottom = -12
	phone.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	phone.grow_vertical = Control.GROW_DIRECTION_BEGIN
	phone.visible = false
	phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_panel = phone
	root.add_child(phone)

	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	phone.add_child(body)

	# Notch
	var notch = PanelContainer.new()
	var notch_s = _style(Color(0.10, 0.10, 0.13), 0, Color.TRANSPARENT, 0, 5)
	notch_s.corner_radius_top_left = 16
	notch_s.corner_radius_top_right = 16
	notch.add_theme_stylebox_override("panel", notch_s)
	notch.custom_minimum_size = Vector2(0, 26)
	body.add_child(notch)

	var notch_center = CenterContainer.new()
	notch.add_child(notch_center)
	var speaker = Label.new()
	speaker.text = "· · ·"
	speaker.add_theme_font_size_override("font_size", 9)
	speaker.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	notch_center.add_child(speaker)

	# Screen
	var screen = PanelContainer.new()
	screen.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.09), 0, Color.TRANSPARENT, 0, 10))
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(screen)

	var screen_col = VBoxContainer.new()
	screen_col.add_theme_constant_override("separation", 8)
	screen.add_child(screen_col)

	var title = Label.new()
	title.text = "Objetivos"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_col.add_child(title)

	var sep = ColorRect.new()
	sep.color = Color(0.3, 0.25, 0.1, 0.7)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_col.add_child(sep)

	_objectives_container = VBoxContainer.new()
	_objectives_container.add_theme_constant_override("separation", 8)
	_objectives_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_col.add_child(_objectives_container)

	var close_hint = Label.new()
	close_hint.text = "[C] fechar"
	close_hint.add_theme_font_size_override("font_size", 11)
	close_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_col.add_child(close_hint)

	# Home button row
	var home_area = CenterContainer.new()
	home_area.custom_minimum_size = Vector2(0, 40)
	body.add_child(home_area)

	var home_dot = Label.new()
	home_dot.text = "○"
	home_dot.add_theme_font_size_override("font_size", 22)
	home_dot.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	home_area.add_child(home_dot)

# --- Full inventory window (center, hidden) ---

func _build_inventory_window(root: Control) -> void:
	_inventory_window = PanelContainer.new()
	_inventory_window.add_theme_stylebox_override("panel",
		_style(Color(0.07, 0.07, 0.10, 0.96), 8, Color(0.50, 0.45, 0.20, 0.90), 2, 14))
	_inventory_window.anchor_left = 0.5
	_inventory_window.anchor_right = 0.5
	_inventory_window.anchor_top = 0.5
	_inventory_window.anchor_bottom = 0.5
	_inventory_window.offset_left = -165
	_inventory_window.offset_right = 165
	_inventory_window.offset_top = -190
	_inventory_window.offset_bottom = 190
	_inventory_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_inventory_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_inventory_window.visible = false
	root.add_child(_inventory_window)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_inventory_window.add_child(col)

	# Header
	var header = HBoxContainer.new()
	col.add_child(header)

	var title = Label.new()
	title.text = "Inventário"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint = Label.new()
	hint.text = "[I] fechar"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(hint)

	var sep = ColorRect.new()
	sep.color = Color(0.40, 0.35, 0.15, 0.80)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sep)

	# Grid
	var grid = GridContainer.new()
	grid.columns = INV_COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)

	for i in INV_COLS * INV_ROWS:
		var slot = PanelContainer.new()
		slot.add_theme_stylebox_override("panel",
			_style(Color(0.04, 0.04, 0.07), 4, Color(0.30, 0.27, 0.12, 0.65), 1, 4))
		slot.custom_minimum_size = Vector2(INV_SLOT_SIZE, INV_SLOT_SIZE)
		grid.add_child(slot)

		var icon = TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_inventory_grid_icons.append(icon)

func _refresh_inventory_grid() -> void:
	for i in INV_COLS * INV_ROWS:
		if i < GameState.inventory.size():
			var icon_path: String = GameState.inventory[i].get("icon_path", "")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				_inventory_grid_icons[i].texture = load(icon_path)
			else:
				_inventory_grid_icons[i].texture = null
		else:
			_inventory_grid_icons[i].texture = null

# --- Signal handlers ---

func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [current, maximum]

func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = str(new_gold)

func _on_inventory_changed(slots: Array) -> void:
	for i in HOTBAR_SLOTS:
		if i < slots.size():
			var icon_path: String = slots[i].get("icon_path", "")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				_hotbar_icons[i].texture = load(icon_path)
			else:
				_hotbar_icons[i].texture = null
		else:
			_hotbar_icons[i].texture = null
	if _inventory_window.visible:
		_refresh_inventory_grid()

func _on_objective_added(index: int) -> void:
	var obj: Dictionary = GameState.objectives[index]
	var lbl = Label.new()
	lbl.name = "Obj" + str(index)
	lbl.text = ("✓  " if obj.completed else "•  ") + obj.text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color",
		Color(0.45, 0.9, 0.45) if obj.completed else Color(0.88, 0.88, 0.88))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(186, 0)
	_objectives_container.add_child(lbl)

func _on_objective_completed(index: int) -> void:
	if index < _objectives_container.get_child_count():
		var lbl := _objectives_container.get_child(index) as Label
		if lbl:
			lbl.text = "✓  " + GameState.objectives[index].text
			lbl.add_theme_color_override("font_color", Color(0.45, 0.9, 0.45))
