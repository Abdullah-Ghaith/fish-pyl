class_name CatchEntry extends Node2D
## One fish's catch card, built by CatchDisplay.
##
## The card is a Control tree so it sizes itself around whatever the fish's
## name turns out to be, but the root stays a Node2D: CatchDisplay tweens
## `scale`, `position:y` and `modulate:a` on it, and all three propagate down
## to Control children for free.
##
## Nothing here is laid out in the scene - the .tscn is a bare Node2D. Auto
## layout is the whole point, and a hand-placed Label would fight it.

## Which part of the card sits on this node's origin.
enum CardAnchor {
	CENTRE,  ## Centred - a taller card grows up AND down, over the player.
	BOTTOM,  ## Bottom edge on the origin - the card only ever grows upward.
}

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
## Where the card sits relative to this node. BOTTOM is the answer to "a big
## card swallows the player": the bottom edge stays put and extra height goes
## upward, so scaling a tier up needs no offset tuning at all.
@export var card_anchor: CardAnchor = CardAnchor.CENTRE
## Card position relative to this node's origin, after anchoring. RarityStyle
## can add a per-tier nudge on top.
@export var card_offset: Vector2 = Vector2(0, -6)

@export_group("Content")
@export var show_title: bool = true
@export var title_text: String = "Fish Caught!"
## Art box for the fish. Zero = native size, which is the crisp option. If you
## set one, use an integer multiple of your fish sprites or the pixels smear.
@export var art_size: Vector2 = Vector2.ZERO
@export var show_value: bool = true
## %d is the size-adjusted price from the CatchRecord.
@export var value_format: String = "%d g"

@export_group("VFX")
## Particles spawn on top of the card by default. Children draw in tree order,
## so an anchor added before the panel is painted straight over by it - which
## is exactly what "the vfx disappeared" looks like.
@export var vfx_in_front: bool = true
## Centre the particles on the fish art rather than on the card's origin.
@export var vfx_on_art: bool = true

@export_group("Text")
## Used for the title line. The fish's name uses RarityStyle.label_settings.
@export var title_settings: LabelSettings
## Used for the rarity, size and value lines. Its colour is replaced by the
## tier's accent on the rarity line, and by value_color on the price.
@export var detail_settings: LabelSettings
@export var value_color: Color = Color(1.0, 0.85, 0.35)

var data: FishData = null
var record: CatchRecord = null
## What CatchDisplay should pop this card up to, taken from the tier's
## RarityStyle. The scale lives on this Node2D rather than on the card Control
## so that _recentre() and the vfx anchors can keep working in unscaled local
## space - which is the whole reason this is a Node2D root.
var target_scale: Vector2 = Vector2.ONE

var _card: PanelContainer
var _title: Label
var _art: TextureRect
var _name: Label
var _rarity: Label
var _size: Label
var _value: Label
var _vfx_back: Marker2D
var _vfx_front: Marker2D
var _vfx: Node = null
var _offset: Vector2 = Vector2.ZERO


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
	_value.text = value_format % record.value
	_value.visible = show_value and record.value > 0

	var panel: StyleBox = card_panel
	_title.visible = show_title
	_card.custom_minimum_size = Vector2(min_width, 0.0)
	_offset = card_offset
	if style != null:
		target_scale = Vector2.ONE * maxf(0.05, style.card_scale)
		scale = target_scale
		_offset = card_offset + style.card_offset_extra
		if style.card_title != RarityStyle.Toggle.INHERIT:
			_title.visible = style.card_title == RarityStyle.Toggle.ON
		if style.card_min_width > 0.0:
			_card.custom_minimum_size = Vector2(style.card_min_width, 0.0)
		if style.card_panel != null:
			panel = style.card_panel
		if style.label_settings != null:
			_name.label_settings = style.label_settings
		_art.modulate = style.tint
		_tint_label(_rarity, style.accent)
	if panel != null:
		_card.add_theme_stylebox_override(&"panel", panel)
	_tint_label(_value, value_color)

	# Built but NOT emitting - CatchDisplay calls play_vfx() once the pop-in
	# tween has landed. Emitting during the tween sprays particles from
	# wherever the card happened to be on its way up.
	_spawn_vfx(style)

	# Measure now that there is text to measure. resized then recentres, which
	# is also what puts the vfx anchors over the art.
	_card.reset_size()
	_recentre()


## LabelSettings wins over theme colour overrides, so a colour has to go INTO a
## copy of the settings rather than beside them.
func _tint_label(label: Label, col: Color) -> void:
	if detail_settings != null:
		var tinted: LabelSettings = detail_settings.duplicate()
		tinted.font_color = col
		label.label_settings = tinted
	else:
		label.add_theme_color_override(&"font_color", col)


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
	# Behind the card, for a glow that spills past the frame.
	_vfx_back = Marker2D.new()
	add_child(_vfx_back)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(min_width, 0.0)
	add_child(_card)

	# In front of the card. Added after it, which is the whole trick.
	_vfx_front = Marker2D.new()
	add_child(_vfx_front)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", padding)
	margin.add_theme_constant_override(&"margin_right", padding)
	margin.add_theme_constant_override(&"margin_top", padding)
	margin.add_theme_constant_override(&"margin_bottom", padding)
	_card.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", line_spacing)
	margin.add_child(rows)

	_title = Label.new()
	_title.text = title_text
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.visible = show_title
	if title_settings != null:
		_title.label_settings = title_settings
	rows.add_child(_title)

	var art_box := CenterContainer.new()
	_art = TextureRect.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if art_size == Vector2.ZERO:
		_art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	else:
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.custom_minimum_size = art_size
	# Container layout is deferred, so the art's rect is still (0,0,0,0) at the
	# end of setup(). This fires when it finally settles - and again on any
	# later reflow - which is what keeps the particles on the fish.
	_art.item_rect_changed.connect(_place_vfx)
	art_box.add_child(_art)
	rows.add_child(art_box)

	_name = _detail_label()
	rows.add_child(_name)
	_rarity = _detail_label()
	rows.add_child(_rarity)

	_size = _detail_label()
	rows.add_child(_size)
	_value = _detail_label()
	rows.add_child(_value)

	# Connected last, on purpose. A Control inside a Node2D gets no layout pass,
	# so the card sizes itself and repositions whenever that size changes - but
	# add_child(_card) above already fires `resized` synchronously, and back then
	# the nodes this handler touches did not exist yet.
	_card.resized.connect(_recentre)


func _detail_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if detail_settings != null:
		l.label_settings = detail_settings
	return l


func _recentre() -> void:
	if _card == null:
		return
	var origin := -_card.size * 0.5
	if card_anchor == CardAnchor.BOTTOM:
		origin = Vector2(-_card.size.x * 0.5, -_card.size.y)
	_card.position = origin + _offset
	_place_vfx()


func _place_vfx() -> void:
	if _card == null or _vfx_front == null or _vfx_back == null:
		return
	# Card centre is the fallback. Before the deferred layout pass runs, every
	# container inside the card is still at (0,0) with zero size, and trusting
	# that put the particles on the card's top-left corner.
	var at: Vector2 = _card.position + _card.size * 0.5
	if vfx_on_art and _art != null and _art.size != Vector2.ZERO:
		at = _local_centre_of(_art)
	_vfx_back.position = at
	_vfx_front.position = at


## Where a Control inside the card sits in this Node2D's coordinates. Walks the
## parent chain rather than using to_local(), which would divide by the entry's
## scale - and CatchDisplay tweens that from zero.
func _local_centre_of(c: Control) -> Vector2:
	var p: Vector2 = c.position + c.size * 0.5
	var n: Node = c.get_parent()
	while n is Control and n != _card:
		p += (n as Control).position
		n = n.get_parent()
	return _card.position + p


func _spawn_vfx(style: RarityStyle) -> void:
	if style == null or style.particles == null:
		return
	var vfx := style.particles.instantiate()
	var anchor: Marker2D = _vfx_front if vfx_in_front else _vfx_back
	# Off first, so nothing emits from the card's starting position. Some
	# particle scenes ship with emitting already true.
	if vfx is GPUParticles2D or vfx is CPUParticles2D:
		vfx.emitting = false
	anchor.add_child(vfx)
	_vfx = vfx


## Start the burst. Called by CatchDisplay once the card has finished moving,
## so the particles come from where the fish ends up rather than from the
## bottom of its rise. Safe to call twice.
func play_vfx() -> void:
	if _vfx == null or not is_instance_valid(_vfx):
		return
	if _vfx is GPUParticles2D or _vfx is CPUParticles2D:
		if _vfx.emitting:
			return
		_vfx.restart()
		_vfx.emitting = true
