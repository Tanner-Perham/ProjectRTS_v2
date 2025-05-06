extends Node3D

# Exportable fields for unit configuration
@export var unit_name: String = "Default Unit"
@export var unit_type: String = "Basic"
@export var unit_description: String = "A basic unit"
@export var unit_icon: Texture2D

# NODES
@onready var selected_graphic: Sprite3D = $selected
@onready var unit_graphic: Node3D = $Test_Unit_01
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var movement_controller = $MovementController
@onready var animation_controller = $AnimationController

# Signals
signal movement_commanded(target_position)

# OWNERSHIP
@export var player_owner: String:
	set(new_value):
		player_owner = new_value
		# When we set player_owner, we need to sync this to all clients
		if multiplayer_synchronizer and multiplayer_synchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
			rpc("update_player_owner", new_value)

# SYNC VARIABLES
var sync_position: Vector3 = Vector3.ZERO
var sync_rotation: Vector3 = Vector3.ZERO
var sync_animation: String = "idle"

# SELECTION
var selected: bool = false:
	set(new_value):
		# Network authority overrides local selection
		if multiplayer.has_multiplayer_peer():
			# For enemy units, only allow single selection
			var current_player_id = str(multiplayer.get_unique_id())
			
			# If this is someone else's unit, we need to handle selection differently
			if player_owner != current_player_id:
				# Count how many units are already selected by this client
				var existing_selection_count = 0
				var player_interface = get_tree().root.get_node_or_null("World/" + current_player_id + "/Player_Interface")
				if player_interface:
					existing_selection_count = player_interface.selected_units.size()
				
				# If we're adding to an existing selection (2+ units would be selected), don't allow it
				if new_value and existing_selection_count >= 1:
					print("Prevented multi-selecting enemy unit")
					return
		
		# Apply the selection change
		selected = new_value
		update_selected(selected)

# UNIT ATTRIBUTES
var obj_data: Dictionary = {"SPEED": 8.0}

func _ready() -> void:
	await(get_tree().process_frame)
	
	# Wait for movement controller to initialize
	await movement_controller._ready()
	
	if unit_graphic:
		unit_graphic.position.y = -NavigationServer3D.map_get_cell_height(movement_controller.map_RID) * 2
	selected = false
	
	# Setup multiplayer authority - server has authority over all units
	if multiplayer.has_multiplayer_peer():
		# Set the initial sync position for clients
		sync_position = global_position
		sync_rotation = global_rotation
		sync_animation = "idle"
		
		if multiplayer_synchronizer:
			# Server has authority over units
			multiplayer_synchronizer.set_multiplayer_authority(1)
			
			# Ensure we're properly connected to replication signals 
			if not multiplayer_synchronizer.is_connected("delta_synchronized", _on_delta_synchronized):
				multiplayer_synchronizer.delta_synchronized.connect(_on_delta_synchronized)
			
	# Force a position update to ensure clients see the unit in the right place
	if multiplayer.is_server():
		# Initial position should be synced to clients
		rpc("update_client_transform", global_position, global_rotation)
		rpc("update_player_owner", player_owner)
		rpc("sync_animation_state", "idle")

func _process(_delta: float) -> void:
	# Apply synced position/rotation for clients
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		if sync_position != Vector3.ZERO:
			global_position = sync_position
		if sync_rotation != Vector3.ZERO:
			global_rotation = sync_rotation
			
		# Ensure animations are playing on client
		if animation_controller and animation_controller.current_animation != sync_animation:
			animation_controller.play_animation(sync_animation)

func update_selected(selected: bool) -> void:
	if selected_graphic:
		if selected:
			selected_graphic.show()
		else:
			selected_graphic.hide()

# RPC FUNCTIONS
@rpc("authority", "call_remote")
func sync_animation_state(anim_name: String) -> void:
	sync_animation = anim_name
	if animation_controller:
		animation_controller.play_animation(anim_name)

@rpc("authority", "call_remote")
func update_player_owner(new_owner: String) -> void:
	player_owner = new_owner

@rpc("any_peer", "call_local")
func server_unit_path_new(goal_position: Vector3) -> void:
	# Only the server should calculate and update paths
	if not is_multiplayer_authority():
		return
		
	# Check that the command is from the unit's owner
	var sender_id = str(multiplayer.get_remote_sender_id())
	if sender_id != player_owner:
		print("Movement command rejected: Unit belongs to ", player_owner, " but command sent by ", sender_id)
		return
		
	movement_controller.unit_path_new(goal_position)

@rpc("authority", "call_remote")
func update_client_transform(pos: Vector3, rot: Vector3) -> void:
	if not is_multiplayer_authority():
		global_position = pos
		global_rotation = rot
		sync_position = pos
		sync_rotation = rot

@rpc("authority", "call_remote")
func update_client_pathing(is_pathing: bool) -> void:
	if not is_multiplayer_authority():
		movement_controller.pathing = is_pathing

# INTERFACE FUNCTIONS
func move_to(target_position: Vector3) -> void:
	movement_controller.unit_path_new(target_position)
	# Emit signal that a movement was commanded
	emit_signal("movement_commanded", target_position)

# Compatibility function for existing code
func unit_path_new(goal_position: Vector3) -> void:
	movement_controller.unit_path_new(goal_position)
	# Emit signal that a movement was commanded
	emit_signal("movement_commanded", goal_position)

# Called when synchronizer sends a delta update
func _on_delta_synchronized() -> void:
	# This ensures we apply network updates immediately when they arrive
	if not is_multiplayer_authority():
		if sync_position != Vector3.ZERO:
			global_position = sync_position
		if sync_rotation != Vector3.ZERO:
			global_rotation = sync_rotation
		
		# Ensure animations are playing on client
		if animation_controller and animation_controller.current_animation != sync_animation:
			animation_controller.play_animation(sync_animation)
