# resource_system.gd
# System that manages resources for all players
class_name ResourceSystem
extends Node

# Player resources structure:
# player_resources = {
#   player_id: {
#     "Wood": amount,
#     "Minerals": amount,
#     "Stone": amount
#   }
# }
var player_resources = {}

# Signal emitted when a player's resources change
signal resources_changed(player_id, resource_type, amount)

# Initialize resources for a player
func initialize_player_resources(player_id: int) -> void:
	player_resources[player_id] = {
		"Wood": 200,     # Starting wood
		"Minerals": 100, # Starting minerals
		"Stone": 50      # Starting stone
	}
	
	# Emit signals for initial resources
	for resource_type in player_resources[player_id]:
		emit_signal("resources_changed", player_id, resource_type, player_resources[player_id][resource_type])

# Add resources to a player's stockpile
func add_resources(player_id: int, resource_type: String, amount: int) -> void:
	# Check if player exists in the system
	if not player_resources.has(player_id):
		initialize_player_resources(player_id)
	
	# Check if resource type is valid
	if not player_resources[player_id].has(resource_type):
		push_error("Invalid resource type: " + resource_type)
		return
	
	# Add resources
	player_resources[player_id][resource_type] += amount
	
	# Emit signal
	emit_signal("resources_changed", player_id, resource_type, player_resources[player_id][resource_type])

# Remove resources from a player's stockpile
# Returns true if player had enough resources, false otherwise
func remove_resources(player_id: int, resource_type: String, amount: int) -> bool:
	# Check if player exists in the system
	if not player_resources.has(player_id):
		return false
	
	# Check if resource type is valid
	if not player_resources[player_id].has(resource_type):
		push_error("Invalid resource type: " + resource_type)
		return false
	
	# Check if player has enough resources
	if player_resources[player_id][resource_type] < amount:
		return false
	
	# Remove resources
	player_resources[player_id][resource_type] -= amount
	
	# Emit signal
	emit_signal("resources_changed", player_id, resource_type, player_resources[player_id][resource_type])
	
	return true

# Get the current amount of a specific resource for a player
func get_resource_amount(player_id: int, resource_type: String) -> int:
	# Check if player exists in the system
	if not player_resources.has(player_id):
		return 0
	
	# Check if resource type is valid
	if not player_resources[player_id].has(resource_type):
		push_error("Invalid resource type: " + resource_type)
		return 0
	
	return player_resources[player_id][resource_type]

# Check if a player has enough resources for a cost dictionary
# cost_dict = { "Wood": amount, "Minerals": amount, "Stone": amount }
func has_enough_resources(player_id: int, cost_dict: Dictionary) -> bool:
	# Check if player exists in the system
	if not player_resources.has(player_id):
		return false
	
	# Check each resource type in the cost dictionary
	for resource_type in cost_dict:
		if not player_resources[player_id].has(resource_type):
			push_error("Invalid resource type: " + resource_type)
			return false
		
		if player_resources[player_id][resource_type] < cost_dict[resource_type]:
			return false
	
	return true

# Deduct a cost dictionary from a player's resources
# Returns true if successful, false if player didn't have enough resources
func deduct_cost(player_id: int, cost_dict: Dictionary) -> bool:
	# First check if player has enough resources
	if not has_enough_resources(player_id, cost_dict):
		return false
	
	# Deduct each resource
	for resource_type in cost_dict:
		remove_resources(player_id, resource_type, cost_dict[resource_type])
	
	return true

# Reset a player's resources (e.g., for a new game)
func reset_player_resources(player_id: int) -> void:
	# Reset player resources to starting values
	player_resources[player_id] = {
		"Wood": 200,
		"Minerals": 100,
		"Stone": 50
	}
	
	# Emit signals for reset resources
	for resource_type in player_resources[player_id]:
		emit_signal("resources_changed", player_id, resource_type, player_resources[player_id][resource_type])

# Network functions for multiplayer synchronization
# These should be called by the server/host only

# RPC to synchronize all resource values for a player
@rpc("authority", "call_remote", "reliable")
func sync_player_resources(player_id: int, resources: Dictionary) -> void:
	player_resources[player_id] = resources.duplicate()
	
	# Emit signals for each resource type
	for resource_type in player_resources[player_id]:
		emit_signal("resources_changed", player_id, resource_type, player_resources[player_id][resource_type])

# Called by the host to synchronize resources to all clients
func broadcast_resources() -> void:
	# Only the host should do this
	if not multiplayer.is_server():
		return
	
	# Send resources for each player to all clients
	for player_id in player_resources:
		sync_player_resources.rpc(player_id, player_resources[player_id])

# Get costs for common game elements
func get_building_cost(building_type: String) -> Dictionary:
	match building_type:
		"MainBase":
			return {"Wood": 400, "Minerals": 200, "Stone": 100}
		"House":
			return {"Wood": 100, "Stone": 50}
		"MilitaryBuilding":
			return {"Wood": 200, "Minerals": 100, "Stone": 50}
		"ResourceCamp":
			return {"Wood": 150, "Stone": 25}
		_:
			push_error("Unknown building type: " + building_type)
			return {}

func get_unit_cost(unit_type: String) -> Dictionary:
	match unit_type:
		"Builder":
			return {"Wood": 50, "Minerals": 0, "Stone": 0}
		"MeleeUnit":
			return {"Wood": 30, "Minerals": 20, "Stone": 0}
		"RangedUnit":
			return {"Wood": 40, "Minerals": 30, "Stone": 0}
		"ScoutUnit":
			return {"Wood": 50, "Minerals": 10, "Stone": 0}
		"HeroUnit":
			return {"Wood": 100, "Minerals": 100, "Stone": 50}
		_:
			push_error("Unknown unit type: " + unit_type)
			return {}

func get_upgrade_cost(upgrade_type: String) -> Dictionary:
	match upgrade_type:
		"EconomicUpgrade":
			return {"Wood": 100, "Minerals": 150, "Stone": 50}
		"MilitaryUpgrade":
			return {"Wood": 200, "Minerals": 200, "Stone": 100}
		"PoisonArrows":
			return {"Wood": 150, "Minerals": 250, "Stone": 0}
		"FireArrows":
			return {"Wood": 200, "Minerals": 200, "Stone": 50}
		_:
			push_error("Unknown upgrade type: " + upgrade_type)
			return {}
