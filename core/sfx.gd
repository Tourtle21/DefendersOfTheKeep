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
	streams["ultimate"] = _make(120.0, 700.0, 0.5, "saw", 0.2, 0.7)
	streams["unlock"] = _make(330.0, 990.0, 0.6, "sine", 0.0, 0.5)
	streams["whoosh"] = _make(500.0, 200.0, 0.12, "sine", 0.7, 0.35)

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
