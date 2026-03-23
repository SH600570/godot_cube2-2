class_name Cube2x2 extends Node3D

## 整个 2x2 魔方的“总控”脚本
## - 负责：生成 8 个角块、安排它们的位置、处理层旋转、计算状态
## - 不负责：贴纸节点结构（在 CubePiece.tscn 里）、输入事件（在 UIController.gd 里）
signal move_started()
signal move_finished()

## 所有角块节点的数组（方便遍历/重置）
var pieces = []
## 逻辑坐标 -> 角块 的映射，用于 O(1) 找到某个位置的块
var pos_to_piece = {}
## 动画期间锁输入，避免重复转动造成状态错乱
var is_rotating := false
## 单步层转动画时长（秒）
const ROTATE_ANIM_DURATION := 0.2
## 相邻角块中心间距（略大于 1），让 8 个角块之间出现可见裂缝
const PIECE_SPACING := 1.03
## 仅用于显示大小，不改变逻辑坐标/状态计算。值越大，屏幕里看起来越大
const DISPLAY_SCALE := 1.8
## 仅用于屏幕构图，把魔方整体稍微上移到画面中心
const DISPLAY_OFFSET := Vector3(0, 1.45, 0)
## 项目坐标约定：前面 = +Z，后面 = -Z（不使用 Godot 内置 FORWARD/BACK 以免混淆）
const DIR_FRONT := Vector3(0, 0, 1)
const DIR_BACK := Vector3(0, 0, -1)
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

## 空间位置到索引的映射（根据README中的定义）
var pos_to_index = {
	Vector3(0.5, 0.5, 0.5): 0,    # TRF
	Vector3(-0.5, 0.5, 0.5): 1,   # TFL
	Vector3(-0.5, 0.5, -0.5): 2,  # TLB
	Vector3(0.5, 0.5, -0.5): 3,   # TBR
	Vector3(0.5, -0.5, -0.5): 4,  # DRB
	Vector3(-0.5, -0.5, -0.5): 5, # DBL
	Vector3(-0.5, -0.5, 0.5): 6,  # DLF
	Vector3(0.5, -0.5, 0.5): 7    # DFR
}

## 每个位置的颜色组合到朝向编码的映射
var orientation_mapping = {
	0: { # TRF位置
		"white,blue,red": 0,   # wbr
		"red,white,blue": 1,   # rwb
		"blue,red,white": 2    # brw
	},
	1: { # TFL位置
		"white,red,green": 0,  # wrg
		"green,white,red": 1,  # gwr
		"red,green,white": 2   # rgw
	},
	2: { # TLB位置
		"white,green,orange": 0, # wgo
		"orange,white,green": 1, # owg
		"green,orange,white": 2  # gow
	},
	3: { # TBR位置
		"white,orange,blue": 0,  # wob
		"blue,white,orange": 1,  # bwo
		"orange,blue,white": 2   # obw
	},
	4: { # DRB位置
		"yellow,blue,orange": 0, # ybo
		"orange,yellow,blue": 1, # oyb
		"blue,orange,yellow": 2  # boy
	},
	5: { # DBL位置
		"yellow,orange,green": 0, # yog
		"green,yellow,orange": 1, # gyo
		"orange,green,yellow": 2  # ogy
	},
	6: { # DLF位置
		"yellow,green,red": 0,   # ygr
		"red,yellow,green": 1,   # ryg
		"green,red,yellow": 2    # gry
	},
	7: { # DFR位置
		"yellow,red,blue": 0,    # yrb
		"blue,yellow,red": 1,    # byr
		"red,blue,yellow": 2     # rby
	}
}

## 角块逻辑坐标的固定顺序（用于状态计算）
## 注意：逻辑坐标用 ±0.5，让相邻角块中心间距正好是 1（即角块宽度）
var piece_positions = [
	Vector3(0.5, 0.5, 0.5),    # 右上前   (右:x>0, 上:y>0, 前:z>0)
	Vector3(-0.5, 0.5, 0.5),   # 左上前   (左:x<0, 上:y>0, 前:z>0)
	Vector3(-0.5, 0.5, -0.5),  # 左上后   (左:x<0, 上:y>0, 后:z<0)
	Vector3(0.5, 0.5, -0.5),   # 右上后   (右:x>0, 上:y>0, 后:z<0)
	Vector3(0.5, -0.5, -0.5),  # 右下后   (右:x>0, 下:y<0, 后:z<0) -> DRB
	Vector3(-0.5, -0.5, -0.5), # 左下后   (左:x<0, 下:y<0, 后:z<0) -> DBL
	Vector3(-0.5, -0.5, 0.5),  # 左下前   (左:x<0, 下:y<0, 前:z>0) -> DLF
	Vector3(0.5, -0.5, 0.5)    # 右下前   (右:x>0, 下:y<0, 前:z>0) -> DFR
]

func _ready():
	# 先做显示缩放/偏移，再生成角块
	scale = Vector3.ONE * DISPLAY_SCALE
	position = DISPLAY_OFFSET
	# 场景加载完成后，生成 8 个角块
	create_pieces()
	var face_hints := FaceHintArrows.new()
	face_hints.name = "FaceHintArrows"
	add_child(face_hints)

func _input(event: InputEvent) -> void:
	# 让面箭头射线检测先于 UIController 等节点处理（同深度下子节点顺序见场景树）
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var fh := get_node_or_null("FaceHintArrows") as FaceHintArrows
			if fh:
				fh._try_pick_rotate(mb)

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
		var piece_id := piece_positions.find(pos)
		# 从场景文件实例化CubePiece节点
		var piece = piece_scene.instantiate()
		piece.piece_id = piece_id
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
		# README 约定：右面=蓝色
		piece.set_face_color("Face_X+", colors["blue"])
	elif lp.x < 0.0:
		# README 约定：左面=绿色
		piece.set_face_color("Face_X-", colors["green"])

func get_pieces_by_x(x: int) -> Array:
	return pieces.filter(func(p): return is_equal_approx(p.logic_pos.x, float(x) * 0.5))

func get_pieces_by_y(y: int) -> Array:
	return pieces.filter(func(p): return is_equal_approx(p.logic_pos.y, float(y) * 0.5))

func get_pieces_by_z(z: int) -> Array:
	return pieces.filter(func(p): return is_equal_approx(p.logic_pos.z, float(z) * 0.5))

func rotate_R() -> void:
	# 右层顺时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_x(1)
	rotate_pieces(pieces_to_rotate, Vector3.RIGHT, -90)

func rotate_L() -> void:
	# 左层顺时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_x(-1)
	rotate_pieces(pieces_to_rotate, Vector3.RIGHT, 90)

func rotate_U() -> void:
	# 上层顺时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_y(1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, -90)

func rotate_D() -> void:
	# 下层顺时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_y(-1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, 90)

func rotate_F() -> void:
	# 前层顺时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_z(1)
	rotate_pieces(pieces_to_rotate, DIR_FRONT, -90)

func rotate_B() -> void:
	# 后层顺时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_z(-1)
	rotate_pieces(pieces_to_rotate, DIR_FRONT, 90)

# 逆时针旋转函数
func rotate_R_counterclockwise() -> void:
	# 右层逆时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_x(1)
	rotate_pieces(pieces_to_rotate, Vector3.RIGHT, 90)

func rotate_L_counterclockwise() -> void:
	# 左层逆时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_x(-1)
	rotate_pieces(pieces_to_rotate, Vector3.RIGHT, -90)

func rotate_U_counterclockwise() -> void:
	# 上层逆时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_y(1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, 90)

func rotate_D_counterclockwise() -> void:
	# 下层逆时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_y(-1)
	rotate_pieces(pieces_to_rotate, Vector3.UP, -90)

func rotate_F_counterclockwise() -> void:
	# 前层逆时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_z(1)
	rotate_pieces(pieces_to_rotate, DIR_FRONT, 90)

func rotate_B_counterclockwise() -> void:
	# 后层逆时针旋转
	if is_rotating:
		return
	var pieces_to_rotate = get_pieces_by_z(-1)
	rotate_pieces(pieces_to_rotate, DIR_FRONT, -90)

func rotate_pieces(pieces_to_rotate: Array, axis: Vector3, angle: float) -> void:
	# 以临时 pivot 实现“整层刚体旋转”，避免局部轴/浮点误差导致逻辑映射失效
	if pieces_to_rotate.is_empty(): # 如果需要旋转的角块列表为空，则直接返回
		return
	is_rotating = true # 设置旋转状态为 true，避免重复旋转
	move_started.emit() # 发射旋转开始信号
	var pivot := Node3D.new()
	pivot.name = "RotatePivot" # 设置旋转轴节点名称为 "RotatePivot"
	add_child(pivot) # 将旋转轴节点添加到当前节点
	pivot.transform = Transform3D.IDENTITY # 设置旋转轴节点变换为单位变换

	for piece in pieces_to_rotate:
		piece.reparent(pivot, true) # 将角块节点添加到旋转轴节点

	var start_basis := pivot.basis
	var end_basis := start_basis.rotated(axis.normalized(), deg_to_rad(angle)) # 计算旋转后的变换
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) # 设置插值类型为正弦插值，缓动方式为缓入缓出
	tween.tween_method(func(weight: float):
		pivot.basis = start_basis.slerp(end_basis, weight) # 插值计算旋转轴节点变换
	, 0.0, 1.0, ROTATE_ANIM_DURATION) # 设置插值时间
	await tween.finished # 等待插值完成		

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
	is_rotating = false
	move_finished.emit()

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

func _get_piece_orientation(piece: CubePiece) -> int:
	# 根据 README 的“每个位置读取顺序”取该位置的 3 个世界方向颜色
	# 然后在 orientation_mapping 中查出 0/1/2 朝向编码。
	var pos_index = pos_to_index.get(piece.logic_pos, 0)
	var dirs: Array[Vector3] = []
	match pos_index:
		0: dirs = [Vector3.UP, Vector3.RIGHT, DIR_FRONT]    # TRF -> wbr
		1: dirs = [Vector3.UP, DIR_FRONT, Vector3.LEFT]     # TFL -> wrg
		2: dirs = [Vector3.UP, Vector3.LEFT, DIR_BACK]      # TLB -> wgo
		3: dirs = [Vector3.UP, DIR_BACK, Vector3.RIGHT]     # TBR -> wob
		4: dirs = [Vector3.DOWN, Vector3.RIGHT, DIR_BACK]   # DRB -> ybo
		5: dirs = [Vector3.DOWN, DIR_BACK, Vector3.LEFT]    # DBL -> yog
		6: dirs = [Vector3.DOWN, Vector3.LEFT, DIR_FRONT]   # DLF -> ygr
		7: dirs = [Vector3.DOWN, DIR_FRONT, Vector3.RIGHT]  # DFR -> yrb
		_: dirs = [Vector3.UP, Vector3.RIGHT, DIR_FRONT]

	var visible_colors: Array[String] = []
	for d in dirs:
		visible_colors.append(_color_to_name(piece.get_color_facing_world_dir(d)))

	var mapping = orientation_mapping.get(pos_index, {})
	var key := ",".join(visible_colors)
	return mapping.get(key, 0)

func _color_to_name(c: Color) -> String:
	# 将颜色转换为名称
	for name in colors.keys():
		if c.is_equal_approx(colors[name]):
			return name
	return "white"

func get_cube_state() -> Array:
	# 计算魔方状态为8个数字的数组
	# 按 piece_id(0..7) 输出“该角块当前位置+朝向”的编码值，
	# 与 README 的示例 [0,4,8,12,16,20,24,28] / U 后数组一致。
	var state = []

	var by_id := pieces.duplicate()
	by_id.sort_custom(func(a: CubePiece, b: CubePiece): return a.piece_id < b.piece_id)

	for piece in by_id:
		var pos_index = pos_to_index.get(piece.logic_pos, 0)
		var orientation = _get_piece_orientation(piece)
		var encoded_value = (pos_index << 2) | orientation
		state.append(encoded_value)
	
	return state
