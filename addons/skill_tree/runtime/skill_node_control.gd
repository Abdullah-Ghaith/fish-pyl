@tool
class_name SkillNodeControl extends Control
## One node's Control, created by SkillTreeView. A real Control rather than a
## draw call so it gets hover, focus, tooltips and a per-node Material for free.

signal activated(data: SkillNodeData)

var data: SkillNodeData
var style: SkillTreeStyle
var node_state: SkillTree.NodeState = SkillTree.NodeState.LOCKED
var affordable: bool = true
var rank: int = 0

## func(data: SkillNodeData) -> String, set by SkillTreeView. Called on every
## hover so the tooltip is always current.
var tooltip_provider: Callable = Callable()

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())


func refresh(new_state: SkillTree.NodeState, new_rank: int, is_affordable: bool) -> void:
	node_state = new_state
	rank = new_rank
	affordable = is_affordable
	# modulate rather than a draw-time tint, so the StyleBox dims too.
	modulate = style.unaffordable_modulate if (style != null \
			and new_state == SkillTree.NodeState.AVAILABLE and not is_affordable) \
			else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if style == null or data == null:
		return

	var rect := Rect2(Vector2.ZERO, size)

	var box: StyleBox = style.box_for(node_state)
	if box != null:
		draw_style_box(box, rect)

	if data.icon != null:
		var m: float = style.icon_margin
		draw_texture_rect(data.icon,
				Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0), false)

	if data.max_rank > 1 and style.rank_pip_radius > 0.0:
		_draw_rank_pips()

	if _hovered and style.node_hover_overlay != null:
		draw_style_box(style.node_hover_overlay, rect)


func _draw_rank_pips() -> void:
	var r: float = style.rank_pip_radius
	var gap: float = r * 3.0
	var total: int = data.max_rank
	var start_x: float = size.x * 0.5 - (float(total - 1) * gap) * 0.5
	var y: float = size.y - r - 2.0
	for i in total:
		var filled: bool = i < rank
		draw_circle(Vector2(start_x + float(i) * gap, y), r,
				style.rank_pip_filled if filled else style.rank_pip_empty)


## Built fresh each hover instead of read from a cached `tooltip_text`.
## Returning non-empty here also stops Godot walking up the parent chain
## looking for a tooltip owner.
func _get_tooltip(_at_position: Vector2) -> String:
	if tooltip_provider.is_valid() and data != null:
		return str(tooltip_provider.call(data))
	return tooltip_text


## A BBCode tooltip, so a skill's description can carry [rainbow], [wave],
## [tornado], [shake] and [pulse] around the words worth noticing. The text is
## built by SkillTreeView._tooltip_for().
##
## Godot frees the returned node when the tooltip closes, so this always
## returns a fresh one - never a cached instance.
func _make_custom_tooltip(for_text: String) -> Object:
	# Called even when tooltip_text is empty. Returning null is how you say
	# "then show nothing", which is what empty should mean.
	if for_text.is_empty():
		return null

	var width: float = style.tooltip_width if style != null else 300.0
	var pad: int = int(style.tooltip_padding) if style != null else 12

	var panel := PanelContainer.new()
	# So an animated tooltip keeps animating if the game pauses behind it.
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if style != null and style.tooltip_panel != null:
		panel.add_theme_stylebox_override(&"panel", style.tooltip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", pad)
	margin.add_theme_constant_override(&"margin_right", pad)
	margin.add_theme_constant_override(&"margin_top", pad)
	margin.add_theme_constant_override(&"margin_bottom", pad)
	panel.add_child(margin)

	var label := RichTextLabel.new()
	# bbcode_enabled must be set before `text`, or the tags are shown literally.
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# See SkillTreeStyle.tooltip_width for why this is not optional.
	label.custom_minimum_size = Vector2(width, 0.0)
	# Effects that move glyphs would otherwise be cut off at the text bounds.
	label.clip_contents = false
	if style != null:
		label.add_theme_color_override(&"default_color", style.tooltip_text_color)
	label.text = for_text
	margin.add_child(label)

	return panel


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			activated.emit(data)
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		activated.emit(data)
