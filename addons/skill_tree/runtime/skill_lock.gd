@tool
class_name SkillLock extends Resource
## Gates a connection behind something your game tracks - an achievement, a
## quest flag, a boss kill. The tree stores only the id; your game answers
## whether it is open, via SkillTreeState.lock_provider.

@export var id: StringName = &""
@export var title: String = ""
## Shown to the player as "why can't I pass this yet".
@export_multiline var hint: String = ""
## Overrides SkillTreeStyle.lock_icon for this one lock.
@export var icon: Texture2D
