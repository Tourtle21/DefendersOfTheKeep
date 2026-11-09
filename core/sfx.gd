extends Node
## Autoload "Sfx": tiny synthesized sound effects (no audio files needed).
## Sfx.play("hit") from anywhere. Swap any name for a real sample later by putting
## an AudioStream in `streams`.

const RATE := 22050
var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _last := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	#                          f0     f1    secs  wave      noise vol
	streams["hit"] = _make(220.0, 90.0, 0.09, "sine", 0.45, 0.7)
	streams["big_hit"] = _make(140.0, 50.0, 0.18, "sine", 0.4, 0.9)
	streams["cast"] = _make(300.0, 900.0, 0.22, "sine", 0.05, 0.5)
	streams["coin"] = _make(880.0, 1320.0, 0.12, "square", 0.0, 0.25)
	streams["chest"] = _make(440.0, 880.0, 0.3, "sine", 0.0, 0.5)
	streams["hurt"] = _make(330.0, 110.0, 0.25, "saw", 0.15, 0.6)
	streams["boss_roar"] = _make(90.0, 55.0, 0.7, "saw", 0.25, 0.8)
	streams["wave_horn"] = _make(150.0, 110.0, 0.9, "saw", 0.08, 0.7)
	streams["ultimate"] = _make(120.0, 700.0, 0.5, "saw", 0.2, 0.7)
	streams["unlock"] = _make(330.0, 990.0, 0.6, "sine", 0.0, 0.5)
	streams["whoosh"] = _make(500.0, 200.0, 0.12, "sine", 0.7, 0.35)
	# the reward reveal: a deal, a building rumble, a snap, then a rising chime by rarity (Common ... Legendary)
	streams["deal"] = _make(700.0, 260.0, 0.13, "sine", 0.8, 0.4)
	streams["flip_rumble"] = _make(60.0, 140.0, 0.42, "saw", 0.55, 0.5)
	streams["flip_pop"] = _make(420.0, 1100.0, 0.12, "sine", 0.25, 0.65)
	streams["reveal_0"] = _arp([523.0, 659.0], 0.07, 0.28, "sine", 0.55)
	streams["reveal_1"] = _arp([523.0, 659.0, 784.0], 0.07, 0.34, "sine", 0.6)
	streams["reveal_2"] = _arp([523.0, 659.0, 784.0, 1047.0], 0.07, 0.5, "sine", 0.65, 0.4)
	streams["reveal_3"] = _arp([392.0, 523.0, 659.0, 784.0, 1047.0], 0.07, 0.7, "tri", 0.7, 0.6)
	streams["reveal_4"] = _arp([330.0, 392.0, 494.0, 659.0, 784.0, 988.0], 0.075, 0.9, "tri", 0.75, 0.8)
	streams["reveal_5"] = _arp([262.0, 330.0, 392.0, 523.0, 659.0, 784.0, 1047.0], 0.075, 1.1, "tri", 0.8, 1.0)
	streams["reveal_6"] = _arp([262.0, 330.0, 392.0, 523.0, 659.0, 784.0, 988.0, 1175.0, 1568.0], 0.085, 1.5, "tri", 0.85, 1.2)
	streams["thump"] = _make(90.0, 35.0, 0.45, "sine", 0.1, 0.95)

func _make(f0: float, f1: float, secs: float, wave: String, noise: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerp(f0, f1, t) / RATE
		var s := sin(phase)
		match wave:
			"square": s = 1.0 if s >= 0.0 else -1.0
			"saw": s = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		s = s * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var env: float = pow(1.0 - t, 1.6) * min(1.0, i / 150.0)
		data.encode_s16(i * 2, int(clamp(s * env * vol, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w

## Several notes, each starting `step` seconds after the one before and all ringing on: arpeggios and fanfares.
## `shimmer` adds a slightly detuned, higher copy of each note so the chord sparkles.
func _arp(freqs: Array, step: float, tone: float, wave: String, vol: float, shimmer := 0.0) -> AudioStreamWAV:
	var total := step * (freqs.size() - 1) + tone
	var n := int(RATE * total)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in freqs.size():
		var start := int(RATE * step * k)
		var len := int(RATE * tone)
		var ph := 0.0
		var ph2 := 0.0
		for i in len:
			if start + i >= n:
				break
			var t := float(i) / len
			ph += TAU * float(freqs[k]) / RATE
			ph2 += TAU * float(freqs[k]) * 2.01 / RATE
			var s := sin(ph)
			if wave == "tri":
				s = asin(sin(ph)) * 2.0 / PI                                   # a soft triangle: warmer than a sine
			s += shimmer * 0.35 * sin(ph2) * (1.0 - t)
			var env: float = pow(1.0 - t, 1.7) * minf(1.0, i / 100.0)
			buf[start + i] += s * env
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * vol * 0.45, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w

## A sound for the local screen only (menus, the reward reveal): never copied to co-op players.
func play_ui(name: String, pitch := 1.0) -> void:
	if !streams.has(name):
		return
	for p in _players:
		if !p.playing:
			p.stream = streams[name]
			p.volume_db = -6.0 + linear_to_db(max(0.001, float(Game.meta.get("sfx_vol", 1.0))))
			p.pitch_scale = pitch
			p.play()
			return

func play(name: String, pitch_jitter := 0.08, pitch := 1.0) -> void:
	if !streams.has(name):
		return
	if Rep.hosting():
		Rep.event("sfx", [name, pitch_jitter, pitch])
	var now := Time.get_ticks_msec()
	if now - _last.get(name, -1000) < 45:      # do not stack identical sounds
		return
	_last[name] = now
	for p in _players:
		if !p.playing:
			p.stream = streams[name]
			p.volume_db = -8.0 + linear_to_db(max(0.001, float(Game.meta.get("sfx_vol", 1.0))))
			p.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return
