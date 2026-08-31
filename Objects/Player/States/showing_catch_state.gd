class_name ShowingCatchState extends State
@onready var fishing_rod: FishingRod = %FishingRod
@onready var catch_display: CatchDisplay = %CatchDisplay
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D

var player: Player = null

func _ready() -> void:
	player = self.owner
	catch_display.finished.connect(_on_display_finished)

func enter() -> void:
	animated_sprite.play("holding_catch")
	player.can_left = false
	player.can_right = false
	player.can_fire = false
	fishing_rod.hide()
	catch_display.show_catch(player.last_catch)

func exit() -> void:
	player.last_catch.clear()
	catch_display.clear()

func _on_display_finished() -> void:
	transitioned.emit(self, "AimingFishingRodState")
