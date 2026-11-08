extends Node
## Merges touch, keyboard and gamepad into one set of flight inputs (autoload "GameInput").

# Written by the touch overlay.
var touch_stick := Vector2.ZERO
var touch_roll := 0.0
var touch_fire := false
var touch_boost := false

# Final merged values, read by the player each frame.
var stick := Vector2.ZERO      # x = yaw (right +), y = pitch (up +)
var roll := 0.0                # right +
var fire := false
var boost := false
var throttle := 0.6            # 0..1, persistent
var using_touch := false
var auto_fire := false

signal auto_fire_changed(on: bool)
signal map_pressed

var _action_queued := false


func _ready() -> void:
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_keys("pitch_up", [KEY_S, KEY_DOWN])
	_bind_keys("pitch_down", [KEY_W, KEY_UP])
	_bind_keys("yaw_left", [KEY_A, KEY_LEFT])
	_bind_keys("yaw_right", [KEY_D, KEY_RIGHT])
	_bind_keys("roll_left", [KEY_Q])
	_bind_keys("roll_right", [KEY_E])
	_bind_keys("throttle_up", [KEY_R])
	_bind_keys("throttle_down", [KEY_F])
	_bind_keys("boost", [KEY_SHIFT])
	_bind_keys("fire", [KEY_SPACE])
	_bind_keys("action", [KEY_ENTER, KEY_T])
	_bind_keys("auto_fire", [KEY_G])
	_bind_keys("map", [KEY_M, KEY_TAB])
	_bind_joy_button("auto_fire", JOY_BUTTON_X)
	_bind_joy_button("map", JOY_BUTTON_BACK)
	_bind_joy_button("fire", JOY_BUTTON_A)
	_bind_joy_button("boost", JOY_BUTTON_B)
	_bind_joy_button("action", JOY_BUTTON_Y)
	_bind_joy_button("throttle_up", JOY_BUTTON_RIGHT_SHOULDER)
	_bind_joy_button("throttle_down", JOY_BUTTON_LEFT_SHOULDER)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("fire", m)


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _bind_joy_button(action: String, b: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		using_touch = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		using_touch = false
	if event.is_action_pressed("action"):
		_action_queued = true
	if event.is_action_pressed("auto_fire"):
		set_auto_fire(not auto_fire)
	if event.is_action_pressed("map"):
		map_pressed.emit()


func set_auto_fire(on: bool) -> void:
	if on == auto_fire:
		return
	auto_fire = on
	auto_fire_changed.emit(on)


## Called by UI buttons and the touch overlay.
func queue_action() -> void:
	_action_queued = true


func consume_action() -> bool:
	var a := _action_queued
	_action_queued = false
	return a


func _process(delta: float) -> void:
	var s := touch_stick
	s.x += Input.get_axis("yaw_left", "yaw_right")
	s.y += Input.get_axis("pitch_up", "pitch_down") * -1.0
	var r := touch_roll + Input.get_axis("roll_left", "roll_right")
	var f := touch_fire or Input.is_action_pressed("fire")
	var b := touch_boost or Input.is_action_pressed("boost")

	# Gamepad: left stick flies, right stick X rolls, triggers fire / boost.
	for dev in Input.get_connected_joypads():
		var lx := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		var rx := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)
		s.x += _dz(lx)
		s.y += -_dz(ly)
		r += _dz(rx)
		throttle = clampf(throttle - _dz(ry) * delta * 0.8, 0.0, 1.0)
		if Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.4:
			f = true
		if Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.4:
			b = true

	throttle = clampf(throttle + Input.get_axis("throttle_down", "throttle_up") * delta * 0.8, 0.0, 1.0)
	if Settings.invert_pitch:
		s.y = -s.y
	stick = s.limit_length(1.0)
	roll = clampf(r, -1.0, 1.0)
	fire = f
	boost = b


func _dz(v: float) -> float:
	if absf(v) < 0.15:
		return 0.0
	return signf(v) * (absf(v) - 0.15) / 0.85
