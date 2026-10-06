extends RefCounted
## A lightweight cutout rig shared by all units. Simulation owns its clock.
const SHADER = preload("res://assets/effects/unit_motion.gdshader")
const GRID_X := 12
const GRID_Y := 16
static var meshes: Dictionary = {}

var body: MeshInstance2D
var surface: ShaderMaterial
var phase := 0.0
var idle_time := 0.0
var walk_weight := 0.0
var travel_lean := 0.0
var rush_weight := 0.0
var facing_sign := 1.0
var skin_key := ""

func attach(unit: Node2D) -> void:
	body = MeshInstance2D.new()
	body.name = "AnimatedBody"
	body.show_behind_parent = true
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	surface = ShaderMaterial.new()
	surface.shader = SHADER
	body.material = surface
	body.visible = false
	unit.add_child(body)
	_sync()

func reset(seed: float = 0.0) -> void:
	phase = seed
	idle_time = seed * 0.5
	walk_weight = 0.0
	travel_lean = 0.0
	rush_weight = 0.0
	facing_sign = 1.0
	_sync()

func advance(delta: float, displacement: Vector2, stride: float,
		sliding := false, attached := false) -> void:
	idle_time += delta
	var distance := displacement.length()
	# Teleports do not play several walk cycles in a single frame.
	var locomotion := distance > 0.001 and distance < maxf(90.0, delta * 900.0) and not attached
	var target_weight := minf(1.0, distance / maxf(delta, 0.001) / 32.0) if locomotion else 0.0
	walk_weight = move_toward(walk_weight, target_weight, delta * 9.0)
	if locomotion and not sliding:
		phase = fposmod(phase + distance / maxf(stride, 10.0) * TAU, TAU)
	var direction := displacement.normalized() if locomotion else Vector2.ZERO
	travel_lean = move_toward(travel_lean, direction.x, delta * 8.0)
	rush_weight = move_toward(rush_weight, 1.0 if sliding and locomotion else 0.0, delta * 14.0)
	if locomotion and absf(direction.x) > 0.22:
		facing_sign = -1.0 if direction.x < 0.0 else 1.0
	_sync()

func _sync() -> void:
	if surface == null:
		return
	surface.set_shader_parameter("phase", phase)
	surface.set_shader_parameter("idle_time", idle_time)
	surface.set_shader_parameter("walk_weight", walk_weight)
	surface.set_shader_parameter("travel_lean", travel_lean * facing_sign)
	surface.set_shader_parameter("rush_weight", rush_weight)

func render(texture: Texture2D, rect: Rect2, tint: Color, profile: int,
		offset := Vector2.ZERO, size_multiplier := 1.0) -> void:
	if body == null:
		return
	body.visible = texture != null
	if texture == null:
		return
	var key := str(texture.get_instance_id()) + str(rect)
	if key != skin_key:
		skin_key = key
		if not meshes.has(key):
			meshes[key] = _mesh(texture, rect)
		body.mesh = meshes[key]
		body.texture = texture.atlas if texture is AtlasTexture else texture
		surface.set_shader_parameter("rect_origin", rect.position)
		surface.set_shader_parameter("rect_size", rect.size)
	body.position = offset
	body.scale = Vector2(facing_sign, 1.0) * size_multiplier
	body.self_modulate = tint
	surface.set_shader_parameter("profile", profile)

func hide() -> void:
	if body != null:
		body.visible = false

static func _mesh(texture: Texture2D, rect: Rect2) -> ArrayMesh:
	var source := Rect2(Vector2.ZERO, Vector2.ONE)
	if texture is AtlasTexture:
		source = Rect2(texture.region.position / texture.atlas.get_size(), texture.region.size / texture.atlas.get_size())
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(GRID_Y + 1):
		for column in range(GRID_X + 1):
			var uv := Vector2(float(column) / GRID_X, float(row) / GRID_Y)
			var point := rect.position + uv * rect.size
			vertices.append(Vector3(point.x, point.y, 0))
			uvs.append(source.position + uv * source.size)
	for row in range(GRID_Y):
		for column in range(GRID_X):
			var a := row * (GRID_X + 1) + column
			var b := a + 1
			var c := a + GRID_X + 1
			indices.append_array(PackedInt32Array([a, b, c, b, c + 1, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
