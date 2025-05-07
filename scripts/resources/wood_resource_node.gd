# wood_resource_node.gd
# Implementation of Wood resource nodes (Trees)
class_name WoodResourceNode
extends ResourceNode

# Tree-specific properties
@export var tree_size: String = "Medium" # Small, Medium, Large - affects resource amount
@export var tree_type: String = "Oak" # Different tree types for visual variety
@export var regrowth_enabled: bool = false # Whether tree stumps can regrow over time
@export var regrowth_time: float = 300.0 # Time in seconds for regrowth (if enabled)

# Tree state tracking
var is_chopped_down: bool = false
var regrowth_timer: float = 0.0

func _ready():
	# Set resource type
	resource_type = "Wood"
	
	# Adjust max resources based on tree size
	match tree_size:
		"Small":
			max_resource_amount = 500
		"Medium":
			max_resource_amount = 1000
		"Large":
			max_resource_amount = 2000
	
	# Initialize current amount
	current_resource_amount = max_resource_amount
	
	# Set gather rate modifier based on tree type
	match tree_type:
		"Oak":
			gather_rate_modifier = 1.0
		"Pine":
			gather_rate_modifier = 0.9 # Harder to chop
		"Birch":
			gather_rate_modifier = 1.2 # Easier to chop
	
	# Call parent ready
	super._ready()

# Override to add tree-specific behavior
func gather_resources(amount: int) -> int:
	var gathered_amount = super.gather_resources(amount)
	
	# Play tree chopping effects
	if gathered_amount > 0:
		_play_chop_effects()
	
	# Check if tree just got chopped down
	if not is_chopped_down and current_resource_amount <= max_resource_amount * 0.5:
		_chop_down_tree()
	
	return gathered_amount

# Handle visual and physical tree chopping
func _chop_down_tree() -> void:
	is_chopped_down = true
	
	# Play tree falling animation/sound
	# This would typically trigger an AnimationPlayer or similar
	# For example:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("fall_animation")
	
	# Could also emit particles, play sounds, etc.
	# $ChopParticles.emitting = true
	# $FallSound.play()

# Play chopping effects (particles, sounds)
func _play_chop_effects() -> void:
	# Implement effects for wood chopping
	# For example:
	# $ChopParticles.emitting = true
	# $ChopSound.play()
	pass

# Process function for handling regrowth if enabled
func _process(delta: float) -> void:
	# If regrowth is enabled and tree is depleted, handle regrowth timer
	if regrowth_enabled and current_resource_amount <= 0:
		regrowth_timer += delta
		
		if regrowth_timer >= regrowth_time:
			_regrow_tree()

# Regrow the tree (if enabled)
func _regrow_tree() -> void:
	current_resource_amount = max_resource_amount
	is_chopped_down = false
	regrowth_timer = 0.0
	
	# Reset visual state
	update_visual_state()
	
	# Play regrowth animation/effect if available
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("regrow_animation")

# Override the depletion behavior for trees
func _on_depleted() -> void:
	super._on_depleted()
	
	# If regrowth is not enabled, make sure collision is disabled for fully depleted trees
	if not regrowth_enabled and collision_shape != null:
		collision_shape.disabled = true
