class_name Wonders
extends RefCounted
## 0.12: one sightseeing wonder per system (and the odd comet), built from
## procedural meshes. They're big - a few km - and sit just outside the loop
## so you pass them on the highway and can snap a postcard.


## Additive, unshaded, soft glow for haze, tails and beams.
static func haze_material(col: Color, energy := 1.5) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 tint : source_color;
uniform float energy = 1.5;
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = tint.rgb * energy;
	ALPHA = COLOR.a * (0.25 + 0.75 * (1.0 - rim)) * tint.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("energy", energy)
	return m


static func build(kind: String, a: Color, b: Color, seed_val: int) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var mb := MeshBuilder.new()
	var mats := MeshBuilder.default_materials()
	match kind:
		"geyser":
			# a moon with ice plumes
			mb.rock("hull", 1100.0, a.lerp(Color(0.8, 0.85, 0.95), 0.6), rng)
			for i in 7:
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.0), rng.randf_range(-1, 1)).normalized()
				mb.cyl("glow", d * 1000.0, d * (1500.0 + rng.randf() * 900.0), 60.0, 4.0, 6, Color(0.7, 0.9, 1.0))
			_plumes(root, rng, Color(0.6, 0.85, 1.0, 0.5), 7, 1100.0, 2600.0)
		"arc":
			# half a ring-forge, still glowing in its seams
			var basis := Basis(Vector3.RIGHT, deg_to_rad(70.0))
			for i in 14:
				var a0 := PI * float(i) / 14.0
				var p := basis * Vector3(cos(a0) * 2600.0, 0, sin(a0) * 2600.0)
				var p2 := basis * Vector3(cos(a0 + PI / 14.0) * 2600.0, 0, sin(a0 + PI / 14.0) * 2600.0)
				mb.cyl("hull", p, p2, 260.0, 260.0, 8, Color(0.35, 0.3, 0.28))
				if i % 3 == 1:
					mb.cyl("glow", p, p2, 275.0, 275.0, 8, a)
			mb.box("hull", basis * Vector3(2600, 0, 0), Vector3(700, 700, 900), Color(0.3, 0.27, 0.25))
			mb.box("hull", basis * Vector3(-2600, 0, 0), Vector3(700, 700, 900), Color(0.3, 0.27, 0.25))
			var halo := _sphere(1500.0, Color(a, 0.6))
			halo.material_override = haze_material(Color(a, 0.18), 1.2)
			root.add_child(halo)
		"wreck":
			# a graveyard of broken dreadnoughts
			for k in 4:
				var o := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)) * 1800.0
				var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)).normalized()
				var L := rng.randf_range(1400.0, 2400.0)
				mb.cyl("hull", o - dir * L * 0.5, o + dir * L * 0.2, 160.0, 220.0, 7, Color(0.25, 0.24, 0.27))
				mb.cyl("hull", o + dir * L * 0.35, o + dir * L * 0.55, 200.0, 70.0, 7, Color(0.28, 0.25, 0.25))
				for r in 3:
					mb.box("hull", o + dir * rng.randf_range(-L * 0.4, L * 0.1) + Vector3(0, 200, 0), Vector3(120, 160, 300), Color(0.22, 0.22, 0.25))
				mb.cyl("glow", o + dir * L * 0.2, o + dir * L * 0.24, 60.0, 60.0, 6, b)
		"pillars":
			# luminous nebula columns
			for k in 5:
				var x := rng.randf_range(-2500.0, 2500.0)
				var z := rng.randf_range(-1200.0, 1200.0)
				var h := rng.randf_range(4000.0, 7000.0)
				var col := _cyl_mesh(Vector3(x, -h * 0.5, z), Vector3(x + rng.randf_range(-600, 600), h * 0.5, z), rng.randf_range(500.0, 900.0), rng.randf_range(200.0, 500.0))
				col.material_override = haze_material(Color(a.lerp(b, rng.randf()), 0.35), 1.4)
				root.add_child(col)
			for i in 30:
				var p := Vector3(rng.randf_range(-3000, 3000), rng.randf_range(-3000, 3000), rng.randf_range(-1500, 1500))
				mb.box("glow", p, Vector3.ONE * rng.randf_range(20, 60), Color(1, 0.95, 0.85))
		"crystal":
			for i in 22:
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
				var L := rng.randf_range(900.0, 2600.0)
				mb.cyl("glow" if i % 3 == 0 else "hull", d * 200.0, d * L, rng.randf_range(120.0, 260.0), 0.0, 5, a.lerp(Color(0.85, 0.95, 1.0), rng.randf()))
			mb.rock("hull", 700.0, Color(0.35, 0.4, 0.5), rng)
			var halo := _sphere(2200.0, Color(a, 0.5))
			halo.material_override = haze_material(Color(a, 0.12), 1.3)
			root.add_child(halo)
		"lighthouse":
			mb.cyl("hull", Vector3(0, -2400, 0), Vector3(0, 1400, 0), 380.0, 180.0, 6, Color(0.2, 0.22, 0.2))
			mb.cyl("hull", Vector3(0, 1400, 0), Vector3(0, 2000, 0), 520.0, 520.0, 6, Color(0.25, 0.27, 0.25))
			for i in 6:
				var ang := TAU * i / 6.0
				mb.cyl("hull", Vector3(cos(ang) * 400, -2400, sin(ang) * 400), Vector3(cos(ang) * 1300, -3300, sin(ang) * 1300), 120.0, 60.0, 5, Color(0.2, 0.2, 0.18))
			var lamp := _sphere(420.0, a)
			lamp.position = Vector3(0, 2300, 0)
			lamp.material_override = MeshBuilder.glow_material(5.0)
			lamp.name = "Lamp"
			root.add_child(lamp)
			var beam := _cyl_mesh(Vector3(0, 2300, 0), Vector3(0, 2300, -12000), 200.0, 1600.0)
			beam.material_override = haze_material(Color(a, 0.25), 1.6)
			beam.name = "Beam"
			root.add_child(beam)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(mats)
	root.add_child(mi)
	return root


static func _plumes(root: Node3D, rng: RandomNumberGenerator, col: Color, n: int, r0: float, len: float) -> void:
	for i in n:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.4, 1.0), rng.randf_range(-1, 1)).normalized()
		var c := _cyl_mesh(d * r0, d * (r0 + len), 90.0, 700.0)
		c.material_override = haze_material(col, 1.0)
		root.add_child(c)


static func _sphere(r: float, col: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 24
	m.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	return mi


static func _cyl_mesh(a: Vector3, b: Vector3, r1: float, r2: float) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r1
	m.top_radius = r2
	m.height = a.distance_to(b)
	m.radial_segments = 16
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var up := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(ref).normalized()
	var z := x.cross(up).normalized()
	mi.transform = Transform3D(Basis(x, up, z), (a + b) * 0.5)
	return mi


## A comet: glowing head and a long tail pointing away from the sun.
static func comet(col: Color) -> Node3D:
	var root := Node3D.new()
	var head := _sphere(140.0, col)
	head.material_override = MeshBuilder.glow_material(4.0)
	root.add_child(head)
	var coma := _sphere(520.0, col)
	coma.material_override = haze_material(Color(col, 0.35), 1.5)
	root.add_child(coma)
	for k in 3:
		var tail := _cyl_mesh(Vector3.ZERO, Vector3(k * 300.0 - 300.0, k * 150.0, 9000.0 + k * 2500.0), 300.0, 1600.0 + k * 600.0)
		tail.material_override = haze_material(Color(col.lerp(Color(0.7, 0.85, 1.0), k * 0.4), 0.25 - k * 0.05), 1.3)
		root.add_child(tail)
	return root
