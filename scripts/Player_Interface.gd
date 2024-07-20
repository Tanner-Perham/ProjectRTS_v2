extends Node2D

# MODULES
const MODULE_LIST = preload("res://scripts/module_list.gd")
const FORMATION = MODULE_LIST.SCRIPTS[MODULE_LIST.MODULES.FORMATION]

@onready var player_camera: Node3D = $camera_base
@onready var player_camera_visibleunits_Area3D: Area3D = $camera_base/visibleunits_area3D
@onready var ui_dragbox: NinePatchRect = $ui_dragbox

const MIN_DRAG_SQUARED: int = 250

var mouse_left_click: bool = false
var drag_rectangle_area: Rect2
var available_units: Dictionary = {}
var selected_units: Dictionary = {}
var player_id: String = "Hello World"

func _ready() -> void:
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_pos:Vector2 = get_global_mouse_position()
		var camera_raycast_coordinates:Vector3 = player_camera.get_vector3_from_camera_raycast(mouse_pos)
		print(camera_raycast_coordinates)
		if camera_raycast_coordinates != Vector3.ZERO:
			for unit in selected_units.values():
				unit.unit_path_new(camera_raycast_coordinates)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_rectangle_area.position = get_global_mouse_position()
			ui_dragbox.position = drag_rectangle_area.position
			mouse_left_click = true
		else:
			mouse_left_click = false
			cast_selection()

func cast_selection() -> void:
	for unit in available_units.values():
		# Check if the unit belongs to the player
		if unit.player_owner != player_id:
			continue
		if drag_rectangle_area.abs().has_point(player_camera.get_Vector2_from_Vector3(unit.transform.origin)):
			selected_units[unit.get_instance_id()] = unit
			unit.selected()
		else:
			# Remove units no longer selected
			unit.unselected()
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


