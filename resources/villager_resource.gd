extends Resource
class_name VillagerResource

@export var villager_type : String = "Default"
@export var villager_texture : Texture2D
@export var villager_movement_speed : float = 75.0
@export var villager_stamina : float = 75.0
@export var villager_initial_stamina : float = 75.0
@export var objects_mined : int = 0
@export var max_objects_mineable : int = 3

enum VillagerStates {
	IDLE,
	WALKING,
	WORKING,
	RESTING
}
