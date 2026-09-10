@tool
class_name SkillTreeView extends Control
## Renders a SkillTreeResource at runtime, and previews it live in the editor.
##
## Drop it in a scene, assign `tree`, and it lays itself out. Assign a
## SkillTreeState to make it interactive; without one it renders read-only,
## which is what the @tool preview uses.
##
## Draw order is three layers of children, so nothing ever covers the thing it
## should sit behind: the anchors are drawn by this Control, then a link layer,
## then a lock layer, then one Control per node on top. The link layer is its
## own CanvasItem so `style.link_material` lands on the links *only*.

signal node_activated(data: SkillNodeData)
signal node_purchased(data: SkillNodeData, rank: int)
signal purchase_rejected(data: SkillNodeData, reason: String)

@export var tree: SkillTreeResource:
	set(v):
		tree = v
		_rebuild()
## Overrides tree.style, so one tree can be shown in two skins.
@export var style_override: SkillTreeStyle:
	set(v):
		style_override = v
		_rebuild()
## Blank space kept around the grid.
@export var padding: Vector2 = Vector2(40, 40):
	set(v):
		padding = v
		_rebuild()
## Clicking an available node buys it. Turn off for a read-only display.
@export var purchase_on_click: bool = true
## Lay out only the part of the grid that holds nodes, dropping empty rows and
## columns around them. A tree authored in one corner of a big grid then sizes
## to what it contains, which is what lets a CenterContainer actually centre
## it. The editor canvas always shows the whole grid - you need the empty
## anchors there to place nodes on.
@export var crop_to_used_cells: bool = true:
	set(v):
		crop_to_used_cells = v
		_rebuild()

var state: SkillTreeState:
	set(v):
		# Drop every connection to the outgoing state, not just `changed` - a
		# swapped-out state would otherwise keep firing purchases at this view.
		if state != null:
			if state.changed.is_connected(refresh):
				state.changed.disconnect(refresh)
			if state.purchased.is_connected(_on_purchased):
				state.purchased.disconnect(_on_purchased)
			if state.purchase_failed.is_connected(_on_failed):
				state.purchase_failed.disconnect(_on_failed)
		state = v
		if state != null:
			state.changed.connect(refresh)
			state.purchased.connect(_on_purchased)
			state.purchase_failed.connect(_on_failed)
		refresh()

var _controls: Dictionary = {}   # StringName -> SkillNodeControl
var _fallback_style: SkillTreeStyle
var _link_layer: Control
var _lock_layer: Control
## Top-left cell the layout is measured from. Vector2i.ZERO unless cropping.
var _origin_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_rebuild()


func active_style() -> SkillTreeStyle:
	if style_override != null:
		return style_override
	if tree != null and tree.style != null:
		return tree.style
	if _fallback_style == null:
		_fallback_style = SkillTreeStyle.new()
	return _fallback_style


## Recreate node Controls. Call after changing the tree's structure.
func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in _controls.values():
		if is_instance_valid(c):
			c.queue_free()
	_controls.clear()
	_ensure_layers()

	var st: SkillTreeStyle = active_style()
	theme = st.ui_theme
	_link_layer.material = st.link_material
	# Marching dashes need a redraw per frame. Never in the editor: authoring
	# should not spin the CPU.
	set_process(not Engine.is_editor_hint() and st.link_dash_speed != 0.0
			and not st.link_shader_strip)

	if tree == null:
		custom_minimum_size = Vector2.ZERO
		queue_redraw()
		return

	var used: Rect2i = tree.used_cell_rect()
	_origin_cell = used.position if crop_to_used_cells else Vector2i.ZERO
	var span: Vector2 = Vector2(used.size) * tree.cell_size if crop_to_used_cells \
			else tree.content_size()
	custom_minimum_size = span + st.node_size + padding * 2.0

	for n in tree.nodes:
		if n == null:
			continue
		var ctrl := SkillNodeControl.new()
		ctrl.data = n
		ctrl.style = st
		ctrl.size = st.node_size
		ctrl.position = node_origin(n)
		# Recomputed on every hover rather than cached, so cost, affordability
		# and rank are never stale - the wallet can change without the tree's
		# state emitting anything.
		ctrl.tooltip_provider = _tooltip_for
		ctrl.tooltip_text = _tooltip_for(n)
		if st.node_material != null:
			ctrl.material = st.node_material
		ctrl.activated.connect(_on_node_activated)
		add_child(ctrl)
		_controls[n.id] = ctrl

	refresh()


## The link and lock layers exist only to own a draw order and a Material.
## They are created once, before any node Control, so they stay underneath.
func _ensure_layers() -> void:
	if _link_layer == null or not is_instance_valid(_link_layer):
		_link_layer = _make_layer(_draw_link_layer)
	if _lock_layer == null or not is_instance_valid(_lock_layer):
		_lock_layer = _make_layer(_draw_lock_layer)


func _make_layer(painter: Callable) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full rect matters: a Control is culled by its own rect rather than by
	# what it drew, so the layer has to cover the content it paints.
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Must not be deferred: draw_* calls are only legal inside the draw window.
	layer.draw.connect(painter)
	add_child(layer)
	return layer


func _process(_delta: float) -> void:
	# Defining _process auto-enables processing, so guard the editor here too.
	if Engine.is_editor_hint():
		return
	if _link_layer != null and is_instance_valid(_link_layer):
		_link_layer.queue_redraw()


## Where a grid anchor sits in this Control's coordinates. Nodes are centred
## on their anchor, which is why padding must be at least half a node.
func anchor_position(cell: Vector2i) -> Vector2:
	return padding + tree.cell_to_position(cell - _origin_cell)


func node_center(n: SkillNodeData) -> Vector2:
	return anchor_position(n.cell)


func node_origin(n: SkillNodeData) -> Vector2:
	return anchor_position(n.cell) - active_style().node_size * 0.5


## Re-evaluate every node's visual state without rebuilding Controls.
func refresh() -> void:
	if tree == null:
		return
	for n in tree.nodes:
		if n == null or not _controls.has(n.id):
			continue
		var ctrl: SkillNodeControl = _controls[n.id]
		if not is_instance_valid(ctrl):
			continue
		if state != null:
			ctrl.refresh(state.state_of(n), state.rank_of(n.id),
					state.can_afford(state.next_rank_costs(n)))
		else:
			ctrl.refresh(SkillTree.NodeState.AVAILABLE, 0, true)
	queue_redraw()
	if _link_layer != null and is_instance_valid(_link_layer):
		_link_layer.queue_redraw()
	if _lock_layer != null and is_instance_valid(_lock_layer):
		_lock_layer.queue_redraw()


func _draw() -> void:
	if tree == null:
		return
	var st: SkillTreeStyle = active_style()
	if st.show_anchors_in_game or Engine.is_editor_hint():
		_draw_anchors(st)


func _draw_anchors(st: SkillTreeStyle) -> void:
	var from := Vector2i.ZERO
	var to: Vector2i = tree.grid_size
	if crop_to_used_cells:
		var used: Rect2i = tree.used_cell_rect()
		from = used.position
		to = used.position + used.size + Vector2i.ONE
	for x in range(from.x, to.x):
		for y in range(from.y, to.y):
			var p: Vector2 = anchor_position(Vector2i(x, y))
			if st.anchor_texture != null:
				var s: Vector2 = st.anchor_texture.get_size()
				draw_texture_rect(st.anchor_texture,
						Rect2(p - s * 0.5, s), false, st.anchor_color)
			else:
				draw_arc(p, st.anchor_radius, 0.0, TAU, 20, st.anchor_color,
						st.anchor_line_width, true)


# --- link layer ---------------------------------------------------------------

func _draw_link_layer() -> void:
	if tree == null:
		return
	var st: SkillTreeStyle = active_style()
	var phase: float = 0.0
	if st.link_dash_speed != 0.0 and not Engine.is_editor_hint():
		phase = fmod(float(Time.get_ticks_msec()) * 0.001 * st.link_dash_speed,
				st.dash_period())

	for c in tree.connections:
		if c == null:
			continue
		var a: SkillNodeData = tree.find_node(c.from_id)
		var b: SkillNodeData = tree.find_node(c.to_id)
		if a == null or b == null:
			continue
		_draw_link(st, c, node_center(a), node_center(b), phase)


func _draw_link(st: SkillTreeStyle, c: SkillConnection, a: Vector2, b: Vector2,
		phase: float) -> void:
	var satisfied: bool = state != null and state.is_link_satisfied(c)
	var from_owned: bool = state != null and state.is_owned(c.from_id)
	var gated: bool = from_owned and c.lock != null \
			and not state.is_lock_open(c.lock.id)
	var col: Color = st.link_color(satisfied, gated, from_owned or state == null)

	if st.link_shader_strip and st.link_material != null:
		# The shader owns the dashes, so hand it one unbroken quad.
		st.draw_link_strip(_link_layer, a, b, col, st.link_width)
		return

	var mid: Vector2 = (a + b) * 0.5
	var hole: float = st.lock_clear_radius() if c.lock != null else 0.0
	if st.link_outline_width > 0.0:
		st.draw_link_dashes(_link_layer, a, b, st.link_outline_color,
				st.link_width + st.link_outline_width * 2.0, phase, mid, hole)
	st.draw_link_dashes(_link_layer, a, b, col, st.link_width, phase, mid, hole)


# --- lock layer ---------------------------------------------------------------

func _draw_lock_layer() -> void:
	if tree == null:
		return
	var st: SkillTreeStyle = active_style()
	for c in tree.connections:
		if c == null or c.lock == null:
			continue
		var a: SkillNodeData = tree.find_node(c.from_id)
		var b: SkillNodeData = tree.find_node(c.to_id)
		if a == null or b == null:
			continue
		var open: bool = state != null and state.is_lock_open(c.lock.id)
		st.draw_lock(_lock_layer, (node_center(a) + node_center(b)) * 0.5,
				open, c.lock.icon)


# --- interaction --------------------------------------------------------------

## BBCode, rendered by SkillNodeControl._make_custom_tooltip. A node's
## `description` is passed through verbatim, so authors can put [rainbow],
## [wave], [tornado] and friends around keywords.
func _tooltip_for(n: SkillNodeData) -> String:
	var st: SkillTreeStyle = active_style()
	var rank: int = state.rank_of(n.id) if state != null else 0
	var lines: PackedStringArray = []

	var head: String = "[b]%s[/b]" % n.label()
	if n.max_rank > 1:
		head += "   [color=#%s]rank %d / %d[/color]" % [
				st.tooltip_dim_color.to_html(false), rank, n.max_rank]
	lines.append(head)

	if n.description != "":
		lines.append(n.description)

	# The addon never interprets `payload` - but if a payload can describe
	# itself, the tooltip says what the skill actually does. That one method
	# name is the entire contract; no payload type is imported here.
	if n.payload != null and n.payload.has_method(&"describe"):
		var effect: String = str(n.payload.call(&"describe"))
		if effect != "":
			lines.append("[color=#%s]%s[/color]" % [
					st.tooltip_effect_color.to_html(false), effect])

	var reason: String = state.blocked_reason(n) if state != null else ""
	if reason != "":
		lines.append("[color=#%s]%s[/color]" % [
				st.tooltip_warn_color.to_html(false), reason])
	else:
		lines.append("[color=#%s]Cost: %s[/color]" % [
				st.tooltip_cost_color.to_html(false), n.describe_costs(rank + 1)])

	return "\n".join(lines)


func _on_node_activated(n: SkillNodeData) -> void:
	node_activated.emit(n)
	if purchase_on_click and state != null:
		state.purchase(n)


func _on_purchased(n: SkillNodeData, rank: int) -> void:
	node_purchased.emit(n, rank)


func _on_failed(n: SkillNodeData, reason: String) -> void:
	purchase_rejected.emit(n, reason)
