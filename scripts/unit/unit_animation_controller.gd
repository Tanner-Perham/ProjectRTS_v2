extends Node

@onready var animation_player: AnimationPlayer
@onready var parent = get_parent()

var current_animation: String = "idle"

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
			
	if is_pathing and animation_player.current_animation != "walking":
		animation_player.play("walking")
		current_animation = "walking"
		if parent.is_multiplayer_authority():
			parent.rpc("sync_animation_state", "walking")
	elif not is_pathing and animation_player.current_animation != "idle":
		animation_player.play("idle")
		current_animation = "idle"
		if parent.is_multiplayer_authority():
			parent.rpc("sync_animation_state", "idle")

func play_animation(anim_name: String) -> void:
	current_animation = anim_name
	
	if not animation_player:
		animation_player = get_parent().find_child("AnimationPlayer2", true)
		if not animation_player:
			return
			
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
