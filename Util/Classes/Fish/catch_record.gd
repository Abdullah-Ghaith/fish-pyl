class_name CatchRecord extends Resource
## One fish as actually caught: the species, plus the things that vary from
## fish to fish.

@export var data: FishData
@export var length_cm: float = 0.0
## Price after the size bonus. Computed once at catch time so the number the
## card shows and the number the wallet gets can never disagree.
@export var value: int = 0


## Rolls a length for this species and prices it.
static func of(fish: FishData, length: float = -1.0) -> CatchRecord:
	var rec := CatchRecord.new()
	rec.data = fish
	if fish == null:
		return rec
	rec.length_cm = fish.roll_length() if length < 0.0 else length
	rec.value = fish.value_for_length(rec.length_cm)
	return rec


func title() -> String:
	return str(data.title) if data != null else "???"


func has_length() -> bool:
	return length_cm > 0.0


func size_text() -> String:
	return "%d cm" % roundi(length_cm)


## Where this fish sits in its species' range, 0..1. Useful for a "record!"
## flourish when it comes back close to 1.
func size_fraction() -> float:
	return data.length_fraction(length_cm) if data != null else 0.0
