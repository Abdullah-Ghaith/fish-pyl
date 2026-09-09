extends Control
## Throwaway harness for looking at a skill tree with real runtime state.
##
## Setup: Scene -> New Scene -> "Other Node" -> Control, attach this script,
## save it anywhere (e.g. res://Scenes/SkillTree/skill_tree_test.tscn), press
## F6. It builds its own UI, so there is nothing to wire up in the editor.
##
## Everything is free here - no wallet, no achievement system - so you can
## click nodes and watch the node states, link colours and gates react. That
## is also the only place the link shader runs: the SkillTree editor tab is a
## static authoring surface and never applies `style.link_material`.

## The tree to show. Points at the demo tree by default.
@export_file("*.tres") var tree_path: String = "res://skill_tree.tres"
## Dropped on this Control, so it propagates down to the view's labels and
## tooltips. Handy for trying a theme pack without editing the style resource.
@export var test_theme: Theme

var _view: SkillTreeView
var _state: SkillTreeState
var _log: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if test_theme != null:
		theme = test_theme

	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var res: Resource = load(tree_path)
	_view = SkillTreeView.new()
	_view.tree = res as SkillTreeResource
	scroll.add_child(_view)

	_build_toolbar()

	if _view.tree == null:
		_log.text = "No SkillTreeResource at %s" % tree_path
		return

	# balance_provider and spender left unset: purchases are free while
	# testing. lock_provider left unset too - the toggle below opens locks
	# directly, which is what set_lock_open() is for.
	_state = SkillTreeState.new(_view.tree)
	_view.state = _state
	_view.node_purchased.connect(_on_purchased)
	_view.purchase_rejected.connect(_on_rejected)


func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -48.0
	bar.offset_bottom = -12.0

	var gate := CheckButton.new()
	gate.text = "Achievements unlocked"
	gate.toggled.connect(_on_gate_toggled)
	bar.add_child(gate)

	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(_on_reset)
	bar.add_child(reset)

	_log = Label.new()
	_log.text = "Click a node to buy it."
	_log.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_log)


func _on_gate_toggled(pressed: bool) -> void:
	for c in _view.tree.connections:
		if c != null and c.lock != null:
			_state.set_lock_open(c.lock.id, pressed)
	_log.text = "Locks %s." % ("open" if pressed else "closed")


func _on_reset() -> void:
	_state.reset()
	_log.text = "Reset."


func _on_purchased(n: SkillNodeData, rank: int) -> void:
	_log.text = "Bought %s (rank %d)." % [n.label(), rank]


func _on_rejected(n: SkillNodeData, reason: String) -> void:
	_log.text = "%s - %s" % [n.label(), reason]
