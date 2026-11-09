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
var _kinds := {}


var _dbg_t := 0


func _beacon_leg() -> bool:
	var p: PlayerShip = main.player
	_dbg_t += 1
	if _dbg_t % 20 == 0:
		print("  ap: mode %d %s s=%d spd=%d beacon %d m, route %d, plan %s" % [p.mode, p.lane.kind if p.lane else "-", p.lane_s, p.speed, p.global_position.distance_to(main.beacon_pos), p.ap_route.size(), str(main._ap_plan.get("rides", []).size())])
	if p.mode == PlayerShip.Mode.LANE:
		_used_lane = true
		_kinds[p.lane.kind] = true
		GameInput.touch_boost = true
	else:
		GameInput.touch_boost = false
	return not p.autopilot


func _lumen_leg() -> bool:
	var p: PlayerShip = main.player
	_dbg_t += 1
	if _dbg_t % 20 == 0:
		var g: Stargate = main.gates.get("corvan")
		print("  ap2: mode %d ap %s %s s=%d spd=%d gate %d m, route %d, sys %s" % [p.mode, p.autopilot, p.lane.kind if p.lane else "-", p.lane_s, p.speed, p.global_position.distance_to(g.global_position) if g else -1, p.ap_route.size(), GameState.system_id])
	return p.mode == PlayerShip.Mode.DOCKED and GameState.system_id == "corvan"


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
	var net: RoadNet = main.net
	var km := {"road": 0.0, "highway": 0.0}
	var cnt := {"road": 0, "highway": 0}
	var kmax := {"road": 0.0, "highway": 0.0}
	for t in net.tracks:
		km[t.kind] += t.length / 1000.0
		cnt[t.kind] += 1
		for i in int(t.length / 50.0):
			kmax[t.kind] = maxf(kmax[t.kind], t.curvature(i * 50.0).z)
	print("network: %d nodes, %d highways (%d km), %d roads (%d km); sharpest turn radius road %d m, highway %d m" % [net.nodes.size(), cnt["highway"], km["highway"], cnt["road"], km["road"], 1.0 / kmax["road"], 1.0 / kmax["highway"]])
	print("stations ", main.stations.keys(), " gates ", main.gates.keys())
	for k in ["road", "highway"]:
		var sp: Dictionary = SpaceLane.KINDS[k]
		var t0: SpaceLane = null
		for t in net.tracks:
			if t.kind == k:
				t0 = t
		print("  %s: autopilot safe speed in its sharpest turn %d m/s; push at full speed %d m/s, boosting %d m/s vs steering %d m/s" % [k, t0.safe_speed(kmax[k]), sp["speed"] * sp["speed"] * kmax[k] / sp["grip"], pow(sp["speed"] + sp["boost"], 2) * kmax[k] / sp["grip"], sp["steer"]])
	# no junction may strand you: every track end at an interchange or
	# crossroads offers at least one way on
	var stranded := 0
	for t in net.tracks:
		for d in [1, -1]:
			if net.nodes[net.end_node(t, d)]["kind"] != "poi" and net.allowed(t, d).is_empty():
				stranded += 1
	print("  dead-end junction approaches: %d" % stranded)
	if stranded > 0:
		return _fail("%d track ends lead nowhere" % stranded)
	# every node reachable from every other through the network
	for n in net.nodes:
		var pl := net.plan(net.nodes[0]["pos"] + Vector3(0, 5, 0), n["pos"], 120.0)
		if n["id"] != 0 and pl["rides"].is_empty() and (net.nodes[0]["pos"] as Vector3).distance_to(n["pos"]) > 10000.0:
			return _fail("no route to " + n["name"])

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
	print("autopilot arrived ", int(p.global_position.distance_to(main.beacon_pos)), " m from beacon, rode: ", _kinds.keys())
	if not _used_lane:
		return _fail("autopilot did not use the network")
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
	ok = await _wait_until(func(): return _lumen_leg(), 400.0)
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
	var road: SpaceLane = null
	var hwy: SpaceLane = null
	for t in main.net.tracks:
		if t.kind == "road" and road == null and t.length > 8000.0:
			road = t
		if t.kind == "highway" and hwy == null:
			hwy = t
	var s_mid: float = road.length * 0.3
	var f: Dictionary = road.frame(s_mid)
	var start: Vector3 = f["origin"] + f["right"] * (road.radius + 120.0)
	p.global_transform = Transform3D(Basis.looking_at((f["origin"] + f["fwd"] * 2500.0 - start).normalized(), Vector3.UP), start)
	p._lane_was_inside = false
	p._merge_cd = 0.0
	GameInput.throttle = 1.0
	ok = await _wait_until(func(): return p.mode == PlayerShip.Mode.LANE, 12.0)
	if not ok:
		return _fail("did not auto-merge into the road (dist %d)" % int(road.closest(p.global_position)["dist"]))
	print("auto-merged onto a ", p.lane.kind, ", dir ", p.lane_dir)
	p.exit_lane()

	# --- highway: ride to the interchange at the end and carry on through it
	f = hwy.frame(hwy.length - 9000.0)
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"])
	p.enter_lane(1, true, hwy)
	p.lane_speed = 3000.0
	GameInput.throttle = 0.6
	ok = await _wait_until(func(): return p.mode != PlayerShip.Mode.LANE or p.lane != hwy, 20.0)
	if not ok or p.mode != PlayerShip.Mode.LANE:
		return _fail("highway did not carry on through the interchange (mode %d)" % p.mode)
	print("through ", main.net.node_name(hwy.node_b), " onto a ", p.lane.kind, " to ", main.net.node_name(main.net.end_node(p.lane, p.lane_dir)), " at ", int(p.lane_speed), " m/s")
	p.exit_lane()

	# --- junctions: no turn sharper than MAX_TURN_DEG, and the lane you hold
	# picks the branch
	var worst := 0.0
	var dead := 0
	var multi := []
	for t in main.net.tracks:
		for d in [1, -1]:
			var opts: Array = p.junction_options(t, d)
			for o in opts:
				if not o.get("stop", false):
					worst = maxf(worst, absf(o["turn"]))
			if opts.is_empty():
				dead += 1
			var real := opts.filter(func(o): return not o.get("stop", false))
			if real.size() >= 2:
				multi.append([t, d])
	print("junction turns: sharpest %d deg, %d dead ends, %d forks" % [int(worst), dead, multi.size()])
	if worst > 75.0:   # MAX_TURN_DEG, or the gentlest way on where nothing is in reach
		return _fail("a junction turn is %d degrees" % int(worst))
	if multi.is_empty():
		return _fail("no junction offers a choice")
	var fork: Array = multi[0]
	var ft: SpaceLane = fork[0]
	var fd: int = fork[1]
	for side in [0, 1]:
		var opts: Array = p.junction_options(ft, fd)
		var want: int = 0 if side == 0 else opts.size() - 1
		if opts[want].get("stop", false):
			want -= 1
		var s0: float = ft.length - 2500.0 if fd > 0 else 2500.0
		f = ft.frame(s0)
		p.global_transform = Transform3D(Basis.looking_at(f["fwd"] * fd, Vector3.UP), f["origin"])
		p.enter_lane(fd, true, ft)
		p.lane = ft
		p.lane_dir = fd
		p.lane_s = s0
		p.lane_speed = 600.0
		GameInput.throttle = 0.0
		p.lane_offset = Vector2(p.band_centre(want, opts.size()) * fd, 0.0)
		ok = await _wait_until(func(): return p.mode != PlayerShip.Mode.LANE or p.lane != ft, 15.0)
		var got: bool = p.mode == PlayerShip.Mode.LANE and p.lane == opts[want]["track"]
		print("lane %d of %d at %s (turn %d deg): %s" % [want + 1, opts.size(), main.net.node_name(main.net.end_node(ft, fd)), int(opts[want]["turn"]), "took it" if got else "missed"])
		if not got:
			return _fail("holding a lane did not pick its branch")
		p.exit_lane()

	# --- GPS: with a destination set it tells you what to do, on and off the roads
	var far_id := ""
	var far_d := 0.0
	for sid in main.stations:
		var dd: float = (main.stations[sid] as Node3D).global_position.distance_to(p.global_position)
		if dd > far_d:
			far_d = dd
			far_id = sid
	GameState.set_destination("station", far_id)
	await _wait(0.6)
	var gi: Dictionary = main.gps_info()
	print("gps (flight): ", gi.get("text", "-"), " / ", gi.get("then", ""))
	if gi.is_empty():
		await _wait(0.6)
		gi = main.gps_info()
		print("gps (flight): ", gi.get("text", "-"), " / ", gi.get("then", ""))
	if gi.is_empty():
		return _fail("GPS gave no directions")
	if not main.gps["rides"].is_empty():
		var r0: Dictionary = main.gps["rides"][0]
		var gt: SpaceLane = r0["track"]
		f = gt.frame(float(r0["enter_s"]))
		p.global_transform = Transform3D(Basis.looking_at(f["fwd"] * int(r0["dir"]), Vector3.UP), f["origin"])
		p.enter_lane(r0["dir"], true, gt)
		await _wait(0.8)
		gi = main.gps_info()
		print("gps (on the %s): %s, %s / %s" % [gt.kind, gi.get("text", "-"), Hud._fmt_dist(gi.get("dist", 0.0)), gi.get("then", "")])
		if gi.is_empty():
			return _fail("GPS gave no directions on the road")
		# the arrow must agree with the words
		var txt: String = gi.get("text", "")
		if (txt.begins_with("Keep LEFT") or txt.begins_with("Bear left")) and gi["icon"] != "left":
			return _fail("GPS says '%s' but shows a %s arrow" % [txt, gi["icon"]])
		if (txt.begins_with("Keep RIGHT:") or txt.begins_with("Bear right")) and gi["icon"] != "right":
			return _fail("GPS says '%s' but shows a %s arrow" % [txt, gi["icon"]])
		p.exit_lane()
	GameState.destination = {}

	# --- turns: since 0.9.0 even the sharpest road bend can be flown flat out
	# on boost with no steering at all (wide tubes, gentle curves)
	var sharp := 0.0
	var sharp_s := 0.0
	for i in int(road.length / 50.0):
		var k: float = road.curvature(i * 50.0).z
		if k > sharp:
			sharp = k
			sharp_s = i * 50.0
	f = road.frame(maxf(sharp_s - 1500.0, 0.0))
	p.global_transform = Transform3D(Basis.looking_at(f["fwd"], Vector3.UP), f["origin"])
	p.enter_lane(1, true, road)
	p.lane_offset = Vector2.ZERO
	p.lane_speed = 1250.0
	GameInput.touch_boost = true
	ok = await _wait_until(func(): return p.mode != PlayerShip.Mode.LANE or p.lane != road or p.lane_s > sharp_s + 1500.0, 12.0)
	GameInput.touch_boost = false
	print("boosting blind through a %d m bend: %s" % [int(1.0 / sharp), "thrown off" if p.mode == PlayerShip.Mode.FLIGHT else "held on"])
	if p.mode != PlayerShip.Mode.LANE:
		return _fail("thrown off a road by its sharpest bend while boosting")
	print("  sideways offset after the bend: %d m of %d" % [int(p.lane_offset.length()), int(road.radius)])
	p.exit_lane()

	# --- boost punch: from cruise, one second of boost nearly doubles the speed
	p.boost_energy = 1.0
	p.boost_drained = false
	p.boost_level = 0.0
	p.speed = p.top_speed()
	GameInput.throttle = 1.0
	GameInput.touch_boost = true
	await _wait(1.0)
	GameInput.touch_boost = false
	print("boost punch: %.2fx top speed after 1 s" % (p.speed / p.top_speed()))
	if p.speed < p.top_speed() * 1.8:
		return _fail("boost is sluggish (%.2fx after 1 s)" % (p.speed / p.top_speed()))
	await _wait(2.0)

	# --- boost tail: drain the meter while holding boost; speed must settle
	# smoothly instead of flickering between boost and no boost
	p.boost_energy = 0.08
	p.boost_drained = false
	GameInput.throttle = 1.0
	GameInput.touch_boost = true
	var last := p.speed
	var flips := 0
	var last_sign := 0
	for i in 240:
		await get_tree().physics_frame
		var d := p.speed - last
		last = p.speed
		var sg := 0 if absf(d) < 0.05 else (1 if d > 0.0 else -1)
		if sg != 0:
			if last_sign != 0 and sg != last_sign:
				flips += 1
			last_sign = sg
	GameInput.touch_boost = false
	print("boost tail: drained ", p.boost_drained, ", speed ", int(p.speed), " (top ", int(p.top_speed()), "), direction flips ", flips)
	if not p.boost_drained or flips > 2 or p.speed < p.top_speed() * 1.05:
		return _fail("boost tail not smooth (flips %d, speed %d)" % [flips, int(p.speed)])

	# --- main menu: opens docked, CONTINUE returns to the station screen
	main.show_title()
	await _wait(0.5)
	if not main.title.visible or main.menu.visible or p.mode != PlayerShip.Mode.DOCKED:
		return _fail("main menu did not open over the docked station")
	main.title._on_continue()
	await _wait(0.3)
	if main.title.visible or not main.menu.visible:
		return _fail("CONTINUE did not return to the station")
	print("main menu ok")
	main._launch()
	await _wait(1.0)

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
