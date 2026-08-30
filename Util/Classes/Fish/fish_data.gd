class_name FishData extends Resource

enum Rarity { None, Common, Rare, Bepic, Legendary }

@export var title: StringName = ""
@export var texture: Texture2D
@export var speed: float = 0.0
@export var cash_value: float = 0.0
@export var rarity: Rarity = Rarity.None
## Nudges this species' odds relative to others in the same rarity tier.
## 1.0 = normal, 2.0 = twice as likely as its tier-mates.
@export var weight_multiplier: float = 1.0


## Resources have no _ready, so the spawner calls this once at startup.
## Returns false if the resource is unusable, so the spawner can skip it.
func validate(context: String) -> bool:
	var label: String = str(title) if title != "" else "<un-named FishData>"
	var ok := true
	if title == "":
		printerr("%s: un-named FishData (%s)" % [context, resource_path])
		ok = false
	if speed == 0.0:
		printerr("%s: %s failed to set speed" % [context, label])
		ok = false
	if cash_value == 0.0:
		printerr("%s: %s failed to set cash_value" % [context, label])
		ok = false
	if rarity == Rarity.None:
		printerr("%s: %s failed to set rarity" % [context, label])
		ok = false
	return ok
