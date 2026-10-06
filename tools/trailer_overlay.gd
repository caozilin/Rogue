extends Node2D
## Video-only titles. CanvasLayer keeps captions away from the fighting area.
var director
var font := SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	font.font_weight = 700

func text_line(at: Vector2, content: String, size: int, color := Color.WHITE) -> void:
	draw_string_outline(font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.02, 0.03, 0.05, 0.85))
	draw_string(font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(y: float, content: String, size: int, color: Color) -> void:
	text_line(Vector2((1280 - font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), content, size, color)

func _draw() -> void:
	if director == null or director.shot_index < 0 or director.shot_index >= director.shots.size(): return
	var shot: Dictionary = director.shots[director.shot_index]
	var accent := Color("7ae1ff")
	if shot.kind in ["dash", "giant", "rescue", "king"]: accent = Color("ffc478")
	if shot.kind == "artillery": accent = Color("efafff")
	if shot.kind in ["dragon", "rebirth"]: accent = Color("ffe680")
	if shot.kind in ["frog", "clones"]: accent = Color("adffb6")
	draw_rect(Rect2(32, 57, 4, 34), accent)
	text_line(Vector2(49, 82), shot.title, 27)
	text_line(Vector2(1000, 80), "TWIN SURVIVORS", 17, accent)
	text_line(Vector2(35, 738), shot.detail, 19, Color("cddae6"))
	text_line(Vector2(1003, 738), "双人合作 · 强化构筑实机", 13, Color("9eacba"))
	draw_rect(Rect2(32, 749, 1216, 2), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(32, 749, 1216 * director.total_time / director.total_duration, 2), accent)
	if director.boss != null and is_instance_valid(director.boss):
		var ratio: float = clampf(director.boss.hp / director.boss.max_hp, 0, 1)
		draw_rect(Rect2(430, 98, 420, 3), Color(1, 1, 1, 0.14))
		draw_rect(Rect2(430, 98, 420 * ratio, 3), accent)
	if shot.kind in ["intro", "outro"]:
		var appear: float = clampf(director.shot_time * 2, 0, 1)
		centered(313, "双人幸存者", 78, Color(1, 1, 1, appear))
		centered(356, "T W I N   S U R V I V O R S", 23, Color(accent, appear))
		centered(570, "两个人。两种构筑。一起扛住终局。", 25, Color(1, 1, 1, appear))
		if shot.kind == "outro": centered(615, "本地双人合作  /  Godot 4 Demo", 19, Color(accent, appear))
	# A brief additive flash on cuts, never an opaque black frame.
	var flash: float = maxf(0, 1 - director.shot_time / 0.16) * 0.13
	if flash > 0: draw_rect(Rect2(0, 40, 1280, 720), Color(accent, flash))
