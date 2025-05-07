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

@onready var game_interface: CanvasLayer = $GameInterface

# TESTING
@onready var spawn_unit_button: Button = $"GameInterface/PanelContainer/HBoxContainer/GridContainer/SpawnUnit"

# CONSTANTS
const MIN_DRAG_SQUARED: int = 128
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
	
	# Set player_id based on multiplayer client ID if in multiplayer
	if multiplayer.has_multiplayer_peer():
		player_id = str(multiplayer.get_unique_id())
		print("Player interface initialized with multiplayer ID: ", player_id)

func unit_entered(unit: Node3D) -> void:
	"""
	Handler function for registering a unit to the available units dictionary.
	"""
	# Skip if this is not an actual unit (like a resource node)
	if not "player_owner" in unit.get_parent():
		return
		
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
					
					# Check what we're clicking on
					var clicked_object = player_camera.get_object_from_camera_raycast(mouse_right_click_position)
					
					# If we clicked on a resource node, try to gather from it
					if clicked_object is ResourceNode:
						print("[Player_Interface] Right-clicked on resource node: " + clicked_object.name)
						command_units_to_gather(clicked_object)
					# Otherwise just move to the position
					elif camera_raycast_coordinates != Vector3.ZERO:
						var goal2D: Vector2 = Vector2(
							camera_raycast_coordinates.x,
							camera_raycast_coordinates.z
						)
						selection_move_as_formation(goal2D)

			if Input.is_action_just_pressed('mouse_leftclick'):
				mouse_pressed_pos = mouse_position
				drag_rectangle_area.position = mouse_pressed_pos
				ui_dragbox.position = drag_rectangle_area.position
				mouse_left_click = true
			if Input.is_action_just_released('mouse_leftclick'):
				mouse_left_click = false

				var shift: bool = Input.is_action_pressed('shift')

				if drag_rectangle_area.size.length_squared() > MIN_DRAG_SQUARED:
					dragbox_cast_selection(shift)
				else:
					single_cast_selection(mouse_pressed_pos, shift)

				print(selected_units)

				
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


func selection_add(unit: Node3D) -> void:
	# If we already have units selected, only allow adding units that belong to the player
	if not selected_units.is_empty() and unit.player_owner != player_id:
		print("Cannot add enemy units to multi-selection")
		return
		
	selected_units[unit.get_instance_id()] = unit
	unit.selected = true

func selection_select_array(unit_array: Array[Node3D]) -> void:
	selection_clear()
	for unit: Node3D in unit_array:
		selection_add(unit)

func selection_clear() -> void:
	for unit in selected_units.values():
		unit.selected = false
	selected_units.clear()

func single_cast_selection(mouse_2D_pos: Vector2, shift: bool) -> void:
	for unit in available_units.values():
		var unit_2D_pos: Vector2 = player_camera.camera.unproject_position( (unit as Node3D).transform.origin + Vector3(0, 0.85, 0))

		if (mouse_2D_pos.distance_to(unit_2D_pos)) < 10.5:
			# If using shift to multi-select, only allow selecting own units
			if shift:
				# If trying to multi-select an enemy unit, ignore
				if unit.player_owner != player_id and not selected_units.is_empty():
					return
					
				if selected_units.has(unit.get_instance_id()):
					selected_units.erase(unit.get_instance_id())
					unit.selected = false
				else:
					selection_add(unit)
				return
			else:
				selection_select_array([unit])
				return
	
	selection_clear()

func dragbox_cast_selection(shift: bool) -> void:
	var units_captured: Array[Node3D] = []
	for unit in available_units.values():
		# Check if the unit belongs to the player - ONLY include units owned by this player
		if unit.player_owner != player_id:
			continue
			
		if drag_rectangle_area.abs().has_point(player_camera.get_Vector2_from_Vector3(unit.transform.origin)):
			units_captured.append(unit)
			
	if units_captured:
		for unit in units_captured:
			if unit.player_owner != player_id:
				units_captured.erase(unit)

	print(units_captured)
	if units_captured:
		if shift:
			for unit in units_captured:
				selection_add(unit)
		else:
			selection_select_array(units_captured)
	else:
		selection_clear()
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
func selection_move_as_formation(goal2D: Vector2) -> void:
	var selection_size: int = selected_units.size()
	
	if selection_size > 1:
		# FORMATION SETUP
		var formation_positions: PackedVector2Array = FORMATION.return_formation_positions(
			goal2D,
			selected_units.values(),
			[_formation_divisor, _formation_spread, _formation_rotation]
		)
		
		var i: int = 0
		for unit in selected_units.values():
			var formation_pos: Vector2 = formation_positions[i]
			var target3D: Vector3 = Vector3(
				formation_pos.x,
				unit.position.y,
				formation_pos.y
			)
			
			# Only send commands to units you own in multiplayer
			if unit.player_owner == player_id:
				unit.unit_path_new(target3D)
			
			i += 1
	else:
		# Single unit movement
		var unit: Node3D = selected_units.values()[0]
		
		# Only send commands to units you own in multiplayer
		if unit.player_owner == player_id:
			unit.unit_path_new(Vector3(goal2D.x, unit.position.y, goal2D.y))

# TESTING
func _on_spawn_unit_pressed() -> void:
	# Get the camera's center position for spawning
	var camera_center = Vector2(get_viewport().get_visible_rect().size / 2)
	var spawn_position_3D = player_camera.get_vector3_from_camera_raycast(camera_center)
	
	# If raycast failed, use camera position instead
	if spawn_position_3D == Vector3.ZERO:
		spawn_position_3D = player_camera.global_position
		spawn_position_3D.y = 0  # Ensure unit spawns on the ground
	
	# Get the world node
	var world = get_tree().root.get_node_or_null("World")
	if world:
		# Use the world's RPC function to spawn a unit properly in multiplayer
		if multiplayer.is_server():
			# Server directly spawns the unit
			world.spawn_test_unit(spawn_position_3D, player_id)
		else:
			# Clients request the server to spawn a unit
			world.rpc_id(1, "request_spawn_test_unit", spawn_position_3D)
		
		print("Requested unit spawn at: ", spawn_position_3D)
	else:
		print("ERROR: World node not found. Cannot spawn unit.")

# Command selected units to gather from a resource node
func command_units_to_gather(resource_node: ResourceNode) -> void:
	print("[Player_Interface] Commanding units to gather from: " + resource_node.name)
	
	# Get all units with gatherers
	var gatherer_units = []
	var non_gatherer_units = []
	
	for unit in selected_units.values():
		var gatherer = unit.find_child("ResourceGatherer", true)
		if gatherer:
			gatherer_units.append(unit)
		else:
			non_gatherer_units.append(unit)
	
	print("[Player_Interface] Found " + str(gatherer_units.size()) + " units that can gather resources")
	
	# Create a list of nearby resources of the same type (including the primary one)
	var all_resources = get_tree().get_nodes_in_group("resources")
	var available_resources = []
	
	# Add the primary resource first
	available_resources.append({
		"node": resource_node,
		"available_points": resource_node.get_available_gather_points()
	})
	
	# Find all alternative resources of the same type
	for res in all_resources:
		if res != resource_node and res is ResourceNode and res.is_same_type_as(resource_node):
			var points = res.get_available_gather_points()
			if points > 0:  # Only include resources that have available points
				available_resources.append({
					"node": res, 
					"available_points": points
				})
	
	print("[Player_Interface] Found " + str(available_resources.size()) + " resources of type " + resource_node.resource_type)
	
	# Sort resources by distance to the first unit (as a reference point)
	if gatherer_units.size() > 0 and available_resources.size() > 1:
		var reference_position = gatherer_units[0].global_transform.origin
		available_resources.sort_custom(func(a, b):
			var dist_a = a.node.global_transform.origin.distance_to(reference_position)
			var dist_b = b.node.global_transform.origin.distance_to(reference_position)
			return dist_a < dist_b
		)
	
	# Distribute units among available resources
	var total_points = 0
	for res_data in available_resources:
		total_points += res_data.available_points
	
	print("[Player_Interface] Total available gathering points: " + str(total_points))
	
	# If not enough points for all units, some will just move to resources
	var assigned_units = 0
	
	# First pass: assign units to resources with available points
	for res_data in available_resources:
		var resource = res_data.node
		var points = res_data.available_points
		
		# Skip if this resource has no points or we've assigned all units
		if points <= 0 or assigned_units >= gatherer_units.size():
			continue
		
		# Determine how many units to assign to this resource
		var units_to_assign = min(points, gatherer_units.size() - assigned_units)
		
		print("[Player_Interface] Assigning " + str(units_to_assign) + " units to " + resource.name + 
			" with " + str(points) + " points")
		
		# Assign units to this resource
		for i in range(units_to_assign):
			var unit_index = assigned_units + i
			var unit = gatherer_units[unit_index]
			var gatherer = unit.find_child("ResourceGatherer", true)
			
			# Try to reserve a gathering point and start gathering
			if gatherer.start_gathering(resource):
				print("[Player_Interface] Unit " + unit.name + " successfully started gathering from " + resource.name)
			else:
				print("[Player_Interface] Unit " + unit.name + " failed to start gathering, moving to resource instead")
				unit.move_to(resource.global_transform.origin)
		
		# Update assigned units count
		assigned_units += units_to_assign
		
		# Update available points for this resource
		res_data.available_points -= units_to_assign
	
	# Second pass: move any remaining units to the nearest resource
	if assigned_units < gatherer_units.size():
		print("[Player_Interface] Moving " + str(gatherer_units.size() - assigned_units) + " units to resources (no gathering points available)")
		
		for i in range(assigned_units, gatherer_units.size()):
			var unit = gatherer_units[i]
			
			# Find the nearest resource with the fewest units already assigned
			var best_resource = null
			var best_score = INF
			
			for res_data in available_resources:
				var resource = res_data.node
				var distance = unit.global_transform.origin.distance_to(resource.global_transform.origin)
				
				# Calculate a score (lower is better) based on distance and how many units are already going there
				var score = distance * (1.0 + float(gatherer_units.size() - res_data.available_points) / float(gatherer_units.size()))
				
				if score < best_score:
					best_score = score
					best_resource = resource
			
			if best_resource:
				print("[Player_Interface] Moving unit " + unit.name + " to resource " + best_resource.name)
				unit.move_to(best_resource.global_transform.origin)
			else:
				# Fallback to primary resource if something went wrong
				print("[Player_Interface] Fallback: Moving unit to primary resource")
				unit.move_to(resource_node.global_transform.origin)
	
	# Non-gatherer units just move to the primary resource
	for unit in non_gatherer_units:
		print("[Player_Interface] Unit " + unit.name + " can't gather, moving to resource")
		unit.move_to(resource_node.global_transform.origin)
