class_name SettingsPanel
extends Control
## Modal options screen.

signal closed

var world: Node
var _seg := {}   # key -> [btnA, btnB]
var _dev_btn: Button
var _menu_btn: Button
var saves: SavePanel
var dev: DevPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.03, 0.06, 0.1, 0.96), Color(UiKit.ACCENT, 0.5), 10, 1, 28))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_override("font", UiKit.display(800, 4))
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_segment(v, "Camera", "first_person", ["3RD PERSON", "1ST PERSON"])
	_segment(v, "Steering", "invert_pitch", ["DIRECT", "INVERTED"])
	_segment(v, "Road", "peaceful_trader", ["PIRATE STOPS", "PEACEFUL TRADER"])
	_slider(v, "Music", "music_volume")
	_slider(v, "Effects", "sfx_volume")

	_segment(v, "Dev mode", "dev_mode", ["OFF", "ON"])

	var tip := Label.new()
	tip.text = "Tip: double-tap FIRE to toggle auto-attack. Steering inverted = drag up to dive."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", UiKit.GOLD)
	v.add_child(tip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_menu_btn = UiKit.button("MAIN MENU", Vector2(170, 58), 15)
	_menu_btn.pressed.connect(func():
		closed.emit()
		world.show_title())
	row.add_child(_menu_btn)
	var saves_btn := UiKit.button("SAVES", Vector2(140, 58), 18)
	saves_btn.pressed.connect(func(): saves.open())
	row.add_child(saves_btn)
	_dev_btn = UiKit.button("DEV MENU", Vector2(160, 58), 15)
	_dev_btn.pressed.connect(func(): dev.open())
	row.add_child(_dev_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var close := UiKit.button("DONE", Vector2(150, 58), 20)
	close.pressed.connect(func():
		world.sfx.ui("click")
		closed.emit())
	row.add_child(close)

	saves = SavePanel.new()
	saves.world = world
	saves.visible = false
	add_child(saves)
	saves.loaded.connect(_on_loaded)
	dev = DevPanel.new()
	dev.world = world
	dev.visible = false
	add_child(dev)


func open() -> void:
	visible = true
	saves.visible = false
	dev.visible = false
	_sync()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	world.sfx.ui("open")


func _segment(parent: Control, label: String, key: String, names: Array) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_override("font", UiKit.display(600))
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	var a := UiKit.button(names[0], Vector2(200, 56), 16)
	var b := UiKit.button(names[1], Vector2(200, 56), 16)
	a.toggle_mode = true
	b.toggle_mode = true
	a.pressed.connect(func(): _set_opt(key, false))
	b.pressed.connect(func(): _set_opt(key, true))
	row.add_child(a)
	row.add_child(b)
	parent.add_child(row)
	_seg[key] = [a, b]


func _slider(parent: Control, label: String, key: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_override("font", UiKit.display(600))
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.get(key)
	s.custom_minimum_size = Vector2(400, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v): Settings.set_value(key, v))
	s.drag_ended.connect(func(_c): world.sfx.ui("click"))
	row.add_child(s)
	parent.add_child(row)


func _set_opt(key: String, v: bool) -> void:
	Settings.set_value(key, v)
	world.sfx.ui("tab")
	_sync()


func _sync() -> void:
	for k in _seg:
		var on: bool = Settings.get(k)
		_seg[k][0].button_pressed = not on
		_seg[k][1].button_pressed = on
	_dev_btn.visible = Settings.dev_mode
	_menu_btn.visible = not world.title.visible


func _on_loaded() -> void:
	closed.emit()
	world.restart_from_save()
