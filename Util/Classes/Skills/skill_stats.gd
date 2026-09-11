class_name SkillStats extends RefCounted
## Turns "which nodes are owned, and at what rank" into numbers the game reads.
##
## The tree is walked once per change and the totals cached, so the fishing rod
## can ask for a stat in the middle of a cast without paying for a tree walk.

signal changed

## Every stat a SkillMod is allowed to name.
const DIVE_TIME := &"dive_time"              ## Hook: seconds underwater.
const HANDLING := &"handling"                ## Hook: steering coefficient.
const CATCH_CAPACITY := &"catch_capacity"    ## Rod: fish carried per cast.
const SPAWN_RATE := &"spawn_rate"            ## Spawn areas: fish per second.
const LUCK := &"luck"                        ## Spawn areas: shift toward rare.
const CAST_POWER := &"cast_power"            ## Rod: maximum cast speed.
const CAST_VISION := &"cast_vision"          ## Rod: length of the visible arc.
const CAST_TIMING := &"cast_timing"          ## Meter: >1 slows the sweep.
const DIVE_BONUS := &"dive_bonus"            ## Rod: dive seconds a perfect hit adds.

const KNOWN := [DIVE_TIME, HANDLING, CATCH_CAPACITY, SPAWN_RATE, LUCK,
		CAST_POWER, CAST_VISION, CAST_TIMING, DIVE_BONUS]

var tree: SkillTreeResource
var state: SkillTreeState

var _add: Dictionary = {}   # StringName -> float
var _mul: Dictionary = {}   # StringName -> float


func _init(for_tree: SkillTreeResource = null, for_state: SkillTreeState = null) -> void:
	tree = for_tree
	state = for_state
	if state != null:
		state.changed.connect(refresh)
	refresh()


## Total additive bonus for a stat. 0.0 when nothing modifies it.
func bonus(stat: StringName) -> float:
	return float(_add.get(stat, 0.0))


## Total multiplier for a stat. 1.0 when nothing modifies it.
func multiplier(stat: StringName) -> float:
	return float(_mul.get(stat, 1.0))


## The call the game should use: base value in, upgraded value out. Both mod
## modes work on any stat
func apply(stat: StringName, base: float) -> float:
	return (base + bonus(stat)) * multiplier(stat)

## Same as 'apply' but for the integer stats like catch capacity.
func apply_int(stat: StringName, base: int) -> int:
	return int(round(apply(stat, float(base))))


## One line per modified stat, for a debug overlay.
func describe() -> String:
	var lines: PackedStringArray = []
	for stat in KNOWN:
		var add: float = bonus(stat)
		var mul: float = multiplier(stat)
		if is_zero_approx(add) and is_equal_approx(mul, 1.0):
			continue
		var parts: PackedStringArray = []
		if not is_zero_approx(add):
			parts.append(SkillMod.fmt_signed(add))
		if not is_equal_approx(mul, 1.0):
			parts.append("x%s" % SkillMod.fmt(mul))
		lines.append("%s %s" % [stat, " ".join(parts)])
	return "\n".join(lines)


## Recompute every total from the owned ranks. Wired to state.changed, so a
## purchase updates the game on the same frame.
func refresh() -> void:
	_add.clear()
	_mul.clear()
	if tree == null or state == null:
		changed.emit()
		return

	for n in tree.nodes:
		if n == null:
			continue
		var rank: int = state.rank_of(n.id)
		if rank <= 0:
			continue
		var upgrade := n.payload as SkillUpgrade
		if upgrade == null:
			continue
		for m in upgrade.mods:
			if m == null or m.stat == &"":
				continue
			if not KNOWN.has(m.stat):
				push_warning("SkillStats: node '%s' modifies unknown stat '%s'."
						% [n.id, m.stat])
				continue
			var total: float = m.total_for_rank(rank)
			if m.mode == SkillMod.Mode.ADD:
				_add[m.stat] = bonus(m.stat) + total
			else:
				_mul[m.stat] = multiplier(m.stat) * total

	changed.emit()
