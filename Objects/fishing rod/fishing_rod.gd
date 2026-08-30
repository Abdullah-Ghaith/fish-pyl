class_name FishingRod extends Node2D

@export var projectile_scene: PackedScene = preload("res://Objects/Hook/hook.tscn")
@onready var trajectory_line: TrajectoryLine = $TrajectoryLine
@onready var fishing_line: FishingLine = $FishingLine
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export_group("Camera")
## The zoomed-in PhantomCamera2D. Its follow_mode must NOT be None, or assigning
## follow_target at runtime silently does nothing (see PhantomCamera2D.set_follow_target).
@export var pcam_hook: PhantomCamera2D
## Priority pcam_hook takes while the hook is under water. Must beat the world
## pcam's priority. The addon clamps priority to >= 0, so no negatives.
@export var hook_pcam_priority: int = 20
## Priority it drops back to once the hook leaves the water.
@export var idle_pcam_priority: int = 0


@export_group("Catching")
@export var catch_capacity: int = 1


var player : Player = null
var projectile_speed: float = 0.0
var projectile_gravity: float = 0.0
var current_hook: Hook = null

signal hook_fired
signal hook_returned(catch: Array[FishData])

func _ready() -> void:
	player = self.owner
	if projectile_scene:
		var temp_projectile: Hook = projectile_scene.instantiate()
		projectile_speed = temp_projectile.speed
		projectile_gravity = temp_projectile.gravity
		temp_projectile.free() # Clean up the temporary node from memory


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		rotation -= delta
	elif Input.is_action_pressed("ui_right"):
		rotation += delta
	if Input.is_action_pressed("ui_up"):
		projectile_speed += 200 * delta
	elif Input.is_action_pressed("ui_down"):
		projectile_speed -= 200 * delta
	projectile_speed = clamp(projectile_speed, 100.0, 2000.0)
	if Input.is_action_just_pressed("ui_accept") and player.can_fire:
		shoot()
	trajectory_line.rotation = -rotation
	trajectory_line.update_trajectory(
		$ShootPos.global_transform.x,
		projectile_speed,
		projectile_gravity,
		delta
	)


func shoot() -> void:
	hook_fired.emit()

	var hook: Hook = projectile_scene.instantiate()
	hook.dir = $ShootPos.global_transform.x
	hook.speed = projectile_speed
	get_tree().current_scene.add_child(hook)
	hook.global_position = $ShootPos.global_position
	hook.rod_tip = $ShootPos   # where the hook reels itself back to
	hook.capacity = self.catch_capacity
	current_hook = hook

	# The line now runs rod tip -> hook and pays out as the hook flies.
	hook.entered_water.connect(fishing_line._on_hook_entered_water)
	hook.started_returning.connect(fishing_line.begin_return)
	hook.returned.connect(_on_hook_returned)

	# The same two moments drive the camera. Signals take any number of
	# connections, so the line and the camera each listen without knowing about
	# each other.
	hook.entered_water.connect(_focus_camera_on_hook.bind(hook))

	fishing_line.attach_hook(hook)


func reel_in() -> void:
	fishing_line.detach_hook()
	_release_camera()
	if is_instance_valid(current_hook):
		# queue_free() is deferred, and hooks are siblings that process after this
		# node - so a hook killed here would still run one more physics frame and
		# could fire `returned` at the line we're about to hand to its replacement.
		# Silencing it first closes that window.
		current_hook.set_physics_process(false)
		current_hook.queue_free()
	current_hook = null


## The hook made it back to the rod tip and is about to free itself.
func _on_hook_returned(catch: Array[FishData]) -> void:
	fishing_line.detach_hook()
	_release_camera()
	hook_returned.emit(catch)
	current_hook = null


func animation_idle() -> void:
	animated_sprite_2d.play("Idle")
	trajectory_line.show()


func animation_fishing() -> void:
	animated_sprite_2d.play("Fishing")
	trajectory_line.hide()


# --- camera ------------------------------------------------------------------

## Splashdown: hand the zoomed-in pcam the hook and out-prioritise the world pcam.
## PhantomCameraHost tweens position AND zoom across the switch, using the curve
## on pcam_hook's own tween_resource - there is no Tween to write here.
func _focus_camera_on_hook(_surface_y: float, which: Hook) -> void:
	if not is_instance_valid(pcam_hook):
		return
	pcam_hook.follow_target = which
	pcam_hook.priority = hook_pcam_priority


func _release_camera() -> void:
	if not is_instance_valid(pcam_hook):
		return
	pcam_hook.priority = idle_pcam_priority
