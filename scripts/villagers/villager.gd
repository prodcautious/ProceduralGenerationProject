extends CharacterBody2D

@export_category("Main")
@export var villager_resource : VillagerResource

@onready var sprite : Sprite2D = $Sprite2D
@onready var action_progress_bar : TextureProgressBar = $ActionProgressBar
@onready var stamina_progress_bar : TextureProgressBar = $StaminaProgressBar

var ground_tilemap : TileMapLayer # Layer 0
var object_tilemap : TileMapLayer # Layer 1

var current_state : VillagerResource.VillagerStates = VillagerResource.VillagerStates.IDLE
var previous_state : VillagerResource.VillagerStates = VillagerResource.VillagerStates.IDLE

var direction : Vector2 = Vector2.ZERO
var target_position : Vector2 = Vector2.ZERO
var working_timer : Timer
var working_time : float = 3.0  # Total time for working
var resting_timer : Timer
var resting_time : float = 10.0 # Total time for resting

var is_resting: bool = false # Track if the villager is resting

func _ready():
	sprite.texture = villager_resource.villager_texture
	
	ground_tilemap = get_tree().get_first_node_in_group("GroundLayer")
	object_tilemap = get_tree().get_first_node_in_group("ObjectLayer")

	# Find a valid spawn position
	find_valid_spawn_point()

	# Initialize working timer
	working_timer = Timer.new()
	working_timer.wait_time = working_time
	working_timer.one_shot = true
	working_timer.timeout.connect(_on_working_timer_timeout)
	add_child(working_timer)
	
	# Initialize resting timer
	resting_timer = Timer.new()
	resting_timer.wait_time = resting_time
	resting_timer.one_shot = true
	resting_timer.timeout.connect(_on_resting_timer_timeout)
	add_child(resting_timer)

	# Hide the progress bar initially
	action_progress_bar.visible = false
	action_progress_bar.min_value = 0
	action_progress_bar.max_value = 100
	action_progress_bar.value = 0

	# Initialize the stamina progress bar
	stamina_progress_bar.value = villager_resource.villager_stamina
	stamina_progress_bar.min_value = 0
	stamina_progress_bar.max_value = villager_resource.villager_stamina

	# Start the autonomous loop
	find_nearest_resource()

func _physics_process(delta):
	if current_state == VillagerResource.VillagerStates.WALKING:
		move_to_target()
	elif current_state == VillagerResource.VillagerStates.WORKING:
		velocity = Vector2.ZERO
		move_and_slide()
		update_progress_bar(delta)
	elif villager_resource.objects_mined == villager_resource.max_objects_mineable and !is_resting:
		start_resting()
	elif current_state == VillagerResource.VillagerStates.RESTING:
		update_progress_bar(delta)  # Update the progress bar during resting

func find_nearest_resource():
	if not object_tilemap:
		return

	var villager_tile_pos = object_tilemap.local_to_map(global_position)
	var nearest_tile_pos = Vector2.ZERO
	var nearest_distance = INF

	for tile_pos in object_tilemap.get_used_cells():
		var distance = villager_tile_pos.distance_to(tile_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tile_pos = tile_pos

	if nearest_distance != INF:
		target_position = object_tilemap.map_to_local(nearest_tile_pos)
		current_state = VillagerResource.VillagerStates.WALKING

func move_to_target():
	if target_position != Vector2.ZERO:
		direction = (target_position - global_position).normalized()
		velocity = direction * villager_resource.villager_movement_speed
		move_and_slide()

		if global_position.distance_to(target_position) < 5.0:  # Small threshold for stopping
			start_working()

func start_working():
	current_state = VillagerResource.VillagerStates.WORKING
	working_timer.start()
	action_progress_bar.visible = true
	action_progress_bar.value = 0

func start_resting():
	if is_resting:  # Prevent starting resting multiple times
		return
	current_state = VillagerResource.VillagerStates.RESTING
	is_resting = true  # Set resting flag
	velocity = Vector2.ZERO  # Stop movement
	move_and_slide()
	resting_timer.start()
	action_progress_bar.visible = true
	action_progress_bar.value = 0

func update_progress_bar(delta):
	if current_state == VillagerResource.VillagerStates.WORKING:
		# Working progress bar
		var progress = ((working_time - working_timer.time_left) / working_time) * 100
		action_progress_bar.value = progress
	elif current_state == VillagerResource.VillagerStates.RESTING:
		# Resting progress bar - increase stamina over time
		var stamina_increase = (resting_time - resting_timer.time_left) / resting_time
		villager_resource.villager_stamina = stamina_increase * villager_resource.villager_initial_stamina
		
		# Update stamina progress bar
		stamina_progress_bar.value = villager_resource.villager_stamina


func _on_working_timer_timeout():
	var tile_pos = object_tilemap.local_to_map(target_position)
	object_tilemap.erase_cell(tile_pos)
	action_progress_bar.visible = false
	villager_resource.objects_mined += 1
	
	# Decrease stamina after each task completed
	decrease_stamina()

	# Check if villager needs to rest
	if villager_resource.objects_mined >= villager_resource.max_objects_mineable:
		start_resting()
	else:
		current_state = VillagerResource.VillagerStates.IDLE
		find_nearest_resource()

func decrease_stamina():
	# Decrease stamina by the initial stamina divided by the number of tasks
	var stamina_decrement = villager_resource.villager_initial_stamina / villager_resource.max_objects_mineable
	villager_resource.villager_stamina -= stamina_decrement
	
	# Prevent stamina from going below 0
	if villager_resource.villager_stamina < 0:
		villager_resource.villager_stamina = 0
	
	# Update stamina progress bar
	stamina_progress_bar.value = villager_resource.villager_stamina

func _on_resting_timer_timeout():
	is_resting = false  # Reset resting flag
	current_state = VillagerResource.VillagerStates.IDLE
	action_progress_bar.visible = false
	villager_resource.villager_stamina = 100
	villager_resource.objects_mined = 0
	
	# Reset stamina progress bar after resting
	stamina_progress_bar.value = villager_resource.villager_stamina
	
	# Find a new resource to work on after finishing
	find_nearest_resource()

func find_valid_spawn_point():
	if not ground_tilemap or not object_tilemap:
		return
	
	var valid_spawn_points = []
	
	# Iterate through all ground tiles (Layer 0)
	for tile_pos in ground_tilemap.get_used_cells():
		# Ensure there's NO object in this tile (Layer 1)
		if object_tilemap.get_cell_source_id(tile_pos) == -1: 
			valid_spawn_points.append(tile_pos)

	# Pick a random spawn point from the valid list
	if valid_spawn_points.size() > 0:
		var chosen_tile = valid_spawn_points[randi() % valid_spawn_points.size()]
		global_position = ground_tilemap.map_to_local(chosen_tile)
	else:
		return
