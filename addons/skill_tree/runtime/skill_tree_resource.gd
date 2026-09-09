@tool
class_name SkillTreeResource extends Resource
## A whole skill tree, as data. This is the file the dev tool edits and the
## file the runtime view reads - nothing else is authored by hand.

@export var tree_name: String = "Skill Tree"

@export_group("Grid")
## How many guide anchors, in columns x rows.
@export var grid_size: Vector2i = Vector2i(7, 7)
## Pixel spacing between anchors. Nodes store cells, not pixels, so changing
## this rescales an existing layout instead of breaking it.
@export var cell_size: Vector2 = Vector2(72, 72)

@export_group("Content")
@export var nodes: Array[SkillNodeData] = []
@export var connections: Array[SkillConnection] = []

@export_group("Look")
@export var style: SkillTreeStyle


func cell_to_position(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_size


## Bounding size of the anchor grid, in pixels.
func content_size() -> Vector2:
	return Vector2(maxi(grid_size.x - 1, 0), maxi(grid_size.y - 1, 0)) * cell_size


func find_node(node_id: StringName) -> SkillNodeData:
	for n in nodes:
		if n != null and n.id == node_id:
			return n
	return null


func node_at_cell(cell: Vector2i) -> SkillNodeData:
	for n in nodes:
		if n != null and n.cell == cell:
			return n
	return null


func incoming(node_id: StringName) -> Array[SkillConnection]:
	var out: Array[SkillConnection] = []
	for c in connections:
		if c != null and c.to_id == node_id:
			out.append(c)
	return out


func outgoing(node_id: StringName) -> Array[SkillConnection]:
	var out: Array[SkillConnection] = []
	for c in connections:
		if c != null and c.from_id == node_id:
			out.append(c)
	return out


func has_connection(from_id: StringName, to_id: StringName) -> bool:
	for c in connections:
		if c != null and c.from_id == from_id and c.to_id == to_id:
			return true
	return false


## Nodes with no prerequisites, i.e. where a player can start.
func roots() -> Array[SkillNodeData]:
	var out: Array[SkillNodeData] = []
	for n in nodes:
		if n == null:
			continue
		if n.unlocked_from_start or incoming(n.id).is_empty():
			out.append(n)
	return out


## Every currency any node in the tree charges.
func used_currencies() -> Array[SkillCurrency]:
	var out: Array[SkillCurrency] = []
	for n in nodes:
		if n == null:
			continue
		for c in n.costs:
			if c != null and c.currency != null and not out.has(c.currency):
				out.append(c.currency)
	return out


## Human-readable problems with this tree. Empty means it is sound.
## The dev tool surfaces this; call it in a unit test too if you like.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Dictionary = {}

	for i in nodes.size():
		var n: SkillNodeData = nodes[i]
		if n == null:
			problems.append("Node slot %d is empty." % i)
			continue
		if n.id == &"":
			problems.append("Node at %s has no id." % str(n.cell))
		elif seen.has(n.id):
			problems.append("Duplicate node id '%s'." % n.id)
		else:
			seen[n.id] = true
		if n.cell.x < 0 or n.cell.y < 0 \
				or n.cell.x >= grid_size.x or n.cell.y >= grid_size.y:
			problems.append("Node '%s' sits outside the grid at %s." % [n.label(), str(n.cell)])
		if n.max_rank < 1:
			problems.append("Node '%s' has max_rank below 1." % n.label())
		for c in n.costs:
			if c == null:
				problems.append("Node '%s' has an empty cost slot." % n.label())
			elif c.currency == null:
				problems.append("Node '%s' has a cost with no currency." % n.label())

	var pairs: Dictionary = {}
	for i in connections.size():
		var c: SkillConnection = connections[i]
		if c == null:
			problems.append("Connection slot %d is empty." % i)
			continue
		if c.from_id == c.to_id:
			problems.append("Connection %d links '%s' to itself." % [i, c.from_id])
		if find_node(c.from_id) == null:
			problems.append("Connection %d starts at missing node '%s'." % [i, c.from_id])
		if find_node(c.to_id) == null:
			problems.append("Connection %d ends at missing node '%s'." % [i, c.to_id])
		var key: String = "%s>%s" % [c.from_id, c.to_id]
		if pairs.has(key):
			problems.append("Duplicate connection '%s'." % key)
		pairs[key] = true

	if roots().is_empty() and nodes.size() > 0:
		problems.append("No roots: every node has a prerequisite, so nothing is ever buyable.")

	for cycle in _find_cycles():
		problems.append("Cycle: %s - nothing on it can ever unlock." % cycle)

	return problems


func _find_cycles() -> PackedStringArray:
	var found: PackedStringArray = []
	var state: Dictionary = {}   # id -> 0 unvisited, 1 in progress, 2 done
	for n in nodes:
		if n != null and int(state.get(n.id, 0)) == 0:
			_walk(n.id, state, [], found)
	return found


func _walk(node_id: StringName, state: Dictionary, path: Array, found: PackedStringArray) -> void:
	state[node_id] = 1
	path.push_back(node_id)
	for c in outgoing(node_id):
		var nxt: StringName = c.to_id
		var s: int = int(state.get(nxt, 0))
		if s == 1:
			var names: PackedStringArray = []
			for p in path:
				names.append(String(p))
			names.append(String(nxt))
			var joined: String = " -> ".join(names)
			if not found.has(joined):
				found.append(joined)
		elif s == 0:
			_walk(nxt, state, path, found)
	path.pop_back()
	state[node_id] = 2
