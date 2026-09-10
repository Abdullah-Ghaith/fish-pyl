extends Node
## The autoload owner of skill progress


signal wallet_changed
signal achievement_unlocked(id: StringName)

const TREE_PATH := "res://skill_tree.tres" #TODO change this to allow for multi skill trees me thinks
const SAVE_PATH := "user://progress.json"

## Skill points per fish, indexed to match FishData.Rarity:
## [None, Common, Rare, Bepic, Legendary].
const POINTS_BY_RARITY := [0, 1, 3, 8, 20] #TODO this could be variable and upgradable

const STARTING_SKILL_POINTS := 12 #TODO get rid of this/set to 0 once we have fish giving sp

var tree: SkillTreeResource
var state: SkillTreeState
var stats: SkillStats

var _wallet: Dictionary = {}   # StringName -> int


func _ready() -> void:
	tree = load(TREE_PATH) as SkillTreeResource
	if tree == null:
		push_error("Progression: no SkillTreeResource at %s" % TREE_PATH)
		return

	state = SkillTreeState.new(tree)
	state.balance_provider = balance
	state.spender = _spend
	stats = SkillStats.new(tree, state)

	if STARTING_SKILL_POINTS > 0:
		add_currency(&"skill_points", STARTING_SKILL_POINTS)


# --- stat access --------------------------------------------------------------

func stat(stat_id: StringName, base: float) -> float:
	return stats.apply(stat_id, base) if stats != null else base


func stat_int(stat_id: StringName, base: int) -> int:
	return stats.apply_int(stat_id, base) if stats != null else base


# --- wallet ------------------------------------------------------------------

func balance(currency_id: StringName) -> int:
	return int(_wallet.get(currency_id, 0))


func add_currency(currency_id: StringName, amount: int) -> void:
	_wallet[currency_id] = maxi(0, balance(currency_id) + amount)
	wallet_changed.emit()

func _spend(costs: Dictionary) -> bool:
	for id in costs:
		if balance(id) < int(costs[id]):
			return false
	for id in costs:
		_wallet[id] = balance(id) - int(costs[id])
	wallet_changed.emit()
	return true


# --- earning -----------------------------------------------------------------

## Call once per completed cast. Pays out currency and unlocks rarity gates.
func record_catch(catch: Array[FishData]) -> void:
	if state == null:
		return
	var points: int = 0
	var gold: int = 0
	for f in catch:
		if f == null:
			continue
		points += points_for(f.rarity)
		gold += int(round(f.cash_value))
		if f.rarity == FishData.Rarity.Legendary:
			unlock_achievement(&"caught_legendary")
	if points > 0:
		add_currency(&"skill_points", points)
	if gold > 0:
		add_currency(&"gold", gold)


func points_for(rarity: FishData.Rarity) -> int:
	var i: int = int(rarity)
	if i < 0 or i >= POINTS_BY_RARITY.size():
		return 0
	return POINTS_BY_RARITY[i]


# --- achievement gates -------------------------------------------------------

## Opens any connection lock with this id.
func unlock_achievement(id: StringName) -> void:
	if state == null or state.is_lock_open(id):
		return
	state.set_lock_open(id, true)
	achievement_unlocked.emit(id)


func has_achievement(id: StringName) -> bool:
	return state != null and state.is_lock_open(id)


# --- persistence -------------------------------------------------------------

func save_progress() -> void:
	if state == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Progression: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify({"wallet": _wallet, "skills": state.to_dict()}))


func load_progress() -> void:
	if state == null or not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Progression: %s is not valid save data" % SAVE_PATH)
		return

	var data: Dictionary = parsed
	_wallet.clear()
	var saved_wallet: Dictionary = data.get("wallet", {})
	for key in saved_wallet:
		_wallet[StringName(key)] = int(saved_wallet[key])
	# from_dict emits changed, which refreshes stats and any open view.
	state.from_dict(data.get("skills", {}))
	wallet_changed.emit()


## Wipe ranks, gates and currency. Handy on a debug key.
func reset_all() -> void:
	if state == null:
		return
	_wallet.clear()
	state.from_dict({})
	if STARTING_SKILL_POINTS > 0:
		add_currency(&"skill_points", STARTING_SKILL_POINTS)
	wallet_changed.emit()
