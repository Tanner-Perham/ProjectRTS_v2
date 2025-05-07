# resource_node_factory.gd
# Factory class for creating and placing resource nodes on the map
class_name ResourceNodeFactory
extends Node

# Resource node scene paths
@export var wood_resource_scene: PackedScene
@export var mineral_resource_scene: PackedScene
@export var stone_resource_scene: PackedScene

# Generation parameters
@export var min_resources_per_cluster: int = 3
@export var max_resources_per_cluster: int = 8
@export var cluster_radius: float = 10.0
@export var min_distance_between_clusters: float = 30.0

# Resource distribution
@export_range(0.0, 1.0) var wood_probability: float = 0.5
@export_range(0.0, 1.0) var mineral_probability: float = 0.3
@export_range(0.0, 1.0) var stone_probability: float = 0.2

# Node that will contain all spawned resources
var resource_parent: Node3D

# Initialize the factory with a parent node for resources
func initialize(parent_node: Node3D) -> void:
	resource_parent = parent_node

# Create a resource node of a specific type
func create_resource_node(type: String, position: Vector3) -> ResourceNode:
	var node: ResourceNode
	
	match type:
		"Wood":
			if wood_resource_scene:
				node = wood_resource_scene.instantiate() as WoodResourceNode
				# Randomize wood-specific properties
				node.tree_size = _random_size()
				node.tree_type = _random_tree_type()
				
		"Minerals":
			if mineral_resource_scene:
				node = mineral_resource_scene.instantiate() as MineralResourceNode
				# Randomize mineral-specific properties
				node.mineral_richness = _random_size()
				node.mineral_type = _random_mineral_type()
				
		"Stone":
			if stone_resource_scene:
				node = stone_resource_scene.instantiate() as StoneResourceNode
				# Randomize stone-specific properties
				node.stone_size = _random_size()
				node.stone_type = _random_stone_type()
	
	if node:
		# Set position
		node.position = position
		
		# Add some random rotation for visual variety
		node.rotation.y = randf_range(0, TAU)
		
		# Add to the resource parent node
		resource_parent.add_child(node)
		
		# If in a network game, setup for network spawning
		if multiplayer.has_multiplayer_peer():
			node.set_multiplayer_authority(1)  # Host always has authority over resources
	
	return node

# Generate resource clusters across the map
func generate_resource_clusters(map_size: Vector2, num_clusters: int) -> void:
	# Store cluster positions to ensure minimum distance
	var cluster_positions = []
	
	for i in range(num_clusters):
		# Find a valid position for this cluster
		var cluster_pos = _find_valid_cluster_position(map_size, cluster_positions)
		if cluster_pos == Vector2.ZERO:
			continue  # Couldn't find a valid position, skip this cluster
		
		cluster_positions.append(cluster_pos)
		
		# Determine cluster type (random or by region)
		var cluster_type = _determine_cluster_type()
		
		# Generate the cluster
		_generate_cluster(Vector3(cluster_pos.x, 0, cluster_pos.y), cluster_type)

# Find a valid position for a new cluster
func _find_valid_cluster_position(map_size: Vector2, existing_clusters: Array) -> Vector2:
	var max_attempts = 30
	
	for attempt in range(max_attempts):
		var pos = Vector2(
			randf_range(50, map_size.x - 50),  # Keep away from edges
			randf_range(50, map_size.y - 50)
		)
		
		var valid = true
		for cluster_pos in existing_clusters:
			if pos.distance_to(cluster_pos) < min_distance_between_clusters:
				valid = false
				break
		
		if valid:
			return pos
	
	# If we couldn't find a valid position after max attempts
	return Vector2.ZERO

# Determine the resource type for a cluster
func _determine_cluster_type() -> String:
	var roll = randf()
	
	if roll < wood_probability:
		return "Wood"
	elif roll < wood_probability + mineral_probability:
		return "Minerals"
	else:
		return "Stone"

# Generate a cluster of resources at a position
func _generate_cluster(center: Vector3, type: String) -> void:
	var resources_in_cluster = randi_range(min_resources_per_cluster, max_resources_per_cluster)
	
	for i in range(resources_in_cluster):
		# Calculate position within cluster radius
		var angle = randf_range(0, TAU)
		var distance = randf_range(0, cluster_radius)
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		# Create the resource node
		create_resource_node(type, center + offset)

# Helper functions for randomization
func _random_size() -> String:
	var sizes = ["Small", "Medium", "Large"]
	var weights = [0.3, 0.5, 0.2]  # Probabilities for each size
	
	var roll = randf()
	var cumulative = 0
	
	for i in range(sizes.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return sizes[i]
	
	return "Medium"  # Default fallback

func _random_tree_type() -> String:
	var types = ["Oak", "Pine", "Birch"]
	return types[randi() % types.size()]

func _random_mineral_type() -> String:
	var types = ["Iron", "Gold", "Copper"]
	return types[randi() % types.size()]

func _random_stone_type() -> String:
	var types = ["Granite", "Limestone", "Sandstone"]
	return types[randi() % types.size()]