class_name SpaceLane
extends Node3D
## One track of a system's travel network: a small ROAD or a grand HIGHWAY.
## Ships ride it at high speed, steer inside the tube, overtake traffic and
## pick a branch at the junction at either end (see RoadNet).
## Track coordinates: s = meters along the curve, offset = Vector2 in the track frame.
## In turns the ship is pushed toward the outside wall (see drift()); hold the
## inside line or slow down, or you get thrown off.

## Per-kind tuning. speed = manual cap at full throttle, boost = extra on boost,
## ap = autopilot cruise, accel = how quickly speed follows (1/s),
## steer = sideways steering rate inside the tube (m/s),
## grip = how hard turns push you outward (higher = gentler).
const KINDS := {
	"road": {"radius": 130.0, "merge": 260.0, "min": 280.0, "speed": 900.0, "boost": 380.0, "ap": 720.0,
		"accel": 1.1, "steer": 260.0, "grip": 1.5, "label": "ROAD"},
	"highway": {"radius": 420.0, "merge": 640.0, "min": 900.0, "speed": 4000.0, "boost": 1600.0, "ap": 3100.0,
		"accel": 0.42, "steer": 430.0, "grip": 4.9, "label": "HIGHWAY"},
}
const TRAFFIC_SIDE := 0.45   # traffic rides at this fraction of the radius, right of centre

var kind := "road"
var radius := 130.0
var node_a := -1
var node_b := -1
var curve := Curve3D.new()
var length := 0.0
var aabb := AABB()
var exits: Array = []   # [{name, s, color}] at both ends
var traffic: Array = [] # [{node, s, dir, speed, offset}]
var _kappa := PackedVector3Array()   # every KSTEP m: (centre dir in frame x, y, curvature 1/m)
const KSTEP := 50.0
var _traffic_tick := 0


func spec() -> Dictionary:
	return KINDS[kind]


func build(points: Array, exit_defs: Array, mats: Dictionary, traffic_meshes: Array, seed_val: int) -> void:
	radius = KINDS[kind]["radius"]
	for i in points.size():
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tan := (next - prev) / 6.0
		curve.add_point(p, -tan, tan)
	curve.bake_interval = 30.0 if kind == "road" else 45.0
	length = curve.get_baked_length()
	aabb = AABB(points[0], Vector3.ZERO)
	for p in curve.get_baked_points():
		aabb = aabb.expand(p)
	aabb = aabb.grow(radius)
	for e in exit_defs:
		var s := curve.get_closest_offset(e["pos"])
		exits.append({"name": e["name"], "s": s, "color": e.get("color", Color(0.3, 0.9, 1.0))})
	_bake_curvature()
	_build_tube(mats)
	_spawn_traffic(traffic_meshes, seed_val)


## Track frame at s: origin, right, up, forward.
func frame(s: float) -> Dictionary:
	s = clampf(s, 0.0, length)
	var p := curve.sample_baked(s, true)
	# a wide tangent baseline keeps the frame (and anything offset far from the
	# axis, like a ship near the wall) from wobbling between baked points
	var a := curve.sample_baked(clampf(s - 25.0, 0.0, length), true)
	var b := curve.sample_baked(clampf(s + 25.0, 0.0, length), true)
	var fwd := (b - a).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return {"origin": p, "right": right, "up": up, "fwd": fwd}


func lane_to_world(s: float, offset: Vector2) -> Vector3:
	var f := frame(s)
	return f["origin"] + f["right"] * offset.x + f["up"] * offset.y


## Closest point on the track axis: {s, dist, pos}.
func closest(pos: Vector3) -> Dictionary:
	var s := curve.get_closest_offset(pos)
	var p := curve.sample_baked(s, true)
	return {"s": s, "dist": p.distance_to(pos), "pos": p, "track": self}


func _bake_curvature() -> void:
	var n := int(ceil(length / KSTEP)) + 1
	_kappa.resize(n)
	for i in n:
		var s := minf(i * KSTEP, length)
		var f := frame(s)
		var f0 := frame(maxf(s - 120.0, 0.0))
		var f1 := frame(minf(s + 120.0, length))
		var span := minf(s + 120.0, length) - maxf(s - 120.0, 0.0)
		var turn: Vector3 = f1["fwd"] - f0["fwd"]
		var k := turn.length() / maxf(span, 1.0)
		var c2 := Vector2(turn.dot(f["right"]), turn.dot(f["up"]))
		c2 = c2.normalized() if c2.length() > 0.00001 else Vector2.ZERO
		_kappa[i] = Vector3(c2.x, c2.y, k)


## Curvature at s: Vector3(centre direction x, y in the track frame, 1/turn radius).
func curvature(s: float) -> Vector3:
	var i := clampi(int(round(s / KSTEP)), 0, _kappa.size() - 1)
	return _kappa[i]


## Sharpest curvature in [s, s + dir * look].
func max_curvature_ahead(s: float, dir: int, look: float) -> float:
	var k := 0.0
	var d := 0.0
	while d <= look:
		k = maxf(k, curvature(s + dir * d).z)
		d += KSTEP * 2.0
	return k


## Sideways push (track-frame m/s) at speed v: toward the outside of the turn.
func drift(s: float, v: float) -> Vector2:
	var c := curvature(s)
	return -Vector2(c.x, c.y) * (v * v * c.z / float(KINDS[kind]["grip"]))


## Fastest speed the autopilot is comfortable with for curvature k.
func safe_speed(k: float) -> float:
	if k < 0.000001:
		return INF
	var sp: Dictionary = KINDS[kind]
	return sqrt(0.55 * sp["steer"] * sp["grip"] / k)


func nearest_entry(pos: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	for e in exits:
		var p := curve.sample_baked(e["s"], true)
		var d := p.distance_to(pos)
		if d < best_d:
			best_d = d
			best = {"name": e["name"], "s": e["s"], "dist": d, "pos": p}
	return best


func next_exit(s: float, dir: int) -> Dictionary:
	var best := {}
	var best_d := INF
	for e in exits:
		var d: float = (e["s"] - s) * dir
		if d > -1.0 and d < best_d:
			best_d = d
			best = {"name": e["name"], "s": e["s"], "dist": maxf(d, 0.0)}
	return best


# --- Look --------------------------------------------------------------------------

func _build_tube(mats: Dictionary) -> void:
	var hw := kind == "highway"
	var sides := 18 if hw else 10
	var step := 160.0 if hw else 110.0
	var n := int(ceil(length / step))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n + 1:
		var s := minf(i * step, length)
		var f := frame(s)
		for k in sides + 1:
			var a := TAU * k / sides
			var dir: Vector3 = f["right"] * cos(a) + f["up"] * sin(a)
			st.set_normal(dir)
			st.set_uv(Vector2(s, float(k) / sides))
			st.add_vertex(f["origin"] + dir * radius)
	for i in n:
		for k in sides:
			var a0 := i * (sides + 1) + k
			var b0 := (i + 1) * (sides + 1) + k
			for idx in [a0, a0 + 1, b0 + 1, a0, b0 + 1, b0]:
				st.add_index(idx)
	_add_mesh(st.commit(), mats["tube_" + kind])

	# bright core line(s) so the track reads from far away: highways get a
	# wide double core, roads a thin single one
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cstep := 200.0
	var cn := int(ceil(length / cstep))
	var w := 26.0 if hw else 6.0
	var lanes := [-0.22, 0.22] if hw else [0.0]
	for i in cn:
		var f0 := frame(i * cstep)
		var f1 := frame(minf((i + 1) * cstep, length))
		for lx in lanes:
			var o0: Vector3 = f0["origin"] + f0["right"] * radius * lx
			var o1: Vector3 = f1["origin"] + f1["right"] * radius * lx
			for ax in [[f0["right"], f1["right"]], [f0["up"], f1["up"]]]:
				var w0: Vector3 = ax[0] * w
				var w1: Vector3 = ax[1] * w
				for v in [o0 - w0, o0 + w0, o1 + w1, o0 - w0, o1 + w1, o1 - w1]:
					core.add_vertex(v)
	_add_mesh(core.commit(), mats["core_" + kind])

	# structure along the track: big pylon rings on highways, small studs on roads
	var deco := SurfaceTool.new()
	deco.begin(Mesh.PRIMITIVE_TRIANGLES)
	if hw:
		var gap := 5000.0
		var cnt := maxi(1, int(length / gap))
		for i in cnt:
			var s := (i + 0.5) * length / cnt
			var f := frame(s)
			var seg := 40
			for k in seg:
				var a0 := TAU * k / seg
				var a1 := TAU * (k + 1) / seg
				var d0: Vector3 = f["right"] * cos(a0) + f["up"] * sin(a0)
				var d1: Vector3 = f["right"] * cos(a1) + f["up"] * sin(a1)
				var ri := radius * 1.02
				var ro := radius * 1.12
				var z: Vector3 = f["fwd"] * 14.0
				for v in [d0 * ri - z, d0 * ro - z, d1 * ro - z, d0 * ri - z, d1 * ro - z, d1 * ri - z,
						d0 * ri + z, d1 * ro + z, d0 * ro + z, d0 * ri + z, d1 * ri + z, d1 * ro + z]:
					deco.add_vertex(f["origin"] + v)
	else:
		var gap := 700.0
		var cnt := maxi(1, int(length / gap))
		for i in cnt:
			var s := (i + 0.5) * length / cnt
			var f := frame(s)
			for a in [0.25, 0.75, 1.25, 1.75]:
				var d: Vector3 = f["right"] * cos(a * PI) + f["up"] * sin(a * PI)
				var c: Vector3 = f["origin"] + d * radius
				var t1: Vector3 = f["fwd"] * 9.0
				var t2: Vector3 = d.cross(f["fwd"]) * 9.0
				for v in [c - t1, c + t2, c + t1, c - t1, c + t1, c - t2]:
					deco.add_vertex(v)
	_add_mesh(deco.commit(), mats["deco_" + kind])

	# junction rings at both ends
	for e in exits:
		var f := frame(e["s"])
		var g := MeshInstance3D.new()
		g.mesh = mats["ring_" + kind]
		add_child(g)
		var sc := radius / 46.0 * 1.1
		g.global_transform = Transform3D(Basis.looking_at(f["fwd"], f["up"]).scaled(Vector3.ONE * sc), f["origin"])


func _add_mesh(mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _spawn_traffic(meshes: Array, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var hw := kind == "highway"
	var count := clampi(int(length / (7000.0 if hw else 9000.0)), 1, 9)
	for dir in [1, -1]:
		for i in count:
			var node := MeshInstance3D.new()
			node.mesh = meshes[rng.randi() % meshes.size()]
			if hw:
				node.scale = Vector3.ONE * 1.6
			add_child(node)
			var s := length * (float(i) + rng.randf() * 0.6) / count
			var side := radius * TRAFFIC_SIDE
			traffic.append({
				"node": node, "s": s, "dir": dir,
				"speed": rng.randf_range(650.0, 900.0) if hw else rng.randf_range(200.0, 290.0),
				"offset": Vector2(side * dir + rng.randf_range(-0.15, 0.15) * radius, rng.randf_range(-0.25, 0.25) * radius),
			})


func _process(delta: float) -> void:
	# far-away tracks only update their traffic now and then
	var cam := get_viewport().get_camera_3d()
	var far := cam != null and not aabb.grow(20000.0).has_point(cam.global_position)
	_traffic_tick += 1
	if far and _traffic_tick % 15 != 0:
		return
	var dt := delta * (15.0 if far else 1.0)
	for t in traffic:
		t["s"] += t["dir"] * t["speed"] * dt
		if t["s"] > length:
			t["s"] -= length
		elif t["s"] < 0.0:
			t["s"] += length
		var f := frame(t["s"])
		var pos: Vector3 = f["origin"] + f["right"] * t["offset"].x + f["up"] * t["offset"].y
		var fwd: Vector3 = f["fwd"] * t["dir"]
		var node: Node3D = t["node"]
		node.global_transform = Transform3D(Basis.looking_at(fwd, f["up"]).scaled(node.scale), pos)


## Traffic the ship hit while moving from s0 to s1 at `offset` (swept, so fast
## ships can't tunnel through freighters), or {}.
func traffic_hit(s0: float, s1: float, offset: Vector2) -> Dictionary:
	var lo := minf(s0, s1) - 20.0
	var hi := maxf(s0, s1) + 20.0
	var r := 7.0 if kind == "road" else 11.0
	for t in traffic:
		if t["s"] > lo and t["s"] < hi and (t["offset"] as Vector2).distance_to(offset) < r:
			return t
	return {}


## Is a track position close behind/ahead of traffic (used by the autopilot to dodge)?
func traffic_near(s: float, dir: int, offset: Vector2, look: float) -> Dictionary:
	var r := 16.0 if kind == "road" else 24.0
	for t in traffic:
		var d: float = (t["s"] - s) * dir
		if d > 0.0 and d < look and (t["offset"] as Vector2).distance_to(offset) < r:
			return t
	return {}
