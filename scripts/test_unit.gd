extends Node3D

# NODES
@onready var selected_graphic:Sprite3D = $selected
@onready var unit_graphic:Node3D = $Test_Unit_01
@onready var map_RID:RID = get_world_3d().get_navigation_map()
@onready var animation_player:AnimationPlayer = $Test_Unit_01/mixamo_base/AnimationPlayer2

@export var player_owner: String

var pathing:bool = false
var pathing_point:int = 0
var path_points_packed:PackedVector3Array

var selected: bool = false:
	set(new_value):
		selected = new_value
		update_selected(selected)

# OBJ ATTRIBUTES / DATA
var obj_data:Dictionary = {"SPEED": 8.0}

func _ready() -> void:
	await(get_tree().process_frame)
	global_position = NavigationServer3D.map_get_closest_point(map_RID, global_position)
	unit_graphic.position.y = - NavigationServer3D.map_get_cell_height(map_RID) * 2
	selected = false

func update_selected(selected: bool) -> void:
	if selected:
		selected_graphic.show()
	else:
		selected_graphic.hide()

	
func unit_path_new(goal_position: Vector3) -> void:
	var safe_goal:Vector3 = NavigationServer3D.map_get_closest_point(map_RID, goal_position)
	path_points_packed = NavigationServer3D.map_get_path(map_RID, global_position, safe_goal, true)
	pathing = true
	pathing_point = 0

func _physics_process(delta: float) -> void:
	if pathing:
		if animation_player.current_animation != "walking":
			animation_player.play("walking")
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
				if animation_player.current_animation != "idle":
					animation_player.play("idle")
	else:
		if animation_player.current_animation != "idle":
			animation_player.play("idle")


func unit_rotate_to_direction(direction:Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)
