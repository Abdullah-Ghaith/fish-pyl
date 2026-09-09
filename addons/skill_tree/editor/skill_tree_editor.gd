@tool
extends VBoxContainer
## Main-screen dev tool: a toolbar over the authoring canvas. The whole UI is
## built in code so there is no .tscn to keep in sync with the scripts.

const DEMO_GRID := Vector2i(5, 6)
## Loaded by path, not class_name: the editor scripts must stay out of the
## global class list so a game export never tries to parse EditorInterface.
const CanvasScript := preload("res://addons/skill_tree/editor/skill_tree_canvas.gd")

var undo_redo: EditorUndoRedoManager:
	set(v):
		undo_redo = v
		if canvas != null:
			canvas.undo_redo = v

var canvas: CanvasScript

var _tree: SkillTreeResource
var _dirty: bool = false

var _title: Label
var _status: Label
var _grid_x: SpinBox
var _grid_y: SpinBox
var _cell_x: SpinBox
var _cell_y: SpinBox
var _picker: OptionButton
var _new_dialog: EditorFileDialog
var _tree_paths: PackedStringArray = []
var _save_btn: Button
var _lock_btn: Button
var _unlock_btn: Button
var _delete_btn: Button
var _demo_btn: Button


func _init() -> void:
	name = "SkillTreeEditor"
	# The editor main screen is a VBoxContainer, so fill it with size flags
	# rather than anchors.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	_build_toolbar()
	_build_canvas()
	_build_status()
	_build_dialogs()


func _build_toolbar() -> void:
	# A Container's minimum width is the sum of its children's, and the editor
	# main screen propagates that minimum outward - which is what was pinning
	# the FileSystem and Inspector docks open at a width you could not drag.
	# Inside a horizontally-scrolling container the toolbar demands no width at
	# all, so the docks are free again and the bar scrolls when space is tight.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 36)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	scroll.add_child(bar)

	_picker = OptionButton.new()
	_picker.custom_minimum_size.x = 150
	_picker.tooltip_text = "Every SkillTreeResource in the project."
	_picker.item_selected.connect(_on_picked)
	bar.add_child(_picker)

	_button(bar, "New...", "Create a new skill tree .tres."
			).pressed.connect(func() -> void: _new_dialog.popup_centered_ratio(0.5))
	_button(bar, "Rescan", "Look for skill tree files again."
			).pressed.connect(refresh_tree_list)

	bar.add_child(VSeparator.new())

	_title = Label.new()
	_title.text = "No tree open"
	bar.add_child(_title)

	bar.add_child(VSeparator.new())

	_save_btn = _button(bar, "Save", "Write the tree back to its .tres file.")
	_save_btn.pressed.connect(save_tree)
	_button(bar, "Fit", "Frame the whole grid (F).").pressed.connect(
			func() -> void: canvas.fit_to_view())
	_button(bar, "Validate", "List structural problems: bad ids, cycles, orphans."
			).pressed.connect(_validate)

	bar.add_child(VSeparator.new())

	_lock_btn = _button(bar, "Add Lock",
			"Gate the selected connection behind a game achievement.")
	_lock_btn.pressed.connect(func() -> void: canvas.add_lock_to_selection())
	_unlock_btn = _button(bar, "Remove Lock", "Make the selected connection open again.")
	_unlock_btn.pressed.connect(func() -> void: canvas.remove_lock_from_selection())
	_delete_btn = _button(bar, "Delete", "Delete the selection (Del).")
	_delete_btn.pressed.connect(func() -> void: canvas.delete_selection())

	bar.add_child(VSeparator.new())

	bar.add_child(_label("Grid"))
	_grid_x = _spin(bar, 1, 64, 1)
	_grid_y = _spin(bar, 1, 64, 1)
	bar.add_child(_label("Cell"))
	_cell_x = _spin(bar, 8, 512, 1)
	_cell_y = _spin(bar, 8, 512, 1)
	_grid_x.value_changed.connect(func(_v: float) -> void: _apply_grid())
	_grid_y.value_changed.connect(func(_v: float) -> void: _apply_grid())
	_cell_x.value_changed.connect(func(_v: float) -> void: _apply_grid())
	_cell_y.value_changed.connect(func(_v: float) -> void: _apply_grid())

	var costs_toggle := CheckBox.new()
	costs_toggle.text = "Costs"
	costs_toggle.tooltip_text = "Show a cost line under each node caption."
	costs_toggle.toggled.connect(func(on: bool) -> void:
		canvas.show_costs = on
		canvas.queue_redraw())
	bar.add_child(costs_toggle)

	bar.add_child(VSeparator.new())
	_demo_btn = _button(bar, "Fill With Demo",
			"Populate an empty tree with a working example to poke at.")
	_demo_btn.pressed.connect(_fill_demo)


func _build_canvas() -> void:
	canvas = CanvasScript.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.undo_redo = undo_redo
	canvas.dirtied.connect(_on_dirtied)
	canvas.status.connect(_set_status)
	canvas.selection_changed.connect(_on_selection_changed)
	add_child(canvas)


func _build_status() -> void:
	_status = Label.new()
	_status.text = "Pick or create a tree from the toolbar."
	# ARBITRARY, not WORD: a word-wrapping Label's minimum width is its longest
	# word, and a res:// path is a very long word.
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.custom_minimum_size = Vector2(0, 32)
	add_child(_status)


func _build_dialogs() -> void:
	_new_dialog = EditorFileDialog.new()
	_new_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_new_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_new_dialog.title = "New Skill Tree"
	_new_dialog.current_file = "skill_tree.tres"
	_new_dialog.clear_filters()
	_new_dialog.add_filter("*.tres", "Skill Tree")
	_new_dialog.file_selected.connect(_create_tree_at)
	add_child(_new_dialog)


# --- finding and opening trees ------------------------------------------------

## Rescans the project for skill tree files. Reads each .tres header rather than
## loading it, so a big project stays cheap to scan.
func refresh_tree_list() -> void:
	_tree_paths = PackedStringArray()
	_scan_dir("res://", _tree_paths)
	if _picker == null:
		return
	_picker.clear()
	_picker.add_item("Select a tree...")
	for p in _tree_paths:
		_picker.add_item(p.trim_prefix("res://"))
	if _tree != null:
		var idx: int = _tree_paths.find(_tree.resource_path)
		if idx >= 0:
			_picker.select(idx + 1)


func _scan_dir(dir_path: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if d.current_is_dir():
			if entry != "addons":
				_scan_dir(full, out)
		elif entry.ends_with(".tres") and _looks_like_tree(full):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func _looks_like_tree(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var head: String = f.get_buffer(1024).get_string_from_utf8()
	f.close()
	return head.contains("SkillTreeResource") or head.contains("skill_tree_resource.gd")


func _on_picked(index: int) -> void:
	if index <= 0 or index > _tree_paths.size():
		return
	var res := load(_tree_paths[index - 1]) as SkillTreeResource
	if res == null:
		_set_status("That file is not a SkillTreeResource.")
		return
	load_tree(res)


func _create_tree_at(path: String) -> void:
	var res := SkillTreeResource.new()
	res.tree_name = path.get_file().get_basename().capitalize()
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		_set_status("Could not create %s (error %d)." % [path, err])
		return
	EditorInterface.get_resource_filesystem().scan()
	refresh_tree_list()
	load_tree(load(path) as SkillTreeResource)
	_set_status("Created %s. Click a guide dot to place your first skill." % path)


func _button(parent: Node, text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	parent.add_child(b)
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _spin(parent: Node, min_v: float, max_v: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size.x = 58
	parent.add_child(s)
	return s


# --- tree lifecycle -----------------------------------------------------------

func load_tree(t: SkillTreeResource) -> void:
	_tree = t
	_dirty = false
	canvas.undo_redo = undo_redo
	canvas.set_tree(t)
	if t != null:
		_grid_x.set_value_no_signal(t.grid_size.x)
		_grid_y.set_value_no_signal(t.grid_size.y)
		_cell_x.set_value_no_signal(t.cell_size.x)
		_cell_y.set_value_no_signal(t.cell_size.y)
	_refresh_header()
	_set_status("Click a guide dot to place a skill. Shift-drag between skills to connect them.")


func save_tree() -> void:
	if _tree == null:
		_set_status("Nothing to save.")
		return
	if _tree.resource_path.is_empty():
		_set_status("This tree has no file yet - save it as a .tres from the Inspector first.")
		return
	var err: int = ResourceSaver.save(_tree, _tree.resource_path)
	if err == OK:
		_dirty = false
		_refresh_header()
		_set_status("Saved %s" % _tree.resource_path)
	else:
		_set_status("Save failed (error %d)." % err)


func _apply_grid() -> void:
	if _tree == null:
		return
	_tree.grid_size = Vector2i(int(_grid_x.value), int(_grid_y.value))
	_tree.cell_size = Vector2(_cell_x.value, _cell_y.value)
	_tree.emit_changed()
	_on_dirtied()
	canvas.queue_redraw()


func _validate() -> void:
	if _tree == null:
		return
	var problems: PackedStringArray = _tree.validate()
	if problems.is_empty():
		_set_status("Valid: %d nodes, %d connections, no problems."
				% [_tree.nodes.size(), _tree.connections.size()])
		return
	_set_status("%d problem(s): %s" % [problems.size(), " | ".join(problems)])
	for p in problems:
		push_warning("[SkillTree] %s" % p)


func _on_dirtied() -> void:
	_dirty = true
	_refresh_header()


func _on_selection_changed(res: Resource) -> void:
	var is_link: bool = res is SkillConnection
	_lock_btn.disabled = not is_link
	_unlock_btn.disabled = not (is_link and (res as SkillConnection).lock != null)
	_delete_btn.disabled = res == null


func _refresh_header() -> void:
	if _tree == null:
		_title.text = "No tree open"
		_save_btn.disabled = true
		_demo_btn.disabled = true
		return
	var label: String = _tree.tree_name if _tree.tree_name != "" else "Untitled"
	_title.text = "%s%s" % [label, " *" if _dirty else ""]
	_save_btn.disabled = false
	_demo_btn.disabled = false


func _set_status(text: String) -> void:
	if _status == null:
		return
	# Truncate so a long Validate report can never widen the panel; the whole
	# thing stays available on hover.
	_status.text = text.left(220) + ("..." if text.length() > 220 else "")
	_status.tooltip_text = text


# --- demo ---------------------------------------------------------------------

## Builds a small but complete tree: two currencies, a multi-rank node, a
## branch that needs either parent, and one achievement-gated route.
func _fill_demo() -> void:
	if _tree == null:
		return
	if not _tree.nodes.is_empty():
		_set_status("Demo only fills an empty tree - clear it first.")
		return

	var points := SkillCurrency.new()
	points.id = &"skill_points"
	points.display_name = "SP"
	points.color = Color(0.6, 0.9, 1.0)

	var gold := SkillCurrency.new()
	gold.id = &"gold"
	gold.display_name = "Gold"
	gold.color = Color(1.0, 0.85, 0.3)

	var gate := SkillLock.new()
	gate.id = &"caught_legendary"
	gate.title = "Landed a legendary"
	gate.hint = "Catch a legendary fish to open this path."

	var nodes: Array[SkillNodeData] = []
	nodes.append(_demo_node("root", "Basics", Vector2i(2, 5), 1, [[points, 1, 0]], true))
	nodes.append(_demo_node("line_a", "Longer Line", Vector2i(1, 4), 3, [[points, 1, 1]], false))
	nodes.append(_demo_node("handling", "Handling", Vector2i(3, 4), 3, [[points, 1, 1]], false))
	nodes.append(_demo_node("capacity", "Bigger Haul", Vector2i(2, 3), 1,
			[[points, 3, 0], [gold, 250, 0]], false))
	nodes.append(_demo_node("deep", "Deep Water", Vector2i(2, 2), 1, [[gold, 500, 0]], false))
	nodes.append(_demo_node("master", "Master Angler", Vector2i(2, 1), 1,
			[[points, 5, 0], [gold, 1000, 0]], false))
	nodes[3].requirement = SkillTree.Requirement.ANY

	var links: Array[SkillConnection] = []
	links.append(_demo_link("root", "line_a", null))
	links.append(_demo_link("root", "handling", null))
	links.append(_demo_link("line_a", "capacity", null))
	links.append(_demo_link("handling", "capacity", null))
	links.append(_demo_link("capacity", "deep", gate))
	links.append(_demo_link("deep", "master", null))

	undo_redo.create_action("Fill demo skill tree", UndoRedo.MERGE_DISABLE, _tree)
	undo_redo.add_do_property(_tree, "grid_size", DEMO_GRID)
	undo_redo.add_undo_property(_tree, "grid_size", _tree.grid_size)
	for n in nodes:
		undo_redo.add_do_method(canvas, "_insert_node", n)
	for l in links:
		undo_redo.add_do_method(canvas, "_insert_link", l)
	for l in links:
		undo_redo.add_undo_method(canvas, "_erase_link", l)
	for n in nodes:
		undo_redo.add_undo_method(canvas, "_erase_node", n)
	undo_redo.commit_action()

	_grid_x.set_value_no_signal(DEMO_GRID.x)
	_grid_y.set_value_no_signal(DEMO_GRID.y)
	canvas.fit_to_view()
	_set_status("Demo built. 'Bigger Haul' needs EITHER parent; 'Deep Water' is gated "
			+ "behind the 'caught_legendary' achievement.")


func _demo_node(id: String, title: String, cell: Vector2i, ranks: int,
		costs: Array, root: bool) -> SkillNodeData:
	var n := SkillNodeData.new()
	n.id = StringName(id)
	n.title = title
	n.cell = cell
	n.max_rank = ranks
	n.unlocked_from_start = root
	var list: Array[SkillCost] = []
	for spec in costs:
		var c := SkillCost.new()
		c.currency = spec[0]
		c.amount = spec[1]
		c.per_rank_increase = spec[2]
		list.append(c)
	n.costs = list
	return n


func _demo_link(from_id: String, to_id: String, lock: SkillLock) -> SkillConnection:
	var c := SkillConnection.new()
	c.from_id = StringName(from_id)
	c.to_id = StringName(to_id)
	c.lock = lock
	return c
