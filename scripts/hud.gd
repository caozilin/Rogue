extends CanvasLayer

const Balance = preload("res://scripts/balance.gd")
const Classes = preload("res://scripts/classes.gd")
const ClassSelect = preload("res://scripts/class_select.gd")

var game
var stats_labels: Array[Label] = []
var skill_labels: Array[Label] = []
var health_bars: Array[ProgressBar] = []
var xp_bars: Array[ProgressBar] = []
var choice_panels: Array[PanelContainer] = []
var choice_titles: Array[Label] = []
var choice_buttons: Array = []
var choice_waiting: Array[Label] = []
var offer_signatures := ["", ""]
var team_panel: PanelContainer
var team_title: Label
var team_buttons: Array[Button] = []
var team_waiting: Label
var team_signature := ""
var time_label: Label
var footer: Label
var modal: PanelContainer
var modal_title: Label
var modal_detail: Label
var restart_button: Button
var upgrade_shade: ColorRect
var class_menu: Control

func _ready() -> void:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 16
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	upgrade_shade = ColorRect.new()
	upgrade_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_shade.color = Color(0.02, 0.04, 0.07, 0.28)
	upgrade_shade.visible = false
	root.add_child(upgrade_shade)
	for id in range(2):
		_create_player_hud(root, id)
		_create_choices(root, id)
	_create_team_choices(root)
	time_label = _label(root, Rect2(495, 17, 290, 76), "", 20)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer = _label(root, Rect2(32, 717, 1216, 72), "", 15)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal = _panel(root, Rect2(390, 235, 500, 290), Color("18263b"), Color("87f5b4"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	modal.add_child(box)
	modal_title = _box_label(box, "", 32)
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_detail = _box_label(box, "", 17)
	modal_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_button = Button.new()
	restart_button.text = "重新开始  [R]"
	restart_button.custom_minimum_size.y = 48
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.pressed.connect(func(): game.restart())
	box.add_child(restart_button)
	modal.visible = false
	class_menu = ClassSelect.new()
	class_menu.game = game
	root.add_child(class_menu)

func _label(parent: Control, rect: Rect2, text: String, size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _box_label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _dock_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := _style(fill, edge)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _panel(parent: Control, rect: Rect2, fill: Color, edge: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(fill, edge))
	parent.add_child(panel)
	return panel

func _bar(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("263349")
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	parent.add_child(bar)
	# Set size after disabling percentage and installing the slim styles.
	bar.position = rect.position
	bar.size = rect.size
	return bar

func _create_player_hud(root: Control, id: int) -> void:
	var left := 32 if id == 0 else 806
	var title := _label(root, Rect2(left, 8, 440, 27), "P%d  /  %s" % [id + 1, "W A S D" if id == 0 else "↑ ↓ ← →"], 20)
	title.modulate = Balance.PLAYER_COLORS[id]
	stats_labels.append(_label(root, Rect2(left, 35, 445, 27), "", 14))
	stats_labels[id].mouse_filter = Control.MOUSE_FILTER_PASS
	health_bars.append(_bar(root, Rect2(left, 68, 442, 9), Balance.PLAYER_COLORS[id]))
	xp_bars.append(_bar(root, Rect2(left, 83, 442, 6), Color("87f5b4")))
	skill_labels.append(_label(root, Rect2(left, 92, 442, 20), "", 13))
	skill_labels[id].modulate = Balance.PLAYER_COLORS[id]

func _create_choices(root: Control, id: int) -> void:
	var left := 60 if id == 0 else 670
	var panel := _panel(root, Rect2(left, 390, 550, 320), Color(0.07, 0.11, 0.17, 0.9), Balance.PLAYER_COLORS[id])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _box_label(box, "", 24)
	title.modulate = Balance.PLAYER_COLORS[id]
	choice_titles.append(title)
	_box_label(box, "仅强化自己的技能 · %s 或鼠标选择" % ("1 / 2 / 3" if id == 0 else "7 / 8 / 9"), 14)
	var waiting := _box_label(box, "技能强化已选完\n等待全队 Buff 与另一名玩家选择", 19)
	waiting.custom_minimum_size.y = 170
	waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	choice_waiting.append(waiting)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var buttons: Array[Button] = []
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 66)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _dock_style(Color(0.10, 0.16, 0.23, 0.78), Color("314660")))
		button.add_theme_stylebox_override("hover", _dock_style(Color(0.15, 0.23, 0.31, 0.9), Balance.PLAYER_COLORS[id]))
		button.add_theme_stylebox_override("pressed", _dock_style(Color("31495d"), Balance.PLAYER_COLORS[id]))
		button.pressed.connect(func(): game.choose_upgrade(id, index))
		row.add_child(button)
		buttons.append(button)
	choice_panels.append(panel)
	choice_buttons.append(buttons)
	panel.visible = false

func _create_team_choices(root: Control) -> void:
	team_panel = _panel(root, Rect2(80, 125, 1120, 235), Color(0.07, 0.11, 0.17, 0.9), Color("87f5b4"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	team_panel.add_child(box)
	team_title = _box_label(box, "", 24)
	team_title.modulate = Color("87f5b4")
	_box_label(box, "全队共享 · 4 / 5 / 6 或鼠标任选一项，两人同时获得 · 三个窗口全部选完继续", 15)
	team_waiting = _box_label(box, "全队 Buff 已选完 · 等待下方技能强化", 20)
	team_waiting.custom_minimum_size.y = 120
	team_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 130)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("normal", _dock_style(Color("1b2c3e"), Color("456153")))
		button.add_theme_stylebox_override("hover", _dock_style(Color("2b4550"), Color("87f5b4")))
		button.pressed.connect(func(): game.choose_team_upgrade(index))
		row.add_child(button)
		team_buttons.append(button)
	team_panel.visible = false

func refresh() -> void:
	if time_label == null:
		return
	var seconds: int = int(game.elapsed)
	var selecting: bool = game.has_pending_upgrades()
	var show_choices: bool = selecting and not game.game_over and not game.paused and not game.selecting_classes
	team_panel.visible = show_choices
	team_waiting.visible = not game.team_choosing
	team_title.text = "全队共享 Buff · 团队Lv.%d" % (game.team_level - game.team_pending_upgrades + 1) if game.team_choosing else "全队共享 Buff · 已选完"
	for button in team_buttons:
		button.visible = game.team_choosing
	if game.team_choosing:
		var signature := str(game.team_offers) + str(game.players[0].ranks)
		if signature != team_signature:
			team_signature = signature
			for index in range(3):
				var offer: Dictionary = game.team_offers[index]
				team_buttons[index].text = "[%d] %s · %d次\n\n%s" % [index + 4, offer.title,
					int(game.players[0].ranks.get(offer.id, 0)), offer.detail]
				team_buttons[index].tooltip_text = "%s\n%s\n同时作用于 P1 和 P2" % [offer.detail, offer.note]
	time_label.text = "双人幸存者\n%02d:%02d   %s" % [seconds / 60, seconds % 60,
		"升级暂停" if selecting else ("10 分钟达成 ✓" if game.milestone else "存活 10 分钟")]
	for id in range(2):
		var player = game.players[id]
		var skill_status := "就绪"
		if player.downed:
			skill_status = "倒地，无法使用"
		elif player.return_remaining > 0.0:
			skill_status = "再按返回 %.1fs · 标记 %d" % [player.return_remaining, game.marked_count(id)]
		elif player.suppression_remaining > 0.0:
			skill_status = "压制中 %.1fs" % player.suppression_remaining
		elif player.skill_cooldown > 0.0:
			skill_status = "冷却 %.1fs" % player.skill_cooldown
		skill_labels[id].text = "%s · [%s] %s · %s" % [Classes.NAMES[player.role],
			"空格" if id == 0 else "回车", Classes.SKILL_NAMES[player.role], skill_status]
		var status := "选 Buff 中" if player.choosing else ("已选完 · 等待队友" if selecting else ("倒地 · 等待队友" if player.downed else "战斗中"))
		stats_labels[id].text = "团队Lv.%d  HP %d/%d  共享XP %d/%d  %s" % [game.team_level, int(player.hp),
			int(player.stats.max_hp), player.xp, Balance.xp_required(player.level), status]
		stats_labels[id].tooltip_text = "伤害 %.1f | 间隔 %.2fs | 射弹 %d | 射程 %d | 穿透 %d | 暴击 %.1f%%（×%.2f）\n弹速 %.0f | 移速 %.0f | 恢复 %.2f/s\n击杀 %d | 升级次数 %s" % [
			player.stats.damage, player.stats.interval, player.stats.projectiles,
			player.stats.range, player.stats.pierce, player.stats.crit * 100, player.stats.crit_multiplier,
			player.stats.projectile_speed, player.stats.speed, player.stats.regen,
			player.kills, str(player.ranks)]
		health_bars[id].max_value = float(player.stats.max_hp)
		health_bars[id].value = player.hp
		xp_bars[id].max_value = Balance.xp_required(player.level)
		xp_bars[id].value = player.xp
		choice_panels[id].visible = show_choices
		choice_waiting[id].visible = not player.choosing
		for button in choice_buttons[id]:
			button.visible = player.choosing
		choice_titles[id].text = "P%d · %s · 已选完" % [id + 1, Classes.SKILL_NAMES[player.role]]
		if player.choosing:
			var choice_level: int = player.level - player.pending_upgrades + 1
			choice_titles[id].text = "P%d · %s强化 · Lv.%d" % [id + 1, Classes.SKILL_NAMES[player.role], choice_level]
			var signature := str(player.offers) + str(player.skill_ranks)
			if signature != offer_signatures[id]:
				offer_signatures[id] = signature
				for index in range(3):
					var offer: Dictionary = player.offers[index]
					var key := index + (1 if id == 0 else 7)
					var detail := str(offer.detail)
					choice_buttons[id][index].text = "[%d] %s · %d次\n%s" % [key, offer.title,
						int(player.skill_ranks.get(offer.id, 0)), detail]
					choice_buttons[id][index].tooltip_text = "%s\n%s\n%s" % [offer.title, offer.detail, offer.note]
	footer.text = "P1 技能 空格 · 强化 1 / 2 / 3     |     全队 Buff 4 / 5 / 6     |     P2 技能 回车 · 强化 7 / 8 / 9\n共享经验 · 升级选 1 个全队 Buff + 各自技能强化  /  靠近队友 3 秒复活  /  ESC 暂停  /  敌人 %d" % game.enemies.size()
	footer.visible = not show_choices
	upgrade_shade.visible = selecting and not game.game_over and not game.paused
	modal.visible = game.game_over or game.paused
	if game.game_over:
		modal_title.text = "两人倒地 · 本局结束"
		modal_detail.text = "存活 %02d:%02d   /   总击杀 %d\nP1 等级 %d   ·   P2 等级 %d\n%s" % [seconds / 60, seconds % 60,
			game.players[0].kills + game.players[1].kills, game.players[0].level, game.players[1].level,
			"已完成 10 分钟目标！" if game.milestone else "互相掩护，再挑战一次。"]
		restart_button.visible = true
	elif game.paused:
		modal_title.text = "游戏已暂停"
		modal_detail.text = "按 ESC 继续\n上方全队 Buff + 下方双方技能强化，全部选完恢复。"
		restart_button.visible = false
	class_menu.refresh()
