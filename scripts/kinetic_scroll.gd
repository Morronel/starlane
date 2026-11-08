class_name KineticScroll
extends Control
## Touch-first vertical scroller: drag anywhere (even on buttons) to scroll,
## fling with momentum, rubber-band at the edges. A drag cancels the button
## press it started on, so scrolling never buys things by accident.

var content: VBoxContainer
var scroll := 0.0
var is_active := Callable()   # optional: returns false while another overlay covers us

const DRAG_START := 12.0
const FRICTION := 3.2

var _touch := -1
var _start := Vector2.ZERO
var _dragging := false
var _vel := 0.0
var _samples: Array = []     # [time, y]
var _bar_alpha := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	add_child(content)


var scroll_vertical: int:
	get:
		return int(scroll)
	set(v):
		scroll = float(v)
		_vel = 0.0
		_clamp_hard()


func max_scroll() -> float:
	return maxf(0.0, content.get_combined_minimum_size().y - size.y + 24.0)


func _clamp_hard() -> void:
	scroll = clampf(scroll, 0.0, max_scroll())


func _active() -> bool:
	if not is_visible_in_tree():
		return false
	return is_active.is_null() or is_active.call()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch == -1 and _active() and get_global_rect().has_point(event.position):
				_touch = event.index
				_start = event.position
				_dragging = false
				_vel = 0.0
				_samples = [[Time.get_ticks_msec() / 1000.0, event.position.y]]
		elif event.index == _touch:
			_touch = -1
			if _dragging:
				_dragging = false
				_vel = _fling_velocity()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch:
		var now := Time.get_ticks_msec() / 1000.0
		_samples.append([now, event.position.y])
		while _samples.size() > 6:
			_samples.pop_front()
		if not _dragging and absf(event.position.y - _start.y) > DRAG_START:
			_dragging = true
			_cancel_presses(content)
		if _dragging:
			var dy: float = event.relative.y
			if scroll < 0.0 or scroll > max_scroll():
				dy *= 0.4   # rubber band
			scroll -= dy
			_bar_alpha = 1.0
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and _active() and get_global_rect().has_point(event.position):
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_vel += 1400.0
			_bar_alpha = 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_vel -= 1400.0
			_bar_alpha = 1.0


func _fling_velocity() -> float:
	if _samples.size() < 2:
		return 0.0
	var a: Array = _samples[0]
	var b: Array = _samples[_samples.size() - 1]
	var dt: float = b[0] - a[0]
	if dt <= 0.0 or Time.get_ticks_msec() / 1000.0 - b[0] > 0.1:
		return 0.0
	return clampf(-(b[1] - a[1]) / dt, -5000.0, 5000.0)


func _cancel_presses(n: Node) -> void:
	for c in n.get_children():
		if c is BaseButton and not c.disabled:
			# toggling disabled clears the pending press without firing it
			c.disabled = true
			c.disabled = false
		_cancel_presses(c)


func _process(delta: float) -> void:
	content.position = Vector2(0, -roundf(scroll))
	content.size = Vector2(size.x - 14.0, 0)
	var mx := max_scroll()
	if not _dragging:
		if absf(_vel) > 1.0:
			scroll += _vel * delta
			_vel *= exp(-FRICTION * delta)
			if scroll < 0.0 or scroll > mx:
				_vel *= exp(-18.0 * delta)
		else:
			_vel = 0.0
		# spring back from overscroll
		if scroll < 0.0:
			scroll = lerpf(scroll, 0.0, 1.0 - exp(-delta * 12.0))
			if scroll > -0.5:
				scroll = 0.0
		elif scroll > mx:
			scroll = lerpf(scroll, mx, 1.0 - exp(-delta * 12.0))
			if scroll < mx + 0.5:
				scroll = mx
	if absf(_vel) > 20.0:
		_bar_alpha = 1.0
	_bar_alpha = maxf(0.0, _bar_alpha - delta * 1.2)
	queue_redraw()


func _draw() -> void:
	var total := content.get_combined_minimum_size().y + 24.0
	if total <= size.y:
		return
	var h := maxf(40.0, size.y * size.y / total)
	var t := clampf(scroll / maxf(max_scroll(), 1.0), 0.0, 1.0)
	var y := t * (size.y - h)
	var a := 0.18 + 0.5 * _bar_alpha
	draw_rect(Rect2(size.x - 6, 4, 3, size.y - 8), Color(1, 1, 1, 0.05))
	draw_rect(Rect2(size.x - 7, y + 4, 5, h - 8), Color(0.45, 0.85, 1.0, a))
