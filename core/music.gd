extends Node
## Autoload "Music": synthesized background loops, no audio files. The theme follows the
## most recently unlocked sector; a boss fight swaps in the boss theme. Tracks are built
## the first time they are needed and cached. Replace any theme with a real AudioStream
## by putting it in `tracks[name]`.

const RATE := 22050
const SECTOR_THEME := {"s": "grass", "se": "desert", "ne": "tundra", "n": "volcano", "nw": "swamp", "sw": "crystal"}

# bpm, root note (Hz), scale (semitones), chord roots (scale degrees), arp wave, drums, mood volume
const THEMES := {
	"grass":   {"bpm": 96,  "root": 130.81, "scale": [0, 2, 4, 7, 9],           "chords": [0, 3, 4, 2], "arp": "sine",     "drums": false, "vol": 0.9},
	"desert":  {"bpm": 104, "root": 146.83, "scale": [0, 1, 4, 5, 7, 8, 11],    "chords": [0, 1, 0, 3], "arp": "triangle", "drums": true,  "vol": 0.9},
	"tundra":  {"bpm": 78,  "root": 110.0,  "scale": [0, 2, 3, 7, 8],           "chords": [0, 2, 3, 1], "arp": "bell",     "drums": false, "vol": 0.85},
	"volcano": {"bpm": 120, "root": 82.41,  "scale": [0, 3, 5, 6, 7, 10],       "chords": [0, 0, 2, 1], "arp": "saw",      "drums": true,  "vol": 0.8},
	"swamp":   {"bpm": 84,  "root": 92.5,   "scale": [0, 1, 3, 5, 6, 8],        "chords": [0, 4, 2, 4], "arp": "triangle", "drums": false, "vol": 0.9},
	"crystal": {"bpm": 100, "root": 196.0,  "scale": [0, 2, 4, 6, 7, 9, 11],    "chords": [0, 4, 1, 3], "arp": "bell",     "drums": false, "vol": 0.85},
	"boss":    {"bpm": 136, "root": 73.42,  "scale": [0, 1, 3, 5, 6, 8],        "chords": [0, 1, 0, 4], "arp": "saw",      "drums": true,  "vol": 0.85},
}

var tracks := {}
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current := ""
var _use_a := true
var _boss_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.volume_db = -60.0
		add_child(p)
	Game.run_started.connect(func():
		_boss_active = false
		_update())
	Game.sector_unlocked.connect(func(_id): _update())
	Game.boss_fight.connect(func(active):
		_boss_active = active
		_update())
	Game.run_ended.connect(func(_info): _fade_out())
	_update()
	_prebuild.call_deferred()

## The first themes are built while the start menu is up (one every couple of seconds), so building them never stalls the game
## or the menu screens. Any other theme is built the first time it is needed (~0.4 s).
func _prebuild() -> void:
	for theme_name in ["grass", "desert", "boss"]:
		await get_tree().create_timer(2.5).timeout
		if !tracks.has(theme_name):
			tracks[theme_name] = _build(THEMES[theme_name], theme_name)

func current_theme() -> String:
	if _boss_active:
		return "boss"
	return SECTOR_THEME[Game.sectors_unlocked.back()]

func _update() -> void:
	if !Game._menu_done:
		return                                  # the start menu is silent: the music begins when you press Play
	var want := current_theme()
	if want == _current:
		return
	_current = want
	if !tracks.has(want):
		tracks[want] = _build(THEMES[want], want)
	var incoming := _a if _use_a else _b
	var outgoing := _b if _use_a else _a
	_use_a = !_use_a
	incoming.stream = tracks[want]
	incoming.volume_db = -50.0
	incoming.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "volume_db", _target_db(), 1.6)
	tw.tween_property(outgoing, "volume_db", -60.0, 1.6)
	tw.chain().tween_callback(outgoing.stop)

func _target_db() -> float:
	return -16.0 + linear_to_db(max(0.001, float(Game.meta.get("music_vol", 1.0))))

## Called by the pause menu when the music slider moves.
func apply_volume() -> void:
	var active := _b if _use_a else _a        # the one fading in / playing
	if active.playing:
		active.volume_db = _target_db()

func _fade_out() -> void:
	_current = ""
	for p in [_a, _b]:
		create_tween().tween_property(p, "volume_db", -60.0, 2.0)

# ---------- synthesis ----------

static func _note(root: float, scale: Array, degree: int) -> float:
	var oct: int = int(floor(float(degree) / scale.size()))
	var idx: int = posmod(degree, scale.size())
	return root * pow(2.0, (scale[idx] + 12.0 * oct) / 12.0)

static func _wave(kind: String, phase: float) -> float:
	var ph: float = fposmod(phase, 1.0)
	match kind:
		"triangle": return 4.0 * absf(ph - 0.5) - 1.0
		"saw": return ph * 2.0 - 1.0
		"bell": return sin(TAU * ph) + 0.4 * sin(TAU * ph * 2.76) * 0.5
	return sin(TAU * ph)

## Four bars of 4/4 that loop cleanly: bass, pad chords, a seeded arpeggio and optional drums.
static func _build(theme: Dictionary, theme_name: String) -> AudioStreamWAV:
	var beat_len: float = 60.0 / theme.bpm
	var beats := 16
	var n := int(RATE * beat_len * beats)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme_name)
	var pattern := []
	for i in 16:
		pattern.append(rng.randi_range(0, 6) if rng.randf() < 0.75 else -1)   # -1 = rest
	var scale: Array = theme.scale
	var root: float = theme.root
	for i in n:
		var t: float = float(i) / RATE
		var beat: float = t / beat_len
		var bar_beat: int = int(beat) % beats
		var chord_deg: int = theme.chords[(bar_beat / 4) % theme.chords.size()]
		var frac: float = beat - floor(beat)
		var s := 0.0
		# bass: root of the chord, one octave down, pulses each beat
		var bf: float = _note(root, scale, chord_deg) * 0.5
		s += _wave("triangle", bf * t) * 0.32 * pow(1.0 - frac, 1.2)
		# pad: root, third and fifth of the chord, soft
		var pad := 0.0
		for off in [0, 2, 4]:
			pad += sin(TAU * _note(root, scale, chord_deg + off) * t)
		s += pad * 0.05 * (0.8 + 0.2 * sin(TAU * t * 0.25))
		# arp: an eighth-note pluck pattern over the scale, an octave up
		var step := int(beat * 2.0) % 16
		var deg: int = pattern[step]
		if deg >= 0:
			var af: float = _note(root * 2.0, scale, deg + chord_deg)
			var local: float = fposmod(beat * 2.0, 1.0)
			s += _wave(theme.arp, af * t) * 0.16 * exp(-local * 4.5)
		# drums
		if theme.drums:
			var kb: float = fposmod(beat, 2.0)
			if kb < 0.18:
				s += sin(TAU * (45.0 + 80.0 * exp(-kb * 30.0)) * kb) * 0.5 * (1.0 - kb / 0.18)
			var hb: float = fposmod(beat + 0.5, 1.0)
			if hb < 0.05:
				s += (rng.randf() * 2.0 - 1.0) * 0.12 * (1.0 - hb / 0.05)
		# tiny fade at the very ends so the loop point never clicks
		var edge: float = min(1.0, min(i, n - 1 - i) / 300.0)
		data.encode_s16(i * 2, int(clamp(s * theme.vol * edge, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
