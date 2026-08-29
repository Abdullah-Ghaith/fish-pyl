class_name WalkingState extends State
@onready var fishing_rod: FishingRod = %FishingRod


var player: Player = null

func _ready():
	player = self.owner

func enter():
	fishing_rod.hide()
	player.can_right = true
	player.can_left = true
	player.can_fire = false

func exit():
	pass

func physics_update(_delta: float):
	pass
