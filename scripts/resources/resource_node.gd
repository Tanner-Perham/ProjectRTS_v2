# resource_node.gd
# Base class for all resource nodes in the game
class_name ResourceNode
extends Node3D

# Network synchronization
@export var sync_properties := ["resource_amount", "is_being_gathered", "gatherer_id"]

# Resource properties
@export var resource_type: String = "Base" # Override in child classes: "Wood", "Minerals", "Stone"
@export var max_resource_amount: int = 1000
@export var current_resource_amount: int = 1000
@export var gather_rate_modifier: float = 1.0 # Modifier that affects how quickly this node can be gathered

# Gathering properties
var is_being_gathered: bool = false
var gatherer_id: int = -1 # ID of the unit gathering from this node, -1 means no unit

# Visual representation
@export var intact_mesh: Mesh
@export var depleted_mesh: Mesh
@export var depletion_stages: int = 3 # How many visual stages of depletion to show
@export var depletion_threshold: float = 0.33 # Percentage threshold for each depletion stage

# Node references
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var mesh_instance: MeshInstance3D = $MeshInstance
@onready var gather_points: Node3D = $GatherPoints

# Called when the node enters the scene tree for the first time
func _ready():
	# Initialize resource node
	current_resource_amount = max_resource_amount
	update_visual_state()
	
	# If we're in a networked game, set up multiplayer synchronization
	if multiplayer.has_multiplayer_peer():
		# Add a MultiplayerSynchronizer if not already added
		if not has_node("MultiplayerSynchronizer"):
			var synchronizer = MultiplayerSynchronizer.new()
			synchronizer.name = "MultiplayerSynchronizer"
			synchronizer.replication_config = create_replication_config()
			add_child(synchronizer)

# Create a replication configuration for the MultiplayerSynchronizer
func create_replication_config() -> SceneReplicationConfig:
	var config = SceneReplicationConfig.new()
	
	# Add properties to replicate
	for property in sync_properties:
		config.add_property(property)
	
	return config

# Start gathering resources from this node
func start_gathering(gatherer_unit_id: int) -> bool:
	# Check if there are resources left
	if current_resource_amount <= 0:
		return false
		
	# Check if already being gathered
	if is_being_gathered and gatherer_id != gatherer_unit_id:
		return false
	
	is_being_gathered = true
	gatherer_id = gatherer_unit_id
	
	return true

# Stop gathering resources from this node
func stop_gathering(gatherer_unit_id: int) -> void:
	# Only the unit that started gathering can stop it
	if gatherer_id == gatherer_unit_id:
		is_being_gathered = false
		gatherer_id = -1

# Gather a specified amount of resources
# Returns the actual amount gathered (may be less if node is nearly depleted)
func gather_resources(amount: int) -> int:
	# If no resources left, return 0
	if current_resource_amount <= 0:
		return 0
	
	# Calculate actual amount to gather (limited by what's available)
	var actual_amount = min(amount, current_resource_amount)
	
	# Reduce the resource amount
	current_resource_amount -= actual_amount
	
	# Update the visual state based on remaining resources
	update_visual_state()
	
	# Check if node is depleted
	if current_resource_amount <= 0:
		_on_depleted()
	
	return actual_amount

# Update the visual appearance based on resource depletion level
func update_visual_state() -> void:
	#if current_resource_amount <= 0:
		## Fully depleted
		#mesh_instance.mesh = depleted_mesh
	#else:
		## Partially depleted - could implement multiple visual stages here
		#var depletion_ratio = float(current_resource_amount) / float(max_resource_amount)
		#mesh_instance.mesh = intact_mesh
		#
		## You could implement a shader parameter or mesh swap based on depletion stage
		## For example:
		#var stage = floor(depletion_ratio / depletion_threshold)
		# Then use 'stage' to modify appearance
		pass

# Get the nearest available gather point for a unit
func get_nearest_gather_point(unit_position: Vector3) -> Vector3:
	var closest_point = global_transform.origin
	var closest_distance = INF
	
	# Find the closest gather point
	for point in gather_points.get_children():
		var distance = point.global_transform.origin.distance_to(unit_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_point = point.global_transform.origin
	
	return closest_point

# Called when resources are depleted
func _on_depleted() -> void:
	# Handle complete depletion (e.g. visual changes, collision adjustment)
	is_being_gathered = false
	gatherer_id = -1
	
	# Signal to any interested systems that this node is depleted
	# For example, the AI system might want to know
	emit_signal("resource_depleted", self)
	
	# Optional: Remove node after a delay
	# var timer = get_tree().create_timer(30.0)  # Remove after 30 seconds
	# await timer.timeout
	# queue_free()

# Signal emitted when the resource node is depleted
signal resource_depleted(node)
