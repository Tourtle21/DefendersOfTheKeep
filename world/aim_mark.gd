extends Node2D
## A split-screen player's aimer (players 2 to 4): a ring with four ticks, in that player's colour.

var color := Color.WHITE

func _draw() -> void:
	draw_arc(Vector2.ZERO, 5.0, 0, TAU, 24, Color(0, 0, 0, 0.85), 2.2)
	draw_arc(Vector2.ZERO, 5.0, 0, TAU, 24, color, 1.2)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(d * 7.0, d * 10.0, color, 1.2)
