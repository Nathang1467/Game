extends Node
## Procedurally synthesised sound effects, so the prototype needs no audio files.

const RATE := 22050
var sounds := {}
var players: Array = []
var _next := 0
var _cooldown := {}

func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	sounds.bumper = _make([[620, 0.07, "square", 0.5], [310, 0.05, "square", 0.3]], 0.35)
	sounds.sling = _make([[0, 0.05, "noise", 1.0], [180, 0.05, "square", 0.5]], 0.3)
	sounds.flipper = _make([[90, 0.06, "sine", 1.0], [0, 0.03, "noise", 0.4]], 0.45)
	sounds.cash = _make([[523, 0.06, "square", 0.6], [659, 0.06, "square", 0.6], [784, 0.06, "square", 0.6], [1046, 0.14, "square", 0.6]], 0.3)
	sounds.big_cash = _make([[392, 0.07, "square", 0.6], [523, 0.07, "square", 0.6], [659, 0.07, "square", 0.6], [784, 0.07, "square", 0.6], [1046, 0.3, "tri", 0.8]], 0.35)
	sounds.drain = _slide(420, 80, 0.55, "saw", 0.3)
	sounds.tilt = _make([[110, 0.5, "saw", 0.8]], 0.4)
	sounds.coin = _make([[988, 0.05, "square", 0.6], [1319, 0.18, "square", 0.6]], 0.25)
	sounds.click = _make([[880, 0.03, "square", 0.5]], 0.2)
	sounds.hover = _make([[1200, 0.015, "sine", 0.4]], 0.12)
	sounds.lane = _make([[1175, 0.05, "tri", 0.8], [1568, 0.08, "tri", 0.6]], 0.25)
	sounds.target = _make([[240, 0.04, "square", 0.8], [0, 0.03, "noise", 0.5]], 0.35)
	sounds.ramp = _slide(200, 900, 0.3, "tri", 0.3)
	sounds.jackpot = _make([[523, 0.1, "square", 0.6], [659, 0.1, "square", 0.6], [784, 0.1, "square", 0.6], [1046, 0.1, "square", 0.6], [784, 0.1, "square", 0.6], [1046, 0.4, "square", 0.6]], 0.35)
	sounds.fever = _slide(600, 1200, 0.4, "square", 0.25)
	sounds.plunge = _slide(120, 60, 0.12, "noise", 0.5)
	sounds.scoop = _slide(300, 120, 0.2, "sine", 0.5)
	sounds.nudge = _make([[70, 0.08, "sine", 1.0], [0, 0.04, "noise", 0.5]], 0.5)
	sounds.shatter = _make([[0, 0.25, "noise", 1.0]], 0.35)
	sounds.secret = _make([[784, 0.08, "tri", 0.7], [988, 0.08, "tri", 0.7], [1175, 0.08, "tri", 0.7], [1568, 0.35, "tri", 0.9]], 0.35)
	sounds.lose = _slide(300, 60, 1.0, "square", 0.3)
	sounds.win = _make([[523, 0.12, "square", 0.6], [659, 0.12, "square", 0.6], [784, 0.12, "square", 0.6], [1046, 0.5, "tri", 0.8]], 0.35)
	sounds.buy = _make([[660, 0.04, "square", 0.6], [990, 0.1, "square", 0.6]], 0.25)
	sounds.card = _make([[0, 0.04, "noise", 0.6], [1400, 0.02, "sine", 0.3]], 0.2)
	sounds.tick = _make([[1600, 0.012, "square", 0.4]], 0.15)
	sounds.bee = _make([[1800, 0.02, "square", 0.3]], 0.1)

func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not sounds.has(name):
		return
	var now := Time.get_ticks_msec()
	if _cooldown.get(name, 0) > now:
		return
	_cooldown[name] = now + 25
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = sounds[name]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = vol_db
	p.play()

func _osc(kind: String, phase: float) -> float:
	match kind:
		"square": return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw": return fmod(phase, 1.0) * 2.0 - 1.0
		"tri": return 1.0 - 4.0 * absf(fmod(phase, 1.0) - 0.5)
		"noise": return randf() * 2.0 - 1.0
	return sin(phase * TAU)

func _make(notes: Array, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for n in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var kind: String = n[2]
		var amp: float = n[3] * vol
		var count := int(dur * RATE)
		var phase := 0.0
		for i in count:
			var t := float(i) / count
			var env := (1.0 - t) * minf(1.0, i / 60.0)
			phase += freq / RATE
			var v := _osc(kind, phase) * amp * env
			var s := int(clampf(v, -1.0, 1.0) * 32000)
			data.append(s & 0xff)
			data.append((s >> 8) & 0xff)
	return _wav(data)

func _slide(f0: float, f1: float, dur: float, kind: String, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(dur * RATE)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var env := (1.0 - t) * minf(1.0, i / 60.0)
		var v := _osc(kind, phase) * vol * env
		var s := int(clampf(v, -1.0, 1.0) * 32000)
		data.append(s & 0xff)
		data.append((s >> 8) & 0xff)
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
