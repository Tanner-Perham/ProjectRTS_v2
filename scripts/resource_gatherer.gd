# resource_gatherer.gd
# Component for units that can gather resources
class_name ResourceGatherer
extends Node

# Resource gathering properties
@export var base_gather_rate: int = 10 # Resources gathered per gathering cycle
@export var gather_cycle_time: float = 1.0 # Time in seconds for one gathering cycle
@export var carrying_capacity: int = 50 # Maximum resources the unit can carry before returning to drop-off
@export var gather_radius: float = 1.5 # How close the unit needs to be to gather

# Parent unit reference
var unit_base: Node3D

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
	# Get the parent unit
	unit_base = get_parent()
	
	print("ResourceGatherer initialized for unit: ", unit_base.name)
	
	# Find resource system in the scene
	resource_system = get_node("/root/Main/ResourceSystem")
	
	# If we couldn't find it in the expected path, look for it as a singleton
	if not resource_system:
		resource_system = get_node("/root/ResourceSystem")
	
	# Get player ID from parent unit if available
	if unit_base and unit_base.has_method("get_player_id"):
		player_id = unit_base.get_player_id()
	elif unit_base and "player_owner" in unit_base:
		player_id = int(unit_base.player_owner)

	# Connect to the unit's movement signals to detect player commands
	if unit_base:
		# Use deferred connection to avoid issues during gathering
		unit_base.connect("movement_commanded", _on_movement_commanded)

# Process function for gathering resources
func _process(delta: float):
	if not gathering_active or not current_resource_node:
		return
	
	# Check if the unit has been commanded to move away (pathing is active but not to our gather point)
	if unit_base and unit_base.movement_controller.pathing:
		var target_pos = unit_base.movement_controller.get_current_target_position()
		if target_pos.distance_squared_to(gather_point) > 1.0:
			print("[ResourceGatherer] Unit is pathing away from resource, stopping gathering")
			stop_gathering()
			return
	
	# Check if we're close enough to the resource to gather
	var distance_to_resource = unit_base.global_transform.origin.distance_to(gather_point)
	if distance_to_resource > gather_radius:
		# If we're too far, move to the gather point
		if unit_base:
			# Make sure we're not still in the kick animation
			if unit_base.animation_controller and unit_base.animation_controller.current_animation == "kick":
				unit_base.animation_controller.play_animation("walking")
			unit_base.move_to(gather_point)
		return
	
	# If we were moving, stop
	if unit_base and unit_base.movement_controller.pathing:
		unit_base.movement_controller.pathing = false
		# Make unit face the resource center when gathering
		_face_resource_center()
	
	# Increment gather timer
	gather_timer += delta
	
	# Play gathering animation if available
	if unit_base and unit_base.animation_controller:
		# Play kick animation when gathering resources
		unit_base.animation_controller.play_animation("kick")
	
	# Check if a gather cycle is complete
	if gather_timer >= gather_cycle_time:
		gather_timer = 0.0
		
		# Calculate how much to gather in this cycle
		var to_gather = min(base_gather_rate, carrying_capacity - current_gathered_amount)
		
		# If we're full, return to drop-off
		if to_gather <= 0:
			print("[ResourceGatherer] Unit is full. Returning to drop-off with " + str(current_gathered_amount) + " " + current_resource_type)
			return_to_drop_off()
			return
		
		# Actually gather resources from the node
		var gathered = current_resource_node.gather_resources(to_gather)
		
		print("[ResourceGatherer] Gathered " + str(gathered) + " " + current_resource_type + ". Total: " + str(current_gathered_amount + gathered))
		
		# Update our carried amount
		current_gathered_amount += gathered
		
		# Sync the gathered amount over multiplayer
		if unit_base.is_multiplayer_authority():
			rpc("sync_gathered_amount", current_gathered_amount, current_resource_type)
		
		# If node is depleted or we're full, return to drop-off
		if gathered == 0 or current_gathered_amount >= carrying_capacity:
			return_to_drop_off()

# Start gathering from a resource node
func start_gathering(resource_node: ResourceNode) -> bool:
	# Only allow the server or unit owner to start gathering
	if unit_base.multiplayer.has_multiplayer_peer() and not unit_base.is_multiplayer_authority():
		print("[ResourceGatherer] Client sending request to server to start gathering")
		unit_base.rpc_id(1, "server_start_gathering", resource_node.get_path())
		return true
	
	# Check if the node is valid
	if not is_instance_valid(resource_node):
		print("[ResourceGatherer] Invalid resource node")
		return false
	
	# Try to start gathering from the node
	if not resource_node.start_gathering(get_instance_id()):
		print("[ResourceGatherer] Unable to start gathering - resource might be full")
		return false
	
	# If we were already gathering from another node, stop that first
	if current_resource_node != null and current_resource_node != resource_node:
		stop_gathering()
	
	# Set our current node and type
	current_resource_node = resource_node
	current_resource_type = resource_node.resource_type
	
	print("[ResourceGatherer] Starting to gather " + current_resource_type + " from " + resource_node.name)
	
	# Get a gather point near the resource
	gather_point = resource_node.get_nearest_gather_point(unit_base.global_transform.origin)
	
	# Make unit face the resource center when gathering
	_face_resource_center()
	
	# Activate gathering
	gathering_active = true
	gather_timer = 0.0
	
	# If we're the server, sync this to clients
	if unit_base.multiplayer.has_multiplayer_peer() and unit_base.is_multiplayer_authority():
		rpc("sync_start_gathering", resource_node.get_path())
	
	# Move to the gather point
	if unit_base:
		unit_base.move_to(gather_point)
	
	return true

# Stop gathering resources
func stop_gathering() -> void:
	print("[ResourceGatherer] Stopping gathering")
	
	if current_resource_node != null:
		current_resource_node.stop_gathering(get_instance_id())
		
	# Reset state
	gathering_active = false
	current_resource_node = null
	gather_timer = 0.0
	
	# Stop gathering animation
	if unit_base and unit_base.animation_controller:
		# Ensure we're returning to idle/walking animation based on movement state
		if unit_base.movement_controller.pathing:
			unit_base.animation_controller.force_animation_change("walking")
		else:
			unit_base.animation_controller.force_animation_change("idle")
	
	# Sync state to clients if we're the server
	if unit_base.multiplayer.has_multiplayer_peer() and unit_base.is_multiplayer_authority():
		rpc("sync_stop_gathering")

# Return gathered resources to a drop-off point
func return_to_drop_off() -> void:
	if current_gathered_amount <= 0:
		# Nothing to return
		return
	
	print("[ResourceGatherer] Returning to drop-off with " + str(current_gathered_amount) + " " + current_resource_type)
	
	# Temporarily stop gathering
	gathering_active = false
	
	# Stop the kick animation before moving
	if unit_base and unit_base.animation_controller:
		unit_base.animation_controller.force_animation_change("walking")
	
	# Find the nearest drop-off point
	var drop_off_point = find_nearest_drop_off()
	
	# If no drop-off found, can't return resources
	if drop_off_point == null:
		print("[ResourceGatherer] ERROR: No drop-off point found!")
		# Resume gathering
		gathering_active = true
		return
	
	print("[ResourceGatherer] Found drop-off point: " + drop_off_point.name)
	
	# Get the drop-off position
	var drop_off_position = drop_off_point.global_transform.origin
	
	# Move to the drop-off point
	if unit_base:
		unit_base.move_to(drop_off_position)
		
		# Wait until we reach the drop-off point
		# In a real implementation, you'd use signals or state machines
		# For simplicity, we'll use a coroutine here
		await get_tree().create_timer(0.1).timeout
		
		while unit_base.movement_controller.pathing:
			await get_tree().create_timer(0.1).timeout
	
	# Once at drop-off, deposit resources
	deposit_resources()
	
	# Return to gathering if we still have a valid node
	if current_resource_node != null and is_instance_valid(current_resource_node):
		# Resume gathering
		gathering_active = true
		
		# Move back to the resource
		if unit_base:
			unit_base.move_to(gather_point)

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
		var distance = unit_base.global_transform.origin.distance_to(building.global_transform.origin)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_camp = building
	
	return nearest_camp

# Deposit gathered resources at a drop-off point
func deposit_resources() -> void:
	if current_gathered_amount <= 0 or current_resource_type == "":
		return
	
	print("[ResourceGatherer] Depositing " + str(current_gathered_amount) + " " + current_resource_type)
	
	# Add resources to the player's stockpile
	if resource_system:
		resource_system.add_resources(player_id, current_resource_type, current_gathered_amount)
	
	# Reset carried amount
	current_gathered_amount = 0
	
	# Play deposit animation
	if unit_base and unit_base.animation_controller:
		unit_base.animation_controller.play_animation("deposit")
	
	# After a short delay, return to idle animation
	await get_tree().create_timer(1.0).timeout
	if unit_base and unit_base.animation_controller:
		unit_base.animation_controller.play_animation("idle")
	
	# Sync the gathered amount over multiplayer
	if unit_base.multiplayer.has_multiplayer_peer() and unit_base.is_multiplayer_authority():
		rpc("sync_gathered_amount", current_gathered_amount, current_resource_type)

# Get the current carried amount
func get_current_carried_amount() -> int:
	return current_gathered_amount

# Get the current resource type being gathered
func get_current_resource_type() -> String:
	return current_resource_type

# RPC functions for multiplayer
@rpc("authority", "reliable")
func sync_gathered_amount(amount: int, type: String) -> void:
	print("[ResourceGatherer] Network sync: Carrying " + str(amount) + " " + type)
	current_gathered_amount = amount
	current_resource_type = type

@rpc("authority", "reliable")
func sync_start_gathering(resource_node_path: NodePath) -> void:
	var node = get_node(resource_node_path)
	if node and node is ResourceNode:
		print("[ResourceGatherer] Network sync: Start gathering from " + node.name)
		# Initialize gathering state on the client
		current_resource_node = node
		current_resource_type = node.resource_type
		gather_point = node.get_nearest_gather_point(unit_base.global_transform.origin)
		gathering_active = true
		gather_timer = 0.0
		
		# Start the kick animation on clients too
		if unit_base and unit_base.animation_controller:
			unit_base.animation_controller.play_animation("kick")

@rpc("authority", "reliable")
func sync_stop_gathering() -> void:
	print("[ResourceGatherer] Network sync: Stop gathering")
	gathering_active = false
	current_resource_node = null
	gather_timer = 0.0

# Server RPC handler for starting gathering (called by client)
@rpc("any_peer", "call_local")
func server_start_gathering(resource_node_path: NodePath) -> void:
	# Only the server should handle this
	if not unit_base.is_multiplayer_authority():
		return
		
	print("[ResourceGatherer] Server received gathering request from client")
	
	# Check that the command is from the unit's owner
	var sender_id = str(unit_base.multiplayer.get_remote_sender_id())
	if sender_id != unit_base.player_owner:
		print("Gathering command rejected: Unit belongs to ", unit_base.player_owner, " but command sent by ", sender_id)
		return
	
	# Get the resource node and start gathering
	var node = get_node(resource_node_path)
	if node and node is ResourceNode:
		start_gathering(node)

# Stop gathering when the unit is commanded to move elsewhere
func _on_movement_commanded(target_position: Vector3) -> void:
	# Check if we're actively gathering and the target isn't the gather point
	if gathering_active and current_resource_node and target_position.distance_squared_to(gather_point) > 1.0:
		print("[ResourceGatherer] Unit was ordered to move away from resource. Stopping gathering.")
		stop_gathering()
		
		# Ensure animation state is updated immediately
		if unit_base and unit_base.animation_controller:
			unit_base.animation_controller.force_animation_change("walking")
			
		# Force the unit to continue with its commanded movement
		unit_base.movement_controller.ensure_pathing_active()

# Make the unit face the center of the resource it's gathering from
func _face_resource_center() -> void:
	if unit_base and current_resource_node:
		# Get direction vector from unit to resource center
		var direction = current_resource_node.global_transform.origin - unit_base.global_transform.origin
		direction.y = 0  # Ignore height difference for rotation
		
		# Only modify rotation if we have a valid direction
		if direction.length_squared() > 0.01:
			# Calculate the rotation to face that direction
			unit_base.rotation.y = atan2(-direction.x, -direction.z)
			print("[ResourceGatherer] Unit is now facing the resource center")
