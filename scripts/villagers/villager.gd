extends CharacterBody2D

@export_category("Main")

@onready var sprite : Sprite2D = $Sprite2D
@onready var action_progress_bar : TextureProgressBar = $ActionProgressBar
@onready var stamina_progress_bar : TextureProgressBar = $StaminaProgressBar

@export var type : String = "Default"
@export var texture : Texture2D = load("res://assets/characters/villagers/default_villager_sprite.png")
@export var movement_speed : float = 100.0
@export var stamina : float = 100.0
@export var initial_stamina : float = 100.0


enum VillagerStates {
	IDLE,
	WALKING,
	WORKING,
	RESTING
}


var ground_tilemap : TileMapLayer # Layer 0
var object_tilemap : TileMapLayer # Layer 1

var current_state : VillagerStates = VillagerStates.IDLE
var previous_state : VillagerStates = VillagerStates.IDLE

var direction : Vector2 = Vector2.ZERO
var target_position : Vector2 = Vector2.ZERO
var working_timer : Timer
var working_time : float = 3.0  # Total time for working
var resting_timer : Timer
var resting_time : float = 10.0 # Total time for resting

var is_resting: bool = false # Track if the villager is resting

func _ready():
	sprite.texture = texture
	ground_tilemap = get_tree().get_first_node_in_group("GroundLayer")
	object_tilemap = get_tree().get_first_node_in_group("ObjectLayer")

	# Remove find_valid_spawn_point and directly set position
	# Assuming spawn position is passed when the villager is instantiated
	# If instantiation logic already sets the position, this is no longer needed

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
	stamina_progress_bar.value = stamina
	stamina_progress_bar.min_value = 0
	stamina_progress_bar.max_value = initial_stamina

	# Start the autonomous loop
	find_nearest_resource()

func _physics_process(delta):
	if current_state == VillagerStates.WALKING:
		move_to_target()
	elif current_state == VillagerStates.WORKING:
		velocity = Vector2.ZERO
		move_and_slide()
		update_progress_bar(delta)
	elif stamina <= 0 and !is_resting:  # Rest when stamina is 0
		start_resting()
	elif current_state == VillagerStates.RESTING:
		update_progress_bar(delta)  # Update the progress bar during resting

#func _update_animation():
	#if current_state == VillagerStates.IDLE:
		

func find_nearest_resource():
	if not object_tilemap:
		return

	var villager_tile_pos = object_tilemap.local_to_map(global_position)
	var nearest_tile_pos = Vector2.ZERO
	var nearest_distance = INF

	# Loop through all the villagers to avoid selecting resources being worked on
	var busy_resources = []  # To store positions of resources already in use

	# Check if any villager is walking toward a resource or working at a resource
	for villager in get_tree().get_nodes_in_group("villagers"):
		if villager.current_state == VillagerStates.WORKING:
			# Add the resource position to busy_resources if it's currently being worked on
			var working_tile_pos = object_tilemap.local_to_map(villager.target_position)
			busy_resources.append(working_tile_pos)
		elif villager.current_state == VillagerStates.WALKING:
			# Add the target resource to busy_resources if the villager is walking toward it
			var walking_tile_pos = object_tilemap.local_to_map(villager.target_position)
			if walking_tile_pos not in busy_resources:
				busy_resources.append(walking_tile_pos)

	# Now find the nearest resource that isn't busy
	for tile_pos in object_tilemap.get_used_cells():
		if tile_pos in busy_resources:
			continue  # Skip this resource if it's already being worked on or walked to

		var distance = villager_tile_pos.distance_to(tile_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tile_pos = tile_pos

	# If no resource is found, set the villager to idle
	if nearest_distance == INF:
		current_state = VillagerStates.IDLE
	else:
		# Resource found, start walking towards it
		target_position = object_tilemap.map_to_local(nearest_tile_pos)
		current_state = VillagerStates.WALKING

func move_to_target():
	if target_position != Vector2.ZERO:
		direction = (target_position - global_position).normalized()
		velocity = direction * movement_speed
		move_and_slide()

		if global_position.distance_to(target_position) < 5.0:  # Small threshold for stopping
			start_working()

func start_working():
	if stamina > 0:  # Only start working if there's enough stamina
		current_state = VillagerStates.WORKING
		working_timer.start()
		action_progress_bar.visible = true
		action_progress_bar.value = 0

func start_resting():
	if is_resting:  # Prevent starting resting multiple times
		return
	current_state = VillagerStates.RESTING
	is_resting = true  # Set resting flag
	velocity = Vector2.ZERO  # Stop movement
	move_and_slide()
	resting_timer.start()
	action_progress_bar.visible = true
	action_progress_bar.value = 0

func update_progress_bar(delta):
	if current_state == VillagerStates.WORKING:
		# Working progress bar
		var progress = ((working_time - working_timer.time_left) / working_time) * 100
		action_progress_bar.value = progress
	elif current_state == VillagerStates.RESTING:
		# Resting progress bar - increase stamina over time
		var stamina_increase = (resting_time - resting_timer.time_left) / resting_time
		stamina = stamina_increase * initial_stamina
		
		# Update stamina progress bar
		stamina_progress_bar.value = stamina

func _on_working_timer_timeout():
	var tile_pos = object_tilemap.local_to_map(target_position)
	object_tilemap.erase_cell(tile_pos)
	action_progress_bar.visible = false
	
	# Decrease stamina after each task completed
	decrease_stamina()

	# Check if villager needs to rest based on stamina
	if stamina <= 0:
		start_resting()
	else:
		current_state = VillagerStates.IDLE
		find_nearest_resource()

func decrease_stamina():
	# Decrease stamina by a set amount
	var stamina_decrement = 5  # Example decrement per work task
	
	stamina -= stamina_decrement
	
	# Prevent stamina from going below 0
	if stamina < 0:
		stamina = 0
	
	# Update stamina progress bar
	stamina_progress_bar.value = stamina

func _on_resting_timer_timeout():
	is_resting = false  # Reset resting flag
	current_state = VillagerStates.IDLE
	action_progress_bar.visible = false
	stamina = initial_stamina  # Reset stamina after resting
	
	# Reset stamina progress bar after resting
	stamina_progress_bar.value = stamina
	
	# Find a new resource to work on after finishing
	find_nearest_resource()
