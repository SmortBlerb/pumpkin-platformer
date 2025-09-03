extends Node2D

# Grappling Physics
@export var rest_length = 2.0
@export var stiffness = 10.0
@export var damping = 2.0
@export var hook_distance = 250.0
var launched = false
var connected = false

# Hook
@onready var player = get_parent()
@onready var line = $"Line2D"
@onready var hook = $"Hook"
@onready var ray = $"Hook/RayCast2D"
var hit_position

# misc
@onready var timer = $"Timer"

const epsilon_vector = Vector2(0.01, 0.01)

func _ready():
	hook.hide()

func _process(_delta):
	ray.look_at(get_global_mouse_position())
	
	if Input.is_action_just_pressed("grapple"):
		launched = true
	if Input.is_action_just_released("grapple"):
		retract_grapple()
		
	if launched:
		handle_hook()
	if connected:
		handle_grapple()
	
	if !launched && !connected:
		hook.position = lerp(hook.position, position, 0.5)
		if hook.global_position >= global_position - epsilon_vector && hook.global_position <= global_position + epsilon_vector:
			hook.hide()
			line.hide()
		else:
			update_line()

func retract_grapple():
	hit_position = null
	launched = false
	connected = false
	
func handle_hook():
	if timer.is_stopped():
		timer.start()
	
	hook.show()
	hit_position = null
	if global_position.distance_to(get_global_mouse_position()) >= hook_distance:
		hook.position = lerp(hook.position, get_local_mouse_position().normalized() * hook_distance, 0.35)
	else:
		hook.position = lerp(hook.position, get_local_mouse_position(), 0.35)
	
	if ray.is_colliding():
		if ray.get_collider().get_cell_tile_data(ray.get_collider().get_coords_for_body_rid(ray.get_collider_rid())).get_custom_data_by_layer_id(0) == true:
			retract_grapple()
		else:
			hit_position = ray.get_collision_point()
			connected = true
			launched = false
	update_line()

func handle_grapple():
	var target_dir = player.global_position.direction_to(hit_position)
	var target_dist = player.global_position.distance_to(hit_position)
	
	var displacement = target_dist - rest_length
	var force = Vector2.ZERO
	
	if displacement > 0:
		var spring_force_magnitude = stiffness * displacement
		var spring_force = target_dir * spring_force_magnitude
		
		var vel_dot = player.velocity.dot(target_dir)
		var damp = -damping * vel_dot * target_dir
		
		force = spring_force + damp
		
	player.velocity += force
	update_line()
	
func update_line():
	line.show()
	hook.show()
	if hit_position:
		line.set_point_position(1, to_local(hit_position))
		hook.position = to_local(hit_position)
	else:
		line.set_point_position(1, hook.position)

func _on_timer_timeout() -> bool:
	if launched && !connected:
		retract_grapple()
	return true
