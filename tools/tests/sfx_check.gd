extends SceneTree
# Are the synthesized reveal sounds audible, unclipped and the right length?
func _initialize() -> void:
	await process_frame
	var sfx = root.get_node("Sfx")
	for name in ["deal", "flip_rumble", "flip_pop", "reveal_0", "reveal_1", "reveal_2", "reveal_3", "reveal_4", "reveal_5", "reveal_6", "thump"]:
		var w: AudioStreamWAV = sfx.streams[name]
		var d: PackedByteArray = w.data
		var n := d.size() / 2
		var peak := 0.0
		var sum := 0.0
		var clipped := 0
		for i in n:
			var v := absf(float(d.decode_s16(i * 2)) / 32768.0)
			peak = maxf(peak, v)
			sum += v * v
			if v > 0.97: clipped += 1
		var rms := sqrt(sum / n)
		var verdict := "ok"
		if peak < 0.15: verdict = "TOO QUIET"
		if clipped > 20: verdict = "CLIPPING"
		print("%-12s %.2f s  peak %.2f  rms %.3f  clipped samples %d  %s" % [name, float(n) / sfx.RATE, peak, rms, clipped, verdict])
	quit()
