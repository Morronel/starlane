class_name StationMenu
extends Control
## Docked station screen. Tabs: contracts, market, hangar, outfit, workshop, services.
## Built for touch: big targets, animated feedback, satisfying sounds.

signal launch_pressed
signal map_pressed
signal settings_pressed

var station: Station
var world: Node
var _tab := "missions"
var _content: VBoxContainer
var _scroll: KineticScroll
var _inspect := ""          # ship shown in the hangar preview
var _confirm := {}          # button key -> msec deadline for two-tap purchases
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
	["hangar", "HANGAR", "hangar"],
	["outfit", "OUTFIT", "bolt"],
	["workshop", "WORKSHOP", "blueprint"],
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
	rail.add_theme_constant_override("separation", 7)
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
	_scroll = KineticScroll.new()
	_scroll.is_active = func(): return not (world.star_map.visible or world.settings_panel.visible)
	panel.add_child(_scroll)
	_content = _scroll.content

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
	launch.position = Vector2(22, h - 96)
	launch.size = Vector2(rail_w, 76)
	var panel: Control = get_node("ContentPanel")
	panel.position = Vector2(rail_w + 44, 130)
	panel.size = Vector2(w - rail_w - 66, h - 152)


# --- widgets -------------------------------------------------------------------

func _rail_button(label: String, icon_name: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(250, 58)
	b.text = ""
	b.add_theme_stylebox_override("normal", UiKit.box(Color(0.04, 0.08, 0.14, 0.85), Color(UiKit.ACCENT, 0.2), 6))
	b.add_theme_stylebox_override("hover", UiKit.box(Color(0.06, 0.12, 0.2, 0.9), Color(UiKit.ACCENT, 0.5), 6))
	b.add_theme_stylebox_override("pressed", UiKit.box(Color(0.08, 0.22, 0.34, 0.95), Color(UiKit.ACCENT, 0.9), 6, 2))
	b.add_theme_stylebox_override("hover_pressed", UiKit.box(Color(0.08, 0.22, 0.34, 0.95), Color(UiKit.ACCENT, 0.9), 6, 2))
	b.draw.connect(func():
		var on := b.button_pressed
		var col := Color(1, 1, 1) if on else Color(UiKit.TEXT_DIM, 0.9)
		UiKit.icon(b, icon_name, Vector2(36, b.size.y * 0.5), 28, UiKit.ACCENT if on else col, 2.2)
		b.draw_string(UiKit.display(700, 2), Vector2(68, b.size.y * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
		if on:
			b.draw_rect(Rect2(Vector2(0, 8), Vector2(4, b.size.y - 16)), UiKit.ACCENT))
	b.pressed.connect(func(): UiKit.pop(b))
	return b


func _icon_button(icon_name: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 52)
	b.draw.connect(func(): UiKit.icon(b, icon_name, b.size * 0.5, 28, UiKit.ACCENT, 2.2))
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
	_build_tab()


func _build_tab() -> void:
	match _tab:
		"missions":
			_build_missions()
		"market":
			_build_market()
		"hangar":
			_build_hangar()
		"outfit":
			_build_outfit()
		"workshop":
			_build_workshop()
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
	h.draw_rect(Rect2(bx + 46, 75, 90 * GameState.hull / GameState.max_hull(), 8), Color(1, 0.6, 0.25))
	h.draw_string(UiKit.display(600), Vector2(bx + 150, 84), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiKit.TEXT_DIM)
	for i in GameState.max_jump_charges():
		var on := i < GameState.jump_charges
		var c := Vector2(bx + 200 + i * 18, 79)
		if on:
			h.draw_circle(c, 6, UiKit.ACCENT)
		else:
			h.draw_arc(c, 6, 0, TAU, 16, Color(UiKit.ACCENT, 0.4), 1.5, true)
	var cargo := "CARGO %d / %d   ·   %s" % [GameState.cargo_used(), GameState.cargo_capacity(), Items.SHIPS[GameState.ship]["name"].to_upper()]
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
		var tracked: bool = GameState.destination.get("type", "") == "mission" and int(GameState.destination["id"]) == m["id"]
		if tracked and state == "active":
			title = title.replace("[ACTIVE]", "[TRACKED]")
		var v := _text_block(h, title, body)
		v.add_child(_label("REWARD  %s CR" % _fmt(m["reward"]), 17, UiKit.GOLD, UiKit.display(700)))
		if state == "offered":
			_btn(h, "ACCEPT", _do_accept.bind(m, col))
		elif state == "active" or state == "done":
			_btn(h, "TRACKING" if tracked else "TRACK", _do_track.bind(m), tracked, 150)


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

	# salvage parts: some stations sell them, every station buys them
	var sold_parts: Array = Galaxy.station(station.station_id).get("parts", [])
	_content.add_child(_label("SALVAGE PARTS", 18, UiKit.ACCENT, UiKit.display(700, 2)))
	for pid in Items.PARTS:
		var pinfo: Dictionary = Items.PARTS[pid]
		var have: int = GameState.parts.get(pid, 0)
		if not (pid in sold_parts) and have == 0:
			continue
		var prow := _card(pinfo["color"])
		var ph: HBoxContainer = prow[1]
		var pv := VBoxContainer.new()
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv.add_theme_constant_override("separation", 2)
		pv.add_child(_label(pinfo["name"].to_upper(), 18, Color(1, 1, 1), UiKit.display(700)))
		var line := "In locker: %d     Sells for %d cr" % [have, int(pinfo["price"] * 0.6)]
		if pid in sold_parts:
			line = "%s CR / unit     " % _fmt(GameState.part_price(station.station_id, pid)) + line
		pv.add_child(_label(line, 16, UiKit.GOLD, UiKit.body(600)))
		ph.add_child(pv)
		if pid in sold_parts:
			_btn(ph, "BUY 1", func(b): _buy_part(b, pid, 1), false, 104)
			_btn(ph, "BUY 5", func(b): _buy_part(b, pid, 5), false, 104)
		_btn(ph, "SELL 1", func(b): _sell_part(b, pid), have == 0, 110)


func _buy_part(b: Control, pid: String, n: int) -> void:
	var before := GameState.credits
	if GameState.buy_part(station.station_id, pid, n) <= 0:
		_deny(b)
		return
	world.sfx.play("ui_buy", -4.0, 0.9)
	_money(GameState.credits - before)
	_sparkle(b, Items.PARTS[pid]["color"])
	_rebuild_keep_scroll.call_deferred()


func _sell_part(b: Control, pid: String) -> void:
	var v := GameState.sell_part(pid, 1)
	if v <= 0:
		_deny(b)
		return
	world.sfx.play("ui_buy", -3.0, 1.12)
	_money(v)
	_sparkle(b, UiKit.GOLD)
	_rebuild_keep_scroll.call_deferred()


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
	_rebuild_keep_scroll.call_deferred()


func _sell(b: Control, id: String) -> void:
	var total := GameState.sell(station.station_id, id)
	if total <= 0:
		_deny(b)
		return
	world.sfx.play("ui_buy", -2.0, 1.12)
	_money(total)
	_sparkle(b, UiKit.GOLD)
	_rebuild_keep_scroll.call_deferred()


func _rebuild_keep_scroll() -> void:
	var sc := _scroll.scroll_vertical
	# rebuild without the slide-in animation so rapid buying feels snappy
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_preview_ship = null
	_build_tab()
	await get_tree().process_frame
	for c in _content.get_children():
		c.modulate.a = 1.0
		c.scale = Vector2.ONE
	_scroll.scroll_vertical = sc


# --- hangar ---------------------------------------------------------------------

func _preview_box(ship_id: String, w := 340, h := 200) -> SubViewportContainer:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(w, h)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_PASS
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = true
	vp.own_world_3d = true
	svc.add_child(vp)
	var sz := Models.ship_size(ship_id)
	var cam := Camera3D.new()
	cam.fov = 40
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.5, 13) * sz, Vector3(0, 0, 0.5), Vector3.UP)
	var ship := MeshInstance3D.new()
	ship.mesh = Models.ship(ship_id)
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
	_preview = vp
	return svc


func _stat_row(parent: Control, label: String, value: String, delta := 0.0) -> void:
	var r := HBoxContainer.new()
	var l := _label(label, 14, UiKit.TEXT_DIM, UiKit.display(600))
	l.custom_minimum_size = Vector2(130, 0)
	r.add_child(l)
	r.add_child(_label(value, 17, UiKit.ACCENT, UiKit.display(700)))
	if absf(delta) > 0.01:
		r.add_child(_label(("  +%s" if delta > 0 else "  %s") % str(int(delta)), 15, UiKit.GOOD if delta > 0 else UiKit.BAD, UiKit.display(700)))
	parent.add_child(r)


func _slots_text(info: Dictionary) -> String:
	var sl: Dictionary = info["slots"]
	return "%d primary · %d secondary · %d utility" % [sl["primary"], sl["secondary"], sl["utility"]]


## Two-tap confirm for big purchases. Returns true when the second tap lands.
func _confirmed(b: Button, key: String, text: String) -> bool:
	var now := Time.get_ticks_msec()
	if _confirm.get(key, 0) > now:
		_confirm.erase(key)
		return true
	_confirm[key] = now + 3000
	b.text = text
	world.sfx.ui("tab")
	return false


func _build_hangar() -> void:
	var stock: Array = Galaxy.station(station.station_id).get("ships", [])
	_heading("HANGAR", "Trade in your ship for a new hull. Your gear moves over where it fits; the rest goes to your locker.")
	if _inspect == "" or not (_inspect in stock or _inspect == GameState.ship):
		_inspect = GameState.ship
	var cur: Dictionary = Items.SHIPS[GameState.ship]
	var ins: Dictionary = Items.SHIPS[_inspect]
	var c := _card(station.accent)
	var h: HBoxContainer = c[1]
	h.add_child(_preview_box(_inspect))
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("separation", 3)
	var mine := _inspect == GameState.ship
	stats.add_child(_label(ins["name"].to_upper() + ("   (YOUR SHIP)" if mine else ""), 20, Color(1, 1, 1), UiKit.display(800, 2)))
	stats.add_child(_label(ins["role"], 15, station.accent, UiKit.display(600)))
	stats.add_child(_label(ins["desc"], 15, UiKit.TEXT_DIM, UiKit.body(500), true))
	_stat_row(stats, "HULL", "%d" % ins["hull"], 0.0 if mine else float(ins["hull"] - cur["hull"]))
	_stat_row(stats, "TOP SPEED", "%d m/s" % ins["speed"], 0.0 if mine else float(ins["speed"] - cur["speed"]))
	_stat_row(stats, "CARGO", "%d" % ins["cargo"], 0.0 if mine else float(ins["cargo"] - cur["cargo"]))
	_stat_row(stats, "HANDLING", "%d%%" % int(ins["turn"] * 100), 0.0 if mine else (ins["turn"] - cur["turn"]) * 100.0)
	stats.add_child(_label(_slots_text(ins), 15, UiKit.GOLD, UiKit.body(600)))
	h.add_child(stats)

	if stock.is_empty():
		var c2 := _card(UiKit.TEXT_DIM)
		var yards := []
		for sid in Galaxy.SYSTEMS:
			for st in Galaxy.SYSTEMS[sid]["stations"]:
				if st.has("ships"):
					yards.append("%s (%s)" % [st["name"], Galaxy.SYSTEMS[sid]["name"]])
		_text_block(c2[1], "NO SHIPYARD HERE", "Ships are sold at: " + ", ".join(yards) + ".")
		return
	_content.add_child(_label("SHIPS FOR SALE", 18, UiKit.ACCENT, UiKit.display(700, 2)))
	for id in stock:
		var info: Dictionary = Items.SHIPS[id]
		var card := _card(UiKit.GOLD if id == GameState.ship else station.accent)
		var ch: HBoxContainer = card[1]
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(48, 48)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.draw.connect(func(): UiKit.icon(ic, "ship", Vector2(24, 24), 40, station.accent, 2.2))
		ch.add_child(ic)
		var body := "Hull %d · %d m/s · Cargo %d · %s" % [info["hull"], info["speed"], info["cargo"], _slots_text(info)]
		var v := _text_block(ch, "%s  ·  %s" % [info["name"].to_upper(), info["role"]], body)
		if id == GameState.ship:
			v.add_child(_label("CURRENT SHIP", 16, UiKit.GOLD, UiKit.display(700)))
			_btn(ch, "INSPECT", _do_inspect.bind(id), id == _inspect, 130)
			continue
		var net := GameState.ship_cost(id)
		v.add_child(_label("%s CR   (trade-in %s cr)" % [_fmt(info["price"]), _fmt(Items.ship_trade_in(GameState.ship))], 16, UiKit.GOLD, UiKit.display(700)))
		_btn(ch, "INSPECT", _do_inspect.bind(id), id == _inspect, 130)
		_btn(ch, ("BUY  %s" % _fmt(net)) if net > 0 else ("SWAP  +%s" % _fmt(-net)), _do_buy_ship.bind(id), false, 190)


func _do_inspect(_b: Control, id: String) -> void:
	_inspect = id
	world.sfx.ui("tab")
	_rebuild_keep_scroll.call_deferred()


func _do_buy_ship(b: Button, id: String) -> void:
	if GameState.credits < GameState.ship_cost(id):
		_deny(b)
		GameState.message.emit("Not enough credits", UiKit.BAD)
		return
	if not _confirmed(b, "ship_" + id, "TAP TO CONFIRM"):
		return
	var before := GameState.credits
	if GameState.buy_ship(id):
		world.player.refresh_ship()
		world.sfx.ui("upgrade")
		world.sfx.play("dock_clamp", -6.0, 0.8)
		_money(GameState.credits - before)
		_sparkle(b, UiKit.GOLD)
		_inspect = id
		GameState.message.emit("Welcome aboard your new %s!" % Items.SHIPS[id]["name"], UiKit.GOOD)
		GameState.save_game()
		_rebuild_keep_scroll.call_deferred()
	else:
		_deny(b)


# --- outfit ----------------------------------------------------------------------

func _gear_icon(slot: String) -> String:
	return {"primary": "target", "secondary": "launch", "utility": "shield"}[slot]


func _gear_color(gear_id: String) -> Color:
	var g: Dictionary = Items.GEAR[gear_id]
	if g.get("unique", false):
		return Color(0.85, 0.6, 1.0)
	return {"primary": Color(1.0, 0.55, 0.45), "secondary": Color(1.0, 0.75, 0.35), "utility": UiKit.ACCENT}[g["slot"]]


func _gear_card(gear_id: String, accent: Color) -> HBoxContainer:
	var card := _card(accent)
	var ch: HBoxContainer = card[1]
	var g: Dictionary = Items.GEAR[gear_id]
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(44, 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var slot: String = g["slot"]
	ic.draw.connect(func(): UiKit.icon(ic, _gear_icon(slot), Vector2(22, 22), 36, accent, 2.2))
	ch.add_child(ic)
	var title: String = g["name"].to_upper() + ("   ·  UNIQUE" if g.get("unique", false) else "")
	var body: String = Items.gear_stats(gear_id)
	if g["slot"] != "utility":
		body += "\n" + g["desc"]
	_text_block(ch, title, body)
	return ch


func _build_outfit() -> void:
	_heading("OUTFIT", "Install weapons and systems. Removed gear goes to your locker and travels with you.")
	var c := _card(UiKit.ACCENT)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label("%s LOADOUT" % Items.SHIPS[GameState.ship]["name"].to_upper(), 18, Color(1, 1, 1), UiKit.display(800, 2)))
	v.add_child(_label("Firepower %d DPS   ·   Shield %d   ·   Hull %d   ·   Speed %d m/s   ·   Cargo %d   ·   Jumps %d" % [
		int(GameState.firepower()), int(GameState.max_shield()), int(GameState.max_hull()), int(GameState.top_speed()),
		GameState.cargo_capacity(), GameState.max_jump_charges()], 16, UiKit.ACCENT, UiKit.body(600), true))
	c[1].add_child(v)

	for slot in ["primary", "secondary", "utility"]:
		var arr: Array = GameState.equip[slot]
		_content.add_child(_label("%s  (%d / %d)" % [Items.slot_label(slot), GameState.installed(slot).size(), arr.size()], 17, UiKit.ACCENT, UiKit.display(700, 2)))
		for i in arr.size():
			if arr[i] == "":
				var e := _card(Color(1, 1, 1, 0.25))
				_text_block(e[1], "EMPTY SLOT", "Install something from your locker or buy it below.", UiKit.TEXT_DIM)
				continue
			var ch := _gear_card(arr[i], _gear_color(arr[i]))
			_btn(ch, "REMOVE", _do_uninstall.bind(slot, i), false, 130)

	_content.add_child(_label("LOCKER  (%d)" % GameState.storage.size(), 17, UiKit.ACCENT, UiKit.display(700, 2)))
	if GameState.storage.is_empty():
		var e2 := _card(Color(1, 1, 1, 0.2))
		_text_block(e2[1], "Locker is empty", "Crafted items and removed gear end up here.", UiKit.TEXT_DIM)
	for i in GameState.storage.size():
		var gid: String = GameState.storage[i]
		var ch2 := _gear_card(gid, _gear_color(gid))
		_btn(ch2, "INSTALL", _do_install.bind(i), GameState.free_slot(Items.GEAR[gid]["slot"]) < 0, 130)
		_btn(ch2, "SELL %s" % _fmt(Items.sell_value(gid)), _do_sell_gear.bind(i), false, 150)

	var sold: Array = Galaxy.station(station.station_id).get("gear", [])
	_content.add_child(_label("FOR SALE AT %s" % station.display_name.to_upper(), 17, UiKit.ACCENT, UiKit.display(700, 2)))
	if sold.is_empty():
		var e3 := _card(Color(1, 1, 1, 0.2))
		_text_block(e3[1], "No outfitter here", "Try a trade hub, fortress or shipyard.", UiKit.TEXT_DIM)
	for gid in sold:
		var g: Dictionary = Items.GEAR[gid]
		var ch3 := _gear_card(gid, _gear_color(gid))
		_btn(ch3, "BUY  %s" % _fmt(g["price"]), _do_buy_gear.bind(gid), false, 180)
	# ammo for installed launchers
	var kinds := {}
	for gid in GameState.installed("secondary"):
		kinds[Items.GEAR[gid]["ammo"]] = true
	for kind in kinds:
		var a: Dictionary = Items.AMMO[kind]
		var ca := _card(Color(1.0, 0.75, 0.35))
		_text_block(ca[1], "%s  ·  %d IN RACKS" % [a["name"].to_upper(), GameState.ammo.get(kind, 0)], "%d cr each" % a["price"])
		_btn(ca[1], "BUY 5", _do_buy_ammo.bind(kind, 5), false, 110)
		_btn(ca[1], "BUY 20", _do_buy_ammo.bind(kind, 20), false, 120)


func _do_uninstall(b: Control, slot: String, i: int) -> void:
	if GameState.uninstall(slot, i):
		world.sfx.play("equip", -4.0, 0.85)
		_sparkle(b, UiKit.TEXT_DIM)
		world.player.shield = minf(world.player.shield, GameState.max_shield())
		_rebuild_keep_scroll.call_deferred()
	else:
		_deny(b)


func _do_install(b: Control, i: int) -> void:
	if GameState.install(i):
		world.sfx.play("equip", -3.0)
		_sparkle(b, UiKit.ACCENT)
		world.player.shield = GameState.max_shield()
		_rebuild_keep_scroll.call_deferred()
	else:
		_deny(b)
		GameState.message.emit("No free slot of that type. Remove something first.", UiKit.BAD)


func _do_sell_gear(b: Button, i: int) -> void:
	if not _confirmed(b, "sell_%d_%s" % [i, GameState.storage[i]], "CONFIRM SELL"):
		return
	var v := GameState.sell_stored(i)
	if v > 0:
		world.sfx.play("ui_buy", -2.0, 1.12)
		_money(v)
		_sparkle(b, UiKit.GOLD)
		_rebuild_keep_scroll.call_deferred()


func _do_buy_gear(b: Control, gid: String) -> void:
	var before := GameState.credits
	var r := GameState.buy_gear(gid)
	if r == "":
		_deny(b)
		GameState.message.emit("Not enough credits", UiKit.BAD)
		return
	world.sfx.play("equip" if r == "installed" else "ui_buy", -3.0)
	world.sfx.ui("upgrade")
	_money(GameState.credits - before)
	_sparkle(b, _gear_color(gid))
	world.player.shield = GameState.max_shield()
	GameState.message.emit("%s %s" % [Items.GEAR[gid]["name"], "installed" if r == "installed" else "sent to your locker"], UiKit.GOOD)
	_rebuild_keep_scroll.call_deferred()


func _do_buy_ammo(b: Control, kind: String, n: int) -> void:
	var before := GameState.credits
	if GameState.buy_ammo(kind, n) > 0:
		world.sfx.play("ui_buy", -4.0, 0.95)
		_money(GameState.credits - before)
		_sparkle(b, Color(1.0, 0.75, 0.35))
		_rebuild_keep_scroll.call_deferred()
	else:
		_deny(b)


# --- workshop ------------------------------------------------------------------------

func _chip(parent: Control, text: String, col: Color, filled := false) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(Color(col, 0.22 if filled else 0.08), Color(col, 0.7), 12, 1, 8))
	p.add_child(_label(text, 14, col.lerp(Color(1, 1, 1), 0.35), UiKit.display(700)))
	parent.add_child(p)


func _build_workshop() -> void:
	_heading("WORKSHOP", "Assemble blueprints from salvage. Wrecked raiders, salvage drifts in asteroid fields and some markets supply parts.")
	var c := _card(Color(0.85, 0.6, 1.0))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label("PARTS LOCKER", 17, Color(1, 1, 1), UiKit.display(800, 2)))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for pid in Items.PARTS:
		_chip(chips, "%s  %d" % [Items.PARTS[pid]["name"].to_upper(), GameState.parts.get(pid, 0)], Items.PARTS[pid]["color"], GameState.parts.get(pid, 0) > 0)
	v.add_child(chips)
	c[1].add_child(v)

	var sold: Array = Galaxy.station(station.station_id).get("blueprints", [])
	for bp in sold:
		if GameState.blueprints.has(bp):
			continue
		var cb := _card(Color(0.85, 0.6, 1.0))
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(44, 44)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.draw.connect(func(): UiKit.icon(ic, "blueprint", Vector2(22, 22), 36, Color(0.85, 0.6, 1.0), 2.0))
		cb[1].add_child(ic)
		_text_block(cb[1], "BLUEPRINT DATA: %s" % Items.blueprint_name(bp).to_upper(), "Decrypted schematics for sale. Unlocks a unique item you can assemble here.")
		_btn(cb[1], "%s CR" % _fmt(Items.BLUEPRINTS[bp]["price"]), _do_buy_bp.bind(bp), false, 150)

	_content.add_child(_label("BLUEPRINTS", 17, UiKit.ACCENT, UiKit.display(700, 2)))
	var unknown := 0
	for bp in Items.BLUEPRINTS:
		if not GameState.blueprints.has(bp):
			unknown += 1
			continue
		var info: Dictionary = Items.BLUEPRINTS[bp]
		var mk: String = info["makes"]
		var col := Color(0.85, 0.6, 1.0) if not mk.begins_with("ammo:") and Items.GEAR[mk].get("unique", false) else UiKit.ACCENT
		var card := _card(col)
		var ch: HBoxContainer = card[1]
		var ic2 := Control.new()
		ic2.custom_minimum_size = Vector2(44, 44)
		ic2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic2.draw.connect(func(): UiKit.icon(ic2, "blueprint", Vector2(22, 22), 36, col, 2.0))
		ch.add_child(ic2)
		var desc := "Ammunition for your launchers." if mk.begins_with("ammo:") else Items.gear_stats(mk)
		var vb := _text_block(ch, Items.blueprint_name(bp).to_upper(), desc)
		var recipe := HFlowContainer.new()
		recipe.add_theme_constant_override("h_separation", 6)
		recipe.add_theme_constant_override("v_separation", 6)
		for pid in info["parts"]:
			var need: int = info["parts"][pid]
			var have: int = GameState.parts.get(pid, 0)
			_chip(recipe, "%s %d/%d" % [Items.PARTS[pid]["name"], have, need], UiKit.GOOD if have >= need else UiKit.BAD, have >= need)
		if info["fee"] > 0:
			_chip(recipe, "FEE %s CR" % _fmt(info["fee"]), UiKit.GOLD if GameState.credits >= info["fee"] else UiKit.BAD)
		vb.add_child(recipe)
		_btn(ch, "ASSEMBLE", _do_craft.bind(bp), not GameState.can_craft(bp), 160)
	if unknown > 0:
		var cu := _card(Color(1, 1, 1, 0.25))
		_text_block(cu[1], "%d ENCRYPTED BLUEPRINT%s" % [unknown, "" if unknown == 1 else "S"],
			"Unique designs are recovered from elite raiders or bought at research stations.", UiKit.TEXT_DIM)


func _do_craft(b: Control, bp: String) -> void:
	var before := GameState.credits
	var made := GameState.craft(bp)
	if made == "":
		_deny(b)
		return
	world.sfx.play("craft", -2.0)
	_money(GameState.credits - before)
	_sparkle(b, Color(0.85, 0.6, 1.0))
	_sparkle(b, UiKit.GOLD)
	_popup("ASSEMBLED", Color(0.85, 0.6, 1.0))
	GameState.message.emit("Assembled: %s%s" % [made, "" if Items.BLUEPRINTS[bp]["makes"].begins_with("ammo:") else " (in your locker)"], Color(0.85, 0.6, 1.0))
	_rebuild_keep_scroll.call_deferred()


func _do_buy_bp(b: Control, bp: String) -> void:
	var before := GameState.credits
	if GameState.buy_blueprint(bp):
		world.sfx.ui("upgrade")
		_money(GameState.credits - before)
		_sparkle(b, Color(0.85, 0.6, 1.0))
		GameState.message.emit("Blueprint unlocked: " + Items.blueprint_name(bp), Color(0.85, 0.6, 1.0))
		_rebuild_keep_scroll.call_deferred()
	else:
		_deny(b)


func _do_track(b: Control, m: Dictionary) -> void:
	GameState.set_destination("mission", m["id"])
	world.sfx.ui("tab")
	_sparkle(b, UiKit.GOLD)
	GameState.message.emit("Tracking: " + m["title"], UiKit.GOLD)
	_rebuild_keep_scroll.call_deferred()


func _do_accept(b: Control, m: Dictionary, col: Color) -> void:
	GameState.accept(m)
	world.sfx.ui("upgrade")
	_sparkle(b, col)
	GameState.message.emit("Contract accepted: " + m["title"], UiKit.GOOD)
	_rebuild.call_deferred()


func _do_repair(b: Control) -> void:
	var before := GameState.credits
	if GameState.repair():
		world.sfx.play("dock_clamp", -6.0, 1.3)
		_money(GameState.credits - before)
		_sparkle(b, Color(1, 0.6, 0.25))
		_rebuild_keep_scroll.call_deferred()
	else:
		_deny(b)


func _do_refuel(b: Control) -> void:
	var before := GameState.credits
	if GameState.refuel():
		world.sfx.ui("upgrade")
		_money(GameState.credits - before)
		_sparkle(b, UiKit.ACCENT)
		_rebuild_keep_scroll.call_deferred()
	else:
		_deny(b)


func _build_services() -> void:
	_heading("SERVICES", "Repairs, jump capacitor refuelling and munitions.")
	var c := _card(Color(1, 0.6, 0.25))
	var h: HBoxContainer = c[1]
	var cost := GameState.repair_cost()
	_text_block(h, "HULL  %d / %d" % [int(GameState.hull), int(GameState.max_hull())], "Full repair: %s cr" % _fmt(cost) if cost > 0 else "Your ship is in perfect shape.")
	_btn(h, "REPAIR", _do_repair, cost <= 0, 170)

	var c2 := _card(UiKit.ACCENT)
	var h2: HBoxContainer = c2[1]
	var missing := GameState.max_jump_charges() - GameState.jump_charges
	_text_block(h2, "JUMP CAPACITORS  %d / %d" % [GameState.jump_charges, GameState.max_jump_charges()],
		"Each stargate hop uses one charge. Refill: %d cr per charge." % GameState.JUMP_CELL_PRICE)
	_btn(h2, "REFUEL" if missing > 0 else "FULL", _do_refuel, missing <= 0, 170)

	var kinds := {}
	for gid in GameState.installed("secondary"):
		kinds[Items.GEAR[gid]["ammo"]] = true
	for kind in kinds:
		var a: Dictionary = Items.AMMO[kind]
		var ca := _card(Color(1.0, 0.75, 0.35))
		_text_block(ca[1], "%s  ·  %d IN RACKS" % [a["name"].to_upper(), GameState.ammo.get(kind, 0)], "%d cr each" % a["price"])
		_btn(ca[1], "BUY 5", _do_buy_ammo.bind(kind, 5), false, 110)
		_btn(ca[1], "BUY 20", _do_buy_ammo.bind(kind, 20), false, 120)

	var c3 := _card(UiKit.TEXT_DIM)
	var v3 := _text_block(c3[1], "PILOT RECORD", "")
	var visited := 0
	for k in GameState.visited:
		visited += 1
	v3.add_child(_label("Raiders destroyed: %d      Systems visited: %d / %d" % [GameState.kills, visited, Galaxy.SYSTEMS.size()], 17, UiKit.TEXT_DIM, UiKit.body(500)))
