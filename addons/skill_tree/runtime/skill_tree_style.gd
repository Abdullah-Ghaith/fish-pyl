@tool
class_name SkillTreeStyle extends Resource
## Every visual choice in one swappable resource. Leave anything empty and the
## view falls back to a built-in grey-box, so a tree is legible before art
## exists. Swap the whole resource to re-skin a tree, or assign a Material to
## drop a shader onto every node or link.
##
## It also owns the link and lock *drawing*, so the editor canvas and the
## runtime view cannot drift apart: what you author is what ships.

@export_group("Anchors")
## The guide dots. Editor-only by default - they are scaffolding, not art.
@export var show_anchors_in_game: bool = false
@export var anchor_radius: float = 6.0
@export var anchor_line_width: float = 2.0
@export var anchor_color: Color = Color(1, 1, 1, 0.18)
## Drawn instead of the circle when set, centred on the anchor.
@export var anchor_texture: Texture2D

@export_group("Nodes")
@export var node_size: Vector2 = Vector2(52, 52)
## Inset between the node's edge and its icon.
@export var icon_margin: float = 8.0
## One StyleBox per state. Any left empty uses a generated flat box.
@export var node_locked: StyleBox
@export var node_gated: StyleBox
@export var node_available: StyleBox
@export var node_purchased: StyleBox
@export var node_maxed: StyleBox
## Extra box drawn on top while hovered - a glow or outline.
@export var node_hover_overlay: StyleBox
## Multiplied in when a node is buyable but you cannot afford it.
@export var unaffordable_modulate: Color = Color(1, 1, 1, 0.5)
## Dropped onto every node Control. Your shader goes here.
@export var node_material: Material
## Rank pips for multi-rank nodes. Set to 0 to hide them.
@export var rank_pip_radius: float = 2.5
@export var rank_pip_filled: Color = Color(1, 1, 1, 0.9)
@export var rank_pip_empty: Color = Color(1, 1, 1, 0.25)

@export_group("Links")
@export var link_width: float = 4.0
@export var link_locked_color: Color = Color(1, 1, 1, 0.12)
@export var link_gated_color: Color = Color(1.0, 0.82, 0.25, 0.65)
@export var link_open_color: Color = Color(1, 1, 1, 0.3)
@export var link_satisfied_color: Color = Color(0.45, 1.0, 0.65, 0.9)
## Drawn behind the link at a wider size, for an outline or bloom.
@export var link_outline_width: float = 0.0
@export var link_outline_color: Color = Color(0, 0, 0, 0.5)

@export_subgroup("Dashes")
## One dash and the gap after it. Links are drawn as a run of dashes marching
## from the prerequisite to the node it unlocks - that is what shows direction,
## so there is no arrowhead for a node to cover.
@export var link_dash_length: float = 14.0
@export var link_dash_gap: float = 9.0
## Dashes start thin at the prerequisite and reach full width at the target.
## 0 = uniform, 0.95 = nearly a point at the tail.
@export_range(0.0, 0.95, 0.01) var link_dash_taper: float = 0.45
## Pixels per second the pattern marches toward the target. 0 = static.
## Ignored in the editor so authoring never spins the CPU.
@export var link_dash_speed: float = 0.0
## Clearance kept between the dash run and each node's edge.
@export var link_end_gap: float = 4.0
## Hand the whole link to `link_material` instead: each link becomes one quad
## whose UV.x counts dash periods and whose UV.y crosses the line, so a shader
## owns the dashes. See shaders/link_dash.gdshader.
@export var link_shader_strip: bool = false
## Shader for the link layer, e.g. an energy flow along satisfied paths.
@export var link_material: Material

@export_group("Lock Badge")
@export var lock_closed_icon: Texture2D
@export var lock_open_icon: Texture2D
@export var lock_size: Vector2 = Vector2(24, 24)
@export var lock_closed_color: Color = Color(1.0, 0.78, 0.12)
@export var lock_open_color: Color = Color(0.45, 1.0, 0.6)
## Disc drawn behind the badge. The dash run is broken around it, so the gate
## reads as a real interruption of the path rather than a sticker on top of it.
@export var lock_backdrop_color: Color = Color(0.05, 0.05, 0.07, 0.95)
@export var lock_ring_width: float = 2.5
## Extra space cleared around the badge, on top of its own radius.
@export var lock_clearance: float = 5.0

@export_group("Tooltip")
## MAXIMUM width, in pixels. Short tooltips hug their text; only text longer
## than this wraps. (The measuring is not optional decoration - a RichTextLabel
## with autowrap on reports a 1px minimum width, and Godot shrinks a tooltip to
## its minimum size, so an unmeasured tooltip is either a sliver or always this
## wide.)
@export var tooltip_width: float = 300.0
## Blank out the background of the PopupPanel the engine wraps the tooltip in.
## Its default is 50% black with an 8/2/8/2 gutter, which otherwise shows as a
## grey border around whatever you set in tooltip_panel. Turn this off only if
## you want the engine's tooltip frame back.
@export var tooltip_hide_popup_background: bool = true
## Inner padding. Animated BBCode effects push glyphs outside their line box,
## so [wave] and [tornado] need room here or they clip.
@export var tooltip_padding: float = 12.0
## Leave empty to inherit the theme's PanelContainer look.
@export var tooltip_panel: StyleBox
## Base text colour, overriding whatever the theme's RichTextLabel would use.
## BBCode [color=...] inside a description still wins over this.
@export var tooltip_text_color: Color = Color(0.92, 0.94, 1.0)
## The rank counter next to the title.
@export var tooltip_dim_color: Color = Color(0.65, 0.70, 0.78)
## The auto-generated "what this skill does" line.
@export var tooltip_effect_color: Color = Color(0.5, 0.95, 0.7)
@export var tooltip_cost_color: Color = Color(1.0, 0.82, 0.35)
@export var tooltip_warn_color: Color = Color(1.0, 0.55, 0.45)

@export_group("UI")
## Applied to SkillTreeView, so its labels and tooltips inherit your project's
## look without the addon knowing anything about it.
@export var ui_theme: Theme


var _placeholders: Dictionary = {}


## StyleBox for a node state, generating a placeholder if none was assigned.
func box_for(state: SkillTree.NodeState) -> StyleBox:
	var assigned: StyleBox = null
	match state:
		SkillTree.NodeState.LOCKED: assigned = node_locked
		SkillTree.NodeState.GATED: assigned = node_gated
		SkillTree.NodeState.AVAILABLE: assigned = node_available
		SkillTree.NodeState.PURCHASED: assigned = node_purchased
		SkillTree.NodeState.MAXED: assigned = node_maxed
	if assigned != null:
		return assigned
	if not _placeholders.has(state):
		_placeholders[state] = _placeholder_box(state)
	return _placeholders[state]


func link_color(satisfied: bool, gated: bool, reachable: bool) -> Color:
	if satisfied:
		return link_satisfied_color
	if gated:
		return link_gated_color
	if reachable:
		return link_open_color
	return link_locked_color


# --- link drawing -------------------------------------------------------------

## One dash plus its gap. Never zero, so callers can divide by it.
func dash_period() -> float:
	return maxf(1.0, link_dash_length + link_dash_gap)


## Radius of clear space a lock badge wants around itself.
func lock_clear_radius() -> float:
	return lock_disc_radius() + lock_clearance


## Radius of the badge's backdrop disc.
func lock_disc_radius() -> float:
	return maxf(lock_size.x, lock_size.y) * 0.62


## Distance from a rect's centre to its edge along `dir`. Links are trimmed by
## this so they stop at the node border instead of running under the node.
func rect_exit(dir: Vector2, half: Vector2) -> float:
	var tx: float = INF if is_zero_approx(dir.x) else half.x / absf(dir.x)
	var ty: float = INF if is_zero_approx(dir.y) else half.y / absf(dir.y)
	return minf(tx, ty)


## One link, as a run of tapered dashes between two node borders.
##
## `phase` scrolls the pattern in pixels toward the target. `hole_at` /
## `hole_radius` punch a gap in the run, which is how the lock badge gets clean
## space; pass a radius of 0 for an unbroken run.
func draw_link_dashes(ci: CanvasItem, a: Vector2, b: Vector2, col: Color,
		width: float, phase: float = 0.0, hole_at: Vector2 = Vector2.ZERO,
		hole_radius: float = 0.0) -> void:
	var to_b: Vector2 = b - a
	var span: float = to_b.length()
	if span <= 0.001 or width <= 0.0:
		return
	var dir: Vector2 = to_b / span
	var inset: float = rect_exit(dir, node_size * 0.5) + link_end_gap
	var run: float = span - inset * 2.0
	if run <= 0.0:
		return
	var origin: Vector2 = a + dir * inset

	if run < link_dash_length * 0.75:
		# Neighbouring cells: no room to dash, so draw one stub instead of a
		# single lonely dash that reads as a rendering glitch.
		ci.draw_line(origin, origin + dir * run, col, width, true)
		return

	var hole_lo: float = -1.0
	var hole_hi: float = -1.0
	if hole_radius > 0.0:
		var centre: float = (hole_at - origin).dot(dir)
		hole_lo = centre - hole_radius
		hole_hi = centre + hole_radius

	var period: float = dash_period()
	var taper: float = clampf(link_dash_taper, 0.0, 0.95)
	# Anchored to the target end, so the leading dash always lands on the node
	# border no matter how long the link is.
	var head: float = run - fposmod(phase, period)
	while head > 0.0:
		var d1: float = minf(head, run)
		var d0: float = maxf(0.0, head - link_dash_length)
		head -= period
		if d1 - d0 <= 0.5:
			continue
		if d1 > hole_lo and d0 < hole_hi:
			continue
		var t: float = ((d0 + d1) * 0.5) / run
		ci.draw_line(origin + dir * d0, origin + dir * d1, col,
				width * lerpf(1.0 - taper, 1.0, t), true)


## One link as a single quad with arc-length UVs, so `link_material`'s shader
## owns the whole look. UV.x counts dash periods from the prerequisite; UV.y
## goes 0..1 across the width.
func draw_link_strip(ci: CanvasItem, a: Vector2, b: Vector2, col: Color,
		width: float) -> void:
	var to_b: Vector2 = b - a
	var span: float = to_b.length()
	if span <= 0.001 or width <= 0.0:
		return
	var dir: Vector2 = to_b / span
	var inset: float = rect_exit(dir, node_size * 0.5) + link_end_gap
	var run: float = span - inset * 2.0
	if run <= 0.0:
		return
	var p0: Vector2 = a + dir * inset
	var p1: Vector2 = p0 + dir * run
	var n: Vector2 = dir.orthogonal() * (width * 0.5)
	var u: float = run / dash_period()
	ci.draw_colored_polygon(
			PackedVector2Array([p0 + n, p1 + n, p1 - n, p0 - n]), col,
			PackedVector2Array([Vector2(0, 0), Vector2(u, 0), Vector2(u, 1), Vector2(0, 1)]))


## The gate badge. Deliberately loud - a dark disc, a bright ring and a chunky
## padlock - because a gate nobody notices is a gate that reads as a bug.
## `scale` lets the editor canvas keep it a constant size while zooming.
func draw_lock(ci: CanvasItem, at: Vector2, open: bool,
		icon: Texture2D = null, scale: float = 1.0) -> void:
	var s: Vector2 = lock_size * scale
	var col: Color = lock_open_color if open else lock_closed_color
	var r: float = lock_disc_radius() * scale

	if lock_backdrop_color.a > 0.0:
		ci.draw_circle(at, r, lock_backdrop_color)
	if lock_ring_width > 0.0:
		ci.draw_arc(at, r, 0.0, TAU, 32, Color(col, col.a * 0.95),
				lock_ring_width * scale, true)

	var tex: Texture2D = icon
	if tex == null:
		tex = lock_open_icon if open else lock_closed_icon
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(at - s * 0.5, s), false, col)
		return

	# No art yet: a bold padlock, drawn dark-first so it keeps its shape even
	# on top of a bright ring or a satisfied link.
	var body := Rect2(at.x - s.x * 0.30, at.y - s.y * 0.04, s.x * 0.60, s.y * 0.38)
	var shackle_c := Vector2(at.x, body.position.y)
	var shackle_r: float = s.x * 0.20
	var arc_from: float = PI * (1.18 if open else 1.0)
	var thick: float = maxf(2.0, s.x * 0.13)
	var shadow := Color(0.02, 0.02, 0.03, 0.7)

	ci.draw_rect(body.grow(1.5), shadow)
	ci.draw_arc(shackle_c, shackle_r, arc_from, arc_from + PI * 0.85, 20,
			shadow, thick + 3.0, true)
	ci.draw_rect(body, col)
	ci.draw_arc(shackle_c, shackle_r, arc_from, arc_from + PI * 0.85, 20,
			col, thick, true)
	# Keyhole, so it reads as a padlock and not a mailbox.
	ci.draw_circle(body.get_center(), maxf(1.5, s.x * 0.075),
			Color(0.06, 0.06, 0.08, 0.95))


func _placeholder_box(state: SkillTree.NodeState) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	box.set_border_width_all(2)
	box.border_color = Color(1, 1, 1, 0.75)
	match state:
		SkillTree.NodeState.LOCKED:
			box.bg_color = Color(0.10, 0.10, 0.13, 0.85)
			box.border_color = Color(1, 1, 1, 0.22)
		SkillTree.NodeState.GATED:
			box.bg_color = Color(0.20, 0.16, 0.05, 0.9)
			box.border_color = Color(1.0, 0.82, 0.25, 0.8)
		SkillTree.NodeState.AVAILABLE:
			box.bg_color = Color(0.12, 0.16, 0.22, 0.95)
			box.border_color = Color(0.75, 0.9, 1.0, 0.9)
		SkillTree.NodeState.PURCHASED:
			box.bg_color = Color(0.10, 0.22, 0.15, 0.95)
			box.border_color = Color(0.45, 1.0, 0.65, 0.9)
		SkillTree.NodeState.MAXED:
			box.bg_color = Color(0.16, 0.26, 0.12, 0.98)
			box.border_color = Color(0.85, 1.0, 0.4, 1.0)
	return box
