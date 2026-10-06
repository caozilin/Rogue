extends Control
## Presentation only: cooldowns are read from Player, never advanced by the HUD.
const Art = preload("res://scripts/art.gd")
const COOLDOWN_SHADER = preload("res://assets/icons/cooldown.gdshader")

var picture: TextureRect
var countdown: Label
var binding: Label
var caption: Label
var effect: Label
var cooldown_material: ShaderMaterial
var stock: Label
var charge_bar: ProgressBar
var fraction := 0.0
var active := false
var disabled := false
var accent := Color.WHITE

func _ready() -> void:
	size = Vector2(64, 86)
	mouse_filter = Control.MOUSE_FILTER_PASS
	picture = TextureRect.new()
	picture.position = Vector2(2, 2)
	picture.size = Vector2(60, 60)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_material = ShaderMaterial.new()
	cooldown_material.shader = COOLDOWN_SHADER
	picture.material = cooldown_material
	add_child(picture)
	binding = _label(Rect2(4, 3, 56, 18), 11)
	binding.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	countdown = _label(Rect2(0, 20, 64, 29), 21)
	countdown.add_theme_constant_override("outline_size", 6)
	effect = _label(Rect2(3, 46, 58, 17), 10)
	caption = _label(Rect2(-7, 66, 78, 20), 12)
	stock = _label(Rect2(26, 2, 35, 18), 12)
	stock.visible = false
	charge_bar = ProgressBar.new()
	charge_bar.show_percentage = false
	charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b2edff")
	var background := StyleBoxFlat.new()
	background.bg_color = Color("1e3247")
	charge_bar.add_theme_stylebox_override("fill", fill)
	charge_bar.add_theme_stylebox_override("background", background)
	charge_bar.visible = false
	add_child(charge_bar)
	charge_bar.position = Vector2(3, 60)
	charge_bar.size = Vector2(58, 3)

func _label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color("0b1221"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func refresh(icon: String, title: String, key: String, cooldown: float,
		total: float, remaining_effect: float, blocked: bool, color: Color, detail: String) -> void:
	stock.visible = false
	charge_bar.visible = false
	picture.texture = Art.skill_icon(icon)
	fraction = clampf(cooldown / maxf(total, 0.01), 0.0, 1.0)
	active = remaining_effect > 0.01
	disabled = blocked
	accent = color
	cooldown_material.set_shader_parameter("remaining", fraction)
	cooldown_material.set_shader_parameter("disabled", disabled)
	countdown.text = "%ds" % maxi(1, int(ceil(cooldown - 0.001))) if cooldown > 0.0 else ("禁用" if disabled else "")
	binding.text = key
	caption.text = title
	caption.modulate = Color("85919e") if disabled else Color("d9e5f1")
	effect.text = "生效 %.1fs" % remaining_effect if active else ("就绪" if cooldown <= 0.0 and not disabled else "")
	effect.modulate = Color("a7ffcf") if active else color
	tooltip_text = "[%s] %s\n%s" % [key, title, detail]
	if cooldown > 0.0:
		tooltip_text += "\n距离就绪：%.1f 秒" % cooldown
	if disabled:
		tooltip_text += "\n当前无法释放"
	queue_redraw()

func refresh_charges(icon: String, title: String, key: String, charges: int,
		capacity: int, recharge: float, recharge_total: float, release: float,
		release_total: float, remaining: float, blocked: bool, color: Color, detail: String) -> void:
	var wait := release if release > 0.0 else (recharge if charges == 0 else 0.0)
	var total := release_total if release > 0.0 else recharge_total
	refresh(icon, title, key, wait, total, remaining, blocked, color, detail)
	stock.visible = true
	stock.text = "%d/%d" % [charges, capacity]
	stock.modulate = color if charges > 0 else Color("a2adbd")
	charge_bar.visible = charges < capacity
	charge_bar.value = (1.0 - clampf(recharge / maxf(recharge_total, 0.01), 0.0, 1.0)) * 100.0
	effect.text = "充能 %ds" % maxi(1, ceili(recharge)) if charges < capacity else "储存已满"
	effect.modulate = Color("b2edff")
	tooltip_text += "\n储存：%d/%d · 下次充能 %.1fs · 释放间隔 %.1fs" % [charges, capacity, recharge if charges < capacity else 0.0, release]

func _draw() -> void:
	var edge := Color("465467") if fraction > 0.0 or disabled else accent
	if active:
		edge = Color("a7ffcf")
	draw_rect(Rect2(0, 0, 64, 64), Color("101a2b"))
	draw_rect(Rect2(1, 1, 62, 62), edge, false, 2.0)
