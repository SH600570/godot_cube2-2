class_name Cube2x2 extends Node3D

## 整个 2x2 魔方的“总控”脚本
## - 负责：生成 8 个角块、安排它们的位置、处理层旋转、计算状态
## - 不负责：贴纸节点结构（在 CubePiece.tscn 里）、输入事件（在 UIController.gd 里）

## 所有角块节点的数组（方便遍历/重置）
var pieces = []
## 逻辑坐标 -> 角块 的映射，用于 O(1) 找到某个位置的块
var pos_to_piece = {}
## 相邻角块中心间距（与角块宽度一致），保证拼成一个几乎无缝的正方体
const PIECE_SPACING := 1.0
## 各个颜色在屏幕上的实际 RGB 值
var colors = {
	"white": Color(1, 1, 1),
	"red": Color(1, 0, 0),
	"green": Color(0, 1, 0),
	"blue": Color(0, 0, 1),
	"yellow": Color(1, 1, 0),
	"orange": Color(1, 0.5, 0)
}

## 颜色到“3 进制数字”的映射，用于 README 里描述的 8 位 3 进制状态
var color_values = {
	"white": 0,
	"red": 1,
	"green": 2,
	"blue": 0,
	"yellow": 1,
	"orange": 2
}

## 角块逻辑坐标的固定顺序（用于状态计算）
## 注意：逻辑坐标用 ±0.5，让相邻角块中心间距正好是 1（即角块宽度）
var piece_positions = [
	Vector3(0.5, 0.5, 0.5),
	Vector3(-0.5, 0.5, 0.5),
	Vector3(-0.5, 0.5, -0.5),
	Vector3(0.5, 0.5, -0.5),
	Vector3(0.5, -0.5, 0.5),
	Vector3(-0.5, -0.5, 0.5),
	Vector3(-0.5, -0.5, -0.5),
	Vector3(0.5, -0.5, -0.5)
]

func _ready():
	# 场景加载完成后，生成 8 个角块
	create_pieces()

## 把一个任意 Vector3“吸附”到最近的逻辑坐标上
## 逻辑坐标以 0.5 为步长（±0.5），这样 8 个角块刚好拼成正方体
func _snap_logic_pos(v: Vector3) -> Vector3:
	return Vector3(
		round(v.x * 2.0) / 2.0,
		round(v.y * 2.0) / 2.0,
		round(v.z * 2.0) / 2.0
	)

## 只在重置或一开始调用：根据 piece_positions 生成 8 个角块
func create_pieces():
	# 生成 8 个角块
	print("Creating cube pieces...")
	# 从场景文件加载角块预制
	var piece_scene = load("res://scenes/CubePiece.tscn")
	if not piece_scene:
		print("Error: Failed to load CubePiece.tscn")
		return
	
	for pos in piece_positions:
		# 从场景文件实例化CubePiece节点
		var piece = piece_scene.instantiate()
		piece.logic_pos = pos
		piece.position = pos * PIECE_SPACING
		print("Created piece at position: " + str(piece.position))
		
		# 设置颜色
		set_piece_colors(piece)
		
		# 隐藏内部面
		piece.hide_internal_faces()
		
		add_child(piece)
		pieces.append(piece)
		pos_to_piece[pos] = piece

func set_piece_colors(piece: CubePiece) -> void:
	## 只在“外露的 3 个方向”上色：
	## 例如 logic_pos 为 (0.5,0.5,0.5) 的角块，外露方向是 +X,+Y,+Z；
	## (-0.5,0.5,-0.5) 的外露方向是 -X,+Y,-Z。
	## 这样总共只有 3*8 = 24 个彩色面，符合真实 2 阶魔方。
	var lp := piece.logic_pos

	# 上下：始终使用 Face_Y+ / Face_Y-，只在对应逻辑位置上上色
	if lp.y > 0.0:
		piece.set_face_color("Face_Y+", colors["white"])
	elif lp.y < 0.0:
		piece.set_face_color("Face_Y-", colors["yellow"])

	# 前后：始终使用 Face_Z+ / Face_Z-
	if lp.z > 0.0:
		piece.set_face_color("Face_Z+", colors["red"])
	elif lp.z < 0.0:
		piece.set_face_color("Face_Z-", colors["orange"])

	# 左右：始终使用 Face_X+ / Face_X-
	if lp.x > 0.0:
		piece.set_face_color("Face_X+", colors["green"])
	elif lp.x < 0.0:
		piece.set_face_color("Face_X-", colors["blue"])

func get_pieces_by_x(x: int) -> Array:
	return pieces.filter(func(p): return is_equal_approx(p.logic_pos.x, float(x) * 0.5))

func get_pieces_by_y(y: int) -> Array:
	return pieces.filter(func(p): return is_equal_approx(p.logic_pos.y, float(y) * 0.5))

func get_pieces_by_z(z: int) -> Array:
	return pieces.filter(func(p): return is_equal_approx(p.logic_pos.z, float(z) * 0.5))

func rotate_R() -> void:
	# 右层顺时针旋转
	var pieces_to_rotate = get_pieces_by_x(1)
	rotate_pieces(pieces_to_rotate, Vector3.RIGHT, -90)

func rotate_L() -> void:
	# 左层顺时针旋转
	var pieces_to_rotate = get_pieces_by_x(-1)
	rotate_pieces(pieces_to_rotate, Vector3.RIGHT, 90)

func rotate_U() -> void:
	# 上层顺时针旋转
	var pieces_to_rotate = get_pieces_by_y(1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, -90)

func rotate_D() -> void:
	# 下层顺时针旋转
	var pieces_to_rotate = get_pieces_by_y(-1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, 90)

func rotate_F() -> void:
	# 前层顺时针旋转
	var pieces_to_rotate = get_pieces_by_z(1)
	rotate_pieces(pieces_to_rotate, Vector3.FORWARD, -90)

func rotate_B() -> void:
	# 后层顺时针旋转
	var pieces_to_rotate = get_pieces_by_z(-1)
	rotate_pieces(pieces_to_rotate, Vector3.FORWARD, 90)

func rotate_pieces(pieces_to_rotate: Array, axis: Vector3, angle: float) -> void:
	# 以临时 pivot 实现“整层刚体旋转”，避免局部轴/浮点误差导致逻辑映射失效
	if pieces_to_rotate.is_empty():
		return
	var pivot := Node3D.new()
	pivot.name = "RotatePivot"
	add_child(pivot)
	pivot.transform = Transform3D.IDENTITY

	for piece in pieces_to_rotate:
		piece.reparent(pivot, true)

	pivot.rotate(axis, deg_to_rad(angle))

	for piece in pieces_to_rotate:
		piece.reparent(self, true)
		piece.logic_pos = _snap_logic_pos(piece.position / PIECE_SPACING)
		piece.position = piece.logic_pos * PIECE_SPACING

	pivot.queue_free()

	# 重建映射（避免 key 细微误差/碰撞）
	pos_to_piece.clear()
	for p in pieces:
		p.logic_pos = _snap_logic_pos(p.logic_pos)
		pos_to_piece[p.logic_pos] = p

	for piece in pieces:
		piece.show_all_faces()
		piece.hide_internal_faces()

func reset() -> void:
	# 重置魔方
	for piece in pieces:
		piece.rotation = Vector3.ZERO
	
	# 重新生成块
	for piece in pieces:
		piece.queue_free()
	pieces.clear()
	pos_to_piece.clear()
	create_pieces()

func _color_to_value(c: Color) -> int:
	for name in color_values.keys():
		if c.is_equal_approx(colors[name]):
			return int(color_values[name])
	return 0

func get_cube_state() -> String:
	# 计算魔方状态为8位3进制数
	var state = ""
	
	# 按照固定顺序检查每个角块的位置
	for target_pos in piece_positions:
		# 通过映射快速查找当前在目标位置的块
		var current_piece = pos_to_piece.get(target_pos)
		
		if current_piece:
			# 按 README：每个角块的状态由其“当前朝上的贴纸颜色”(世界 Y+) 决定
			var up_color: Color = (current_piece as CubePiece).get_color_facing_world_dir(Vector3.UP)
			state += str(_color_to_value(up_color))
		else:
			state += "0"
	
	return state
