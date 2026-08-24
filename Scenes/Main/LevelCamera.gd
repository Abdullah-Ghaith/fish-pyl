extends Camera2D

@export var map_layer: TileMapLayer # Or reference your main boundary node

func _ready() -> void:
	# Get the used rectangle region in tile coordinates
	var map_rect: Rect2i = map_layer.get_used_rect()
	var cell_size: Vector2i = map_layer.tile_set.tile_size
	
	# Convert tile coordinates to absolute pixels and apply to limits
	limit_left = map_rect.position.x * cell_size.x
	limit_top = map_rect.position.y * cell_size.y
	limit_right = map_rect.end.x * cell_size.x
	limit_bottom = map_rect.end.y * cell_size.y
