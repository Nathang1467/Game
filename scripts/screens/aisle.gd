extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Inventory = preload("res://scripts/ui/inventory.gd")
const CUser = preload("res://scripts/ui/consumable_user.gd")
const Card = preload("res://scripts/ui/card.gd")
const Game = preload("res://scripts/screens/game.gd")

var main
var inv
var cuser
var cols_box: HBoxContainer
var feature_pick := 0

func setup(m, _p: Dictionary) -> void:
	main = m
	main.set_bg_mood("boss" if Run.stage == 2 else "")
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	# header
	var head := UI.panel(Color(0.08, 0.05, 0.14, 0.9), 14, 6)
	head.position = Vector2(20, 14)
	head.custom_minimum_size = Vector2(1040, 70)
	add_child(head)
	var hh := UI.hbox(24)
	head.add_child(hh)
	hh.add_child(UI.label("AISLE %d%s" % [Run.aisle, " / 8" if not Run.extended else "  EXTENDED"], 36, UI.CREAM, "head"))
	hh.add_child(UI.label("Setting %d: %s" % [Run.stake, DB.SETTINGS[Run.stake - 1].name], 18, UI.MUTED))
	hh.add_child(UI.expander())
	hh.add_child(UI.label("TICKETS %d" % Run.tickets, 24, UI.TICKET, "head"))
	hh.add_child(UI.label("JACKPOT %d" % Run.jackpot, 24, UI.JACKPOT, "head"))
	var info := UI.button("RUN INFO", UI.BLUE, Vector2(130, 44), 15)
	info.pressed.connect(func(): add_child(Game.run_info_panel(func(): pass)))
	hh.add_child(info)
	# three machines
	cols_box = UI.hbox(14)
	cols_box.position = Vector2(20, 100)
	add_child(cols_box)
	for stg in 3:
		cols_box.add_child(_machine(stg))
	# progress dots
	var prog := UI.hbox(8)
	prog.position = Vector2(30, 850)
	add_child(prog)
	for a in range(1, 9):
		var done := a < Run.aisle
		var cur := a == Run.aisle
		var dot := UI.label("●" if done or cur else "○", 22, UI.GREEN if done else (UI.TICKET if cur else UI.MUTED))
		prog.add_child(dot)
	prog.add_child(UI.label("  Beat the Aisle 8 finale to win the run.", 16, UI.MUTED))
	# inventory
	var rp := UI.panel(Color(0.08, 0.05, 0.14, 0.9), 16, 6)
	rp.position = Vector2(1080, 14)
	rp.custom_minimum_size = Vector2(506, 872)
	add_child(rp)
	inv = Inventory.new()
	inv.cols = 5
	rp.add_child(inv)
	cuser = CUser.new(main, inv, self, false)
	cuser.on_done = func(): _build()

func _machine(stg: int) -> Control:
	var colors := [UI.BLUE, UI.PURPLE, UI.RED]
	var current := stg == Run.stage
	var done := stg < Run.stage
	var col: Color = colors[stg]
	var p := UI.panel(col.darkened(0.55) if current else Color(0.1, 0.08, 0.16, 0.9), 16, 8)
	p.custom_minimum_size = Vector2(334, 730)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var v := UI.vbox(10)
	p.add_child(UI.margin(v, 6, 6, 6, 6))
	var ban := UI.panel(col if current else col.darkened(0.5), 10, 4)
	var bl := UI.label(["WARM-UP", "FEATURE", "BOSS"][stg], 30, UI.CREAM, "head")
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ban.add_child(bl)
	v.add_child(ban)
	var tl := UI.label("TARGET", 16, UI.MUTED, "head")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var tv := UI.label(UI.fmt(Run.target_for(stg)), 40, UI.RED.lightened(0.25), "head")
	tv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tv)
	var rw := Run.reward_for_stage(stg)
	if stg == 0 and Run.stake >= 3:
		rw = 0
	var rl := UI.label("Reward: T%d  ·  %d balls" % [rw, _balls_for(stg)], 18, UI.TICKET)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rl)
	match stg:
		0:
			var d := UI.label("A plain machine. Warm up, build your table, or skip it for a Credit.", 17)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(290, 0)
			v.add_child(d)
		1:
			if Run.feature == "" and current:
				Run.feature = Run.feature_options[feature_pick]
			for i in 2:
				var fid: String = Run.feature_options[i]
				var fd = DB.FEATURES[fid]
				var chosen := Run.feature == fid or (Run.feature == "" and i == feature_pick)
				var fp := UI.panel(UI.PURPLE.darkened(0.2) if chosen else Color(0, 0, 0, 0.3), 10, 4)
				var fv := UI.vbox(2)
				fp.add_child(fv)
				fv.add_child(UI.label(("▶ " if chosen else "   ") + fd.name, 20, UI.CREAM))
				var dl := UI.label(fd.desc, 15)
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dl.custom_minimum_size = Vector2(270, 0)
				fv.add_child(dl)
				fv.add_child(UI.label("Win: " + fd.reward_desc, 15, UI.GREEN))
				if current:
					var b := Button.new()
					b.flat = true
					b.focus_mode = Control.FOCUS_NONE
					b.set_anchors_preset(Control.PRESET_FULL_RECT)
					b.pressed.connect(func(): feature_pick = i; Run.feature = fid; Sfx.play("card"); _build())
					fp.add_child(b)
				v.add_child(fp)
		2:
			var bd = DB.BOSSES.get(Run.boss, DB.FINALES.get(Run.boss, {}))
			var bp := UI.panel(Color(0.3, 0.05, 0.1, 0.8), 10, 4)
			var bv := UI.vbox(4)
			bp.add_child(bv)
			bv.add_child(UI.label(bd.name, 26, UI.TICKET, "head"))
			bv.add_child(UI.label(bd.kind + (" BOSS" if bd.kind != "Finale" else ""), 15, UI.MUTED))
			var bdl := UI.label(bd.desc, 17)
			bdl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bdl.custom_minimum_size = Vector2(290, 0)
			bv.add_child(bdl)
			v.add_child(bp)
	v.add_child(UI.expander())
	if done:
		var dl := UI.label("CLEARED" if not Run.flags.get("skipped_%d" % stg, false) else "SKIPPED", 30, UI.GREEN, "head")
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dl)
	elif current:
		var play := UI.button("PLAY", UI.ORANGE, Vector2(300, 66), 28)
		play.pressed.connect(_play)
		v.add_child(play)
		if stg < 2:
			var cid: String = Run.skip_credits[stg]
			var sk := UI.panel(Color(0, 0, 0, 0.35), 10, 4)
			var sv := UI.vbox(4)
			sk.add_child(sv)
			var h := UI.hbox(8)
			var cc = Card.new().setup("credit", cid, {}, 3)
			h.add_child(cc)
			var cv := UI.vbox(2)
			cv.add_child(UI.label("Skip for: " + DB.CREDITS[cid].name, 17, UI.PTS))
			var cdl := UI.label(DB.CREDITS[cid].desc, 14)
			cdl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cdl.custom_minimum_size = Vector2(200, 0)
			cv.add_child(cdl)
			h.add_child(cv)
			sv.add_child(h)
			var skb := UI.button("SKIP", UI.BLUE, Vector2(280, 48), 20)
			skb.pressed.connect(_skip)
			sv.add_child(skb)
			v.add_child(sk)
	else:
		var ul := UI.label("UP NEXT", 24, UI.MUTED, "head")
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ul)
	return p

func _balls_for(stg: int) -> int:
	var save := Run.stage
	Run.stage = stg
	var n := Run.balls_per_game()
	Run.stage = save
	return n

func _play() -> void:
	if Run.stage == 1 and Run.feature == "":
		Run.feature = Run.feature_options[feature_pick]
	main.goto("game")

func _skip() -> void:
	var cid: String = Run.skip_credits[Run.stage]
	Run.flags["skipped_%d" % Run.stage] = true
	main.toast("Skipped! Credit: %s — %s" % [DB.CREDITS[cid].name, DB.CREDITS[cid].desc], UI.PTS)
	Run.skip_stage()
	if Run.stage == 1:
		Run.feature = ""
	_build()
