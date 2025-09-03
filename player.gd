extends CharacterBody2D

# Left-Right Movement Variables
var input : float
var direction_facing # based off sprite, use when player isnt moving
@export var speed : float = 300.0
@export var top_speed : float = 900.0
@export var acceleration_time : float = 6
@export var decceleration_time : float = 4
@export var reactivity_percent : float = 4

# Gravity
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Jumping
var jumping : bool = false
var buffer : bool = false
var coyote : bool = false
var last_floor
@export var jump_height : float
@export var jump_time_to_peak : float
@export var jump_time_to_descent : float

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

# Slam
var special : bool = false

# Animation
@onready var animation_player = $"AnimationPlayer"
@onready var sprite = $"Sprite2D"
var fall_animation_state : bool = false
var jump_animation_state : bool = false
var play_idle_animation : bool = true

# Grapple
@onready var grappler = $"Grapple Controller"
@export var grapple_top_speed : float = 1800.0

# Debug/Code States
enum STATE {
	idle, walk, jump, long_jump, grappled, grapple_launch
}
var state = STATE.idle

func _physics_process(delta: float):
	# Get direction player is facing (may be used later
	if sprite.flip_h:
		direction_facing = -1
	else:
		direction_facing = 1
	
	# Gravity
	velocity.y += get_jump_gravity() * delta
	
	# Landing
	if is_on_floor() && jumping:
		jumping = false
	if is_on_floor() && !grappler.connected:
		special = false
	
	# Coyote Time
	if !is_on_floor() && last_floor && !jumping:
		coyote_time()
	
	# Handle Jump
	if Input.is_action_just_pressed("up"):
		if is_on_floor() || coyote && !jumping:
			jump()
		else:
			buffer_jump()
	
	# Jump Buffer
	if is_on_floor() && buffer:
		jump()
		if !Input.is_action_pressed("up") && jumping:
			velocity.y = velocity.y / 1.5
		buffer = false
		
	# Long Jump
	if Input.is_action_just_pressed("down") && is_on_floor() && !special && state == STATE.walk:
		long_jump()
		
	# Handle falling
	if Input.is_action_just_released("up") && jumping && !buffer:
		velocity.y = velocity.y / 1.5
	
	# Condensed movement into one function
	movement()
	
	# Sprite flipping
	if input < 0:
		sprite.flip_h = true
	if input > 0:
		sprite.flip_h = false
	
	# Top Speed Handling
	if abs(velocity.x) >= speed:
		velocity.x += 5 * input
	if abs(velocity.x) >= top_speed && !grappler.connected:
		velocity.x = lerp(velocity.x, top_speed * input, 0.025)
	elif abs(velocity.x) >= top_speed && grappler.connected:
		velocity.x = clampf(velocity.x, -grapple_top_speed, grapple_top_speed)
		velocity.y = clampf(velocity.y, -grapple_top_speed, grapple_top_speed)
	
	if Input.is_action_just_pressed("down") && !special && !is_on_floor():
		if grappler.connected:
			grapple_launch()
	elif grappler.connected:
		state = STATE.grappled
	
	# Spike Collision
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() is TileMapLayer:
			var tile_data = collision.get_collider().get_cell_tile_data(collision.get_collider().get_coords_for_body_rid(collision.get_collider_rid()))
			if tile_data.get_custom_data_by_layer_id(0) == true:
				$"..".get_tree().reload_current_scene()
			
	# End of frame/proccess functions
	if is_zero_approx(velocity.x) && !jumping:
		state = STATE.idle
	last_floor = is_on_floor()
	move_and_slide()
	animate()
	$"TextEdit".text = STATE.keys()[state]
	
func movement():
	# Input Variables
	input = Input.get_axis("left", "right")
	var is_inputting = true if (Input.is_action_pressed("left") or Input.is_action_pressed("right")) else false
	if !jumping:
		state = STATE.walk
	
	# Acceleration + decceleration
	if is_inputting && abs(velocity.x) <= speed && !grappler.connected:
		velocity.x += (input * speed) / acceleration_time
	elif is_inputting && signf(input) != signf(velocity.x) && !grappler.connected:
		velocity.x += ((input * speed) / acceleration_time) * reactivity_percent
	elif !is_inputting && !is_zero_approx(velocity.x) && !grappler.connected:
		velocity.x += (velocity.x * -1) / decceleration_time
	# Grappler specific acceleration + decceleration
	elif is_inputting && abs(velocity.x) <= speed && grappler.connected:
		velocity.x = lerp(velocity.x, input * speed, 0.1)
	elif !is_inputting && !is_zero_approx(velocity.x) && grappler.connected:
		velocity.x = lerp(velocity.x, 0.0, 0.035)

func jump():
	velocity.y = jump_velocity
	jumping = true
	state = STATE.jump

func long_jump():
	if is_zero_approx(velocity.x):
		return
	velocity.x += (jump_velocity * -input * 0.6)
	velocity.y = jump_velocity * 0.6
	jumping = true
	special = true
	state = STATE.long_jump
	
func grapple_launch():
	grappler.retract_grapple()
	velocity.x *= 1.75
	velocity.x = clampf(velocity.x, -top_speed * 3.5, top_speed * 3.5)
	velocity.y *= 1.75
	velocity.y = clampf(velocity.y, -top_speed * 3.5, top_speed * 3.5)
	state = STATE.grapple_launch
	
func get_jump_gravity() -> float:
	if velocity.y < 0.0:
		return jump_gravity
	else:
		return fall_gravity
	
func coyote_time():
	coyote = true
	$"Coyote Time".start()
	
func buffer_jump():
	buffer = true
	$"Jump Buffer".start()

func _on_coyote_time_timeout() -> void:
	coyote = false

func _on_jump_buffer_timeout() -> void:
	buffer = false

func animate():
	if is_zero_approx(velocity.x) && is_zero_approx(velocity.y) && play_idle_animation:
		fall_animation_state = false
		jump_animation_state = false
		play_idle_animation = false
		animation_player.play("Idle")
		$"Idle Delay".start(2.0 + randf_range(-0.5, 1.0))
	elif !is_zero_approx(velocity.x) && is_zero_approx(velocity.y):
		fall_animation_state = false
		jump_animation_state = false
		play_idle_animation = true
		animation_player.play("Walk")
	elif velocity.y < 0 && jump_animation_state == false:
		fall_animation_state = false
		jump_animation_state = true
		play_idle_animation = true
		animation_player.play("Jump")
	elif velocity.y > 0 && fall_animation_state == false:
		fall_animation_state = true
		jump_animation_state = false
		play_idle_animation = true
		animation_player.play("Fall")

func _on_idle_delay_timeout() -> void:
	play_idle_animation = true
