class_name FishingRod extends Node2D
## Aim, then power, then cast.
##
## The rod node itself is never rotated - the sprite and the power meter have to
## stay upright - so the angle lives in `aim_angle` and only the cast direction
## and the preview arc use it.

## AIM accepts steering; POWER has the angle locked and the meter running.
enum CastPhase { AIM, POWER }

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

@export_group("Casting")
## The sweeping meter that sets cast strength. Leave empty and a press casts
## at full power, which is handy while building a level.
@export var power_meter: PowerMeter
## Floor of the aim range - the original hardcoded value.
@export var min_cast_speed: float = 100.0
## Ceiling of the aim range. This replaces the old hardcoded 2000: it is the
## distance cap, and cast_power is the only thing that raises it.
@export var max_cast_speed: float = 1200.0
## How fast up/down sweep the distance, in speed units per second.
@export var aim_rate: float = 200.0
## How fast left/right swing the angle, in radians per second.
@export var aim_turn_rate: float = 1.0
## Angle the rod starts at. Negative is upward, Godot's y being down.
@export var aim_start_deg: float = -40.0
## Angle limits. Stops the player aiming backwards or into their own feet.
@export var aim_min_deg: float = -85.0
@export var aim_max_deg: float = -5.0
## Extra seconds underwater for a perfect meter hit, scaled by the score
## bad hit adds nothing and the hook's own dive_time is the baseline. Raised by
## the dive_bonus upgrade.
@export var dive_bonus_max: float = 4.0


var player : Player = null
var projectile_speed: float = 0.0
var projectile_gravity: float = 0.0
var current_hook: Hook = null

var aim_angle: float = 0.0
var phase: CastPhase = CastPhase.AIM

var _dive_bonus: float = 0.0

signal hook_fired
signal hook_returned(catch: Array[CatchRecord])
## The meter was locked in and the cast is going out. Hook a "NICE!" popup here.
signal cast_locked(score: float, dive_bonus: float)

func _ready() -> void:
	player = self.owner
	if projectile_scene:
		var temp_projectile: Hook = projectile_scene.instantiate()
		projectile_speed = temp_projectile.speed
		projectile_gravity = temp_projectile.gravity
		temp_projectile.free()
	aim_angle = deg_to_rad(aim_start_deg)

	if power_meter != null:
		power_meter.locked_in.connect(_on_power_locked)
	else:
		push_warning("%s: no power_meter assigned - casting at mid power." % name)

	if Progression.stats != null:
		Progression.stats.changed.connect(_apply_cast_upgrades)
	_apply_cast_upgrades()


func _apply_cast_upgrades() -> void:
	trajectory_line.steps_multiplier = Progression.stat(SkillStats.CAST_VISION, 1.0)
	if power_meter != null:
		power_meter.sweep_time_multiplier = Progression.stat(SkillStats.CAST_TIMING, 1.0)


func get_max_cast_speed() -> float:
	return Progression.stat(SkillStats.CAST_POWER, max_cast_speed)


## Seconds a 100-score hit adds on top of the hook's own dive_time.
func get_max_dive_bonus() -> float:
	return Progression.stat(SkillStats.DIVE_BONUS, dive_bonus_max)


## First press arms the meter, second locks it in and casts.
func _on_cast_pressed() -> void:
	if power_meter == null:
		_dive_bonus = 0.0
		shoot()
		return
	match phase:
		CastPhase.AIM:
			phase = CastPhase.POWER
			power_meter.start()
		CastPhase.POWER:
			power_meter.stop()


## The meter no longer decides how far the cast goes - the player aims that
## with up/down. It buys bottom time instead.
func _on_power_locked(score: float, _t: float, _perfect: bool) -> void:
	_dive_bonus = get_max_dive_bonus() * clampf(score, 0.0, 100.0) / 100.0
	phase = CastPhase.AIM
	cast_locked.emit(score, _dive_bonus)
	shoot()


## Call when leaving the aiming state, so an armed meter does not survive into
## the next cast.
func cancel_cast() -> void:
	reset_aim()


func _physics_process(delta: float) -> void:
	if phase == CastPhase.AIM:
		_update_aim(delta)
	elif _wants_to_walk():
		# Stepping off the ledge throws the locked angle away.
		reset_aim()

	if Input.is_action_just_pressed("ui_accept") and player.can_fire:
		_on_cast_pressed()

	# No delta: the arc simulates at a fixed step so its length does not change
	# with the frame rate.
	trajectory_line.update_trajectory(
			aim_direction(), projectile_speed, projectile_gravity)


func _update_aim(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		aim_angle -= aim_turn_rate * delta
	elif Input.is_action_pressed("ui_right"):
		aim_angle += aim_turn_rate * delta
	aim_angle = clampf(aim_angle, deg_to_rad(aim_min_deg), deg_to_rad(aim_max_deg))

	if Input.is_action_pressed("ui_up"):
		projectile_speed += aim_rate * delta
	elif Input.is_action_pressed("ui_down"):
		projectile_speed -= aim_rate * delta
	# Clamped every frame, so lowering the cap re-clamps an already-high aim.
	projectile_speed = clampf(projectile_speed, min_cast_speed, get_max_cast_speed())


## Unit vector the cast travels along. The rod chain carries no rotation or
## flip, so local +X is global +X and this needs no transform.
func aim_direction() -> Vector2:
	return Vector2.RIGHT.rotated(aim_angle)


func _wants_to_walk() -> bool:
	return not is_zero_approx(Input.get_axis("move_left", "move_right"))


## Back to choosing an angle, meter disarmed.
func reset_aim() -> void:
	phase = CastPhase.AIM
	if power_meter != null:
		power_meter.cancel()


func shoot() -> void:
	hook_fired.emit()

	var hook: Hook = projectile_scene.instantiate()
	hook.dir = aim_direction()
	hook.speed = projectile_speed
	get_tree().current_scene.add_child(hook)
	hook.global_position = $ShootPos.global_position
	hook.rod_tip = $ShootPos   # where the hook reels itself back to
	current_hook = hook

	# Skill upgrades are applied here, once per cast, using the hook scene's own
	# exported values as the base - so the numbers live in one place (the
	# inspector) and the tree only ever describes the delta.
	hook.capacity = Progression.stat_int(SkillStats.CATCH_CAPACITY, catch_capacity)
	hook.handling = Progression.stat(SkillStats.HANDLING, hook.handling)
	hook.dive_time = Progression.stat(SkillStats.DIVE_TIME, hook.dive_time) + _dive_bonus

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
func _on_hook_returned(catch: Array[CatchRecord]) -> void:
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
