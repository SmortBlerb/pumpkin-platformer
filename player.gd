extends CharacterBody2D

# Left-Right Movement Variables
var input : float
var direction_facing # based off sprite, use when player isnt moving
@export var speed : float = 300.0
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

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = (-3500) * -1.0

# Special
var special : bool = true
var long_jump_charge_amount : float = 1.0
var ball_state : bool = false;

# Animation
@onready var animation_player := $"AnimationPlayer"
@onready var sprite := $"Sprite2D"
var fall_animation_state : bool = false
var jump_animation_state : bool = false
var play_idle_animation : bool = true
var time : int = 0

# Grapple
@onready var grappler = $"Grapple Controller"
@export var grapple_top_speed : float = 1800.0

# Debug/Code States
enum STATE {
	idle, walk, jump, ball
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
	if (is_on_floor() && jumping) || state == STATE.ball:
		jumping = false
	if is_on_floor() && state == STATE.ball:
		special = true
	
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
			velocity.y = 0
		buffer = false
		
	# Jump squash and stretch
	if jumping:
		if time == 0:
			sprite.scale.y = 1.10
			sprite.scale.x = 0.9
		elif time <= 11:
			sprite.scale.y -= 0.01
			sprite.scale.x += 0.01
		time += 1
	else:
		sprite.scale.y = 1
		sprite.scale.x = 1
		time = 0
		
	# Handle falling
	if Input.is_action_just_released("up") && jumping && !buffer && velocity.y < 0:
		velocity.y = 0
	
	if !jumping && is_on_floor():
		state = STATE.walk
	
	# Condensed movement into one function
	if !(state == STATE.ball):
		movement()
	else:
		ball_movement()
	
	# Sprite flipping
	if input < 0:
		sprite.flip_h = true
	if input > 0:
		sprite.flip_h = false
	
	# Top Speed Handling
	if abs(velocity.x) >= speed && state != STATE.ball:
		velocity.x = clampf(velocity.x, -speed, speed)
	else:
		velocity.x = clampf(velocity.x, -grapple_top_speed, grapple_top_speed)
	
	# Ball State Check
	if state == STATE.ball:
		ball_state = true
	else:
		ball_state = false

	# End of frame/proccess functions
	if is_zero_approx(velocity.x) && !jumping && state != STATE.ball:
		state = STATE.idle
	last_floor = is_on_floor()
	move_and_slide()
	animate()
	$"TextEdit".text = STATE.keys()[state]
	
func movement():
	# Input Variables
	input = Input.get_axis("left", "right")
	var is_inputting = true if (Input.is_action_pressed("left") or Input.is_action_pressed("right")) else false

	# Acceleration + decceleration
	if is_inputting && abs(velocity.x) <= speed && signf(input) == signf(velocity.x) && state != STATE.ball:
		velocity.x += (input * speed) / acceleration_time
	elif is_inputting && signf(input) != signf(velocity.x) && state != STATE.ball:
		velocity.x += ((input * speed) / acceleration_time) * reactivity_percent
	elif !is_inputting && !is_zero_approx(velocity.x) && state != STATE.ball:
		velocity.x += (velocity.x * -1) / decceleration_time
	elif !is_inputting && state != STATE.ball:
		velocity.x += (velocity.x * -1) / (decceleration_time * 10)

func ball_movement():
	if special:
		if Input.get_action_raw_strength("down") == 1:
			velocity = Vector2(velocity.x / 10, velocity.y / 10)
			velocity.y = 1000
			special = false
		if Input.get_action_raw_strength("left") == 1:
			velocity = Vector2(velocity.x / 10, velocity.y / 10)
			velocity.x = -600
			special = false
		if Input.get_action_raw_strength("right") == 1:
			velocity = Vector2(velocity.x / 10, velocity.y / 10)
			velocity.x = 600
			special = false

func jump():
	velocity.y = jump_velocity
	jumping = true
	state = STATE.jump
	
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

func ball():
	state = STATE.ball

func _on_idle_delay_timeout() -> void:
	play_idle_animation = true
	
func _on_coyote_time_timeout() -> void:
	coyote = false

func _on_jump_buffer_timeout() -> void:
	buffer = false
