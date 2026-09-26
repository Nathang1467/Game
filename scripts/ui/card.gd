extends Control
## A juicy, wobbly item card. Used everywhere items are shown.

const UI = preload("res://scripts/ui/ui.gd")

signal pressed(card)

var kind := "part"
var id := ""
var extra := {}
var compact := false
var price := -1
var selected := false
var disabled := false
var face_down := false
var _hover := false
var _t := 0.0
var _name_l: Label
var _desc_l: Label
var _flip := 0.0

var mode := 0

func setup(k: String, i: String, ex: Dictionary = {}, size_mode = 0) -> Control:
	kind = k
	id = i
	extra = ex
	mode = int(size_mode)
	compact = mode > 0
	price = ex.get("price", -1)
	custom_minimum_size = [Vector2(150, 206), Vector2(112, 150), Vector2(86, 116), Vector2(64, 86)][mode]
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "
	_t = randf() * 10.0
	_build_labels()
	return self

func _build_labels() -> void:
	for c in get_children():
		c.queue_free()
	var w := custom_minimum_size.x
	_name_l = UI.label(_title(), [16, 13, 11, 10][mode], UI.CREAM, "main", 4 if mode >= 2 else 5)
	_name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_l.position = Vector2(6, custom_minimum_size.y * (0.52 if not compact else 0.6))
	_name_l.size = Vector2(w - 12, [34, 40, 34, 30][mode])
	if mode == 2:
		_name_l.position = Vector2(4, custom_minimum_size.y * 0.6)
		_name_l.size = Vector2(w - 8, 40)
	_name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_l)
	if mode == 3:
		_name_l.visible = false
	if not compact:
		_desc_l = UI.label(_desc(), 11, UI.CREAM.darkened(0.08), "main", 3)
		_desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_desc_l.position = Vector2(8, custom_minimum_size.y * 0.52 + 30)
		_desc_l.size = Vector2(w - 16, custom_minimum_size.y * 0.48 - 36)
		_desc_l.clip_text = false
		_desc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_desc_l)
	if face_down:
		_name_l.visible = false
		if _desc_l:
			_desc_l.visible = false

func set_face_down(v: bool) -> void:
	face_down = v
	if _name_l:
		_name_l.visible = not v
	if _desc_l:
		_desc_l.visible = not v
	queue_redraw()

func _title() -> String:
	match kind:
		"capsule": return {"part": "Part Capsule", "blueprint": "Blueprint Capsule", "tool": "Tool Capsule", "fault": "Fault Capsule", "ball": "Ball Capsule", "firmware": "Chip Capsule"}.get(id, "Capsule")
		"credit": return DB.CREDITS[id].name
		"ball":
			var e: String = extra.get("eng", "")
			return DB.BALLS[id].name + (" · " + DB.ENGRAVINGS[e].name if e != "" else "")
		"empty": return "Empty"
		"stat": return extra.get("title", id)
	return DB.item_name(kind, id)

func _desc() -> String:
	match kind:
		"capsule":
			return {"part": "Pick 1 of 3 Parts.", "blueprint": "Pick 1 of 3 Blueprints.", "tool": "Pick 1 of 3 Tools.", "fault": "Pick 1 of 2 Faults.", "ball": "Pick 1 of 3 balls.", "firmware": "Pick 1 of 2 Firmware chips."}.get(id, "")
		"credit": return DB.CREDITS[id].desc
		"ball":
			var d: String = DB.BALLS[id].desc
			var e: String = extra.get("eng", "")
			if e != "":
				d += " " + DB.ENGRAVINGS[e].desc
			return d
		"empty": return "Nothing installed."
		"stat": return extra.get("desc", "")
	return DB.item_desc(kind, id)

func _rarity() -> String:
	match kind:
		"part": return DB.PARTS[id].rarity
		"firmware": return DB.FIRMWARE[id].rarity
		"fault": return "R"
		"mod": return "U" if DB.MODS[id].tier == 1 else "R"
	return ""

func _body_color() -> Color:
	if face_down:
		return Color("3a2d5a")
	if kind == "part" and DB.THEME_COLORS.has(DB.PARTS[id].theme):
		return UI.kind_color("part").lerp(DB.THEME_COLORS[DB.PARTS[id].theme], 0.18)
	return UI.kind_color(kind)

func _process(delta: float) -> void:
	_t += delta
	pivot_offset = size * 0.5
	var target_scale := 1.0
	var target_rot := sin(_t * 1.3) * 0.012
	if _hover and not disabled:
		target_scale = 1.08
		var m := get_local_mouse_position() - size * 0.5
		target_rot = clampf(m.x / size.x, -0.5, 0.5) * 0.12
	if selected:
		target_scale = 1.1
	scale = scale.lerp(Vector2.ONE * target_scale, minf(1.0, delta * 14.0))
	rotation = lerpf(rotation, target_rot, minf(1.0, delta * 10.0))
	if _flip > 0.0:
		_flip = maxf(0.0, _flip - delta * 3.0)
		scale.x *= absf(cos(_flip * PI))
	modulate = Color(1, 1, 1, 0.45) if disabled else Color.WHITE
	queue_redraw()

func flip_in() -> void:
	_flip = 1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		if not disabled:
			Sfx.play("card", randf_range(0.9, 1.2), -10.0)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not disabled:
			pressed.emit(self)
			accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var lift := -6.0 if selected else 0.0
	r.position.y += lift
	# shadow
	var sh := UI.style(Color(0, 0, 0, 0.45), 12)
	draw_style_box(sh, Rect2(r.position + Vector2(0, 7), r.size))
	# body
	var body := _body_color()
	var sb := UI.style(body, 12)
	sb.border_color = body.darkened(0.45)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	draw_style_box(sb, r)
	# art window
	var art := Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, r.size.y * (0.46 if not compact else 0.52)))
	var ab := UI.style(body.darkened(0.55), 8)
	draw_style_box(ab, art)
	if face_down:
		_draw_back(art)
	else:
		_draw_art(art)
	# rarity band
	var rar := _rarity()
	if rar != "" and rar != "S" and not face_down:
		var rc: Color = DB.RARITY_COLORS[rar]
		draw_rect(Rect2(art.position + Vector2(0, art.size.y - 6), Vector2(art.size.x, 6)), rc)
	# lower text plate
	var plate := Rect2(r.position + Vector2(6, r.size.y * (0.5 if not compact else 0.58)), Vector2(r.size.x - 12, r.size.y * (0.5 if not compact else 0.42) - 8))
	draw_style_box(UI.style(Color(0, 0, 0, 0.28), 8), plate)
	# finish overlays
	var fin: String = extra.get("finish", "")
	if fin != "" and not face_down:
		_draw_finish(r, fin)
	if extra.get("rental", false):
		_tag(Vector2(r.size.x - 4, r.position.y + 4), "RENT", UI.RED, true)
	if extra.get("wear", 0.0) > 0.0:
		_tag(Vector2(4, r.position.y + 4), "WORN %d%%" % int(extra.wear * 100), UI.MUTED.darkened(0.3), false)
	if extra.get("burning", false):
		_tag(Vector2(4, r.position.y + 4), "BURNING", UI.ORANGE, false)
	if extra.get("upgrade", 1.0) > 1.001:
		_tag(Vector2(r.size.x - 4, r.position.y + r.size.y - 22), "+%d%%" % int(round((extra.upgrade - 1.0) * 100)), UI.GREEN, true)
	if price >= 0:
		var txt := "T%d" % price if price > 0 else "FREE"
		var f := UI.font("head")
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 18
		var pr := Rect2(Vector2(r.size.x * 0.5 - w * 0.5, r.position.y - 26), Vector2(w, 26))
		draw_style_box(UI.style(UI.PANEL_DARK, 8), pr)
		draw_string_outline(f, pr.position + Vector2(9, 19), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, UI.EDGE)
		draw_string(f, pr.position + Vector2(9, 19), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.TICKET)
	if selected:
		var sel := UI.style(Color(0, 0, 0, 0), 14)
		sel.border_color = UI.TICKET
		sel.border_width_left = 3
		sel.border_width_right = 3
		sel.border_width_top = 3
		sel.border_width_bottom = 3
		sel.draw_center = false
		draw_style_box(sel, r.grow(4))

func _area(pp: PackedVector2Array) -> float:
	var a := 0.0
	for i in pp.size():
		var j := (i + 1) % pp.size()
		a += pp[i].x * pp[j].y - pp[j].x * pp[i].y
	return a * 0.5

func _tag(pos: Vector2, txt: String, col: Color, right: bool) -> void:
	var f := UI.font("main")
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
	var p := pos - Vector2(w if right else 0, 0)
	draw_style_box(UI.style(col, 6), Rect2(p, Vector2(w, 18)))
	draw_string(f, p + Vector2(5, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.CREAM)

func _draw_back(art: Rect2) -> void:
	var c := art.get_center()
	for i in 6:
		draw_arc(c, 8.0 + i * 7.0, 0, TAU, 32, Color(1, 1, 1, 0.08 + 0.02 * i), 2.0)
	var f := UI.font("head")
	draw_string_outline(f, c + Vector2(-9, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 6, UI.EDGE)
	draw_string(f, c + Vector2(-9, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, UI.JACKPOT)

func _draw_finish(r: Rect2, fin: String) -> void:
	var col: Color = DB.FINISHES[fin].color
	var fb := UI.style(Color(0, 0, 0, 0), 12)
	fb.draw_center = false
	fb.border_color = col
	fb.border_width_left = 3
	fb.border_width_right = 3
	fb.border_width_top = 3
	fb.border_width_bottom = 3
	draw_style_box(fb, r.grow(1))
	var x := fmod(_t * 60.0, r.size.x + 80.0) - 40.0
	match fin:
		"chrome", "holo":
			var c2 := col
			if fin == "holo":
				c2 = Color.from_hsv(fmod(_t * 0.3, 1.0), 0.6, 1.0)
			c2.a = 0.35
			var pts := PackedVector2Array([Vector2(x, r.position.y + 4), Vector2(x + 18, r.position.y + 4), Vector2(x - 12, r.end.y - 4), Vector2(x - 30, r.end.y - 4)])
			var clip := Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8))
			var poly := Geometry2D.intersect_polygons(pts, PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)]))
			for pp in poly:
				if pp.size() >= 3 and absf(_area(pp)) > 2.0:
					draw_colored_polygon(pp, c2)
		"neon":
			var g := col
			g.a = 0.25 + 0.15 * sin(_t * 5.0)
			var gb := UI.style(Color(0, 0, 0, 0), 14)
			gb.draw_center = false
			gb.border_color = g
			gb.border_width_left = 6
			gb.border_width_right = 6
			gb.border_width_top = 6
			gb.border_width_bottom = 6
			draw_style_box(gb, r.grow(5))
		"gold":
			draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(1, 0.8, 0.2, 0.08))
		"phantom":
			draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(0.8, 0.7, 1.0, 0.12 + 0.06 * sin(_t * 3.0)))

func _draw_art(a: Rect2) -> void:
	var c := a.get_center()
	var s := minf(a.size.x, a.size.y)
	match kind:
		"part":
			_draw_part_icon(c, s, DB.PARTS[id].socket, id)
			var th: String = DB.PARTS[id].theme
			if th != "":
				draw_circle(a.position + Vector2(10, 10), 5, DB.THEME_COLORS[th])
		"firmware":
			var chip := Rect2(c - Vector2(s * 0.3, s * 0.22), Vector2(s * 0.6, s * 0.44))
			for i in 5:
				var x := chip.position.x + 6 + i * (chip.size.x - 12) / 4.0
				draw_line(Vector2(x, chip.position.y - 8), Vector2(x, chip.end.y + 8), Color("c9d1c8"), 3)
			draw_style_box(UI.style(Color("1d2a24"), 4), chip)
			draw_rect(Rect2(chip.position + Vector2(6, 6), Vector2(10, 10)), Color("3fae7a"))
			var f := UI.font("dmd")
			draw_string(f, chip.position + Vector2(6, chip.size.y - 8), DB.FIRMWARE[id].name.substr(0, 6).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 8, 16, Color("7dffb0"))
		"ball":
			_draw_ball_icon(c, s * 0.3, DB.BALLS[id].color, id)
		"tool":
			draw_line(c + Vector2(-s * 0.25, s * 0.25), c + Vector2(s * 0.18, -s * 0.18), Color("e0d8f0"), 8)
			draw_circle(c + Vector2(s * 0.2, -s * 0.2), s * 0.12, Color("e0d8f0"))
			draw_circle(c + Vector2(s * 0.24, -s * 0.24), s * 0.06, _body_color().darkened(0.55))
			draw_circle(c + Vector2(-s * 0.25, s * 0.25), 5, Color("e0d8f0"))
		"blueprint":
			for i in 7:
				draw_line(Vector2(a.position.x, a.position.y + i * a.size.y / 6.0), Vector2(a.end.x, a.position.y + i * a.size.y / 6.0), Color(1, 1, 1, 0.12), 1)
				draw_line(Vector2(a.position.x + i * a.size.x / 6.0, a.position.y), Vector2(a.position.x + i * a.size.x / 6.0, a.end.y), Color(1, 1, 1, 0.12), 1)
			if id != "master_plan":
				_draw_part_icon(c, s * 0.8, _shot_socket(id), "", Color("bfe0ff"))
			else:
				draw_arc(c, s * 0.3, 0, TAU, 32, Color("bfe0ff"), 3)
				draw_arc(c, s * 0.18, 0, TAU, 32, Color("bfe0ff"), 3)
		"fault":
			for i in 9:
				var y := a.position.y + 6 + i * (a.size.y - 12) / 8.0
				var off := sin(_t * 7.0 + i * 1.7) * 8.0
				draw_line(Vector2(a.position.x + 8 + off, y), Vector2(a.end.x - 8 + off * 0.5, y), Color(1, 0.2, 0.3, 0.3 + 0.1 * (i % 3)), 3)
			var f := UI.font("head")
			draw_string_outline(f, c + Vector2(-26, 8), "ERR", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, UI.EDGE)
			draw_string(f, c + Vector2(-26, 8), "ERR", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ff4d6d"))
		"mod":
			var t := Rect2(c - Vector2(s * 0.4, s * 0.2), Vector2(s * 0.8, s * 0.4))
			draw_style_box(UI.style(Color("fff1c9"), 6), t)
			draw_circle(Vector2(t.position.x, t.get_center().y), 8, _body_color().darkened(0.55))
			draw_circle(Vector2(t.end.x, t.get_center().y), 8, _body_color().darkened(0.55))
			var f := UI.font("head")
			draw_string(f, t.position + Vector2(14, t.size.y * 0.7), "MOD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b0701a"))
		"capsule":
			var col := UI.kind_color({"part": "part", "blueprint": "blueprint", "tool": "tool", "fault": "fault", "ball": "ball", "firmware": "firmware"}.get(id, "capsule"))
			draw_circle(c, s * 0.32, Color(1, 1, 1, 0.9))
			draw_arc(c, s * 0.32, 0, PI, 24, col, s * 0.32 * 0.95)
			draw_arc(c, s * 0.32, 0, TAU, 32, UI.EDGE, 3)
			draw_line(c - Vector2(s * 0.32, 0), c + Vector2(s * 0.32, 0), UI.EDGE, 3)
		"credit":
			draw_circle(c, s * 0.3, UI.TICKET)
			draw_circle(c, s * 0.22, UI.TICKET.darkened(0.25))
			var f := UI.font("head")
			draw_string(f, c + Vector2(-8, 9), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.CREAM)
		"empty":
			draw_arc(c, s * 0.25, 0, TAU, 32, Color(1, 1, 1, 0.15), 3)
		"stat":
			var f := UI.font("head")
			draw_string(f, c + Vector2(-a.size.x * 0.4, 10), extra.get("big", ""), HORIZONTAL_ALIGNMENT_CENTER, a.size.x * 0.8, 28, UI.CREAM)

func _shot_socket(shot: String) -> String:
	return {"bumper": "bumper", "sling": "sling", "spinner": "center", "rollover": "lanes", "target": "target", "bank": "target", "ramp": "ramp", "orbit": "orbit", "scoop": "scoop"}.get(shot, "secret")

func _draw_part_icon(c: Vector2, s: float, socket: String, pid: String, tint: Color = Color(0, 0, 0, 0)) -> void:
	var main := Color("f3e9d2") if tint.a == 0 else tint
	var acc := Color("ff5a4e") if tint.a == 0 else tint.darkened(0.3)
	if pid != "" and DB.PARTS.has(pid) and DB.PARTS[pid].theme != "":
		acc = DB.THEME_COLORS[DB.PARTS[pid].theme]
	match socket:
		"bumper":
			draw_circle(c + Vector2(0, 5), s * 0.3, Color(0, 0, 0, 0.35))
			draw_circle(c, s * 0.3, acc)
			draw_circle(c, s * 0.2, main)
			draw_circle(c + Vector2(-s * 0.06, -s * 0.06), s * 0.07, Color.WHITE)
		"target":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-s * 0.3 + i * s * 0.22, -s * 0.2), Vector2(s * 0.14, s * 0.4)), acc if i != 1 else main)
		"lanes":
			for i in 3:
				var p := c + Vector2(-s * 0.25 + i * s * 0.25, 0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 0.18), p + Vector2(s * 0.08, s * 0.05), p + Vector2(-s * 0.08, s * 0.05)]), acc if i % 2 == 0 else main)
		"ramp":
			draw_arc(c + Vector2(0, s * 0.2), s * 0.32, PI, TAU, 24, main, 7)
			draw_arc(c + Vector2(0, s * 0.2), s * 0.32, PI, TAU, 24, acc, 3)
		"orbit":
			draw_arc(c, s * 0.32, 0, TAU * 0.85, 32, main, 5)
			draw_circle(c + Vector2(s * 0.32, 0).rotated(TAU * 0.85), 6, acc)
		"scoop":
			draw_circle(c, s * 0.26, UI.EDGE)
			draw_arc(c, s * 0.26, 0, TAU, 32, main, 4)
			draw_arc(c, s * 0.34, PI * 1.1, PI * 1.9, 16, acc, 4)
		"center":
			if pid == "spinner":
				draw_rect(Rect2(c - Vector2(s * 0.3, 4), Vector2(s * 0.6, 8)), main)
				draw_rect(Rect2(c - Vector2(s * 0.3, 12), Vector2(s * 0.6, 4)), acc)
			elif pid == "stock_center" or pid == "":
				draw_arc(c, s * 0.2, 0, TAU, 24, Color(1, 1, 1, 0.2), 2)
			else:
				var pts := PackedVector2Array()
				for i in 10:
					var rr := s * (0.32 if i % 2 == 0 else 0.14)
					pts.append(c + Vector2(rr, 0).rotated(i * TAU / 10.0 - PI / 2))
				draw_colored_polygon(pts, acc)
				draw_circle(c, s * 0.08, main)
		"outlane":
			draw_line(c + Vector2(-s * 0.1, -s * 0.3), c + Vector2(-s * 0.1, s * 0.3), main, 5)
			draw_line(c + Vector2(s * 0.15, -s * 0.3), c + Vector2(s * 0.15, s * 0.3), main, 5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.02 * s, -s * 0.15), c + Vector2(0.1 * s, s * 0.05), c + Vector2(-0.06 * s, s * 0.05)]), acc)
		"sling":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(-s * 0.2, s * 0.2), c + Vector2(s * 0.2, s * 0.3)]), main)
			draw_line(c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s * 0.2, s * 0.3), acc, 4)
		_:
			draw_string(UI.font("head"), c + Vector2(-10, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, main)

func _draw_ball_icon(c: Vector2, r: float, col: Color, mat: String) -> void:
	draw_circle(c + Vector2(3, 5), r, Color(0, 0, 0, 0.35))
	var a := 1.0 if not mat in ["glass", "ghost"] else 0.6
	draw_circle(c, r, Color(col.r, col.g, col.b, a))
	draw_circle(c + Vector2(r * 0.15, r * 0.2), r * 0.7, Color(col.darkened(0.25).r, col.darkened(0.25).g, col.darkened(0.25).b, a))
	draw_circle(c, r * 0.72, Color(col.r, col.g, col.b, a))
	draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.85))

func _make_custom_tooltip(_for_text: String) -> Object:
	if face_down:
		return null
	var p := UI.panel(UI.PANEL_DARK, 10, 4)
	var v := UI.vbox(4)
	v.custom_minimum_size = Vector2(260, 0)
	var t := UI.label(_title(), 20, UI.CREAM, "main", 5)
	v.add_child(t)
	var sub := ""
	match kind:
		"part":
			var pd = DB.PARTS[id]
			sub = "%s · %s" % [DB.RARITY_NAMES[pd.rarity], DB.SOCKET_NAMES[pd.socket]]
			if pd.theme != "":
				sub += " · " + DB.THEME_NAMES[pd.theme]
		"firmware": sub = "Firmware · " + DB.RARITY_NAMES[DB.FIRMWARE[id].rarity]
		"ball": sub = "Ball"
		"tool": sub = "Tool"
		"blueprint": sub = "Blueprint"
		"fault": sub = "Fault"
		"mod": sub = "Mod · Tier %d" % DB.MODS[id].tier
		"capsule": sub = "Capsule"
		"credit": sub = "Credit"
	if sub != "":
		v.add_child(UI.label(sub, 14, UI.MUTED, "main", 3))
	var d := UI.label(_desc(), 16, UI.CREAM, "main", 3)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(260, 0)
	v.add_child(d)
	var fin: String = extra.get("finish", "")
	if fin != "":
		var fl := UI.label("%s: %s" % [DB.FINISHES[fin].name, DB.FINISHES[fin].desc], 14, DB.FINISHES[fin].color, "main", 3)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(260, 0)
		v.add_child(fl)
	if kind == "part" and DB.PARTS[id].theme != "":
		var th: String = DB.PARTS[id].theme
		var tl := UI.label("Set of 3 %s: %s" % [DB.THEME_NAMES[th], DB.THEME_SET_DESC[th]], 13, DB.THEME_COLORS[th], "main", 3)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(260, 0)
		v.add_child(tl)
	if extra.has("hint"):
		v.add_child(UI.label(extra.hint, 13, UI.TICKET, "main", 3))
	p.add_child(v)
	return p
