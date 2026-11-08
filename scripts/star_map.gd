class_name StarMap
extends Control
## Star map: a top-down SYSTEM view and a GALAXY view of the stargate network.
## Opened at a stargate it becomes the jump computer.

signal closed
signal jump_requested(dest: String)
signal autopilot_requested

var world: Node
var jump_mode := false
var tab := "galaxy"
var selected := ""
var _t := 0.0
var _jump_btn: Button
var _close_btn: Button
var _tab_btns := {}
var _info: RichTextLabel
var _panel_scroll: KineticScroll
var _dest_box: VBoxContainer
var _ap_btn: Button
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

	_panel_scroll = KineticScroll.new()
	add_child(_panel_scroll)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_override("normal_font", UiKit.body(500))
	_info.add_theme_font_override("bold_font", UiKit.display(700))
	_info.add_theme_font_size_override("normal_font_size", 18)
	_info.add_theme_font_size_override("bold_font_size", 22)
	_panel_scroll.content.add_child(_info)
	_dest_box = VBoxContainer.new()
	_dest_box.add_theme_constant_override("separation", 8)
	_panel_scroll.content.add_child(_dest_box)

	_jump_btn = UiKit.button("JUMP", Vector2(300, 66), 24)
	_jump_btn.pressed.connect(_on_jump)
	add_child(_jump_btn)
	_ap_btn = UiKit.button("ENGAGE AUTOPILOT", Vector2(300, 66), 19)
	_ap_btn.pressed.connect(func():
		world.sfx.ui("click")
		autopilot_requested.emit())
	add_child(_ap_btn)


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
	_panel_scroll.position = Vector2(size.x - panel_w - 24, 96)
	_panel_scroll.size = Vector2(panel_w + 10, size.y - 96 - 104)
	_jump_btn.position = Vector2(size.x - panel_w - 24 + (panel_w - _jump_btn.size.x) * 0.5, size.y - 92)
	_ap_btn.position = _jump_btn.position
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
	if not press:
		return
	if tab == "system":
		for st in get_tree().get_nodes_in_group("stations"):
			if _sys_to2d(st.global_position).distance_to(pos) < 40.0:
				_set_dest("station", st.station_id)
				return
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


func _set_dest(kind: String, id) -> void:
	GameState.set_destination(kind, id)
	world.sfx.ui("tab")
	var info := GameState.destination_info()
	if not info.is_empty():
		GameState.message.emit("Destination set: " + info["label"], Color(1.0, 0.82, 0.35))
	_refresh()


func _dest_button(text: String, active: bool, cb: Callable) -> void:
	var b := UiKit.button(text, Vector2(0, 50), 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if active:
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.35, 0.28, 0.08, 0.95), Color(1.0, 0.82, 0.35, 0.95), 4, 2, 14))
		b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	b.pressed.connect(cb)
	_dest_box.add_child(b)


func _rebuild_dest_list(view_sys: String) -> void:
	for c in _dest_box.get_children():
		_dest_box.remove_child(c)
		c.queue_free()
	var d: Dictionary = GameState.destination
	var hdr := Label.new()
	hdr.text = "SET COURSE"
	hdr.add_theme_font_override("font", UiKit.display(700, 2))
	hdr.add_theme_font_size_override("font_size", 17)
	hdr.add_theme_color_override("font_color", UiKit.ACCENT)
	_dest_box.add_child(hdr)
	for m in GameState.missions:
		if m["state"] != "active" and m["state"] != "done":
			continue
		var on: bool = d.get("type", "") == "mission" and int(d["id"]) == m["id"]
		var t: String = ("[DONE] " if m["state"] == "done" else "") + m["title"]
		_dest_button(t, on, _set_dest.bind("mission", m["id"]))
	for st in Galaxy.SYSTEMS[view_sys]["stations"]:
		var on2: bool = d.get("type", "") == "station" and d["id"] == st["id"]
		_dest_button("Station: " + st["name"], on2, _set_dest.bind("station", st["id"]))
	if not d.is_empty():
		var clr := UiKit.button("CLEAR DESTINATION", Vector2(0, 44), 14)
		clr.pressed.connect(func():
			GameState.destination = {}
			world.player.autopilot = false
			world.sfx.ui("click")
			_refresh())
		_dest_box.add_child(clr)


func _refresh() -> void:
	var cur: String = GameState.system_id
	_jump_btn.visible = jump_mode and tab == "galaxy"
	var flying: bool = world.player.mode == PlayerShip.Mode.FLIGHT or world.player.mode == PlayerShip.Mode.LANE
	_ap_btn.visible = not jump_mode and flying
	_ap_btn.disabled = GameState.destination.is_empty()
	_ap_btn.text = "AUTOPILOT OFF" if world.player.autopilot else "ENGAGE AUTOPILOT"
	_rebuild_dest_list(selected if tab == "galaxy" and selected != "" else cur)
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
		t += "[color=#ffd98c]==[/color] Grand highway (very fast)\n[color=#7fe0ff]—[/color] Road (fast, merge anywhere)\n[color=#ffd98c][ ][/color] Interchange  [color=#9fe6ff]•[/color] Crossroads\n[color=#ffd36b]O[/color] Stargates\n[color=#ff6655]•[/color] Raiders\n[color=#ffd36b]*[/color] Destination\n"
		var notes := _mission_notes(cur)
		if notes != "":
			t += "\n[b]CONTRACTS HERE[/b]\n" + notes
		t += "\n[color=#9fb4cc]Tap a station to set course.[/color]\n"
	if not GameState.destination.is_empty() and not flying and not jump_mode:
		t += "\n[color=#ffd36b]Launch, then tap AUTOPILOT to fly there.[/color]\n"
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


var _sys_ctr := Vector2.ZERO
var _sys_sc := 1.0


func _sys_fit() -> void:
	var r := _map_rect().grow(-30)
	var pts := []
	for st in get_tree().get_nodes_in_group("stations"):
		pts.append(st.global_position)
	for g in get_tree().get_nodes_in_group("stargates"):
		pts.append(g.global_position)
	if world.net:
		for nd in world.net.nodes:
			pts.append(nd["pos"])
	pts.append(world.player.global_position)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p3 in pts:
		var v := Vector2(p3.x, p3.z)
		mn = mn.min(v)
		mx = mx.max(v)
	var span := (mx - mn).max(Vector2(1000, 1000))
	_sys_sc = minf(r.size.x / span.x, r.size.y / span.y) * 0.9
	_sys_ctr = (mn + mx) * 0.5


func _sys_to2d(p3: Vector3) -> Vector2:
	return _map_rect().grow(-30).get_center() + (Vector2(p3.x, p3.z) - _sys_ctr) * _sys_sc


func _draw_system() -> void:
	_sys_fit()
	var r := _map_rect().grow(-30)
	var sc := _sys_sc
	var to2d := _sys_to2d

	# scale bar
	var km := 10000.0 * sc
	draw_line(r.position + Vector2(10, r.size.y - 10), r.position + Vector2(10 + km, r.size.y - 10), Color(1, 1, 1, 0.5), 2.0)
	draw_string(UiKit.body(500), r.position + Vector2(10, r.size.y - 18), "10 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))

	# asteroid field
	if world.field_center != Vector3.ZERO:
		var fc: Vector2 = to2d.call(world.field_center)
		draw_circle(fc, 1500.0 * sc, Color(0.6, 0.5, 0.4, 0.1))
		UiKit.text_c(self, UiKit.body(500), fc + Vector2(0, maxf(1500.0 * sc, 12.0) + 12.0), "Salvage field", 13, Color(0.8, 0.7, 0.6, 0.75), false)
	# roads first, highways on top
	if world.net:
		var net: RoadNet = world.net
		for pass_kind in ["road", "highway"]:
			var hw: bool = pass_kind == "highway"
			for t in net.tracks:
				if t.kind != pass_kind:
					continue
				var step := 900.0 if hw else 500.0
				var prev: Vector2 = to2d.call(t.curve.sample_baked(0.0, true))
				var s := 0.0
				while s < t.length:
					s = minf(s + step, t.length)
					var p2: Vector2 = to2d.call(t.curve.sample_baked(s, true))
					if hw:
						draw_line(prev, p2, Color(1.0, 0.75, 0.35, 0.22), 12.0, true)
						draw_line(prev, p2, Color(1.0, 0.86, 0.55, 0.95), 4.0, true)
					else:
						draw_line(prev, p2, Color(0.45, 0.85, 1.0, 0.75), 1.8, true)
					prev = p2
				# flowing dot
				var fp: Vector2 = to2d.call(t.curve.sample_baked(fmod(_t * (9000.0 if hw else 2500.0), t.length), true))
				draw_circle(fp, 3.5 if hw else 2.2, Color(1.0, 0.95, 0.8) if hw else Color(0.8, 1.0, 1.0))
		for nd in net.nodes:
			var np: Vector2 = to2d.call(nd["pos"])
			match nd["kind"]:
				"hub":
					draw_rect(Rect2(np - Vector2(8, 8), Vector2(16, 16)), Color(1.0, 0.86, 0.5), false, 2.5)
					UiKit.text_c(self, UiKit.body(600), np + Vector2(0, -20), nd["name"].replace(" Interchange", ""), 13, Color(1.0, 0.86, 0.55, 0.85))
				"cross":
					draw_circle(np, 4.5, Color(0.6, 0.9, 1.0))
				_:
					draw_arc(np, 7, 0, TAU, 18, Color(0.75, 0.6, 1.0), 2.0, true)
					if nd["name"] == "Beacon":
						UiKit.text_c(self, UiKit.body(600), np + Vector2(0, -20), "Beacon", 14, Color(0.8, 0.75, 1.0, 0.9))
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
	# destination
	var dt: Dictionary = world.dest_target()
	if not dt.is_empty():
		var dp: Vector2 = to2d.call(dt["pos"])
		var rr := 20.0 + 4.0 * sin(_t * 5.0)
		draw_polyline(PackedVector2Array([dp + Vector2(0, -rr), dp + Vector2(rr, 0), dp + Vector2(0, rr), dp + Vector2(-rr, 0), dp + Vector2(0, -rr)]), Color(1.0, 0.82, 0.35), 3.0, true)
		draw_line(to2d.call(world.player.global_position), dp, Color(1.0, 0.82, 0.35, 0.35), 2.0, true)
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
