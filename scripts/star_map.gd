class_name StarMap
extends Control
## Star map: a top-down SYSTEM view and a GALAXY view of the stargate network.
## Opened at a stargate it becomes the jump computer.

signal closed
signal jump_requested(dest: String)

var world: Node
var jump_mode := false
var tab := "galaxy"
var selected := ""
var _t := 0.0
var _jump_btn: Button
var _close_btn: Button
var _tab_btns := {}
var _info: RichTextLabel
var _open_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP

	var top := HBoxContainer.new()
	top.position = Vector2(24, 18)
	add_child(top)
	for t in [["system", "SYSTEM"], ["galaxy", "GALAXY"]]:
		var b := UiKit.button(t[1], Vector2(170, 52))
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(t[0]))
		top.add_child(b)
		_tab_btns[t[0]] = b

	_close_btn = UiKit.button("CLOSE", Vector2(150, 52))
	_close_btn.pressed.connect(func():
		world.sfx.ui("click")
		closed.emit())
	add_child(_close_btn)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_override("normal_font", UiKit.body(500))
	_info.add_theme_font_override("bold_font", UiKit.display(700))
	_info.add_theme_font_size_override("normal_font_size", 19)
	_info.add_theme_font_size_override("bold_font_size", 24)
	add_child(_info)

	_jump_btn = UiKit.button("JUMP", Vector2(300, 70), 24)
	_jump_btn.pressed.connect(_on_jump)
	add_child(_jump_btn)


func open(in_jump_mode: bool) -> void:
	jump_mode = in_jump_mode
	selected = ""
	_set_tab("galaxy" if in_jump_mode else tab)
	visible = true
	modulate.a = 0.0
	if _open_tween:
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	world.sfx.ui("open")


func _set_tab(t: String) -> void:
	tab = t
	for k in _tab_btns:
		_tab_btns[k].button_pressed = (k == t)
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var right := size.x - 24
	_close_btn.position = Vector2(right - _close_btn.size.x, 18)
	var panel_w := minf(380.0, size.x * 0.32)
	_info.position = Vector2(size.x - panel_w - 24, 100)
	_info.size = Vector2(panel_w, 0)
	_jump_btn.position = Vector2(size.x - panel_w - 24 + (panel_w - _jump_btn.size.x) * 0.5, size.y - 100)
	queue_redraw()


func _map_rect() -> Rect2:
	var panel_w := minf(380.0, size.x * 0.32)
	return Rect2(Vector2(40, 100), Vector2(size.x - panel_w - 100, size.y - 140))


func _gui_input(event: InputEvent) -> void:
	var press := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press = true
		pos = event.position
	if not press or tab != "galaxy":
		return
	for sid in Galaxy.SYSTEMS:
		if _gal_pos(sid).distance_to(pos) < 46.0:
			selected = sid
			world.sfx.ui("tab")
			_refresh()
			return


func _gal_pos(sid: String) -> Vector2:
	var r := _map_rect()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for k in Galaxy.SYSTEMS:
		var p: Vector2 = Galaxy.SYSTEMS[k]["map"]
		mn = mn.min(p)
		mx = mx.max(p)
	var span := (mx - mn)
	var sc := minf((r.size.x - 200) / maxf(span.x, 0.01), (r.size.y - 160) / maxf(span.y, 0.01))
	var c := r.get_center()
	var p2: Vector2 = Galaxy.SYSTEMS[sid]["map"]
	return c + (p2 - (mn + mx) * 0.5) * sc


func _refresh() -> void:
	var cur: String = GameState.system_id
	_jump_btn.visible = jump_mode and tab == "galaxy"
	var t := ""
	if tab == "galaxy":
		var sid := selected if selected != "" else cur
		var sysd: Dictionary = Galaxy.SYSTEMS[sid]
		var h := Galaxy.hops(cur, sid)
		t += "[b]%s[/b]\n" % sysd["name"].to_upper()
		t += "[color=#9fb4cc]%s[/color]\n\n" % sysd["desc"]
		t += "Threat  [color=#ff7766]%s[/color]\n" % ["", "Low", "Medium", "High"][sysd["threat"]]
		t += "Jump charges  [color=#7fe0ff]%d / %d[/color]\n" % [GameState.jump_charges, GameState.max_jump_charges()]
		if sid == cur:
			t += "[color=#7fffb0]You are here[/color]\n"
		else:
			t += "Distance  %d hop%s\n" % [h, "" if h == 1 else "s"]
		t += "\n[b]STATIONS[/b]\n"
		for st in sysd["stations"]:
			t += "[color=#%s]»[/color] %s  [color=#8899aa]%s[/color]\n" % [(st["accent"] as Color).to_html(false), st["name"], st["kind"]]
		var notes := _mission_notes(sid)
		if notes != "":
			t += "\n[b]CONTRACTS[/b]\n" + notes
		if jump_mode:
			var can := sid != cur and h <= GameState.jump_charges
			_jump_btn.disabled = not can
			if sid == cur:
				_jump_btn.text = "SELECT A SYSTEM"
			elif h > GameState.jump_charges:
				_jump_btn.text = "NEED %d CHARGES" % h
			else:
				_jump_btn.text = "JUMP  (%d)" % h
	else:
		var sysd: Dictionary = Galaxy.SYSTEMS[cur]
		t += "[b]%s[/b]\n" % sysd["name"].to_upper()
		t += "[color=#9fb4cc]%s[/color]\n\n" % sysd["desc"]
		t += "[color=#7fe0ff]—[/color] Space lane\n[color=#b48cff]o[/color] Lane exits\n[color=#ffd36b]O[/color] Stargates\n[color=#ff6655]•[/color] Raiders\n"
		var notes := _mission_notes(cur)
		if notes != "":
			t += "\n[b]CONTRACTS HERE[/b]\n" + notes
	_info.text = t


func _mission_notes(sid: String) -> String:
	var out := ""
	for m in GameState.missions:
		if m["state"] != "active" and m["state"] != "done":
			continue
		if m["kind"] == "hunt" and m["system"] == sid:
			out += "[color=#ff8866]»[/color] %s (%d left)\n" % [m["title"], m["left"]]
		elif m["kind"] == "courier" and Galaxy.system_of(m["station"]) == sid:
			out += "[color=#ffd36b]»[/color] %s\n" % m["title"]
	return out


func _on_jump() -> void:
	if selected == "" or selected == GameState.system_id:
		return
	world.sfx.ui("click")
	jump_requested.emit(selected)


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.97))
	# subtle grid
	var r := _map_rect()
	var grid := Color(UiKit.ACCENT, 0.05)
	var step := 60.0
	var x := r.position.x
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid, 1.0)
		x += step
	var y := r.position.y
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid, 1.0)
		y += step
	draw_rect(r, Color(UiKit.ACCENT, 0.18), false, 1.0)
	# info panel backdrop
	var panel_w := minf(380.0, size.x * 0.32)
	var pr := Rect2(Vector2(size.x - panel_w - 40, 84), Vector2(panel_w + 32, size.y - 104))
	draw_style_box(UiKit.box(Color(0.04, 0.07, 0.12, 0.9), Color(UiKit.ACCENT, 0.3)), pr)
	if tab == "galaxy":
		_draw_galaxy()
	else:
		_draw_system()
	var title := "JUMP COMPUTER" if jump_mode else "STAR MAP"
	UiKit.text_c(self, UiKit.display(800, 4), Vector2((400.0 + size.x - 200.0) * 0.5, 44), title, 24, Color(1, 1, 1, 0.9))


func _draw_galaxy() -> void:
	var cur: String = GameState.system_id
	var font := UiKit.display(700)
	var reach := {}
	for sid in Galaxy.SYSTEMS:
		reach[sid] = Galaxy.hops(cur, sid)
	# links
	var drawn := {}
	for sid in Galaxy.SYSTEMS:
		for l in Galaxy.SYSTEMS[sid]["links"]:
			var key: String = sid + l if sid < l else l + sid
			if drawn.has(key):
				continue
			drawn[key] = true
			var a := _gal_pos(sid)
			var b := _gal_pos(l)
			draw_line(a, b, Color(0.6, 0.75, 1.0, 0.25), 3.0, true)
			# travelling pulses along the link
			for k in 3:
				var f := fmod(_t * 0.25 + k / 3.0, 1.0)
				draw_circle(a.lerp(b, f), 2.5, Color(0.7, 0.9, 1.0, 0.5))
	# highlighted jump route
	if selected != "" and selected != cur:
		var route := Galaxy.path(cur, selected)
		var ok: bool = route.size() - 1 <= GameState.jump_charges
		for i in range(route.size() - 1):
			draw_line(_gal_pos(route[i]), _gal_pos(route[i + 1]), Color(UiKit.GOOD if ok else UiKit.BAD, 0.85), 5.0, true)
	# systems
	for sid in Galaxy.SYSTEMS:
		var p := _gal_pos(sid)
		var sysd: Dictionary = Galaxy.SYSTEMS[sid]
		var sky: Dictionary = sysd["sky"]
		var col: Color = (sky["c"] as Color).lerp(sky["sun_col"], 0.5)
		var glow := 0.5 + 0.5 * sin(_t * 2.0 + p.x)
		for i in 4:
			draw_circle(p, 34.0 - i * 6.0, Color(col, 0.05 + i * 0.03))
		draw_circle(p, 12.0, col.lightened(0.3))
		if sid == cur:
			draw_arc(p, 26.0 + glow * 4.0, 0, TAU, 40, Color(UiKit.GOOD, 0.9), 2.5, true)
		if sid == selected:
			draw_arc(p, 38.0, _t, _t + PI * 1.5, 40, Color(1, 1, 1, 0.9), 2.0, true)
		var label: String = sysd["name"].to_upper()
		UiKit.text_c(self, font, p + Vector2(0, 52), label, 17, Color(1, 1, 1, 0.92))
		var sub := "%d HOP%s" % [reach[sid], "" if reach[sid] == 1 else "S"] if sid != cur else "YOU ARE HERE"
		UiKit.text_c(self, UiKit.body(600), p + Vector2(0, 74), sub, 14, Color(UiKit.TEXT_DIM, 0.9))
		# threat pips
		for k in int(sysd["threat"]):
			draw_rect(Rect2(p + Vector2(-14 + k * 10, -40), Vector2(7, 7)), Color(UiKit.BAD, 0.85))
		if not _mission_notes(sid).is_empty():
			UiKit.icon(self, "target", p + Vector2(30, -26), 18, UiKit.GOLD, 1.6)


func _draw_system() -> void:
	var r := _map_rect().grow(-30)
	var pts := []
	for st in get_tree().get_nodes_in_group("stations"):
		pts.append(st.global_position)
	for g in get_tree().get_nodes_in_group("stargates"):
		pts.append(g.global_position)
	if world.lane:
		for e in world.lane.exits:
			pts.append(world.lane.curve.sample_baked(e["s"], true))
	pts.append(world.player.global_position)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p3 in pts:
		var v := Vector2(p3.x, p3.z)
		mn = mn.min(v)
		mx = mx.max(v)
	var span := (mx - mn).max(Vector2(1000, 1000))
	var sc := minf(r.size.x / span.x, r.size.y / span.y) * 0.9
	var ctr := (mn + mx) * 0.5
	var to2d := func(p3: Vector3) -> Vector2:
		return r.get_center() + (Vector2(p3.x, p3.z) - ctr) * sc

	# scale bar
	var km := 1000.0 * sc
	draw_line(r.position + Vector2(10, r.size.y - 10), r.position + Vector2(10 + km, r.size.y - 10), Color(1, 1, 1, 0.5), 2.0)
	draw_string(UiKit.body(500), r.position + Vector2(10, r.size.y - 18), "1 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))

	# asteroid field
	if world.field_center != Vector3.ZERO:
		var fc: Vector2 = to2d.call(world.field_center)
		draw_circle(fc, 900.0 * sc, Color(0.6, 0.5, 0.4, 0.08))
		UiKit.text_c(self, UiKit.body(500), fc + Vector2(0, 900.0 * sc * 0.5), "Asteroid field", 13, Color(0.8, 0.7, 0.6, 0.6), false)
	# lane
	if world.lane:
		var lane: SpaceLane = world.lane
		var prev: Vector2 = to2d.call(lane.curve.sample_baked(0.0, true))
		var s := 0.0
		while s < lane.length:
			s = minf(s + 100.0, lane.length)
			var p2: Vector2 = to2d.call(lane.curve.sample_baked(s, true))
			draw_line(prev, p2, Color(0.3, 0.85, 1.0, 0.25), 9.0, true)
			draw_line(prev, p2, Color(0.5, 0.95, 1.0, 0.9), 2.5, true)
			prev = p2
		# flowing dot
		var fp: Vector2 = to2d.call(lane.curve.sample_baked(fmod(_t * 1500.0, lane.length), true))
		draw_circle(fp, 4, Color(0.8, 1.0, 1.0))
		for e in lane.exits:
			var ep: Vector2 = to2d.call(lane.curve.sample_baked(e["s"], true))
			draw_arc(ep, 9, 0, TAU, 20, Color(0.75, 0.6, 1.0), 2.5, true)
			UiKit.text_c(self, UiKit.body(600), ep + Vector2(0, -20), e["name"], 14, Color(0.8, 0.75, 1.0, 0.9))
	# stargates
	for g in get_tree().get_nodes_in_group("stargates"):
		var gp: Vector2 = to2d.call(g.global_position)
		draw_arc(gp, 15, 0, TAU, 28, UiKit.GOLD, 3.0, true)
		draw_arc(gp, 8 + 3 * sin(_t * 3.0), 0, TAU, 20, Color(UiKit.GOLD, 0.5), 2.0, true)
		UiKit.text_c(self, UiKit.display(600), gp + Vector2(0, 30), g.display_name.to_upper(), 13, UiKit.GOLD)
	# stations
	for st in get_tree().get_nodes_in_group("stations"):
		var sp: Vector2 = to2d.call(st.global_position)
		var c: Color = st.accent
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -12), sp + Vector2(12, 0), sp + Vector2(0, 12), sp + Vector2(-12, 0)]), Color(c, 0.85))
		UiKit.text_c(self, UiKit.display(700), sp + Vector2(0, 30), st.display_name.to_upper(), 15, c)
	# raiders
	for e in get_tree().get_nodes_in_group("enemies"):
		draw_circle(to2d.call(e.global_position), 4, Color(1.0, 0.35, 0.3, 0.9))
	# player
	var p: PlayerShip = world.player
	var pp: Vector2 = to2d.call(p.global_position)
	var f3 := -p.global_transform.basis.z
	var f2 := Vector2(f3.x, f3.z).normalized()
	if f2.length() < 0.1:
		f2 = Vector2(0, -1)
	var side := Vector2(-f2.y, f2.x)
	draw_colored_polygon(PackedVector2Array([pp + f2 * 14, pp - f2 * 9 + side * 8, pp - f2 * 4, pp - f2 * 9 - side * 8]), UiKit.GOOD)
	draw_arc(pp, 20 + 4 * sin(_t * 4.0), 0, TAU, 28, Color(UiKit.GOOD, 0.5), 1.5, true)
