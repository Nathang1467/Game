extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Card = preload("res://scripts/ui/card.gd")
const Effects = preload("res://scripts/effects.gd")

var main
var event := ""
var body: VBoxContainer
var finished := false
var swap_sock := -1

func setup(m, p: Dictionary) -> void:
	main = m
	main.set_bg_mood("shop")
	event = p.get("event", "")
	if event == "":
		event = DB.pick(Run.rng, DB.EVENTS.keys())
	var panel := UI.panel(Color(0.08, 0.05, 0.14, 0.94), 20, 10)
	panel.position = Vector2(200, 60)
	panel.custom_minimum_size = Vector2(1200, 780)
	add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(UI.margin(v, 24, 18, 24, 18))
	v.add_child(UI.label("THE BACK ROOM", 20, UI.MUTED, "head"))
	v.add_child(UI.label(DB.EVENTS[event].name, 44, UI.JACKPOT, "head"))
	var d := UI.label(DB.EVENTS[event].desc, 20)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(1100, 0)
	v.add_child(d)
	body = UI.vbox(14)
	v.add_child(body)
	v.add_child(UI.expander())
	var h := UI.hbox(12)
	h.add_child(UI.label("Tickets: %d" % Run.tickets, 22, UI.TICKET, "head"))
	h.add_child(UI.expander())
	var cont := UI.button("CONTINUE", UI.ORANGE, Vector2(260, 60), 24)
	cont.pressed.connect(_continue)
	h.add_child(cont)
	v.add_child(h)
	if p.has("rival_result"):
		_rival_result(p.rival_result)
	else:
		_start()

func _start() -> void:
	match event:
		"repair_bench": _part_picker("Choose a Part to upgrade:", _repair)
		"swap_meet": _part_picker("Choose a Part to trade:", _swap_pick)
		"operators_deal": _deals()
		"rivals_ghost": _rival_intro()
		"madame_tilt": _madame()

func _clear() -> void:
	for c in body.get_children():
		c.queue_free()

func _part_picker(title: String, cb: Callable) -> void:
	_clear()
	body.add_child(UI.label(title, 22))
	var g := GridContainer.new()
	g.columns = 7
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	var any := false
	for i in Run.sockets.size():
		var s = Run.sockets[i]
		if s.part == "" or DB.PARTS[s.part].rarity == "S":
			continue
		any = true
		var c = Card.new().setup("part", s.part, {"finish": s.finish, "wear": s.wear, "upgrade": s.upgrade}, 1)
		var idx := i
		c.pressed.connect(func(_c): cb.call(idx))
		g.add_child(c)
	if not any:
		body.add_child(UI.label("You have no Parts worth working on. Maybe next time.", 20, UI.MUTED))
		finished = true
		return
	body.add_child(g)

func _repair(i: int) -> void:
	var s = Run.sockets[i]
	s.upgrade *= 1.5
	s.wear = 0.0
	Sfx.play("buy")
	main.toast("%s upgraded to +%d%%" % [DB.PARTS[s.part].name, int(round((s.upgrade - 1.0) * 100))], UI.GREEN)
	finished = true
	_done_msg("The bench hums. Your Part feels stronger.")

func _swap_pick(i: int) -> void:
	swap_sock = i
	var s = Run.sockets[i]
	var rar: String = DB.PARTS[s.part].rarity
	var order := ["C", "U", "R"]
	var min_i := maxi(0, order.find(rar))
	_clear()
	body.add_child(UI.label("Trade %s for:" % DB.PARTS[s.part].name, 22))
	var h := UI.hbox(24)
	var used := [s.part]
	for k in 3:
		var r: String = order[mini(2, min_i + (1 if Run.rng.randf() < 0.3 else 0))]
		var pid := DB.random_part(Run.rng, s.type, r, used)
		if pid == "":
			continue
		used.append(pid)
		var c = Card.new().setup("part", pid, {}, 0)
		var pp := pid
		c.pressed.connect(func(_c):
			Run.install(swap_sock, pp, s.finish)
			Sfx.play("buy")
			main.toast("Traded for %s" % DB.PARTS[pp].name, UI.GREEN)
			finished = true
			_done_msg("A fair trade. Probably."))
		h.add_child(c)
	body.add_child(h)

func _deals() -> void:
	_clear()
	var ds := DB.DEALS.duplicate()
	ds.shuffle()
	body.add_child(UI.label("\"Psst. I can fix things for you. For a price.\" — The Operator", 20, UI.MUTED))
	for k in 2:
		var dl = ds[k]
		var p := UI.panel(Color(0.25, 0.05, 0.12, 0.9), 12, 6)
		var h := UI.hbox(16)
		p.add_child(h)
		var l := UI.label(dl.desc, 22)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(820, 0)
		h.add_child(l)
		var b := UI.button("ACCEPT", UI.RED, Vector2(180, 54), 20)
		var did: String = dl.id
		b.pressed.connect(func():
			var msg := Effects.apply_deal(did)
			Sfx.play("secret", 0.7)
			main.toast(msg, Color("ff4d6d"))
			finished = true
			_done_msg("The Operator smiles and pockets something."))
		h.add_child(b)
		body.add_child(p)

func _rival_intro() -> void:
	_clear()
	body.add_child(UI.label("A ghost player haunts a machine back here. Score %s with 1 ball in 60 seconds." % UI.fmt(round(DB.warmup_target(Run.aisle) * 0.6)), 22))
	body.add_child(UI.label("Win: choose a Rare Part.  Lose: nothing happens.", 20, UI.MUTED))
	var b := UI.button("CHALLENGE THE GHOST", UI.PURPLE, Vector2(420, 64), 22)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		Run.rival_mode = true
		main.goto("game"))
	body.add_child(b)

func _rival_result(won: bool) -> void:
	Run.rival_mode = false
	_clear()
	if not won:
		body.add_child(UI.label("The ghost's score stands. It fades away, laughing.", 24, UI.MUTED))
		finished = true
		return
	body.add_child(UI.label("You beat the ghost! Choose a Rare Part:", 24, UI.GREEN))
	var h := UI.hbox(24)
	var used := []
	for k in 3:
		var pid := DB.random_part(Run.rng, "", "R", used)
		used.append(pid)
		var c = Card.new().setup("part", pid, {}, 0)
		var pp := pid
		c.pressed.connect(func(_c):
			var idx := Run.first_socket_of(DB.PARTS[pp].socket)
			var old: String = Run.sockets[idx].part
			var refund := Run.sell_value(idx)
			Run.install(idx, pp)
			if refund > 0:
				Run.add_tickets(refund)
			main.toast("Installed %s%s" % [DB.PARTS[pp].name, (" (replaced %s)" % DB.PARTS[old].name) if old != "" and DB.PARTS[old].rarity != "S" else ""], UI.GREEN)
			Sfx.play("buy")
			finished = true
			_done_msg("The ghost's machine goes quiet."))
		h.add_child(c)
	body.add_child(h)

func _madame() -> void:
	_clear()
	body.add_child(UI.label("\"Five tickets, and I'll show you your future.\"", 22, UI.MUTED))
	var b := UI.button("PAY T5", UI.PURPLE, Vector2(220, 56), 22)
	b.disabled = not Run.can_afford(5)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		if not Run.spend(5):
			return
		_madame_cards())
	body.add_child(b)

func _madame_cards() -> void:
	_clear()
	body.add_child(UI.label("Pick a card...", 24))
	var h := UI.hbox(30)
	var ks := DB.FAULTS.keys()
	ks.shuffle()
	for k in 3:
		var fid: String = ks[k]
		var c = Card.new().setup("fault", fid, {}, 0)
		c.set_face_down(true)
		c.pressed.connect(func(_c):
			if finished:
				return
			finished = true
			c.set_face_down(false)
			c.flip_in()
			var targets := []
			if Effects.target_kind("fault", fid) == "part":
				for i in Run.sockets.size():
					var pp: String = Run.sockets[i].part
					if pp != "" and DB.PARTS[pp].rarity != "S":
						targets = [i]
						break
				if targets.is_empty():
					main.toast("The card crumbles. Nothing happens.", UI.MUTED)
					return
			if Effects.can_use("fault", fid) != "":
				main.toast("The card crumbles. Nothing happens.", UI.MUTED)
				return
			var msg := Effects.apply("fault", fid, targets)
			Sfx.play("secret", 0.8)
			main.toast(msg, Color("ff4d6d")))
		h.add_child(c)
	body.add_child(h)

func _done_msg(t: String) -> void:
	_clear()
	body.add_child(UI.label(t, 24, UI.CREAM))

func _continue() -> void:
	Run.rival_mode = false
	Run.next_aisle()
	main.goto("aisle")

func auto_step() -> void:
	_continue()
