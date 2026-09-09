extends Control
## Copy-paste starting point. Put this on a Control with a SkillTreeView child
## named "SkillTreeView", assign a tree to the view, and it works.
##
## Nothing in the addon knows about the three functions at the bottom - they are
## the whole integration surface. Rewrite them for your game and you are done.

@onready var view: SkillTreeView = $SkillTreeView

## Stand-in for your real wallet. Replace with your own singleton/save data.
var wallet: Dictionary = {&"skill_points": 6, &"gold": 800}
## Stand-in for your achievement store.
var achievements: Dictionary = {}

var state: SkillTreeState


func _ready() -> void:
	state = SkillTreeState.new(view.tree)
	state.balance_provider = _balance_of
	state.spender = _try_spend
	state.lock_provider = _has_achievement

	view.state = state
	view.node_purchased.connect(_on_purchased)
	view.purchase_rejected.connect(_on_rejected)


# --- the three seams ----------------------------------------------------------

func _balance_of(currency_id: StringName) -> int:
	return int(wallet.get(currency_id, 0))


## Return false to refuse the purchase. Deduct here, not in the addon, so your
## save data stays the single source of truth.
func _try_spend(costs: Dictionary) -> bool:
	for currency_id in costs:
		if int(wallet.get(currency_id, 0)) < int(costs[currency_id]):
			return false
	for currency_id in costs:
		wallet[currency_id] = int(wallet[currency_id]) - int(costs[currency_id])
	return true


func _has_achievement(lock_id: StringName) -> bool:
	return bool(achievements.get(lock_id, false))


# --- reacting to purchases ----------------------------------------------------

## SkillNodeData.payload is your own Resource type - the addon never reads it.
## Branch on it here, or give the payload an `apply(target)` method and call it.
func _on_purchased(node: SkillNodeData, rank: int) -> void:
	print("Bought %s (rank %d)" % [node.label(), rank])
	match node.id:
		&"capacity":
			# e.g. get_tree().get_first_node_in_group("rod").catch_capacity += 1
			pass
		&"handling":
			pass


func _on_rejected(node: SkillNodeData, reason: String) -> void:
	print("Can't buy %s: %s" % [node.label(), reason])


# --- saving -------------------------------------------------------------------

func save_data() -> Dictionary:
	return state.to_dict()


func load_data(data: Dictionary) -> void:
	state.from_dict(data)


## Call this when your game grants an achievement, so gated links open live.
func grant_achievement(lock_id: StringName) -> void:
	achievements[lock_id] = true
	state.set_lock_open(lock_id, true)
