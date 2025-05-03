extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $"CanvasLayer/MainMenu/MarginContainer/VBoxContainer/Address Entry"
@onready var multiplayer_spawner = $MultiplayerSpawner

const Player = preload("res://scenes/Player.tscn")
const TestUnit = preload("res://scenes/test_unit.tscn")
const PORT = 9999
const MAX_CLIENTS = 4
var enet_peer = ENetMultiplayerPeer.new()

func _ready():
	# Make sure the test_unit scene is registered as spawnable
	if multiplayer_spawner:
		# Add the test_unit scene to spawnable scenes if it isn't already
		var spawnable_scenes = multiplayer_spawner._spawnable_scenes
		var test_unit_path = "uid://dxcsmnywfolfe"  # The unit UID from the file
		if not test_unit_path in spawnable_scenes:
			spawnable_scenes.append(test_unit_path)
			multiplayer_spawner._spawnable_scenes = spawnable_scenes

func _on_host_button_pressed() -> void:
	main_menu.hide()
	
	enet_peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	
	add_player(multiplayer.get_unique_id())


func _on_join_button_pressed() -> void:
	main_menu.hide()
	
	enet_peer.create_client(str(address_entry.text), PORT)
	multiplayer.multiplayer_peer = enet_peer

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
	unit.player_owner = owner_id
	unit.global_position = position
	add_child(unit)
	
# Called by clients to request unit creation
@rpc("any_peer", "call_local")
func request_spawn_test_unit(position: Vector3) -> void:
	if not multiplayer.is_server():
		return
		
	# Get the client ID that sent the request
	var client_id = str(multiplayer.get_remote_sender_id())
	spawn_test_unit(position, client_id)
