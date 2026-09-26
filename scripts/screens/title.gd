extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Table = preload("res://scripts/table/table.gd")
const Options = preload("res://scripts/ui/options_panel.gd")

var main
var letters: Array = []
var t := 0.0
var table: Node2D

func setup(m, _p: Dictionary) -> void:
	main = m
	main.set_bg_mood("")
	# attract-mode table
	var holder := Control.new()
	holder.position = Vector2(1000, 40)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	table = Table.new()
	table.scale = Vector2(0.84, 0.84)
	holder.add_child(table)
	table.start_attract()
	var tag := UI.label("ATTRACT MODE", 16, UI.DMD, "dmd", 4)
	tag.position = Vector2(1170, 872)
	add_child(tag)
	# logo
	var logo := Control.new()
	logo.position = Vector2(110, 90)
	add_child(logo)
	var cols := [UI.MULT, UI.TICKET, UI.PTS, UI.GREEN]
	var word := "TILT"
	for i in word.length():
		var l := UI.label(word[i], 190, cols[i], "head", 18)
		l.position = Vector2([0, 150, 245, 385][i], 0)
		l.pivot_offset = Vector2(70, 110)
		logo.add_child(l)
		letters.append(l)
	var sub := UI.label("a pinball roguelite", 34, UI.CREAM, "main", 8)
	sub.position = Vector2(118, 320)
	add_child(sub)
	var v := UI.vbox(14)
	v.position = Vector2(130, 410)
	add_child(v)
	var play := UI.button("PLAY", UI.ORANGE, Vector2(340, 70), 30)
	play.pressed.connect(func(): main.goto("setup"))
	v.add_child(play)
	var daily := UI.button("DAILY MACHINE", UI.BLUE, Vector2(340, 56), 22)
	daily.pressed.connect(_daily)
	v.add_child(daily)
	var h := UI.hbox(12)
	var col := UI.button("COLLECTION", UI.PURPLE, Vector2(164, 52), 18)
	col.pressed.connect(func(): main.goto("collection"))
	var how := UI.button("HOW TO PLAY", UI.GREEN.darkened(0.2), Vector2(164, 52), 18)
	how.pressed.connect(func(): main.goto("howto"))
	h.add_child(col)
	h.add_child(how)
	v.add_child(h)
	var h2 := UI.hbox(12)
	var opt := UI.button("OPTIONS", UI.PANEL_LIGHT, Vector2(164, 52), 18)
	opt.pressed.connect(func(): add_child(Options.new().build(main)))
	var quit := UI.button("QUIT", UI.RED.darkened(0.2), Vector2(164, 52), 18)
	quit.pressed.connect(func(): get_tree().quit())
	h2.add_child(opt)
	h2.add_child(quit)
	v.add_child(h2)
	var info := UI.label("Runs: %d   Wins: %d   Chassis unlocked: %d/%d   Secrets found: %d/5" % [Run.meta.runs, Run.meta.wins, Run.meta.unlocked.size(), DB.CHASSIS.size(), Run.meta.secrets.size()], 18, UI.MUTED, "main", 4)
	info.position = Vector2(130, 820)
	add_child(info)
	var ctr := UI.label("A / D  flippers    SPACE  plunge    Q / E / W  nudge    SHIFT  phantom", 16, UI.MUTED, "main", 4)
	ctr.position = Vector2(130, 850)
	add_child(ctr)

func _daily() -> void:
	Run.new_run("classic", 1, Run.daily_seed(), true)
	main.toast("Daily Machine #%d — everyone gets the same arcade today." % Run.daily_seed(), UI.PTS)
	main.goto("aisle")

func _process(delta: float) -> void:
	t += delta
	for i in letters.size():
		var l: Label = letters[i]
		l.rotation = sin(t * 1.6 + i * 0.9) * 0.06
		l.position.y = sin(t * 2.2 + i * 1.3) * 10.0
