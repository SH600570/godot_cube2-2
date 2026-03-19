class_name CubePiece extends Node3D

## 角块节点（2 阶魔方里 8 个角块的“砖头”）
## - 自己只关心：逻辑坐标、6 个面的贴纸颜色、哪些面可见
## - 不关心：转动规则、层的组合，这些在 Cube2x2 里统一管理

## 逻辑坐标（由 Cube2x2 维护），取值类似 (0.5, 0.5, 0.5)
## 表示这个角块在整个魔方中的“右/左、上/下、前/后”位置
var logic_pos: Vector3
## 角块身份 ID（0~7，创建后固定不变，用于状态数组输出）
var piece_id: int = -1

## 记录每个面当前的颜色（用于状态计算等）
var face_colors = {}
## 调试色：用于标记“被判定为内部”的面（不再隐藏）
const INTERNAL_DEBUG_COLOR := Color(0.75, 0.0, 1.0) # 亮紫色
## 是否显示内部面调试色。false=正常隐藏内部面；true=内部面染紫便于排查
const SHOW_INTERNAL_DEBUG_FACES := false

## 方便遍历 6 个面的名称
const FACE_NAMES := ["Face_X+", "Face_X-", "Face_Y+", "Face_Y-", "Face_Z+", "Face_Z-"]

func _ready() -> void:
	# 给角块本体一个较深灰材质，避免白色贴纸与本体融在一起看不清
	var body := get_node_or_null("CubeBody") as MeshInstance3D
	if body:
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.22, 0.22, 0.22)
		body_mat.roughness = 0.85
		body.material_override = body_mat

## 给某一面贴上“贴纸颜色”
## face: "Face_X+" / "Face_Y-" 等节点名
## color: 想要的颜色
func set_face_color(face: String, color: Color) -> void:
	var face_node = get_node_or_null(face)
	if face_node:
		var material = StandardMaterial3D.new()
		var final_color := color
		# 关闭背面裁剪：PlaneMesh 即使反着摆，颜色也能从两面看到
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.35
		material.metallic = 0.05
		material.specular = 0.8
		material.clearcoat = 0.4
		material.clearcoat_roughness = 0.15
		# 白色贴纸在某些视角/光照下容易和本体混在一起，这里做轻微提亮增强可见性
		if color.is_equal_approx(Color(1, 1, 1)):
			# 乳白色
			final_color = Color(0.96, 0.94, 0.88)
			material.emission_enabled = true
			material.emission = Color(0.22, 0.2, 0.16)
			material.emission_energy_multiplier = 0.85
			# 白色额外提升镜面反差，增强“贴纸存在感”
			material.specular = 1.0
			material.roughness = 0.18
		else:
			# 非白色贴纸做轻度增饱和，提升鲜亮感
			final_color = _boost_saturation(color, 1.25)
			# 给所有非白色贴纸一点基础自发光，避免背光角度太暗
			material.emission_enabled = true
			material.emission = final_color * 0.12
			material.emission_energy_multiplier = 0.35
		material.albedo_color = final_color
		face_node.material_override = material
		face_colors[face] = color

func _boost_saturation(c: Color, amount: float) -> Color:
	var avg := (c.r + c.g + c.b) / 3.0
	return Color(
		clamp(avg + (c.r - avg) * amount, 0.0, 1.0),
		clamp(avg + (c.g - avg) * amount, 0.0, 1.0),
		clamp(avg + (c.b - avg) * amount, 0.0, 1.0),
		c.a
	)

## 给内部面设置明显的调试材质（不隐藏，便于肉眼检查）
func set_internal_debug_face(face: String) -> void:
	var face_node = get_node_or_null(face)
	if face_node:
		var material = StandardMaterial3D.new()
		material.albedo_color = INTERNAL_DEBUG_COLOR
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# 加一点发光，避免灯光较暗时看不清
		material.emission_enabled = true
		material.emission = INTERNAL_DEBUG_COLOR
		material.emission_energy_multiplier = 0.4
		face_node.material_override = material
		face_node.visible = true

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
		# 不依赖 PlaneMesh 法线方向，直接用“贴纸中心相对角块中心”的方向判定。
		# 这样即使某些面在 tscn 里正反旋转不一致，也能稳定得到朝向。
		var face_dir := (node.global_position - global_position).normalized()
		var d := face_dir.dot(dir)
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
	# 注意：角块会旋转，不能再靠固定面名判断“内部面”。
	# 必须按“世界法线方向”判断哪些面朝向魔方中心。
	var internal_dirs: Array[Vector3] = []
	if logic_pos.x > 0.0:
		internal_dirs.append(Vector3.LEFT)   # 右侧块，内部方向朝左
	elif logic_pos.x < 0.0:
		internal_dirs.append(Vector3.RIGHT)  # 左侧块，内部方向朝右

	if logic_pos.y > 0.0:
		internal_dirs.append(Vector3.DOWN)   # 上侧块，内部方向朝下
	elif logic_pos.y < 0.0:
		internal_dirs.append(Vector3.UP)     # 下侧块，内部方向朝上

	if logic_pos.z > 0.0:
		# 项目约定：前 = +Z，所以内部“后”方向是 -Z
		internal_dirs.append(Vector3(0, 0, -1))
	elif logic_pos.z < 0.0:
		# 项目约定：前 = +Z，所以内部“前”方向是 +Z
		internal_dirs.append(Vector3(0, 0, 1))

	for face in FACE_NAMES:
		var node := get_node_or_null(face) as Node3D
		if node == null:
			continue
		# 不依赖法线，改用“贴纸中心方向”判断是否朝向内部。
		var face_dir := (node.global_position - global_position).normalized()
		var is_internal := false
		for d in internal_dirs:
			if face_dir.dot(d) > 0.95:
				is_internal = true
				break
		if is_internal:
			if SHOW_INTERNAL_DEBUG_FACES:
				# 调试模式：内部面染成亮紫色
				set_internal_debug_face(face)
			else:
				# 正常模式：隐藏内部面
				hide_face(face)
