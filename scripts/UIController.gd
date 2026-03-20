class_name UIController extends Node

## 负责把键盘输入转换成“魔方动作”，并在界面上显示当前状态字符串
## - 不直接操作角块，只调用 Cube2x2 暴露出来的接口

## 场景里的 Cube2x2 节点引用（在 _ready 里查找）
var cube: Cube2x2
## 显示状态字符串的 Label
var status_label: Label
## 相机节点引用
var camera: Camera3D
var orbit_camera: OrbitCamera
## 初始相机状态
var initial_camera_state = {
	"position": Vector3(3, 3, 3),  # 默认初始位置
	"rotation": Vector3(0, 0, 0),   # 默认初始旋转
	"fov": 75.0                    # 默认初始FOV
}
## 保存的自定义视角
var saved_views = []
## 当前选中的视角索引
var current_view_index = -1

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
	
	## 2. 找到相机节点
	# 首先尝试在父节点的直接子节点中查找
	camera = get_parent().get_node_or_null("Camera3D")
	
	# 如果没找到，尝试递归查找整个场景树
	if not camera:
		camera = get_tree().root.get_node_or_null("**/Camera3D")
	
	if camera:
		# 获取OrbitCamera脚本引用
		orbit_camera = camera as OrbitCamera
		if orbit_camera:
			print("OrbitCamera script found on Camera3D")
		else:
			print("Warning: OrbitCamera script not found on Camera3D")
		
		# 保存初始相机状态
		initial_camera_state["position"] = camera.position
		initial_camera_state["rotation"] = camera.rotation
		initial_camera_state["fov"] = camera.fov
		print("Camera3D found at position: " + str(camera.position))
		print("Initial camera state saved: " + str(initial_camera_state))
	else:
		print("Warning: Failed to find Camera3D node")
		# 如果还是没找到，尝试创建一个默认相机
		var new_camera = Camera3D.new()
		new_camera.name = "Camera3D"
		new_camera.position = initial_camera_state["position"]
		new_camera.fov = initial_camera_state["fov"]
		new_camera.look_at(Vector3(0, 0, 0), Vector3.UP)
		get_parent().add_child(new_camera)
		camera = new_camera
		orbit_camera = camera as OrbitCamera
		print("Created default Camera3D at position: " + str(camera.position))

	## 3. 创建左上角的“魔方状态: xxxxxxxx”文本
	create_status_label()
	
	## 4. 创建右侧旋转操作按钮
	create_rotation_buttons()

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
	var dialog = ConfirmationDialog.new()
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
	dialog.confirmed.connect(func():
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
	
	# 先添加到场景树，再显示对话框
	add_child(dialog)
	dialog.popup_centered()

## 创建右侧旋转操作按钮
func create_rotation_buttons():
	# 创建按钮容器
	var button_container = VBoxContainer.new()
	button_container.name = "RotationButtons"
	button_container.position = Vector2(800, 100)
	button_container.size = Vector2(150, 400)
	add_child(button_container)

	# 创建标题
	var title = Label.new()
	title.text = "旋转操作"
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	title.add_theme_constant_override("outline_size", 2)
	button_container.add_child(title)

	# 旋转按钮配置
	var rotation_buttons = [
		{ "text": "U", "func": "rotate_U" },
		{ "text": "U'", "func": "rotate_U_counterclockwise" },
		{ "text": "D", "func": "rotate_D" },
		{ "text": "D'", "func": "rotate_D_counterclockwise" },
		{ "text": "L", "func": "rotate_L" },
		{ "text": "L'", "func": "rotate_L_counterclockwise" },
		{ "text": "R", "func": "rotate_R" },
		{ "text": "R'", "func": "rotate_R_counterclockwise" },
		{ "text": "F", "func": "rotate_F" },
		{ "text": "F'", "func": "rotate_F_counterclockwise" },
		{ "text": "B", "func": "rotate_B" },
		{ "text": "B'", "func": "rotate_B_counterclockwise" }
	]

	# 创建旋转按钮
	for button_config in rotation_buttons:
		var button = Button.new()
		button.text = button_config["text"]
		button.size = Vector2(140, 30)
		# 使用闭包确保每个按钮调用正确的方法
		button.pressed.connect(func(func_name = button_config["func"]):
			call(func_name)
			update_status()
		)
		button_container.add_child(button)

	# 创建重置视角按钮
	var reset_view_button = Button.new()
	reset_view_button.text = "重置视角"
	reset_view_button.size = Vector2(140, 40)
	reset_view_button.pressed.connect(func():
		reset_camera_view()
	)
	button_container.add_child(reset_view_button)
	
	# 创建保存视角按钮
	var save_view_button = Button.new()
	save_view_button.text = "保存视角"
	save_view_button.size = Vector2(140, 40)
	save_view_button.pressed.connect(func():
		save_current_view()
	)
	button_container.add_child(save_view_button)
	
	# 创建选择视角按钮
	var select_view_button = Button.new()
	select_view_button.text = "选择视角"
	select_view_button.size = Vector2(140, 40)
	select_view_button.pressed.connect(func():
		show_view_selection()
	)
	button_container.add_child(select_view_button)

## 重置相机视角到初始状态
func reset_camera_view():
	# 重置相机视角到初始状态
	if orbit_camera:
		print("Resetting camera to initial state...")
		orbit_camera.reset_view()
		print("Camera reset completed using OrbitCamera.reset_view()")
	elif camera:
		print("Resetting camera to initial state (fallback)...")
		print("Initial position: " + str(initial_camera_state["position"]))
		print("Initial rotation: " + str(initial_camera_state["rotation"]))
		print("Initial FOV: " + str(initial_camera_state["fov"]))
		
		# 重置位置、旋转和FOV
		camera.position = initial_camera_state["position"]
		camera.rotation = initial_camera_state["rotation"]
		camera.fov = initial_camera_state["fov"]
		
		# 确保相机看向魔方中心
		camera.look_at(Vector3(0, 0, 0), Vector3.UP)
		
		print("Camera reset completed. New position: " + str(camera.position))
	else:
		print("Error: Camera not found when resetting view")

## 保存当前视角为自定义视角
func save_current_view():
	if orbit_camera:
		print("Saving current view...")
		var orbit_view = orbit_camera.get_current_view()
		print("Current view: " + str(orbit_view))
		
		var view = {
			"orbit_view": orbit_view,
			"name": "视角 " + str(saved_views.size() + 1)
		}
		saved_views.append(view)
		
		print("View saved successfully! Total saved views: " + str(saved_views.size()))
		
		# 显示保存成功提示
		var dialog = AcceptDialog.new()
		dialog.title = "保存视角"
		dialog.add_child(Label.new())
		dialog.get_child(0).text = "视角保存成功！\n当前已保存 " + str(saved_views.size()) + " 个视角"
		add_child(dialog)
		dialog.popup_centered()
		
		# 3秒后自动关闭
		var timer = Timer.new()
		timer.wait_time = 3.0
		timer.one_shot = true
		timer.timeout.connect(func():
			dialog.queue_free()
			timer.queue_free()
		)
		add_child(timer)
		timer.start()
	elif camera:
		print("Saving current view (fallback)...")
		print("Current position: " + str(camera.position))
		print("Current rotation: " + str(camera.rotation))
		print("Current FOV: " + str(camera.fov))
		
		var view = {
			"position": camera.position,
			"rotation": camera.rotation,
			"fov": camera.fov,
			"name": "视角 " + str(saved_views.size() + 1)
		}
		saved_views.append(view)
		
		print("View saved successfully! Total saved views: " + str(saved_views.size()))
		
		# 显示保存成功提示
		var dialog = AcceptDialog.new()
		dialog.title = "保存视角"
		dialog.add_child(Label.new())
		dialog.get_child(0).text = "视角保存成功！\n当前已保存 " + str(saved_views.size()) + " 个视角"
		add_child(dialog)
		dialog.popup_centered()
		
		# 3秒后自动关闭
		var timer = Timer.new()
		timer.wait_time = 3.0
		timer.one_shot = true
		timer.timeout.connect(func():
			dialog.queue_free()
			timer.queue_free()
		)
		add_child(timer)
		timer.start()
	else:
		print("Error: Camera not found when saving view")

## 显示视角选择对话框
func show_view_selection():
	if saved_views.is_empty():
		# 没有保存的视角，显示提示
		var dialog = AcceptDialog.new()
		dialog.title = "选择视角"
		dialog.add_child(Label.new())
		dialog.get_child(0).text = "还没有保存的自定义视角！"
		add_child(dialog)
		dialog.popup_centered()
		return
	
	# 创建视角选择对话框
	var dialog = ConfirmationDialog.new()
	dialog.title = "选择视角"
	
	# 添加视角列表
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	# 添加初始视角选项
	var initial_button = Button.new()
	initial_button.text = "初始视角"
	initial_button.pressed.connect(func():
		reset_camera_view()
		dialog.queue_free()
	)
	vbox.add_child(initial_button)
	
	# 添加分隔线
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# 添加保存的自定义视角
	for i in range(saved_views.size()):
		var view = saved_views[i]
		var view_button = Button.new()
		view_button.text = view["name"]
		view_button.pressed.connect(func(index = i):
			load_view(index)
			dialog.queue_free()
		)
		vbox.add_child(view_button)
	
	# 调整对话框大小
	dialog.set_min_size(Vector2(300, 200 + saved_views.size() * 30))
	
	# 连接取消信号
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	# 显示对话框
	add_child(dialog)
	dialog.popup_centered()

## 加载指定索引的视角
func load_view(index: int):
	if index >= 0 and index < saved_views.size():
		print("Loading view at index " + str(index) + "...")
		var view = saved_views[index]
		
		if orbit_camera and "orbit_view" in view:
			print("Loading orbit view: " + str(view["orbit_view"]))
			orbit_camera.set_view(view["orbit_view"])
			current_view_index = index
			print("View loaded successfully! Current view index: " + str(current_view_index))
		elif camera and "position" in view:
			print("Loading regular view (fallback)...")
			print("View position: " + str(view["position"]))
			print("View rotation: " + str(view["rotation"]))
			print("View FOV: " + str(view["fov"]))
			
			camera.position = view["position"]
			camera.rotation = view["rotation"]
			camera.fov = view["fov"]
			
			# 确保相机看向魔方中心
			camera.look_at(Vector3(0, 0, 0), Vector3.UP)
			
			current_view_index = index
			print("View loaded successfully! Current view index: " + str(current_view_index))
		else:
			print("Error: Invalid view data or camera not found")
	else:
		print("Error: Invalid view index or camera not found")

## 旋转方法
func rotate_U():
	if cube:
		cube.rotate_U()

func rotate_U_counterclockwise():
	if cube:
		cube.rotate_U_counterclockwise()

func rotate_D():
	if cube:
		cube.rotate_D()

func rotate_D_counterclockwise():
	if cube:
		cube.rotate_D_counterclockwise()

func rotate_L():
	if cube:
		cube.rotate_L()

func rotate_L_counterclockwise():
	if cube:
		cube.rotate_L_counterclockwise()

func rotate_R():
	if cube:
		cube.rotate_R()

func rotate_R_counterclockwise():
	if cube:
		cube.rotate_R_counterclockwise()

func rotate_F():
	if cube:
		cube.rotate_F()

func rotate_F_counterclockwise():
	if cube:
		cube.rotate_F_counterclockwise()

func rotate_B():
	if cube:
		cube.rotate_B()

func rotate_B_counterclockwise():
	if cube:
		cube.rotate_B_counterclockwise()
