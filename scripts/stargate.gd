class_name Stargate
extends Node3D
## A stargate linking this system to a neighbour. Fly close and tap JUMP.

const JUMP_RANGE := 650.0

var link := ""          # destination system id
var display_name := ""
var color := Color(0.5, 0.8, 1.0)
var membrane_mat: ShaderMaterial
var _charge := 0.0


func build() -> void:
	add_to_group("stargates")
	var m := Models.stargate(color)
	var frame := MeshInstance3D.new()
	frame.mesh = m["frame"]
	add_child(frame)
	var q := QuadMesh.new()
	q.size = Vector2(272, 272)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	membrane_mat = ShaderMaterial.new()
	membrane_mat.shader = load("res://shaders/gate_membrane.gdshader")
	membrane_mat.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
	mi.material_override = membrane_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = (m["frame"] as ArrayMesh).create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	var omni := OmniLight3D.new()
	omni.light_color = color
	omni.light_energy = 0.8
	omni.omni_range = 300.0
	add_child(omni)


func set_charge(c: float) -> void:
	_charge = c
	membrane_mat.set_shader_parameter("charge", c)


## Point in front of the gate where arriving ships appear (facing away).
func arrival_transform() -> Transform3D:
	var b := global_transform.basis
	return Transform3D(b, global_transform * Vector3(0, 0, -420))


func approach_point() -> Vector3:
	return global_transform * Vector3(0, 0, -260)
