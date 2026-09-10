@tool
class_name SkillMod extends Resource
## One stat change contributed by one skill node.
## `stat` must be one of the constants on SkillStats

enum Mode {
	ADD,
	MULTIPLY,
}

@export var stat: StringName = &""
@export var mode: Mode = Mode.ADD
## What the first rank is worth.
@export var value: float = 0.0
## Added to `value` for each rank after the first. 0 = every rank is equal.
@export var per_rank: float = 0.0



func total_for_rank(rank: int) -> float:
	var identity: float = 0.0 if mode == Mode.ADD else 1.0
	if rank <= 0 or stat == &"":
		return identity
	var total: float = identity
	for r in rank:
		var step: float = value + per_rank * float(r)
		if mode == Mode.ADD:
			total += step
		else:
			total *= step
	return total


## Trims trailing zeros: 1.5 -> "1.5", 2.0 -> "2", 0.35 -> "0.35".
##
## GDScript's % operator supports only s c d o x X f v - there is no %g - and
## on an unsupported specifier it returns the *format string itself*, so this
## goes through String.num instead. trim_suffix(".0") rather than stripping
## zeros, because String.num(20.0, 0) is "20" and rstrip would make it "2".
static func fmt(value: float, decimals: int = 4) -> String:
	return String.num(value, decimals).trim_suffix(".0")


static func fmt_signed(value: float, decimals: int = 4) -> String:
	var s: String = fmt(value, decimals)
	return s if s.begins_with("-") else "+" + s


## For a tooltip. Describes one rank, not the total.
func describe() -> String:
	if stat == &"":
		return "(no stat)"
	if mode == Mode.ADD:
		return "%s %s" % [fmt_signed(value), stat]
	return "x%s %s" % [fmt(value), stat]
