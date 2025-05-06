# resource_drop_off.gd
class_name ResourceDropOff
extends Node3D

# What resource types this drop-off accepts
@export var accepted_resource_types: Array[String] = ["Wood", "Minerals", "Stone"]
# Default to accepting all resource types for the Main Base
# For resource camps, override to accept only specific types

# Reference to building owner info
@onready var building = get_parent()

# Called when the node enters the scene tree
func _ready():
	# Add to drop-off points group for easy querying
	add_to_group("resource_drop_offs")

# Check if this drop-off accepts a given resource type
func accepts_resource_type(resource_type: String) -> bool:
	return resource_type in accepted_resource_types

# Get the drop-off position where units should go
func get_drop_off_position() -> Vector3:
	# By default, use the building's position
	# You can add specific marker nodes for more control
	if has_node("DropOffMarker"):
		return $DropOffMarker.global_position
	return global_position

# Get the owner player ID
func get_player_id() -> int:
	if building and building.has_method("get_player_id"):
		return building.get_player_id()
	return 1 # Default to player 1
