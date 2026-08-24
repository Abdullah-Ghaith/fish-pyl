class_name TrajectoryLine extends Line2D


func update_trajectory(dir: Vector2, speed: float, gravity: float, delta: float) -> void:
	var max_points = 300
	clear_points()
	var pos: Vector2 = Vector2.ZERO
	var vel = dir * speed
	for i in max_points:
		add_point(pos)
		vel.y += gravity * delta
	
		var collision : KinematicCollision2D = $CollisionTest.move_and_collide(vel * delta, false, true, true)
		if collision:
			vel = vel.bounce(collision.get_normal()) * 0.6

		pos += vel * delta
		$CollisionTest.position = pos
