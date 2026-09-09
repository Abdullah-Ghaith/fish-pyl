class_name SkillTreeState extends RefCounted
## Runtime ownership and rules for one SkillTreeResource.
##
## Project-agnostic by design: it never assumes an autoload, a save system or a
## currency class. You hand it three Callables and it asks them questions.
## Leave them unset and everything is free and every lock is closed, which is
## exactly what you want while prototyping.
##
##     var state := SkillTreeState.new(my_tree)
##     state.balance_provider = func(id): return Wallet.get(id)
##     state.spender = func(costs): return Wallet.try_spend(costs)
##     state.lock_provider = func(id): return Achievements.has(id)

signal changed
signal purchased(node: SkillNodeData, rank: int)
signal purchase_failed(node: SkillNodeData, reason: String)
signal lock_opened(lock_id: StringName)

var tree: SkillTreeResource

## func(currency_id: StringName) -> int. Unset means "infinite money".
var balance_provider: Callable = Callable()
## func(costs: Dictionary) -> bool. Deduct and return false to refuse the buy.
## Unset means purchases are free.
var spender: Callable = Callable()
## func(lock_id: StringName) -> bool. Unset means locks are closed until you
## call set_lock_open() yourself.
var lock_provider: Callable = Callable()

var _ranks: Dictionary = {}       # StringName -> int
var _open_locks: Dictionary = {}  # StringName -> true


func _init(for_tree: SkillTreeResource = null) -> void:
	tree = for_tree


# --- ownership ---------------------------------------------------------------

func rank_of(node_id: StringName) -> int:
	return int(_ranks.get(node_id, 0))


func is_owned(node_id: StringName) -> bool:
	return rank_of(node_id) > 0


## Force a rank without paying - for loading a save, or a debug menu.
func set_rank(node_id: StringName, rank: int) -> void:
	if rank <= 0:
		_ranks.erase(node_id)
	else:
		_ranks[node_id] = rank
	changed.emit()


func reset() -> void:
	_ranks.clear()
	changed.emit()


# --- locks -------------------------------------------------------------------

func is_lock_open(lock_id: StringName) -> bool:
	if _open_locks.has(lock_id):
		return true
	if lock_provider.is_valid():
		return bool(lock_provider.call(lock_id))
	return false


## Open a lock locally, without going through lock_provider. Handy for testing
## and for games that push achievements rather than being polled.
func set_lock_open(lock_id: StringName, open: bool = true) -> void:
	if open:
		if not _open_locks.has(lock_id):
			_open_locks[lock_id] = true
			lock_opened.emit(lock_id)
	else:
		_open_locks.erase(lock_id)
	changed.emit()


# --- state -------------------------------------------------------------------

func state_of(node: SkillNodeData) -> SkillTree.NodeState:
	if node == null or tree == null:
		return SkillTree.NodeState.LOCKED

	var rank: int = rank_of(node.id)
	if rank >= node.max_rank:
		return SkillTree.NodeState.MAXED
	if rank > 0:
		return SkillTree.NodeState.PURCHASED
	if node.unlocked_from_start:
		return SkillTree.NodeState.AVAILABLE

	var links: Array[SkillConnection] = tree.incoming(node.id)
	if links.is_empty():
		return SkillTree.NodeState.AVAILABLE

	var satisfied: int = 0
	var gated: int = 0
	for c in links:
		if not is_owned(c.from_id):
			continue
		if c.lock != null and not is_lock_open(c.lock.id):
			gated += 1
			continue
		satisfied += 1

	var needed: int = 1 if node.requirement == SkillTree.Requirement.ANY else links.size()
	if satisfied >= needed:
		return SkillTree.NodeState.AVAILABLE
	if gated > 0:
		return SkillTree.NodeState.GATED
	return SkillTree.NodeState.LOCKED


## True when this connection's prerequisite is owned and its lock is open.
func is_link_satisfied(c: SkillConnection) -> bool:
	if c == null:
		return false
	if not is_owned(c.from_id):
		return false
	return c.lock == null or is_lock_open(c.lock.id)


# --- buying ------------------------------------------------------------------

func next_rank_costs(node: SkillNodeData) -> Dictionary:
	if node == null:
		return {}
	return node.costs_for_rank(rank_of(node.id) + 1)


func can_afford(costs: Dictionary) -> bool:
	if not balance_provider.is_valid():
		return true
	for currency_id in costs:
		if int(balance_provider.call(currency_id)) < int(costs[currency_id]):
			return false
	return true


func can_purchase(node: SkillNodeData) -> bool:
	return blocked_reason(node) == ""


## "" when the node can be bought right now, otherwise why not - suitable for
## a tooltip.
func blocked_reason(node: SkillNodeData) -> String:
	if node == null or tree == null:
		return "No node."
	match state_of(node):
		SkillTree.NodeState.MAXED:
			return "Already at max rank."
		SkillTree.NodeState.LOCKED:
			return "Requires an earlier skill."
		SkillTree.NodeState.GATED:
			return _gate_hint(node)
	if not can_afford(next_rank_costs(node)):
		return "Costs %s." % node.describe_costs(rank_of(node.id) + 1)
	return ""


func purchase(node: SkillNodeData) -> bool:
	var reason: String = blocked_reason(node)
	if reason != "":
		purchase_failed.emit(node, reason)
		return false

	var next: int = rank_of(node.id) + 1
	var costs: Dictionary = node.costs_for_rank(next)
	if spender.is_valid() and not bool(spender.call(costs)):
		purchase_failed.emit(node, "Payment refused.")
		return false

	_ranks[node.id] = next
	purchased.emit(node, next)
	changed.emit()
	return true


func _gate_hint(node: SkillNodeData) -> String:
	for c in tree.incoming(node.id):
		if c.lock != null and is_owned(c.from_id) and not is_lock_open(c.lock.id):
			if c.lock.hint != "":
				return c.lock.hint
			if c.lock.title != "":
				return "Locked: %s" % c.lock.title
			return "Locked: %s" % c.lock.id
	return "Locked."


# --- saving ------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"ranks": _ranks.duplicate(), "open_locks": _open_locks.keys()}


func from_dict(data: Dictionary) -> void:
	_ranks.clear()
	_open_locks.clear()
	for key in data.get("ranks", {}):
		_ranks[StringName(key)] = int(data["ranks"][key])
	for lock_id in data.get("open_locks", []):
		_open_locks[StringName(lock_id)] = true
	changed.emit()
