extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Table = preload("res://scripts/table/table.gd")
const Inventory = preload("res://scripts/ui/inventory.gd")
const CUser = preload("res://scripts/ui/consumable_user.gd")
const Options = preload("res://scripts/ui/options_panel.gd")

var main
var table
var holder: Control
var shake := 0.0
var shake_vec := Vector2.ZERO
var lbl_stage: Label
var lbl_boss: Label
var lbl_boss_desc: Label
var lbl_target: Label
var lbl_score: Label
var lbl_pts: Label
var lbl_mult: Label
var lbl_xm: Label
var lbl_shot_total: Label
var lbl_balls: Label
var lbl_tickets: Label
var lbl_jackpot: Label
var lbl_status: Label
var lbl_fever: Label
var tilt_bar: ProgressBar
var score_bar: ProgressBar
var dmd_label: Label
var dmd_queue: Array = []
var dmd_t := 0.0
var feed_box: VBoxContainer
var inv
var cuser
var shown_score := 0.0
var pts_box: PanelContainer
var mult_box: PanelContainer
var pop_t := 0.0
var overlay: Control
var result: Dictionary = {}
var autopilot := false
var ended_flag := false

func setup(m, p: Dictionary) -> void:
	main = m
	autopilot = p.get("autopilot", false)
	main.set_bg_mood("boss" if Run.stage == 2 else "")
	_build_left()
	_build_table()
	_build_right()
	table.start_game()
	if Run.rival_mode:
		_dmd("RIVAL'S GHOST: BEAT %s IN 60s" % UI.fmt(table.target), UI.PURPLE)

# ---------------------------------------------------------------- LEFT COLUMN
func _build_left() -> void:
	var col := UI.panel(Color(0.08, 0.05, 0.14, 0.92), 18, 8)
	col.position = Vector2(14, 12)
	col.custom_minimum_size = Vector2(368, 876)
	add_child(col)
	var v := UI.vbox(10)
	col.add_child(v)
	# stage banner
	var ban_col: Color = [UI.BLUE, UI.PURPLE, UI.RED][Run.stage]
	if Run.rival_mode:
		ban_col = UI.PURPLE
	var ban := UI.panel(ban_col.darkened(0.25), 12, 5)
	var bv := UI.vbox(2)
	ban.add_child(bv)
	var st := "AISLE %d  ·  %s" % [Run.aisle, Run.stage_name().to_upper()]
	if Run.rival_mode:
		st = "BACK ROOM  ·  RIVAL'S GHOST"
	lbl_stage = UI.label(st, 22, UI.CREAM, "head")
	bv.add_child(lbl_stage)
	var bname := ""
	var bdesc := ""
	if Run.stage == 2 and not Run.rival_mode:
		var bd = DB.BOSSES.get(Run.boss, DB.FINALES.get(Run.boss, {}))
		bname = bd.name
		bdesc = bd.desc
	elif Run.stage == 1 and Run.feature != "" and not Run.rival_mode:
		bname = DB.FEATURES[Run.feature].name
		bdesc = DB.FEATURES[Run.feature].desc + "  Reward: " + DB.FEATURES[Run.feature].reward_desc
	else:
		bname = "Warm-Up Machine" if not Run.rival_mode else "Ghost Machine"
		bdesc = "Reach the target before your balls run out." if not Run.rival_mode else "1 ball, 60 seconds. Win a Rare Part."
	lbl_boss = UI.label(bname, 20, UI.TICKET)
	bv.add_child(lbl_boss)
	lbl_boss_desc = UI.label(bdesc, 15, UI.CREAM)
	lbl_boss_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_boss_desc.custom_minimum_size = Vector2(330, 0)
	bv.add_child(lbl_boss_desc)
	v.add_child(ban)
	# target / score
	var tp := UI.panel(UI.PANEL_DARK, 12, 4)
	var tv := UI.vbox(2)
	tp.add_child(tv)
	var th := UI.hbox(8)
	th.add_child(UI.label("TARGET", 16, UI.MUTED, "head"))
	lbl_target = UI.label("0", 30, UI.RED.lightened(0.2), "head")
	th.add_child(UI.expander())
	th.add_child(lbl_target)
	tv.add_child(th)
	var sh := UI.hbox(8)
	sh.add_child(UI.label("SCORE", 16, UI.MUTED, "head"))
	sh.add_child(UI.expander())
	lbl_score = UI.label("0", 36, UI.CREAM, "head")
	sh.add_child(lbl_score)
	tv.add_child(sh)
	score_bar = ProgressBar.new()
	score_bar.show_percentage = false
	score_bar.custom_minimum_size = Vector2(0, 12)
	score_bar.add_theme_stylebox_override("background", UI.style(Color(0, 0, 0, 0.5), 6))
	score_bar.add_theme_stylebox_override("fill", UI.style(UI.GREEN, 6))
	tv.add_child(score_bar)
	v.add_child(tp)
	# shot tally
	var shot_panel := UI.panel(UI.PANEL_DARK, 12, 4)
	var sv := UI.vbox(4)
	shot_panel.add_child(sv)
	var shh := UI.hbox(6)
	shh.add_child(UI.label("CURRENT SHOT", 15, UI.MUTED, "head"))
	shh.add_child(UI.expander())
	lbl_shot_total = UI.label("", 18, UI.CREAM, "head")
	shh.add_child(lbl_shot_total)
	sv.add_child(shh)
	var boxes := UI.hbox(6)
	var pb := UI.stat_box("POINTS", UI.PTS, 138)
	pts_box = pb[0]
	lbl_pts = pb[1]
	pts_box.add_theme_stylebox_override("panel", UI.style(UI.PTS.darkened(0.25), 10, 4))
	lbl_pts.add_theme_font_size_override("font_size", 30)
	boxes.add_child(pts_box)
	var x := UI.label("X", 26, UI.MULT, "head")
	boxes.add_child(x)
	var mb := UI.stat_box("MULT", UI.MULT, 138)
	mult_box = mb[0]
	lbl_mult = mb[1]
	mult_box.add_theme_stylebox_override("panel", UI.style(UI.MULT.darkened(0.2), 10, 4))
	lbl_mult.add_theme_font_size_override("font_size", 30)
	boxes.add_child(mult_box)
	sv.add_child(boxes)
	lbl_xm = UI.label("", 18, UI.XMULT, "head")
	lbl_xm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(lbl_xm)
	v.add_child(shot_panel)
	# row: balls / tickets / jackpot
	var row := UI.hbox(6)
	var bb := UI.stat_box("BALLS", UI.PTS, 108)
	lbl_balls = bb[1]
	row.add_child(bb[0])
	var tk := UI.stat_box("TICKETS", UI.TICKET, 108)
	lbl_tickets = tk[1]
	row.add_child(tk[0])
	var jk := UI.stat_box("JACKPOT", UI.JACKPOT, 108)
	lbl_jackpot = jk[1]
	row.add_child(jk[0])
	v.add_child(row)
	# tilt + status
	var tpnl := UI.panel(UI.PANEL_DARK, 12, 4)
	var tvb := UI.vbox(4)
	tpnl.add_child(tvb)
	var tl := UI.hbox(6)
	tl.add_child(UI.label("TILT", 15, UI.MUTED, "head"))
	tilt_bar = ProgressBar.new()
	tilt_bar.show_percentage = false
	tilt_bar.max_value = 100
	tilt_bar.custom_minimum_size = Vector2(250, 16)
	tilt_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tilt_bar.add_theme_stylebox_override("background", UI.style(Color(0, 0, 0, 0.5), 6))
	tilt_bar.add_theme_stylebox_override("fill", UI.style(UI.ORANGE, 6))
	tl.add_child(tilt_bar)
	tvb.add_child(tl)
	lbl_fever = UI.label("", 18, UI.ORANGE, "head")
	tvb.add_child(lbl_fever)
	lbl_status = UI.label("", 15, UI.CREAM)
	lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_status.custom_minimum_size = Vector2(330, 0)
	tvb.add_child(lbl_status)
	v.add_child(tpnl)
	v.add_child(UI.expander())
	var bh := UI.hbox(8)
	var info := UI.button("RUN INFO", UI.BLUE, Vector2(170, 46), 16)
	info.pressed.connect(_run_info)
	var pause := UI.button("PAUSE", UI.PANEL_LIGHT, Vector2(160, 46), 16)
	pause.pressed.connect(_pause)
	bh.add_child(info)
	bh.add_child(pause)
	v.add_child(bh)
	var foot := UI.label("Setting %d: %s   ·   Seed %d" % [Run.stake, DB.SETTINGS[Run.stake - 1].name, Run.seed_value], 13, UI.MUTED)
	v.add_child(foot)

# ---------------------------------------------------------------- TABLE
func _build_table() -> void:
	holder = Control.new()
	holder.position = Vector2(412, 12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	table = Table.new()
	table.scale = Vector2(0.895, 0.895)
	table.position = Vector2(12, 12)
	table.autopilot = autopilot
	holder.add_child(table)
	table.ended.connect(_on_ended)
	table.dmd.connect(_dmd)
	table.feed.connect(_feed)
	table.cashed.connect(_on_cashed)
	table.shake_req.connect(func(a): if Run.options.shake: shake = maxf(shake, a))

# ---------------------------------------------------------------- RIGHT COLUMN
func _build_right() -> void:
	var dmd_p := PanelContainer.new()
	dmd_p.add_theme_stylebox_override("panel", UI.style(Color("120804"), 10, 6, Color("3a1a08")))
	dmd_p.position = Vector2(924, 12)
	dmd_p.custom_minimum_size = Vector2(662, 74)
	add_child(dmd_p)
	dmd_label = UI.label("INSERT BALL", 44, UI.DMD, "dmd", 0)
	dmd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dmd_p.add_child(dmd_label)
	var dots := preload("res://scripts/ui/dmd_grid.gd").new()
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmd_p.add_child(dots)
	var rp := UI.panel(Color(0.08, 0.05, 0.14, 0.88), 16, 6)
	rp.position = Vector2(924, 100)
	rp.custom_minimum_size = Vector2(662, 590)
	add_child(rp)
	inv = Inventory.new()
	inv.cols = 7
	rp.add_child(inv)
	cuser = CUser.new(main, inv, self, true)
	var fp := UI.panel(Color(0.08, 0.05, 0.14, 0.88), 16, 6)
	fp.position = Vector2(924, 702)
	fp.custom_minimum_size = Vector2(662, 186)
	add_child(fp)
	var fv := UI.vbox(2)
	fv.add_child(UI.label("TRIGGERS", 14, UI.MUTED, "head"))
	feed_box = UI.vbox(0)
	fv.add_child(feed_box)
	fp.add_child(fv)
	var keys := UI.label("A/D flip · SPACE plunge · Q/E/W nudge · SHIFT phantom · ESC pause", 13, UI.MUTED)
	keys.position = Vector2(930, 866)
	add_child(keys)

# ---------------------------------------------------------------- SIGNALS
func _dmd(text: String, col: Color) -> void:
	dmd_queue.append([text, col])
	if dmd_queue.size() > 4:
		dmd_queue.pop_front()

func _feed(text: String, col: Color) -> void:
	if feed_box.get_child_count() > 0:
		var last: Label = feed_box.get_child(feed_box.get_child_count() - 1)
		if last.get_meta("base", "") == text:
			var n: int = last.get_meta("n", 1) + 1
			last.set_meta("n", n)
			last.text = "%s  x%d" % [text, n]
			return
	var l := UI.label(text, 16, col, "main", 3)
	l.set_meta("base", text)
	l.set_meta("n", 1)
	feed_box.add_child(l)
	while feed_box.get_child_count() > 6:
		var c := feed_box.get_child(0)
		feed_box.remove_child(c)
		c.queue_free()

func _on_cashed(v: float, _p: float, _m: float, _x: float) -> void:
	pop_t = 0.35
	_dmd(UI.fmt(v), UI.TICKET if v >= table.target * 0.25 else UI.DMD)

# ---------------------------------------------------------------- PROCESS
func _process(delta: float) -> void:
	if table == null:
		return
	# shake
	shake = maxf(0.0, shake - delta * 40.0)
	holder.position = Vector2(412, 12) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	# relaxed mode
	if Run.options.relaxed and table.at_risk_any and not autopilot:
		Engine.time_scale = 0.7
	else:
		Engine.time_scale = 1.0
	shown_score = lerpf(shown_score, table.score, minf(1.0, delta * 8.0))
	if absf(shown_score - table.score) < 1.0:
		shown_score = table.score
	lbl_target.text = UI.fmt(table.target)
	lbl_score.text = UI.fmt(shown_score)
	score_bar.max_value = maxf(table.target, 1.0)
	score_bar.value = minf(shown_score, table.target)
	var fb = table.focus_ball()
	if fb != null and fb.shot != null:
		var hide: bool = table.brule("scrambled")
		lbl_pts.text = "???" if hide else UI.fmt_short(fb.shot.pts)
		lbl_mult.text = "???" if hide else UI.fmt_short(fb.shot.mult)
		lbl_xm.text = "" if fb.shot.xm <= 1.001 or hide else "x%s  MULT" % UI.fmt_short(fb.shot.xm)
		lbl_shot_total.text = "" if hide else "= " + UI.fmt(fb.shot.value())
	else:
		lbl_pts.text = "0"
		lbl_mult.text = "0"
		lbl_xm.text = ""
		lbl_shot_total.text = ""
	pop_t = maxf(0.0, pop_t - delta)
	var s := 1.0 + pop_t * 0.5
	pts_box.pivot_offset = pts_box.size * 0.5
	mult_box.pivot_offset = mult_box.size * 0.5
	pts_box.scale = Vector2(s, s)
	mult_box.scale = Vector2(s, s)
	lbl_balls.text = "%d" % table.balls_left()
	lbl_tickets.text = "%d" % Run.tickets
	lbl_jackpot.text = "%d" % Run.jackpot
	tilt_bar.value = table.tilt
	var tcol := UI.ORANGE if table.tilt < 70 else UI.RED
	(tilt_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = tcol
	var fev := ""
	if table.fever > 0:
		fev = "FEVER x%d  (+%d Mult)" % [table.fever, table.fever]
	elif table.state == "play":
		fev = "Fever in %ds" % maxi(0, int(45.0 - table.ball_time))
	lbl_fever.text = fev
	var st := []
	st.append("Bonus %dX  ·  Lamps %d/%d" % [table.bonus_x, table.lamps.size(), table.L.get("lamps", []).size()])
	if table.saver > 0.0:
		st.append("BALL SAVE %.0fs" % table.saver)
	if table.pf_on:
		st.append("PLAYFIELD x2!")
	if table.wizard_t > 0.0:
		st.append("WIZARD MODE %.0fs" % table.wizard_t)
	if table.wreck_broken:
		st.append("Wrecking Post x3")
	if table.boss == "last_call":
		st.append("LAST CALL %.0fs" % maxf(0.0, table.last_call_t))
	if table.rival:
		st.append("RIVAL TIMER %.0fs" % maxf(0.0, table.rival_t))
	if table.boss == "endless_ball":
		st.append("Ends in %.0fs" % maxf(0.0, table.endless_total))
	if table.stuck_coil:
		st.append("STUCK COIL x3")
	lbl_status.text = "\n".join(st)
	# dmd
	dmd_t -= delta
	if dmd_t <= 0.0 and not dmd_queue.is_empty():
		var e = dmd_queue.pop_front()
		dmd_label.text = e[0]
		dmd_label.add_theme_color_override("font_color", e[1])
		dmd_t = 1.1
	elif dmd_t <= -2.5:
		dmd_label.text = "%s  %s" % ["AISLE %d" % Run.aisle, UI.fmt(table.score)]
		dmd_label.add_theme_color_override("font_color", UI.DMD)
		dmd_t = 0.5
	if table.fever > 0:
		main.set_bg_mood("fever")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and overlay == null and not ended_flag:
		_pause()

# ---------------------------------------------------------------- OVERLAYS
func _make_overlay() -> Control:
	if overlay:
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.size = Vector2(1600, 900)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = overlay.size
	overlay.add_child(dim)
	add_child(overlay)
	return overlay

func _pause() -> void:
	table.paused = true
	var o := _make_overlay()
	var p := UI.panel(UI.PANEL, 18, 8)
	p.position = Vector2(620, 230)
	p.custom_minimum_size = Vector2(360, 0)
	o.add_child(p)
	var v := UI.vbox(12)
	p.add_child(UI.margin(v, 16, 16, 16, 16))
	v.add_child(UI.label("PAUSED", 36, UI.CREAM, "head"))
	var res := UI.button("RESUME", UI.ORANGE, Vector2(320, 56))
	res.pressed.connect(_unpause)
	v.add_child(res)
	var ri := UI.button("RUN INFO", UI.BLUE, Vector2(320, 50), 18)
	ri.pressed.connect(func(): _unpause(); _run_info())
	v.add_child(ri)
	var op := UI.button("OPTIONS", UI.PANEL_LIGHT, Vector2(320, 50), 18)
	op.pressed.connect(func(): add_child(Options.new().build(main)))
	v.add_child(op)
	var ab := UI.button("ABANDON RUN", UI.RED.darkened(0.2), Vector2(320, 50), 18)
	ab.pressed.connect(func():
		Engine.time_scale = 1.0
		Run.end_run()
		main.goto("title"))
	v.add_child(ab)

func _unpause() -> void:
	table.paused = false
	if overlay:
		overlay.queue_free()
		overlay = null

func _run_info() -> void:
	table.paused = true
	var o := _make_overlay()
	o.add_child(run_info_panel(func(): _unpause()))

static func run_info_panel(on_close: Callable) -> Control:
	var p := UI.panel(UI.PANEL, 18, 8)
	p.position = Vector2(200, 60)
	p.custom_minimum_size = Vector2(1200, 780)
	var h := UI.hbox(30)
	p.add_child(UI.margin(h, 16, 12, 16, 12))
	# shot levels
	var v := UI.vbox(4)
	v.add_child(UI.label("SHOT TYPES", 26, UI.CREAM, "head"))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 20)
	for hdr in ["Shot", "Lvl", "Points", "Mult"]:
		g.add_child(UI.label(hdr, 16, UI.MUTED, "head"))
	for s in DB.SHOTS:
		var sd = DB.SHOTS[s]
		var known: bool = not sd.secret or Run.secrets.has(s) or Run.meta.secrets.has(s)
		var lv := DB.shot_value(s, Run.levels.get(s, 1))
		g.add_child(UI.label(sd.name if known else "??? (secret)", 18, UI.CREAM if known else UI.MUTED))
		g.add_child(UI.label(str(Run.levels.get(s, 1)), 18, UI.TICKET))
		g.add_child(UI.label("+%d" % lv.pts, 18, UI.PTS))
		var ms := "+%d" % lv.mult
		if sd.has("xm"):
			ms += "  x%s" % UI.fmt_short(lv.xm)
		g.add_child(UI.label(ms, 18, UI.MULT))
	v.add_child(g)
	var hint := UI.label("Secret shots are unlocked by pulling off real pinball tricks.", 14, UI.MUTED)
	v.add_child(hint)
	for s in DB.SECRET_SHOTS:
		if not Run.meta.secrets.has(s):
			var l := UI.label("• " + DB.SHOTS[s].how, 14, UI.MUTED)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(520, 0)
			v.add_child(l)
	h.add_child(v)
	# right: run stats
	var r := UI.vbox(6)
	r.add_child(UI.label("THIS RUN", 26, UI.CREAM, "head"))
	var lines := [
		"Chassis: %s   ·   Setting %d (%s)" % [DB.CHASSIS[Run.chassis].name, Run.stake, DB.SETTINGS[Run.stake - 1].name],
		"Aisle %d / 8%s" % [Run.aisle, "  (Extended Play)" if Run.extended else ""],
		"Best Shot: %s" % UI.fmt(Run.stats.get("best_shot", 0.0)),
		"Games won: %d   ·   Cash-ins: %d" % [Run.stats.get("games", 0), Run.stats.get("cashes", 0)],
		"Drains: %d   ·   Tilts: %d   ·   Faults used: %d" % [Run.stats.get("drains", 0), Run.stats.get("tilts", 0), Run.stats.get("faults", 0)],
		"Continues left: %d" % Run.continues,
		"Graveyard bonus: +%d Points per Bumper" % Run.graveyard_bonus,
	]
	for ln in lines:
		r.add_child(UI.label(ln, 18))
	r.add_child(UI.spacer(8))
	r.add_child(UI.label("THEMES (3 of a kind = set bonus)", 18, UI.MUTED, "head"))
	var tc := Run.theme_counts()
	for t in DB.THEMES:
		var n: int = tc.get(t, 0)
		var l := UI.label("%s %d/3 — %s" % [DB.THEME_NAMES[t], n, DB.THEME_SET_DESC[t]], 16, DB.THEME_COLORS[t] if n >= 3 else DB.THEME_COLORS[t].darkened(0.4))
		r.add_child(l)
	r.add_child(UI.spacer(8))
	r.add_child(UI.label("MODS", 18, UI.MUTED, "head"))
	var mods := []
	for m in Run.mods:
		mods.append(DB.MODS[m].name)
	var ml := UI.label(", ".join(mods) if not mods.is_empty() else "None yet", 16)
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ml.custom_minimum_size = Vector2(520, 0)
	r.add_child(ml)
	if not Run.flags.get("curses", []).is_empty():
		r.add_child(UI.label("CURSES", 18, UI.RED, "head"))
		for c in Run.flags.curses:
			r.add_child(UI.label("%s — %s" % [DB.CURSES[c].name, DB.CURSES[c].desc], 16, UI.RED.lightened(0.3)))
	var flg := []
	if Run.flags.get("mirror", false):
		flg.append("Mirrored table")
	if Run.flags.get("gravity_leak", false):
		flg.append("Gravity Leak")
	if Run.flags.get("balls_minus", 0) > 0:
		flg.append("-%d ball (Kernel Panic)" % Run.flags.balls_minus)
	if not flg.is_empty():
		r.add_child(UI.label(", ".join(flg), 16, UI.PURPLE))
	r.add_child(UI.expander())
	var close := UI.button("CLOSE", UI.ORANGE, Vector2(200, 52))
	close.pressed.connect(func(): p.queue_free(); on_close.call())
	r.add_child(close)
	h.add_child(r)
	return p

# ---------------------------------------------------------------- GAME END
func _on_ended(res: Dictionary) -> void:
	if ended_flag:
		return
	ended_flag = true
	Engine.time_scale = 1.0
	result = res
	var used: int = res.balls_used
	Run.finish_game(res)
	Run.rotate_rack(maxi(0, used - res.destroyed_balls.size()))
	if res.get("rival", false):
		main.goto("backroom", {"event": "rivals_ghost", "rival_result": res.won})
		return
	if not res.won:
		main.goto("gameover", {"won": false, "score": res.score, "target": res.target})
		return
	_show_cashout(res)

func _show_cashout(res: Dictionary) -> void:
	var o := _make_overlay()
	var p := UI.panel(UI.PANEL, 18, 8)
	p.position = Vector2(470, 150)
	p.custom_minimum_size = Vector2(560, 0)
	o.add_child(p)
	var v := UI.vbox(10)
	p.add_child(UI.margin(v, 20, 16, 20, 16))
	var ttl := UI.label("CLEARED!", 44, UI.GREEN, "head")
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ttl)
	var sc := UI.label("%s / %s" % [UI.fmt(res.score), UI.fmt(res.target)], 22, UI.CREAM, "head")
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	var best := UI.label("Best Shot: %s" % UI.fmt(res.best_shot), 18, UI.TICKET)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(best)
	v.add_child(UI.spacer(6))
	# match lottery
	var mrow := UI.hbox(10)
	mrow.alignment = BoxContainer.ALIGNMENT_CENTER
	mrow.add_child(UI.label("MATCH", 20, UI.MUTED, "head"))
	var digit := UI.label("0", 30, UI.DMD, "dmd")
	mrow.add_child(digit)
	var mine := UI.label("vs your %d0" % res.get("match_digit", 0), 20, UI.MUTED, "main")
	mrow.add_child(mine)
	v.add_child(mrow)
	var lines_box := UI.vbox(4)
	v.add_child(lines_box)
	var total := UI.label("", 34, UI.TICKET, "head")
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var collect := UI.button("COLLECT", UI.ORANGE, Vector2(520, 64), 26)
	collect.disabled = true
	collect.pressed.connect(_collect)
	# animate lines
	var tw := create_tween()
	var spin := {"n": 0}
	for k in 12:
		tw.tween_callback(func(): digit.text = str(randi() % 10); Sfx.play("tick", 1.0 + k * 0.05)).set_delay(0.06)
	tw.tween_callback(func():
		var md: int = res.get("match_digit", 0)
		digit.text = str(md if res.match else (md + 1 + randi() % 9) % 10)
		if res.match:
			Sfx.play("jackpot")
			digit.add_theme_color_override("font_color", UI.GREEN))
	for line in Run.cashout_lines:
		var ln = line
		tw.tween_callback(func():
			var h := UI.hbox(8)
			h.add_child(UI.label(ln.label, 20, UI.CREAM))
			h.add_child(UI.expander())
			var vc := UI.GREEN if ln.value >= 0 else UI.RED
			h.add_child(UI.label(("+T%d" if ln.value >= 0 else "-T%d") % absi(ln.value), 22, vc, "head"))
			lines_box.add_child(h)
			Sfx.play("coin", 1.0 + randf() * 0.2)).set_delay(0.28)
	var interest: int = res.get("interest", 0)
	if interest > 0:
		tw.tween_callback(func():
			var h := UI.hbox(8)
			h.add_child(UI.label("Jackpot interest (collect it on the table!)", 18, UI.JACKPOT))
			h.add_child(UI.expander())
			h.add_child(UI.label("+%d" % interest, 20, UI.JACKPOT, "head"))
			lines_box.add_child(h)).set_delay(0.28)
	if res.get("ember_broke", "") != "":
		tw.tween_callback(func():
			lines_box.add_child(UI.label("Ember burned out: %s broke!" % res.ember_broke, 18, UI.ORANGE))).set_delay(0.28)
	tw.tween_callback(func():
		total.text = "+T%d" % res.get("ticket_total", 0)
		collect.disabled = false
		Sfx.play("buy")).set_delay(0.3)
	v.add_child(total)
	v.add_child(collect)
	if autopilot:
		tw.tween_callback(_collect).set_delay(0.2)

func _collect() -> void:
	if overlay == null:
		return
	overlay = null
	Run.collect_cashout()
	var nxt := Run.advance_after_win()
	match nxt:
		"victory":
			main.goto("gameover", {"won": true, "victory": true})
		"shop_then_backroom":
			Run.pending_backroom = true
			main.goto("shop")
		_:
			main.goto("shop")
