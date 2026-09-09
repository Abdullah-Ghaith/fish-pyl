@tool
extends Control
## The authoring surface. Draws the anchor grid, the nodes on it and the links
## between them, and turns mouse gestures into undoable edits.
##
## Property editing is deliberately NOT reimplemented here - selecting anything
## hands it to Godot's own Inspector via EditorInterface.edit_resource, so you
## get full fidelity on icons, cost arrays and your own payload resources for
## free.

signal selection_changed(res: Resource)
signal dirtied
signal status(text: String)

enum Drag { NONE, MOVE, CONNECT, PAN }

const ZOOM_MIN := 0.25
const ZOOM_MAX := 3.0
const ANCHOR_GRAB := 22.0
const LINK_GRAB := 8.0

var tree: SkillTreeResource
var undo_redo: EditorUndoRedoManager
## Adds a cost line under each caption. Off by default - on a tight grid the
## second line collides with the node below.
var show_costs: bool = false

var selected: Resource

var _fallback_style: SkillTreeStyle
var _zoom: float = 1.0
var _pan: Vector2 = Vector2(80, 80)
var _drag: Drag = Drag.NONE
var _drag_node: SkillNodeData
var _drag_start_cell: Vector2i
var _connect_from: SkillNodeData
var _mouse_canvas: Vector2
var _hover_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true


func set_tree(t: SkillTreeResource) -> void:
	tree = t
	selected = null
	selection_changed.emit(null)
	fit_to_view()


# --- coordinate helpers -------------------------------------------------------

func to_canvas(local: Vector2) -> Vector2:
	return (local - _pan) / _zoom


func to_screen(canvas: Vector2) -> Vector2:
	return canvas * _zoom + _pan


## The tree's style, or a default one. Link and lock drawing lives on the
## style resource, so the canvas and the runtime view stay in sync by
## construction instead of by me remembering to edit both.
func style() -> SkillTreeStyle:
	if tree != null and tree.style != null:
		return tree.style
	if _fallback_style == null:
		_fallback_style = SkillTreeStyle.new()
	return _fallback_style


func node_size() -> Vector2:
	return style().node_size


func node_rect(n: SkillNodeData) -> Rect2:
	var s: Vector2 = node_size()
	return Rect2(tree.cell_to_position(n.cell) - s * 0.5, s)


func fit_to_view() -> void:
	if size.x < 64.0 or size.y < 64.0:
		# Called before layout (e.g. straight after set_tree). Try again once
		# the container has given us a size.
		if is_inside_tree():
			call_deferred("fit_to_view")
		return
	if tree == null:
		_zoom = 1.0
		_pan = Vector2(80, 80)
		queue_redraw()
		return
	var content: Vector2 = tree.content_size() + node_size() * 2.0
	var avail: Vector2 = size - Vector2(40, 40)
	if content.x > 0.0 and content.y > 0.0 and avail.x > 0.0 and avail.y > 0.0:
		_zoom = clampf(minf(avail.x / content.x, avail.y / content.y), ZOOM_MIN, ZOOM_MAX)
	else:
		_zoom = 1.0
	_pan = (size - tree.content_size() * _zoom) * 0.5
	queue_redraw()


# --- hit testing --------------------------------------------------------------

func _node_at(canvas_pt: Vector2) -> SkillNodeData:
	if tree == null:
		return null
	for i in range(tree.nodes.size() - 1, -1, -1):
		var n: SkillNodeData = tree.nodes[i]
		if n != null and node_rect(n).has_point(canvas_pt):
			return n
	return null


func _cell_at(canvas_pt: Vector2) -> Vector2i:
	if tree == null or tree.cell_size.x <= 0.0 or tree.cell_size.y <= 0.0:
		return Vector2i(-1, -1)
	var approx: Vector2 = canvas_pt / tree.cell_size
	var cell := Vector2i(roundi(approx.x), roundi(approx.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= tree.grid_size.x or cell.y >= tree.grid_size.y:
		return Vector2i(-1, -1)
	if tree.cell_to_position(cell).distance_to(canvas_pt) > ANCHOR_GRAB:
		return Vector2i(-1, -1)
	return cell


func _link_at(canvas_pt: Vector2) -> SkillConnection:
	if tree == null:
		return null
	for c in tree.connections:
		if c == null:
			continue
		var a: SkillNodeData = tree.find_node(c.from_id)
		var b: SkillNodeData = tree.find_node(c.to_id)
		if a == null or b == null:
			continue
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(
				canvas_pt, tree.cell_to_position(a.cell), tree.cell_to_position(b.cell))
		if p.distance_to(canvas_pt) <= LINK_GRAB:
			return c
	return null


# --- input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if tree == null:
		return

	if event is InputEventMouseButton:
		_handle_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_motion(event as InputEventMouseMotion)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_handle_key(event as InputEventKey)


func _handle_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not mb.pressed:
			return
		var before: Vector2 = to_canvas(mb.position)
		var factor: float = 1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
		_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
		_pan = mb.position - before * _zoom
		accept_event()
		queue_redraw()
		return

	if mb.button_index == MOUSE_BUTTON_MIDDLE:
		_drag = Drag.PAN if mb.pressed else Drag.NONE
		accept_event()
		return

	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var pt: Vector2 = to_canvas(mb.position)

	if mb.pressed:
		grab_focus()
		accept_event()
		var node: SkillNodeData = _node_at(pt)
		if node != null:
			_select(node)
			if mb.shift_pressed:
				_drag = Drag.CONNECT
				_connect_from = node
				status.emit("Drag onto another node to connect. Release on empty space to cancel.")
			else:
				_drag = Drag.MOVE
				_drag_node = node
				_drag_start_cell = node.cell
			return

		var link: SkillConnection = _link_at(pt)
		if link != null:
			_select(link)
			return

		var cell: Vector2i = _cell_at(pt)
		if cell.x >= 0 and tree.node_at_cell(cell) == null:
			_add_node(cell)
		else:
			_select(null)
		return

	# release
	accept_event()
	if _drag == Drag.CONNECT and _connect_from != null:
		var target: SkillNodeData = _node_at(pt)
		if target != null and target != _connect_from:
			_add_link(_connect_from, target)
	elif _drag == Drag.MOVE and _drag_node != null:
		var cell: Vector2i = _cell_at(pt)
		if cell.x >= 0 and cell != _drag_start_cell and tree.node_at_cell(cell) == null:
			_move_node(_drag_node, _drag_start_cell, cell)
	_drag = Drag.NONE
	_drag_node = null
	_connect_from = null
	queue_redraw()


func _handle_motion(mm: InputEventMouseMotion) -> void:
	_mouse_canvas = to_canvas(mm.position)
	if _drag == Drag.PAN:
		_pan += mm.relative
		queue_redraw()
		return
	var cell: Vector2i = _cell_at(_mouse_canvas)
	if cell != _hover_cell or _drag != Drag.NONE:
		_hover_cell = cell
		queue_redraw()


func _handle_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_DELETE, KEY_BACKSPACE:
			delete_selection()
			accept_event()
		KEY_F:
			fit_to_view()
			accept_event()
		KEY_ESCAPE:
			_select(null)
			accept_event()


# --- edits (all undoable) -----------------------------------------------------

func _select(res: Resource) -> void:
	selected = res
	selection_changed.emit(res)
	if res != null and Engine.is_editor_hint():
		EditorInterface.edit_resource(res)
	queue_redraw()


func unique_node_id(base: String = "skill") -> StringName:
	var i: int = 1
	while true:
		var candidate := StringName("%s_%d" % [base, i])
		if tree.find_node(candidate) == null:
			return candidate
		i += 1
	return StringName(base)  # unreachable; keeps the type checker happy


func _add_node(cell: Vector2i) -> void:
	var data := SkillNodeData.new()
	data.id = unique_node_id()
	data.title = "New Skill"
	data.cell = cell
	data.unlocked_from_start = tree.nodes.is_empty()

	undo_redo.create_action("Add skill node", UndoRedo.MERGE_DISABLE, tree)
	undo_redo.add_do_method(self, "_insert_node", data)
	undo_redo.add_undo_method(self, "_erase_node", data)
	undo_redo.commit_action()
	_select(data)
	status.emit("Added '%s'. Edit it in the Inspector." % data.id)


func _add_link(from_node: SkillNodeData, to_node: SkillNodeData) -> void:
	if tree.has_connection(from_node.id, to_node.id):
		status.emit("Those two are already connected.")
		return
	var link := SkillConnection.new()
	link.from_id = from_node.id
	link.to_id = to_node.id

	undo_redo.create_action("Connect skill nodes", UndoRedo.MERGE_DISABLE, tree)
	undo_redo.add_do_method(self, "_insert_link", link)
	undo_redo.add_undo_method(self, "_erase_link", link)
	undo_redo.commit_action()
	_select(link)
	status.emit("%s -> %s. Add a lock from the toolbar to gate it." % [from_node.id, to_node.id])


func _move_node(data: SkillNodeData, from_cell: Vector2i, to_cell: Vector2i) -> void:
	undo_redo.create_action("Move skill node", UndoRedo.MERGE_DISABLE, tree)
	undo_redo.add_do_property(data, "cell", to_cell)
	undo_redo.add_undo_property(data, "cell", from_cell)
	undo_redo.add_do_method(self, "_touch")
	undo_redo.add_undo_method(self, "_touch")
	undo_redo.commit_action()


func delete_selection() -> void:
	if selected is SkillNodeData:
		_delete_node(selected as SkillNodeData)
	elif selected is SkillConnection:
		_delete_link(selected as SkillConnection)
	else:
		status.emit("Nothing selected.")


func _delete_node(data: SkillNodeData) -> void:
	var links: Array[SkillConnection] = []
	for c in tree.connections:
		if c != null and c.involves(data.id):
			links.append(c)

	undo_redo.create_action("Delete skill node", UndoRedo.MERGE_DISABLE, tree)
	for l in links:
		undo_redo.add_do_method(self, "_erase_link", l)
	undo_redo.add_do_method(self, "_erase_node", data)
	undo_redo.add_undo_method(self, "_insert_node", data)
	for l in links:
		undo_redo.add_undo_method(self, "_insert_link", l)
	undo_redo.commit_action()
	_select(null)
	status.emit("Deleted '%s' and %d connection(s)." % [data.id, links.size()])


func _delete_link(link: SkillConnection) -> void:
	undo_redo.create_action("Delete connection", UndoRedo.MERGE_DISABLE, tree)
	undo_redo.add_do_method(self, "_erase_link", link)
	undo_redo.add_undo_method(self, "_insert_link", link)
	undo_redo.commit_action()
	_select(null)


## Puts a fresh lock on the selected connection and opens it in the Inspector.
func add_lock_to_selection() -> void:
	var link := selected as SkillConnection
	if link == null:
		status.emit("Select a connection first, then add a lock to it.")
		return
	if link.lock != null:
		EditorInterface.edit_resource(link.lock)
		status.emit("That connection already has a lock - editing it.")
		return
	var lock := SkillLock.new()
	lock.id = StringName("%s_to_%s_gate" % [link.from_id, link.to_id])
	lock.title = "New Gate"

	undo_redo.create_action("Add connection lock", UndoRedo.MERGE_DISABLE, tree)
	undo_redo.add_do_property(link, "lock", lock)
	undo_redo.add_undo_property(link, "lock", null)
	undo_redo.add_do_method(self, "_touch")
	undo_redo.add_undo_method(self, "_touch")
	undo_redo.commit_action()
	EditorInterface.edit_resource(lock)
	status.emit("Lock '%s' added. Your game answers is_lock_open() for that id." % lock.id)


func remove_lock_from_selection() -> void:
	var link := selected as SkillConnection
	if link == null or link.lock == null:
		status.emit("Select a locked connection first.")
		return
	undo_redo.create_action("Remove connection lock", UndoRedo.MERGE_DISABLE, tree)
	undo_redo.add_do_property(link, "lock", null)
	undo_redo.add_undo_property(link, "lock", link.lock)
	undo_redo.add_do_method(self, "_touch")
	undo_redo.add_undo_method(self, "_touch")
	undo_redo.commit_action()


# Called by the undo manager. Kept tiny and symmetrical on purpose.
func _insert_node(data: SkillNodeData) -> void:
	if not tree.nodes.has(data):
		tree.nodes.append(data)
	_touch()


func _erase_node(data: SkillNodeData) -> void:
	tree.nodes.erase(data)
	_touch()


func _insert_link(link: SkillConnection) -> void:
	if not tree.connections.has(link):
		tree.connections.append(link)
	_touch()


func _erase_link(link: SkillConnection) -> void:
	tree.connections.erase(link)
	_touch()


func _touch() -> void:
	if tree != null:
		tree.emit_changed()
	dirtied.emit()
	queue_redraw()


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	if tree == null:
		_draw_hint("Open a SkillTreeResource (.tres) to start editing.")
		return

	# World layer: everything that should pan and zoom.
	draw_set_transform(_pan, 0.0, Vector2(_zoom, _zoom))
	_draw_grid()
	_draw_links()
	_draw_nodes()
	_draw_drag()

	# Screen layer: text and lock badges stay a constant size, are measured
	# rather than clipped, and sit above the nodes so nothing hides them.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_lock_badges()
	_draw_captions()
	_draw_info()
	_draw_legend()


func _draw_grid() -> void:
	for x in tree.grid_size.x:
		for y in tree.grid_size.y:
			var cell := Vector2i(x, y)
			var p: Vector2 = tree.cell_to_position(cell)
			var occupied: bool = tree.node_at_cell(cell) != null
			if occupied:
				continue
			var hot: bool = cell == _hover_cell
			draw_arc(p, 8.0 if hot else 6.0, 0.0, TAU, 20,
					Color(0.6, 0.85, 1.0, 0.9) if hot else Color(1, 1, 1, 0.22),
					2.0, true)


## Dashes marching from the prerequisite to the node it unlocks. No arrowhead:
## the taper and the march read as direction, and neither can be hidden under a
## node the way a head parked on the node's edge was.
func _draw_links() -> void:
	var st: SkillTreeStyle = style()
	for c in tree.connections:
		if c == null:
			continue
		var a: SkillNodeData = tree.find_node(c.from_id)
		var b: SkillNodeData = tree.find_node(c.to_id)
		if a == null or b == null:
			continue
		var pa: Vector2 = tree.cell_to_position(a.cell)
		var pb: Vector2 = tree.cell_to_position(b.cell)
		var chosen: bool = c == selected
		var col := Color(1.0, 0.55, 0.2) if chosen else Color(0.72, 0.86, 1.0, 0.7)
		# The badge is drawn in screen space at a fixed size, so the gap it
		# needs in world space grows as we zoom out.
		var hole: float = 0.0
		if c.lock != null:
			hole = st.lock_clear_radius() / maxf(_zoom, 0.01)
		st.draw_link_dashes(self, pa, pb, col,
				st.link_width * (1.4 if chosen else 1.0), 0.0, (pa + pb) * 0.5, hole)


## Lock badges are the one piece of world content drawn in the screen layer:
## a gate you cannot see is worse than no gate, and in world space it shrank
## with the zoom until it was a smudge.
func _draw_lock_badges() -> void:
	var st: SkillTreeStyle = style()
	var margin: float = st.lock_clear_radius() + 4.0
	for c in tree.connections:
		if c == null or c.lock == null:
			continue
		var a: SkillNodeData = tree.find_node(c.from_id)
		var b: SkillNodeData = tree.find_node(c.to_id)
		if a == null or b == null:
			continue
		var at: Vector2 = to_screen(
				(tree.cell_to_position(a.cell) + tree.cell_to_position(b.cell)) * 0.5)
		if at.x < -margin or at.y < -margin \
				or at.x > size.x + margin or at.y > size.y + margin:
			continue
		st.draw_lock(self, at, false, c.lock.icon)
		if c == selected:
			draw_arc(at, st.lock_clear_radius(), 0.0, TAU, 32,
					Color(1.0, 0.55, 0.2, 0.9), 2.0, true)


func _draw_nodes() -> void:
	for n in tree.nodes:
		if n == null:
			continue
		var rect: Rect2 = node_rect(n)
		var chosen: bool = n == selected
		draw_rect(rect, Color(0.13, 0.15, 0.20, 0.95))
		draw_rect(rect, Color(1.0, 0.55, 0.2) if chosen else Color(0.8, 0.9, 1.0, 0.85),
				false, 3.0 if chosen else 2.0)
		if n.icon != null:
			draw_texture_rect(n.icon, rect.grow(-6.0), false)
		if n.unlocked_from_start:
			draw_circle(rect.position + Vector2(6, 6), 3.5, Color(0.5, 1.0, 0.6))


## Captions live in screen space: measured against the real font so nothing is
## clipped, constant size at any zoom, and backed by a plate so they stay
## readable over links.
func _draw_captions() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var fs: int = maxi(9, get_theme_default_font_size() - 1)
	var line_h: float = float(fs) + 4.0
	var half_y: float = node_size().y * 0.5 * _zoom

	for n in tree.nodes:
		if n == null:
			continue
		var center: Vector2 = to_screen(tree.cell_to_position(n.cell))
		var y: float = center.y + half_y + line_h
		if y < -line_h or y > size.y + line_h or center.x < -200.0 or center.x > size.x + 200.0:
			continue
		_plate_text(font, n.label(), Vector2(center.x, y), fs, Color(1, 1, 1, 0.92))
		if show_costs and n.costs.size() > 0:
			_plate_text(font, n.describe_costs(1), Vector2(center.x, y + line_h),
					fs, Color(1.0, 0.88, 0.5, 0.85))


## Centred text on a dark plate. Returns nothing; measures its own width.
func _plate_text(font: Font, text: String, center_at: Vector2, fs: int, col: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var origin := Vector2(center_at.x - w * 0.5, center_at.y)
	draw_rect(Rect2(origin.x - 3.0, origin.y - float(fs), w + 6.0, float(fs) + 4.0),
			Color(0.08, 0.09, 0.11, 0.8))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Details of whatever is selected, pinned to the corner. Full costs and ids go
## here rather than next to the node, where they would collide or clip.
func _draw_info() -> void:
	if selected == null:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var fs: int = get_theme_default_font_size()

	var lines: PackedStringArray = []
	var node := selected as SkillNodeData
	if node != null:
		lines.append("%s   [%s]" % [node.label(), node.id])
		lines.append("cell %s    max rank %d    requires %s" % [str(node.cell),
				node.max_rank,
				"ALL" if node.requirement == SkillTree.Requirement.ALL else "ANY"])
		lines.append("cost: %s" % node.describe_costs(1))
		if node.unlocked_from_start:
			lines.append("unlocked from start")
	else:
		var link := selected as SkillConnection
		if link == null:
			return
		lines.append("%s   ->   %s" % [link.from_id, link.to_id])
		lines.append("lock: %s" % (String(link.lock.id) if link.lock != null else "none"))

	var w: float = 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var line_h: float = float(fs) + 5.0
	var rect := Rect2(10.0, 10.0, w + 20.0, float(lines.size()) * line_h + 10.0)
	draw_rect(rect, Color(0.08, 0.09, 0.11, 0.93))
	draw_rect(rect, Color(1.0, 0.55, 0.2, 0.7), false, 1.0)
	var y: float = rect.position.y + float(fs) + 5.0
	for l in lines:
		draw_string(font, Vector2(rect.position.x + 10.0, y), l,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
		y += line_h


func _draw_drag() -> void:
	if _drag == Drag.CONNECT and _connect_from != null:
		draw_line(tree.cell_to_position(_connect_from.cell), _mouse_canvas,
				Color(0.4, 1.0, 0.6, 0.8), 3.0, true)
	elif _drag == Drag.MOVE and _drag_node != null:
		var cell: Vector2i = _cell_at(_mouse_canvas)
		if cell.x >= 0:
			var s: Vector2 = node_size()
			draw_rect(Rect2(tree.cell_to_position(cell) - s * 0.5, s),
					Color(0.4, 1.0, 0.6, 0.35))


func _draw_legend() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var lines: PackedStringArray = [
		"click dot: add node    click node: select    drag node: move",
		"shift+drag node to node: connect    click link: select    Del: delete",
		"wheel: zoom    middle-drag: pan    F: fit",
	]
	var y: float = size.y - 12.0 - float(lines.size() - 1) * 15.0
	for line in lines:
		draw_string(font, Vector2(12, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				get_theme_default_font_size() - 1, Color(1, 1, 1, 0.4))
		y += 15.0


func _draw_hint(text: String) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(24, size.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, get_theme_default_font_size() + 2, Color(1, 1, 1, 0.55))
