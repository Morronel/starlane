class_name SavePanel
extends Modal
## Save slots: the autosave plus three manual slots. Save, load, delete, or
## start a new game. Loading puts you back in the hangar of the saved station.

signal loaded

var _list: VBoxContainer
var _armed := ""            # "del_2", "new": the action waiting for a second tap
var _new_btn: Button


func _ready() -> void:
	_frame("SAVES", 820)
	var hint := Modal.label("The game also autosaves whenever you dock, launch or jump. Loading puts you in the hangar of the saved station.", 15, UiKit.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	body.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	_new_btn = UiKit.button("NEW GAME", Vector2(260, 58), 16)
	_new_btn.pressed.connect(_on_new)
	row.add_child(_new_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var back := UiKit.button("BACK", Vector2(200, 58), 20)
	back.pressed.connect(close)
	row.add_child(back)


func _refresh() -> void:
	_armed = ""
	_new_btn.text = "NEW GAME"
	for c in _list.get_children():
		c.queue_free()
	for slot in GameState.SLOT_COUNT + 1:
		_list.add_child(_slot_row(slot))


static func when_text(unix: int) -> String:
	if unix <= 0:
		return ""
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


func _slot_row(slot: int) -> Control:
	var info := GameState.slot_info(slot)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(0.06, 0.1, 0.16, 0.9), Color(UiKit.ACCENT, 0.25 if not info.is_empty() else 0.1), 8, 1, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var slot_name := "AUTOSAVE" if slot == 0 else "SLOT %d" % slot
	v.add_child(Modal.label(slot_name, 18, UiKit.GOLD if slot == 0 else UiKit.ACCENT, UiKit.display(700, 2)))
	if info.is_empty():
		v.add_child(Modal.label("Empty", 15, Color(1, 1, 1, 0.4)))
	else:
		v.add_child(Modal.label("%s  ·  %d cr  ·  %d kills" % [info["ship"], info["credits"], info["kills"]], 15))
		v.add_child(Modal.label("%s, %s   %s" % [info["station"], info["system"], when_text(info["saved_at"])], 13, UiKit.TEXT_DIM))
	if slot != 0:
		var sv := UiKit.button("SAVE", Vector2(110, 52), 15)
		sv.pressed.connect(_on_save.bind(slot))
		h.add_child(sv)
	if not info.is_empty():
		var ld := UiKit.button("LOAD", Vector2(110, 52), 15)
		ld.pressed.connect(_on_load.bind(slot))
		h.add_child(ld)
		if slot != 0:
			var del := UiKit.button("DELETE", Vector2(120, 52), 14)
			del.pressed.connect(_on_delete.bind(slot, del))
			h.add_child(del)
	return card


func _on_save(slot: int) -> void:
	GameState.save_slot(slot)
	world.sfx.ui("buy")
	_refresh.call_deferred()


func _on_load(slot: int) -> void:
	if not GameState.load_slot(slot):
		world.sfx.ui("error")
		return
	world.sfx.ui("upgrade")
	visible = false
	loaded.emit()


func _on_delete(slot: int, btn: Button) -> void:
	var key := "del_%d" % slot
	if _armed != key:
		_armed = key
		btn.text = "SURE?"
		world.sfx.ui("error")
		return
	GameState.delete_slot(slot)
	world.sfx.ui("click")
	_refresh.call_deferred()


func _on_new() -> void:
	if _armed != "new":
		_armed = "new"
		_new_btn.text = "TAP AGAIN: START OVER"
		world.sfx.ui("error")
		return
	GameState.reset_game()
	GameState.save_game()
	world.sfx.ui("click")
	visible = false
	loaded.emit()
