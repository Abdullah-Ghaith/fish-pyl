@tool
class_name SkillUpgrade extends Resource
## What a skill node actually does. Drop one into SkillNodeData.payload.

@export var mods: Array[SkillMod] = []
## Designer note or tooltip text. Nothing reads this; it's for us.
@export_multiline var notes: String = ""


func describe() -> String:
	var parts: PackedStringArray = []
	for m in mods:
		if m != null:
			parts.append(m.describe())
	return ", ".join(parts) if parts.size() > 0 else "(no effect)"
