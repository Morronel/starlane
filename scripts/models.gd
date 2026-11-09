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


## Any player-flyable hull by id (see Items.SHIPS).
static func ship(id: String) -> ArrayMesh:
	match id:
		"wren":
			return _wren()
		"kestrel":
			return _kestrel()
		"mule":
			return _mule()
		"corsair":
			return _corsair()
		"seraph":
			return _seraph()
	return player_ship()


## Rough size relative to the Sparrow (camera distance, collision).
static func ship_size(id: String) -> float:
	return {"sparrow": 1.0, "wren": 1.05, "kestrel": 1.1, "mule": 1.65, "corsair": 1.45, "seraph": 1.25}.get(id, 1.0)


## Gun muzzle positions in ship space; weapons cycle through them.
static func hardpoints(id: String) -> Array:
	match id:
		"wren":
			return [Vector3(0, -0.4, -6.5)]
		"kestrel":
			return [Vector3(-2.6, 0, -3.5), Vector3(2.6, 0, -3.5), Vector3(0, -0.6, -6.0)]
		"mule":
			return [Vector3(-3.4, 1.2, -7.0), Vector3(3.4, 1.2, -7.0)]
		"corsair":
			return [Vector3(-3.8, 0.4, -6.4), Vector3(3.8, 0.4, -6.4), Vector3(-2.2, -0.6, -7.2), Vector3(2.2, -0.6, -7.2)]
		"seraph":
			return [Vector3(-3.2, 0, -4.4), Vector3(3.2, 0, -4.4), Vector3(-1.2, -0.3, -6.4), Vector3(1.2, -0.3, -6.4)]
	return [Vector3(-1.6, 0, -3.0), Vector3(1.6, 0, -3.0)]


static func _mirror(pts: Array) -> Array:
	var out := []
	for p in pts:
		out.append(Vector2(-p.x, p.y))
	return out


static func _wren() -> ArrayMesh:
	var b := MeshBuilder.new()
	var body := Color(0.86, 0.82, 0.7)
	var trim := Color(0.55, 0.42, 0.3)
	b.loft("hull", [
		Vector4(-8.0, 0.05, 0.05, 0.0),
		Vector4(-5.0, 0.5, 0.42, 0.05),
		Vector4(-1.5, 0.85, 0.7, 0.1),
		Vector4(2.5, 0.95, 0.75, 0.1),
		Vector4(4.6, 0.7, 0.6, 0.05),
	], 8, body, trim)
	b.loft("dim", [Vector4(-4.6, 0.05, 0.05, 0.45), Vector4(-3.0, 0.32, 0.3, 0.55), Vector4(-0.6, 0.36, 0.3, 0.6), Vector4(0.4, 0.05, 0.05, 0.5)], 6, Color(0.15, 0.4, 0.55))
	var wing := [Vector2(0.8, -0.5), Vector2(3.8, 3.0), Vector2(3.9, 3.8), Vector2(0.8, 3.4)]
	b.slab("hull", wing, -0.1, 0.14, body, trim)
	b.slab("hull", _mirror(wing), -0.1, 0.14, body, trim)
	b.slab("hull", [Vector2(0.0, 1.0), Vector2(0.0, 4.4), Vector2(0.02, 4.4)], 0.7, 0.1, trim)
	b.box("hull", Vector3(0, 1.3, 3.6), Vector3(0.12, 1.4, 1.4), trim, Basis(Vector3.RIGHT, -0.5))
	b.cyl("hull", Vector3(0, 0.05, 3.5), Vector3(0, 0.05, 5.4), 0.75, 0.85, 8, STEEL)
	b.cyl("glow", Vector3(0, 0.05, 5.42), Vector3(0, 0.05, 5.5), 0.5, 0.5, 8, AMBER.darkened(0.2))
	for sx in [-1.0, 1.0]:
		b.box("glow", Vector3(2.2 * sx, 0.0, 1.8), Vector3(2.4, 0.04, 0.1), AMBER, Basis(Vector3.UP, -0.85 * sx))
		b.cyl("hull", Vector3(3.85 * sx, -0.1, 1.2), Vector3(3.85 * sx, -0.1, 3.9), 0.12, 0.18, 5, STEEL)
	return b.build(MeshBuilder.default_materials())


static func _kestrel() -> ArrayMesh:
	var b := MeshBuilder.new()
	var body := Color(0.45, 0.49, 0.55)
	var stripe := Color(0.75, 0.2, 0.15)
	b.loft("hull", [
		Vector4(-6.5, 0.05, 0.05, 0.0),
		Vector4(-4.0, 0.7, 0.5, 0.0),
		Vector4(-0.5, 1.1, 0.75, 0.1),
		Vector4(2.8, 1.0, 0.7, 0.1),
		Vector4(4.0, 0.7, 0.5, 0.0),
	], 6, body, DARK)
	b.loft("dim", [Vector4(-3.6, 0.05, 0.05, 0.6), Vector4(-2.2, 0.42, 0.34, 0.7), Vector4(-0.2, 0.44, 0.36, 0.72), Vector4(0.8, 0.05, 0.05, 0.6)], 6, Color(0.6, 0.35, 0.12))
	for sx in [-1.0, 1.0]:
		# side nacelles
		b.cyl("hull", Vector3(2.6 * sx, 0.0, -3.0), Vector3(2.6 * sx, 0.0, 4.4), 0.55, 0.75, 8, body)
		b.cyl("glow", Vector3(2.6 * sx, 0.0, 4.42), Vector3(2.6 * sx, 0.0, 4.5), 0.45, 0.45, 8, CYAN)
		b.cyl("hull", Vector3(2.6 * sx, 0.0, -3.6), Vector3(2.6 * sx, 0.0, -3.0), 0.12, 0.3, 6, DARK)
		# wing joining nacelle and body, plus outer blade
		b.slab("hull", [Vector2(0.9 * sx, -0.8), Vector2(2.4 * sx, -1.2), Vector2(2.4 * sx, 2.8), Vector2(0.9 * sx, 3.0)], -0.05, 0.16, body, DARK)
		b.slab("hull", [Vector2(3.0 * sx, 0.6), Vector2(5.4 * sx, 2.6), Vector2(5.4 * sx, 3.4), Vector2(3.0 * sx, 3.2)], -0.05, 0.12, stripe, DARK)
		# canards
		b.slab("hull", [Vector2(0.6 * sx, -4.0), Vector2(1.9 * sx, -3.2), Vector2(1.9 * sx, -2.8), Vector2(0.6 * sx, -2.6)], 0.0, 0.08, stripe)
		b.box("hull", Vector3(2.6 * sx, 0.9, 2.6), Vector3(0.12, 1.4, 1.3), DARK, Basis(Vector3.RIGHT, -0.45))
		b.box("glow", Vector3(1.6 * sx, 0.1, 0.8), Vector3(0.9, 0.04, 0.1), CYAN)
	b.cyl("hull", Vector3(0, -0.6, -6.0), Vector3(0, -0.6, -3.5), 0.12, 0.16, 5, DARK)
	return b.build(MeshBuilder.default_materials())


static func _mule() -> ArrayMesh:
	var b := MeshBuilder.new()
	var body := Color(0.82, 0.68, 0.32)
	var plate := Color(0.4, 0.42, 0.45)
	# cockpit nose
	b.loft("hull", [Vector4(-7.8, 0.6, 0.5, 1.2), Vector4(-6.6, 1.6, 1.2, 1.1), Vector4(-4.4, 2.0, 1.5, 0.9), Vector4(-3.6, 1.8, 1.4, 0.8)], 8, body, plate)
	b.box("dim", Vector3(0, 1.75, -6.2), Vector3(2.2, 0.5, 1.2), Color(0.2, 0.45, 0.6), Basis(Vector3.RIGHT, 0.5))
	# cargo body
	b.box("hull", Vector3(0, 0.3, 0.0), Vector3(5.6, 3.6, 8.4), plate)
	for z in [-2.6, 0.0, 2.6]:
		for sx in [-1.0, 1.0]:
			b.box("hull", Vector3(2.9 * sx, 0.3, z), Vector3(0.3, 3.2, 2.2), body)
		b.box("hull", Vector3(0, 2.2, z), Vector3(5.0, 0.3, 2.2), body)
	b.box("glow", Vector3(0, 2.4, 3.9), Vector3(0.3, 0.3, 0.3), RED)
	# engines
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			b.cyl("hull", Vector3(1.6 * sx, 0.3 + 1.0 * sy, 4.2), Vector3(1.6 * sx, 0.3 + 1.0 * sy, 6.0), 0.8, 0.95, 8, DARK)
			b.cyl("glow", Vector3(1.6 * sx, 0.3 + 1.0 * sy, 6.02), Vector3(1.6 * sx, 0.3 + 1.0 * sy, 6.1), 0.5, 0.5, 8, Color(0.7, 0.5, 0.22))
		b.box("hull", Vector3(3.4 * sx, 1.2, -5.4), Vector3(0.5, 0.5, 3.4), DARK)
		b.slab("hull", [Vector2(2.8 * sx, -1.5), Vector2(4.6 * sx, 0.5), Vector2(4.6 * sx, 2.5), Vector2(2.8 * sx, 3.0)], -1.2, 0.2, plate, DARK)
	return b.build(MeshBuilder.default_materials())


static func _corsair() -> ArrayMesh:
	var b := MeshBuilder.new()
	var body := Color(0.28, 0.3, 0.34)
	var accent := Color(0.95, 0.5, 0.15)
	b.loft("hull", [
		Vector4(-6.8, 1.6, 0.4, 0.0),
		Vector4(-5.5, 2.8, 0.9, 0.1),
		Vector4(-2.0, 2.2, 1.3, 0.2),
		Vector4(2.5, 2.0, 1.3, 0.2),
		Vector4(4.6, 1.4, 0.9, 0.1),
	], 6, body, DARK, 0.0, PI / 6.0)
	b.loft("dim", [Vector4(-4.8, 0.05, 0.05, 1.05), Vector4(-3.4, 0.6, 0.4, 1.25), Vector4(-1.4, 0.6, 0.4, 1.3), Vector4(-0.4, 0.05, 0.05, 1.2)], 6, Color(0.7, 0.35, 0.1))
	for sx in [-1.0, 1.0]:
		b.slab("hull", [Vector2(1.8 * sx, -3.0), Vector2(4.4 * sx, -2.4), Vector2(5.2 * sx, 3.6), Vector2(1.8 * sx, 4.0)], -0.2, 0.3, body, DARK)
		b.box("hull", Vector3(4.6 * sx, 0.0, 0.4), Vector3(1.2, 1.2, 6.0), DARK)
		b.cyl("hull", Vector3(3.8 * sx, 0.4, -6.4), Vector3(3.8 * sx, 0.4, -2.6), 0.18, 0.28, 6, STEEL)
		b.cyl("hull", Vector3(2.2 * sx, -0.6, -7.2), Vector3(2.2 * sx, -0.6, -4.8), 0.16, 0.24, 6, STEEL)
		b.cyl("hull", Vector3(1.5 * sx, 0.1, 3.8), Vector3(1.5 * sx, 0.1, 6.2), 1.0, 1.15, 8, DARK)
		b.cyl("hull", Vector3(1.5 * sx, 0.1, 6.2), Vector3(1.5 * sx, 0.1, 6.24), 1.1, 0.75, 8, DARK)
		b.cyl("glow", Vector3(1.5 * sx, 0.1, 6.22), Vector3(1.5 * sx, 0.1, 6.3), 0.55, 0.55, 8, Color(0.75, 0.38, 0.15))
		b.box("glow", Vector3(3.6 * sx, 0.15, 1.4), Vector3(1.4, 0.06, 0.15), accent)
		b.box("hull", Vector3(4.9 * sx, 0.9, 2.8), Vector3(0.14, 1.6, 1.6), accent, Basis(Vector3.RIGHT, -0.4))
	return b.build(MeshBuilder.default_materials())


static func _seraph() -> ArrayMesh:
	var b := MeshBuilder.new()
	var body := Color(0.9, 0.92, 0.96)
	var trim := Color(0.45, 0.4, 0.6)
	var glow := Color(0.7, 0.45, 1.0)
	b.loft("hull", [
		Vector4(-7.5, 0.05, 0.05, 0.0),
		Vector4(-4.5, 0.75, 0.45, 0.05),
		Vector4(-1.0, 1.2, 0.7, 0.1),
		Vector4(2.5, 1.15, 0.7, 0.1),
		Vector4(4.8, 0.8, 0.5, 0.05),
	], 8, body, trim)
	b.loft("dim", [Vector4(-4.2, 0.05, 0.05, 0.42), Vector4(-2.6, 0.4, 0.3, 0.55), Vector4(-0.4, 0.42, 0.32, 0.6), Vector4(0.6, 0.05, 0.05, 0.5)], 6, Color(0.35, 0.2, 0.55))
	for sx in [-1.0, 1.0]:
		# forward-swept upper wing and swept-back lower wing
		b.slab("hull", [Vector2(1.0 * sx, 0.2), Vector2(5.6 * sx, -2.2), Vector2(6.0 * sx, -1.4), Vector2(1.0 * sx, 2.4)], 0.25, 0.12, body, trim)
		b.slab("hull", [Vector2(1.0 * sx, 1.0), Vector2(4.6 * sx, 4.2), Vector2(4.4 * sx, 4.8), Vector2(1.0 * sx, 3.8)], -0.3, 0.12, body, trim)
		b.box("glow", Vector3(3.4 * sx, 0.32, -0.6), Vector3(3.0, 0.04, 0.12), glow, Basis(Vector3.UP, 0.45 * sx))
		b.cyl("hull", Vector3(1.3 * sx, 0.0, 2.6), Vector3(1.3 * sx, 0.0, 5.4), 0.55, 0.7, 8, trim)
		b.cyl("glow", Vector3(1.3 * sx, 0.0, 5.42), Vector3(1.3 * sx, 0.0, 5.5), 0.42, 0.42, 8, glow.darkened(0.2))
		b.cyl("hull", Vector3(3.2 * sx, 0.0, -4.4), Vector3(3.2 * sx, 0.0, -1.0), 0.12, 0.2, 6, trim)
		b.box("glow", Vector3(6.0 * sx, 0.25, -1.6), Vector3(0.25, 0.25, 0.25), glow)
	b.slab("hull", [Vector2(0.0, 1.2), Vector2(0.0, 4.6), Vector2(0.02, 4.6)], 0.7, 0.1, trim)
	b.box("hull", Vector3(0, 1.3, 3.8), Vector3(0.12, 1.4, 1.6), body, Basis(Vector3.RIGHT, -0.55))
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


## Junction ring of radius r. Its members grow only with the square root of
## the size, so a ring around a kilometre-wide tube stays slim instead of
## turning into a wall of lit steel.
static func gate_ring(color: Color, r := 46.0) -> ArrayMesh:
	var g := sqrt(r / 46.0)
	var segs := 24 if r < 200.0 else 64
	var b := MeshBuilder.new()
	b.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	b.torus("hull", Vector3.ZERO, r, 3.0 * g, segs, 6, STEEL, Basis.IDENTITY, DARK)
	b.torus("glow", Vector3.ZERO, r - 3.5 * g, 0.8 * g, segs, 4, color)
	b.xform = Transform3D.IDENTITY
	for k in 6:
		var a := TAU * k / 6.0
		var d := Vector3(cos(a), sin(a), 0)
		b.box("hull", d * (r + 2.0 * g), Vector3(7, 7, 9) * g, STEEL, Basis(Vector3.FORWARD, a))
		b.box("glow", d * (r + 6.0 * g), Vector3(2, 2, 2) * g, color)
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
