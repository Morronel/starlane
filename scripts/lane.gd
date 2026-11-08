class_name SpaceLane
extends Node3D
## A glowing space lane. Ships ride it at high speed, steer inside the tube,
## overtake traffic, and choose where to drop out.
## Lane coordinates: s = meters along the curve, offset = Vector2 in the lane frame.

const RADIUS := 150.0
const TRAFFIC_SIDE := 70.0
const MERGE_RANGE := 240.0   # manual ENTER LANE works this close to the lane axis

var curve := Curve3D.new()
var length := 0.0
var exits: Array = []   # [{name, s}]
var traffic: Array = [] # [{node, s, dir, speed, offset}]
var lane_mat: ShaderMaterial


func build(points: Array, exit_defs: Array) -> void:
	# points: Array of Vector3. Build smooth handles automatically.
	for i in points.size():
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tan := (next - prev) * 0.25
		curve.add_point(p, -tan, tan)
	curve.bake_interval = 30.0
	length = curve.get_baked_length()
	for e in exit_defs:
		var s := curve.get_closest_offset(e["pos"])
		exits.append({"name": e["name"], "s": s, "color": e.get("color", Color(0.3, 0.9, 1.0))})
	_build_tube()
	_build_gates()
	_spawn_traffic()


## Lane frame at s: origin, right, up, forward.
func frame(s: float) -> Dictionary:
	s = clampf(s, 0.0, length)
	var p := curve.sample_baked(s, true)
	var a := curve.sample_baked(clampf(s - 5.0, 0.0, length), true)
	var b := curve.sample_baked(clampf(s + 5.0, 0.0, length), true)
	var fwd := (b - a).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return {"origin": p, "right": right, "up": up, "fwd": fwd}


func lane_to_world(s: float, offset: Vector2) -> Vector3:
	var f := frame(s)
	return f["origin"] + f["right"] * offset.x + f["up"] * offset.y


## Closest point on the lane axis: {s, dist, pos}.
func closest(pos: Vector3) -> Dictionary:
	var s := curve.get_closest_offset(pos)
	var p := curve.sample_baked(s, true)
	return {"s": s, "dist": p.distance_to(pos), "pos": p}


## Nearest named exit (stations, gates, beacon).
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
		if d > 1.0 and d < best_d:
			best_d = d
			best = {"name": e["name"], "s": e["s"], "dist": d}
	return best


func _build_tube() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 18
	var step := 60.0
	var n := int(ceil(length / step))
	var rings := []
	for i in n + 1:
		var s := minf(i * step, length)
		var f := frame(s)
		var ring := []
		for k in sides + 1:
			var a := TAU * k / sides
			var dir: Vector3 = f["right"] * cos(a) + f["up"] * sin(a)
			ring.append([f["origin"] + dir * RADIUS, dir, Vector2(s, float(k) / sides)])
		rings.append(ring)
	for i in n:
		for k in sides:
			var q := [rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[idx][1])
				st.set_uv(q[idx][2])
				st.add_vertex(q[idx][0])
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	lane_mat = ShaderMaterial.new()
	lane_mat.shader = load("res://shaders/lane.gdshader")
	mi.material_override = lane_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	# bright core line so the lane reads from far away
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var f0 := frame(i * step)
		var f1 := frame(minf((i + 1) * step, length))
		for ax in [f0["right"], f0["up"]]:
			var w: Vector3 = ax * 3.0
			var a0: Vector3 = f0["origin"] - w
			var a1: Vector3 = f0["origin"] + w
			var b0: Vector3 = f1["origin"] - w
			var b1: Vector3 = f1["origin"] + w
			for v in [a0, a1, b1, a0, b1, b0]:
				core.add_vertex(v)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(0.25, 0.7, 1.0)
	cm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	cm.distance_fade_min_distance = 80.0
	cm.distance_fade_max_distance = 900.0
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var cmi := MeshInstance3D.new()
	cmi.mesh = core.commit()
	cmi.material_override = cm
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cmi)


func _build_gates() -> void:
	for e in exits:
		var f := frame(e["s"])
		var g := MeshInstance3D.new()
		g.mesh = Models.gate_ring(e["color"])
		add_child(g)
		var sc := RADIUS / 46.0 * 1.08
		g.global_transform = Transform3D(Basis.looking_at(f["fwd"], f["up"]).scaled(Vector3.ONE * sc), f["origin"])


func _spawn_traffic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for dir in [1, -1]:
		var count := 22
		for i in count:
			var node := MeshInstance3D.new()
			node.mesh = Models.freighter(rng.randi())
			add_child(node)
			var s := length * (float(i) + rng.randf() * 0.6) / count
			traffic.append({
				"node": node, "s": s, "dir": dir,
				"speed": rng.randf_range(220.0, 300.0),
				"offset": Vector2(TRAFFIC_SIDE * dir + rng.randf_range(-22, 22), rng.randf_range(-35, 35)),
			})


func _process(delta: float) -> void:
	for t in traffic:
		t["s"] += t["dir"] * t["speed"] * delta
		if t["s"] > length:
			t["s"] -= length
		elif t["s"] < 0.0:
			t["s"] += length
		var f := frame(t["s"])
		var pos: Vector3 = f["origin"] + f["right"] * t["offset"].x + f["up"] * t["offset"].y
		var fwd: Vector3 = f["fwd"] * t["dir"]
		var node: Node3D = t["node"]
		node.global_transform = Transform3D(Basis.looking_at(fwd, f["up"]), pos)


## Traffic the ship hit while moving from s0 to s1 at `offset` (swept, so fast
## ships can't tunnel through freighters), or {}.
func traffic_hit(s0: float, s1: float, offset: Vector2) -> Dictionary:
	var lo := minf(s0, s1) - 16.0
	var hi := maxf(s0, s1) + 16.0
	for t in traffic:
		if t["s"] > lo and t["s"] < hi and (t["offset"] as Vector2).distance_to(offset) < 7.0:
			return t
	return {}


## Is a lane position close behind/ahead of traffic (used by the autopilot to dodge)?
func traffic_near(s: float, dir: int, offset: Vector2, look: float) -> Dictionary:
	for t in traffic:
		var d: float = (t["s"] - s) * dir
		if d > 0.0 and d < look and (t["offset"] as Vector2).distance_to(offset) < 14.0:
			return t
	return {}
