@tool
class_name SkillConnection extends Resource
## A prerequisite edge: `to_id` needs `from_id` bought first.

@export var from_id: StringName = &""
@export var to_id: StringName = &""
## Null for an open path. Set one to gate this route behind an achievement.
@export var lock: SkillLock


func involves(node_id: StringName) -> bool:
	return from_id == node_id or to_id == node_id
