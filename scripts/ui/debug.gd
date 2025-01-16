extends Control

@onready var fps_label : Label = $MarginContainer/VBoxContainer/FPSLabel
@onready var villager_count_label : Label = $MarginContainer/VBoxContainer/VillagerCountLabel
@onready var villagers_working_label : Label = $MarginContainer/VBoxContainer/VillagersWorkingLabel
@onready var villagers_resting_label : Label = $MarginContainer/VBoxContainer/VillagersRestingLabel
@onready var villagers_idle_label : Label = $MarginContainer/VBoxContainer/VillagersIdleLabel
@onready var villagers_walking_label : Label = $MarginContainer/VBoxContainer/VillagersWalkingLabel

func _process(delta: float) -> void:
	# Get the number of villagers by counting the members in the "villagers" group
	var villagers_in_group = get_tree().get_nodes_in_group("villagers")
	var villager_count = villagers_in_group.size()
	var working_count = 0
	var resting_count = 0
	var idle_count = 0
	var walking_count = 0
	
	# Loop through the villagers and count working and resting ones
	for villager in villagers_in_group:
		if villager.current_state == villager.VillagerStates.WORKING:
			working_count += 1
		elif villager.current_state == villager.VillagerStates.RESTING:
			resting_count += 1
		elif villager.current_state == villager.VillagerStates.IDLE:
			idle_count += 1
		elif villager.current_state == villager.VillagerStates.WALKING:
			walking_count += 1
	
	# Update the labels with the current counts
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
	villager_count_label.text = "Villagers: " + str(villager_count)
	villagers_working_label.text = "Working: " + str(working_count)
	villagers_resting_label.text = "Resting: " + str(resting_count)
	villagers_idle_label.text = "Idle: " + str(idle_count)
	villagers_walking_label.text = "Walking: " + str(walking_count)
