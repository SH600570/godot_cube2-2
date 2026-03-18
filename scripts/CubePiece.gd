class_name CubePiece extends Node3D

## 角块节点（2 阶魔方里 8 个角块的“砖头”）
## - 自己只关心：逻辑坐标、6 个面的贴纸颜色、哪些面可见
## - 不关心：转动规则、层的组合，这些在 Cube2x2 里统一管理

## 逻辑坐标（由 Cube2x2 维护），取值类似 (0.5, 0.5, 0.5)
## 表示这个角块在整个魔方中的“右/左、上/下、前/后”位置
var logic_pos: Vector3

## 记录每个面当前的颜色（用于状态计算等）
var face_colors = {}

## 方便遍历 6 个面的名称
const FACE_NAMES := ["Face_X+", "Face_X-", "Face_Y+", "Face_Y-", "Face_Z+", "Face_Z-"]

## 给某一面贴上“贴纸颜色”
## face: "Face_X+" / "Face_Y-" 等节点名
## color: 想要的颜色
func set_face_color(face: String, color: Color) -> void:
	var face_node = get_node_or_null(face)
	if face_node:
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		# 关闭背面裁剪：PlaneMesh 即使反着摆，颜色也能从两面看到
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		face_node.material_override = material
		face_colors[face] = color

## 读取指定面的颜色（如果还没设过颜色，默认返回白色）
func get_face_color(face: String) -> Color:
	return face_colors.get(face, Color(1, 1, 1))

## 给“状态计算”用：查看当前在某个世界方向上朝外的贴纸颜色
## 比如 world_dir = Vector3.UP 时，返回“朝上的那张贴纸”的颜色
func get_color_facing_world_dir(world_dir: Vector3) -> Color:
	var dir := world_dir.normalized()
	var best_face := ""
	var best_dot := -INF

	for face in FACE_NAMES:
		var node := get_node_or_null(face) as Node3D
		if node == null:
			continue
		# PlaneMesh 的法线默认沿 +Z，这里把每个面的“本地 +Z 法线”变换到世界坐标系
		var n := (node.global_transform.basis * Vector3.FORWARD).normalized()
		var d := n.dot(dir)
		if d > best_dot:
			best_dot = d
			best_face = face

	return get_face_color(best_face)

## 把某个面整体隐藏（完全不可见）
func hide_face(face: String) -> void:
	var face_node = get_node_or_null(face)
	if face_node:
		face_node.visible = false

## 显示 6 个面（在重新计算哪些面是“内部面”之前调用）
func show_all_faces() -> void:
	for face in FACE_NAMES:
		var face_node = get_node_or_null(face)
		if face_node:
			face_node.visible = true

## 根据逻辑坐标，把“朝向魔方内部”的 3 个面隐藏
## 例：右上前角块 (x>0, y>0, z>0) 的内部面是 X-, Y-, Z-
func hide_internal_faces() -> void:
	# x>0：说明在右边，内部是 X- 面
	if logic_pos.x > 0.0:
		hide_face("Face_X-")
	elif logic_pos.x < 0.0:
		hide_face("Face_X+")

	# y>0：说明在上面，内部是 Y- 面
	if logic_pos.y > 0.0:
		hide_face("Face_Y-")
	elif logic_pos.y < 0.0:
		hide_face("Face_Y+")

	# z>0：说明在前面，内部是 Z- 面
	if logic_pos.z > 0.0:
		hide_face("Face_Z-")
	elif logic_pos.z < 0.0:
		hide_face("Face_Z+")
