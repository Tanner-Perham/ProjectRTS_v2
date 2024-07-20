extends  RefCounted

# Handles unit formations
# -----------------------------------------------------------
# Returns a PackedVector2Array to be used as formation positions.

static func return_formation_positions(
	formation_destination: Vector2,
	formation_units: Array,
	formation_parameters = [ 3, 1.0, 0.0 ]
) -> PackedVector2Array:

	# CLASSIFY PARAMETERs
	var formation_size: int = (formation_units.size() as int)
	var formation_divisor: int = (formation_parameters[0] as int)
	var formation_spread: float = (formation_parameters[1] as float)

	# Current Units Average Position
	var current_units_position_2D: Array[Vector2] = []
	for unit:Node3D in formation_units:
		current_units_position_2D.append(
			Vector2(
				unit.global_position.x,
				unit.global_position.z
				)
			)
	var current_unit_pos_centre: Vector2 = get_average_2D_pos(current_units_position_2D)

	# Calculate angle for formation rotation
	var angle_to_position_rad: float = current_unit_pos_centre.angle_to_point(formation_destination)
	var angle_to_position_deg: float = snapped(remap(rad_to_deg(angle_to_position_rad), -180, 180, 0, 360), 1) - formation_parameters[2]
	var formation_angle_rad: float = deg_to_rad(angle_to_position_deg)

	# Create Formation
	var divisor: int = formation_divisor
	var horizontal_size: int = ceili((float(formation_size) / divisor))
	var vertical_size: int = divisor
	var spread: float = formation_spread

	var formation_positions: Array[Vector2] = []
	var Hi: int = 0
	var Vi: int = 0
	for unit in formation_units:
		var H_swapper: int = 1
		while Vi < vertical_size:
			while Hi < horizontal_size:
				H_swapper = -H_swapper
				var formation_position: Vector2 = Vector2(
					(spread * Hi) * H_swapper,
					spread * Vi
				)
				formation_positions.append(formation_destination + (formation_position).rotated(formation_angle_rad))
				Hi += 1;
			Vi += 1; Hi = 0;


	return (formation_positions as PackedVector2Array)

static func get_average_2D_pos(from_vec2s: Array[Vector2]) -> Vector2:
	var summed_vec2: Vector2 = Vector2()
	for vec2pos in from_vec2s: summed_vec2 += vec2pos
	return (summed_vec2 / from_vec2s.size() as Vector2).snapped(Vector2(0.01, 0.01))
