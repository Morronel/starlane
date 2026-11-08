class_name TouchControls
extends Control
## Multi-touch flight controls drawn in one Control:
## floating stick (left), fire + boost (right), throttle slider, roll pads,
## and one context button (enter lane / exit lane / dock).

var action_label := ""
var action_color := Color(0.3, 0.9, 1.0)

var _stick_touch := -1
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _fire_touch := -1
var _boost_touch := -1
var _throttle_touch := -1
var _roll_touches := {}   # index -> -1 / +1
var _action_flash := 0.0
var _last_fire_tap := -10000

signal map_tapped
signal settings_tapped
signal autopilot_tapped

var autopilot_on := false
var autopilot_ready := false
var missile_ammo := -1     # -1 = no secondary weapon
var _missile_flash := 0.0

const STICK_R := 95.0
const ACCENT := Color(0.55, 0.85, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fire_c() -> Vector2: return Vector2(size.x - 140, size.y - 140)
func _boost_c() -> Vector2: return Vector2(size.x - 300, size.y - 92)
func _roll_c(side: int) -> Vector2: return Vector2(110 + (side + 1) * 75, size.y - 330)
func _action_rect() -> Rect2: return Rect2(size.x - 330, size.y * 0.36, 250, 74)
func _throttle_rect() -> Rect2: return Rect2(size.x - 72, 110, 46, size.y - 390)
func _stick_home() -> Vector2: return Vector2(185, size.y - 165)
func _map_rect() -> Rect2: return Rect2(size.x * 0.5 - 214, 12, 120, 50)
func _auto_rect() -> Rect2: return Rect2(size.x * 0.5 - 82, 12, 164, 50)
func _gear_rect() -> Rect2: return Rect2(size.x * 0.5 + 94, 12, 120, 50)
func _missile_c() -> Vector2: return Vector2(size.x - 305, size.y - 236)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var idx: int = event.index
		var p: Vector2 = event.position
		if event.pressed:
			if _action_rect().has_point(p) and action_label != "":
				GameInput.queue_action()
				_action_flash = 1.0
			elif _map_rect().has_point(p):
				map_tapped.emit()
			elif _auto_rect().has_point(p):
				autopilot_tapped.emit()
			elif missile_ammo >= 0 and p.distance_to(_missile_c()) < 52.0:
				GameInput.queue_missile()
				_missile_flash = 1.0
			elif _gear_rect().has_point(p):
				settings_tapped.emit()
			elif p.distance_to(_fire_c()) < 100.0:
				_fire_touch = idx
				var now := Time.get_ticks_msec()
				if now - _last_fire_tap < 320:
					GameInput.set_auto_fire(not GameInput.auto_fire)
					_last_fire_tap = -10000
				else:
					_last_fire_tap = now
			elif p.distance_to(_boost_c()) < 60.0:
				_boost_touch = idx
			elif _throttle_rect().grow(26).has_point(p):
				_throttle_touch = idx
				_set_throttle(p)
			elif p.distance_to(_roll_c(-1)) < 42.0:
				_roll_touches[idx] = -1
			elif p.distance_to(_roll_c(1)) < 42.0:
				_roll_touches[idx] = 1
			elif p.x < size.x * 0.5 and _stick_touch == -1:
				_stick_touch = idx
				_stick_center = p
				_stick_pos = p
		else:
			if idx == _stick_touch:
				_stick_touch = -1
			if idx == _fire_touch:
				_fire_touch = -1
			if idx == _boost_touch:
				_boost_touch = -1
			if idx == _throttle_touch:
				_throttle_touch = -1
			_roll_touches.erase(idx)
		_sync()
	elif event is InputEventScreenDrag:
		var idx: int = event.index
		if idx == _stick_touch:
			_stick_pos = event.position
			# drag the base along when pulling past the edge
			var d: Vector2 = _stick_pos - _stick_center
			if d.length() > STICK_R * 1.4:
				_stick_center = _stick_pos - d.normalized() * STICK_R * 1.4
		elif idx == _throttle_touch:
			_set_throttle(event.position)
		_sync()


func _set_throttle(p: Vector2) -> void:
	var r := _throttle_rect()
	GameInput.throttle = clampf(1.0 - (p.y - r.position.y) / r.size.y, 0.0, 1.0)


func _sync() -> void:
	if _stick_touch >= 0:
		var d := (_stick_pos - _stick_center) / STICK_R
		d = d.limit_length(1.0)
		# shape the response: fine control near center
		GameInput.touch_stick = Vector2(d.x, -d.y) * d.length()
	else:
		GameInput.touch_stick = Vector2.ZERO
	GameInput.touch_fire = _fire_touch >= 0
	GameInput.touch_boost = _boost_touch >= 0
	var r := 0.0
	for k in _roll_touches:
		r += _roll_touches[k]
	GameInput.touch_roll = clampf(r, -1.0, 1.0)


func reset() -> void:
	_stick_touch = -1
	_fire_touch = -1
	_boost_touch = -1
	_throttle_touch = -1
	_roll_touches.clear()
	_sync()


func _process(delta: float) -> void:
	_action_flash = maxf(0.0, _action_flash - delta * 3.0)
	_missile_flash = maxf(0.0, _missile_flash - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var font := UiKit.display(700)
	var faint := Color(ACCENT, 0.18)
	var line := Color(ACCENT, 0.45)
	# stick
	var c := _stick_center if _stick_touch >= 0 else _stick_home()
	var knob := c
	if _stick_touch >= 0:
		knob = c + (_stick_pos - c).limit_length(STICK_R)
	draw_circle(c, STICK_R, faint)
	draw_arc(c, STICK_R, 0, TAU, 48, line, 2.0, true)
	draw_circle(knob, 38, Color(ACCENT, 0.35 if _stick_touch >= 0 else 0.22))
	draw_arc(knob, 38, 0, TAU, 32, line, 2.0, true)
	# roll pads
	for side in [-1, 1]:
		var rc := _roll_c(side)
		var on: bool = side in _roll_touches.values()
		draw_circle(rc, 36, Color(ACCENT, 0.3 if on else 0.12))
		draw_arc(rc, 36, 0, TAU, 32, line, 2.0, true)
		_text(font, rc, "<" if side < 0 else ">", 30, Color(1, 1, 1, 0.8))
	_text(font, (_roll_c(-1) + _roll_c(1)) * 0.5 + Vector2(0, 4), "ROLL", 15, Color(1, 1, 1, 0.45))
	# fire
	var fc := _fire_c()
	var firing := _fire_touch >= 0
	draw_circle(fc, 84, Color(1.0, 0.35, 0.3, 0.35 if firing else 0.18))
	draw_arc(fc, 84, 0, TAU, 48, Color(1.0, 0.5, 0.45, 0.7), 3.0, true)
	_text(font, fc + Vector2(0, -8 if GameInput.auto_fire else 0), "FIRE", 24, Color(1, 1, 1, 0.9))
	if GameInput.auto_fire:
		var a0 := Time.get_ticks_msec() * 0.004
		for k in 3:
			draw_arc(fc, 94, a0 + k * TAU / 3.0, a0 + k * TAU / 3.0 + 1.2, 16, Color(1.0, 0.85, 0.4, 0.95), 4.0, true)
		_text(font, fc + Vector2(0, 22), "AUTO", 16, Color(1.0, 0.85, 0.4))
	else:
		_text(font, fc + Vector2(0, 112), "double-tap: auto", 12, Color(1, 1, 1, 0.35))
	# missiles
	if missile_ammo >= 0:
		var mc := _missile_c()
		var has := missile_ammo > 0
		draw_circle(mc, 46, Color(1.0, 0.7, 0.3, (0.18 if has else 0.06) + _missile_flash * 0.4))
		draw_arc(mc, 46, 0, TAU, 36, Color(1.0, 0.75, 0.4, 0.75 if has else 0.3), 2.5, true)
		_text(font, mc + Vector2(0, -8), "MSL", 17, Color(1, 1, 1, 0.9 if has else 0.4))
		_text(font, mc + Vector2(0, 14), str(missile_ammo), 15, Color(1.0, 0.85, 0.5, 0.95 if has else 0.4))
	# autopilot
	var ar2 := _auto_rect()
	var ap_col := UiKit.GOOD if autopilot_on else ACCENT
	var pulse2 := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	draw_rect(ar2, Color(ap_col, 0.12 + (0.18 * pulse2 if autopilot_on else 0.0)) if autopilot_on else Color(0.03, 0.06, 0.1, 0.55))
	draw_rect(ar2, Color(ap_col, 0.9 if autopilot_on else (0.45 if autopilot_ready else 0.25)), false, 1.5 if not autopilot_on else 2.5)
	_text(font, ar2.get_center(), "AUTOPILOT" if not autopilot_on else "AUTO ON", 15, Color(1, 1, 1, 0.9 if autopilot_ready or autopilot_on else 0.45))
	# map + settings
	for item in [[_map_rect(), "map", "MAP"], [_gear_rect(), "gear", ""]]:
		var r: Rect2 = item[0]
		draw_rect(r, Color(0.03, 0.06, 0.1, 0.55))
		draw_rect(r, line, false, 1.5)
		UiKit.icon(self, item[1], r.get_center() - Vector2(22 if item[2] != "" else 0, 0), 30, ACCENT, 2.0)
		if item[2] != "":
			_text(font, r.get_center() + Vector2(18, 0), item[2], 16, Color(1, 1, 1, 0.85))
	# boost
	var bc := _boost_c()
	draw_circle(bc, 52, Color(ACCENT, 0.35 if _boost_touch >= 0 else 0.15))
	draw_arc(bc, 52, 0, TAU, 40, line, 2.0, true)
	_text(font, bc, "BOOST", 17, Color(1, 1, 1, 0.85))
	# throttle
	var tr := _throttle_rect()
	draw_rect(tr, faint)
	draw_rect(tr, line, false, 2.0)
	var fill_h := tr.size.y * GameInput.throttle
	draw_rect(Rect2(tr.position.x + 5, tr.end.y - fill_h, tr.size.x - 10, fill_h), Color(ACCENT, 0.45))
	_text(font, Vector2(tr.get_center().x, tr.position.y - 18), "THR", 15, Color(1, 1, 1, 0.6))
	# context action
	if action_label != "":
		var ar := _action_rect()
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		draw_rect(ar, Color(action_color, 0.22 + pulse * 0.12 + _action_flash * 0.4))
		draw_rect(ar, Color(action_color, 0.9), false, 3.0)
		_text(font, ar.get_center(), action_label, 24, Color(1, 1, 1))


func _text(font: Font, center: Vector2, s: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-w * 0.5, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
