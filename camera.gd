extends Camera2D

# Positions + Camera Shift
@onready var player = $"../Player"
@onready var grapple = $"../Player/Grapple Controller"
@onready var viewport = get_window().content_scale_size
var new_position : Vector2
var camera_shift : float = 2.5

func _ready():
	global_position = player.global_position

func _process(_delta):
	if grapple.connected:
		position = lerp(position, (grapple.get_child(2).global_position + player.position) / 2, 0.08)
	else:
		position = lerp(position, Vector2(player.position.x + (player.velocity.x / camera_shift), player.position.y - 100), 0.05)
		offset.x = lerp(offset.x, (player.input * player.speed) / camera_shift, 0.1)
