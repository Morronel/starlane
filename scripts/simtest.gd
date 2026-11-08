extends Node
## Dev-only headless gameplay check: godot --headless -- --simtest
## Fresh pilot -> hunt via autopilot + lane -> auto-attack + missiles -> loot ->
## autopilot dock -> workshop craft + outfit -> autopilot across a stargate ->
## hangar trade-in -> manual lane merge -> death/respawn -> save/load.

var main: Node


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _fail(msg: String) -> void:
	print("SIMTEST FAIL: ", msg)
	Engine.time_scale = 1.0
	get_tree().quit(1)


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		await _wait(0.25)
		t += 0.25
		if t > timeout:
			return false
	return true


var _used_lane := false


func _beacon_leg() -> bool:
	var p: PlayerShip = main.player
	if p.mode == PlayerShip.Mode.LANE:
		_used_lane = true
		GameInput.touch_boost = true
	else:
		GameInput.touch_boost = false
	return not p.autopilot


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = get_viewport().get_final_transform() * pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = get_viewport().get_final_transform() * pos
	e.relative = get_viewport().get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)


func _find_button(n: Node, text: String, inside := Rect2()) -> Button:
	for c in n.get_children():
		if c is Button and c.text == text and c.is_visible_in_tree() and (inside.size == Vector2.ZERO or inside.has_point(c.get_global_rect().get_center())):
			return c
		var r := _find_button(c, text, inside)
		if r:
			return r
	return null


## Drag that starts on a BUY button must scroll and must not buy; a tap must buy.
func _scroll_test() -> bool:
	main.menu._select("market", false)
	await _wait(0.6)
	var b := _find_button(main.menu._content, "BUY 1")
	if b == null:
		_fail("no BUY 1 button")
		return false
	var cr := GameState.credits
	var at := b.get_global_rect().get_center()
	_touch(at, true)
	await get_tree().process_frame
	var pos := at
	for i in 12:
		pos += Vector2(0, -25)
		_drag(pos, Vector2(0, -25))
		await get_tree().process_frame
	_touch(pos, false)
	await _wait(0.3)
	var sc: float = main.menu._scroll.scroll
	print("scroll test: drag from BUY scrolled to ", int(sc), ", credits ", cr, " -> ", GameState.credits)
	if GameState.credits != cr:
		_fail("dragging over a button bought something")
		return false
	if sc < 100.0:
		_fail("drag did not scroll")
		return false
	await _wait(1.5)
	b = _find_button(main.menu._content, "BUY 1", main.menu._scroll.get_global_rect())
	at = b.get_global_rect().get_center()
	_touch(at, true)
	await get_tree().process_frame
	_touch(at, false)
	await _wait(0.3)
	print("tap test: credits ", cr, " -> ", GameState.credits)
	if GameState.credits >= cr:
		_fail("tapping BUY 1 did nothing")
		return false
	return true


func _run() -> void:
	GameState.reset_game()
	main.restart_from_save()
	await _wait(0.5)
	var p: PlayerShip = main.player
	var hunt := {}
	for m in GameState.missions:
		if m["kind"] == "hunt" and m["system"] == "tessaly":
			hunt = m
	if hunt.is_empty():
		return _fail("no local hunt offered")
	GameState.accept(hunt)
	if GameState.destination_info().get("beacon", false) != true:
		return _fail("accepting a hunt did not track it")
	print("lane length ", int(main.lane.length), " m, stations ", main.stations.keys(), " gates ", main.gates.keys())

	# --- autopilot to the raider nest (uses the lane), boosting part of the way
	main._launch()
	await _wait(1.0)
	Engine.time_scale = 4.0
	main.toggle_autopilot()
	if not p.autopilot:
		return _fail("autopilot did not engage")
	var ok := await _wait_until(_beacon_leg, 200.0)
	GameInput.touch_boost = false
	if not ok:
		return _fail("autopilot never reached the beacon (at %s, %d m away)" % [str(p.global_position), int(p.global_position.distance_to(main.beacon_pos))])
	print("autopilot arrived ", int(p.global_position.distance_to(main.beacon_pos)), " m from beacon, used lane: ", _used_lane)
	if not _used_lane:
		return _fail("autopilot did not use the lane")
	Engine.time_scale = 1.0

	# --- fight: auto-attack with heavy guns, plus a missile volley
	GameState.equip["primary"] = ["starbreaker", "starbreaker"]
	p.weapon_cd.clear()
	GameState.hull = 100000.0
	GameInput.set_auto_fire(true)
	var ammo0: int = GameState.ammo["hornet"]
	var fired_missile := false
	var guard := 0.0
	await _wait(0.5)
	while not get_tree().get_nodes_in_group("enemies").is_empty() and guard < 150.0:
		var e: Node3D = get_tree().get_nodes_in_group("enemies")[0]
		var pos := e.global_position + (p.global_position - e.global_position).normalized() * 250.0
		var aim: Vector3 = main.lead_point(pos, e, 2200.0)
		p.global_transform = Transform3D(Basis.looking_at(aim - pos, Vector3.UP), pos)
		p.velocity = Vector3.ZERO
		GameInput.throttle = 0.0
		if not fired_missile:
			p.target = e
			fired_missile = p.fire_missile()
		await _wait(0.1)
		guard += 0.1
	GameInput.set_auto_fire(false)
	print("kills: ", GameState.kills, " hunt: ", hunt["state"], " in ", guard, " s, missiles ", ammo0, " -> ", GameState.ammo["hornet"])
	if hunt["state"] != "done":
		return _fail("hunt not completed")
	if GameState.ammo["hornet"] != ammo0 - 1:
		return _fail("missile not fired")

	# --- loot: fly over the salvage
	var parts0 := 0
	for k in GameState.parts:
		parts0 += GameState.parts[k]
	var loots := get_tree().get_nodes_in_group("loot")
	print("loot canisters in system: ", loots.size())
	for l in loots.slice(0, 6):
		p.global_position = l.global_position + Vector3(0, 0, 30)
		await _wait(0.4)
	var parts1 := 0
	for k in GameState.parts:
		parts1 += GameState.parts[k]
	print("parts ", parts0, " -> ", parts1, " ", GameState.parts)
	if parts1 <= parts0:
		return _fail("no salvage collected")
	GameState.hull = GameState.max_hull()

	# --- autopilot to a station and dock
	GameState.set_destination("station", "verdant")
	Engine.time_scale = 4.0
	main.toggle_autopilot()
	ok = await _wait_until(func(): return p.mode == PlayerShip.Mode.DOCKED, 240.0)
	Engine.time_scale = 1.0
	if not ok:
		return _fail("autopilot did not dock at Verdant (mode %d, %d m away)" % [p.mode, int(p.global_position.distance_to(main.stations["verdant"].global_position))])
	await _wait(1.5)
	if GameState.missions.has(hunt):
		return _fail("hunt not paid")
	print("docked at ", GameState.last_station, " credits ", GameState.credits)

	# --- workshop + outfit through the menu code paths
	GameState.parts["scrap"] = 20
	GameState.parts["circuit"] = 10
	var made := GameState.craft("bp_pulse_2")
	if made == "" or not GameState.storage.has("pulse_2"):
		return _fail("craft failed")
	GameState.uninstall("primary", 0)
	var idx := GameState.storage.find("pulse_2")
	if not GameState.install(idx):
		return _fail("install failed")
	print("crafted and installed ", made, ": ", GameState.equip)
	GameState.credits += 200000
	if GameState.buy_gear("tractor") == "":
		return _fail("buy gear failed")
	for tab in ["missions", "market", "hangar", "outfit", "workshop", "services"]:
		main.menu._select(tab)
		await _wait(0.2)
	if not await _scroll_test():
		return

	# --- autopilot across a stargate to Lumen Exchange (Corvan) and dock
	GameState.jump_charges = GameState.max_jump_charges()
	GameState.set_destination("station", "lumen")
	main._launch()
	await _wait(1.0)
	Engine.time_scale = 4.0
	main.toggle_autopilot()
	ok = await _wait_until(func(): return p.mode == PlayerShip.Mode.DOCKED and GameState.system_id == "corvan", 400.0)
	Engine.time_scale = 1.0
	if not ok:
		return _fail("autopilot did not reach Lumen: system %s mode %d" % [GameState.system_id, p.mode])
	await _wait(1.5)
	print("autopiloted to ", GameState.last_station, " in ", GameState.system_id, ", charges ", GameState.jump_charges)

	# --- hangar trade-in
	var cr := GameState.credits
	if not GameState.buy_ship("wren"):
		return _fail("could not buy Wren")
	p.refresh_ship()
	print("bought Wren for ", cr - GameState.credits, " cr; equip ", GameState.equip, " locker ", GameState.storage)
	if GameState.equip["primary"].size() != 1 or GameState.storage.is_empty():
		return _fail("loadout not normalized for Wren")

	# --- manual lane merge: fly into the tube along it
	main._launch()
	await _wait(1.0)
	# cockpit view: the Wren cabin is built and shown, and hides again in 3rd person
	Settings.first_person = true
	await _wait(0.4)
	if not main.cockpit.visible or main.cockpit._built != "wren":
		return _fail("cockpit not shown for the Wren")
	Settings.first_person = false
	await _wait(0.2)
	if main.cockpit.visible:
		return _fail("cockpit still visible in 3rd person")
	print("cockpit ok: ", main.cockpit._built)
	var c: Dictionary = main.lane.closest(p.global_position)
	var s_mid: float = main.lane.length * 0.3
	var f: Dictionary = main.lane.frame(s_mid)
	var start: Vector3 = f["origin"] + f["right"] * (SpaceLane.RADIUS + 120.0)
	p.global_transform = Transform3D(Basis.looking_at((f["origin"] + f["fwd"] * 700.0 - start).normalized(), Vector3.UP), start)
	p._lane_was_inside = false
	p._merge_cd = 0.0
	GameInput.throttle = 1.0
	ok = await _wait_until(func(): return p.mode == PlayerShip.Mode.LANE, 12.0)
	if not ok:
		return _fail("did not auto-merge into the lane (dist %d)" % int(main.lane.closest(p.global_position)["dist"]))
	print("auto-merged into lane, dir ", p.lane_dir)
	p.exit_lane()

	# --- death and respawn
	GameState.hull = 1.0
	p.shield = 0.0
	p.take_damage(50.0)
	await _wait(5.0)
	if p.mode != PlayerShip.Mode.DOCKED:
		return _fail("no respawn after death")
	print("respawned at ", GameState.last_station, " in ", GameState.system_id)
	GameState.save_game()
	if not GameState.load_game() or GameState.ship != "wren":
		return _fail("save did not load")
	# manual save slots: save, change things, load back, delete
	GameState.save_slot(2)
	var cr_saved := GameState.credits
	GameState.credits += 12345
	GameState.ship = "sparrow"
	if GameState.slot_info(2).is_empty():
		return _fail("slot 2 empty after saving")
	if not GameState.load_slot(2) or GameState.credits != cr_saved or GameState.ship != "wren":
		return _fail("slot 2 did not restore the game")
	GameState.delete_slot(2)
	if not GameState.slot_info(2).is_empty():
		return _fail("slot 2 not deleted")
	print("save slots ok: ", GameState.slot_info(0))
	print("SIMTEST PASS")
	get_tree().quit(0)
