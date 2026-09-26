extends VBoxContainer
## Shows the run's table parts, firmware, ball rack and consumables as clickable cards.

const UI = preload("res://scripts/ui/ui.gd")
const Card = preload("res://scripts/ui/card.gd")

signal part_clicked(idx: int)
signal firmware_clicked(idx: int)
signal ball_clicked(idx: int)
signal consumable_clicked(idx: int)

var card_mode := 2
var cols := 7
var highlight_sockets := []   # socket indices to highlight (selection mode)
var dim_others := false
var selected_parts := []
var selected_balls := []
var show_sections := ["parts", "firmware", "rack", "consumables"]
var title_size := 16

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	Run.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		c.queue_free()
	if show_sections.has("parts"):
		add_child(_section_title("TABLE  %s" % _theme_summary(), UI.CREAM))
		var g := GridContainer.new()
		g.columns = cols
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 8)
		for i in Run.sockets.size():
			var s = Run.sockets[i]
			var c: Control
			var ex := {"finish": s.finish, "wear": s.wear, "rental": s.rental, "upgrade": s.upgrade,
				"hint": "%s socket%s" % [DB.SOCKET_NAMES[s.type], (" (" + s.side + ")") if s.side != "" else ""]}
			if s.part == "":
				c = Card.new().setup("empty", "", ex, card_mode)
			else:
				c = Card.new().setup("part", s.part, ex, card_mode)
			c.pressed.connect(func(_c): part_clicked.emit(i))
			if dim_others and not highlight_sockets.has(i):
				c.disabled = true
			if highlight_sockets.has(i) or selected_parts.has(i):
				c.selected = true
			g.add_child(c)
		add_child(g)
	if show_sections.has("firmware"):
		add_child(_section_title("FIRMWARE  %d/%d" % [Run.firmware.size(), Run.firmware_slots], Color("7dffb0")))
		var h := UI.hbox(6)
		for i in Run.firmware.size():
			var c = Card.new().setup("firmware", Run.firmware[i], {}, card_mode)
			c.pressed.connect(func(_c): firmware_clicked.emit(i))
			if dim_others:
				c.disabled = true
			h.add_child(c)
		for i in maxi(0, Run.firmware_slots - Run.firmware.size()):
			var e = Card.new().setup("empty", "", {}, card_mode)
			e.disabled = true
			h.add_child(e)
		add_child(h)
	var row := UI.hbox(18)
	if show_sections.has("rack"):
		var rv := UI.vbox(4)
		rv.add_child(_section_title("BALL RACK  (next game uses the first %d)" % Run.balls_per_game(), UI.PTS))
		var rh := UI.hbox(4)
		for i in Run.rack.size():
			var b = Run.rack[i]
			var c = Card.new().setup("ball", b.mat, {"eng": b.eng}, 3)
			c.pressed.connect(func(_c): ball_clicked.emit(i))
			if selected_balls.has(i):
				c.selected = true
			if i < Run.balls_per_game():
				c.extra["hint"] = "Plays in the next game (slot %d)" % (i + 1)
			rh.add_child(c)
		rv.add_child(rh)
		row.add_child(rv)
	if show_sections.has("consumables"):
		var cv := UI.vbox(4)
		cv.add_child(_section_title("CONSUMABLES %d/%d" % [Run.consumables.size(), Run.cons_slots], UI.PURPLE))
		var ch := UI.hbox(6)
		for i in Run.consumables.size():
			var cs = Run.consumables[i]
			var c = Card.new().setup(cs.kind, cs.id, {"hint": "Click to use"}, 3)
			c.pressed.connect(func(_c): consumable_clicked.emit(i))
			ch.add_child(c)
		cv.add_child(ch)
		row.add_child(cv)
	add_child(row)

func _theme_summary() -> String:
	var tc := Run.theme_counts()
	var parts := []
	for t in DB.THEMES:
		if tc.get(t, 0) > 0:
			parts.append("%s %d%s" % [DB.THEME_NAMES[t], tc[t], "*" if tc[t] >= 3 else ""])
	return ("· " + "  ".join(parts)) if not parts.is_empty() else ""

func _section_title(t: String, col: Color) -> Label:
	var l := UI.label(t, title_size, col, "main", 4)
	return l
