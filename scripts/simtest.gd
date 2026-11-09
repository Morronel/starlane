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



# --- 0.10 roads for humans ---------------------------------------------------------

## 0.12 "the road": cruise, storms, distress calls, customs, pirate tolls,
## drifting cargo and postcards.
func _road_tests() -> bool:
	var p: PlayerShip = main.player
	var road: RoadEvents = main.road
	var net: RoadNet = main.net
	road.timer = 99999.0
	Engine.time_scale = 1.0
	var loop: SpaceLane = null
	for t in net.tracks:
		if t.role == "loop" and (loop == null or t.length > loop.length):
			loop = t
	p.mode = PlayerShip.Mode.FLIGHT
	p.lane = null
	var f: Dictionary = loop.frame(loop.length * 0.1)
	var start: Vector3 = f["origin"] + f["right"] * (loop.radius + 200.0)
	p.global_transform = Transform3D(Basis.looking_at((f["origin"] + f["fwd"] * 6000.0 - start).normalized(), Vector3.UP), start)
	p._lane_was_inside = false
	p._merge_cd = 0.0
	p.exit_choice = 0
	GameState.destination = {}
	if not await _wait_until(func(): return p.mode == PlayerShip.Mode.LANE, 12.0):
		return _failb("road test could not merge onto the loop")
	await _wait(0.3)
	if not road.cruise_available():
		return _failb("cruise not offered on the open loop")
	road.take_offer()
	if not road.cruise or Engine.time_scale != RoadEvents.CRUISE_SCALE:
		return _failb("cruise did not engage")
	road.take_offer()
	if road.cruise or Engine.time_scale != 1.0:
		return _failb("cruise did not switch off")
	print("road: cruise x3 on and off")
	road.start("storm")
	await _wait(0.2)
	if p.speed_mult > 0.6:
		return _failb("ion storm did not slow the lane")
	road.storm_t = 0.0
	road.start("distress")
	if road.offer().get("label", "") != "HELP HAULER":
		return _failb("distress call not offered")
	var cr0 := GameState.credits
	road.take_offer()
	await _wait(0.3)
	if p.mode != PlayerShip.Mode.FLIGHT or road.ev.get("phase", "") != "go":
		return _failb("helping the hauler did not drop us out to it")
	p.global_position = road.ev["pos"] + Vector3(0, 0, 150)
	await _wait(0.4)
	if not road.ev.is_empty() or GameState.credits <= cr0:
		return _failb("the hauler did not thank us")
	print("road: helped a hauler, +%d cr" % (GameState.credits - cr0))
	GameState.cargo["stims"] = 3
	GameState.cargo_cost["stims"] = 1800
	cr0 = GameState.credits
	road.start("customs")
	await _wait(5.5)
	if GameState.cargo.has("stims") or GameState.credits >= cr0:
		return _failb("customs missed the contraband")
	print("road: customs fined %d cr and took the stims" % (cr0 - GameState.credits))
	var foes0 := get_tree().get_nodes_in_group("enemies").size()
	road.start("pirates")
	await _wait(0.2)
	var crew: int = road.ev.get("crew", []).size()
	if crew < 2 or road.offer().is_empty():
		return _failb("pirate stop did not offer a toll")
	cr0 = GameState.credits
	road.take_offer()
	await _wait(0.3)
	if get_tree().get_nodes_in_group("enemies").size() > foes0 or GameState.credits >= cr0:
		return _failb("paying the toll did not send the pirates away")
	print("road: paid a %d cr pirate toll, %d pirates left" % [cr0 - GameState.credits, crew])
	var loot0 := get_tree().get_nodes_in_group("loot").size()
	road.start("derelict")
	road.take_offer()
	await _wait(0.2)
	if get_tree().get_nodes_in_group("loot").size() < loot0 + 3:
		return _failb("derelict pod spilled no cargo")
	# postcards: the comet and the system wonder
	road.start("comet")
	await _wait(0.2)
	p.global_transform = Transform3D(Basis.looking_at((road.comet.global_position - p.global_position).normalized(), Vector3.UP), p.global_position)
	main.camera.snap()
	await _wait(0.5)
	cr0 = GameState.credits
	road.take_photo()
	if not GameState.postcards.has("comet_" + GameState.system_id) or GameState.credits <= cr0:
		return _failb("comet photo did not count")
	var wp: Vector3 = road.wonder.global_position
	var from := wp + Vector3(9000, 1500, 0)
	p.global_transform = Transform3D(Basis.looking_at((wp - from).normalized(), Vector3.UP), from)
	main.camera.snap()
	await _wait(0.5)
	road.take_photo()
	if not GameState.postcards.has("wonder_" + GameState.system_id):
		return _failb("wonder photo did not count (target %s)" % str(road.photo_target()))
	print("road: postcards ", GameState.postcards.keys())
	road.timer = 90.0
	return true


func _failb(why: String) -> bool:
	_fail(why)
	return false


func _loop_tests() -> bool:
	var p: PlayerShip = main.player
	var net: RoadNet = main.net
	# shape: one loop, every fork a 2-way choice, every turn gentle
	var forks := 0
	var worst := 0.0
	var exits := 0
	for t in net.tracks:
		if t.role == "exit":
			exits += 1
		for d in [1, -1]:
			if t.oneway and d < 0:
				continue
			var opts: Array = p.junction_options(t, d)
			var real := opts.filter(func(o): return not o.get("stop", false))
			if real.size() > 2:
				_fail("a junction offers %d ways" % real.size())
				return false
			if real.size() == 2:
				forks += 1
			for o in real:
				worst = maxf(worst, absf(o["turn"]))
			if opts.is_empty():
				_fail("track %s leads nowhere" % t.name)
				return false
	var pois: int = main.stations.size() + main.gates.size() + 1
	print("loop network: %d tracks, %d exits for %d destinations, %d forks, sharpest junction turn %d deg" % [net.tracks.size(), exits, pois, forks, int(worst)])
	if exits != pois:
		_fail("expected one exit per destination")
		return false
	if worst > 15.0:
		_fail("a junction turns %d degrees" % int(worst))
		return false

	# auto-merge: fly into the loop along it
	var loop: SpaceLane = null
	for t in net.tracks:
		if t.role == "loop" and (loop == null or t.length > loop.length):
			loop = t
	var f: Dictionary = loop.frame(loop.length * 0.3)
	var start: Vector3 = f["origin"] + f["right"] * (loop.radius + 200.0)
	p.global_transform = Transform3D(Basis.looking_at((f["origin"] + f["fwd"] * 6000.0 - start).normalized(), Vector3.UP), start)
	p._lane_was_inside = false
	p._merge_cd = 0.0
	GameInput.throttle = 1.0
	var ok := await _wait_until(func(): return p.mode == PlayerShip.Mode.LANE, 12.0)
	if not ok:
		_fail("did not auto-merge into the highway loop")
		return false
	print("auto-merged onto the ", p.lane.role, " ", p.lane.kind, ", dir ", p.lane_dir)

	# stay on: with nothing armed the loop carries you past exits
	GameState.destination = {}
	Engine.time_scale = 4.0
	var passed := {}
	ok = await _wait_until(func():
		if p.mode == PlayerShip.Mode.LANE and p.lane.role == "loop":
			passed[p.lane] = true
		return p.mode != PlayerShip.Mode.LANE or p.lane.role == "exit" or passed.size() >= 5, 60.0)
	if p.mode != PlayerShip.Mode.LANE or p.lane.role == "exit":
		Engine.time_scale = 1.0
		_fail("left the loop without asking (mode %d)" % p.mode)
		return false
	print("stayed on the loop through %d segments" % passed.size())

	# the EXIT button takes the next exit
	ok = await _wait_until(func(): return p.exit_ahead(), 30.0)
	var want: int = p.junction["options"][p.junction["exit"]]["track"].exit_no
	p.toggle_exit()
	ok = await _wait_until(func(): return p.mode != PlayerShip.Mode.LANE or p.lane.role == "exit", 30.0)
	if p.mode != PlayerShip.Mode.LANE or p.lane.exit_no != want:
		Engine.time_scale = 1.0
		_fail("TAKE EXIT did not take exit %d" % want)
		return false
	print("took exit %d onto the ramp to %s at %d m/s" % [want, net.node_name(p.lane.node_b), int(p.lane_speed)])
	ok = await _wait_until(func(): return p.mode == PlayerShip.Mode.FLIGHT, 30.0)
	Engine.time_scale = 1.0
	if not ok:
		_fail("ramp did not end in free flight")
		return false
	print("ramp ended in free flight, speed %d" % int(p.speed))

	# a human pilot: slow hands, no autopilot, only the GPS and the EXIT
	# button. Must reach every destination in the system from a station.
	var targets := []
	for sid in main.stations:
		targets.append({"type": "station", "id": sid})
	for k in main.gates:
		targets.append({"type": "gate", "id": k})
	targets.append({"type": "beacon"})
	var from: String = main.stations.keys()[0]
	for tg in targets:
		if tg["type"] == "station" and tg["id"] == from:
			continue
		var st: Station = main.stations[from]
		p.mode = PlayerShip.Mode.FLIGHT
		p.lane = null
		p.global_transform = st.undock_transform()
		p.speed = 60.0
		p.velocity = Vector3.ZERO
		if tg["type"] == "station":
			GameState.set_destination("station", tg["id"])
		elif tg["type"] == "gate":
			# a gate is the way to a station in the next system
			GameState.set_destination("station", Galaxy.SYSTEMS[tg["id"]]["stations"][0]["id"])
		else:
			GameState.destination = {}
			var hm := {"id": 9999, "kind": "hunt", "state": "active", "system": GameState.system_id, "title": "test nest",
				"desc": "", "count": 1, "left": 1, "reward": 1, "station": "", "spawned": true}
			GameState.missions.append(hm)
			GameState.set_destination("mission", 9999)
		var t0 := Time.get_ticks_msec()
		Engine.time_scale = 4.0
		var res: String = await _human_fly(tg)
		Engine.time_scale = 1.0
		GameInput.touch_stick = Vector2.ZERO
		print("  human pilot %s -> %s: %s (%.0f s game time)" % [from, tg.get("id", "beacon"), res, (Time.get_ticks_msec() - t0) * 4.0 / 1000.0])
		if res != "arrived":
			_fail("a human pilot could not reach " + str(tg.get("id", "beacon")))
			return false
		if p.mode == PlayerShip.Mode.DOCKING:
			await _wait_until(func(): return p.mode == PlayerShip.Mode.DOCKED, 10.0)
		if p.mode == PlayerShip.Mode.DOCKED:
			main.menu.visible = false
			p.mode = PlayerShip.Mode.FLIGHT
	GameState.destination = {}
	GameState.missions = GameState.missions.filter(func(m): return m["id"] != 9999)
	return true


## Fly by hand like a person would: look at the GPS every 0.4 s, steer toward
## the join point / destination with a limited stick rate, press the context
## button for ENTER and DOCK, and otherwise leave the loop to the GPS.
func _human_fly(tg: Dictionary) -> String:
	var p: PlayerShip = main.player
	var stick := Vector2.ZERO
	var want := Vector2.ZERO
	var think := 0.0
	var t := 0.0
	GameInput.throttle = 1.0
	while t < 240.0:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		if p.mode == PlayerShip.Mode.DOCKING or p.mode == PlayerShip.Mode.DOCKED:
			return "arrived" if tg["type"] == "station" and p.dock_station.station_id == tg["id"] else "docked at the wrong place"
		if tg["type"] == "gate" and p.mode == PlayerShip.Mode.FLIGHT and p.can_jump() == main.gates[tg["id"]]:
			return "arrived"
		if tg["type"] == "beacon" and p.global_position.distance_to(main.beacon_pos) < 1500.0:
			return "arrived"
		think -= dt
		if think <= 0.0:
			think = 0.4
			want = Vector2.ZERO
			if p.mode == PlayerShip.Mode.FLIGHT:
				var g: Dictionary = main.gps_info()
				var aim := Vector3.INF
				if g.has("join"):
					aim = g["join"]
				else:
					var dt2: Dictionary = main.dest_target()
					if not dt2.is_empty():
						aim = dt2["goal"]
				if aim != Vector3.INF:
					var local: Vector3 = p.global_transform.basis.inverse() * (aim - p.global_position).normalized()
					want = Vector2(local.x, local.y) * 3.0
					if local.z > 0.0:
						want = Vector2(signf(local.x + 0.01), 0.0)
					want = want.limit_length(1.0)
				# press the context button when it offers what we want
				if tg["type"] == "station" and p.can_dock() == main.stations[tg["id"]]:
					GameInput.queue_action()
				elif g.has("join") and p.can_dock() == null and p.can_jump() == null and not p.can_enter_lane().is_empty() and p.global_position.distance_to(g["join"]) < 2500.0:
					GameInput.queue_action()
			elif p.mode == PlayerShip.Mode.LANE:
				var j: Dictionary = p.junction
				var g2: Dictionary = main.gps_info()
				# the GPS arms our exit; only step in if it says to take one that isn't armed
				if not j.is_empty() and j.get("exit", -1) >= 0 and g2.get("junction", -1) == j["node"] and not j["armed"]:
					GameInput.queue_action()
				var txt := str(g2.get("text", ""))
				if g2.get("icon", "") == "exit" and (txt.begins_with("Leave") or txt.begins_with("Drop")) and g2.get("dist", 0.0) < 400.0 and not p.exit_ahead():
					GameInput.queue_action()
		stick = stick.move_toward(want, dt * 3.0)
		GameInput.touch_stick = Vector2(stick.x, -stick.y if Settings.invert_pitch else stick.y)
	return "timed out at mode %d, %s" % [p.mode, str(main.gps_info().get("text", ""))]


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
			if t.oneway and d < 0:
				continue
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

	# --- 0.11 living economy: prices follow stock, trades move them, events bite
	var here: String = GameState.last_station
	var made_g: String = Galaxy.station(here)["makes"][0]
	var p0 := Economy.buy_price(here, made_g)
	GameState.credits += 50000
	var bought := GameState.buy(here, made_g, 12)
	var p1 := Economy.buy_price(here, made_g)
	var sold := GameState.sell(here, made_g)
	print("economy: bought %d %s at %d, price now %d; sold back for %d (profit %d)" % [bought, made_g, p0, p1, sold, GameState.last_profit])
	if bought <= 0 or p1 <= p0:
		return _fail("buying did not raise the price")
	var need: String = Galaxy.station(here)["needs"][0]
	var n0 := Economy.sell_price(here, need)
	Economy.start_event("festival", here, need, 300.0)
	var n1 := Economy.sell_price(here, need)
	print("economy: festival at %s: %s sells %d -> %d" % [here, need, n0, n1])
	if n1 <= n0:
		return _fail("a festival did not raise demand")
	Economy.step(60.0)
	GameState.remember_prices(GameState.system_id)
	var deals: Array = Economy.best_deals(here, GameState.cargo_capacity(), GameState.credits, GameState.price_memory, Economy.clock)
	print("trade computer: ", deals.slice(0, 2).map(func(d): return "%s -> %s +%d/u" % [d["good"], d["to"], d["profit_unit"]]))
	if Economy.news.is_empty():
		return _fail("no news")

	# --- 0.13 people: contracts, bar, factions
	var offers := GameState.missions.filter(func(m): return m["state"] == "offered" and m.get("from", "") == here)
	print("contracts at %s: %s" % [here, str(offers.map(func(m): return m["kind"]))])
	if offers.size() < 3:
		return _fail("station offers fewer than 3 contracts")
	var rum := []
	for i in 3:
		rum.append(Bar.rumour(here, i)["kind"])
	print("bar: %s pours; regulars %s; rumours %s" % [Bar.bartender(here)["name"], str(Bar.regulars(here).map(func(r): return r["name"])), str(rum)])
	main.menu.visible = true
	main.menu._select("bar")
	await _wait(0.3)
	main.menu._do_dice(Button.new(), 50)
	main.menu._select("missions")
	var sup := {"id": 8001, "kind": "supply", "state": "active", "good": "water", "units": 5, "station": here, "title": "test supply", "desc": "", "reward": 999, "faction": "haulers"}
	GameState.missions.append(sup)
	GameState.cargo["water"] = 7
	GameState.cargo_cost["water"] = 700
	var chain := {"id": 8002, "kind": "chain", "state": "active", "station": here, "chain": ["lumen", "halcyon"], "step": 1, "title": "The Parcel (part 1 of 3)", "desc": "", "reward": 500}
	GameState.missions.append(chain)
	var cr_b := GameState.credits
	var notes := GameState.turn_in(here)
	print("turn in: ", notes)
	if GameState.cargo.get("water", 0) != 2 or GameState.credits < cr_b + 1499:
		return _fail("supply / chain contracts did not pay")
	var next := GameState.missions.filter(func(m): return m["kind"] == "chain" and m["step"] == 2)
	if next.is_empty() or next[0]["station"] != "lumen":
		return _fail("chain contract did not continue")
	GameState.missions.erase(next[0])
	var fac := Factions.of_station(here)
	GameState.add_rep(fac, 30)
	GameState.credits += 20000
	if not GameState.buy_licence(fac) or not GameState.has_licence(fac):
		return _fail("could not buy a licence at %d rep" % GameState.get_rep(fac))
	print("faction: %s %s, licence bought" % [fac, Factions.standing(GameState.get_rep(fac))])

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
	for tab in ["missions", "market", "bar", "hangar", "outfit", "workshop", "services"]:
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
	if not await _loop_tests():
		return
	if not await _road_tests():
		return

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
