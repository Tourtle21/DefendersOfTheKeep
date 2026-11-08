extends SceneTree
# Every order of flipping wave tokens must end with the Start button available (after any upgrade choices).
class Host extends Node2D:
	var spawned := 0
	func spawn_enemies(_e) -> void:
		spawned += 1
	func wave_title() -> String:
		return "Day wave 1"
func perms(items: Array) -> Array:
	var out := []
	for i in items.size():
		out.append([items[i]])
		var rest := items.duplicate()
		rest.remove_at(i)
		for p in perms(rest):
			out.append([items[i]] + p)
	return out
func _initialize() -> void:
	await process_frame
	var host := Host.new()
	root.add_child(host)
	var stuck := []
	var checked := 0
	var seqs := []
	for p in perms([0, 1, 2, 3]):
		if p not in seqs: seqs.append(p)
	for seq in seqs:
		var up = load("res://ui/hud/upgrades/upgrades.tscn").instantiate()
		host.add_child(up)
		await process_frame
		up.create_tokens()
		var done := false
		var log := []
		for id in seq:
			if up.finished and !up.upgrading:
				break
			if up.finished:
				break                      # the screen blocks more flips once it is finished
			up.pick_token(id)
			log.append(id)
			# the player picks upgrades when asked
			var guard := 0
			while up.upgrading and up.upgrades > 0 and guard < 10:
				guard += 1
				var flipped: Array = up.enemies_flipped
				if flipped.is_empty():
					break
				up.upgrade("level", flipped[0].id)
		# left alone: the screen finishes the forced step itself
		var rescue := 0
		while !up.get_node("Control/Button").visible and rescue < 12:
			rescue += 1
			up._auto_resolve()
		if rescue > 0 and !up.get_node("Control/Button").visible:
			stuck.append("auto-resolve never reached Start after flips %s" % [log])
		checked += 1
		var start_ok: bool = up.get_node("Control/Button").visible
		var more_flips: bool = !up.finished and up.tokens_flipped < up.total_tokens
		if !start_ok and !more_flips:
			stuck.append("flips %s -> finished %s upgrading %s upgrades %s flipped %s drawing %s" % [log, up.finished, up.upgrading, up.upgrades, up.tokens_flipped, up.drawing])
		up.queue_free()
	print("orders checked: ", checked, " | stuck: ", stuck.size())
	for s in stuck.slice(0, 12):
		print("  STUCK ", s)
	quit()
