class_name WalkingState extends State
@onready var fishing_rod: FishingRod = $FishingRod


var player: Player = null

func _ready():
	player = self.owner

func enter():
	fishing_rod.hide()
	player.movement_enabled = true

func exit():
	pass

func physics_update(_delta: float):
	pass
