class_name CubePiece extends Node3D

var logic_pos: Vector3
var face_colors = {}

func set_face_color(face: String, color: Color) -> void:
	var face_node = get_node_or_null(face)
	if face_node:
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		face_node.material_override = material
		face_colors[face] = color

func get_face_color(face: String) -> Color:
	return face_colors.get(face, Color(1, 1, 1))

func hide_face(face: String) -> void:
	var face_node = get_node_or_null(face)
	if face_node:
		face_node.visible = false

func show_all_faces() -> void:
	for face in ["Face_X+", "Face_X-", "Face_Y+", "Face_Y-", "Face_Z+", "Face_Z-"]:
		var face_node = get_node_or_null(face)
		if face_node:
			face_node.visible = true

func hide_internal_faces() -> void:
	# 隐藏内部面，只显示外部面
	if logic_pos.x == 1:
		hide_face("Face_X-")
	elif logic_pos.x == -1:
		hide_face("Face_X+")
	
	if logic_pos.y == 1:
		hide_face("Face_Y-")
	elif logic_pos.y == -1:
		hide_face("Face_Y+")
	
	if logic_pos.z == 1:
		hide_face("Face_Z-")
	elif logic_pos.z == -1:
		hide_face("Face_Z+")
