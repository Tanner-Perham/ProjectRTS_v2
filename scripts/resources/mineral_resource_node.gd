# mineral_resource_node.gd
# Implementation of Mineral resource nodes
class_name MineralResourceNode
extends ResourceNode

# Mineral-specific properties
@export var mineral_richness: String = "Medium" # Poor, Medium, Rich - affects resource amount
@export var mineral_type: String = "Iron" # Different mineral types for visual variety
@export var hardness: float = 1.0 # Affects gather rate (higher = slower gathering)
@export var bonus_resources_enabled: bool = true # Can drop bonus resources occasionally

# Mineral state tracking
var depletion_stages_mesh: Array[Mesh] = []
var current_depletion_stage: int = 0

func _ready():
	# Set resource type
	resource_type = "Minerals"
	
	# Adjust max resources based on mineral richness
	match mineral_richness:
		"Poor":
			max_resource_amount = 600
		"Medium":
			max_resource_amount = 1200
		"Rich":
			max_resource_amount = 2400
	
	# Initialize current amount
	current_resource_amount = max_resource_amount
	
	# Set gather rate modifier based on hardness
	gather_rate_modifier = 1.0 / hardness
	
	# Call parent ready
	super._ready()
	
	# Load depletion stage meshes if specified in the scene
	_load_depletion_meshes()

# Load different visual representations for depletion stages
func _load_depletion_meshes() -> void:
	# This would typically be set up in the editor
	# Here we're just creating a placeholder for the concept
	
	# Example (in practice, you'd assign these in the editor):
	# depletion_stages_mesh.append(preload("res://assets/minerals/iron_full.mesh"))
	# depletion_stages_mesh.append(preload("res://assets/minerals/iron_depleted_33.mesh"))
	# depletion_stages_mesh.append(preload("res://assets/minerals/iron_depleted_66.mesh"))
	# depletion_stages_mesh.append(preload("res://assets/minerals/iron_depleted_100.mesh"))
	pass

# Override to add mineral-specific behavior
func gather_resources(amount: int) -> int:
	var gathered_amount = super.gather_resources(amount)
	
	# Play mining effects
	if gathered_amount > 0:
		_play_mining_effects()
		
		# Check for bonus resources
		if bonus_resources_enabled and randf() < 0.05: # 5% chance
			_drop_bonus_resources()
	
	return gathered_amount

# Override visual state update for minerals
func update_visual_state() -> void:
	if depletion_stages_mesh.size() > 0:
		# Calculate which depletion stage we're in
		var depletion_ratio = 1.0 - (float(current_resource_amount) / float(max_resource_amount))
		var stage = min(floor(depletion_ratio * depletion_stages_mesh.size()), depletion_stages_mesh.size() - 1)
		
		# Only update mesh if the stage has changed
		if stage != current_depletion_stage and stage < depletion_stages_mesh.size():
			current_depletion_stage = stage
			mesh_instance.mesh = depletion_stages_mesh[stage]
	else:
		# Fall back to basic visual update if no stage meshes defined
		super.update_visual_state()

# Play mining effects (particles, sounds)
func _play_mining_effects() -> void:
	# Implement effects for mining
	# For example:
	# $MiningParticles.emitting = true
	# $MiningSound.play()
	pass

# Occasionally drops bonus resources when mining
func _drop_bonus_resources() -> void:
	# Implement bonus resource drop
	# This would typically spawn a small pickup item near the mineral node
	# For example:
	# var bonus = preload("res://scenes/resources/mineral_bonus.tscn").instantiate()
	# bonus.global_transform.origin = global_transform.origin + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	# get_parent().add_child(bonus)
	
	# Could also just directly give the player some bonus resource amount
	# Game.add_player_resources(get_tree().get_network_unique_id(), "Minerals", 50)
	pass