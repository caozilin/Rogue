extends Control
const Sources = preload("res://scripts/damage_sources.gd")
const Balance = preload("res://scripts/balance.gd")
const Classes = preload("res://scripts/classes.gd")
var game
var player_id := 0
var title: Label
var summary: Label
var tabs: Array[Button] = []
var list: VBoxContainer
var current_rows: Array[Dictionary] = []
var signature := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.04, 0.72)
	shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			shade.accept_event()
			close())
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(300, 145)
	panel.size = Vector2(680, 620)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c2c")
	style.border_color = Color("54718b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	title = _label(box, "伤害来源", 26)
	var switches := HBoxContainer.new()
	switches.add_theme_constant_override("separation", 12)
	box.add_child(switches)
	for id in range(2):
		var button := Button.new()
		button.custom_minimum_size.y = 35
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(open_player.bind(id))
		switches.add_child(button)
		tabs.append(button)
	summary = _label(box, "", 18)
	var header := HBoxContainer.new()
	box.add_child(header)
	var source_heading := _label(header, "来源", 14)
	source_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for column in [{"text": "有效伤害", "width": 130}, {"text": "占比", "width": 90}]:
		var heading := _label(header, column.text, 14)
		heading.custom_minimum_size.x = column.width
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.modulate = Color("a5b6c9")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 210
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var note := _label(box, "不计溢出；反应、附身和后摇增伤计入原来源。\n雷楞塔、天雷链狱、雷霆潮汐和雷神裁决分别统计。", 13)
	note.modulate = Color("a5b6c9")
	var close_button := Button.new()
	close_button.text = "关闭明细 · ESC"
	close_button.custom_minimum_size.y = 36
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	box.add_child(close_button)
	visible = false

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _number(amount: float) -> String:
	var parts := ("%.1f" % amount).split(".")
	var grouped := ""
	for index in range(parts[0].length()):
		if index > 0 and (parts[0].length() - index) % 3 == 0: grouped += ","
		grouped += parts[0][index]
	return grouped + "." + parts[1]

func open_player(id: int) -> void:
	if game.selecting_classes or game.has_pending_upgrades(): return
	player_id = id
	game.damage_inspecting = true
	visible = true
	signature = ""
	refresh()

func close() -> void:
	visible = false
	game.damage_inspecting = false
	game.hud.refresh()

func refresh() -> void:
	if not visible: return
	var next_signature := str(player_id) + str(game.damage_breakdown) + str(game.damage_totals)
	if next_signature == signature: return
	signature = next_signature
	var color: Color = Balance.PLAYER_COLORS[player_id]
	title.text = "P%d · %s · 伤害来源" % [player_id + 1, Classes.NAMES[game.players[player_id].role]]
	title.modulate = color
	summary.text = "本局有效伤害  %s    ·    战斗已暂停" % _number(game.damage_totals[player_id])
	for id in range(2):
		tabs[id].text = "P%d · %s%s" % [id + 1, Classes.NAMES[game.players[id].role], " · 当前" if id == player_id else ""]
		tabs[id].modulate = Balance.PLAYER_COLORS[id]
	for old in list.get_children():
		list.remove_child(old)
		old.queue_free()
	current_rows = Sources.rows(game, player_id)
	for entry in current_rows:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		list.add_child(row)
		var line := HBoxContainer.new()
		row.add_child(line)
		var name := _label(line, entry.name, 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _label(line, _number(entry.amount), 15)
		value.custom_minimum_size.x = 130
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var share := _label(line, "%.1f%%" % (entry.share * 100.0), 15)
		share.custom_minimum_size.x = 90
		share.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 4
		bar.step = 0.0
		bar.max_value = 1.0
		bar.value = entry.share
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		var background := StyleBoxFlat.new()
		background.bg_color = Color("26354b")
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", background)
		row.add_child(bar)
