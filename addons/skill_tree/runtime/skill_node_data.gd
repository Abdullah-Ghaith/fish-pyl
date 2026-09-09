@tool
class_name SkillNodeData extends Resource
## One buyable square in the tree.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

## Grid coordinates. Pixel position is cell * SkillTreeResource.cell_size, so
## moving the grid never invalidates a layout.
@export var cell: Vector2i = Vector2i.ZERO

## 1 = a plain on/off skill. Higher = buy it repeatedly.
@export_range(1, 99) var max_rank: int = 1

## Price of one rank. Several entries = several currencies, all required.
@export var costs: Array[SkillCost] = []

## Buyable with no prerequisites - a tree root.
@export var unlocked_from_start: bool = false

## How to treat multiple incoming connections.
@export var requirement: SkillTree.Requirement = SkillTree.Requirement.ALL

## Whatever this skill MEANS in your game. The addon never reads it - point it
## at your own Resource type and interpret it yourself when `purchased` fires.
@export var payload: Resource


## currency_id -> amount, for the given rank.
func costs_for_rank(rank: int) -> Dictionary:
	var out: Dictionary = {}
	for c in costs:
		if c == null or c.currency == null:
			continue
		var key: StringName = c.currency.id
		out[key] = int(out.get(key, 0)) + c.amount_for_rank(rank)
	return out


func describe_costs(rank: int = 1) -> String:
	var parts: PackedStringArray = []
	for c in costs:
		if c != null and c.currency != null:
			parts.append(c.describe(rank))
	return ", ".join(parts) if parts.size() > 0 else "Free"


func label() -> String:
	return title if title != "" else String(id)
