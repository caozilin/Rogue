extends Node2D
## Transparent pre-cast overlay on the unchanged arena. Simulation owns its action lock.
const Art = preload("res://scripts/art.gd")
var remaining := 0.0
var duration := 0.8
const MIN_INTERVAL := 10.0
var interval_remaining := 0.0
signal started(label: String, rage_exception: bool)
var title := ""
var subtitle := ""
var form := 1
var pose := "idle"
var font := SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var input_cover := Control.new()
	input_cover.size = Vector2(1280,800)
	input_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(input_cover)
	hide()

func is_active() -> bool:
	return remaining > 0.0

func announce(label: String, detail: String, body: int, expression: String, rage_exception := false) -> bool:
	if interval_remaining > 0.0 and not rage_exception: return false
	title = label
	subtitle = detail
	form = body
	pose = expression
	remaining = duration
	interval_remaining = MIN_INTERVAL
	show()
	queue_redraw()
	started.emit(label, rage_exception)
	return true

func tick_interval(delta: float) -> void:
	interval_remaining = maxf(0.0, interval_remaining-delta)

func advance(delta: float) -> void:
	tick_interval(delta)
	remaining = maxf(0.0, remaining-delta)
	visible = remaining > 0.0
	queue_redraw()

func _draw() -> void:
	if remaining <= 0: return
	var p := 1.0-remaining/duration
	var alpha := minf(1.0,p*10.0)*minf(1.0,(1.0-p)*6.0)
	var color := Color("ffd362") if form == 1 else Color("a0ff93")
	var slide := (1.0-minf(1.0,p*7.0))*180
	draw_texture_rect(Art.glow(),Rect2(-20,100,650,650),false,Color(color,alpha*0.15))
	draw_line(Vector2(0,205),Vector2(1280,300),Color(color,alpha*0.7),2,true)
	draw_line(Vector2(0,510),Vector2(1280,605),Color("ff82cc",alpha*0.7),2,true)
	var texture := Art.milk_character(form,pose)
	if texture != null: draw_texture_rect(texture,Rect2(90-slide,140,365,460),false,Color(1,1,1,alpha))
	var size := 52
	while size > 30 and font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > 720: size -= 1
	var title_at := Vector2(465+slide,380)
	var body_label := "奶龙 · 第一命" if form == 1 else "奶蛙 · 第二命"
	draw_string_outline(font,Vector2(469+slide,311),body_label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,4,Color(0,0,0,alpha))
	draw_string(font,Vector2(469+slide,311),body_label,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(1,0.95,0.83,alpha))
	draw_string_outline(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,size,7,Color(0,0,0,alpha))
	draw_string(font,title_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(color,alpha))
	draw_string_outline(font,Vector2(469+slide,425),subtitle,HORIZONTAL_ALIGNMENT_LEFT,720,20,4,Color(0,0,0,alpha))
	draw_string(font,Vector2(469+slide,425),subtitle,HORIZONTAL_ALIGNMENT_LEFT,720,20,Color(1,0.94,0.96,alpha))
	var hint := "技能即将释放 · 角色行动暂时锁定"
	draw_string_outline(font,Vector2(470,482),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,18,4,Color(0,0,0,alpha*0.85))
	draw_string(font,Vector2(470,482),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(color,alpha*0.85))
