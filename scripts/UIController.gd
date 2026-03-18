class_name UIController extends Node

var cube: Cube2x2
var status_label: Label

func _ready():
	# 获取 Cube2x2 实例
	# 查找 Cube2x2 类型的节点
	var cube_nodes = get_parent().get_children()
	for node in cube_nodes:
		if node is Cube2x2:
			cube = node
			break
	if cube == null:
		print("Error: Failed to find Cube2x2 node")
		return

	# 创建状态显示标签
	create_status_label()

func create_status_label():
	# 创建一个标签节点来显示魔方状态
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "魔方状态: " + cube.get_cube_state()
	status_label.position = Vector2(20, 20)
	status_label.add_theme_color_override("font_color", Color(0, 0, 0))
	add_child(status_label)

func _unhandled_input(event):
	# 处理键盘输入
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_U: 
				cube.rotate_U()
				update_status()
			KEY_D: 
				cube.rotate_D()
				update_status()
			KEY_L: 
				cube.rotate_L()
				update_status()
			KEY_R: 
				cube.rotate_R()
				update_status()
			KEY_F: 
				cube.rotate_F()
				update_status()
			KEY_B: 
				cube.rotate_B()
				update_status()
			KEY_SPACE: 
				cube.reset()
				update_status()

func update_status():
	# 更新魔方状态显示
	if status_label:
		status_label.text = "魔方状态: " + cube.get_cube_state()
