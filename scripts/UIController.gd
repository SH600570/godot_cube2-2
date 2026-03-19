class_name UIController extends Node

## 负责把键盘输入转换成“魔方动作”，并在界面上显示当前状态字符串
## - 不直接操作角块，只调用 Cube2x2 暴露出来的接口

## 场景里的 Cube2x2 节点引用（在 _ready 里查找）
var cube: Cube2x2
## 显示状态字符串的 Label
var status_label: Label

func _ready():
	## 1. 在父节点的子节点列表里找到 Cube2x2 实例
	var cube_nodes = get_parent().get_children()
	for node in cube_nodes:
		if node is Cube2x2:
			cube = node
			break
	if cube == null:
		print("Error: Failed to find Cube2x2 node")
		return

	## 2. 创建左上角的“魔方状态: xxxxxxxx”文本
	create_status_label()

## 创建并初始化状态 Label
func create_status_label():
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "魔方状态: " + str(cube.get_cube_state())
	# 简单放在屏幕左上角
	status_label.position = Vector2(20, 20)
	# 深色背景下使用高对比白字，并加描边防止与场景高光混在一起
	status_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	status_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	status_label.add_theme_constant_override("outline_size", 2)
	add_child(status_label)

## 监听全局输入事件，把按键映射到魔方动作
func _input(event):
	if event is InputEventKey and event.pressed:
		var shift_pressed = event.shift_pressed
		match event.keycode:
			KEY_U: 
				if shift_pressed:
					cube.rotate_U_counterclockwise()
				else:
					cube.rotate_U()
				update_status()
			KEY_D: 
				if shift_pressed:
					cube.rotate_D_counterclockwise()
				else:
					cube.rotate_D()
				update_status()
			KEY_L: 
				if shift_pressed:
					cube.rotate_L_counterclockwise()
				else:
					cube.rotate_L()
				update_status()
			KEY_R: 
				if shift_pressed:
					cube.rotate_R_counterclockwise()
				else:
					cube.rotate_R()
				update_status()
			KEY_F: 
				if shift_pressed:
					cube.rotate_F_counterclockwise()
				else:
					cube.rotate_F()
				update_status()
			KEY_B: 
				if shift_pressed:
					cube.rotate_B_counterclockwise()
				else:
					cube.rotate_B()
				update_status()
			KEY_SPACE: 
				# 重置魔方，需要输入"reset"确认
				reset_with_confirmation()
				update_status()

## 重新计算并刷新左上角的状态字符串
func update_status():
	if status_label:
		status_label.text = "魔方状态: " + str(cube.get_cube_state())

## 重置魔方，需要输入"reset"确认
func reset_with_confirmation():
	# 创建确认对话框
	var dialog = AcceptDialog.new()
	dialog.title = "重置魔方"
	dialog.add_child(Label.new())
	dialog.get_child(0).text = "确定要重置魔方到初始状态吗？\n请输入'reset'确认："
	
	# 添加输入框
	var line_edit = LineEdit.new()
	line_edit.name = "ResetInput"
	line_edit.placeholder_text = "请输入'reset'"
	dialog.add_child(line_edit)
	
	# 调整布局
	dialog.set_min_size(Vector2(300, 150))
	
	# 连接确认信号
	dialog.accepted.connect(func():
		var input_text = line_edit.text
		if input_text == "reset":
			cube.reset()
			update_status()
		dialog.queue_free()
	)
	
	# 连接取消信号
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	# 显示对话框
	dialog.popup_centered()
	add_child(dialog)
