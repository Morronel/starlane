class_name StationMenu
extends Control
## Docked station screen. Tabs: contracts, market, shipyard, services.
## Built for touch: big targets, animated feedback, satisfying sounds.

signal launch_pressed
signal map_pressed
signal settings_pressed

var station: Station
var world: Node
var _tab := "missions"
var _content: VBoxContainer
var _scroll: ScrollContainer
var _rail_btns := {}
var _header: Control
var _shown_credits := 0.0
var _popups: Array = []   # {text, color, t, x}
var _open_t := 0.0
var _notes: Array = []
var _preview: SubViewport
var _preview_ship: Node3D

const TABS := [
	["missions", "CONTRACTS", "target"],
	["market", "MARKET", "crate"],
	["shipyard", "SHIPYARD", "ship"],
	["services", "SERVICES", "wrench"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	_shown_credits = GameState.credits

	# header (custom drawn)
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(_draw_header)
	add_child(_header)

	# left rail
	var rail := VBoxContainer.new()
	rail.name = "Rail"
	rail.add_theme_constant_override("separation", 10)
	add_child(rail)
	for t in TABS:
		var b := _rail_button(t[1], t[2])
		b.pressed.connect(_select.bind(t[0], true))
		rail.add_child(b)
		_rail_btns[t[0]] = b
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	rail.add_child(spacer)
	var mini := HBoxContainer.new()
	mini.add_theme_constant_override("separation", 10)
	rail.add_child(mini)
	var mapb := _icon_button("map")
	mapb.pressed.connect(func():
		world.sfx.ui("click")
		map_pressed.emit())
	mini.add_child(mapb)
	var setb := _icon_button("gear")
	setb.pressed.connect(func():
		world.sfx.ui("click")
		settings_pressed.emit())
	mini.add_child(setb)

	var launch := _launch_button()
	launch.name = "Launch"
	add_child(launch)

	# content
	var panel := PanelContainer.new()
	panel.name = "ContentPanel"
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.02, 0.04, 0.08, 0.82), Color(UiKit.ACCENT, 0.25), 8, 1, 18))
	add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content)

	GameState.credits_changed.connect(_on_credits)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var rail_w := 250.0
	_header.position = Vector2.ZERO
	_header.size = Vector2(w, 118)
	var rail: Control = get_node("Rail")
	rail.position = Vector2(22, 130)
	rail.size = Vector2(rail_w, 0)
	var launch: Control = get_node("Launch")
	launch.position = Vector2(22, h - 104)
	launch.size = Vector2(rail_w, 82)
	var panel: Control = get_node("ContentPanel")
	panel.position = Vector2(rail_w + 44, 130)
	panel.size = Vector2(w - rail_w - 66, h - 152)


# --- widgets -------------------------------------------------------------------

func _rail_button(label: String, icon_name: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(250, 66)
	b.text = ""
	b.add_theme_stylebox_override("normal", UiKit.box(Color(0.04, 0.08, 0.14, 0.85), Color(UiKit.ACCENT, 0.2), 6))
	b.add_theme_stylebox_override("hover", UiKit.box(Color(0.06, 0.12, 0.2, 0.9), Color(UiKit.ACCENT, 0.5), 6))
	b.add_theme_stylebox_override("pressed", UiKit.box(Color(0.08, 0.22, 0.34, 0.95), Color(UiKit.ACCENT, 0.9), 6, 2))
	b.add_theme_stylebox_override("hover_pressed", UiKit.box(Color(0.08, 0.22, 0.34, 0.95), Color(UiKit.ACCENT, 0.9), 6, 2))
	b.draw.connect(func():
		var on := b.button_pressed
		var col := Color(1, 1, 1) if on else Color(UiKit.TEXT_DIM, 0.9)
		UiKit.icon(b, icon_name, Vector2(36, b.size.y * 0.5), 30, UiKit.ACCENT if on else col, 2.2)
		b.draw_string(UiKit.display(700, 2), Vector2(68, b.size.y * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		if on:
			b.draw_rect(Rect2(Vector2(0, 8), Vector2(4, b.size.y - 16)), UiKit.ACCENT))
	b.pressed.connect(func(): UiKit.pop(b))
	return b


func _icon_button(icon_name: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 58)
	b.draw.connect(func(): UiKit.icon(b, icon_name, b.size * 0.5, 30, UiKit.ACCENT, 2.2))
	b.pressed.connect(func(): UiKit.pop(b))
	return b


func _launch_button() -> Button:
	var b := Button.new()
	b.add_theme_stylebox_override("normal", UiKit.box(Color(0.05, 0.3, 0.22, 0.95), Color(UiKit.GOOD, 0.8), 8, 2))
	b.add_theme_stylebox_override("hover", UiKit.box(Color(0.08, 0.4, 0.3, 0.95), Color(UiKit.GOOD, 1.0), 8, 2))
	b.add_theme_stylebox_override("pressed", UiKit.box(Color(0.2, 0.6, 0.45, 1.0), Color(1, 1, 1), 8, 3))
	b.draw.connect(func():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		b.draw_rect(Rect2(Vector2(6, 6), b.size - Vector2(12, 12)), Color(UiKit.GOOD, 0.05 + pulse * 0.08))
		UiKit.icon(b, "launch", Vector2(42, b.size.y * 0.5), 34, Color(1, 1, 1), 2.6)
		b.draw_string(UiKit.display(900, 3), Vector2(76, b.size.y * 0.5 + 10), "LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1)))
	b.pressed.connect(func():
		UiKit.pop(b)
		launch_pressed.emit())
	return b


func _card(accent: Color) -> Array:
	## Returns [card, hbox]. Cards slide/fade in when a tab opens.
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(0.06, 0.1, 0.16, 0.92), Color(accent, 0.35), 6, 1, 16)
	sb.border_width_left = 5
	sb.border_color = Color(accent, 0.9)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	_content.add_child(p)
	var i := _content.get_child_count()
	p.modulate.a = 0.0
	p.pivot_offset = Vector2(0, 30)
	p.scale = Vector2(0.96, 0.96)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.25).set_delay(i * 0.045)
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_delay(i * 0.045).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return [p, h]


func _label(text: String, size_px: int, col: Color, font: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _text_block(parent: Control, title: String, body: String, title_col := Color(1, 1, 1)) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	v.add_child(_label(title, 20, title_col, UiKit.display(700)))
	if body != "":
		v.add_child(_label(body, 17, UiKit.TEXT_DIM, UiKit.body(500), true))
	parent.add_child(v)
	return v


func _btn(parent: Control, text: String, cb: Callable, disabled := false, w := 150.0) -> Button:
	var b := UiKit.button(text, Vector2(w, 56), 16)
	b.disabled = disabled
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb.bind(b))
	parent.add_child(b)
	return b


func _heading(text: String, sub := "") -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(_label(text, 26, UiKit.ACCENT, UiKit.display(800, 3)))
	if sub != "":
		v.add_child(_label(sub, 16, UiKit.TEXT_DIM, UiKit.body(500), true))
	_content.add_child(v)


# --- open / tabs ----------------------------------------------------------------

func open(st: Station, notes: Array) -> void:
	station = st
	_notes = notes
	visible = true
	_open_t = 0.0
	_shown_credits = GameState.credits
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	for n in notes:
		if n.ends_with(" cr"):
			_popup(n.get_slice(": ", n.get_slice_count(": ") - 1), UiKit.GOLD)
	_select(_tab, false)


func _select(tab: String, with_sound := true) -> void:
	_tab = tab
	if with_sound:
		world.sfx.ui("tab")
	for k in _rail_btns:
		_rail_btns[k].button_pressed = (k == tab)
		_rail_btns[k].queue_redraw()
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	if _preview:
		_preview = null
	_scroll.scroll_vertical = 0
	match _tab:
		"missions":
			_build_missions()
		"market":
			_build_market()
		"shipyard":
			_build_shipyard()
		"services":
			_build_services()


func _process(delta: float) -> void:
	if not visible:
		return
	_open_t += delta
	_shown_credits = lerpf(_shown_credits, GameState.credits, 1.0 - exp(-delta * 7.0))
	if absf(_shown_credits - GameState.credits) < 0.5:
		_shown_credits = GameState.credits
	for p in _popups:
		p["t"] += delta
	_popups = _popups.filter(func(p): return p["t"] < 2.2)
	if _preview_ship and is_instance_valid(_preview_ship):
		_preview_ship.rotate_y(delta * 0.6)
	_header.queue_redraw()
	var l: Control = get_node("Launch")
	l.queue_redraw()


func _on_credits(_v: int) -> void:
	_header.queue_redraw()


func _popup(text: String, col: Color) -> void:
	_popups.append({"text": text, "color": col, "t": 0.0, "i": _popups.size()})


func _money(delta_cr: int) -> void:
	if delta_cr == 0:
		return
	_popup(("+%s cr" if delta_cr > 0 else "-%s cr") % _fmt(absi(delta_cr)), UiKit.GOOD if delta_cr > 0 else UiKit.BAD)


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _draw_header() -> void:
	if station == null:
		return
	var h := _header
	var w := h.size.x
	# backdrop gradient strip
	h.draw_rect(Rect2(0, 0, w, 118), Color(0.0, 0.02, 0.05, 0.75))
	var reveal := clampf(_open_t / 0.6, 0.0, 1.0)
	var ease_r := 1.0 - pow(1.0 - reveal, 3.0)
	h.draw_rect(Rect2(24, 104, (w * 0.45) * ease_r, 3), station.accent)
	h.draw_rect(Rect2(24, 104, (w * 0.45) * ease_r, 3).grow(3), Color(station.accent, 0.15))
	# scanning shimmer
	var sx := fmod(_open_t * 260.0, w + 400.0) - 200.0
	h.draw_rect(Rect2(sx, 0, 120, 118), Color(station.accent, 0.035))
	var name_font := UiKit.display(900, 6)
	h.draw_string(name_font, Vector2(26, 62), station.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, ease_r))
	var sys_name: String = Galaxy.SYSTEMS[GameState.system_id]["name"]
	var sub := "%s   ·   %s SYSTEM" % [station.kind.to_upper(), sys_name.to_upper()]
	h.draw_string(UiKit.display(600, 2), Vector2(28, 92), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(station.accent, 0.95 * ease_r))

	# credits
	var right := w - 28
	var cr_text := _fmt(int(round(_shown_credits)))
	var cf := UiKit.display(800, 1)
	var cw := cf.get_string_size(cr_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	h.draw_string(cf, Vector2(right - cw - 44, 56), cr_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UiKit.GOLD)
	h.draw_string(UiKit.display(700), Vector2(right - 38, 56), "CR", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiKit.GOLD, 0.8))
	# hull bar + jump pips + cargo
	var bx := right - 300
	h.draw_string(UiKit.display(600), Vector2(bx, 84), "HULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.TEXT_DIM)
	h.draw_rect(Rect2(bx + 46, 75, 90, 8), Color(1, 0.6, 0.25, 0.2))
	h.draw_rect(Rect2(bx + 46, 75, 90 * GameState.hull / 100.0, 8), Color(1, 0.6, 0.25))
	h.draw_string(UiKit.display(600), Vector2(bx + 150, 84), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.TEXT_DIM)
	for i in GameState.max_jump_charges():
		var on := i < GameState.jump_charges
		var c := Vector2(bx + 200 + i * 18, 79)
		if on:
			h.draw_circle(c, 6, UiKit.ACCENT)
		else:
			h.draw_arc(c, 6, 0, TAU, 16, Color(UiKit.ACCENT, 0.4), 1.5, true)
	var cargo := "CARGO %d / %d" % [GameState.cargo_used(), GameState.cargo_capacity()]
	h.draw_string(UiKit.display(600), Vector2(bx, 104), cargo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.TEXT_DIM)

	# money popups float up from the counter
	for p in _popups:
		var t: float = p["t"]
		var a := clampf(1.0 - (t - 1.4) / 0.8, 0.0, 1.0) * clampf(t / 0.12, 0.0, 1.0)
		var y: float = 110.0 - t * 30.0 + p["i"] * 26.0
		var f := UiKit.display(700)
		var tw := f.get_string_size(p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		h.draw_string(f, Vector2(right - tw, y + 40), p["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(p["color"], a))


# --- feedback --------------------------------------------------------------------

func _sparkle(at: Control, col: Color) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 28
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = col
	var g := Gradient.new()
	g.set_color(0, Color(col, 1.0))
	g.set_color(1, Color(col, 0.0))
	p.color_ramp = g
	add_child(p)
	p.global_position = at.global_position + at.size * 0.5
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _deny(b: Control) -> void:
	world.sfx.ui("error")
	var tw := b.create_tween()
	var x0 := b.position.x
	for i in 4:
		tw.tween_property(b, "position:x", x0 + (8 if i % 2 == 0 else -8), 0.04)
	tw.tween_property(b, "position:x", x0, 0.04)


# --- tabs ------------------------------------------------------------------------

func _build_missions() -> void:
	_heading("CONTRACTS", "Take work, earn credits. Hunts pay on completion at any station.")
	for n in _notes:
		var c := _card(UiKit.GOLD)
		_text_block(c[1], "PAYMENT RECEIVED" if n.ends_with(" cr") else "STATION NOTICE", n, UiKit.GOLD)
	_notes = []
	var list := GameState.missions_for(station.station_id)
	if list.is_empty():
		var c := _card(UiKit.TEXT_DIM)
		_text_block(c[1], "No contracts right now", "Check back later.")
	for m in list:
		var hunt: bool = m["kind"] == "hunt"
		var col := Color(1.0, 0.5, 0.4) if hunt else UiKit.GOLD
		var c := _card(col)
		var h: HBoxContainer = c[1]
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(48, 48)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.draw.connect(func(): UiKit.icon(ic, "target" if hunt else "crate", Vector2(24, 24), 40, col, 2.2))
		h.add_child(ic)
		var state: String = m["state"]
		var title: String = m["title"]
		if state == "active":
			title = "[ACTIVE]  " + title
		elif state == "done":
			title = "[COMPLETE]  " + title
		var body: String = m["desc"]
		if hunt and state == "active":
			body += "  Raiders left: %d." % m["left"]
		var v := _text_block(h, title, body)
		v.add_child(_label("REWARD  %s CR" % _fmt(m["reward"]), 17, UiKit.GOLD, UiKit.display(700)))
		if state == "offered":
			_btn(h, "ACCEPT", _do_accept.bind(m, col))


func _build_market() -> void:
	_heading("MARKET", "Buy low, sell where it's needed. Prices differ in every station.")
	# cargo hold bar
	var c := _card(UiKit.ACCENT)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 46)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func():
		var w := bar.size.x
		var cap := GameState.cargo_capacity()
		bar.draw_string(UiKit.display(700), Vector2(0, 16), "CARGO HOLD  %d / %d" % [GameState.cargo_used(), cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
		var x := 0.0
		bar.draw_rect(Rect2(0, 26, w, 14), Color(1, 1, 1, 0.06))
		for id in Galaxy.COMMODITIES:
			var n: int = GameState.cargo.get(id, 0)
			if n > 0:
				var seg := w * n / cap
				bar.draw_rect(Rect2(x, 26, seg - 2, 14), Galaxy.COMMODITIES[id]["color"])
				x += seg
		for i in range(1, cap):
			bar.draw_line(Vector2(w * i / cap, 26), Vector2(w * i / cap, 40), Color(0, 0, 0, 0.35), 1.0))
	c[1].add_child(bar)

	for id in Galaxy.COMMODITIES:
		var info: Dictionary = Galaxy.COMMODITIES[id]
		var price := GameState.price(station.station_id, id)
		var held: int = GameState.cargo.get(id, 0)
		var avg := 0.0
		var cnt := 0
		for sid in Galaxy.SYSTEMS:
			for st in Galaxy.SYSTEMS[sid]["stations"]:
				avg += float(st["prices"][id])
				cnt += 1
		avg /= cnt
		var mult: float = Galaxy.station(station.station_id)["prices"][id]
		var tag := "FAIR"
		var tag_col := UiKit.TEXT_DIM
		if mult < avg * 0.88:
			tag = "CHEAP HERE"
			tag_col = UiKit.GOOD
		elif mult > avg * 1.1:
			tag = "IN DEMAND"
			tag_col = UiKit.GOLD
		var row := _card(info["color"])
		var h: HBoxContainer = row[1]
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		top.add_child(_label(info["name"].to_upper(), 19, Color(1, 1, 1), UiKit.display(700)))
		top.add_child(_label("  " + tag, 14, tag_col, UiKit.display(700)))
		v.add_child(top)
		v.add_child(_label("%s CR / unit     In hold: %d" % [_fmt(price), held], 17, UiKit.GOLD, UiKit.body(600)))
		var best := Galaxy.best_sell(id)
		if best["station"] != station.station_id:
			v.add_child(_label("Best market: %s, %s (%s cr)" % [best["name"], best["system"], _fmt(int(round(info["base"] * best["mult"])))], 14, UiKit.TEXT_DIM, UiKit.body(500)))
		h.add_child(v)
		_btn(h, "BUY 1", func(b): _buy(b, id, 1), false, 104)
		_btn(h, "BUY 5", func(b): _buy(b, id, 5), false, 104)
		_btn(h, "MAX", func(b): _buy(b, id, 999), false, 92)
		_btn(h, "SELL ALL", func(b): _sell(b, id), held == 0, 130)


func _buy(b: Control, id: String, n: int) -> void:
	var before := GameState.credits
	var got := GameState.buy(station.station_id, id, n)
	if got == 0:
		_deny(b)
		GameState.message.emit("Not enough credits or cargo space", UiKit.BAD)
		return
	world.sfx.play("ui_buy", -4.0, 0.9)
	_money(GameState.credits - before)
	_sparkle(b, Galaxy.COMMODITIES[id]["color"])
	_rebuild_keep_scroll()


func _sell(b: Control, id: String) -> void:
	var total := GameState.sell(station.station_id, id)
	if total <= 0:
		_deny(b)
		return
	world.sfx.play("ui_buy", -2.0, 1.12)
	_money(total)
	_sparkle(b, UiKit.GOLD)
	_rebuild_keep_scroll()


func _rebuild_keep_scroll() -> void:
	var sc := _scroll.scroll_vertical
	# rebuild without the slide-in animation so rapid buying feels snappy
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match _tab:
		"market":
			_build_market()
		"shipyard":
			_build_shipyard()
		"services":
			_build_services()
	await get_tree().process_frame
	for c in _content.get_children():
		c.modulate.a = 1.0
		c.scale = Vector2.ONE
	_scroll.scroll_vertical = sc


func _build_shipyard() -> void:
	_heading("SHIPYARD", "Every upgrade is permanent. No shortcuts, just credits earned the hard way.")
	# rotating ship preview + stats
	var c := _card(UiKit.ACCENT)
	var h: HBoxContainer = c[1]
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(320, 190)
	svc.stretch = true
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 190)
	vp.transparent_bg = true
	vp.own_world_3d = true
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 4.5, 13)
	cam.fov = 40
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 0.5), Vector3.UP)
	var ship := MeshInstance3D.new()
	ship.mesh = Models.player_ship()
	vp.add_child(ship)
	_preview_ship = ship
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	vp.add_child(key)
	key.look_at_from_position(Vector3(5, 6, 4), Vector3.ZERO, Vector3.UP)
	var rim := DirectionalLight3D.new()
	rim.light_color = station.accent
	rim.light_energy = 1.4
	vp.add_child(rim)
	rim.look_at_from_position(Vector3(-4, 2, -6), Vector3.ZERO, Vector3.UP)
	var penv := Environment.new()
	penv.background_mode = Environment.BG_CLEAR_COLOR
	penv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	penv.ambient_light_color = Color(0.35, 0.4, 0.5)
	penv.glow_enabled = true
	penv.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = penv
	vp.add_child(we)
	h.add_child(svc)
	_preview = vp
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(_label("STARLANE MK-I INTERCEPTOR", 18, Color(1, 1, 1), UiKit.display(800, 2)))
	for s in [["TOP SPEED", "%d m/s" % int(GameState.top_speed())], ["SHIELD", "%d" % int(GameState.max_shield())],
			["LASER DMG", "%.1f" % GameState.laser_damage()], ["CARGO", "%d units" % GameState.cargo_capacity()],
			["JUMP CHARGES", "%d" % GameState.max_jump_charges()]]:
		var r := HBoxContainer.new()
		var l := _label(s[0], 14, UiKit.TEXT_DIM, UiKit.display(600))
		l.custom_minimum_size = Vector2(150, 0)
		r.add_child(l)
		r.add_child(_label(s[1], 17, UiKit.ACCENT, UiKit.display(700)))
		stats.add_child(r)
	h.add_child(stats)

	for id in GameState.UPGRADES:
		var info: Dictionary = GameState.UPGRADES[id]
		var lvl: int = GameState.upgrades[id]
		var maxed: bool = lvl >= info["max"]
		var cost: int = 0 if maxed else info["cost"][lvl]
		var card := _card(UiKit.ACCENT)
		var ch: HBoxContainer = card[1]
		var v := _text_block(ch, info["name"].to_upper(), info["desc"])
		var pips := Control.new()
		pips.custom_minimum_size = Vector2(0, 16)
		var mx: int = info["max"]
		pips.draw.connect(func():
			for i in mx:
				var r := Rect2(Vector2(i * 46, 2), Vector2(40, 10))
				pips.draw_rect(r, UiKit.ACCENT if i < lvl else Color(UiKit.ACCENT, 0.15))
				if i < lvl:
					pips.draw_rect(r.grow(2), Color(UiKit.ACCENT, 0.15)))
		v.add_child(pips)
		var label := "MAXED" if maxed else "%s CR" % _fmt(cost)
		_btn(ch, label, _do_upgrade.bind(id), maxed, 170)


func _do_accept(b: Control, m: Dictionary, col: Color) -> void:
	GameState.accept(m)
	world.sfx.ui("upgrade")
	_sparkle(b, col)
	GameState.message.emit("Contract accepted: " + m["title"], UiKit.GOOD)
	_rebuild()


func _do_upgrade(b: Control, id: String) -> void:
	var before := GameState.credits
	if GameState.upgrade(id):
		world.sfx.ui("upgrade")
		_money(GameState.credits - before)
		_sparkle(b, UiKit.ACCENT)
		GameState.message.emit("%s upgraded to Mk %d" % [GameState.UPGRADES[id]["name"], GameState.upgrades[id]], UiKit.GOOD)
		_rebuild_keep_scroll()
	else:
		_deny(b)


func _do_repair(b: Control) -> void:
	var before := GameState.credits
	if GameState.repair():
		world.sfx.play("dock_clamp", -6.0, 1.3)
		_money(GameState.credits - before)
		_sparkle(b, Color(1, 0.6, 0.25))
		_rebuild_keep_scroll()
	else:
		_deny(b)


func _do_refuel(b: Control) -> void:
	var before := GameState.credits
	if GameState.refuel():
		world.sfx.ui("upgrade")
		_money(GameState.credits - before)
		_sparkle(b, UiKit.ACCENT)
		_rebuild_keep_scroll()
	else:
		_deny(b)


func _build_services() -> void:
	_heading("SERVICES", "Repairs and jump capacitor refuelling.")
	var c := _card(Color(1, 0.6, 0.25))
	var h: HBoxContainer = c[1]
	var cost := GameState.repair_cost()
	_text_block(h, "HULL INTEGRITY  %d%%" % int(GameState.hull), "Full repair: %s cr" % _fmt(cost) if cost > 0 else "Your ship is in perfect shape.")
	_btn(h, "REPAIR", _do_repair, cost <= 0, 170)

	var c2 := _card(UiKit.ACCENT)
	var h2: HBoxContainer = c2[1]
	var missing := GameState.max_jump_charges() - GameState.jump_charges
	_text_block(h2, "JUMP CAPACITORS  %d / %d" % [GameState.jump_charges, GameState.max_jump_charges()],
		"Each stargate hop uses one charge. Refill: %d cr per charge." % GameState.JUMP_CELL_PRICE)
	_btn(h2, "REFUEL" if missing > 0 else "FULL", _do_refuel, missing <= 0, 170)

	var c3 := _card(UiKit.TEXT_DIM)
	var v3 := _text_block(c3[1], "PILOT RECORD", "")
	var visited := 0
	for k in GameState.visited:
		visited += 1
	v3.add_child(_label("Raiders destroyed: %d      Systems visited: %d / %d" % [GameState.kills, visited, Galaxy.SYSTEMS.size()], 17, UiKit.TEXT_DIM, UiKit.body(500)))
