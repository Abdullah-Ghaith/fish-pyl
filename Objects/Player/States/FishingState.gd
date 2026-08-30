class_name FishingState extends State
@onready var fishing_rod: FishingRod = %FishingRod


var player: Player = null

func _ready():
	player = self.owner

func enter():
	fishing_rod.animation_fishing()
	player.can_right = false
	player.can_left = false
	player.can_fire = false

func exit():
	pass

func physics_update(_delta: float):
	pass

func _on_fishing_rod_hook_returned(_catch: Array[FishData]) -> void:
	self.transitioned.emit(self, "AimingFishingRodState")
