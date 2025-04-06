extends StaticBody2D

func activate():
	$Crystal.activate()

func deactive():
	$Crystal.deactive()

func return_crystal():
	$Crystal.being_held = false
	$Crystal.dropped = false
	$Crystal.position = Vector2(0, $Crystal.starting_position)
