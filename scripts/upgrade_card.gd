extends Button
## Keep the whole card clickable while its children only present the offer.
const Art = preload("res://scripts/art.gd")
var picture: TextureRect
var description: RichTextLabel

func _ready() -> void:
	text = ""
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(44, 44)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	description = RichTextLabel.new()
	description.bbcode_enabled = true
	description.fit_content = true
	description.scroll_active = false
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.add_theme_font_size_override("normal_font_size", 15)
	description.add_theme_font_size_override("bold_font_size", 15)
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	bold.font_weight = 700
	description.add_theme_font_override("bold_font", bold)
	column.add_child(description)

func show_offer(icon: String, title: String, rank: int, effect: String, major := false) -> void:
	picture.texture = Art.skill_icon(icon)
	var level := "[b][color=#ffda8a]解锁大技能[/color][/b]" if major else "升至 [b][color=#b9f2ff]Lv.%d / 3[/color][/b]" % rank
	description.text = "%s · %s\n[color=#d0dfec]%s[/color]" % [title, level, effect]
