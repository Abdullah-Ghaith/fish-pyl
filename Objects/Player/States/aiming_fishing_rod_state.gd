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
# Add the gravity.
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * _delta

	# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	if not player.can_right and direction > 0.0:
		direction = 0.0
	if not player.can_left and direction < 0.0:
		direction = 0.0

	# Determine Sprite orientation and animation
	if player.is_on_floor():
		if direction == 0.0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")

	# Determine Sprite Orientation
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	if direction:
		player.velocity.x = direction * player.SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED)

	player.move_and_slide()
