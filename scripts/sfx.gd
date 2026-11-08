class_name Sfx
extends Node
## Tiny synthesizer: all sounds are generated at startup, no audio files needed.

const RATE := 22050

var _laser_p: Array[AudioStreamPlayer] = []
var _laser_i := 0
var _streams := {}
var _engine: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _boom: AudioStreamPlayer
var _hit: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _lane: AudioStreamPlayer


func _ready() -> void:
	_streams["laser0"] = _make(0.16, func(t, _i): return _sweep(t, 1900.0, 500.0, 0.16) * exp(-t * 18.0) * 0.5)
	_streams["laser1"] = _make(0.2, func(t, _i): return _sq(_phase_sweep(t, 700.0, 180.0, 0.2)) * exp(-t * 14.0) * 0.22)
	var lp := [0.0]
	var boom_fn := func(t, _i):
		lp[0] = lerpf(lp[0], randf_range(-1, 1), 0.08 + 0.3 * exp(-t * 6.0))
		return lp[0] * exp(-t * 2.6) * 1.6 + sin(TAU * 48.0 * t) * exp(-t * 5.0) * 0.6
	_streams["boom"] = _make(1.6, boom_fn)
	_streams["hit"] = _make(0.25, func(t, _i): return randf_range(-1, 1) * exp(-t * 20.0) * 0.5 + sin(TAU * 120.0 * t) * exp(-t * 12.0) * 0.4)
	_streams["ui"] = _make(0.18, func(t, _i): return sin(TAU * (880.0 + 440.0 * floor(t * 12.0)) * t) * exp(-t * 14.0) * 0.25)
	var lp2 := [0.0]
	var lane_fn := func(t, _i):
		lp2[0] = lerpf(lp2[0], randf_range(-1, 1), 0.05 + t * 0.2)
		var e := sin(PI * clampf(t / 1.4, 0.0, 1.0))
		return (lp2[0] * 0.7 + sin(TAU * (200.0 + 500.0 * t) * t) * 0.25) * e * 0.6
	_streams["lane"] = _make(1.4, lane_fn)
	# engine hum loop: harmonics with integer cycles in 1 s so it loops cleanly
	var lp3 := [0.0]
	var engine_fn := func(t, _i):
		lp3[0] = lerpf(lp3[0], randf_range(-1, 1), 0.04)
		return (sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.0 * t) * 0.25 + sin(TAU * 167.0 * t) * 0.1 + lp3[0] * 0.8) * 0.35
	_streams["engine"] = _make(1.0, engine_fn, true)
	# ambient pad: slow evolving chord, 8 s loop
	var pad_fn := func(t, _i):
		var lfo := 0.5 + 0.5 * sin(TAU * t / 8.0)
		var lfo2 := 0.5 + 0.5 * sin(TAU * t / 4.0 + 1.0)
		var v := sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 164.75 * t) * 0.22 * lfo + sin(TAU * 220.0 * t) * 0.12
		v += sin(TAU * 277.25 * t) * 0.1 * lfo2 + sin(TAU * 329.5 * t) * 0.07 * (1.0 - lfo)
		v += sin(TAU * 55.0 * t) * 0.25
		return v * 0.35
	_streams["pad"] = _make(8.0, pad_fn, true)

	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_laser_p.append(p)
	_engine = _player("engine", -14.0)
	_engine.play()
	_pad = _player("pad", -16.0)
	_pad.play()
	_boom = _player("boom", -2.0)
	_hit = _player("hit", -6.0)
	_ui = _player("ui", -10.0)
	_lane = _player("lane", -6.0)


func _player(stream: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[stream]
	p.volume_db = db
	add_child(p)
	return p


func _make(seconds: float, gen: Callable, loop := false) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(gen.call(t, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


static func _sweep(t: float, f0: float, f1: float, dur: float) -> float:
	return sin(_phase_sweep(t, f0, f1, dur))


static func _phase_sweep(t: float, f0: float, f1: float, dur: float) -> float:
	# integral of linearly changing frequency
	var k := (f1 - f0) / dur
	return TAU * (f0 * t + 0.5 * k * t * t)


static func _sq(ph: float) -> float:
	return 1.0 if sin(ph) > 0.0 else -1.0


func laser(team: int, dist: float) -> void:
	var p := _laser_p[_laser_i]
	_laser_i = (_laser_i + 1) % _laser_p.size()
	p.stream = _streams["laser%d" % team]
	p.volume_db = -12.0 - clampf(dist / 80.0, 0.0, 24.0)
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


func boom(dist: float) -> void:
	_boom.volume_db = -2.0 - clampf(dist / 150.0, 0.0, 20.0)
	_boom.pitch_scale = randf_range(0.85, 1.1)
	_boom.play()


func hit() -> void:
	_hit.play()


func ui() -> void:
	_ui.play()


func lane(on: bool) -> void:
	_lane.pitch_scale = 1.0 if on else 0.7
	_lane.play()


func engine(ratio: float, active: bool) -> void:
	var target_db := -14.0 + clampf(ratio, 0.0, 3.0) * 3.0 if active else -40.0
	_engine.volume_db = lerpf(_engine.volume_db, target_db, 0.05)
	_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.7 + clampf(ratio, 0.0, 4.0) * 0.25, 0.05)
