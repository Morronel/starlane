class_name MeshBuilder
extends RefCounted
## Small procedural mesh kit for flat-shaded low-poly models.
## Every primitive is pushed into a named surface ("hull", "glow", ...) with
## per-vertex colors, and triangles are auto-oriented to face away from a
## reference point so we never have to think about winding order.

var _surfaces := {}   # name -> {"v": PackedVector3Array, "n": PackedVector3Array, "c": PackedColorArray}
var xform := Transform3D.IDENTITY


func _surf(s: String) -> Dictionary:
	if not _surfaces.has(s):
		_surfaces[s] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray()}
	return _surfaces[s]


## Triangle that faces away from `center` (in local, untransformed space).
func tri(s: String, a: Vector3, b: Vector3, c: Vector3, col: Color, center: Vector3) -> void:
	a = xform * a
	b = xform * b
	c = xform * c
	center = xform * center
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot((a + b + c) / 3.0 - center) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	var d := _surf(s)
	d["v"].append_array([a, b, c])
	d["n"].append_array([n, n, n])
	d["c"].append_array([col, col, col])


func quad(s: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, center: Vector3) -> void:
	tri(s, a, b, c, col, center)
	tri(s, a, c, d, col, center)


## Lofted hull along Z. Each section is Vector4(z, half_width, half_height, y_offset).
## `sides` points per elliptical section; ends are capped.
func loft(s: String, sections: Array, sides: int, col: Color, col2: Color = Color(-1, 0, 0), x_off := 0.0, rot := 0.0) -> void:
	if col2.r < 0.0:
		col2 = col
	var rings := []
	for sec in sections:
		var ring := []
		for i in sides:
			var ang := TAU * float(i) / sides + rot
			ring.append(Vector3(x_off + cos(ang) * sec.y, sec.w + sin(ang) * sec.z, sec.x))
		rings.append(ring)
	for r in range(rings.size() - 1):
		var r0: Array = rings[r]
		var r1: Array = rings[r + 1]
		var sec0: Vector4 = sections[r]
		var sec1: Vector4 = sections[r + 1]
		var ctr := Vector3(x_off, (sec0.w + sec1.w) * 0.5, (sec0.x + sec1.x) * 0.5)
		for i in sides:
			var j := (i + 1) % sides
			var colr := col if (r0[i].y + r0[j].y) * 0.5 >= ctr.y else col2
			quad(s, r0[i], r0[j], r1[j], r1[i], colr, ctr)
	# caps
	var first: Vector4 = sections[0]
	var last: Vector4 = sections[sections.size() - 1]
	_cap(s, rings[0], Vector3(x_off, first.w, first.x), col2, Vector3(0, 0, 1))
	_cap(s, rings[rings.size() - 1], Vector3(x_off, last.w, last.x), col2, Vector3(0, 0, -1))


func _cap(s: String, ring: Array, center: Vector3, col: Color, inward: Vector3) -> void:
	var avg := Vector3.ZERO
	for p in ring:
		avg += p
	avg /= ring.size()
	if (ring[0] as Vector3).distance_to(avg) < 0.001:
		return
	for i in ring.size():
		tri(s, avg, ring[i], ring[(i + 1) % ring.size()], col, center + inward)


## Oriented box.
func box(s: String, center: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var p := []
	for i in 8:
		var v := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		p.append(center + basis * v)
	var faces := [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
	for f in faces:
		quad(s, p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, center)


## Wedge / wing: a flat polygon (in XZ plane at height y) extruded by thickness.
func slab(s: String, pts: Array, y: float, thick: float, col: Color, col_bottom: Color = Color(-1, 0, 0)) -> void:
	if col_bottom.r < 0.0:
		col_bottom = col
	var top := []
	var bot := []
	var ctr := Vector3.ZERO
	for q in pts:
		top.append(Vector3(q.x, y + thick * 0.5, q.y))
		bot.append(Vector3(q.x, y - thick * 0.5, q.y))
		ctr += Vector3(q.x, y, q.y)
	ctr /= pts.size()
	for i in range(1, pts.size() - 1):
		tri(s, top[0], top[i], top[i + 1], col, ctr)
		tri(s, bot[0], bot[i], bot[i + 1], col_bottom, ctr)
	for i in pts.size():
		var j := (i + 1) % pts.size()
		quad(s, top[i], top[j], bot[j], bot[i], col_bottom, ctr)


## Cylinder (or cone) from a to b.
func cyl(s: String, a: Vector3, b: Vector3, r1: float, r2: float, sides: int, col: Color, caps := true) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u).normalized()
	var ctr := (a + b) * 0.5
	var ra := []
	var rb := []
	for i in sides:
		var ang := TAU * float(i) / sides
		var d := u * cos(ang) + v * sin(ang)
		ra.append(a + d * r1)
		rb.append(b + d * r2)
	for i in sides:
		var j := (i + 1) % sides
		# orient each side quad away from the axis point at its height
		var mid := ctr
		quad(s, ra[i], ra[j], rb[j], rb[i], col, mid)
	if caps:
		if r1 > 0.0:
			for i in range(1, sides - 1):
				tri(s, ra[0], ra[i], ra[i + 1], col, ctr)
		if r2 > 0.0:
			for i in range(1, sides - 1):
				tri(s, rb[0], rb[i], rb[i + 1], col, ctr)


## Torus around local Y axis.
func torus(s: String, center: Vector3, big_r: float, small_r: float, seg: int, sides: int, col: Color, basis := Basis.IDENTITY, col_inner: Color = Color(-1, 0, 0)) -> void:
	if col_inner.r < 0.0:
		col_inner = col
	var rings := []
	var ctrs := []
	for i in seg:
		var a := TAU * float(i) / seg
		var dir := Vector3(cos(a), 0, sin(a))
		var c := dir * big_r
		ctrs.append(c)
		var ring := []
		for k in sides:
			var b := TAU * float(k) / sides
			ring.append(c + dir * cos(b) * small_r + Vector3.UP * sin(b) * small_r)
		rings.append(ring)
	for i in seg:
		var j := (i + 1) % seg
		var ctr: Vector3 = (ctrs[i] + ctrs[j]) * 0.5
		for k in sides:
			var l := (k + 1) % sides
			var p0: Vector3 = rings[i][k]
			var outer := (p0 - ctr).dot(ctr) > 0.0
			quad(s, center + basis * p0, center + basis * rings[i][l], center + basis * rings[j][l], center + basis * rings[j][k],
				col if outer else col_inner, center + basis * ctr)


## Rough rock: subdivided icosahedron with noise displacement.
func rock(s: String, radius: float, col: Color, rng: RandomNumberGenerator) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	# one subdivision
	var cache := {}
	var nv := []
	for v in verts:
		nv.append((v as Vector3).normalized())
	var nf := []
	for f in faces:
		var m := []
		for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
			var key := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
			if not cache.has(key):
				cache[key] = nv.size()
				nv.append(((nv[e[0]] + nv[e[1]]) * 0.5).normalized())
			m.append(cache[key])
		nf.append([f[0], m[0], m[2]])
		nf.append([f[1], m[1], m[0]])
		nf.append([f[2], m[2], m[1]])
		nf.append([m[0], m[1], m[2]])
	var stretch := Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.4))
	for i in nv.size():
		nv[i] = nv[i] * radius * stretch * rng.randf_range(0.82, 1.12)
	for f in nf:
		var shade := rng.randf_range(0.85, 1.1)
		tri(s, nv[f[0]], nv[f[1]], nv[f[2]], Color(col.r * shade, col.g * shade, col.b * shade), Vector3.ZERO)


## Build the ArrayMesh. `materials` maps surface name -> Material.
func build(materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in _surfaces:
		var d: Dictionary = _surfaces[s]
		if d["v"].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = d["v"]
		arr[Mesh.ARRAY_NORMAL] = d["n"]
		arr[Mesh.ARRAY_COLOR] = d["c"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_name(idx, s)
		if materials.has(s):
			mesh.surface_set_material(idx, materials[s])
	return mesh


# --- Shared materials ---------------------------------------------------------

static var _mat_cache := {}


static func hull_material() -> StandardMaterial3D:
	if not _mat_cache.has("hull"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.55
		m.metallic = 0.35
		m.metallic_specular = 0.6
		_mat_cache["hull"] = m
	return _mat_cache["hull"]


static func glow_material(energy := 4.0) -> Material:
	var key := "glow_%s" % energy
	if not _mat_cache.has(key):
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, fog_disabled;
uniform float energy = 4.0;
void fragment() { ALBEDO = COLOR.rgb * energy; }
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("energy", energy)
		_mat_cache[key] = m
	return _mat_cache[key]


static func rock_material() -> StandardMaterial3D:
	if not _mat_cache.has("rock"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.95
		m.metallic = 0.0
		m.metallic_specular = 0.2
		_mat_cache["rock"] = m
	return _mat_cache["rock"]


static func default_materials() -> Dictionary:
	return {"hull": hull_material(), "glow": glow_material(4.0), "dim": glow_material(1.6)}
