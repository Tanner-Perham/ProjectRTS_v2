extends Node3D

# NODES
@onready var selected_graphic:Sprite3D = $selected
@onready var unit_graphic:Node3D = $Test_Unit_01
@onready var map_RID:RID = get_world_3d().get_navigation_map()
@onready var animation_player:AnimationPlayer = $Test_Unit_01/mixamo_base/AnimationPlayer2
@onready var multiplayer_synchronizer:MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var player_owner: String:
	set(new_value):
		player_owner = new_value
		# When we set player_owner, we need to sync this to all clients
		if multiplayer_synchronizer and multiplayer_synchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
			rpc("update_player_owner", new_value)

# The direct position variable
var sync_position: Vector3 = Vector3.ZERO
var sync_rotation: Vector3 = Vector3.ZERO
var sync_animation: String = "idle"

var pathing:bool = false:
	set(value):
		pathing = value
		# Update animation state when pathing changes
		update_animation_state()

var pathing_point:int = 0
var path_points_packed:PackedVector3Array

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

# OBJ ATTRIBUTES / DATA
var obj_data:Dictionary = {"SPEED": 8.0}

func _ready() -> void:
	await(get_tree().process_frame)
	global_position = NavigationServer3D.map_get_closest_point(map_RID, global_position)
	unit_graphic.position.y = - NavigationServer3D.map_get_cell_height(map_RID) * 2
	selected = false
	
	# Ensure animations work even if initial animation_player ref is null
	if animation_player:
		animation_player.play("idle")
	else:
		# Try to get reference again after a short delay
		await get_tree().create_timer(0.2).timeout
		animation_player = $Test_Unit_01/mixamo_base/AnimationPlayer2
		if animation_player:
			animation_player.play("idle")
	
	# Setup multiplayer authority - server has authority over all units
	if multiplayer.has_multiplayer_peer():
		# Set the initial sync position for clients
		sync_position = global_position
		sync_rotation = global_rotation
		sync_animation = "idle"
		
		if multiplayer_synchronizer:
			# Server has authority over units
			multiplayer_synchronizer.set_multiplayer_authority(1)
			
	# Force a position update to ensure clients see the unit in the right place
	if multiplayer.is_server():
		# Initial position should be synced to clients
		rpc("update_client_transform", global_position, global_rotation)
		rpc("update_player_owner", player_owner)
		rpc("sync_animation_state", "idle")

func update_animation_state() -> void:
	if not animation_player:
		animation_player = $Test_Unit_01/mixamo_base/AnimationPlayer2
		if not animation_player:
			return
			
	if pathing and animation_player.current_animation != "walking":
		animation_player.play("walking")
		if is_multiplayer_authority():
			rpc("sync_animation_state", "walking")
	elif not pathing and animation_player.current_animation != "idle":
		animation_player.play("idle")
		if is_multiplayer_authority():
			rpc("sync_animation_state", "idle")

@rpc("authority", "call_remote")
func sync_animation_state(anim_name: String) -> void:
	sync_animation = anim_name
	
	if not animation_player:
		animation_player = $Test_Unit_01/mixamo_base/AnimationPlayer2
		if not animation_player:
			return
			
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

@rpc("authority", "call_remote")
func update_player_owner(new_owner: String) -> void:
	player_owner = new_owner

func _process(_delta: float) -> void:
	# Apply synced position/rotation for clients
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		if sync_position != Vector3.ZERO:
			global_position = sync_position
		if sync_rotation != Vector3.ZERO:
			global_rotation = sync_rotation
			
		# Ensure animations are playing on client
		if animation_player and animation_player.current_animation != sync_animation:
			animation_player.play(sync_animation)

func update_selected(selected: bool) -> void:
	if selected:
		selected_graphic.show()
	else:
		selected_graphic.hide()

func unit_path_new(goal_position: Vector3) -> void:
	# If we're not the server, send an RPC to the server
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		rpc_id(1, "server_unit_path_new", goal_position)
		return
		
	var safe_goal:Vector3 = NavigationServer3D.map_get_closest_point(map_RID, goal_position)
	path_points_packed = NavigationServer3D.map_get_path(map_RID, global_position, safe_goal, true)
	pathing = true
	pathing_point = 0

# Server-side path calculation
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
		
	unit_path_new(goal_position)

func _physics_process(delta: float) -> void:
	# Only process movement on the authority (server)
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
		
	if pathing:
		var path_next_point:Vector3 = path_points_packed[pathing_point] - global_position
		if path_next_point.length_squared() > 1.0:
			var velocity:Vector3 = (path_next_point.normalized() * delta) * obj_data["SPEED"]
			unit_rotate_to_direction(velocity)
			global_position += velocity
			
			# Update synced variables - these will be automatically replicated
			sync_position = global_position
			sync_rotation = global_rotation
			
			# Sync movement to clients
			rpc("update_client_transform", global_position, global_rotation)
		else:
			if pathing_point < (path_points_packed.size() - 1):
				pathing_point += 1 # Grab next path point
				_physics_process(delta)
			else:
				pathing = false
				# Sync pathing state to clients
				rpc("update_client_pathing", false)

# Called on clients to update position and rotation
@rpc("authority", "call_remote")
func update_client_transform(pos: Vector3, rot: Vector3) -> void:
	if not is_multiplayer_authority():
		global_position = pos
		global_rotation = rot
		sync_position = pos
		sync_rotation = rot

# Called on clients to update pathing state
@rpc("authority", "call_remote")
func update_client_pathing(is_pathing: bool) -> void:
	if not is_multiplayer_authority():
		pathing = is_pathing
	
func unit_rotate_to_direction(direction:Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)
