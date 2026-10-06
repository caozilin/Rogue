extends RefCounted
## Shared enemy atlas, distinct class portraits and individual skill icons.
## Runtime gameplay does not depend on artwork; geometric fallback stays usable.

const PATH := "res://assets/sprites/survivors-atlas.png"
static var textures: Dictionary = {}
static var loaded := false
static var realistic_loaded := false
static var glow_texture: Texture2D
static var spell_texture: Texture2D

static func realistic(id: String) -> Texture2D:
	if not realistic_loaded:
		realistic_loaded = true
		var path := "res://assets/art/realistic-atlas.png"
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path)
			var cell := sheet.get_size() / Vector2(4, 3)
			var ids := ["mage", "warrior", "enemy", "elite", "fan", "ring", "sweep", "mortar", "spore_boss", "thorn_boss", "final_boss", "gem"]
			for index in range(ids.size()):
				var tile := AtlasTexture.new()
				tile.atlas = sheet
				var region := Rect2(Vector2(index % 4, index / 4) * cell, cell)
				# Tall crown / upright sword use the empty gutter above their cells.
				# Exclude those tips from the shooter cells directly above them.
				if ids[index] in ["spore_boss", "final_boss"]:
					region.position.y -= cell.y * 0.09
					region.size.y += cell.y * 0.09
				elif ids[index] in ["fan", "sweep"]:
					region.size.y *= 0.90
				tile.region = region
				textures["realistic/" + ids[index]] = tile
	return textures.get("realistic/" + id, null)

static func floor_texture() -> Texture2D:
	var key := "realistic/floor"
	if not textures.has(key):
		var path := "res://assets/art/stone-arena.png"
		textures[key] = load(path) if ResourceLoader.exists(path) else null
	return textures[key]

static func milk_character(form: int, pose := "idle") -> Texture2D:
	var column := 1 if pose == "tongue" else (2 if pose == "laugh" else 0)
	var key := "milk/%d/%d" % [form, column]
	if not textures.has(key):
		var path := "res://assets/art/milk-poses.png"
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path)
			var tile := AtlasTexture.new()
			tile.atlas = sheet
			var cell := sheet.get_size() / Vector2(3, 2)
			tile.region = Rect2(Vector2(column, form - 1) * cell, cell)
			# The lower heads extend into the transparent gutter above their cells.
			# Exclude those tips from the dragon portraits in the upper row.
			if form == 1:
				tile.region.size.y = cell.y * 0.94
			else:
				tile.region.position.y = cell.y * 0.95
				tile.region.size.y = cell.y * 1.05
			textures[key] = tile
		else:
			var fallback := "res://assets/art/nailoong-boss.png" if form == 1 else "res://assets/art/milkfrog-boss.png"
			textures[key] = load(fallback) if ResourceLoader.exists(fallback) else null
	return textures[key]

static func glow() -> Texture2D:
	if glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 128
		texture.height = 128
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0)
		glow_texture = texture
	return glow_texture

static func white() -> Texture2D:
	if spell_texture == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 32
		texture.height = 32
		spell_texture = texture
	return spell_texture

static func shadow(canvas: CanvasItem, center: Vector2, extent: Vector2, strength := 0.65) -> void:
	canvas.draw_texture_rect(glow(), Rect2(center - extent * 0.5, extent), false, Color(0.01, 0.015, 0.025, strength))

static func character(role: int) -> Texture2D:
	var texture := realistic("mage" if role == 0 else "warrior")
	if texture != null:
		return texture
	return asset("mage" if role == 0 else "warrior", "sprites")

static func skill_icon(id: String) -> Texture2D:
	return asset(id, "icons")

static func asset(id: String, folder: String) -> Texture2D:
	var key := folder + "/" + id
	if not textures.has(key):
		var path := "res://assets/" + key + ".svg"
		textures[key] = load(path) if ResourceLoader.exists(path) else null
	return textures[key]

static func sprite(id: String) -> Texture2D:
	var texture := realistic(id)
	if texture != null:
		return texture
	if not loaded:
		loaded = true
		if ResourceLoader.exists(PATH):
			var sheet: Texture2D = load(PATH)
			var cell := sheet.get_size() / 2.0
			var locations := {"hero": Vector2(0, 0), "enemy": Vector2(1, 0),
				"elite": Vector2(0, 1), "gem": Vector2(1, 1)}
			for key in locations:
				var tile := AtlasTexture.new()
				tile.atlas = sheet
				tile.region = Rect2(locations[key] * cell, cell)
				textures[key] = tile
	return textures.get(id, null)
