class_name FaceHintArrows extends Node3D

## 六个外侧面各一套「光环」：两段 90° 圆弧 + 末端箭头彼此反向，分别表示顺/逆转动。
## 面心/法线：对每层 4 个角块，在 6 个贴纸中选取与层外法线最一致的一面再平均，避免转动后仍用固定 local_face 导致点跑到魔方内部。

const STICKER_FACE_LOCAL := 0.51
const FLOAT_OUT := 0.16
const RING_RADIUS := 0.7
const RING_WIDTH := 0.2
const ARC_SEGMENTS := 20
const HALO_TWIST := PI * 0.25
## 两段弧中点附近各放一个扁盒，分别对应顺/逆
const HIT_ARC_BOX := Vector3(0.52, 0.52, 0.28)

const META_ACTION := &"face_hint_rotate_action"
const META_HOLDER := &"face_hint_holder_node"

## 六个贴纸中心相对角块中心的偏移（与 CubePiece.tscn 一致）
const FACE_OFFSETS: Array[Vector3] = [
	Vector3(STICKER_FACE_LOCAL, 0, 0), Vector3(-STICKER_FACE_LOCAL, 0, 0),
	Vector3(0, STICKER_FACE_LOCAL, 0), Vector3(0, -STICKER_FACE_LOCAL, 0),
	Vector3(0, 0, STICKER_FACE_LOCAL), Vector3(0, 0, -STICKER_FACE_LOCAL),
]

var _cube: Cube2x2
var _entries: Array[Dictionary] = []

func _ready() -> void:
	_cube = get_parent() as Cube2x2
	if _cube == null:
		push_warning("FaceHintArrows: parent must be Cube2x2")
		return
	set_process(true)
	call_deferred("_build_faces")

func _process(_delta: float) -> void:
	if _cube == null or _cube.pieces.is_empty():
		return
	for e in _entries:
		_update_entry(e)

func _build_faces() -> void:
	if _cube == null:
		return
	var specs: Array[Dictionary] = [
		{"id": "U", "normal": Vector3.UP, "layer": func(): return _cube.get_pieces_by_y(1), "cw": _cube.rotate_U, "ccw": _cube.rotate_U_counterclockwise},
		{"id": "D", "normal": Vector3.DOWN, "layer": func(): return _cube.get_pieces_by_y(-1), "cw": _cube.rotate_D, "ccw": _cube.rotate_D_counterclockwise},
		{"id": "L", "normal": Vector3.LEFT, "layer": func(): return _cube.get_pieces_by_x(-1), "cw": _cube.rotate_L, "ccw": _cube.rotate_L_counterclockwise},
		{"id": "R", "normal": Vector3.RIGHT, "layer": func(): return _cube.get_pieces_by_x(1), "cw": _cube.rotate_R, "ccw": _cube.rotate_R_counterclockwise},
		{"id": "F", "normal": Vector3(0, 0, 1), "layer": func(): return _cube.get_pieces_by_z(1), "cw": _cube.rotate_F, "ccw": _cube.rotate_F_counterclockwise},
		{"id": "B", "normal": Vector3(0, 0, -1), "layer": func(): return _cube.get_pieces_by_z(-1), "cw": _cube.rotate_B, "ccw": _cube.rotate_B_counterclockwise},
	]
	for spec in specs:
		var holder := Node3D.new()
		holder.name = "FaceHints_" + spec["id"]
		add_child(holder)
		var mesh := MeshInstance3D.new()
		mesh.name = "HaloMesh"
		mesh.mesh = _build_single_halo_mesh()
		mesh.material_override = _mat(Color(0.55, 0.82, 1.0, 0.6))
		holder.add_child(mesh)
		# 两段弧中点（holder 局部 XY），用于摆碰撞盒
		var seg_a0 := HALO_TWIST
		var seg_a1 := HALO_TWIST + PI * 0.5
		var seg_b0 := HALO_TWIST + PI
		var seg_b1 := HALO_TWIST + PI * 1.5
		var mid_a := (seg_a0 + seg_a1) * 0.5
		var mid_b := (seg_b0 + seg_b1) * 0.5
		var r_hit := RING_RADIUS * 0.92
		var pos_hit_a := Vector3(cos(mid_a) * r_hit, sin(mid_a) * r_hit, 0.0)
		var pos_hit_b := Vector3(cos(mid_b) * r_hit, sin(mid_b) * r_hit, 0.0)
		var body_cw := _make_hit_body(holder, "HitCW", spec["cw"] as Callable, pos_hit_a)
		var body_ccw := _make_hit_body(holder, "HitCCW", spec["ccw"] as Callable, pos_hit_b)
		_entries.append({
			"spec": spec,
			"holder": holder,
			"mesh": mesh,
			"hit_cw": body_cw,
			"hit_ccw": body_ccw,
		})

func _make_hit_body(parent: Node3D, name_str: String, action: Callable, local_pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_str
	body.collision_layer = 1
	body.collision_mask = 0
	body.input_ray_pickable = true
	body.set_meta(META_ACTION, action)
	body.set_meta(META_HOLDER, parent)
	body.position = local_pos
	var shp := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = HIT_ARC_BOX
	shp.shape = box
	body.add_child(shp)
	parent.add_child(body)
	return body

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.45
	m.metallic = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## 局部 XY：斜向 45° 后 [0,90°] 与 [180°,270°] 两段；末端箭头沿弧向，两段箭头在圆上大致反向
func _build_single_halo_mesh() -> ArrayMesh:
	var st := SurfaceTool.new() # SurfaceTool 是 Godot 中用于构建网格的工具类，用于将顶点、法线和纹理坐标等数据组织成三角形面片。
	st.begin(Mesh.PRIMITIVE_TRIANGLES) # 使用三角形作为基本几何体。
	var ri := RING_RADIUS - RING_WIDTH * 0.5 # 内半径
	var ro := RING_RADIUS + RING_WIDTH * 0.5 # 外半径
	var seg_a0 := HALO_TWIST # 第一段弧的起始角度
	var seg_a1 := HALO_TWIST + PI * 0.5 # 第一段弧的结束角度
	var seg_b0 := HALO_TWIST + PI # 第二段弧的起始角度
	var seg_b1 := HALO_TWIST + PI * 1.5 # 第二段弧的结束角度
	_append_arc_strip(st, ri, ro, seg_a0, seg_a1) # 添加第一段弧 顺时针 st:SurfaceTool ri:内半径 ro:外半径 a0:起始角度 a1:结束角度
	_append_arc_strip(st, ri, ro, seg_b0, seg_b1) # 添加第二段弧 逆时针 st:SurfaceTool ri:内半径 ro:外半径 a0:起始角度 a1:结束角度
	# 沿弧参数增加方向在局部 XY 上为「数学逆时针」；从面外（+n）看，顺/逆相反：
	# 第一段箭头表示顺转 → 反转切向以得到顺时针观感；第二段保持为逆时针观感
	_add_arc_arrowhead_at_segment_end(st, ro, seg_a0, seg_a1, true) # 添加第一段箭头。 ro:外半径 a0:起始角度 a1:结束角度 true:反转切向
	_add_arc_arrowhead_at_segment_end(st, ro, seg_b0, seg_b1, false) # 添加第二段箭头。 ro:外半径 a0:起始角度 a1:结束角度 false:不反转切向
	return st.commit() # 将 SurfaceTool 中的数据提交为 ArrayMesh。

func _append_arc_strip(st: SurfaceTool, ri: float, ro: float, a0: float, a1: float) -> void:
	var u := Vector3.RIGHT
	var v := Vector3.UP
	for i in ARC_SEGMENTS:
		var t0 := float(i) / float(ARC_SEGMENTS)
		var t1 := float(i + 1) / float(ARC_SEGMENTS)
		var ang0 := lerpf(a0, a1, t0)
		var ang1 := lerpf(a0, a1, t1)
		var p0i := _arc_pt(ri, ang0, u, v)
		var p0o := _arc_pt(ro, ang0, u, v)
		var p1i := _arc_pt(ri, ang1, u, v)
		var p1o := _arc_pt(ro, ang1, u, v)
		var n0 := _arc_radial_normal(ang0, u, v)
		var n1 := _arc_radial_normal(ang1, u, v)
		st.set_normal(n0)
		st.add_vertex(p0i)
		st.set_normal(n0)
		st.add_vertex(p0o)
		st.set_normal(n1)
		st.add_vertex(p1o)
		st.set_normal(n0)
		st.add_vertex(p0i)
		st.set_normal(n1)
		st.add_vertex(p1o)
		st.set_normal(n1)
		st.add_vertex(p1i)

func _add_arc_arrowhead_at_segment_end(st: SurfaceTool, r_outer: float, a0: float, a1: float, flip_tangent: bool) -> void:
	var u := Vector3.RIGHT # 右向量 这个vector3是单位向量，长度为1。
	# u是右向量，v是上向量，ang是结束角度，dtheta是角度差，tangent是切向量，
	# radial是径向向量，base是基点，tip是箭头尖端，wing是箭头翼，p_l是箭头左翼，p_r是箭头右翼，ntri是三角形法线。
	var v := Vector3.UP # 上向量
	var ang := a1 # 结束角度
	var dtheta := signf(a1 - a0) # 角度差
	if absf(a1 - a0) < 1e-5: # 如果结束角度和起始角度相差小于1e-5，则直接返回
	# 这里的1e-5是“1乘以10的负5次方”，即0.00001，并不是自然常数e（约2.718）；这种写法是科学计数法
		return
	var tangent := (-sin(ang) * u + cos(ang) * v).normalized() * dtheta # 切向量
	if flip_tangent: # 如果需要反转切向，则反转切向	flip_tangent: bool
		tangent = -tangent # 反转切向
	var radial := _arc_radial_normal(ang, u, v)
	var base := _arc_pt(r_outer, ang, u, v) # 基点
	var tip := base + tangent * (RING_WIDTH * 1.2) # 箭头尖端 箭头的长度是环宽的1.2倍
	var wing := radial * (RING_WIDTH * 0.6) # 箭头翼 箭头尾部宽度是环宽的0.6倍
	var p_l := base + wing # 箭头左翼
	var p_r := base - wing # 箭头右翼
	var ntri := tangent.cross(p_l - tip).normalized() # 三角形法线
	# 每次都要设置三角形法线，是因为 SurfaceTool 的 set_normal() 仅对后续 add_vertex() 生效。
	# 例如这里我们依次添加箭头三角形的每个顶点，每次 set_normal(ntri) 确保每个顶点都被分配了该三角形的法线，
	# 这样渲染时三角面片能获得统一的法线，显示为平面效果（否则顶点如果没有正确法线，光照和渲染会异常）。
	st.set_normal(ntri) # 设置三角形法线
	st.add_vertex(tip)  # 添加箭头尖端

	st.set_normal(ntri) # 设置三角形法线
	st.add_vertex(p_l)  # 添加箭头左翼

	st.set_normal(ntri) # 设置三角形法线
	st.add_vertex(p_r)  # 添加箭头右翼

	st.set_normal(ntri) # 对多个三角形连续绘制时，通常每组 set_normal+add_vertex 配对，便于扩展和统一书写

func _arc_pt(r: float, ang: float, u: Vector3, v: Vector3) -> Vector3:
	return r * (cos(ang) * u + sin(ang) * v)

func _arc_radial_normal(ang: float, u: Vector3, v: Vector3) -> Vector3:
	return (cos(ang) * u + sin(ang) * v).normalized()

## 该角块上，与层外法线 spec_n 最一致的外贴纸中心与法线
func _best_face_on_piece(piece: CubePiece, spec_n: Vector3) -> Array:
	var best_dot := -2.0
	var best_center := piece.position
	var best_n := spec_n
	var n_ref := spec_n.normalized()
	for lf in FACE_OFFSETS:
		var face_dir := lf.normalized()
		var world_n := piece.basis * face_dir
		if world_n.length_squared() < 1e-8:
			continue
		world_n = world_n.normalized()
		var d := world_n.dot(n_ref)
		if d > best_dot:
			best_dot = d
			best_center = piece.position + piece.basis * lf
			best_n = world_n
	return [best_center, best_n]

func _layer_face_center_and_normal(spec: Dictionary) -> Array:
	var layer: Callable = spec["layer"]
	var pieces: Array = layer.call()
	var n_ref: Vector3 = spec["normal"].normalized()
	if pieces.is_empty():
		return [Vector3.ZERO, n_ref]
	var acc_p := Vector3.ZERO
	var acc_n := Vector3.ZERO
	for p in pieces:
		var cp := p as CubePiece
		var r := _best_face_on_piece(cp, n_ref)
		acc_p += r[0]
		acc_n += r[1]
	acc_p /= float(pieces.size())
	acc_n = acc_n.normalized()
	return [acc_p, acc_n]

func _basis_from_normal(n: Vector3) -> Basis:
	var up := Vector3.UP
	if absf(n.dot(up)) > 0.92:
		up = Vector3.RIGHT
	var u := up.cross(n)
	if u.length_squared() < 1e-8:
		up = Vector3.FORWARD
		u = up.cross(n)
	u = u.normalized()
	var v := n.cross(u).normalized()
	return Basis(u, v, n)

func _update_entry(entry: Dictionary) -> void:
	var spec: Dictionary = entry["spec"]
	var cn := _layer_face_center_and_normal(spec)
	var center: Vector3 = cn[0]
	var n: Vector3 = cn[1]
	if n.length_squared() < 1e-8:
		n = spec["normal"].normalized()
	var basis := _basis_from_normal(n)
	var pos := center + n * FLOAT_OUT
	var holder: Node3D = entry["holder"]
	holder.transform = Transform3D(basis, pos)
	var mesh: MeshInstance3D = entry["mesh"]
	mesh.position = Vector3.ZERO
	# 碰撞盒局部位置：与 _build_faces 中弧中点一致（holder 局部 XY）
	var seg_a0 := HALO_TWIST
	var seg_a1 := HALO_TWIST + PI * 0.5
	var seg_b0 := HALO_TWIST + PI
	var seg_b1 := HALO_TWIST + PI * 1.5
	var mid_a := (seg_a0 + seg_a1) * 0.5
	var mid_b := (seg_b0 + seg_b1) * 0.5
	var r_hit := RING_RADIUS * 0.92
	entry["hit_cw"].position = Vector3(cos(mid_a) * r_hit, sin(mid_a) * r_hit, 0.0)
	entry["hit_ccw"].position = Vector3(cos(mid_b) * r_hit, sin(mid_b) * r_hit, 0.0)

func _try_pick_rotate(mb: InputEventMouseButton) -> void:
	if _cube == null or _cube.is_rotating:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(mb.position)
	var dir := cam.project_ray_normal(mb.position)
	var max_dist := 200.0
	var space := get_world_3d().direct_space_state
	var excluded: Array = []
	for _attempt in range(16):
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_dist)
		q.collide_with_areas = true
		q.collide_with_bodies = true
		q.collision_mask = 0xffffffff
		q.exclude = excluded
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		var col = hit.get("collider")
		if col == null:
			return
		if col is CollisionObject3D:
			var co := col as CollisionObject3D
			if co.has_meta(META_ACTION) and co.has_meta(META_HOLDER):
				var holder_node: Node3D = co.get_meta(META_HOLDER) as Node3D
				if holder_node and _is_halo_visible_from_camera(cam, holder_node):
					var act: Callable = co.get_meta(META_ACTION)
					act.call()
					get_viewport().set_input_as_handled()
					return
			# 背面光环（不可见）或其它碰撞体：排除后继续沿射线查找
			excluded.append(co.get_rid())
		else:
			return

## 相机须在该面外法线一侧（与贴纸同侧），避免穿过魔方点到背面光环
func _is_halo_visible_from_camera(cam: Camera3D, holder: Node3D) -> bool:
	var n_world: Vector3 = holder.global_transform.basis.z.normalized()
	var ref: Vector3 = holder.global_position
	var v := cam.global_position - ref
	return v.dot(n_world) > 0.02
