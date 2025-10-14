extends Camera2D

# Positions + Camera Shift
@onready var player = $"../Player"
@onready var viewport = get_window().content_scale_size

func _ready():
	global_position = player.global_position

func _process(_delta):
	position.x = lerp(position.x, player.position.x, 0.2)
	position.y = lerp(position.y, player.position.y - 100, 0.1)
