extends Control
## Pre-run selection: keyboard or mouse, with no combat timers running.

const Classes = preload("res://scripts/classes.gd")
const Balance = preload("res://scripts/balance.gd")
const Art = preload("res://scripts/art.gd")

var game
var role_buttons: Array = []
var details: Array[Label] = []
var ready_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.04, 0.07, 1.0)
	add_child(shade)
	var title := _label(self, "双人幸存者 · 选择职业", 32)
	title.position = Vector2(240, 65)
	title.size = Vector2(800, 50)
	var hint := _label(self, "各自任选一个职业，也可以选择相同职业 · 双方准备后开战", 17)
	hint.position = Vector2(190, 123)
	hint.size = Vector2(900, 35)
	for id in range(2):
		var panel := PanelContainer.new()
		panel.position = Vector2(90 + id * 580, 185)
		panel.size = Vector2(520, 450)
		panel.add_theme_stylebox_override("panel", _style(Color("142334"), Balance.PLAYER_COLORS[id]))
		add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 13)
		panel.add_child(box)
		var heading := _label(box, "P%d  /  %s  /  技能 %s" % [id + 1,
			"WASD" if id == 0 else "方向键", "空格" if id == 0 else "回车"], 23)
		heading.modulate = Balance.PLAYER_COLORS[id]
		var portrait := TextureRect.new()
		portrait.texture = Art.sprite("hero")
		portrait.custom_minimum_size = Vector2(0, 78)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(portrait)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var buttons: Array[Button] = []
		for role in range(2):
			var button := Button.new()
			button.custom_minimum_size.y = 50
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func(): game.select_class(id, role))
			row.add_child(button)
			buttons.append(button)
		role_buttons.append(buttons)
		var detail := _label(box, "", 16)
		detail.custom_minimum_size.y = 105
		details.append(detail)
		var ready := Button.new()
		ready.custom_minimum_size.y = 48
		ready.focus_mode = Control.FOCUS_NONE
		ready.pressed.connect(func(): game.toggle_ready(id))
		box.add_child(ready)
		ready_buttons.append(ready)
	var start := Button.new()
	start.position = Vector2(465, 669)
	start.size = Vector2(350, 54)
	start.text = "使用当前选择开始游戏"
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func(): game.start_run())
	add_child(start)
	var footer := _label(self, "自动攻击 · 战斗中只需移动 + 一个技能键\n共享经验，独立 Build · 靠近倒地队友 3 秒复活", 16)
	footer.position = Vector2(190, 739)
	footer.size = Vector2(900, 50)
	refresh()

func _label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func refresh() -> void:
	visible = game.selecting_classes
	if not visible:
		return
	for id in range(2):
		for role in range(2):
			var selected: bool = game.selected_classes[id] == role
			var key := role + (1 if id == 0 else 7)
			role_buttons[id][role].text = "%s [%d] %s" % ["✓" if selected else "", key, Classes.NAMES[role]]
			role_buttons[id][role].add_theme_stylebox_override("normal", _style(
				Color("25445a") if selected else Color("182b3f"),
				Balance.PLAYER_COLORS[id] if selected else Color("35495d")))
		details[id].text = Classes.description(game.selected_classes[id])
		ready_buttons[id].text = "%s [%s]" % ["已准备 · 再按取消" if game.class_ready[id] else "准备",
			"空格" if id == 0 else "回车"]
