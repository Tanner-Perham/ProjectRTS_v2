extends Node3D

# NODES
@onready var selected_graphic:Sprite3D = $selected
@onready var unit_graphic:Node3D = $Test_Unit_01
@onready var map_RID:RID = get_world_3d().get_navigation_map()

@export var player_owner: String

var pathing:bool = false
var pathing_point:int = 0
var path_points_packed:PackedVector3Array

# OBJ ATTRIBUTES / DATA
var obj_data:Dictionary = {"SPEED": 8.0}

func _ready() -> void:
	await(get_tree().process_frame)
	global_position = NavigationServer3D.map_get_closest_point(map_RID, global_position)
	unit_graphic.position.y = NavigationServer3D.map_get_cell_height(map_RID) * 2
	unselected()

func selected() -> void:
	selected_graphic.visible = true

func unselected() -> void:
	selected_graphic.visible = false
	
func unit_path_new(goal_position: Vector3) -> void:
	var safe_goal:Vector3 = NavigationServer3D.map_get_closest_point(map_RID, goal_position)
	path_points_packed = NavigationServer3D.map_get_path(map_RID, global_position, safe_goal, true)
	pathing = true
	pathing_point = 0

func _physics_process(delta: float) -> void:
	if pathing:
		var path_next_point:Vector3 = path_points_packed[pathing_point] - global_position
		if path_next_point.length_squared() > 1.0:
			var velocity:Vector3 = (path_next_point.normalized() * delta) * obj_data["SPEED"]
			unit_rotate_to_direction(velocity)
			global_position += velocity
		else:
			if pathing_point < (path_points_packed.size() - 1):
				pathing_point += 1 # Grab next path point
				_physics_process(delta)
			else:
				pathing = false 

func unit_rotate_to_direction(direction:Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)
