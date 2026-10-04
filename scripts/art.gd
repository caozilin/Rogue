extends RefCounted
## Shared atlas textures: both players use the very same character sprite.
## Runtime gameplay does not depend on artwork; geometric fallback stays usable.

const PATH := "res://assets/sprites/survivors-atlas.png"
static var textures: Dictionary = {}
static var loaded := false

static func sprite(id: String) -> Texture2D:
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
