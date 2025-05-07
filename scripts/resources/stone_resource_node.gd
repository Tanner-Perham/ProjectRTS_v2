# stone_resource_node.gd
# Implementation of Stone resource nodes
class_name StoneResourceNode
extends ResourceNode

# Stone-specific properties
@export var stone_size: String = "Medium" # Small, Medium, Large - affects resource amount
@export var stone_type: String = "Granite" # Different stone types for visual variety
@export var hardness: float = 1.5 # Stone is typically harder to gather than wood
@export var can_collapse: bool = true # Whether the node can collapse and damage nearby units

# Stone state tracking
var collapse_threshold: float = 0.2 # Percentage of resources remaining that triggers collapse
var has_collapsed: bool = false
var collapse_damage: int = 50 # Damage dealt to units if stone collapses

func _ready():
	# Set resource type
	resource_type = "Stone"
	
	# Adjust max resources based on stone size
	match stone_size:
		"Small":
			max_resource_amount = 800
			collapse_damage = 30
		"Medium":
			max_resource_amount = 1600
			collapse_damage = 50
		"Large":
			max_resource_amount = 3200
			collapse_damage = 80
	
	# Initialize current amount
	current_resource_amount = max_resource_amount
	
	# Set gather rate modifier based on hardness
	gather_rate_modifier = 1.0 / hardness
	
	# Adjust collapse threshold based on stone type
	match stone_type:
		"Granite":
			collapse_threshold = 0.2 # Stable
		"Limestone":
			collapse_threshold = 0.4 # Less stable
		"Sandstone":
			collapse_threshold = 0.6 # Quite unstable
	
	# Call parent ready
	super._ready()

# Override to add stone-specific behavior
func gather_resources(amount: int) -> int:
	var gathered_amount = super.gather_resources(amount)
	
	# Play mining effects
	if gathered_amount > 0:
		_play_quarry_effects()
		
		# Check for potential collapse
		if can_collapse and not has_collapsed:
			var remaining_ratio = float(current_resource_amount) / float(max_resource_amount)
			if remaining_ratio <= collapse_threshold:
				_trigger_collapse()
	
	return gathered_amount

# Play quarrying effects (particles, sounds)
func _play_quarry_effects() -> void:
	# Implement effects for stone quarrying
	# For example:
	# $QuarryParticles.emitting = true
	# $QuarrySound.play()
	pass

# Trigger a collapse of the stone node
func _trigger_collapse() -> void:
	has_collapsed = true
	
	# Play collapse animation/effects
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("collapse_animation")
	
	# Check for units in collapse radius
	var collapse_radius = 5.0  # Adjust as needed
	
	# In a real implementation, you'd use area detection or physics queries
	# For example:
	# var space_state = get_world_3d().direct_space_state
	# var query = PhysicsShapeQueryParameters3D.new()
	# query.set_shape($CollapseArea/CollisionShape.shape)
	# query.transform = $CollapseArea.global_transform
	# var results = space_state.intersect_shape(query)
	
	# For now, we'll emit a signal that other systems can connect to
	emit_signal("stone_collapsed", global_transform.origin, collapse_radius, collapse_damage)
	
	# Add some visual debris
	_spawn_collapse_debris()

# Spawn visual debris particles when collapsing
func _spawn_collapse_debris() -> void:
	# Implement debris spawning
	# For example:
	# var debris = preload("res://scenes/effects/stone_debris.tscn").instantiate()
	# debris.global_transform.origin = global_transform.origin
	# get_parent().add_child(debris)
	pass

# Signal emitted when stone collapses
signal stone_collapsed(position, radius, damage)