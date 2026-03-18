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
	status_label.text = "魔方状态: " + cube.get_cube_state()
	# 简单放在屏幕左上角
	status_label.position = Vector2(20, 20)
	status_label.add_theme_color_override("font_color", Color(0, 0, 0))
	add_child(status_label)

## 监听全局输入事件，把按键映射到魔方动作
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
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

## 重新计算并刷新左上角的状态字符串
func update_status():
	if status_label:
		status_label.text = "魔方状态: " + cube.get_cube_state()
