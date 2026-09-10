class_name CatchEntry extends Node2D
## One fish's catch card, built by CatchDisplay.


@export_group("Frame")
## Default card frame. A RarityStyle can override it per tier.
## Kenney's pixel pack has ready 9-slices: make a StyleBoxTexture from
## 9-Slice/Ancient/brown.png with texture margins 3 / 3 / 3 / 5.
@export var card_panel: StyleBox
## Space between the frame and the contents.
@export var padding: int = 8
## Gap between the card's lines.
@export var line_spacing: int = 2
## Never narrower than this, so a short name still gets a card-shaped card.
@export var min_width: float = 104.0
## Card position relative to this node's origin, before centring.
@export var card_offset: Vector2 = Vector2(0, -6)

@export_group("Content")
@export var show_title: bool = true
@export var title_text: String = "Fish Caught!"
## Art box for the fish. Zero = native size, which is the crisp option. If you
## set one, use an integer multiple of your fish sprites or the pixels smear.
@export var art_size: Vector2 = Vector2.ZERO

@export_group("Text")
## Used for the title line. The fish's name uses RarityStyle.label_settings.
@export var title_settings: LabelSettings
## Used for the rarity and size lines. Its colour is replaced by the tier's
## accent on the rarity line.
@export var detail_settings: LabelSettings

var data: FishData = null
var record: CatchRecord = null

var _card: PanelContainer
var _art: TextureRect
var _name: Label
var _rarity: Label
var _size: Label
var _vfx_anchor: Marker2D


func _ready() -> void:
	_build()


func setup(rec: CatchRecord, style: RarityStyle) -> void:
	record = rec
	data = rec.data if rec != null else null
	if data == null:
		return
	if _card == null:
		_build()

	_art.texture = data.texture
	_name.text = str(data.title)
	_rarity.text = _rarity_name(style)
	_size.text = record.size_text()
	_size.visible = record.has_length()

	var panel: StyleBox = card_panel
	if style != null:
		if style.card_panel != null:
			panel = style.card_panel
		if style.label_settings != null:
			_name.label_settings = style.label_settings
		_art.modulate = style.tint
		_rarity.add_theme_color_override(&"font_color", style.accent)
		if detail_settings != null:
			# LabelSettings wins over theme overrides, so the accent has to go
			# into a copy of the settings rather than beside them.
			var tinted: LabelSettings = detail_settings.duplicate()
			tinted.font_color = style.accent
			_rarity.label_settings = tinted
	if panel != null:
		_card.add_theme_stylebox_override(&"panel", panel)

	_spawn_vfx(style)

	# Measure now that there is text to measure. resized then recentres.
	_card.reset_size()
	_recentre()


## Rarity as a word. Falls back to the enum name, so an unconfigured tier still
## says "Legendary" rather than "4".
func _rarity_name(style: RarityStyle) -> String:
	if style != null and style.display_name != "":
		return style.display_name
	if data == null:
		return ""
	var names: Array = FishData.Rarity.keys()
	var tier: int = int(data.rarity)
	return str(names[tier]) if tier >= 0 and tier < names.size() else ""


func _build() -> void:
	_vfx_anchor = Marker2D.new()
	add_child(_vfx_anchor)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(min_width, 0.0)
	# A Control inside a Node2D gets no layout pass, so the card sizes itself
	# and repositions whenever that size changes.
	_card.resized.connect(_recentre)
	add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", padding)
	margin.add_theme_constant_override(&"margin_right", padding)
	margin.add_theme_constant_override(&"margin_top", padding)
	margin.add_theme_constant_override(&"margin_bottom", padding)
	_card.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", line_spacing)
	margin.add_child(rows)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.visible = show_title
	if title_settings != null:
		title.label_settings = title_settings
	rows.add_child(title)

	var art_box := CenterContainer.new()
	_art = TextureRect.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if art_size == Vector2.ZERO:
		_art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	else:
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.custom_minimum_size = art_size
	art_box.add_child(_art)
	rows.add_child(art_box)

	_name = _detail_label()
	rows.add_child(_name)
	_rarity = _detail_label()
	rows.add_child(_rarity)
	_size = _detail_label()
	rows.add_child(_size)


func _detail_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if detail_settings != null:
		l.label_settings = detail_settings
	return l


func _recentre() -> void:
	if _card != null:
		_card.position = -_card.size * 0.5 + card_offset


func _spawn_vfx(style: RarityStyle) -> void:
	if style == null or style.particles == null:
		return
	var vfx := style.particles.instantiate()
	_vfx_anchor.add_child(vfx)
	if vfx is GPUParticles2D or vfx is CPUParticles2D:
		vfx.emitting = true
