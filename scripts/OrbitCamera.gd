class_name OrbitCamera extends Camera3D

## 简单轨道相机（用于调试/教学演示）：
## - 右键拖拽：绕目标旋转
## - 滚轮：缩放远近
## - 中键拖拽：平移目标点（可选）

@export var target_path: NodePath
@export var distance: float = 8.5
@export var min_distance: float = 3.0
@export var max_distance: float = 20.0
@export var rotate_sensitivity: float = 0.008
@export var pan_sensitivity: float = 0.01
@export var zoom_step: float = 0.8

var _target: Node3D
var _yaw: float = deg_to_rad(45.0)
var _pitch: float = deg_to_rad(-25.0)
var _orbit_center: Vector3 = Vector3.ZERO
var _right_dragging := false
var _middle_dragging := false

# 初始状态
var initial_state = {
	"yaw": _yaw,
	"pitch": _pitch,
	"distance": distance,
	"orbit_center": _orbit_center
}

func _ready() -> void:
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target:
		_orbit_center = _target.global_position
	# 用当前相机位置初始化 yaw/pitch/distance，避免场景跳变
	var offset := global_position - _orbit_center
	distance = clamp(offset.length(), min_distance, max_distance)
	if distance > 0.0001:
		_yaw = atan2(offset.x, offset.z)
		_pitch = asin(clamp(offset.y / distance, -0.999, 0.999))
	# 保存初始状态
	initial_state = {
		"yaw": _yaw,
		"pitch": _pitch,
		"distance": distance,
		"orbit_center": _orbit_center
	}
	_update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_right_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = max(min_distance, distance - zoom_step)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = min(max_distance, distance + zoom_step)
			_update_camera_transform()

	if event is InputEventMouseMotion:
		if _right_dragging:
			_yaw -= event.relative.x * rotate_sensitivity
			_pitch -= event.relative.y * rotate_sensitivity
			_pitch = clamp(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
			_update_camera_transform()
		elif _middle_dragging:
			# 平移目标点：沿相机的右/上方向移动
			var right := global_transform.basis.x.normalized()
			var up := global_transform.basis.y.normalized()
			_orbit_center += (-right * event.relative.x + up * event.relative.y) * pan_sensitivity
			_update_camera_transform()

func _process(_delta: float) -> void:
	# 如果目标移动了（例如调整 DISPLAY_OFFSET），让轨道中心跟随目标
	if _target:
		_orbit_center = _target.global_position
		_update_camera_transform()

func _update_camera_transform() -> void:
	var cp := cos(_pitch)
	var offset := Vector3(
		sin(_yaw) * cp,
		sin(_pitch),
		cos(_yaw) * cp
	) * distance
	global_position = _orbit_center + offset
	look_at(_orbit_center, Vector3.UP)

## 重置视角到初始状态
func reset_view() -> void:
	_yaw = initial_state["yaw"]
	_pitch = initial_state["pitch"]
	distance = initial_state["distance"]
	_orbit_center = initial_state["orbit_center"]
	_update_camera_transform()

## 获取当前视角状态
func get_current_view() -> Dictionary:
	return {
		"yaw": _yaw,
		"pitch": _pitch,
		"distance": distance,
		"orbit_center": _orbit_center
	}

## 设置视角状态
func set_view(view: Dictionary) -> void:
	if "yaw" in view:
		_yaw = view["yaw"]
	if "pitch" in view:
		_pitch = view["pitch"]
	if "distance" in view:
		distance = clamp(view["distance"], min_distance, max_distance)
	if "orbit_center" in view:
		_orbit_center = view["orbit_center"]
	_update_camera_transform()
