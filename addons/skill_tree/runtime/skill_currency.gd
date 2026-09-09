@tool
class_name SkillCurrency extends Resource
## Something a skill costs - gold, skill points, fish scales. The tree only
## ever stores the id; your game owns the balance. Make one .tres per currency.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export var color: Color = Color.WHITE
