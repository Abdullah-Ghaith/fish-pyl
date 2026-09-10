extends Control

@export var ui_theme: Theme
## Debug: hand out points and open gates from the toolbar.
@export var show_debug_bar: bool = true

@export_group("Background")
## Flat fill behind the tree. Ignored when background_style is set.
@export var background_color: Color = Color(0.07, 0.08, 0.11)
## A StyleBox instead of the flat colour - a 9-slice frame, a gradient, etc.
@export var background_style: StyleBox
## Use the theme's own Panel look. Loses background_color/background_style.
@export var use_theme_panel: bool = false
## Drawn on top of the fill. Use STRETCH_TILE for a repeating pattern.
@export var background_texture: Texture2D
@export var background_stretch: TextureRect.StretchMode = \
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
## NEAREST keeps pixel art crisp; LINEAR smooths a painted backdrop.
@export var background_filter: CanvasItem.TextureFilter = \
		CanvasItem.TEXTURE_FILTER_NEAREST
## Tint and fade the texture without editing the file.
@export var background_modulate: Color = Color.WHITE
## Dropped on the backdrop, so a shader can animate it - caustics, parallax,
## drifting clouds. Lands on the texture layer when there is one.
@export var background_material: Material

var _view: SkillTreeView
var _wallet_label: Label
var _log: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ui_theme != null:
		theme = ui_theme

	_build_background()

	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -56.0   # keep the tree out from under the toolbar

	# EXPAND makes the ScrollContainer stretch this to the viewport so it has
	# room to centre in; FILL is separately required or the rect is discarded.
	# When the tree is larger than the window, the CenterContainer's minimum
	# size takes over and scrolling engages instead.
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)

	_view = SkillTreeView.new()
	_view.tree = Progression.tree
	centre.add_child(_view)

	_build_bar()

	if Progression.state == null:
		_log.text = "Progression has no tree - check Progression.TREE_PATH."
		return

	# The screen borrows the long-lived state; it never owns one.
	_view.state = Progression.state
	_view.node_purchased.connect(_on_purchased)
	_view.purchase_rejected.connect(_on_rejected)
	Progression.wallet_changed.connect(_refresh_wallet)
	Progression.achievement_unlocked.connect(_on_achievement)
	_refresh_wallet()


## Fill, then an optional texture on top, then an optional shader on whichever
## of those is frontmost. Both layers ignore the mouse so clicks reach the tree.
func _build_background() -> void:
	var fill: Control
	if use_theme_panel or background_style != null:
		var panel := Panel.new()
		if background_style != null:
			panel.add_theme_stylebox_override(&"panel", background_style)
		fill = panel
	else:
		var rect := ColorRect.new()
		rect.color = background_color
		fill = rect
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if background_texture == null:
		fill.material = background_material
		return

	var tex := TextureRect.new()
	tex.texture = background_texture
	tex.stretch_mode = background_stretch
	# Without IGNORE_SIZE the rect refuses to shrink below the image size and
	# a large backdrop would force the whole screen wider.
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.texture_filter = background_filter
	# TILE samples outside 0..1, which needs repeat switched on explicitly.
	if background_stretch == TextureRect.STRETCH_TILE:
		tex.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tex.modulate = background_modulate
	tex.material = background_material
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex)
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -48.0
	bar.offset_bottom = -12.0

	_wallet_label = Label.new()
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_wallet_label)

	if show_debug_bar:
		var give := Button.new()
		give.text = "+10 SP"
		give.pressed.connect(func() -> void:
				Progression.add_currency(&"skill_points", 10))
		bar.add_child(give)

		var gate := Button.new()
		gate.text = "Open gates"
		gate.pressed.connect(_open_all_gates)
		bar.add_child(gate)

		var reset := Button.new()
		reset.text = "Reset"
		reset.pressed.connect(func() -> void:
				Progression.reset_all()
				_log.text = "Reset.")
		bar.add_child(reset)

	_log = Label.new()
	_log.text = "Click a node to buy it."
	_log.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_log)


func _refresh_wallet() -> void:
	# Affordability lives in the wallet, not in the tree's state, so the nodes
	# have to be told when it moves or they stay dimmed after a payday.
	if _view != null:
		_view.refresh()
	var sp: int = Progression.balance(&"skill_points")
	var gold: int = Progression.balance(&"gold")
	_wallet_label.text = "SP %d    Gold %d" % [sp, gold]


func _open_all_gates() -> void:
	for c in Progression.tree.connections:
		if c != null and c.lock != null:
			Progression.unlock_achievement(c.lock.id)


func _on_purchased(n: SkillNodeData, rank: int) -> void:
	# stats has already recomputed by now - state.changed fires first.
	var upgrade := n.payload as SkillUpgrade
	var effect: String = "  ->  %s" % upgrade.describe() if upgrade != null else ""
	_log.text = "%s rank %d%s" % [n.label(), rank, effect]


func _on_rejected(n: SkillNodeData, reason: String) -> void:
	_log.text = "%s - %s" % [n.label(), reason]


func _on_achievement(id: StringName) -> void:
	_log.text = "Achievement: %s" % id
