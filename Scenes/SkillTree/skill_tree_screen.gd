extends Control

@export var ui_theme: Theme
## Debug: hand out points and open gates from the toolbar.
@export var show_debug_bar: bool = true

var _view: SkillTreeView
var _wallet_label: Label
var _log: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ui_theme != null:
		theme = ui_theme

	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_view = SkillTreeView.new()
	_view.tree = Progression.tree
	scroll.add_child(_view)

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
	var sp: int = Progression.balance(&"skill_points")
	var gold: int = Progression.balance(&"gold")
	_wallet_label.text = "SP %d    Gold %d" % [sp, gold]


func _open_all_gates() -> void:
	for c in Progression.tree.connections:
		if c != null and c.lock != null:
			Progression.unlock_achievement(c.lock.id)


func _on_purchased(n: SkillNodeData, rank: int) -> void:
	# stats has already recomputed by now - state.changed fires first.
	_log.text = "%s rank %d.  %s" % [n.label(), rank,
			Progression.stats.describe().replace("\n", "   ")]


func _on_rejected(n: SkillNodeData, reason: String) -> void:
	_log.text = "%s - %s" % [n.label(), reason]


func _on_achievement(id: StringName) -> void:
	_log.text = "Achievement: %s" % id
