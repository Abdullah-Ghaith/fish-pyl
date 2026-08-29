class_name AimingFishingRodState extends State
@onready var fishing_rod: FishingRod = %FishingRod


var player: Player = null

func _ready():
	player = self.owner

func enter():
	fishing_rod.show()
	fishing_rod.animation_idle()
	player.can_right = false
	player.can_left = true
	player.can_fire = true

func exit():
	pass

func physics_update(_delta: float): #listen to cast
	pass
