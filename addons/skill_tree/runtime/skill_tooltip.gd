@tool
class_name SkillTooltip extends PanelContainer
## The BBCode tooltip panel, shared by skill nodes and lock badges.
##
## Godot wraps a custom tooltip in its own PopupPanel, and that popup has a
## background of its own: theme type "TooltipPanel", which the default theme
## sets to 50% black with 8/2/8/2 content margins. That grey gutter around a
## custom panel is the popup showing through, not your own styling.
##
## Theme only propagates downward, so the override has to be applied to the
## parent from inside the child. NOTIFICATION_ENTER_TREE fires while the popup
## is already in the tree but before it measures itself, so this lands in time
## to change the popup's size as well as its colour.

var label: RichTextLabel
var max_width: float = 300.0
var strip_popup_background: bool = true


## The whole tooltip, ready to return from _make_custom_tooltip. Always build a
## fresh one - Godot frees it when the tooltip closes.
static func build(style: SkillTreeStyle, text: String) -> SkillTooltip:
	var pad: int = int(style.tooltip_padding) if style != null else 12

	var panel := SkillTooltip.new()
	panel.max_width = style.tooltip_width if style != null else 300.0
	panel.strip_popup_background = \
			style.tooltip_hide_popup_background if style != null else true
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

	var rich := RichTextLabel.new()
	# bbcode_enabled must be set before `text`, or the tags are shown literally.
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Effects that move glyphs would otherwise be cut off at the text bounds.
	rich.clip_contents = false
	if style != null:
		rich.add_theme_color_override(&"default_color", style.tooltip_text_color)
	rich.text = text
	margin.add_child(rich)

	# Width is settled in _fit_width(), once there is a theme to measure against.
	panel.label = rich
	return panel


func _notification(what: int) -> void:
	if what != NOTIFICATION_ENTER_TREE:
		return
	if strip_popup_background:
		var popup := get_parent() as PopupPanel
		if popup != null:
			popup.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_fit_width()


## With autowrap on, RichTextLabel reports a 1px minimum width, so a wrap width
## set as custom_minimum_size acts as a *fixed* width - a three-line tooltip
## would still be 300px wide. Measure the text and only clamp when it is
## genuinely long enough to need wrapping.
func _fit_width() -> void:
	if label == null:
		return
	var font: Font = label.get_theme_font(&"normal_font")
	if font == null:
		label.custom_minimum_size = Vector2(max_width, 0.0)
		return
	var fs: int = label.get_theme_font_size(&"normal_font_size")
	var widest: float = 0.0
	# get_parsed_text() is the text with the BBCode tags removed.
	for line in label.get_parsed_text().split("\n"):
		widest = maxf(widest,
				font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	# Bold runs measure a little wider than the normal font reports.
	label.custom_minimum_size = Vector2(minf(widest + 12.0, max_width), 0.0)
