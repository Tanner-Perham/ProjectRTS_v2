extends Node2D

const ui_formation_node: PackedScene = preload("res://scenes/ui_formation_node.tscn")
var pooled_formation_nodes: Array[Sprite3D] = []

# MODULES
const MODULE_LIST = preload("res://scripts/module_list.gd")
const FORMATION = MODULE_LIST.SCRIPTS[MODULE_LIST.MODULES.FORMATION]

@onready var player_camera: Node3D = $camera_base
@onready var player_camera_visibleunits_Area3D: Area3D = $camera_base/visibleunits_area3D
@onready var ui_dragbox: NinePatchRect = $ui_dragbox
@onready var ui_formation_nodes_tree: Node3D = $ui_formation_nodes

# CONSTANTS
const MIN_DRAG_SQUARED: int = 250
enum INPUT_STATES{
	IDLE,
	DRAGBOX_SELECTION,
	GROUP_FORMATION_SET,
}

# VARIABLES
var mouse_left_click: bool = false
var drag_rectangle_area: Rect2
var available_units: Dictionary = {}
var selected_units: Dictionary = {}
var player_id: String = "Hello World"
var mouse_position: Vector2 = Vector2.ZERO
var mouse_pressed_pos: Vector2 = Vector2.ZERO
var mouse_right_click_position:Vector2 = Vector2.ZERO
var input_state:int = INPUT_STATES.IDLE :
	set(new_value): input_state = new_value
	get: return input_state


# FORMATION
var _formation_divisor: int = 3:
	set(new_value): _formation_divisor = clampi(new_value, 1, 10)
var _formation_spread: float = 1.0:
	set(new_value): _formation_spread = clampf(new_value, 0.5, 3.0)
var _formation_rotation: float = 90.0


func _ready() -> void:
	formation_nodes_pool_build()
	initialise_interface()
	

func unit_entered(unit: Node3D) -> void:
	"""
	Handler function for registering a unit to the available units dictionary.
	"""
	var unit_id: int = unit.get_instance_id()
	if available_units.has(unit_id):
		return
	available_units[unit_id] = unit.get_parent()
	print("unit_entered:", unit, "id:", unit_id, "unit_node:", unit.get_parent())

func unit_exited(unit: Node3D) -> void:
	var unit_id: int = unit.get_instance_id()
	if available_units.has(unit_id):
		available_units.erase(unit_id)
	print("unit_exited:", unit, "id:", unit_id, "unit_node:", unit.get_parent())

func debug_units_selected() -> void:
	print(available_units)

func initialise_interface() -> void:
	ui_dragbox.visible = false
	player_camera_visibleunits_Area3D.body_entered.connect(unit_entered)
	player_camera_visibleunits_Area3D.body_exited.connect(unit_exited)

func _input(event: InputEvent) -> void:
	mouse_position = get_global_mouse_position()

	match input_state:
		INPUT_STATES.IDLE:
			if event.is_action_pressed("mouse_rightclick"):
				if mouse_pressed_pos == Vector2.ZERO: mouse_pressed_pos = mouse_position
				if selected_units.size() > 1:
					if mouse_right_click_position == Vector2.ZERO:
						mouse_right_click_position = mouse_pressed_pos
					if (mouse_right_click_position).distance_squared_to(mouse_position) > 500:
						input_state = INPUT_STATES.GROUP_FORMATION_SET
						player_camera.camera_can_process = false

			if event.is_action_released("mouse_rightclick"):
				if !selected_units.is_empty():
					mouse_right_click_position = get_global_mouse_position()
					var camera_raycast_coordinates:Vector3 = player_camera.get_vector3_from_camera_raycast(mouse_right_click_position)
					# print(camera_raycast_coordinates)
					if camera_raycast_coordinates != Vector3.ZERO:
						var goal2D: Vector2 = Vector2(
							camera_raycast_coordinates.x,
							camera_raycast_coordinates.z
						)

						selection_move_as_formation(goal2D)

			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				mouse_pressed_pos = mouse_position
				if event.pressed:
					drag_rectangle_area.position = get_global_mouse_position()
					ui_dragbox.position = drag_rectangle_area.position
					mouse_left_click = true
				else:
					mouse_left_click = false
					cast_selection()
				
		INPUT_STATES.GROUP_FORMATION_SET:
			if Input.is_action_pressed("mouse_rightclick"):
				mouse_right_click_position = get_global_mouse_position()
				var camera_raycast_coordinates:Vector3 = player_camera.get_vector3_from_camera_raycast(mouse_right_click_position)
				

				# FORMATION SETUP
				if Input.is_action_pressed('shift'):
					if event.is_action_released('camera_zoom_in'):
						print('spread: %s', _formation_spread)
						_formation_spread += 0.1
					if event.is_action_released('camera_zoom_out'):
						print('spread: %s', _formation_spread)
						_formation_spread -= 0.1
				else:
					if event.is_action_released('camera_zoom_in'):
						print('divisor: %s', _formation_divisor)
						_formation_divisor += 1
					if event.is_action_released('camera_zoom_out'):
						print('divisor: %s', _formation_divisor)
						_formation_divisor -= 1
				if Input.is_action_just_released('control'):
					if _formation_rotation == 90.0:
						_formation_rotation = 0.0
					else:
						_formation_rotation = 90.0
				
				var goal2D: Vector2 = Vector2(
					camera_raycast_coordinates.x,
					camera_raycast_coordinates.z
				)

				var formation_positions: PackedVector2Array = FORMATION.return_formation_positions(
					goal2D,
					selected_units.values(),
					[_formation_divisor, _formation_spread, _formation_rotation]
				)

				ui_formation_nodes_tree.show()

				var i: int = 0
				var formation_pos_Y: float = (selected_units.values()[0] as Node3D).position.y
				for unit in selected_units.values():
					var formation_pos: Vector2 = formation_positions[i]
					pooled_formation_nodes[i].global_position = Vector3(
						formation_pos.x,
						formation_pos_Y,
						formation_pos.y
					)
					pooled_formation_nodes[i].show()
					i += 1

			if event.is_action_released("mouse_rightclick"):
				mouse_right_click_position = get_global_mouse_position()
				var camera_raycast_coordinates:Vector3 = player_camera.get_vector3_from_camera_raycast(mouse_right_click_position)
				# print(camera_raycast_coordinates)
				if camera_raycast_coordinates != Vector3.ZERO:
					var goal2D: Vector2 = Vector2(
						camera_raycast_coordinates.x,
						camera_raycast_coordinates.z
					)

					selection_move_as_formation(goal2D)
					input_state = INPUT_STATES.IDLE
					player_camera.camera_can_process = true

					ui_formation_nodes_tree.hide()
					for ui_node:Sprite3D in pooled_formation_nodes:
						ui_node.hide()

func cast_selection() -> void:
	for unit in available_units.values():
		# Check if the unit belongs to the player
		if unit.player_owner != player_id:
			continue
		if drag_rectangle_area.abs().has_point(player_camera.get_Vector2_from_Vector3(unit.transform.origin)):
			selected_units[unit.get_instance_id()] = unit
			unit.selected = true
		else:
			# Remove units no longer selected
			unit.selected = false
			selected_units.erase(unit.get_instance_id())
	print(selected_units)

func _process(delta: float) -> void:
	if mouse_left_click:
		drag_rectangle_area.size = get_global_mouse_position() - drag_rectangle_area.position
		update_ui_dragbox()
		if !ui_dragbox.visible and drag_rectangle_area.size.length_squared() > MIN_DRAG_SQUARED:
			ui_dragbox.visible = true
	else:
		ui_dragbox.visible = false

func update_ui_dragbox() -> void:
	ui_dragbox.size = abs(drag_rectangle_area.size)
	if drag_rectangle_area.size.x < 0:
		ui_dragbox.scale.x = -1
	else:
		ui_dragbox.scale.x = 1
	if drag_rectangle_area.size.y < 0:
		ui_dragbox.scale.y = -1
	else:
		ui_dragbox.scale.y = 1


func formation_nodes_pool_build() -> void:
	var i: int = 300
	for formation_node in range(0, i):
		var instanced_formation_node: Sprite3D = ui_formation_node.instantiate()
		ui_formation_nodes_tree.add_child(instanced_formation_node)
		instanced_formation_node.hide()
		pooled_formation_nodes.append(instanced_formation_node)

# Move selection to given destination as a formation
func selection_move_as_formation(where_to: Vector2) -> void:
	var selection_size: int = selected_units.size()
	if selection_size > 1:
		var formation_positions: PackedVector2Array = FORMATION.return_formation_positions(
			where_to,
			selected_units.values(),
			[_formation_divisor, _formation_spread, _formation_rotation]
			)
		var i: int = 0
		for unit in selected_units.values():
			var pos: Vector3 = Vector3(
				formation_positions[i].x,
				unit.position.y,
				formation_positions[i].y
			)
			unit.unit_path_new(pos)

			i += 1
