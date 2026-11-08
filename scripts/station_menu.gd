class_name StationMenu
extends Control
## Docked station screen: missions, market, shipyard, repair, launch.

signal launch_pressed

var station: Station
var _tab := "missions"
var _content: VBoxContainer
var _title: Label
var _credits: Label
var _info: Label
var _tab_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = make_theme()
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)

	# left column: station name + tabs + launch
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	row.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	left.add_child(lv)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	lv.add_child(_title)
	_credits = Label.new()
	_credits.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	lv.add_child(_credits)
	lv.add_child(HSeparator.new())
	for t in [["missions", "Mission Board"], ["market", "Market"], ["shipyard", "Shipyard"], ["repair", "Repairs"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(_select.bind(t[0]))
		lv.add_child(b)
		_tab_buttons[t[0]] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(spacer)
	var launch := Button.new()
	launch.text = "LAUNCH"
	launch.custom_minimum_size = Vector2(0, 72)
	launch.add_theme_font_size_override("font_size", 28)
	launch.add_theme_color_override("font_color", Color(0.5, 1.0, 0.75))
	launch.pressed.connect(func(): launch_pressed.emit())
	lv.add_child(launch)

	# right: content
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 10)
	scroll.add_child(rv)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	rv.add_child(_info)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	rv.add_child(_content)
	GameState.credits_changed.connect(func(_v): _refresh_header())


func open(st: Station, notes: Array) -> void:
	station = st
	_info.text = "\n".join(notes) if not notes.is_empty() else ""
	_info.visible = not notes.is_empty()
	visible = true
	_select(_tab)


func _select(tab: String) -> void:
	_tab = tab
	for k in _tab_buttons:
		_tab_buttons[k].button_pressed = (k == tab)
	_rebuild()


func _refresh_header() -> void:
	if station == null:
		return
	_title.text = station.display_name
	_credits.text = "%d credits\nHull %d%%   Cargo %d/%d" % [GameState.credits, int(GameState.hull), GameState.cargo_used(), GameState.cargo_capacity()]


func _rebuild() -> void:
	_refresh_header()
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		"missions":
			_build_missions()
		"market":
			_build_market()
		"shipyard":
			_build_shipyard()
		"repair":
			_build_repair()


func _heading(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_content.add_child(l)


func _card(title: String, body: String, buttons: Array) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.12, 0.16, 0.24, 0.9), Color(0.3, 0.5, 0.7, 0.6)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 23)
	v.add_child(tl)
	if body != "":
		var bl := Label.new()
		bl.text = body
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		bl.add_theme_font_size_override("font_size", 18)
		v.add_child(bl)
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(150, 56)
		btn.disabled = b.size() > 2 and b[2]
		btn.pressed.connect(b[1])
		h.add_child(btn)
	_content.add_child(p)


func _build_missions() -> void:
	_heading("Mission Board")
	var list := GameState.missions_for(station.station_id)
	if list.is_empty():
		_card("No contracts right now", "Check back later.", [])
	for m in list:
		var state: String = m["state"]
		var body: String = m["desc"] + "\nReward: %d cr" % m["reward"]
		if state == "offered":
			_card(m["title"], body, [["Accept", _accept.bind(m)]])
		elif state == "active":
			var extra := ""
			if m["kind"] == "hunt":
				extra = "\nRaiders left: %d" % m["left"]
			_card("[ACTIVE] " + m["title"], body + extra, [])
		elif state == "done":
			_card("[COMPLETE] " + m["title"], "Payment will be made when you dock.", [])
	var tip := "Tip: the lane gate is right outside the bay. Kessler Beacon sits halfway along the lane."
	_card("Pilot's note", tip, [])


func _build_market() -> void:
	_heading("Market")
	for id in GameState.COMMODITIES:
		var info: Dictionary = GameState.COMMODITIES[id]
		var price := GameState.price(station.station_id, id)
		var held: int = GameState.cargo.get(id, 0)
		var ratio: float = float(price) / info["base"]
		var trend := "cheap here" if ratio < 0.9 else ("in demand" if ratio > 1.1 else "fair")
		var body := "%d cr / unit  (%s)\nIn hold: %d" % [price, trend, held]
		_card(info["name"], body, [
			["Buy 1", _buy.bind(id, 1)],
			["Buy max", _buy.bind(id, 999)],
			["Sell all", _sell.bind(id), held == 0],
		])


func _buy(id: String, n: int) -> void:
	var got := GameState.buy(station.station_id, id, n)
	if got == 0:
		GameState.message.emit("Not enough credits or cargo space", Color(1, 0.6, 0.4))
	_rebuild()


func _sell(id: String) -> void:
	var total := GameState.sell(station.station_id, id)
	if total > 0:
		GameState.message.emit("Sold for %d cr" % total, Color(1.0, 0.9, 0.5))
	_rebuild()


func _build_shipyard() -> void:
	_heading("Shipyard")
	for id in GameState.UPGRADES:
		var info: Dictionary = GameState.UPGRADES[id]
		var lvl: int = GameState.upgrades[id]
		var maxed: bool = lvl >= info["max"]
		var cost: int = 0 if maxed else info["cost"][lvl]
		var body := "Mk %d / %d   %s" % [lvl, info["max"], info["desc"]]
		var label := "MAX" if maxed else "Buy  %d cr" % cost
		_card(info["name"], body, [[label, _do_upgrade.bind(id), maxed or GameState.credits < cost]])


func _build_repair() -> void:
	_heading("Repairs")
	var cost := GameState.repair_cost()
	if cost <= 0:
		_card("Hull integrity 100%", "Your ship is in perfect shape.", [])
	else:
		_card("Hull integrity %d%%" % int(GameState.hull), "Full repair: %d cr" % cost, [["Repair", _do_repair, GameState.credits < cost]])
	_card("Pilot record", "Raiders destroyed: %d" % GameState.kills, [])


func _accept(m: Dictionary) -> void:
	GameState.accept(m)
	GameState.message.emit("Accepted: " + m["title"], Color(0.6, 1.0, 0.7))
	_rebuild()


func _do_upgrade(id: String) -> void:
	if GameState.upgrade(id):
		GameState.message.emit("%s upgraded to Mk %d" % [GameState.UPGRADES[id]["name"], GameState.upgrades[id]], Color(0.6, 1.0, 0.7))
	_rebuild()


func _do_repair() -> void:
	GameState.repair()
	_rebuild()


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.04, 0.06, 0.1, 0.82), Color(0.35, 0.6, 0.85, 0.5)))
	t.set_stylebox("normal", "Button", _box(Color(0.1, 0.18, 0.28, 0.95), Color(0.35, 0.65, 0.9, 0.7)))
	t.set_stylebox("hover", "Button", _box(Color(0.14, 0.26, 0.4, 0.95), Color(0.5, 0.8, 1.0, 0.9)))
	t.set_stylebox("pressed", "Button", _box(Color(0.2, 0.42, 0.6, 0.95), Color(0.6, 0.9, 1.0, 1.0)))
	t.set_stylebox("hover_pressed", "Button", _box(Color(0.2, 0.42, 0.6, 0.95), Color(0.6, 0.9, 1.0, 1.0)))
	t.set_stylebox("disabled", "Button", _box(Color(0.08, 0.1, 0.13, 0.8), Color(0.25, 0.3, 0.35, 0.5)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.55))
	return t
