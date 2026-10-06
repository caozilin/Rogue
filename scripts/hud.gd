extends CanvasLayer

const Balance = preload("res://scripts/balance.gd")
const Classes = preload("res://scripts/classes.gd")
const ClassSelect = preload("res://scripts/class_select.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")
const SkillIcon = preload("res://scripts/skill_icon.gd")
const UpgradeCard = preload("res://scripts/upgrade_card.gd")
const Mage = preload("res://scripts/mage.gd")
const DamageDetails = preload("res://scripts/damage_details.gd")

var game
var stats_labels: Array[Label] = []
var skill_labels: Array[Label] = []
var skill_icons: Array = []
var health_bars: Array[ProgressBar] = []
var xp_bars: Array[ProgressBar] = []
var choice_panels: Array[PanelContainer] = []
var choice_titles: Array[Label] = []
var choice_buttons: Array = []
var choice_waiting: Array[Label] = []
var offer_signatures := ["", ""]
var team_panel: PanelContainer
var team_title: Label
var team_instructions: Label
var team_buttons: Array[Button] = []
var team_waiting: Label
var team_signature := ""
var time_label: Label
var damage_board: Panel
var damage_rows: Array[Button] = []
var damage_row_players := [0, 1]
var damage_details: Control
var footer: Label
var modal: PanelContainer
var modal_title: Label
var modal_detail: Label
var restart_button: Button
var upgrade_shade: ColorRect
var class_menu: Control
var boss_background: ColorRect
var boss_title: Label
var boss_health: ProgressBar
var boss_hint: Label
var other_boss_hint: Label

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
	_create_damage_board(root)
	footer = _label(root, Rect2(32, 717, 1216, 72), "", 15)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_background = ColorRect.new()
	# The bottom HUD strip starts below the arena, so Boss info never covers play.
	boss_background.position = Vector2(32, 706)
	boss_background.size = Vector2(1216, 72)
	boss_background.color = Color(0.04, 0.06, 0.1, 0.85)
	boss_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_background)
	boss_title = _label(root, Rect2(48, 706, 1184, 24), "", 17)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health = _bar(root, Rect2(48, 733, 1184, 7), Color("ffb86a"))
	boss_health.step = 0.0
	boss_hint = _label(root, Rect2(48, 745, 1184, 22), "", 14)
	boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	other_boss_hint = _label(root, Rect2(48, 770, 1184, 22), "", 14)
	other_boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	other_boss_hint.modulate = Color("ffc975")
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
	damage_details = DamageDetails.new()
	damage_details.game = game
	root.add_child(damage_details)

func _create_damage_board(root: Control) -> void:
	# Fits the gap between the skill docks, over the top wall rather than the central field.
	damage_board = Panel.new()
	damage_board.position = Vector2(488, 112)
	damage_board.size = Vector2(304, 68)
	damage_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_board.add_theme_stylebox_override("panel", _dock_style(Color(0.04, 0.07, 0.12, 0.62), Color(0.2, 0.3, 0.4, 0.5)))
	root.add_child(damage_board)
	var title := _label(damage_board, Rect2(8, 2, 288, 19), "累计伤害 · 点击查看来源", 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("b7c7d7")
	for row in range(2):
		var button := Button.new()
		button.position = Vector2(12, 22 + row * 21)
		button.size = Vector2(280, 21)
		button.flat = true
		button.tooltip_text = "点击查看该玩家各技能的有效伤害与占比"
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		var style := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(_open_damage_row.bind(row))
		damage_board.add_child(button)
		damage_rows.append(button)

func _open_damage_row(row: int) -> void:
	damage_details.open_player(damage_row_players[row])

func _damage_number(amount: float) -> String:
	var digits := str(floori(amount))
	var grouped := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0: grouped += ","
		grouped += digits[index]
	return grouped

func _refresh_damage_board() -> void:
	damage_board.visible = not game.selecting_classes and not game.has_pending_upgrades()
	var order := [0, 1] if game.damage_totals[0] >= game.damage_totals[1] else [1, 0]
	for row in range(2):
		var id: int = order[row]
		damage_row_players[row] = id
		damage_rows[row].text = "%d.  P%d    %s" % [row + 1, id + 1, _damage_number(game.damage_totals[id])]
		damage_rows[row].modulate = Balance.PLAYER_COLORS[id]

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
	var dock := Panel.new()
	dock.position = Vector2(left, 96)
	dock.size = Vector2(442, 96)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_stylebox_override("panel", _style(Color(0.04, 0.07, 0.12, 0.94), Color("263a50")))
	root.add_child(dock)
	var icons: Array = []
	for slot in range(4):
		var icon := SkillIcon.new()
		icon.position = Vector2(left + 8 + slot * 78, 102)
		root.add_child(icon)
		icons.append(icon)
	skill_icons.append(icons)
	skill_labels.append(_label(root, Rect2(left + 326, 108, 108, 70), "", 15))
	skill_labels[id].modulate = Balance.PLAYER_COLORS[id]
	skill_labels[id].mouse_filter = Control.MOUSE_FILTER_PASS

func _create_choices(root: Control, id: int) -> void:
	var left := 60 if id == 0 else 670
	var panel := _panel(root, Rect2(left, 400, 550, 350), Color(0.07, 0.11, 0.17, 0.9), Balance.PLAYER_COLORS[id])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := _box_label(box, "", 24)
	title.modulate = Balance.PLAYER_COLORS[id]
	choice_titles.append(title)
	_box_label(box, "仅强化自己的技能 · 鼠标左键点击选择", 14)
	var waiting := _box_label(box, "技能强化已选完\n等待全队 Buff 与另一名玩家选择", 19)
	waiting.custom_minimum_size.y = 170
	waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	choice_waiting.append(waiting)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var buttons: Array[Button] = []
	for index in range(3):
		var button := UpgradeCard.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _dock_style(Color(0.10, 0.16, 0.23, 0.78), Color("314660")))
		button.add_theme_stylebox_override("hover", _dock_style(Color(0.15, 0.23, 0.31, 0.9), Balance.PLAYER_COLORS[id]))
		button.add_theme_stylebox_override("pressed", _dock_style(Color("31495d"), Balance.PLAYER_COLORS[id]))
		# Bind the recipient and slot explicitly; refreshes only change presentation.
		button.pressed.connect(game.choose_upgrade.bind(id, index))
		row.add_child(button)
		buttons.append(button)
	choice_panels.append(panel)
	choice_buttons.append(buttons)
	panel.visible = false

func _create_team_choices(root: Control) -> void:
	team_panel = _panel(root, Rect2(80, 125, 1120, 250), Color(0.07, 0.11, 0.17, 0.9), Color("87f5b4"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	team_panel.add_child(box)
	team_title = _box_label(box, "", 24)
	team_title.modulate = Color("87f5b4")
	team_instructions = _box_label(box, "全队共享 · 鼠标左键任选一项，两人同时获得 · 三个窗口全部选完继续", 15)
	team_waiting = _box_label(box, "全队 Buff 已选完 · 等待下方技能强化", 20)
	team_waiting.custom_minimum_size.y = 120
	team_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for index in range(3):
		var button := UpgradeCard.new()
		button.custom_minimum_size = Vector2(0, 140)
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
	_refresh_damage_board()
	damage_details.refresh()
	var seconds: int = int(game.elapsed)
	var selecting: bool = game.has_pending_upgrades()
	var show_boss: bool = (game.boss_alive() or game.boss_notice_remaining > 0.0) and not selecting and not game.selecting_classes and not game.paused and not game.game_over
	boss_background.visible = show_boss
	boss_title.visible = show_boss
	boss_hint.visible = show_boss
	boss_health.visible = show_boss and game.boss_alive()
	other_boss_hint.visible = false
	boss_background.size.y = 72.0
	if game.boss_alive():
		var boss = game.mini_boss
		var stage_name: String = boss.phase_name() if game.final_battle else ("狂怒" if boss.enraged else "第一阶段")
		boss_title.text = "%s · %s · %s   %d / %d" % ["终局Boss" if game.final_battle else "小Boss", boss.display_name(), stage_name, int(boss.hp), int(boss.max_hp)]
		boss_title.modulate = Color("ff745c") if boss.enraged else Color("ffc975")
		boss_health.max_value = boss.max_hp
		boss_health.value = boss.hp
		boss_hint.text = boss.status_text()
		for enemy in game.enemies:
			if enemy != boss and not enemy.dead and enemy.kind == "boss":
				other_boss_hint.text = "仍在场：%s   %d / %d" % [enemy.display_name(), int(enemy.hp), int(enemy.max_hp)]
				other_boss_hint.visible = show_boss
				boss_background.size.y = 86.0
	else:
		boss_title.text = "%s已击败！" % game.boss_victory_name
		boss_hint.text = game.boss_notice
		boss_title.modulate = Color("87f5b4")
	var show_choices: bool = selecting and not game.game_over and not game.paused and not game.selecting_classes
	team_panel.visible = show_choices
	team_waiting.visible = not game.team_choosing
	team_title.text = "全队共享 Buff · 团队Lv.%d" % (game.team_level - game.team_pending_upgrades + 1) if game.team_choosing else "全队共享 Buff · 已选完"
	var team_maxed := not Upgrades.has_available(game.players[0].ranks)
	if team_maxed:
		team_title.text = "全队共享 Buff · 全部升满"
	team_waiting.text = "全队 Buff 全部升满（每项 3 级）\n等待尚未完成的技能强化" if team_maxed else "全队 Buff 已选完 · 等待下方技能强化"
	team_instructions.text = "全队共享 · 鼠标左键任选一项，两人同时获得 · 三个窗口全部选完继续"
	if game.choosing_opening_majors():
		team_title.text = "%s难度 · 开局大技能" % game.run_difficulty().name
		team_waiting.text = "每人选择 %d 个不重复大技能\n双方全部选完后开战，不消耗正常升级次数" % int(game.run_difficulty().starting_majors)
		team_instructions.text = "在下方各自的三张卡中鼠标选择 · 只解锁自己的技能 · 已选大技能不会重复出现"
	for index in range(team_buttons.size()):
		team_buttons[index].visible = game.team_choosing and index < game.team_offers.size()
	if game.team_choosing:
		var signature := str(game.team_offers) + str(game.players[0].ranks)
		if signature != team_signature:
			team_signature = signature
			for index in range(game.team_offers.size()):
				var offer: Dictionary = game.team_offers[index]
				var rank := int(game.players[0].ranks.get(offer.id, 0)) + 1
				team_buttons[index].show_offer("buff_" + str(offer.id), offer.title, rank, Upgrades.effect_text(offer.id, rank))
				team_buttons[index].tooltip_text = "%s\n%s\n同时作用于 P1 和 P2" % [offer.detail, offer.note]
	time_label.text = "%s\n%02d:%02d   %s" % ["破线模式 · 满强化" if game.breakthrough_mode else "双人幸存者 · %s" % game.run_difficulty().name, seconds / 60, seconds % 60,
		"开局选择" if game.choosing_opening_majors() else ("升级暂停" if selecting else ("终局决斗" if game.final_battle else "存活至终局"))]
	if not game.selecting_classes:
		var wave_left := maxi(0, int(ceil(game.next_wave - game.elapsed)))
		var stage := "混合围攻" if seconds >= 120 else ("重装加入" if seconds >= 60 else ("精英加入" if seconds >= 18 else "边缘来袭"))
		if seconds >= 150:
			stage = "炮击混战"
		elif seconds >= 95:
			stage = "扫射加入"
		elif seconds >= 50:
			stage = "环射加入"
		elif seconds >= 22:
			stage = "散射加入"
		if game.boss_alive():
			stage = "终局Boss交战" if game.final_battle else "小Boss交战"
		var event_text := "敌潮来袭！" if wave_left > int(Balance.WAVE_INTERVAL) - 3 else "敌潮 %ds" % wave_left
		if game.boss_encounters < 2 and game.next_boss - game.elapsed <= 8.0:
			event_text = "Boss %ds" % maxi(0, int(ceil(game.next_boss - game.elapsed)))
		if not game.final_battle and Balance.FINAL_BOSS_SECONDS - game.elapsed <= 10.0:
			event_text = "终局 %ds" % maxi(0, int(ceil(Balance.FINAL_BOSS_SECONDS - game.elapsed)))
		if game.final_battle:
			stage = "终局 %d / 3" % game.final_stage
			event_text = "奶龙 → 奶蛙 · 两条命" if game.final_stage == 3 else "双人对决"
			if game.victory: event_text = "已通关"
			if game.final_transition_remaining > 0.0:
				event_text = "%s %ds 后入场" % ["炮皇" if game.final_stage == 1 else "奶龙",int(ceil(game.final_transition_remaining))]
		time_label.text += "\n%s · %s" % [stage, event_text]
	for id in range(2):
		var player = game.players[id]
		_refresh_skill_icons(id, player)
		var status := "选 Buff 中" if player.choosing else ("已选完 · 等待队友" if selecting else ("倒地 · 等待队友" if player.downed else "战斗中"))
		if player.is_possessed() and not selecting:
			status = "附身 P%d · %.1fs" % [player.possession_host.player_id + 1, player.possession_remaining]
		if player.blessing_remaining > 0.0 and not selecting:
			status += " · 庇护盾 %.0f / %.1fs" % [player.blessing_shield, player.blessing_remaining]
		if player.counterattack_remaining > 0.0 and not selecting:
			status += " · 反攻 ×1.3 / %.1fs" % player.counterattack_remaining
		stats_labels[id].text = "团队Lv.%d  HP %d/%d  共享XP %d/%d  %s" % [game.team_level, int(player.hp),
			int(player.stats.max_hp), player.xp, Balance.xp_required(player.level), status]
		if game.breakthrough_mode:
			stats_labels[id].text = "满强化  HP %d/%d  %s" % [int(player.hp), int(player.stats.max_hp), status]
		stats_labels[id].tooltip_text = "伤害 %.1f | 间隔 %.2fs | 射弹 %d | 射程 %d | 每弹最多命中 %d 个怪物 | 暴击 %.1f%%（×%.2f）\n弹速 %.0f | 移速 %.1f | 每秒恢复最大生命 %.0f%%\n击杀 %d | 全队 Buff 等级 %s" % [
			player.stats.damage, player.stats.interval, player.stats.projectiles,
			player.stats.range, player.stats.pierce + 1, player.stats.crit * 100, player.stats.crit_multiplier,
			player.stats.projectile_speed, player.movement_speed(), player.stats.regen * 100.0,
			player.kills, str(player.ranks)]
		health_bars[id].max_value = float(player.stats.max_hp)
		health_bars[id].value = player.hp
		xp_bars[id].max_value = Balance.xp_required(player.level)
		xp_bars[id].value = player.xp
		xp_bars[id].visible = not game.breakthrough_mode
		choice_panels[id].visible = show_choices
		choice_waiting[id].visible = not player.choosing
		var skill_maxed := not SkillUpgrades.has_available(player.role, player.skill_ranks)
		choice_waiting[id].text = "技能强化全部获得\n等待其他窗口选择" if skill_maxed else "技能强化已选完\n等待其他窗口选择"
		for index in range(choice_buttons[id].size()):
			choice_buttons[id][index].visible = player.choosing and index < player.offers.size()
		choice_titles[id].text = "P%d · %s技能 · 已选完" % [id + 1, Classes.NAMES[player.role]]
		if skill_maxed:
			choice_titles[id].text = "P%d · %s技能 · 全部升满" % [id + 1, Classes.NAMES[player.role]]
		if player.choosing:
			choice_titles[id].text = "P%d · %s强化 · 第 %d 次" % [id + 1, Classes.NAMES[player.role], player.skill_choices + 1]
			if bool(player.offers[0].get("major", false)):
				choice_titles[id].text = "P%d · 第 %d 次 · 选择大技能" % [id + 1, player.skill_choices + 1]
			if game.opening_major_pending[id] > 0:
				choice_titles[id].text = "P%d · 开局大技能 · 剩余 %d 个" % [id + 1, game.opening_major_pending[id]]
			var signature := str(player.offers) + str(player.skill_ranks)
			if signature != offer_signatures[id]:
				offer_signatures[id] = signature
				for index in range(player.offers.size()):
					var offer: Dictionary = player.offers[index]
					var rank := int(player.skill_ranks.get(offer.id, 0)) + 1
					var major := bool(offer.get("major", false))
					var detail := "[b]%s[/b]" % offer.detail if major else SkillUpgrades.effect_text(offer.id, rank)
					var icon := "fireball" if str(offer.id).begins_with("fire_") else ("frost" if str(offer.id).begins_with("frost_") else ("dash" if str(offer.id).begins_with("dash_") else ("rescue" if str(offer.id).begins_with("rescue_") else "giant")))
					if str(offer.id).begins_with("tower_"):
						icon = offer.id
					if offer.id == "dash_blades": icon = "dash_blades"
					if str(offer.id).begins_with("warcry_"):
						icon = "warcry"
					choice_buttons[id][index].show_offer(icon, offer.title, rank, detail, major)
					choice_buttons[id][index].tooltip_text = "%s\n%s\n%s" % [offer.title, offer.detail, offer.note]
	footer.text = "P1：Q / E / R / 空格    |    P2：右键 / 1 / 2 / 3（支持小键盘）\n法师：火球 / 冰霜 / 附身 / 雷楞塔 · 战士：突进 / 战吼 / 巨化 / 救援 · Buff 鼠标选择 · ESC 暂停 · 敌人 %d" % game.enemies.size()
	footer.text += " · 全体复活 %d/1" % (0 if game.team_revive_used else 1)
	if game.team_revive_notice_remaining > 0.0:
		footer.text = "全体复活已触发 · 双方满血并获得 3 秒保护\n" + footer.text.get_slice("\n", 1)
		if show_boss: boss_hint.text += " · 全体复活已触发"
	footer.visible = not show_choices and not show_boss
	upgrade_shade.visible = selecting and not game.game_over and not game.paused
	modal.visible = game.game_over or game.paused
	if game.game_over:
		modal_title.text = "终局胜利 · %s已败" % game.boss_victory_name if game.victory else "两人倒地 · 本局结束"
		modal_detail.text = "存活 %02d:%02d   /   总击杀 %d\nP1 等级 %d   ·   P2 等级 %d\n%s" % [seconds / 60, seconds % 60,
			game.players[0].kills + game.players[1].kills, game.players[0].level, game.players[1].level,
			"武王、炮皇、奶龙与奶蛙均已击败！" if game.victory else ("已进入终局，再挑战一次。" if game.final_battle else "互相掩护，再挑战一次。")]
		restart_button.visible = true
	elif game.paused:
		modal_title.text = "游戏已暂停"
		modal_detail.text = "按 ESC 继续\n上方全队 Buff + 下方双方技能强化，全部选完恢复。"
		restart_button.visible = false
	class_menu.refresh()

func _refresh_skill_icons(id: int, player) -> void:
	var recovery: float = player.cooldown_recovery()
	var main_cd: float = player.skill_cooldown / recovery
	var main_total: float = float(player.skill_stats.cooldown) / recovery
	var main_active: float = maxf(player.suppression_remaining, player.dash_remaining)
	# Keep the sweep denominator stable when active time changes into cooldown.
	main_total += float(player.skill_stats.duration) if player.role == Classes.MAGE else Classes.DASH_DURATION
	# The original skill starts recovering only after its effect ends.
	if player.suppression_remaining > 0.0:
		main_cd += player.suppression_remaining
	elif player.dash_remaining > 0.0 and player.return_remaining <= 0.0:
		main_cd += player.dash_remaining
	var slots: Array = []
	if player.role == Classes.RAIDER:
		var taunt_active: float = player.warcry_remaining
		for dummy in game.taunt_dummies:
			if dummy.owner_id == id and dummy.is_active(): taunt_active = maxf(taunt_active, dummy.warcry_remaining)
		slots = [
			["dash", player.skill_name(), "Q" if id == 0 else "右键", main_cd, main_total, main_active,
				"%s；无敌、无初始击退，基础物理伤害 ×3.2；冲刺独立伤害 ×%.2f\n宽度 %.0f、距离 %.0f；每次冲刺技能族有效命中返还 %.2fs，单次最多 %.0f%%（已返还 %.2fs）\n独立乘区覆盖本体、二段、破空斩、剑气残痕，与全局伤害和并肩反攻相乘。\n二段突袭：%s · 剑气残痕：%s · 破空斩：%s\n残痕持续 2 秒，每 0.2 秒物理伤害 ×0.25，最多 10 跳，结束处决伤害 ×6；本体、破空斩、路径跳伤与处决均触发回流。\n二段窗口 2 秒，两段共用返还上限；基础冷却 6 秒。" % ["Q 自动索敌：优先最高等级，同等级选最近；无目标不释放" if id == 0 else "右键朝鼠标方向冲刺", float(player.skill_stats.dash_power), float(player.skill_stats.hit_radius) * 2.0, float(player.skill_stats.distance), float(player.skill_stats.refund_seconds), float(player.skill_stats.refund_cap) * 100.0, player.dash_refund_total, "已获得" if bool(player.skill_stats.dash_recast) else "未获得", "已获得" if bool(player.skill_stats.dash_blades) else "未获得", "已获得" if bool(player.skill_stats.dash_wave) else "未获得"]],
			["warcry", "嘲讽木桩" if bool(player.skill_stats.warcry_dummy) else "战吼", "E" if id == 0 else "1", player.warcry_cooldown, Classes.WARCRY_COOLDOWN, taunt_active,
				"原地生成嘲讽木桩，持续 %.0f 秒，生命为自身最大生命 %.0f%%；仅木桩嘲讽。冷却 20 秒。" % [player.skill_stats.dummy_duration, float(player.skill_stats.dummy_hp) * 100] if bool(player.skill_stats.warcry_dummy) else "全图敌人优先锁定自己，持续 %.0f 秒；冷却 20 秒。大技能 1：嘲讽木桩，替代自身嘲讽。" % player.skill_stats.warcry_duration],
			["giant", "巨大化撞击", "R" if id == 0 else "2", player.giant_cooldown + player.giant_remaining, Classes.GIANT_COOLDOWN + float(player.skill_stats.giant_duration), player.giant_remaining,
				"体型 ×%.1f、移速 +100%%、减伤 60%%；持续 %.1fs，结束后开始 12 秒冷却\n撞击伤害 ×%.1f，击退 %.0f（受敌人韧性影响）；同一敌人每 0.5 秒可再撞击\n人肉炮弹：%s · 荆棘反甲：%s · 震地余波：%s\n反甲：巨化期间反弹敌方原始伤害 ×3，再乘全队伤害加成；不受自身护盾、减伤影响。" % [float(player.skill_stats.giant_size), float(player.skill_stats.giant_duration), Classes.GIANT_DAMAGE * float(player.skill_stats.giant_power), Classes.GIANT_KNOCKBACK * float(player.skill_stats.giant_power), "已获得" if bool(player.skill_stats.giant_cannon) else "未获得", "已获得" if bool(player.skill_stats.giant_thorns) else "未获得", "已获得" if bool(player.skill_stats.giant_quake) else "未获得"]],
			["rescue", "救援", "空格" if id == 0 else "3", player.rescue_cooldown, Classes.RESCUE_COOLDOWN, player.carry_remaining,
				"瞬移到队友并携带 3 秒，替队友承担伤害；释放后自身无敌 1 秒，冷却 20 秒。救援立即复活机会：%s。\n被动护盾 %.1f / %.1f：每秒恢复最大生命 %.1f%%，上限 %.0f%%。\n大技能 1 · 庇护救援：%s。抵达后补满自身被动护盾；队友 10 秒庇护，护盾为战士最大生命 50%%，韧性 50%%，每秒额外回血 3%%。\n大技能 3 · 并肩反攻：%s。成功携带或立即复活后双方伤害独立 ×1.3，持续 5 秒。" % ["已用完" if game.instant_revive_used else "可用", player.guard_shield, player.guard_shield_max(), float(player.skill_stats.guard_regen) * 100, float(player.skill_stats.guard_cap) * 100, "已获得" if bool(player.skill_stats.rescue_blessing) else "未获得", "已获得" if bool(player.skill_stats.rescue_counterattack) else "未获得"]]
		]
	else:
		var keys := ["Q", "E", "R"] if id == 0 else ["右键", "1", "2"]
		slots = [
			["fireball", "大火球", keys[0], player.fireball_cooldown / recovery, Mage.FIREBALL_COOLDOWN / recovery, 0.0,
				"最高等级优先；半径 ×%.1f，火系伤害 ×%.2f，%d 重火球（每 0.3 秒重新定位索敌）\n伤害强化作用于火球、火区、灼烧和吞能炎星爆炸\n炎浪击退：%s · 烈焰之路：%s · 吞能炎星：%s\n火属性命中冰附着目标，3 秒内火伤 ×2；冷却 15 秒。" % [float(player.skill_stats.fire_width), float(player.skill_stats.fire_power), int(player.skill_stats.fire_count), "已获得" if bool(player.skill_stats.fire_push) else "未获得", "已获得" if bool(player.skill_stats.fire_ground) else "未获得", "已获得" if bool(player.skill_stats.fire_growth) else "未获得"]],
			["frost", "冰霜 Lv.%d" % int(player.skill_ranks.get("frost_width", 0)), keys[1], player.frost_cooldown / recovery, Mage.FROST_COOLDOWN / recovery, maxf(player.frost_remaining, player.frost_ward_remaining),
				"随身领域半径 %.0f；伤害频率 ×%.0f；所有冰系伤害独立 ×%.1f\n移速 -40%%、攻速 -35%%，领域持续 5 秒，冷却 15 秒\n冰锥雨：%s · 冰径：%s · 庇护寒域：%s（护罩 %.0f / %.0f）\n冰伤乘区覆盖领域和所有冰系大技能，与全局伤害、附身、反应相乘；冰附着/冰径目前无持续伤害。\n守护罩固定半径 1.5 身位（48 像素），仅挡敌方弹丸；生命为施放时最大生命 100%%，独立持续 10 秒，剩余 %.1fs。等级、体型、附身不扩大护罩，破罩不结束领域。\n冰属性命中火附着目标，3 秒内冰伤 ×2。" % [game.mage_system.frost_radius(player), float(player.skill_stats.frost_rate), float(player.skill_stats.frost_power), "已获得" if bool(player.skill_stats.frost_cones) else "未获得", "已获得" if bool(player.skill_stats.frost_path) else "未获得", "已获得" if bool(player.skill_stats.frost_ward) else "未获得", player.frost_shield_hp, player.frost_shield_max, player.frost_ward_remaining]],
			["possession", "附身", keys[2], player.possession_cooldown / recovery, Mage.POSSESSION_COOLDOWN / recovery, player.possession_remaining,
				"%d 范围内附到队友头顶，持续 5 秒；伤害 +35%%、范围 +25%%、冷却恢复 +25%%，冷却 25 秒。" % int(Mage.POSSESSION_RANGE)],
			["lightning_tower", player.skill_name(), player.skill_binding(), 0.0, 1.0, 0.0,
				"原地召唤固定雷楞塔，持续 %.0f 秒，全屏索敌\n每 %.2f 秒电击最近敌人；角色伤害 ×0.47 ×核心 %.2f，最终雷击倍率 ×%.3f，继承全局伤害加成\n天雷链狱：%s · 雷霆潮汐：%s · 雷神裁决：%s\n所有大技能倍率以这次雷击伤害为基准，不重复乘 0.47；链狱每段 ×0.15，雷柱 ×2 / 2.5 / 3；潮汐环 ×1.8、末秒环 ×2.4、自爆 ×6 ×寿命/10；Boss 裁决 12 连击触发 ×15。\n最多储存 2 次，每 15 秒依次恢复 1 次，释放间隔 2 秒。" % [float(player.skill_stats.tower_duration), 0.8 / float(player.skill_stats.tower_rate), float(player.skill_stats.tower_damage), Classes.TOWER_BASE_DAMAGE * float(player.skill_stats.tower_damage), "已获得" if bool(player.skill_stats.tower_chain) else "未获得", "已获得" if bool(player.skill_stats.tower_tide) else "未获得", "已获得" if bool(player.skill_stats.tower_judgment) else "未获得"]]
		]
	for slot in range(4):
		var data: Array = slots[slot]
		if player.role == Classes.RAIDER and slot == 2:
			data[6] += "\n受击回流：%s · 巨化期间每次有效受击减少冷却 0.5 秒，单次最多 3 秒（已返还 %.1fs）。" % ["已获得" if bool(player.skill_stats.giant_refund) else "未获得", player.giant_refund_total]
		var blocked: bool = player.downed
		if player.role == Classes.MAGE and slot == 2 and not player.is_possessed():
			blocked = blocked or player.is_carried() or player.carrying != null or player.possessed_by != null
		skill_icons[id][slot].refresh(data[0], data[1], data[2], data[3], data[4], data[5],
			blocked, Balance.PLAYER_COLORS[id], data[6])
	if player.role == Classes.MAGE:
		var data: Array = slots[3]
		skill_icons[id][3].refresh_charges(data[0], data[1], data[2], player.tower_charges,
			Classes.TOWER_MAX_CHARGES, player.tower_recharge / recovery, Classes.TOWER_RECHARGE / recovery,
			player.tower_release_cooldown, Classes.TOWER_RELEASE_COOLDOWN, game.mage_system.tower_remaining(id),
			player.downed, Balance.PLAYER_COLORS[id], data[6])
	# A second dash remains available while the shared cooldown recovers.
	if player.role == Classes.RAIDER and player.dash_recast_remaining > 0.0 and player.dash_remaining <= 0.0:
		skill_icons[id][0].refresh("dash", "二段突袭", "Q" if id == 0 else "右键", 0.0, main_total,
			player.dash_recast_remaining, player.downed, Balance.PLAYER_COLORS[id],
			"%s；剩余 %.1fs。两段去重累计穿敌数量，共用冷却和返还上限。" % ["再次 Q 按火球规则重新索敌冲刺" if id == 0 else "再次右键朝最新鼠标方向冲刺", player.dash_recast_remaining])
	skill_labels[id].text = "%s\n四个技能" % Classes.NAMES[player.role]
	if player.downed:
		skill_labels[id].text = "%s\n倒地禁用" % Classes.NAMES[player.role]
	elif player.is_carried():
		skill_labels[id].text = "%s\n携带 %.1fs" % [Classes.NAMES[player.role], player.carried_by.carry_remaining]
	elif player.is_possessed():
		skill_labels[id].text = "%s\n附身 %.1fs" % [Classes.NAMES[player.role], player.possession_remaining]
	skill_labels[id].tooltip_text = "悬停各个技能图标可查看说明。\n灰度扇形顺时针恢复彩色；数字为距离就绪的秒数。\n亮绿色边框表示技能正在生效。"
