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
@export var happiness : float = 100.0
@export var initial_happiness : float = 100.0

enum VillagerStates {
	IDLE,
	WALKING,
	WORKING,
	RESTING,
	SOCIALIZING
}

var ground_tilemap : TileMapLayer
var object_tilemap : TileMapLayer

var current_state : VillagerStates = VillagerStates.IDLE
var previous_state : VillagerStates = VillagerStates.IDLE

var direction : Vector2 = Vector2.ZERO
var target_position : Vector2 = Vector2.ZERO
var working_timer : Timer
var working_time : float = 3.0
var resting_timer : Timer
var resting_time : float = 10.0
var social_timer : Timer
var social_time : float = 30.0
var happiness_decay_timer : Timer
var happiness_decay_rate : float = 2.0

var is_resting: bool = false
var social_partner = null

func _ready():
	sprite.texture = texture
	ground_tilemap = get_tree().get_first_node_in_group("GroundLayer")
	object_tilemap = get_tree().get_first_node_in_group("ObjectLayer")
	position = find_valid_spawn_point()
	
	working_timer = Timer.new()
	working_timer.wait_time = working_time
	working_timer.one_shot = true
	working_timer.timeout.connect(_on_working_timer_timeout)
	add_child(working_timer)
	
	resting_timer = Timer.new()
	resting_timer.wait_time = resting_time
	resting_timer.one_shot = true
	resting_timer.timeout.connect(_on_resting_timer_timeout)
	add_child(resting_timer)
	
	social_timer = Timer.new()
	social_timer.wait_time = social_time
	social_timer.one_shot = true
	social_timer.timeout.connect(_on_social_timer_timeout)
	add_child(social_timer)
	
	happiness_decay_timer = Timer.new()
	happiness_decay_timer.wait_time = 1.0
	happiness_decay_timer.timeout.connect(_on_happiness_decay_timeout)
	add_child(happiness_decay_timer)
	happiness_decay_timer.start()
	
	action_progress_bar.visible = false
	action_progress_bar.min_value = 0
	action_progress_bar.max_value = 100
	action_progress_bar.value = 0
	
	stamina_progress_bar.value = stamina
	stamina_progress_bar.min_value = 0
	stamina_progress_bar.max_value = initial_stamina
	
	find_nearest_resource()

func _physics_process(delta):
	if current_state == VillagerStates.WALKING:
		move_to_target()
		# Check if both villagers have reached the meeting point for socializing
		if social_partner and global_position.distance_to(target_position) < 5.0:
			if social_partner.global_position.distance_to(target_position) < 5.0:
				start_socializing()
	elif current_state == VillagerStates.WORKING:
		velocity = Vector2.ZERO
		move_and_slide()
		update_progress_bar(delta)
	elif stamina <= 0 and !is_resting:
		start_resting()
	elif current_state == VillagerStates.RESTING:
		update_progress_bar(delta)
	elif current_state == VillagerStates.SOCIALIZING:
		update_progress_bar(delta)
		
	if happiness < 50 and current_state != VillagerStates.SOCIALIZING:
		find_social_partner()


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
		var progress = ((working_time - working_timer.time_left) / working_time) * 100
		action_progress_bar.value = progress
	elif current_state == VillagerStates.RESTING:
		var stamina_increase = (resting_time - resting_timer.time_left) / resting_time
		stamina = stamina_increase * initial_stamina
		stamina_progress_bar.value = stamina
	elif current_state == VillagerStates.SOCIALIZING:
		var social_progress = ((social_time - social_timer.time_left) / social_time) * 100
		action_progress_bar.value = social_progress

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

func find_social_partner():
	var nearest_distance = INF
	var nearest_villager = null
	
	for villager in get_tree().get_nodes_in_group("villagers"):
		# Skip villagers who are already socializing, resting, or have a social partner
		if villager == self or villager.current_state == VillagerStates.SOCIALIZING or \
		   villager.current_state == VillagerStates.RESTING or villager.social_partner != null:
			continue  
			
		# Allow villagers who are IDLE, WALKING, or WORKING to socialize
		if villager.current_state in [VillagerStates.IDLE, VillagerStates.WALKING, VillagerStates.WORKING]:
			var distance = global_position.distance_to(villager.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_villager = villager
	
	if nearest_villager:
		social_partner = nearest_villager
		# Calculate a midpoint between the two villagers for them to meet
		var meeting_point = (global_position + nearest_villager.global_position) / 2
		target_position = meeting_point
		
		# Store previous state so they can return to work later
		previous_state = current_state 
		current_state = VillagerStates.WALKING
		
		# Tell the other villager to also walk to the meeting point
		nearest_villager.join_social_interaction(self, meeting_point)

func join_social_interaction(partner, meeting_point):
	social_partner = partner
	previous_state = current_state
	target_position = meeting_point
	current_state = VillagerStates.WALKING

func start_socializing():
	if social_partner == null:
		return
		
	current_state = VillagerStates.SOCIALIZING
	action_progress_bar.visible = true
	action_progress_bar.value = 0
	social_timer.start()
	
	# Make sure both villagers face each other
	if social_partner.global_position.x > global_position.x:
		sprite.flip_h = false
	else:
		sprite.flip_h = true

func _on_social_timer_timeout():
	happiness = initial_happiness
	
	# Only the initiating villager should handle ending the social interaction for both
	if social_partner and social_partner.social_partner == self:
		social_partner.end_social_interaction()
	
	end_social_interaction()

func end_social_interaction():
	action_progress_bar.visible = false
	current_state = VillagerStates.IDLE
	social_partner = null
	find_nearest_resource()

func _on_happiness_decay_timeout():
	if current_state == VillagerStates.WORKING:
		happiness = max(0, happiness - happiness_decay_rate)

# Spawn point functionality
func find_valid_spawn_point() -> Vector2:
	# Safety checks for required tilemaps
	if not ground_tilemap:
		push_error("Ground tilemap not found!")
		return Vector2.ZERO
		
	var available_tiles = ground_tilemap.get_used_cells()
	if available_tiles.is_empty():
		push_error("No valid ground tiles found!")
		return Vector2.ZERO
	
	var tried_positions = []
	
	# Try random positions until we find a valid one or run out of options
	while tried_positions.size() < available_tiles.size():
		var random_tile = available_tiles[randi() % available_tiles.size()]
		
		if random_tile in tried_positions:
			continue
			
		tried_positions.append(random_tile)
		var potential_pos = ground_tilemap.map_to_local(random_tile)
		
		if is_spawn_position_valid(potential_pos):
			return potential_pos
			
	return Vector2.ZERO

func is_spawn_position_valid(pos: Vector2) -> bool:
	var tile_pos = ground_tilemap.local_to_map(pos)
	
	# Must have ground and no objects
	if ground_tilemap.get_cell_source_id(tile_pos) == -1:
		return false
	if object_tilemap.get_cell_source_id(tile_pos) != -1:
		return false
	
	# Must be away from other villagers
	for villager in get_tree().get_nodes_in_group("villagers"):
		if villager != self and villager.global_position.distance_to(pos) < 32:
			return false
			
	return true
