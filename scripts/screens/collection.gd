extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Card = preload("res://scripts/ui/card.gd")

var main
var tab := "part"
var grid: GridContainer
var tabs: HBoxContainer
var count_l: Label

func setup(m, _p: Dictionary) -> void:
	main = m
	var t := UI.label("COLLECTION", 44, UI.CREAM, "head")
	t.position = Vector2(50, 24)
	add_child(t)
	count_l = UI.label("", 18, UI.MUTED)
	count_l.position = Vector2(460, 44)
	add_child(count_l)
	tabs = UI.hbox(10)
	tabs.position = Vector2(50, 90)
	add_child(tabs)
	var sc := ScrollContainer.new()
	sc.position = Vector2(50, 160)
	sc.size = Vector2(1500, 650)
	add_child(sc)
	grid = GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	sc.add_child(UI.margin(grid, 10, 10, 10, 10))
	var back := UI.button("BACK", UI.PANEL_LIGHT, Vector2(200, 56))
	back.position = Vector2(50, 826)
	back.pressed.connect(func(): main.goto("title"))
	add_child(back)
	_refresh()

func _refresh() -> void:
	for c in tabs.get_children():
		c.queue_free()
	for tb in [["part", "PARTS"], ["firmware", "FIRMWARE"], ["ball", "BALLS"], ["cons", "CONSUMABLES"], ["mod", "MODS"], ["boss", "BOSSES"], ["secret", "SECRETS"]]:
		var b := UI.button(tb[1], UI.ORANGE if tab == tb[0] else UI.PANEL_LIGHT, Vector2(170, 50), 16)
		var k: String = tb[0]
		b.pressed.connect(func(): tab = k; _refresh())
		tabs.add_child(b)
	for c in grid.get_children():
		c.queue_free()
	var items := []
	match tab:
		"part":
			for id in DB.PARTS:
				if DB.PARTS[id].rarity != "S":
					items.append(["part", id])
		"firmware":
			for id in DB.FIRMWARE:
				items.append(["firmware", id])
		"ball":
			for id in DB.BALLS:
				items.append(["ball", id])
		"cons":
			for id in DB.NORMAL_SHOTS:
				items.append(["blueprint", id])
			for id in DB.TOOLS:
				items.append(["tool", id])
			for id in DB.FAULTS:
				items.append(["fault", id])
		"mod":
			for id in DB.MODS:
				items.append(["mod", id])
	var seen := 0
	if tab == "boss" or tab == "secret":
		grid.columns = 3
		var src := {}
		if tab == "boss":
			src = DB.BOSSES.duplicate()
			src.merge(DB.FINALES)
		for id in (src.keys() if tab == "boss" else DB.SECRET_SHOTS):
			var p := UI.panel(UI.PANEL, 12, 6)
			p.custom_minimum_size = Vector2(470, 110)
			var v := UI.vbox(2)
			p.add_child(v)
			if tab == "boss":
				v.add_child(UI.label(src[id].name, 22, UI.TICKET, "head"))
				v.add_child(UI.label(src[id].kind, 14, UI.MUTED))
				var dl := UI.label(src[id].desc, 16)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dl.custom_minimum_size = Vector2(440, 0)
				v.add_child(dl)
				seen += 1
			else:
				var found: bool = Run.meta.secrets.has(id) or Run.options.unlock_all
				v.add_child(UI.label(DB.SHOTS[id].name if found else "??? secret shot", 22, UI.JACKPOT if found else UI.MUTED, "head"))
				var dl := UI.label(DB.SHOTS[id].how, 16, UI.CREAM if found else UI.MUTED)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dl.custom_minimum_size = Vector2(440, 0)
				v.add_child(dl)
				if found:
					seen += 1
			grid.add_child(p)
		count_l.text = "%d / %d" % [seen, grid.get_child_count()]
		return
	grid.columns = 9
	for it in items:
		var key: String = it[0] + ":" + it[1]
		var known: bool = Run.meta.seen.has(key) or Run.options.unlock_all or it[0] in ["mod", "blueprint"]
		var c = Card.new().setup(it[0], it[1], {}, 1)
		if not known:
			c.set_face_down(true)
		else:
			seen += 1
		grid.add_child(c)
	count_l.text = "Discovered %d / %d" % [seen, items.size()]
