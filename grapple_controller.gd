extends Node2D

# Grappling Physics
@export var hook_distance = 250.0
@export var grapple_force = 1250.0	
var launched = false
var connected = false

# Hook
@onready var player = get_parent()
@onready var line = $"Line2D"
@onready var hook = $"Hook"
@onready var ray = $"Hook/RayCast2D"
var hit_position

# misc
var time = 0
var force = Vector2(0.0, 0.0)

const epsilon_vector = Vector2(0.01, 0.01)

func _ready():
	hook.hide()

func _process(_delta):
	ray.look_at(get_global_mouse_position())
	
	if Input.is_action_just_pressed("grapple"):
		launched = true
	if Input.is_action_just_released("grapple") && hit_position == null:
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
	launched = false
	connected = false
	hit_position = null
	
func handle_hook():
	hook.show()
	hit_position = null
	if global_position.distance_to(get_global_mouse_position()) >= hook_distance:
		hook.position = lerp(hook.position, get_local_mouse_position().normalized() * hook_distance, 0.35)
	else:
		hook.position = lerp(hook.position, get_local_mouse_position(), 0.35)
	
	if ray.is_colliding():
		hit_position = ray.get_collider().get_parent().position
		connected = true
		launched = false
	update_line()

func handle_grapple():
	if time == 0:
		force = (player.position.direction_to(hit_position)).normalized() * grapple_force
	
	player.grapple_launch()
	player.velocity = Vector2(0, 0)
	time += 1
	update_line()
	if time >= 12:
		player.grapple_launch()
		player.position = lerp(player.position, hit_position, 1/(force.length()/player.position.distance_to(hit_position)))
	if time >= 18:
		player.velocity += force
		player.grapple_launch()
		retract_grapple()
		time = 0
	
func update_line():
	line.show()
	hook.show()
	if hit_position:
		line.set_point_position(1, to_local(hit_position))
		hook.position = to_local(hit_position)
	else:
		line.set_point_position(1, hook.position)
