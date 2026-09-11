@tool
class_name DayNightCycle extends CanvasModulate
## The face of the day/night cycle: reads the [b]TimeOfDay[/b] autoload and
## paints the world with it.
##
## Drop one of these anywhere in a level scene. A CanvasModulate tints every
## canvas item in its canvas, so the tilemap, the player, the fish and the
## rod all shift together and nothing needs to know the cycle exists. The UI
## sits on its own CanvasLayer and stays readable.
##
## The water is done separately: its shader reads the screen behind it, so it
## already picks up the tint above - what it cannot pick up is its own colour,
## hence the second gradient driving the shader's [code]tint[/code] uniform.
##
## This node also configures the clock on ready, so the day length and the
## phase boundaries are editable in the inspector rather than buried in the
## autoload.

@export_group("Clock")
## Push the settings below into the TimeOfDay autoload on ready. Turn this off
## if a second scene owns the clock, or if you set it from code.
@export var configure_clock: bool = true
## Real seconds in one in-game day.
@export var day_length_seconds: float = 480.0
## The hour the level starts at.
@export_range(0.0, 24.0, 0.25) var start_hour: float = 8.0
## Start with the clock frozen - useful while building a level.
@export var start_paused: bool = false

@export_subgroup("Phase boundaries", "boundary_")
## Each phase runs from its own start to the next one's, wrapping at midnight.
@export_range(0.0, 24.0, 0.25) var boundary_dawn: float = 5.0
@export_range(0.0, 24.0, 0.25) var boundary_day: float = 8.0
@export_range(0.0, 24.0, 0.25) var boundary_dusk: float = 18.0
@export_range(0.0, 24.0, 0.25) var boundary_night: float = 21.0

@export_group("Sky")
## Colour of the world across the day, sampled at time-of-day (0 = midnight,
## 0.5 = noon). Leave empty for the built-in one. Keep the first and last stops
## the same colour or midnight will jump.
@export var sky_gradient: Gradient:
	set(v):
		sky_gradient = v
		_refresh_preview()
## How much of the gradient to apply, 0 = no tint at all. Turn it down if the
## nights come out too dark to fish in.
@export_range(0.0, 1.0, 0.01) var sky_strength: float = 1.0:
	set(v):
		sky_strength = v
		_refresh_preview()

@export_group("Water")
@export var tint_water: bool = true
## The Polygon2D carrying the water shader. The default path is where it sits
## in main.tscn.
@export var water_polygon_path: NodePath = ^"../WaterBody/WaterPolygon"
## Name of the shader uniform to drive - the water shader calls it "tint".
@export var water_shader_parameter: StringName = &"tint"
## Water colour across the day. Leave empty for the built-in one.
@export var water_gradient: Gradient:
	set(v):
		water_gradient = v
		_water_lookup_done = false
		_refresh_preview()

@export_group("Editor preview")
## Scrub this to see the level at an hour of the day. Editor only - the clock
## takes over as soon as the game runs.
@export_range(0.0, 24.0, 0.25) var preview_hour: float = 8.0:
	set(v):
		preview_hour = v
		_refresh_preview()

var _clock: Node = null
var _water_material: ShaderMaterial = null
var _water_lookup_done: bool = false
# Built on demand and never written back to the exported properties - assigning
# to an @export from _ready would bake a copy into whatever scene this sits in
# the moment the editor next saves it.
var _sky_fallback: Gradient = null
var _water_fallback: Gradient = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply(preview_hour / 24.0)
		return

	_clock = get_node_or_null(^"/root/TimeOfDay")
	if _clock == null:
		push_warning("DayNightCycle: no TimeOfDay autoload - "
				+ "add it in Project Settings > Autoload. Holding at start_hour.")
		_apply(start_hour / 24.0)
		return

	if configure_clock:
		_clock.day_length = day_length_seconds
		_clock.dawn_start = boundary_dawn
		_clock.day_start = boundary_day
		_clock.dusk_start = boundary_dusk
		_clock.night_start = boundary_night
		_clock.paused = start_paused
		_clock.set_hour(start_hour)

	_apply(_clock.time)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _clock == null:
		return
	_apply(_clock.time)


# --- painting ----------------------------------------------------------------

## [param t] is time of day, 0..1, 0 = midnight.
func _apply(t: float) -> void:
	var at: float = fposmod(t, 1.0)
	color = Color.WHITE.lerp(_sky().sample(at), sky_strength)
	# Skipped in the editor on purpose: the water material is a sub-resource of
	# water_body.tscn, so writing to it from a preview would dirty that scene.
	if tint_water and not Engine.is_editor_hint():
		var mat := _get_water_material()
		if mat != null:
			mat.set_shader_parameter(water_shader_parameter, _water().sample(at))


## The gradient in the inspector when there is one, the built-in otherwise.
func _sky() -> Gradient:
	if sky_gradient != null:
		return sky_gradient
	if _sky_fallback == null:
		_sky_fallback = _default_sky_gradient()
	return _sky_fallback


func _water() -> Gradient:
	if water_gradient != null:
		return water_gradient
	if _water_fallback == null:
		_water_fallback = _default_water_gradient()
	return _water_fallback


## Looked up once and then remembered, failure included - this runs every frame,
## and a missed lookup that retried would also re-warn sixty times a second.
func _get_water_material() -> ShaderMaterial:
	if _water_lookup_done:
		return _water_material
	_water_lookup_done = true
	var node := get_node_or_null(water_polygon_path) as CanvasItem
	if node == null:
		push_warning("DayNightCycle: nothing at %s, so the water is not tinted."
				% water_polygon_path)
		return null
	_water_material = node.material as ShaderMaterial
	if _water_material == null:
		push_warning("DayNightCycle: %s has no ShaderMaterial to tint." % water_polygon_path)
	return _water_material


## The editor preview writes to `color`, which is a saved property - so hand the
## scene back its white before it is written to disk and re-tint afterwards.
## Without this, merely opening a level would leave a tint baked into the .tscn.
func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		color = Color.WHITE
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_apply(preview_hour / 24.0)


func _refresh_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	_apply(preview_hour / 24.0)


# --- built-in gradients ------------------------------------------------------
# Offsets are fractions of a day, so 0.25 is 6am. Both gradients start and end
# on the same colour so midnight is seamless.

func _default_sky_gradient() -> Gradient:
	return _make_gradient(
		[0.0, 0.19, 0.25, 0.35, 0.70, 0.78, 0.86, 1.0],
		[
			Color(0.26, 0.31, 0.58),   # 00:00 night
			Color(0.30, 0.34, 0.60),   # 04:30 still night
			Color(0.86, 0.66, 0.62),   # 06:00 dawn, warm and low
			Color(1.00, 1.00, 1.00),   # 08:24 full day, no tint at all
			Color(1.00, 0.97, 0.90),   # 16:48 afternoon goes slightly golden
			Color(0.95, 0.62, 0.45),   # 18:43 dusk
			Color(0.38, 0.36, 0.58),   # 20:38 dropping into night
			Color(0.26, 0.31, 0.58),   # 24:00 back to the first stop
		])


func _default_water_gradient() -> Gradient:
	return _make_gradient(
		[0.0, 0.19, 0.25, 0.35, 0.70, 0.78, 0.86, 1.0],
		[
			Color(0.05, 0.22, 0.45),   # night water, deep and cold
			Color(0.06, 0.26, 0.50),
			Color(0.35, 0.72, 0.85),   # dawn
			Color(0.12, 1.00, 1.00),   # the original daytime cyan
			Color(0.12, 1.00, 1.00),
			Color(0.55, 0.65, 0.80),   # dusk pulls the cyan out
			Color(0.09, 0.32, 0.55),
			Color(0.05, 0.22, 0.45),
		])


func _make_gradient(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	# set_offsets resizes the point list, so offsets must go in first.
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g
