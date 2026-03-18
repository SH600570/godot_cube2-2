class_name Cube2x2 extends Node3D

var pieces = []
# 逻辑坐标到块的映射，用于快速查找
var pos_to_piece = {}
# 颜色定义
var colors = {
	"white": Color(1, 1, 1),
	"red": Color(1, 0, 0),
	"green": Color(0, 1, 0),
	"blue": Color(0, 0, 1),
	"yellow": Color(1, 1, 0),
	"orange": Color(1, 0.5, 0)
}

# 颜色值映射（用于3进制状态表示）
var color_values = {
	"white": 0,
	"red": 1,
	"green": 2,
	"blue": 0,
	"yellow": 1,
	"orange": 2
}

# 角块位置顺序（用于状态计算）
var piece_positions = [
	Vector3(1, 1, 1),
	Vector3(-1, 1, 1),
	Vector3(-1, 1, -1),
	Vector3(1, 1, -1),
	Vector3(1, -1, 1),
	Vector3(-1, -1, 1),
	Vector3(-1, -1, -1),
	Vector3(1, -1, -1)
]

func _ready():
	create_pieces()

func create_pieces():
	# 加载 CubePiece 场景
	var piece_scene = load("res://scenes/CubePiece.tscn")
	if piece_scene == null:
		print("Error: Failed to load CubePiece.tscn")
		return
	
	# 生成8个角块的逻辑坐标
	for pos in piece_positions:
		var piece = piece_scene.instantiate()
		piece.logic_pos = pos
		piece.position = pos * 0.5  # 缩放位置
		
		# 设置颜色
		set_piece_colors(piece)
		
		# 隐藏内部面
		piece.hide_internal_faces()
		
		add_child(piece)
		pieces.append(piece)
		pos_to_piece[pos] = piece

func set_piece_colors(piece: CubePiece) -> void:
	# 根据逻辑坐标设置颜色
	# Y+ 面: 白色
	# Y- 面: 黄色
	# Z+ 面: 红色
	# Z- 面: 橙色
	# X+ 面: 绿色
	# X- 面: 蓝色
	
	if piece.logic_pos.y == 1:
		piece.set_face_color("Face_Y+", colors["white"])
	elif piece.logic_pos.y == -1:
		piece.set_face_color("Face_Y-", colors["yellow"])
	
	if piece.logic_pos.z == 1:
		piece.set_face_color("Face_Z+", colors["red"])
	elif piece.logic_pos.z == -1:
		piece.set_face_color("Face_Z-", colors["orange"])
	
	if piece.logic_pos.x == 1:
		piece.set_face_color("Face_X+", colors["green"])
	elif piece.logic_pos.x == -1:
		piece.set_face_color("Face_X-", colors["blue"])

func get_pieces_by_x(x: int) -> Array:
	return pieces.filter(func(p): return int(p.logic_pos.x) == x)

func get_pieces_by_y(y: int) -> Array:
	return pieces.filter(func(p): return int(p.logic_pos.y) == y)

func get_pieces_by_z(z: int) -> Array:
	return pieces.filter(func(p): return int(p.logic_pos.z) == z)

func rotate_R() -> void:
	# 右层顺时针旋转
	var pieces_to_rotate = get_pieces_by_x(1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, 90)

func rotate_L() -> void:
	# 左层顺时针旋转
	var pieces_to_rotate = get_pieces_by_x(-1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, -90)

func rotate_U() -> void:
	# 上层顺时针旋转
	var pieces_to_rotate = get_pieces_by_y(1)
	rotate_pieces(pieces_to_rotate, Vector3.FORWARD, -90)

func rotate_D() -> void:
	# 下层顺时针旋转
	var pieces_to_rotate = get_pieces_by_y(-1)
	rotate_pieces(pieces_to_rotate, Vector3.FORWARD, 90)

func rotate_F() -> void:
	# 前层顺时针旋转
	var pieces_to_rotate = get_pieces_by_z(1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, 90)

func rotate_B() -> void:
	# 后层顺时针旋转
	var pieces_to_rotate = get_pieces_by_z(-1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, -90)

func rotate_pieces(pieces_to_rotate: Array, axis: Vector3, angle: float) -> void:
	# 旋转指定的块
	for piece in pieces_to_rotate:
		# 动画旋转（这里简化为直接旋转）
		piece.rotate(axis, deg_to_rad(angle))
		# 移除旧的位置映射
		pos_to_piece.erase(piece.logic_pos)
		# 更新逻辑坐标
		piece.logic_pos = piece.logic_pos.rotated(axis, deg_to_rad(angle))
		# 添加新的位置映射
		pos_to_piece[piece.logic_pos] = piece
		# 重新设置颜色和隐藏面
		piece.show_all_faces()
		piece.hide_internal_faces()
		set_piece_colors(piece)

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

func get_cube_state() -> String:
	# 计算魔方状态为8位3进制数
	var state = ""
	
	# 按照固定顺序检查每个角块的位置
	for target_pos in piece_positions:
		# 通过映射快速查找当前在目标位置的块
		var current_piece = pos_to_piece.get(target_pos)
		
		if current_piece:
			# 确定当前块的方向（通过检查Y+面的颜色）
			var y_plus_color = current_piece.get_face_color("Face_Y+")
			var value = 0
			
			# 根据颜色确定值
			if y_plus_color == colors["white"]:
				value = 0
			elif y_plus_color == colors["red"]:
				value = 1
			elif y_plus_color == colors["green"]:
				value = 2
			elif y_plus_color == colors["blue"]:
				value = 0
			elif y_plus_color == colors["yellow"]:
				value = 1
			elif y_plus_color == colors["orange"]:
				value = 2
			
			state += str(value)
		else:
			state += "0"
	
	return state
