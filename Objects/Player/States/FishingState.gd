class_name FishingState extends State
@onready var fishing_rod: FishingRod = $FishingRod


var player: Player = null

func _ready():
	player = self.owner

func enter():
	fishing_rod.
	player.movement_enabled = false

func exit():
	pass

func physics_update(_delta: float):
	pass
