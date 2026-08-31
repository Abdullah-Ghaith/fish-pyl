class_name FishingState extends State
@onready var fishing_rod: FishingRod = %FishingRod
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D


var player: Player = null

func _ready():
	player = self.owner

func enter():
	fishing_rod.animation_fishing()
	animated_sprite.play("idle")
	player.can_right = false
	player.can_left = false
	player.can_fire = false

func exit():
	pass

func physics_update(_delta: float):
	pass

func _on_fishing_rod_hook_returned(catch: Array[FishData]) -> void:
	player.last_catch = catch
	if catch.is_empty():
		transitioned.emit(self, "AimingFishingRodState")
	else:
		transitioned.emit(self, "ShowingCatchState")
