@tool
class_name SkillLockControl extends Control
## One gate badge on a connection. A real Control rather than a draw call on
## the link layer, purely so it can be hovered - a lock that does not say what
## it is waiting on reads as a bug.
##
## SkillTreeView creates one per locked connection, sized to the badge's clear
## radius and centred on the link's midpoint.

var lock: SkillLock
var style: SkillTreeStyle
var is_open: bool = false
## func(lock: SkillLock) -> String, set by SkillTreeView.
var tooltip_provider: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	queue_redraw()


func _draw() -> void:
	if style == null or lock == null:
		return
	style.draw_lock(self, size * 0.5, is_open, lock.icon)


func _get_tooltip(_at_position: Vector2) -> String:
	if tooltip_provider.is_valid() and lock != null:
		return str(tooltip_provider.call(lock))
	return tooltip_text


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	return SkillTooltip.build(style, for_text)
