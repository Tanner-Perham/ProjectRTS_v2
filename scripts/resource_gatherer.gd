# resource_gatherer.gd
# Component for units that can gather resources
class_name ResourceGatherer
extends Node

# Resource gathering properties
@export var base_gather_rate: int = 10 # Resources gathered per gathering cycle
@export var gather_cycle_time: float = 1.0 # Time in seconds for one gathering cycle
@export var carrying_capacity: int = 50 # Maximum resources the unit can carry before returning to drop-off
@export var gather_radius: float = 1.5 # How close the unit needs to be to gather

# References to other components
@export var unit_movement: Node # Reference to the unit's movement component
@export var animator: Node # Reference to the unit's animator

# Current state
var current_resource_node: ResourceNode = null
var current_gathered_amount: int = 0
var current_resource_type: String = ""
var gathering_active: bool = false
var gather_timer: float = 0.0
var gather_point: Vector3 = Vector3.ZERO

# Unit owner info
var player_id: int = 1 # Default to player 1, should be set by the unit

# Reference to resource system
var resource_system: ResourceSystem

# Called when the node enters the scene tree
func _ready():
	# Find resource system in the scene
	resource_system = get_node("/root/Main/ResourceSystem")
	
	# If we couldn't find it in the expected path, look for it as a singleton
	if not resource_system:
		resource_system = get_node("/root/ResourceSystem")
	
	# Get player ID from parent unit if available
	if get_parent() and get_parent().has_method("get_player_id"):
		player_id = get_parent().get_player_id()

# Process function for gathering resources
func _process(delta: float):
	if not gathering_active or not current_resource_node:
		return
	
	# Check if we're close enough to the resource to gather
	var distance_to_resource = get_parent().global_transform.origin.distance_to(gather_point)
	if distance_to_resource > gather_radius:
		# If we're too far, move to the gather point
		if unit_movement:
			unit_movement.move_to(gather_point)
		return
	
	# If we were moving, stop
	if unit_movement and unit_movement.is_moving():
		unit_movement.stop_moving()
	
	# Increment gather timer
	gather_timer += delta
	
	# Play gathering animation if available
	if animator and animator.has_method("play_animation"):
		animator.play_animation("gather")
	
	# Check if a gather cycle is complete
	if gather_timer >= gather_cycle_time:
		gather_timer = 0.0
		
		# Calculate how much to gather in this cycle
		var to_gather = min(base_gather_rate, carrying_capacity - current_gathered_amount)
		
		# If we're full, return to drop-off
		if to_gather <= 0:
			return_to_drop_off()
			return
		
		# Actually gather resources from the node
		var gathered = current_resource_node.gather_resources(to_gather)
		
		# Update our carried amount
		current_gathered_amount += gathered
		
		# If node is depleted or we're full, return to drop-off
		if gathered == 0 or current_gathered_amount >= carrying_capacity:
			return_to_drop_off()

# Start gathering from a resource node
func start_gathering(resource_node: ResourceNode) -> bool:
	# Check if the node is valid
	if not is_instance_valid(resource_node):
		return false
	
	# Try to start gathering from the node
	if not resource_node.start_gathering(get_instance_id()):
		return false
	
	# If we were already gathering from another node, stop that first
	if current_resource_node != null and current_resource_node != resource_node:
		stop_gathering()
	
	# Set our current node and type
	current_resource_node = resource_node
	current_resource_type = resource_node.resource_type
	
	# Get a gather point near the resource
	gather_point = resource_node.get_nearest_gather_point(get_parent().global_transform.origin)
	
	# Activate gathering
	gathering_active = true
	gather_timer = 0.0
	
	# If we have a movement component, move to the gather point
	if unit_movement:
		unit_movement.move_to(gather_point)
	
	return true

# Stop gathering resources
func stop_gathering() -> void:
	if current_resource_node != null:
		current_resource_node.stop_gathering(get_instance_id())
		
	# Reset state
	gathering_active = false
	current_resource_node = null
	gather_timer = 0.0
	
	# Stop gathering animation if applicable
	if animator and animator.has_method("stop_animation"):
		animator.stop_animation("gather")

# Return gathered resources to a drop-off point
func return_to_drop_off() -> void:
	if current_gathered_amount <= 0:
		# Nothing to return
		return
	
	# Temporarily stop gathering
	gathering_active = false
	
	# Find the nearest drop-off point
	var drop_off_point = find_nearest_drop_off()
	
	# If no drop-off found, can't return resources
	if drop_off_point == null:
		# Resume gathering
		gathering_active = true
		return
	
	# Get the drop-off position
	var drop_off_position = drop_off_point.global_transform.origin
	
	# Move to the drop-off point
	if unit_movement:
		unit_movement.move_to(drop_off_position)
		
		# Wait until we reach the drop-off point
		# In a real implementation, you'd use signals or state machines
		# For simplicity, we'll use a coroutine here
		await get_tree().create_timer(0.1).timeout
		
		while unit_movement.is_moving():
			await get_tree().create_timer(0.1).timeout
	
	# Once at drop-off, deposit resources
	deposit_resources()
	
	# Return to gathering if we still have a valid node
	if current_resource_node != null and is_instance_valid(current_resource_node):
		# Resume gathering
		gathering_active = true
		
		# Move back to the resource
		if unit_movement:
			unit_movement.move_to(gather_point)

# Find the nearest drop-off point for the current resource type
func find_nearest_drop_off():
	# This would typically search through all buildings to find the nearest drop-off
	# For simplicity, we'll assume there's a global method to find it
	
	# First check for a resource camp that accepts our resource type
	var nearest_camp = null
	var nearest_distance = INF
	
	# Look for resource camps or the main base
	var buildings = get_tree().get_nodes_in_group("buildings")
	
	for building in buildings:
		# Check if this building belongs to our player
		if building.has_method("get_player_id") and building.get_player_id() != player_id:
			continue
		
		# Check if this building is a drop-off point for our resource
		var is_drop_off = false
		
		if building.has_method("is_resource_drop_off"):
			is_drop_off = building.is_resource_drop_off(current_resource_type)
		elif building.has_method("get_building_type"):
			# Main base can accept all resources
			if building.get_building_type() == "MainBase":
				is_drop_off = true
			# Resource camps only accept specific resources
			elif building.get_building_type() == "ResourceCamp":
				if building.has_method("get_resource_type"):
					is_drop_off = building.get_resource_type() == current_resource_type
		
		if not is_drop_off:
			continue
		
		# Calculate distance
		var distance = get_parent().global_transform.origin.distance_to(building.global_transform.origin)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_camp = building
	
	return nearest_camp

# Deposit gathered resources at a drop-off point
func deposit_resources() -> void:
	if current_gathered_amount <= 0 or current_resource_type == "":
		return
	
	# Add resources to the player's stockpile
	if resource_system:
		resource_system.add_resources(player_id, current_resource_type, current_gathered_amount)
	
	# Reset carried amount
	current_gathered_amount = 0
	
	# Play deposit animation if available
	if animator and animator.has_method("play_animation"):
		animator.play_animation("deposit")

# Get the current carried amount
func get_current_carried_amount() -> int:
	return current_gathered_amount

# Get the current resource type being gathered
func get_current_resource_type() -> String:
	return current_resource_type

# RPC functions for multiplayer
@rpc("authority", "reliable")
func sync_gathered_amount(amount: int, type: String) -> void:
	current_gathered_amount = amount
	current_resource_type = type
