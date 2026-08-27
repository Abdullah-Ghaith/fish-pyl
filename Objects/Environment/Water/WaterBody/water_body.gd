class_name WaterBody extends Node2D

const WATER_SPRING = preload("uid://dyocq22qpgc0x")

@export_category("Spring Constants")
@export var k : float = 0.015 # spring const
@export var d : float = 0.03  # damp
@export var spread : float = 0.0002 # co-eff for how much waves spread to their neighbour

@export_category("Feel")
@export var passes : int = 8
@export var curve_tightness : float = 0.25

@export_category("Spring Amount")
@export var distance_between_springs : float = 32
@export var num_springs : int = 6

@export_category("Water Depth")
@export var depth = 1000
var target_height: float = global_position.y
var bottom : float = target_height + depth
@onready var water_polygon: Polygon2D = %WaterPolygon
var springs : Array = []

@onready var water_border: SmoothPath = $WaterBorder
@export var border_thickness: float = 1.1

@onready var water_body_area: Area2D = $WaterBodyArea
@onready var water_body_collision_shape: CollisionShape2D = $WaterBodyArea/WaterBodyCollisionShape
@onready var total_length : float = distance_between_springs * (num_springs - 1)

signal entered_water 

func _ready() -> void:
	#Area setup:
	water_body_area.position = Vector2(total_length / 2, depth / 2)
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(total_length, depth)
	water_body_collision_shape.set_shape(rectangle)
	
	water_border.width = border_thickness
	
	for i in range(num_springs):
		var x_pos : float = distance_between_springs * i
		var w : WaterSpring = WATER_SPRING.instantiate()
		add_child(w)
		springs.append(w)
		w.initialize(x_pos, i)
		w.set_collision_width(distance_between_springs)
		w.splash.connect(splash)

func _physics_process(delta: float) -> void:
	
	for i : WaterSpring in springs:
		i.water_update(k,d)
	
	var left_deltas = []
	var right_deltas = []
	
	for i in range(springs.size()):
		left_deltas.append(0)
		right_deltas.append(0)
	
	for j in range(passes):
		for i in range(springs.size()):
			if i > 0:
				left_deltas[i] = spread * (springs[i].height - springs[i-1].height)
				springs[i-1].velocity += left_deltas[i]
			if i < springs.size() - 1:
				right_deltas[i] = spread * (springs[i].height - springs[i+1].height)
				springs[i+1].velocity += right_deltas[i]
		for i in range(springs.size()):
			if i > 0:
				springs[i-1].height += left_deltas[i]
			if i < springs.size() - 1:
				springs[i+1].height += right_deltas[i]
	
	new_border()
	draw_water_body()

func splash(index: int, speed: float) -> void:
	if index >= 0 and index < springs.size():
		springs[index].velocity += speed

func draw_water_body():
	
	var curve = water_border.curve
	var water_polygon_points = Array(curve.get_baked_points())
	
	var first_index = 0
	var last_index = water_polygon_points.size()-1
	
	water_polygon_points.append(Vector2(water_polygon_points[last_index].x, bottom))   #these 2 make it a quadrilateral instead of a line 
	water_polygon_points.append(Vector2(water_polygon_points[first_index].x, bottom))
	
	water_polygon.set_polygon(PackedVector2Array(water_polygon_points))

func new_border():
	var curve = Curve2D.new()
	
	# 1. Grab all the current positions from our springs
	var surface_points = []
	for i in range(springs.size()):
		surface_points.append(springs[i].position)
	
	# 2. Loop through and mathematically smooth the connections
	for i in range(surface_points.size()):
		var p = surface_points[i]
		
		var handle_left = Vector2.ZERO
		var handle_right = Vector2.ZERO
		
		# Only calculate curves for middle segments
		if i > 0 and i < surface_points.size() - 1:
			# Look at the spring behind us and the spring ahead of us
			var prev_p = surface_points[i - 1]
			var next_p = surface_points[i + 1]
			
			# Vector between neighbor points dictates the horizontal tangent line
			var tangent = (next_p - prev_p).normalized()
			
			var distance = distance_between_springs * curve_tightness
			
			handle_left = -tangent * distance
			handle_right = tangent * distance
		
		# Add the point along with its left and right bezier handles
		curve.add_point(p, handle_left, handle_right)
	
	# 3. Update the path representation
	water_border.curve = curve
	water_border.queue_redraw()


func _on_water_body_area_body_entered(body: Node2D) -> void:
	entered_water.emit()
	if body is Hook:
		# Hand the hook the exact waterline height so the fishing line can pin
		# its slack at the surface instead of wherever the overlap was reported.
		body.entered_water.emit(surface_y_at(body.global_position.x))
	elif body.has_signal("entered_water"):
		body.entered_water.emit()


## Global y of the waterline at a given global x, interpolated between springs.
func surface_y_at(global_x: float) -> float:
	if springs.is_empty():
		return global_position.y
	var local_x: float = to_local(Vector2(global_x, 0.0)).x
	var f: float = clampf(local_x / distance_between_springs, 0.0, float(springs.size() - 1))
	var i: int = int(floor(f))
	var j: int = mini(i + 1, springs.size() - 1)
	var h: float = lerpf(springs[i].position.y, springs[j].position.y, f - float(i))
	return to_global(Vector2(local_x, h)).y
