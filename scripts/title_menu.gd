class_name TitleMenu
extends Control
## Main menu shown at startup over the orbiting view of the saved station:
## Continue, New game, Load, Settings, Exit.

signal continue_pressed
signal loaded
signal new_game_pressed
signal settings_pressed

const VERSION := "1.0.0"

var world: Node
var saves: SavePanel
var _box: VBoxContainer
var _continue: Button
var _new: Button
var _info: Label
var _new_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP

	# left-side shade so the menu reads over the scenery
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.01, 0.03, 0.92))
	grad.set_color(1, Color(0.0, 0.01, 0.03, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.35, 0)
	gt.fill_to = Vector2(1.0, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 520
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var title := Label.new()
	title.text = "STARLANE"
	title.add_theme_font_override("font", UiKit.display(900, 12))
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(UiKit.ACCENT, 0.45))
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 14)
	v.add_child(title)
	var sub := Modal.label("TRADE  ·  TRAVEL  ·  FIND THE LOST LANES", 16, UiKit.TEXT_DIM, UiKit.display(600, 4))
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	v.add_child(_box)
	_continue = _button("CONTINUE", _on_continue)
	_info = Modal.label("", 14, UiKit.TEXT_DIM)
	_box.add_child(_info)
	_new = _button("NEW GAME", _on_new)
	_button("LOAD GAME", func(): saves.open())
	_button("SETTINGS", func(): settings_pressed.emit())
	_button("EXIT", _on_exit)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(Modal.label("v" + VERSION, 13, Color(1, 1, 1, 0.35)))

	saves = SavePanel.new()
	saves.world = world
	saves.visible = false
	add_child(saves)
	saves.loaded.connect(func(): loaded.emit())


func _button(text: String, cb: Callable) -> Button:
	var b := UiKit.button(text, Vector2(360, 62), 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func open() -> void:
	visible = true
	saves.visible = false
	_new_armed = false
	_new.text = "NEW GAME"
	var info := GameState.slot_info(0)
	_continue.disabled = info.is_empty()
	_info.visible = not info.is_empty()
	if not info.is_empty():
		_info.text = "   %s  ·  %d cr  ·  %s, %s" % [info["ship"], info["credits"], info["station"], info["system"]]
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _on_continue() -> void:
	world.sfx.ui("click")
	continue_pressed.emit()


func _on_new() -> void:
	if not GameState.slot_info(0).is_empty() and not _new_armed:
		_new_armed = true
		_new.text = "TAP AGAIN: START OVER"
		world.sfx.ui("error")
		return
	world.sfx.ui("upgrade")
	new_game_pressed.emit()


func _on_exit() -> void:
	world.sfx.ui("click")
	GameState.save_game()
	get_tree().quit()
