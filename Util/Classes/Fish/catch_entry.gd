class_name CatchEntry extends Node2D
## One fish in the caught row. Built by CatchDisplay.

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var vfx_anchor: Marker2D = $VfxAnchor

var data: FishData = null


func setup(fish_data: FishData, style: RarityStyle) -> void:
	data = fish_data
	if data == null:
		return
	sprite.texture = data.texture
	label.text = str(data.title)

	if style == null:
		return
	if style.label_settings:
		label.label_settings = style.label_settings
	sprite.modulate = style.tint

	var vfx_scene: PackedScene = style.particles
	if vfx_scene:
		var vfx := vfx_scene.instantiate()
		vfx_anchor.add_child(vfx)
		if vfx is GPUParticles2D or vfx is CPUParticles2D:
			vfx.emitting = true
