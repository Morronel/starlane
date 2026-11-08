class_name Modal
extends Control
## Shared frame for full-screen dialogs (saves, dev menu): dimmed backdrop,
## centred panel with a title, fade-in, and a `closed` signal.

signal closed

var world: Node
var body: VBoxContainer


func _frame(title_text: String, width := 760.0) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.03, 0.06, 0.1, 0.97), Color(UiKit.ACCENT, 0.5), 10, 1, 24))
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_override("font", UiKit.display(800, 4))
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(title)


func open() -> void:
	visible = true
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	world.sfx.ui("open")


func close() -> void:
	world.sfx.ui("click")
	visible = false
	closed.emit()


func _refresh() -> void:
	pass


static func label(text: String, size := 16, col := Color(1, 1, 1, 0.9), font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	return l
