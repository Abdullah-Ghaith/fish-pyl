extends Node
## The autoload owner of the in-game clock.
##
## The whole cycle is one float: [member time], 0..1 across a day, 0.0 = midnight.
## Hours, the current phase and phase blending are all derived from it, so there
## is only ever one number to save, scrub or fake.
##
## Nothing in here draws. The visuals live on [DayNightCycle], which reads this
## clock and drives a CanvasModulate; the fish read it through
## [method FishData.phase_weights]. That split is deliberate - the clock keeps
## running with no level loaded, which is what makes the debug keys and any
## future "sleep until morning" sane.


## Emitted the moment the clock crosses a phase boundary. Both arguments are
## [enum Phase] values - untyped here only because signal argument types are
## fussier than they look.
signal phase_changed(from: int, to: int)
## Emitted when the clock wraps past midnight. [param day] is the new day index.
signal day_changed(day: int)

enum Phase { DAWN, DAY, DUSK, NIGHT }

const PHASE_NAMES := ["Dawn", "Day", "Dusk", "Night"]
const PHASE_COUNT: int = 4

# --- configuration -----------------------------------------------------------
# Set these from DayNightCycle in the inspector, or here for the defaults.

## Real seconds in one in-game day. 480 = an eight minute day.
var day_length: float = 480.0
## Multiplies the passage of time. The debug fast-forward moves this, so leave
## it at 1.0 and use [member paused] to stop the clock.
var time_scale: float = 1.0
## Freezes the clock where it stands. Time can still be moved by hand.
var paused: bool = false

## Phase boundaries, in hours. Each phase runs from its own start to the start
## of the next, wrapping at midnight, so night is night_start..dawn_start.
var dawn_start: float = 5.0
var day_start: float = 8.0
var dusk_start: float = 18.0
var night_start: float = 21.0

## Debug keys, on in debug builds only:
##   [ and ]  - step back / forward one hour
##   \        - cycle fast-forward 1x -> 10x -> 60x
var debug_keys: bool = OS.is_debug_build()

# --- state -------------------------------------------------------------------

## Where we are in the day, 0..1, 0.0 = midnight.
var time: float = 8.0 / 24.0
## Days elapsed since the game started. Purely a counter - nothing reads it yet.
var day: int = 0

var _phase: int = Phase.DAY


func _ready() -> void:
	_phase = current_phase()
	# The clock must keep ticking while the skill tree is open, otherwise a long
	# menu session makes the day stutter.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if paused or day_length <= 0.0:
		return
	advance_days(delta * time_scale / day_length)


# --- moving time -------------------------------------------------------------

## Push the clock forward by a fraction of a day. Negative rewinds.
func advance_days(days: float) -> void:
	if is_zero_approx(days):
		return
	var raw: float = time + days
	var crossed: int = int(floor(raw))
	time = fposmod(raw, 1.0)
	if crossed != 0:
		day += crossed
		day_changed.emit(day)
	_settle_phase()


## Push the clock forward by in-game hours. Negative rewinds.
func advance_hours(hours: float) -> void:
	advance_days(hours / 24.0)


## Jump to a point in the day, 0..1. Does not touch the day counter.
func set_time(t: float) -> void:
	time = fposmod(t, 1.0)
	_settle_phase()


## Jump to an hour, 0..24.
func set_hour(h: float) -> void:
	set_time(h / 24.0)


## Jump to the start of a phase - the one call a "sleep until morning" needs.
func skip_to_phase(phase: int) -> void:
	set_hour(phase_start(phase))


## Jump forward to the next time this hour comes round, so 6.0 at 9pm lands on
## tomorrow morning rather than rewinding. Rolls the day counter as it passes
## midnight, which is what makes it the right call for sleeping.
func skip_forward_to_hour(h: float) -> void:
	advance_hours(fposmod(h - hour(), 24.0))


# --- reading time ------------------------------------------------------------

## The current hour, 0..24, with a fraction.
func hour() -> float:
	return time * 24.0


## "07:45", for a clock widget or a debug label.
func clock_string() -> String:
	var total: int = int(round(time * 1440.0)) % 1440
	return "%02d:%02d" % [total / 60, total % 60]


## The phase the clock is in right now, as an [enum Phase] value.
func current_phase() -> int:
	var h: float = hour()
	for i in PHASE_COUNT:
		if fposmod(h - phase_start(i), 24.0) < phase_length(i):
			return i
	return Phase.DAY


func phase_name() -> String:
	return PHASE_NAMES[current_phase()]


## The hour a phase begins at.
func phase_start(phase: int) -> float:
	match phase:
		Phase.DAWN: return dawn_start
		Phase.DAY: return day_start
		Phase.DUSK: return dusk_start
		_: return night_start


## How many hours a phase lasts, wrapping past midnight where it has to.
func phase_length(phase: int) -> float:
	var next_start: float = phase_start((phase + 1) % PHASE_COUNT)
	var span: float = fposmod(next_start - phase_start(phase), 24.0)
	# Four boundaries set to the same hour would make every phase zero-length
	# and current_phase() fall through. Treat that as "one phase, all day".
	return 24.0 if is_zero_approx(span) else span


## The middle of a phase - the hour at which a phase-tagged value is at full
## strength. [method blend] fades between these.
func phase_centre(phase: int) -> float:
	return fposmod(phase_start(phase) + phase_length(phase) * 0.5, 24.0)


## How far into the current phase we are, 0..1. Handy for a sun position or a
## phase progress bar.
func phase_progress() -> float:
	var phase: int = current_phase()
	var length: float = phase_length(phase)
	if length <= 0.0:
		return 0.0
	return clampf(fposmod(hour() - phase_start(phase), 24.0) / length, 0.0, 1.0)


## Four numbers in, one number out: given a value per phase - indexed by
## [enum Phase] - return the value for right now, eased between the centres of
## the two phases we sit between.
##
## This is what stops a night fish vanishing the instant the clock ticks past
## dusk. Its weight falls off across the evening instead, and the spawner sees a
## curve rather than a switch.
func blend(values: PackedFloat32Array) -> float:
	if values.size() < PHASE_COUNT:
		return 1.0
	var h: float = hour()
	for i in PHASE_COUNT:
		var j: int = (i + 1) % PHASE_COUNT
		var span: float = fposmod(phase_centre(j) - phase_centre(i), 24.0)
		var into: float = fposmod(h - phase_centre(i), 24.0)
		if span <= 0.0:
			continue
		if into <= span:
			return lerpf(values[i], values[j], smoothstep(0.0, 1.0, into / span))
	return values[current_phase()]


# --- persistence -------------------------------------------------------------
# Not wired to Progression's save file yet; call these from it when you want the
# clock to survive a reload.

func to_dict() -> Dictionary:
	return {"time": time, "day": day}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 0))
	set_time(float(data.get("time", time)))


# --- internals ---------------------------------------------------------------

func _settle_phase() -> void:
	var now: int = current_phase()
	if now == _phase:
		return
	var was: int = _phase
	_phase = now
	phase_changed.emit(was, now)


func _unhandled_key_input(event: InputEvent) -> void:
	if not debug_keys:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_BRACKETRIGHT:
			advance_hours(1.0)
		KEY_BRACKETLEFT:
			advance_hours(-1.0)
		KEY_BACKSLASH:
			time_scale = 10.0 if is_equal_approx(time_scale, 1.0) \
					else (60.0 if is_equal_approx(time_scale, 10.0) else 1.0)
			print("TimeOfDay: %sx" % time_scale)
			get_viewport().set_input_as_handled()
			return
		_:
			return
	print("TimeOfDay: %s (%s)" % [clock_string(), phase_name()])
	get_viewport().set_input_as_handled()
