extends Node2D

var fnl := FastNoiseLite.new()
var tree_noise := FastNoiseLite.new()
var rock_noise := FastNoiseLite.new()
var world_size_x : int = 60
var world_size_y : int = 34


@onready var ground_tilemap : TileMapLayer = $Ground
@onready var object_tilemap : TileMapLayer = $Objects

func _ready() -> void:
	# Setup main terrain noise
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnl.frequency = 0.05
	fnl.seed = randi()
	
	# Setup tree clustering noise
	tree_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	tree_noise.frequency = 0.1  # Higher frequency = smaller clusters
	tree_noise.seed = randi()
	
	# Setup rock clustering noise
	rock_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rock_noise.frequency = 0.15  # Even higher frequency = smaller clusters
	rock_noise.seed = randi()
	
	generateMap()

func generateMap() -> void:
	# First pass: Generate ground and trees
	for x in range(world_size_x):
		for y in range(world_size_y):
			var noiseVal := fnl.get_noise_2d(x * 0.8, y * 0.8)
			
			# Set ground tile
			if noiseVal > -0.1 and noiseVal < 0.2:
				ground_tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
				
				# Check for tree cluster
				var tree_noise_val = tree_noise.get_noise_2d(x, y)
				if tree_noise_val > 0.2:  # Adjust threshold to control tree density
					object_tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))  # Place tree
			else:
				ground_tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	
	# Second pass: Generate rocks
	for x in range(world_size_x):
		for y in range(world_size_y):
			var rock_noise_val = rock_noise.get_noise_2d(x, y)
			
			# Check if we should try to place a rock here
			if rock_noise_val > 0.3:  # Adjust threshold to control rock density
				var can_place_rock = true
				
				# Check if there's a tree below
				if y < 255 and object_tilemap.get_cell_source_id(Vector2i(x, y + 1)) != -1:
					# If there's a tree below, try to find a nearby spot
					var placed = false
					for offset_x in range(-2, 3):  # Check 2 tiles left and right
						for offset_y in range(-2, 3):  # Check 2 tiles up and down
							var new_x = x + offset_x
							var new_y = y + offset_y
							
							# Check if the new position is valid and free
							if new_x >= 0 and new_x < world_size_x and world_size_y >= 0 and new_y < 256:
								if object_tilemap.get_cell_source_id(Vector2i(new_x, new_y)) == -1:
									# No objects at this position, place the rock here
									object_tilemap.set_cell(Vector2i(new_x, new_y), 0, Vector2i(0, 1))
									placed = true
									break
						if placed:
							break
				else:
					# No tree below, place rock normally
					if object_tilemap.get_cell_source_id(Vector2i(x, y)) == -1:
						object_tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 1))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("re-generate"):
		get_tree().reload_current_scene()
