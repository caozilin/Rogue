extends Control
## Pre-run selection: keyboard or mouse, with no combat timers running.

const Classes = preload("res://scripts/classes.gd")
const Balance = preload("res://scripts/balance.gd")
const Art = preload("res://scripts/art.gd")

var game
var role_buttons: Array = []
var details: Array[Label] = []
var ready_buttons: Array[Button] = []
var portraits: Array[TextureRect] = []
var mode_buttons: Array[Button] = []
var difficulty_buttons: Array[Button] = []
var hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.04, 0.07, 1.0)
	add_child(shade)
	var title := _label(self, "双人幸存者 · 选择职业", 32)
	title.position = Vector2(240, 22)
	title.size = Vector2(800, 50)
	hint = _label(self, "", 17)
	hint.position = Vector2(190, 76)
	hint.size = Vector2(900, 35)
	for mode in range(2):
		var button := Button.new()
		button.position = Vector2(315 + mode * 330, 120)
		button.size = Vector2(310, 46)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): game.select_mode(mode == 1))
		add_child(button)
		mode_buttons.append(button)
	for index in range(Balance.RUN_DIFFICULTIES.size()):
		var button := Button.new()
		button.position = Vector2(230 + index * 280, 188)
		button.size = Vector2(260, 36)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func(): game.select_difficulty(index))
		add_child(button)
		difficulty_buttons.append(button)
	for id in range(2):
		var panel := PanelContainer.new()
		panel.position = Vector2(90 + id * 580, 230)
		panel.size = Vector2(520, 420)
		panel.add_theme_stylebox_override("panel", _style(Color("142334"), Balance.PLAYER_COLORS[id]))
		add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		var heading := _label(box, "P%d  /  %s  /  准备 %s" % [id + 1,
			"WASD" if id == 0 else "方向键", "空格" if id == 0 else "回车"], 23)
		heading.modulate = Balance.PLAYER_COLORS[id]
		var portrait := TextureRect.new()
		portrait.texture = Art.character(game.selected_classes[id])
		portrait.custom_minimum_size = Vector2(0, 72)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(portrait)
		portraits.append(portrait)
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
		detail.custom_minimum_size.y = 140
		details.append(detail)
		var ready := Button.new()
		ready.custom_minimum_size.y = 48
		ready.focus_mode = Control.FOCUS_NONE
		ready.pressed.connect(func(): game.toggle_ready(id))
		box.add_child(ready)
		ready_buttons.append(ready)
	var start := Button.new()
	start.position = Vector2(465, 680)
	start.size = Vector2(350, 54)
	start.text = "使用当前选择开始游戏"
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func(): game.start_run())
	add_child(start)
	var footer := _label(self, "技能统一：P1 Q / E / R / 空格；P2 右键 / 1 / 2 / 3（支持小键盘）\n法师：火球 / 冰霜 / 附身 / 雷楞塔；战士：突进 / 战吼 / 巨化 / 救援", 16)
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
	var tuning: Dictionary = game.run_difficulty()
	hint.text = "各自任选职业 · %s难度 · 开局每人可选 %d 个大技能，双方选完开战" % [tuning.name, tuning.starting_majors] if not game.breakthrough_mode else "破线模式 · 所有强化已点满 · 武王 → 炮皇 → 奶龙"
	if not game.breakthrough_mode and game.selected_difficulty == 0:
		hint.text = "各自任选职业 · 简单难度 · 从基础技能开始成长，双方准备后开战"
	for index in range(difficulty_buttons.size()):
		var button := difficulty_buttons[index]
		var selected: bool = not game.breakthrough_mode and game.selected_difficulty == index
		var entry: Dictionary = Balance.RUN_DIFFICULTIES[index]
		button.disabled = game.breakthrough_mode
		button.text = ("✓ " if selected else "") + ("简单 · 当前基础数值" if index == 0 else "%s · 伤害 +%.0f%% / 生命 +%.0f%%" % [entry.name, (float(entry.damage) - 1.0) * 100, (float(entry.health) - 1.0) * 100])
		button.tooltip_text = "普通模式：敌方伤害 ×%.2f，生命 ×%.2f；开局每人选择 %d 个不重复大技能，后续升级照常。" % [entry.damage, entry.health, entry.starting_majors] if not game.breakthrough_mode else "难度选择用于普通成长模式；破线模式采用独立满强化挑战数值。"
		var style := _style(Color("25445a") if selected else Color("182b3f"), Color("ffe08a") if selected else Color("35495d"))
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override("normal", style)
	for mode in range(2):
		var selected: bool = game.breakthrough_mode == (mode == 1)
		mode_buttons[mode].text = ("✓ " if selected else "") + ("普通模式 · 从零成长" if mode == 0 else "破线模式 · 满强化三连 Boss")
		mode_buttons[mode].add_theme_stylebox_override("normal", _style(
			Color("25445a") if selected else Color("182b3f"), Color("ffe08a") if selected else Color("35495d")))
		mode_buttons[mode].tooltip_text = "所有大小技能与全局 Buff 点满；直接挑战武王 → 炮皇 → 奶龙（含奶蛙第二条命），血量按职业组合调整。" if mode == 1 else "从基础属性开局，击杀升级后选择强化，再挑战终局 Boss。"
	for id in range(2):
		portraits[id].texture = Art.character(game.selected_classes[id])
		for role in range(2):
			var selected: bool = game.selected_classes[id] == role
			var key := role + (1 if id == 0 else 7)
			role_buttons[id][role].text = "%s [%d] %s" % ["✓" if selected else "", key, Classes.NAMES[role]]
			role_buttons[id][role].add_theme_stylebox_override("normal", _style(
				Color("25445a") if selected else Color("182b3f"),
				Balance.PLAYER_COLORS[id] if selected else Color("35495d")))
		details[id].text = Classes.description(game.selected_classes[id])
		if id == 0 and game.selected_classes[id] == Classes.RAIDER:
			details[id].text = details[id].text.replace("右键朝鼠标突进 230", "[Q] 优先最高等级索敌突进 230").replace("[1]", "[E]").replace("[2]", "[R]").replace("[3]", "[空格]")
		if id == 1 and game.selected_classes[id] == Classes.MAGE:
			details[id].text = details[id].text.replace("[Q]", "[右键]").replace("[E]", "[1]").replace("[R]", "[2]").replace("[空格]", "[3]")
		if game.breakthrough_mode:
			details[id].text = _full_build_description(game.selected_classes[id], id)
		ready_buttons[id].text = "%s [%s]" % ["已准备 · 再按取消" if game.class_ready[id] else "准备",
			"空格" if id == 0 else "回车"]

func _full_build_description(role: int, id: int) -> String:
	var keys := ["Q", "E", "R", "空格"] if id == 0 else ["右键", "1", "2", "3"]
	var shared := "全局满级：伤害 / 攻速 / 生命 ×2.5，四发贯穿弹"
	if role == Classes.MAGE:
		return "[%s] 四重火球 · 范围 ×2.5，三项大强化全开\n[%s] 冰霜 · 范围 ×2.5，频率 ×4，三项大强化全开\n[%s] 附身 · 伤害 +35%%，范围与冷却恢复 +25%%\n[%s] 雷楞塔 · 高频增幅，连锁 / 潮汐 / 裁决全开\n所有小强化 Lv.3 · 九项大技能全部解锁\n%s" % [keys[0], keys[1], keys[2], keys[3], shared]
	return "[%s] 突进 · 宽幅长驱，二段 / 炎刃 / 破空斩全开\n[%s] 木桩嘲讽 16 秒，生命为自身上限 250%%\n[%s] 巨化 ×4 / 4.5秒，反甲 / 回流 / 炮弹 / 震地\n[%s] 救援 · 庇护 / 并肩反攻，被动护盾上限 45%%\n所有小强化 Lv.3 · 十项大技能全部解锁\n%s" % [keys[0], keys[1], keys[2], keys[3], shared]
