class_name FishData extends Resource

enum Rarity { None, Common, Rare, Bepic, Legendary }

@export var title: StringName = ""
@export var texture: Texture2D
@export var speed: float = 0.0
## Per-fish spread around `speed`, as a fraction. 0.2 = every fish swims at
## 80-120% of it.
##
## Load-bearing, not decoration: with this at 0 every fish of a species moves
## at exactly the same rate, so any two that spawn near each other stay stuck
## together for the whole crossing. That is what makes shoals look like clumps.
@export_range(0.0, 0.9, 0.01) var speed_variation: float = 0.2
@export var cash_value: float = 0.0
@export var rarity: Rarity = Rarity.None
## Nudges this species' odds relative to others in the same rarity tier.
## 1.0 = normal, 2.0 = twice as likely as its tier-mates.
@export var weight_multiplier: float = 1.0

@export_group("Size")
## Length range for this species, in cm. Leave max at 0 and the fish has no
## size at all - the catch card hides its size line and value_for_length()
## returns the plain cash_value.
@export var min_length_cm: float = 0.0
@export var max_length_cm: float = 0.0
## What a maximum-length fish is worth over a minimum-length one, as a fraction
## of cash_value. 0.5 = a record fish sells for 50% more.
@export var length_value_bonus: float = 0.5

@export_group("HitBox")
@export var hitbox : Shape2D
## Only used for the auto-fitted rectangle
@export var hitbox_scale: Vector2 = Vector2(0.8, 0.6)


## This fish's own swimming speed. Rolled per fish, not per species.
func roll_speed() -> float:
	if is_zero_approx(speed_variation):
		return speed
	return speed * randf_range(1.0 - speed_variation, 1.0 + speed_variation)


## Triangular distribution - the average of two uniform rolls - so most fish
## come out mid-sized and a big one is genuinely uncommon. No tuning knobs and
## no normal-distribution maths to get wrong.
func roll_length() -> float:
	if max_length_cm <= 0.0:
		return 0.0
	return lerpf(minf(min_length_cm, max_length_cm),
			maxf(min_length_cm, max_length_cm), (randf() + randf()) * 0.5)


## Where a length sits in this species' range, 0..1.
func length_fraction(length: float) -> float:
	if max_length_cm <= 0.0:
		return 0.0
	var lo: float = minf(min_length_cm, max_length_cm)
	var hi: float = maxf(min_length_cm, max_length_cm)
	if is_equal_approx(hi, lo):
		return 0.0
	return clampf((length - lo) / (hi - lo), 0.0, 1.0)


## Base price plus the size bonus, so a bigger fish of the same species pays
## more. Rounded to an int here, once, at catch time.
func value_for_length(length: float) -> int:
	return int(round(cash_value * (1.0 + length_value_bonus * length_fraction(length))))


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
	# Lengths are optional, so a missing range is not an error - but a backwards
	# one silently disables the size line, which is worth saying out loud.
	if max_length_cm > 0.0 and min_length_cm > max_length_cm:
		printerr("%s: %s has min_length_cm above max_length_cm" % [context, label])
		ok = false
	return ok
