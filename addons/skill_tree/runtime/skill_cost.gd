@tool
class_name SkillCost extends Resource
## One currency's share of a node's price. A node can carry several.

@export var currency: SkillCurrency
@export var amount: int = 1
## Added on for each rank past the first, for multi-rank nodes.
@export var per_rank_increase: int = 0


func currency_id() -> StringName:
	return currency.id if currency else &""


func amount_for_rank(rank: int) -> int:
	return amount + per_rank_increase * maxi(0, rank - 1)


func describe(rank: int = 1) -> String:
	var label: String = display_currency()
	return "%d %s" % [amount_for_rank(rank), label]


func display_currency() -> String:
	if currency == null:
		return "?"
	return currency.display_name if currency.display_name != "" else String(currency.id)
