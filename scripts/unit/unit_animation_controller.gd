extends Node

@onready var animation_player: AnimationPlayer
@onready var parent = get_parent()

var current_animation: String = "idle"
var animation_lock: bool = false  # Used to prevent rapid animation changes

func _ready() -> void:
	await(get_tree().process_frame)
	
	# Attempt to get animation player from parent structure
	animation_player = get_parent().find_child("AnimationPlayer2", true)
	
	if animation_player:
		animation_player.play("idle")
	else:
		# Try to get reference again after a short delay
		await get_tree().create_timer(0.2).timeout
		animation_player = get_parent().find_child("AnimationPlayer2", true)
		if animation_player:
			animation_player.play("idle")

func update_animation_state(is_pathing: bool) -> void:
	if not animation_player:
		animation_player = get_parent().find_child("AnimationPlayer2", true)
		if not animation_player:
			return
	
	# Only change animation if not locked		
	if is_pathing and animation_player.current_animation != "walking":
		play_animation("walking")
		
		if parent.is_multiplayer_authority():
			parent.rpc("sync_animation_state", "walking")
	elif not is_pathing and animation_player.current_animation != "idle":
		# Don't override resource gathering animations
		if animation_player.current_animation != "kick" and animation_player.current_animation != "gather" and animation_player.current_animation != "deposit":
			play_animation("idle")
			
			if parent.is_multiplayer_authority():
				parent.rpc("sync_animation_state", "idle")

func play_animation(anim_name: String) -> void:
	# Don't change if animation is the same
	if current_animation == anim_name:
		return
		
	current_animation = anim_name
	
	if not animation_player:
		animation_player = get_parent().find_child("AnimationPlayer2", true)
		if not animation_player:
			return
			
	# Priority system: walking/idle can be overridden by action animations,
	# but action animations should finish playing
	var current_is_action = is_action_animation(animation_player.current_animation)
	var new_is_action = is_action_animation(anim_name)
	
	# If we're changing from one action to another, or from a basic to action
	# animation, or if we're currently in a basic animation
	if (current_is_action and new_is_action) or (!current_is_action and new_is_action) or !current_is_action:
		animation_player.play(anim_name)
		
		# When starting a new action animation, lock briefly to prevent interruption
		if new_is_action:
			animation_lock = true
			get_tree().create_timer(0.3).timeout.connect(_unlock_animation)

# Helper function to check if an animation is an action that shouldn't be interrupted
func is_action_animation(anim_name: String) -> bool:
	return anim_name == "kick" or anim_name == "gather" or anim_name == "deposit"

# Unlock animations after a delay
func _unlock_animation() -> void:
	animation_lock = false

# Force animation change regardless of current state - for critical transitions
func force_animation_change(anim_name: String) -> void:
	current_animation = anim_name
	animation_lock = false
	
	if animation_player:
		animation_player.play(anim_name)
		
	if parent.is_multiplayer_authority():
		parent.rpc("sync_animation_state", anim_name)
