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


## For a tooltip. Describes one rank, not the total.
func describe() -> String:
	if stat == &"":
		return "(no stat)"
	if mode == Mode.ADD:
		return "%+.4g %s" % [value, stat]
	return "x%.4g %s" % [value, stat]
