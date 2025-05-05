extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $"CanvasLayer/MainMenu/MarginContainer/VBoxContainer/Address Entry"
@onready var port_entry = $"CanvasLayer/MainMenu/MarginContainer/VBoxContainer/Port Entry"
@onready var multiplayer_spawner = $MultiplayerSpawner

@onready var debug_info = $DebugInfo
@onready var network_status_info = $DebugInfo/PanelContainer/HBoxContainer/NetworkStatus

const Player = preload("res://scenes/Player.tscn")
const TestUnit = preload("res://scenes/test_unit.tscn")
var PORT = 9999
const MAX_CLIENTS = 4
var enet_peer = ENetMultiplayerPeer.new()

func _ready():
	PORT = int(port_entry.text)
	# Configure the MultiplayerSpawner to include both Player and TestUnit scenes
	if multiplayer_spawner:
		# Set spawnable scenes properly - directly assign to the property
		var scenes_to_spawn = PackedStringArray(["res://scenes/Player.tscn", "res://scenes/test_unit.tscn"])
		multiplayer_spawner._spawnable_scenes = scenes_to_spawn
		print("Multiplayer spawner configured with scenes: ", scenes_to_spawn)

func _on_host_button_pressed() -> void:
	main_menu.hide()
	
	enet_peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	
	add_player(multiplayer.get_unique_id())
	
	network_status_info.text = "Hosting Game!"


func _on_join_button_pressed() -> void:
	main_menu.hide()
	
	enet_peer.create_client(str(address_entry.text), PORT)
	multiplayer.multiplayer_peer = enet_peer
	
	network_status_info.text = "Joined game at: " + str(address_entry.text)

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	
# Function to spawn a test unit - this would be called on the server when needed
# and then automatically synchronized to clients
func spawn_test_unit(position: Vector3, owner_id: String) -> void:
	# Only the server should spawn units
	if not multiplayer.is_server():
		return
		
	var unit = TestUnit.instantiate()
	# Explicitly set the owner before adding to scene tree
	unit.player_owner = owner_id
	unit.global_position = position
	
	# Use add_child through the multiplayer API to ensure replication
	# The multiplayer spawner will detect this and replicate to clients
	add_child(unit, true)
	
	# Force an explicit update of player_owner to all clients
	# This ensures ownership is correctly set across network
	unit.rpc("update_player_owner", owner_id)
	
	print("Server spawned unit at position: ", position, " with owner: ", owner_id)
	
# Called by clients to request unit creation
@rpc("any_peer", "call_local")
func request_spawn_test_unit(position: Vector3) -> void:
	if not multiplayer.is_server():
		return
		
	# Get the client ID that sent the request
	var client_id = str(multiplayer.get_remote_sender_id())
	spawn_test_unit(position, client_id)
	print("Received spawn request from client: ", client_id)
