class_name Models
extends RefCounted
## Procedural low-poly models. Ships point down -Z (Godot forward).

const WHITE := Color(0.78, 0.81, 0.86)
const STEEL := Color(0.42, 0.46, 0.53)
const DARK := Color(0.16, 0.17, 0.21)
const CYAN := Color(0.25, 0.9, 1.0)
const AMBER := Color(1.0, 0.62, 0.2)
const RED := Color(1.0, 0.18, 0.12)


static func player_ship() -> ArrayMesh:
	var b := MeshBuilder.new()
	# fuselage: sharp nose, wide middle, flat back
	b.loft("hull", [
		Vector4(-6.0, 0.05, 0.05, 0.1),
		Vector4(-3.5, 0.55, 0.38, 0.15),
		Vector4(-0.5, 1.05, 0.62, 0.2),
		Vector4(2.2, 1.25, 0.7, 0.15),
		Vector4(3.4, 1.0, 0.55, 0.1),
	], 6, WHITE, STEEL)
	# canopy
	b.loft("dim", [
		Vector4(-3.0, 0.05, 0.05, 0.55),
		Vector4(-1.6, 0.38, 0.32, 0.62),
		Vector4(0.2, 0.42, 0.34, 0.66),
		Vector4(1.0, 0.1, 0.1, 0.5),
	], 6, Color(0.12, 0.45, 0.6))
	# swept wings
	var wing := [Vector2(1.0, -1.2), Vector2(4.6, 2.2), Vector2(4.9, 3.3), Vector2(1.0, 2.6)]
	b.slab("hull", wing, 0.0, 0.18, WHITE, STEEL)
	var wing_l := []
	for p in wing:
		wing_l.append(Vector2(-p.x, p.y))
	b.slab("hull", wing_l, 0.0, 0.18, WHITE, STEEL)
	# wing tip fins + accent stripes
	for sx in [-1.0, 1.0]:
		b.slab("hull", [Vector2(4.75 * sx, 1.6), Vector2(4.75 * sx, 3.3), Vector2(4.75 * sx + 0.02 * sx, 3.3)], 0.0, 0.1, STEEL)
		b.box("hull", Vector3(4.75 * sx, 0.45, 2.7), Vector3(0.12, 0.9, 1.2), STEEL, Basis(Vector3.RIGHT, -0.4))
		b.box("glow", Vector3(3.1 * sx, 0.1, 1.6), Vector3(1.6, 0.04, 0.12), CYAN, Basis(Vector3.UP, -0.75 * sx))
		# engine pods
		b.cyl("hull", Vector3(1.1 * sx, 0.05, 0.6), Vector3(1.1 * sx, 0.05, 3.7), 0.42, 0.5, 8, STEEL)
		b.cyl("glow", Vector3(1.1 * sx, 0.05, 3.72), Vector3(1.1 * sx, 0.05, 3.8), 0.38, 0.38, 8, CYAN)
	# dorsal fin
	b.slab("hull", [Vector2(0.0, 0.8), Vector2(0.0, 3.3), Vector2(0.02, 3.3)], 0.6, 0.1, STEEL)
	b.box("hull", Vector3(0, 1.0, 2.6), Vector3(0.12, 1.1, 1.3), STEEL, Basis(Vector3.RIGHT, -0.5))
	return b.build(MeshBuilder.default_materials())


static func raider_ship() -> ArrayMesh:
	var b := MeshBuilder.new()
	var body := Color(0.3, 0.27, 0.28)
	var accent := Color(0.62, 0.16, 0.12)
	b.loft("hull", [
		Vector4(-5.0, 0.05, 0.05, 0.0),
		Vector4(-2.8, 0.7, 0.35, 0.0),
		Vector4(0.6, 1.0, 0.55, 0.0),
		Vector4(2.8, 0.7, 0.45, 0.0),
	], 4, body, DARK, 0.0, PI / 4.0)
	# forward-swept blade wings
	var wing := [Vector2(0.6, 2.4), Vector2(5.0, -1.2), Vector2(5.4, -0.2), Vector2(0.8, 0.0)]
	b.slab("hull", wing, -0.1, 0.16, accent, DARK)
	var wl := []
	for p in wing:
		wl.append(Vector2(-p.x, p.y))
	b.slab("hull", wl, -0.1, 0.16, accent, DARK)
	for sx in [-1.0, 1.0]:
		b.cyl("hull", Vector3(5.2 * sx, -0.1, -2.6), Vector3(5.2 * sx, -0.1, 0.2), 0.14, 0.2, 5, DARK)
		b.box("glow", Vector3(2.6 * sx, 0.0, 0.6), Vector3(1.2, 0.04, 0.1), RED, Basis(Vector3.UP, 0.6 * sx))
	b.cyl("hull", Vector3(0, 0, 1.8), Vector3(0, 0, 3.4), 0.5, 0.62, 6, DARK)
	b.cyl("glow", Vector3(0, 0, 3.42), Vector3(0, 0, 3.5), 0.5, 0.5, 6, Color(1.0, 0.35, 0.15))
	b.box("glow", Vector3(0, 0.36, -2.4), Vector3(0.5, 0.08, 0.6), RED)
	return b.build(MeshBuilder.default_materials())


static func freighter(seed_val: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var b := MeshBuilder.new()
	var hull := Color(0.62, 0.64, 0.66)
	var tints := [Color(0.75, 0.32, 0.18), Color(0.2, 0.42, 0.62), Color(0.78, 0.66, 0.22), Color(0.3, 0.55, 0.36), Color(0.7, 0.72, 0.74)]
	# bridge
	b.loft("hull", [Vector4(-14, 0.5, 0.5, 0), Vector4(-12, 2.2, 1.6, 0.3), Vector4(-8, 2.4, 2.0, 0.3), Vector4(-7, 1.0, 1.0, 0)], 6, hull, STEEL)
	b.box("glow", Vector3(0, 1.3, -12.6), Vector3(2.4, 0.3, 0.2), Color(1.0, 0.85, 0.6))
	# spine
	b.box("hull", Vector3(0, 0, 1.0), Vector3(1.2, 1.2, 18.0), STEEL)
	# containers
	var z := -6.0
	while z < 9.0:
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				if rng.randf() < 0.85:
					b.box("hull", Vector3(sx * 1.6, sy * 1.6, z + 1.4), Vector3(2.0, 2.0, 2.6), tints[rng.randi() % tints.size()])
		z += 3.0
	# engines
	b.cyl("hull", Vector3(0, 0, 10), Vector3(0, 0, 13), 1.6, 2.0, 8, STEEL)
	b.cyl("glow", Vector3(0, 0, 13.02), Vector3(0, 0, 13.1), 1.7, 1.7, 8, Color(0.6, 0.8, 1.0))
	b.box("glow", Vector3(0, 2.8, 4), Vector3(0.25, 0.25, 0.25), RED)
	return b.build(MeshBuilder.default_materials())


## Station hull (static parts) and ring (rotating) as two meshes.
static func station(accent: Color, variant: int) -> Dictionary:
	var hub := MeshBuilder.new()
	var ring := MeshBuilder.new()
	# central spindle along Z (docking bay faces -Z)
	hub.loft("hull", [
		Vector4(-70, 10, 10, 0),
		Vector4(-60, 22, 22, 0),
		Vector4(-30, 26, 26, 0),
		Vector4(20, 26, 26, 0),
		Vector4(40, 18, 18, 0),
		Vector4(90, 10, 10, 0),
		Vector4(110, 16, 16, 0),
		Vector4(130, 4, 4, 0),
	], 8, WHITE, STEEL, 0.0, PI / 8.0)
	# docking bay frame at the front (-Z)
	hub.torus("hull", Vector3(0, 0, -72), 13, 2.2, 16, 6, STEEL, Basis(Vector3.RIGHT, PI / 2.0))
	hub.torus("glow", Vector3(0, 0, -74.5), 11.5, 0.5, 16, 4, accent, Basis(Vector3.RIGHT, PI / 2.0))
	# bay approach lights
	for i in 6:
		var z := -90.0 - i * 18.0
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4.0
			hub.box("glow", Vector3(cos(a) * 16.0, sin(a) * 16.0, z), Vector3(1.2, 1.2, 1.2), accent)
	# solar arrays / radiators at the back
	for sx in [-1.0, 1.0]:
		hub.box("hull", Vector3(sx * 45, 0, 75), Vector3(60, 2, 4), STEEL)
		for k in 3:
			var x: float = sx * (30 + k * 22)
			hub.box("hull", Vector3(x, 0, 75), Vector3(18, 0.6, 40), Color(0.12, 0.18, 0.32))
			hub.box("dim", Vector3(x, 0.35, 75), Vector3(17, 0.05, 1.2), Color(0.3, 0.5, 0.9))
	# comm mast
	hub.cyl("hull", Vector3(0, 26, -10), Vector3(0, 70, -10), 2.0, 0.6, 6, STEEL)
	hub.box("glow", Vector3(0, 71, -10), Vector3(2, 2, 2), RED)
	# window strips on the spindle
	for k in 8:
		var a := TAU * k / 8.0
		hub.box("dim", Vector3(cos(a) * 25.6, sin(a) * 25.6, -5), Vector3(1.0, 1.0, 40), Color(1.0, 0.9, 0.7), Basis(Vector3.FORWARD, a))
	if variant == 1:
		# Verdant Spire: extra garden dome modules
		for k in 3:
			var a := TAU * k / 3.0
			var p := Vector3(cos(a) * 34, sin(a) * 34, 10)
			hub.cyl("hull", Vector3(cos(a) * 20, sin(a) * 20, 10), p, 5, 5, 6, STEEL)
			hub.xform = Transform3D(Basis.IDENTITY, p)
			hub.loft("dim", [Vector4(-12, 1, 1, 0), Vector4(-8, 10, 10, 0), Vector4(8, 10, 10, 0), Vector4(12, 1, 1, 0)], 8, Color(0.35, 0.8, 0.45))
			hub.xform = Transform3D.IDENTITY
	if variant == 2:
		# industrial: container stacks, crane arms and a smelter block
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for k in 10:
			var a := TAU * k / 10.0
			var r := 36.0 + rng.randf() * 10.0
			hub.box("hull", Vector3(cos(a) * r, sin(a) * r, 30 + rng.randf() * 30), Vector3(10, 10, 22),
				[Color(0.7, 0.35, 0.2), Color(0.3, 0.4, 0.5), Color(0.6, 0.55, 0.3), STEEL][k % 4])
		for sx in [-1.0, 1.0]:
			hub.box("hull", Vector3(sx * 60, 0, -20), Vector3(70, 5, 5), STEEL)
			hub.box("hull", Vector3(sx * 95, -12, -20), Vector3(5, 28, 5), STEEL)
			hub.box("glow", Vector3(sx * 95, -27, -20), Vector3(3, 2, 3), Color(1.0, 0.6, 0.2))
		hub.box("hull", Vector3(0, -48, 40), Vector3(40, 30, 50), DARK)
		hub.box("glow", Vector3(0, -48, 66), Vector3(30, 4, 0.5), Color(1.0, 0.45, 0.15))
	if variant == 3:
		# spire: tall needle with a second, counter-rotating ring segment
		hub.cyl("hull", Vector3(0, 0, 130), Vector3(0, 0, 260), 6, 1.5, 6, WHITE)
		hub.box("glow", Vector3(0, 0, 262), Vector3(3, 3, 3), accent)
		hub.torus("hull", Vector3(0, 0, 190), 40, 3.5, 24, 6, STEEL, Basis(Vector3.RIGHT, PI / 2.0))
		hub.torus("glow", Vector3(0, 0, 190), 44, 0.6, 24, 3, accent, Basis(Vector3.RIGHT, PI / 2.0))
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4.0
			hub.cyl("hull", Vector3(cos(a) * 6, sin(a) * 6, 190), Vector3(cos(a) * 38, sin(a) * 38, 190), 1.5, 1.5, 4, STEEL)
	# habitat ring (rotates around Z)
	var ring_r: float = [95.0, 80.0, 105.0, 70.0][variant]
	ring.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	ring.torus("hull", Vector3.ZERO, ring_r, 9.0, 32, 6, WHITE, Basis.IDENTITY, STEEL)
	ring.torus("dim", Vector3.ZERO, ring_r + 9.2, 0.6, 32, 3, Color(1.0, 0.9, 0.7))
	ring.xform = Transform3D.IDENTITY
	for k in 4:
		var a := TAU * k / 4.0
		var d := Vector3(cos(a), sin(a), 0)
		ring.cyl("hull", d * 24.0, d * (ring_r - 8.0), 3.0, 3.0, 6, STEEL)
		ring.box("glow", d * (ring_r + 1.0) + Vector3(0, 0, 9.5), Vector3(3, 3, 0.4), accent)
	return {
		"hub": hub.build(MeshBuilder.default_materials()),
		"ring": ring.build(MeshBuilder.default_materials()),
	}


static func gate_ring(color: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	b.torus("hull", Vector3.ZERO, 46, 3.0, 24, 6, STEEL, Basis.IDENTITY, DARK)
	b.torus("glow", Vector3.ZERO, 42.5, 0.8, 24, 4, color)
	b.xform = Transform3D.IDENTITY
	for k in 6:
		var a := TAU * k / 6.0
		var d := Vector3(cos(a), sin(a), 0)
		b.box("hull", d * 48.0, Vector3(7, 7, 9), WHITE, Basis(Vector3.FORWARD, a))
		b.box("glow", d * 52.0, Vector3(2, 2, 2), color)
	return b.build(MeshBuilder.default_materials())


static func beacon(color: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cyl("hull", Vector3(0, -30, 0), Vector3(0, 30, 0), 3, 3, 6, STEEL)
	b.loft("hull", [Vector4(-8, 0.5, 0.5, 0), Vector4(-4, 8, 8, 0), Vector4(4, 8, 8, 0), Vector4(8, 0.5, 0.5, 0)], 6, WHITE, STEEL)
	b.box("glow", Vector3(0, 32, 0), Vector3(3, 3, 3), color)
	b.box("glow", Vector3(0, -32, 0), Vector3(3, 3, 3), color)
	return b.build(MeshBuilder.default_materials())


## Stargate: a huge segmented ring with an energy membrane, facing local -Z.
static func stargate(color: Color) -> Dictionary:
	var b := MeshBuilder.new()
	b.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	b.torus("hull", Vector3.ZERO, 150, 12, 48, 8, STEEL, Basis.IDENTITY, DARK)
	b.torus("glow", Vector3.ZERO, 136, 2.0, 48, 4, color)
	b.torus("dim", Vector3.ZERO, 165, 1.2, 48, 4, color)
	b.xform = Transform3D.IDENTITY
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector3(cos(a), sin(a), 0)
		var bs := Basis(Vector3.FORWARD, a)
		b.box("hull", d * 158.0, Vector3(40, 26, 40), WHITE, bs)
		b.box("hull", d * 180.0, Vector3(14, 30, 22), STEEL, bs)
		b.box("glow", d * 196.0, Vector3(5, 5, 5), color)
		b.box("glow", d * 158.0 + Vector3(0, 0, -20.5), Vector3(26, 3, 0.6), color, bs)
	# support pylons
	for sx in [-1.0, 1.0]:
		b.cyl("hull", Vector3(sx * 170, -60, 0), Vector3(sx * 230, -260, 40), 8, 5, 6, STEEL)
	return {"frame": b.build(MeshBuilder.default_materials())}
