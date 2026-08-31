class_name AimingFishingRodState extends State
@onready var fishing_rod: FishingRod = %FishingRod
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D


var player: Player = null

func _ready():
	player = self.owner

func enter():
	animated_sprite.play("idle")
	fishing_rod.show()
	fishing_rod.animation_idle()
	player.can_right = false
	player.can_left = true
	player.can_fire = true

func exit():
	pass

func physics_update(_delta: float):
	player.move(_delta)
