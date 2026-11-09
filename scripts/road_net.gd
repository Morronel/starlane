class_name RoadNet
extends Node3D
## A star system's travel network: a graph of nodes (interchanges, crossroads,
## and the approaches to stations, gates and the beacon) joined by tracks.
## Grand highways link the interchanges; plenty of small roads connect
## everything else. Also plans autopilot routes across it.

const MERGE_PENALTY := 3.0     # seconds the planner adds for joining a track
const JUNCTION_PENALTY := 0.4
const AP_EFFICIENCY := 0.85    # autopilot slows in turns, so ride a bit slower than cruise

var nodes: Array = []    # [{id, name, pos, kind ("hub" / "cross" / "poi"), edges: [SpaceLane]}]
var tracks: Array = []   # [SpaceLane]
var mats := {}
var _traffic_meshes: Array = []
var _goal_cache := {}    # goal Vector3 -> [{track, s, dist}]
var _pending: Array = [] # [{a, b, kind, bulge}] until build_nodes() lays the tracks out
var _rng: RandomNumberGenerator
var _allowed_cache := {}

const MAX_TURN_DEG := 55.0   # sharpest turn a junction offers
const FAN_DEG := 18.0        # tracks leave a junction within +-this of its axis


func _init() -> void:
	for kind in ["road", "highway"]:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/lane.gdshader")
		mats["tube_" + kind] = m
		var c := StandardMaterial3D.new()
		c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		c.distance_fade_min_distance = 80.0
		c.distance_fade_max_distance = 2400.0 if kind == "road" else 6000.0
		c.cull_mode = BaseMaterial3D.CULL_DISABLED
		c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		c.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mats["core_" + kind] = c
		var d := c.duplicate() as StandardMaterial3D
		d.distance_fade_min_distance = 30.0
		d.distance_fade_max_distance = 900.0
		mats["deco_" + kind] = d
	var hw: ShaderMaterial = mats["tube_highway"]
	hw.set_shader_parameter("rails", 12.0)
	hw.set_shader_parameter("rim_strength", 0.15)
	hw.set_shader_parameter("swell_strength", 0.03)
	hw.set_shader_parameter("rail_strength", 0.08)
	var rd: ShaderMaterial = mats["tube_road"]
	rd.set_shader_parameter("rails", 6.0)
	rd.set_shader_parameter("rim_strength", 0.08)
	rd.set_shader_parameter("swell_strength", 0.0)
	rd.set_shader_parameter("rail_strength", 0.06)
	for i in 4:
		_traffic_meshes.append(Models.freighter(1000 + i * 77))


## Tint the network with the current system's palette (soft, never neon).
## Roads take the cooler sky colours; highways the same hue pushed toward
## warm white, so they read as brighter, grander lines.
func set_palette(sky: Dictionary) -> void:
	var c1 := _soften(sky["c"])
	var c2 := _soften((sky["b"] as Color).lerp(sky["c"], 0.35))
	var h1 := c1.lerp(Color(1.0, 0.88, 0.62), 0.45)
	var h2 := c1.lerp(Color(1.0, 0.97, 0.9), 0.3)
	_tint("road", c2, c2.lerp(c1, 0.5))
	_tint("highway", h1, h2)
	mats["ring_road"] = Models.gate_ring(c2, SpaceLane.KINDS["road"]["radius"] * 1.1)
	mats["ring_highway"] = Models.gate_ring(h1, SpaceLane.KINDS["highway"]["radius"] * 1.1)


func _tint(kind: String, a: Color, b: Color) -> void:
	var m: ShaderMaterial = mats["tube_" + kind]
	m.set_shader_parameter("color", Vector3(a.r, a.g, a.b))
	m.set_shader_parameter("color2", Vector3(b.r, b.g, b.b))
	# the tubes are big now, so everything on them glows more softly
	(mats["core_" + kind] as StandardMaterial3D).albedo_color = a * (0.28 if kind == "road" else 0.4)
	(mats["deco_" + kind] as StandardMaterial3D).albedo_color = b * (0.9 if kind == "road" else 0.55)


static func _soften(c: Color) -> Color:
	var m := maxf(c.r, maxf(c.g, c.b))
	if m > 0.001:
		c = c / m
	return c.lerp(Color(0.85, 0.9, 1.0), 0.25)


func set_intensity(riding: SpaceLane) -> void:
	for kind in ["road", "highway"]:
		var dim: bool = riding != null and riding.kind == kind
		(mats["tube_" + kind] as ShaderMaterial).set_shader_parameter("intensity", 0.7 if dim else 1.0)


# --- Building ------------------------------------------------------------------

func add_node(name: String, pos: Vector3, kind: String, color := Color(0.4, 0.9, 1.0)) -> int:
	nodes.append({"id": nodes.size(), "name": name, "pos": pos, "kind": kind, "edges": [], "color": color, "links": []})
	return nodes.size() - 1


func has_edge(a: int, b: int) -> bool:
	return nodes[a]["links"].has(b)


## Queue a winding track from node a to node b; it is laid out in
## build_nodes() once every junction knows all of its tracks. bulge bends the
## whole track sideways (used for the highway ring).
func add_track(a: int, b: int, kind: String, rng: RandomNumberGenerator, bulge := Vector3.ZERO) -> void:
	_rng = rng
	_pending.append({"a": a, "b": b, "kind": kind, "bulge": bulge})
	nodes[a]["links"].append(b)
	nodes[b]["links"].append(a)


## Every junction gets an axis. Its tracks leave along that axis, half one way
## and half the other, fanned out within +-FAN_DEG in the horizontal plane and
## ordered as they really lie. Riding in from one side you can carry on to any
## track on the far side with a turn of at most MAX_TURN_DEG, and the fan
## spreads them left to right so the lane you hold picks the branch.
func _layout_junctions() -> void:
	for n in nodes.size():
		var ends := []   # [{e (pending index), end ("a"/"b"), dir}]
		for ei in _pending.size():
			var e: Dictionary = _pending[ei]
			for end in ["a", "b"]:
				if e[end] != n:
					continue
				var other: int = e["b"] if end == "a" else e["a"]
				var d: Vector3 = (nodes[other]["pos"] as Vector3) - (nodes[n]["pos"] as Vector3) + (e["bulge"] as Vector3) * 0.6
				d.y = 0.0
				ends.append({"e": ei, "end": end, "dir": d.normalized()})
		if ends.is_empty():
			continue
		# axis that the tracks line up with best, with both sides used
		var best_u := Vector3.ZERO
		var best_sc := -1.0
		for k in 72:
			var u := Vector3(cos(k * PI / 72.0), 0, sin(k * PI / 72.0))
			var sc := 0.0
			var pos_n := 0
			for en in ends:
				var dt: float = (en["dir"] as Vector3).dot(u)
				sc += absf(dt)
				if dt > 0.0:
					pos_n += 1
			if ends.size() >= 2 and (pos_n == 0 or pos_n == ends.size()):
				continue
			if sc > best_sc:
				best_sc = sc
				best_u = u
		if best_u == Vector3.ZERO or ends.size() == 1:
			best_u = ends[0]["dir"]
		nodes[n]["axis"] = best_u
		for side in [1.0, -1.0]:
			var axis: Vector3 = best_u * side
			var group := []
			for en in ends:
				if signf((en["dir"] as Vector3).dot(best_u)) == side or (ends.size() == 1):
					en["ang"] = axis.signed_angle_to(en["dir"], Vector3.UP)
					group.append(en)
			group.sort_custom(func(x, y): return x["ang"] < y["ang"])
			var m := group.size()
			var spread := deg_to_rad(minf(FAN_DEG, 14.0 * (m - 1)))
			for i in m:
				var a := 0.0 if m == 1 else lerpf(-spread, spread, float(i) / (m - 1))
				var tan := axis.rotated(Vector3.UP, a)
				_pending[group[i]["e"]]["t_" + group[i]["end"]] = tan
			if ends.size() == 1:
				break


func _build_tracks() -> void:
	_layout_junctions()
	for e in _pending:
		_lay_track(e["a"], e["b"], e["kind"], _rng, e["bulge"], e.get("t_a", Vector3.ZERO), e.get("t_b", Vector3.ZERO))
	_pending.clear()


## Lay out the track as a Hermite curve that leaves each junction along its
## assigned fan direction, plus gentle wiggles in the middle.
func _lay_track(a: int, b: int, kind: String, rng: RandomNumberGenerator, bulge: Vector3, ta: Vector3, tb: Vector3) -> SpaceLane:
	var pa: Vector3 = nodes[a]["pos"]
	var pb: Vector3 = nodes[b]["pos"]
	var d := pb - pa
	var L := d.length()
	var fwd := d / L
	if ta == Vector3.ZERO:
		ta = fwd
	if tb == Vector3.ZERO:
		tb = -fwd
	var side := fwd.cross(Vector3.UP).normalized()
	var up := side.cross(fwd).normalized()
	var hw := kind == "highway"
	var half_wave := 26000.0 if hw else 9000.0
	var waves := maxf(1.0, round(L / half_wave))
	var amp := (rng.randf_range(1200.0, 1800.0) if hw else rng.randf_range(300.0, 600.0)) * minf(1.0, L / (half_wave * 1.5))
	var ph := rng.randf() * TAU
	var flip := 1.0 if rng.randf() < 0.5 else -1.0
	var vamp := rng.randf_range(150.0, 450.0) if hw else rng.randf_range(80.0, 300.0)
	var k_lim := 1.0 / (8000.0 if not hw else 20000.0)
	var n := maxi(10, int(L / (600.0 if hw else 300.0)))
	# 1) the base curve: leave each junction on its fan line, but if that
	# bends harder than k_lim, ease the end directions toward the straight
	# line until it doesn't (a slightly bigger junction turn is far easier to
	# fly than a tight bend in the middle of nowhere)
	var pts := []
	var relax := 1.0
	var tlen := L
	var ta0 := ta
	var tb0 := tb
	for attempt in 10:
		ta = fwd.slerp(ta0, relax).normalized() if ta0.dot(fwd) > -0.99 else ta0
		tb = (-fwd).slerp(tb0, relax).normalized() if tb0.dot(-fwd) > -0.99 else tb0
		# the best tangent length depends on the shape (C or S bend), so try a few
		var best_k := INF
		for c in [0.9, 1.15, 1.4]:
			var cand := _hermite_pts(pa, pb, ta * L * c, -tb * L * c, n, bulge, Vector3.ZERO, 0.0, 1.0, 1.0, Vector3.ZERO, 0.0, 0.0)
			var kc := _kmax(cand)
			if kc < best_k:
				best_k = kc
				pts = cand
				tlen = L * c
		if best_k <= k_lim * 0.85 or relax <= 0.0:
			break
		relax = maxf(0.0, relax - 0.12)
	# 2) gentle wiggles on top, scaled down until the whole track stays under k_lim
	var scale := 1.0
	for attempt in 8:
		pts = _hermite_pts(pa, pb, ta * tlen, -tb * tlen, n, bulge, side, amp * scale, waves, flip, up, vamp * scale, ph)
		var kmax := _kmax(pts)
		if kmax <= k_lim:
			break
		scale *= clampf(k_lim / kmax, 0.3, 0.9)
		if attempt == 7:
			pts = _hermite_pts(pa, pb, ta * tlen, -tb * tlen, n, bulge, side, 0.0, waves, flip, up, 0.0, ph)
	var t := SpaceLane.new()
	t.kind = kind
	t.node_a = a
	t.node_b = b
	t.name = "%s_%d_%d" % [kind, a, b]
	add_child(t)
	t.build(pts, [
		{"name": nodes[a]["name"], "pos": pa, "color": nodes[a]["color"]},
		{"name": nodes[b]["name"], "pos": pb, "color": nodes[b]["color"]},
	], mats, _traffic_meshes, rng.randi())
	nodes[a]["edges"].append(t)
	nodes[b]["edges"].append(t)
	tracks.append(t)
	return t


func _hermite_pts(pa: Vector3, pb: Vector3, m0: Vector3, m1: Vector3, n: int, bulge: Vector3,
		side: Vector3, amp: float, waves: float, flip: float, up: Vector3, vamp: float, ph: float) -> Array:
	var pts := []
	# the bulge is a smooth arch (no kink in its curvature); take its slope at
	# the ends out of the end tangents so the track still leaves on its fan line
	m0 -= bulge * PI
	m1 += bulge * PI
	for i in n + 1:
		var f := float(i) / n
		var f2 := f * f
		var f3 := f2 * f
		var base := pa * (2 * f3 - 3 * f2 + 1) + m0 * (f3 - 2 * f2 + f) + pb * (-2 * f3 + 3 * f2) + m1 * (f3 - f2)
		# wiggles fade out well before the ends so tracks leave junctions on their fan line
		var env := pow(sin(f * PI), 3.0)
		var wig := sin(f * PI * waves) * env * flip
		pts.append(base + side * (wig * amp) + up * (sin(f * TAU + ph) * vamp * env) + bulge * sin(f * PI))
	return pts


## Sharpest bend (1/m) of a polyline.
static func _kmax(pts: Array) -> float:
	var kmax := 0.0
	for i in range(1, pts.size() - 1):
		var u: Vector3 = pts[i] - pts[i - 1]
		var w: Vector3 = pts[i + 1] - pts[i]
		kmax = maxf(kmax, u.angle_to(w) / ((u.length() + w.length()) * 0.5))
	return kmax


## Junction structures: a slowly turning double ring at interchanges, a
## single ring at crossroads.
func build_nodes(sky: Dictionary) -> void:
	_build_tracks()
	for nd in nodes:
		if nd["kind"] == "poi":
			continue
		var hub: bool = nd["kind"] == "hub"
		var holder := Node3D.new()
		add_child(holder)
		holder.global_position = nd["pos"]
		var sc := 1.12   # just outside the tube-sized junction rings
		for k in (3 if hub else 1):
			var mi := MeshInstance3D.new()
			mi.mesh = mats["ring_highway" if hub else "ring_road"]
			mi.scale = Vector3.ONE * sc * (1.0 + k * 0.12)
			mi.rotation = Vector3(k * PI / 3.0, k * 0.7, 0.0)
			holder.add_child(mi)
		var spin := SpinNode.new()
		spin.rate = 0.05 if hub else 0.12
		holder.add_child(spin)


class SpinNode extends Node:
	var rate := 0.1
	func _process(delta: float) -> void:
		var p := get_parent() as Node3D
		if p:
			p.rotate_y(rate * delta)


# --- Queries -------------------------------------------------------------------

## Closest point on any track within max_dist of the axis: {track, s, dist, pos} or {}.
func closest(pos: Vector3, max_dist := INF, kind := "") -> Dictionary:
	var best := {}
	var best_d := max_dist
	for t in tracks:
		if kind != "" and t.kind != kind:
			continue
		if max_dist < INF and not t.aabb.grow(max_dist).has_point(pos):
			continue
		var c: Dictionary = t.closest(pos)
		# prefer highways where tubes overlap: they're the bigger, faster ride
		var d: float = c["dist"] - (t.radius if max_dist < INF else 0.0)
		if d < best_d:
			best_d = d
			best = c
	return best


func end_node(t: SpaceLane, dir: int) -> int:
	return t.node_b if dir > 0 else t.node_a


func node_name(i: int) -> String:
	return nodes[i]["name"] if i >= 0 else ""


## Tracks leaving the node reached by riding t in dir (excluding t itself):
## [{track, dir, s, out (world direction), name, kind}]
func branches(t: SpaceLane, dir: int) -> Array:
	var n := end_node(t, dir)
	var out := []
	for o in nodes[n]["edges"]:
		if o == t:
			continue
		var d := 1 if o.node_a == n else -1
		var s0: float = 0.0 if d > 0 else o.length
		var f: Dictionary = o.frame(s0 + d * 300.0)
		var fe: Dictionary = o.frame(s0)
		var out_dir: Vector3 = (f["origin"] - fe["origin"]).normalized()
		out.append({"track": o, "dir": d, "s": s0, "out": out_dir, "name": node_name(end_node(o, d)), "kind": o.kind})
	return out


## Branches you can actually take arriving by t in dir: turns up to
## MAX_TURN_DEG, sorted left to right, each with its signed turn in degrees
## (negative = left). These are the "lanes" of the junction.
func allowed(t: SpaceLane, dir: int) -> Array:
	var key := "%d_%d" % [t.get_instance_id(), dir]
	if _allowed_cache.has(key):
		return _allowed_cache[key]
	var end_s: float = t.length if dir > 0 else 0.0
	var f := t.frame(end_s)
	var back := t.frame(clampf(end_s - dir * 300.0, 0.0, t.length))
	var arrive: Vector3 = ((f["origin"] as Vector3) - (back["origin"] as Vector3)).normalized()
	var right := arrive.cross(Vector3.UP).normalized()
	var out := []
	var gentlest := {}
	for b in branches(t, dir):
		var o: Vector3 = b["out"]
		var ang := rad_to_deg(arrive.angle_to(o))
		b["turn"] = ang * (1.0 if o.dot(right) > 0.0 else -1.0)
		if ang > MAX_TURN_DEG + 4.0:
			# never strand a rider: if nothing else is in reach, the gentlest
			# way on (short of a U-turn) is still offered
			if ang < 120.0 and (gentlest.is_empty() or ang < absf(gentlest["turn"])):
				gentlest = b
			continue
		out.append(b)
	if out.is_empty() and not gentlest.is_empty():
		out.append(gentlest)
	out.sort_custom(func(x, y): return x["turn"] < y["turn"])
	_allowed_cache[key] = out
	return out


# --- Autopilot route planning ------------------------------------------------------

func _ap_speed(t: SpaceLane) -> float:
	return float(SpaceLane.KINDS[t.kind]["ap"]) * AP_EFFICIENCY


func _goal_points(goal: Vector3) -> Array:
	if _goal_cache.has(goal):
		return _goal_cache[goal]
	if _goal_cache.size() > 16:
		_goal_cache.clear()
	var arr := []
	for t in tracks:
		arr.append(t.closest(goal))
	_goal_cache[goal] = arr
	return arr


## Plans the fastest way to `goal` at free-flight speed `top`.
## From free flight (riding == null) or from riding track `riding` at s in dir.
## Junction turns are limited to the allowed branches, so the search runs over
## directed rides (track, dir) rather than junctions.
## Returns {cost, rides: [{track, dir, enter_s, exit_s}]}; empty rides = fly straight there.
func plan(from: Vector3, goal: Vector3, top: float, riding: SpaceLane = null, s := 0.0, dir := 1) -> Dictionary:
	var dist := {}
	var prev := {}
	var ride_of := {}
	var best := {"cost": from.distance_to(goal) / top, "rides": []}
	var goals := _goal_points(goal)

	if riding == null:
		for ti in tracks.size():
			var t: SpaceLane = tracks[ti]
			var c := t.closest(from)
			var v := _ap_speed(t)
			var fly: float = c["dist"] / top + MERGE_PENALTY
			_seed(dist, prev, ride_of, [t, -1], fly + c["s"] / v, {"track": t, "dir": -1, "enter_s": c["s"], "exit_s": 0.0})
			_seed(dist, prev, ride_of, [t, 1], fly + (t.length - c["s"]) / v, {"track": t, "dir": 1, "enter_s": c["s"], "exit_s": t.length})
			# ride part of this one track and drop out near the goal
			var g: Dictionary = goals[ti]
			var cost: float = fly + absf(g["s"] - c["s"]) / v + g["dist"] / top
			if cost < best["cost"]:
				best = {"cost": cost, "rides": [{"track": t, "dir": 1 if g["s"] >= c["s"] else -1, "enter_s": c["s"], "exit_s": g["s"]}]}
	else:
		var v := _ap_speed(riding)
		var rem: float = (riding.length - s) if dir > 0 else s
		_seed(dist, prev, ride_of, [riding, dir], rem / v, {"track": riding, "dir": dir, "enter_s": s, "exit_s": riding.length if dir > 0 else 0.0})
		var g: Dictionary = goals[tracks.find(riding)]
		var ahead: float = (g["s"] - s) * dir
		best["cost"] = INF
		if ahead > 0.0:
			best = {"cost": ahead / v + g["dist"] / top, "rides": [{"track": riding, "dir": dir, "enter_s": s, "exit_s": g["s"]}]}

	var done := {}
	while true:
		var cur = null
		var cd := INF
		for k in dist:
			if not done.has(k) and dist[k] < cd:
				cd = dist[k]
				cur = k
		if cur == null or cd >= best["cost"]:
			break
		done[cur] = true
		var t0: SpaceLane = cur[0]
		var n := end_node(t0, cur[1])
		# stop at this junction and fly the rest
		var here: float = cd + (nodes[n]["pos"] as Vector3).distance_to(goal) / top
		if here < best["cost"]:
			best = {"cost": here, "rides": _unwind(prev, ride_of, cur)}
		for b in allowed(t0, cur[1]):
			var t: SpaceLane = b["track"]
			var d: int = b["dir"]
			var nk := [t, d]
			var nc: float = cd + t.length / _ap_speed(t) + JUNCTION_PENALTY
			if nc < dist.get(nk, INF):
				dist[nk] = nc
				prev[nk] = cur
				ride_of[nk] = {"track": t, "dir": d, "enter_s": 0.0 if d > 0 else t.length, "exit_s": t.length if d > 0 else 0.0}
			# or ride part of it and drop out near the goal
			var g2: Dictionary = goals[tracks.find(t)]
			var s0: float = 0.0 if d > 0 else t.length
			if (g2["s"] - s0) * d > 0.0:
				var cost: float = cd + JUNCTION_PENALTY + absf(g2["s"] - s0) / _ap_speed(t) + g2["dist"] / top
				if cost < best["cost"]:
					best = {"cost": cost, "rides": _unwind(prev, ride_of, cur) + [{"track": t, "dir": d, "enter_s": s0, "exit_s": g2["s"]}]}
	return best


func _seed(dist: Dictionary, prev: Dictionary, ride_of: Dictionary, key: Array, cost: float, ride: Dictionary) -> void:
	if cost < dist.get(key, INF):
		dist[key] = cost
		prev.erase(key)
		ride_of[key] = ride


func _unwind(prev: Dictionary, ride_of: Dictionary, key: Array) -> Array:
	var out := []
	var guard := 0
	var k = key
	while k != null and guard < 64:
		out.push_front(ride_of[k])
		k = prev.get(k, null)
		guard += 1
	return out
