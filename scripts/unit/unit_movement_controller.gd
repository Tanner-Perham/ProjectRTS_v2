extends Node

@onready var parent = get_parent()
@onready var map_RID: RID

var pathing: bool = false:
	set(value):
		pathing = value
		# Update animation state when pathing changes
		parent.animation_controller.update_animation_state(pathing)

var pathing_point: int = 0
var path_points_packed: PackedVector3Array
var current_target_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	await(get_tree().process_frame)
	# Get the navigation map from the parent Node3D
	map_RID = parent.get_world_3d().get_navigation_map()
	parent.global_position = NavigationServer3D.map_get_closest_point(map_RID, parent.global_position)

func unit_path_new(goal_position: Vector3) -> void:
	# If we're not the server, send an RPC to the server
	if multiplayer.has_multiplayer_peer() and not parent.is_multiplayer_authority():
		parent.rpc_id(1, "server_unit_path_new", goal_position)
		return
	
	# Store current target position	
	current_target_position = goal_position
		
	var safe_goal: Vector3 = NavigationServer3D.map_get_closest_point(map_RID, goal_position)
	path_points_packed = NavigationServer3D.map_get_path(map_RID, parent.global_position, safe_goal, true)
	pathing = true
	pathing_point = 0

# Get the current target position the unit is moving to
func get_current_target_position() -> Vector3:
	return current_target_position

# Ensure pathing is active if there's a valid path
func ensure_pathing_active() -> void:
	if not pathing and not path_points_packed.is_empty():
		pathing = true

func _physics_process(delta: float) -> void:
	# Only process movement on the authority (server)
	if multiplayer.has_multiplayer_peer() and not parent.is_multiplayer_authority():
		return
		
	if pathing:
		var path_next_point: Vector3 = path_points_packed[pathing_point] - parent.global_position
		if path_next_point.length_squared() > 1.0:
			var velocity: Vector3 = (path_next_point.normalized() * delta) * parent.obj_data["SPEED"]
			unit_rotate_to_direction(velocity)
			parent.global_position += velocity
			
			# Update synced variables - these will be automatically replicated
			parent.sync_position = parent.global_position
			parent.sync_rotation = parent.global_rotation
			
			# Sync movement to clients
			parent.rpc("update_client_transform", parent.global_position, parent.global_rotation)
		else:
			if pathing_point < (path_points_packed.size() - 1):
				pathing_point += 1 # Grab next path point
				_physics_process(delta)
			else:
				pathing = false
				# Sync pathing state to clients
				parent.rpc("update_client_pathing", false)

func unit_rotate_to_direction(direction: Vector3) -> void:
	parent.rotation.y = atan2(-direction.x, -direction.z)
