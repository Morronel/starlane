class_name Station
extends Node3D
## A dockable station: static hub with collision, a rotating habitat ring,
## a docking bay facing local -Z and blinking navigation lights.

var station_id := "halcyon"
var display_name := "Halcyon Yard"
var kind := ""
var accent := Color(0.25, 0.9, 1.0)
var variant := 0

const DOCK_RANGE := 420.0

var ring: Node3D


func build() -> void:
	add_to_group("stations")
	var meshes := Models.station(accent, variant)
	var hub := MeshInstance3D.new()
	hub.mesh = meshes["hub"]
	add_child(hub)
	ring = MeshInstance3D.new()
	(ring as MeshInstance3D).mesh = meshes["ring"]
	add_child(ring)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = (meshes["hub"] as ArrayMesh).create_trimesh_shape()
	body.add_child(shape)
	var rshape := CollisionShape3D.new()
	rshape.shape = (meshes["ring"] as ArrayMesh).create_trimesh_shape()
	body.add_child(rshape)
	add_child(body)

	# blinking nav lights
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 3.2
	sm.radial_segments = 8
	sm.rings = 4
	var pts := [Vector3(0, 30, -60), Vector3(0, -30, -60), Vector3(30, 0, -60), Vector3(-30, 0, -60), Vector3(0, 0, 132)]
	for i in pts.size():
		var l := MeshInstance3D.new()
		l.mesh = sm
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/blink.gdshader")
		m.set_shader_parameter("color", Color(1.0, 0.25, 0.15) if i % 2 == 0 else Color(0.3, 1.0, 0.5))
		m.set_shader_parameter("rate", 0.8)
		m.set_shader_parameter("phase", i * 0.13)
		l.material_override = m
		l.position = pts[i]
		add_child(l)

	# soft accent light so the ship picks up station color when close
	var omni := OmniLight3D.new()
	omni.light_color = accent
	omni.light_energy = 2.0
	omni.omni_range = 220.0
	omni.position = Vector3(0, 0, -90)
	add_child(omni)


func _process(delta: float) -> void:
	if ring:
		ring.rotate_object_local(Vector3.FORWARD, delta * 0.06)


## World-space point just outside the bay where docking ends.
func dock_point() -> Vector3:
	return global_transform * Vector3(0, 0, -60)


func approach_point() -> Vector3:
	return global_transform * Vector3(0, 0, -200)


func undock_transform() -> Transform3D:
	var t := Transform3D()
	t.origin = global_transform * Vector3(0, 0, -150)
	t.basis = global_transform.basis   # facing -Z = away from the bay
	return t
