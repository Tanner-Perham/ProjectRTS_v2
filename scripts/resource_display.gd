# resource_display.gd
# UI component for displaying player resources
extends Control

# References to UI elements
@onready var wood_label: Label = $HBoxContainer/WoodContainer/WoodAmount
@onready var minerals_label: Label = $HBoxContainer/MineralsContainer/MineralsAmount
@onready var stone_label: Label = $HBoxContainer/StoneContainer/StoneAmount

# Icon references (optional)
#@onready var wood_icon: TextureRect = $HBoxContainer/WoodContainer/WoodIcon
#@onready var minerals_icon: TextureRect = $HBoxContainer/MineralsContainer/MineralsIcon
#@onready var stone_icon: TextureRect = $HBoxContainer/StoneContainer/StoneIcon

# Player ID to display resources for
@export var player_id: int = 1

# Called when the node enters the scene tree
func _ready():
	# Find and initialize labels if they're not directly set
	if not wood_label:
		wood_label = find_child("WoodAmount")
	
	if not minerals_label:
		minerals_label = find_child("MineralsAmount")
		
	if not stone_label:
		stone_label = find_child("StoneAmount")
	
	# Find the resource system and connect to its signal
	var resource_system = get_node_or_null("/root/Main/ResourceSystem")
	
	# If we couldn't find it in the expected path, try other locations
	if not resource_system:
		resource_system = get_node_or_null("/root/ResourceSystem")
	
	# Try to find it in the resource_system group
	if not resource_system:
		var resources = get_tree().get_nodes_in_group("resource_system")
		if resources.size() > 0:
			resource_system = resources[0]
	
	if resource_system:
		print("[ResourceDisplay] Connected to ResourceSystem")
		# Connect to the resources_changed signal
		resource_system.connect("resources_changed", _on_resources_changed)
		
		# Initialize with current values
		update_resource_display(player_id, "Wood", resource_system.get_resource_amount(player_id, "Wood"))
		update_resource_display(player_id, "Minerals", resource_system.get_resource_amount(player_id, "Minerals"))
		update_resource_display(player_id, "Stone", resource_system.get_resource_amount(player_id, "Stone"))
	else:
		print("[ResourceDisplay] WARNING: Could not find ResourceSystem")
		# Initialize with zero values
		update_resource_display(player_id, "Wood", 100)
		update_resource_display(player_id, "Minerals", 0)
		update_resource_display(player_id, "Stone", 0)

# Update a specific resource display
func update_resource_display(p_id: int, resource_type: String, amount: int) -> void:
	# Only update if this is for our player
	if p_id != player_id:
		return
	
	# Update the appropriate label
	match resource_type:
		"Wood":
			if wood_label:
				wood_label.text = str(amount)
		"Minerals":
			if minerals_label:
				minerals_label.text = str(amount)
		"Stone":
			if stone_label:
				stone_label.text = str(amount)

# Set the player ID to display resources for
func set_player_id(p_id: int) -> void:
	player_id = p_id
	
	# Force refresh all displays
	var resource_system = get_node_or_null("/root/Main/ResourceSystem")
	
	# If we couldn't find it in the expected path, try other locations
	if not resource_system:
		resource_system = get_node_or_null("/root/ResourceSystem")
	
	# Try to find it in the resource_system group
	if not resource_system:
		var resources = get_tree().get_nodes_in_group("resource_system")
		if resources.size() > 0:
			resource_system = resources[0]
	
	if resource_system:
		update_resource_display(player_id, "Wood", resource_system.get_resource_amount(player_id, "Wood"))
		update_resource_display(player_id, "Minerals", resource_system.get_resource_amount(player_id, "Minerals"))
		update_resource_display(player_id, "Stone", resource_system.get_resource_amount(player_id, "Stone"))
	else:
		print("[ResourceDisplay] WARNING: Could not find ResourceSystem when setting player ID")

# Callback for when resources change
func _on_resources_changed(p_id: int, resource_type: String, amount: int) -> void:
	# Update the display for the changed resource
	update_resource_display(p_id, resource_type, amount)
