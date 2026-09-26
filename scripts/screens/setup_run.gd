extends Control

const UI = preload("res://scripts/ui/ui.gd")

var main
var chassis := "classic"
var stake := 1
var seed_edit: LineEdit
var grid: GridContainer
var stake_box: HBoxContainer
var stake_desc: Label
var ch_desc: Label

func setup(m, _p: Dictionary) -> void:
	main = m
	main.set_bg_mood("")
	var t := UI.label("NEW RUN", 48, UI.CREAM, "head")
	t.position = Vector2(60, 30)
	add_child(t)
	var sub := UI.label("Pick a Chassis (your starting table) and an Operator Setting (difficulty).", 20, UI.MUTED)
	sub.position = Vector2(64, 96)
	add_child(sub)
	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(60, 140)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	add_child(grid)
	var sp := UI.panel(Color(0.08, 0.05, 0.14, 0.92), 16, 6)
	sp.position = Vector2(60, 640)
	sp.custom_minimum_size = Vector2(1480, 150)
	add_child(sp)
	var sv := UI.vbox(8)
	sp.add_child(sv)
	sv.add_child(UI.label("OPERATOR SETTING", 20, UI.MUTED, "head"))
	stake_box = UI.hbox(8)
	sv.add_child(stake_box)
	stake_desc = UI.label("", 18)
	stake_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stake_desc.custom_minimum_size = Vector2(1440, 0)
	sv.add_child(stake_desc)
	var bh := UI.hbox(14)
	bh.position = Vector2(60, 810)
	add_child(bh)
	var back := UI.button("BACK", UI.PANEL_LIGHT, Vector2(180, 60))
	back.pressed.connect(func(): main.goto("title"))
	bh.add_child(back)
	bh.add_child(UI.label("Seed:", 20, UI.MUTED))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "random"
	seed_edit.custom_minimum_size = Vector2(220, 50)
	seed_edit.add_theme_font_size_override("font_size", 20)
	bh.add_child(seed_edit)
	bh.add_child(UI.spacer(0, 640))
	var go := UI.button("START RUN", UI.ORANGE, Vector2(300, 64), 28)
	go.pressed.connect(_start)
	bh.add_child(go)
	_refresh()

func _refresh() -> void:
	for c in grid.get_children():
		c.queue_free()
	for ch in DB.CHASSIS_ORDER:
		var d = DB.CHASSIS[ch]
		var open := Run.is_unlocked(ch)
		var sel: bool = ch == chassis
		var col := UI.ORANGE.darkened(0.35) if sel else (Color(0.14, 0.1, 0.24, 0.95) if open else Color(0.07, 0.05, 0.1, 0.9))
		var p := UI.panel(col, 12, 6)
		p.custom_minimum_size = Vector2(360, 108)
		var v := UI.vbox(2)
		p.add_child(v)
		var h := UI.hbox(8)
		h.add_child(UI.label(d.name if open else "???", 22, UI.CREAM if open else UI.MUTED, "head"))
		h.add_child(UI.expander())
		var best := int(Run.meta.best_stake.get(ch, 0))
		if best > 0:
			h.add_child(UI.label("★%d" % best, 18, UI.TICKET, "head"))
		v.add_child(h)
		var dl := UI.label(d.desc if open else "Unlock: " + d.unlock, 15, UI.CREAM if open else UI.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(336, 0)
		v.add_child(dl)
		if open:
			var b := Button.new()
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.set_anchors_preset(Control.PRESET_FULL_RECT)
			var cc: String = ch
			b.pressed.connect(func(): chassis = cc; stake = mini(stake, Run.max_stake(cc)); Sfx.play("card"); _refresh())
			p.add_child(b)
		grid.add_child(p)
	for c in stake_box.get_children():
		c.queue_free()
	var mx := Run.max_stake(chassis)
	for i in range(1, 9):
		var b := UI.button(str(i), UI.RED.darkened(0.1 * (8 - i)) if i == stake else UI.PANEL_LIGHT, Vector2(60, 48), 22)
		b.disabled = i > mx
		var ii := i
		b.pressed.connect(func(): stake = ii; _refresh())
		stake_box.add_child(b)
	var txt := "Setting %d — %s:  " % [stake, DB.SETTINGS[stake - 1].name]
	var parts := []
	for i in stake:
		parts.append(DB.SETTINGS[i].desc)
	stake_desc.text = txt + "  ".join(parts) + ("" if mx >= 8 else "   (Win at Setting %d to unlock the next.)" % mx)

func _start() -> void:
	var sd := 0
	if seed_edit.text.strip_edges() != "":
		sd = int(seed_edit.text) if seed_edit.text.is_valid_int() else seed_edit.text.hash()
	Run.new_run(chassis, stake, sd)
	main.goto("aisle")
