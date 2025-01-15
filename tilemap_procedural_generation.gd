extends Node2D

var fnl := FastNoiseLite.new()
@onready var ground_tilemap : TileMapLayer = $Ground
@onready var object_tilemap : TileMapLayer = $Objects

func _ready() -> void:
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	seed( randi() )
	fnl.frequency = randf()
	randomize()
	generateMap()

func generateMap() -> void:
	for x in range(30):
		for y in range(30):
			var noiseVal := fnl.get_noise_2d(x,y)
			print(noiseVal)
			if noiseVal < 0.14:
				ground_tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0,0))
				object_tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1,1))
			else:
				ground_tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0,0))
