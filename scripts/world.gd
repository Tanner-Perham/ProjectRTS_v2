extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $"CanvasLayer/MainMenu/MarginContainer/VBoxContainer/Address Entry"

const Player = preload("res://scenes/Player.tscn")
const PORT = 9999
const MAX_CLIENTS = 4
var enet_peer = ENetMultiplayerPeer.new()

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
