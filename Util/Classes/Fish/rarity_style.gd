class_name RarityStyle extends Resource

@export var particles: PackedScene

@export var label_settings: LabelSettings
@export var tint: Color = Color.WHITE

## How long this tier lingers on screen. Rarer = longer
@export var hold_time: float = 1.0
@export var sound: AudioStream
