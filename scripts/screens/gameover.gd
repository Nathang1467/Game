extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Effects = preload("res://scripts/effects.gd")

var main
var won := false
var t := 0.0
var big: Label

func setup(m, p: Dictionary) -> void:
	main = m
	won = p.get("won", false)
	main.set_bg_mood("boss" if not won else "fever")
	var unlocked := []
	if won:
		unlocked = Run.win_run()
	var panel := UI.panel(Color(0.08, 0.05, 0.14, 0.94), 20, 10)
	panel.position = Vector2(400, 90)
	panel.custom_minimum_size = Vector2(800, 700)
	add_child(panel)
	var v := UI.vbox(12)
	panel.add_child(UI.margin(v, 30, 24, 30, 24))
	big = UI.label("YOU BEAT THE ARCADE!" if won else "GAME OVER", 58 if not won else 46, UI.GREEN if won else UI.RED, "head", 12)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.pivot_offset = Vector2(370, 30)
	v.add_child(big)
	if not won:
		var sl := UI.label("%s  /  %s" % [UI.fmt(p.get("score", 0.0)), UI.fmt(p.get("target", 0.0))], 28, UI.CREAM, "head")
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
	else:
		var wl := UI.label("\"THE OPERATOR IS DISPLEASED.\"", 24, UI.DMD, "dmd")
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(wl)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	var stats := [
		["Chassis", DB.CHASSIS[Run.chassis].name],
		["Operator Setting", "%d — %s" % [Run.stake, DB.SETTINGS[Run.stake - 1].name]],
		["Reached", "Aisle %d · %s" % [Run.aisle, Run.stage_name()]],
		["Best Shot", UI.fmt(Run.stats.get("best_shot", 0.0))],
		["Best Game", UI.fmt(Run.stats.get("best_game", 0.0))],
		["Cash-ins", str(Run.stats.get("cashes", 0))],
		["Drains / Tilts", "%d / %d" % [Run.stats.get("drains", 0), Run.stats.get("tilts", 0)]],
		["Secret shots found (ever)", "%d / 5" % Run.meta.secrets.size()],
		["Seed", str(Run.seed_value) + ("  (Daily)" if Run.daily else "")],
	]
	for s in stats:
		g.add_child(UI.label(s[0], 20, UI.MUTED))
		g.add_child(UI.label(s[1], 20, UI.CREAM))
	v.add_child(UI.margin(g, 60, 10, 20, 10))
	for u in unlocked:
		var ul := UI.label("UNLOCKED: %s Chassis!" % DB.CHASSIS[u].name, 24, UI.TICKET, "head")
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ul)
	v.add_child(UI.expander())
	var h := UI.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if won:
		var ex := UI.button("EXTENDED PLAY", UI.PURPLE, Vector2(260, 60), 20)
		ex.pressed.connect(func():
			Run.extended = true
			Run.next_aisle()
			main.goto("shop"))
		h.add_child(ex)
	else:
		if Run.continues > 0 and Run.stake < 8:
			var ic := UI.button("INSERT COIN (%d)" % Run.continues, UI.TICKET.darkened(0.2), Vector2(260, 60), 20)
			ic.tooltip_text = "Replay this game with fresh balls. Costs 2 random Parts and adds a curse."
			ic.pressed.connect(func():
				main.toast(Effects.apply_continue(), UI.TICKET, 3.5)
				main.goto("game"))
			h.add_child(ic)
		var nr := UI.button("NEW RUN", UI.ORANGE, Vector2(220, 60), 22)
		nr.pressed.connect(func(): Run.end_run(); main.goto("setup"))
		h.add_child(nr)
	var menu := UI.button("MAIN MENU", UI.PANEL_LIGHT, Vector2(220, 60), 20)
	menu.pressed.connect(func(): Run.end_run(); main.goto("title"))
	h.add_child(menu)
	v.add_child(h)
	Sfx.play("win" if won else "lose")

func _process(delta: float) -> void:
	t += delta
	if big:
		big.rotation = sin(t * 2.0) * 0.03
		big.scale = Vector2.ONE * (1.0 + 0.03 * sin(t * 3.0))
