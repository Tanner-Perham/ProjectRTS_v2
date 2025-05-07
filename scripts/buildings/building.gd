# building.gd
# Base class for all buildings in the game
extends Node3D

# Network synchronization
@export var sync_properties := ["player_owner"]

# Building properties
@export var building_name: String = "Default Building"
@export var building_type: String = "Basic"
@export var building_description: String = "A basic building"
@export var building_icon: Texture2D
@export var multiplayer_synchronizer: MultiplayerSynchronizer

# Building ownership
@export var player_owner: String = "1":  # Default to player 1
	set(new_value):
		player_owner = new_value
		# When we set player_owner, we need to sync this to all clients
		if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
			rpc("update_player_owner", new_value)

# Called when the node enters the scene tree
func _ready():
	# Add to buildings group for easy finding
	add_to_group("buildings")
	
	# Setup multiplayer authority - server has authority over all buildings
	if multiplayer.has_multiplayer_peer():
		# Set the initial sync position for clients
		if multiplayer_synchronizer:
			# Server has authority over buildings
			multiplayer_synchronizer.set_multiplayer_authority(1)
			
			# Ensure we're properly connected to replication signals 
			if not multiplayer_synchronizer.is_connected("delta_synchronized", _on_delta_synchronized):
				multiplayer_synchronizer.delta_synchronized.connect(_on_delta_synchronized)
		
		# Initial owner should be synced to clients
		if multiplayer.is_server():
			rpc("update_player_owner", player_owner)

# Get the player ID of the building owner
func get_player_id() -> int:
	return int(player_owner)

# RPC functions for multiplayer
@rpc("authority", "call_remote")
func update_player_owner(new_owner: String) -> void:
	player_owner = new_owner
	print("[Building] Owner updated to player " + new_owner)

# Called when synchronizer sends a delta update
func _on_delta_synchronized() -> void:
	# This ensures we apply network updates immediately when they arrive
	pass  # Add any additional sync logic here if needed
