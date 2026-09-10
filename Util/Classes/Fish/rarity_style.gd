class_name RarityStyle extends Resource

## For per-tier overrides of a CatchEntry bool. INHERIT leaves the entry's own
## export alone.
enum Toggle { INHERIT, ON, OFF }

@export var particles: PackedScene

@export var label_settings: LabelSettings
@export var tint: Color = Color.WHITE

## How long this tier lingers on screen. Rarer = longer
@export var hold_time: float = 1.0
@export var sound: AudioStream

@export_group("Catch Card")
## Shown under the fish's name. Blank falls back to the Rarity enum name.
@export var display_name: String = ""
## Colour of the rarity line.
@export var accent: Color = Color(0.85, 0.85, 0.9)
## Frame for this tier's card, overriding CatchEntry.card_panel - so a
## legendary can arrive in a fancier box than a minnow.
@export var card_panel: StyleBox
## Whole-card size for this tier. CatchDisplay pops the card up to this instead
## of to 1.0, so a common can be a small card and a legendary a big one.
##
## It scales the text too, so a pixel font goes soft at fractional values -
## 0.5, 0.75, 1.0, 1.5 stay crisp where 0.85 does not. If you want a smaller
## card with sharp text, leave this at 1.0 and use card_title/card_min_width.
@export_range(0.1, 3.0, 0.05) var card_scale: float = 1.0
## Per-tier override of CatchEntry.show_title. The "Fish Caught!" banner is
## usually the widest thing on the card, so switching it OFF is the biggest
## single reduction available without scaling anything.
@export var card_title: Toggle = Toggle.INHERIT
## Overrides CatchEntry.min_width. 0 = use the entry's own value.
@export var card_min_width: float = 0.0
## Added to CatchEntry.card_offset for this tier. Additive on purpose - there
## is no "unset" Vector2, so zero simply means "use the entry's own offset".
##
## Note it is scaled along with the card, so on a 1.5x card a -20 nudge moves
## the art 30px. Push it further negative on big tiers, or switch the entry's
## card_anchor to BOTTOM and mostly stop caring.
@export var card_offset_extra: Vector2 = Vector2.ZERO
