extends Area2D

@export var bounce_strength : float = -750.0

func _on_area_entered(area: Area2D) -> void:
	var body = area.get_parent()
	if body.ball_state:
		body.velocity = transform.y * bounce_strength * 1.5
		body.ball()
	else:
		body.velocity = transform.y * bounce_strength
