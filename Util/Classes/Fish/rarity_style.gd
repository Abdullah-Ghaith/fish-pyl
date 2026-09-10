class_name RarityStyle extends Resource

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
