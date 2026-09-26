extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Inventory = preload("res://scripts/ui/inventory.gd")
const CUser = preload("res://scripts/ui/consumable_user.gd")
const Card = preload("res://scripts/ui/card.gd")
const Effects = preload("res://scripts/effects.gd")
const Game = preload("res://scripts/screens/game.gd")

var main
var inv
var cuser
var offers_box: GridContainer
var lbl_tickets: Label
var lbl_jackpot: Label
var reroll_btn: Button
var placing := {}          # part being installed: {id, finish, price, rental, offer_ref}
var banner: Control
var popup: Control
var gauntlet := false
var gauntlet_done := false
var chooser: Control

func setup(m, _p: Dictionary) -> void:
	main = m
	main.set_bg_mood("shop")
	gauntlet = Run.chassis == "gauntlet"
	if not gauntlet:
		Effects.generate_shop()
		Run.shop_state.erase("free_capsule")
		Run.shop_state.erase("free_rare")
	_build()
	Run.changed.connect(_refresh_labels)

func _build() -> void:
	# left column
	var lp := UI.panel(Color(0.08, 0.05, 0.14, 0.92), 18, 8)
	lp.position = Vector2(20, 14)
	lp.custom_minimum_size = Vector2(380, 872)
	add_child(lp)
	var v := UI.vbox(12)
	lp.add_child(v)
	var t := UI.label("PRIZE COUNTER" if not gauntlet else "GAUNTLET", 30, UI.TICKET, "head")
	v.add_child(t)
	var sub := UI.label("Spend Tickets on Parts, chips, balls and consumables." if not gauntlet else "No shops here. Choose 1 of 3 rewards.", 16, UI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(340, 0)
	v.add_child(sub)
	var tb := UI.stat_box("TICKETS", UI.TICKET, 340)
	lbl_tickets = tb[1]
	lbl_tickets.add_theme_font_size_override("font_size", 44)
	v.add_child(tb[0])
	var jb := UI.stat_box("JACKPOT (collect it on the table)", UI.JACKPOT, 340)
	lbl_jackpot = jb[1]
	v.add_child(jb[0])
	var nxt := UI.panel(UI.PANEL_DARK, 12, 4)
	var nv := UI.vbox(4)
	nxt.add_child(nv)
	nv.add_child(UI.label("NEXT UP", 16, UI.MUTED, "head"))
	var ns := ""
	if Run.pending_backroom:
		ns = "The Back Room, then Aisle %d" % (Run.aisle + 1)
	else:
		ns = "Aisle %d · %s · target %s" % [Run.aisle, Run.stage_name(), UI.fmt(Run.target_for(Run.stage))]
	var nl := UI.label(ns, 18)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(340, 0)
	nv.add_child(nl)
	if not Run.pending_backroom:
		var bd = DB.BOSSES.get(Run.boss, DB.FINALES.get(Run.boss, {}))
		var bl := UI.label("Boss: %s — %s" % [bd.name, bd.desc], 15, UI.RED.lightened(0.3))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(340, 0)
		nv.add_child(bl)
	v.add_child(nxt)
	v.add_child(UI.expander())
	if not gauntlet:
		reroll_btn = UI.button("REROLL", UI.GREEN.darkened(0.15), Vector2(340, 56), 22)
		reroll_btn.pressed.connect(_reroll)
		v.add_child(reroll_btn)
		if Run.stake >= 6:
			var rep := UI.button("REPAIR ALL  T2", UI.PANEL_LIGHT, Vector2(340, 46), 18)
			rep.pressed.connect(_repair)
			v.add_child(rep)
	var info := UI.button("RUN INFO", UI.BLUE, Vector2(340, 46), 16)
	info.pressed.connect(func(): add_child(Game.run_info_panel(func(): pass)))
	v.add_child(info)
	var go := UI.button("NEXT", UI.ORANGE, Vector2(340, 72), 30)
	go.pressed.connect(_next)
	v.add_child(go)
	# offers
	var op := UI.panel(Color(0.08, 0.05, 0.14, 0.75), 18, 8)
	op.position = Vector2(418, 14)
	op.custom_minimum_size = Vector2(646, 872)
	add_child(op)
	var ov := UI.vbox(8)
	op.add_child(ov)
	ov.add_child(UI.label("FOR SALE" if not gauntlet else "CHOOSE ONE", 22, UI.CREAM, "head"))
	offers_box = GridContainer.new()
	offers_box.columns = 4
	offers_box.add_theme_constant_override("h_separation", 14)
	offers_box.add_theme_constant_override("v_separation", 44)
	ov.add_child(UI.margin(offers_box, 6, 30, 6, 6))
	# inventory
	var rp := UI.panel(Color(0.08, 0.05, 0.14, 0.92), 18, 8)
	rp.position = Vector2(1080, 14)
	rp.custom_minimum_size = Vector2(506, 872)
	add_child(rp)
	var rv := UI.vbox(6)
	rp.add_child(rv)
	inv = Inventory.new()
	inv.cols = 5
	rv.add_child(inv)
	var hint := UI.label("Click your Parts, chips and balls to sell, repair or reorder them.", 14, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(480, 0)
	rv.add_child(hint)
	cuser = CUser.new(main, inv, self, false)
	inv.part_clicked.connect(_on_part)
	inv.firmware_clicked.connect(_on_fw)
	inv.ball_clicked.connect(_on_ball)
	_fill_offers()
	_refresh_labels()

func _refresh_labels() -> void:
	if lbl_tickets == null:
		return
	lbl_tickets.text = str(Run.tickets)
	lbl_jackpot.text = str(Run.jackpot)
	if reroll_btn:
		reroll_btn.text = "REROLL  T%d" % Effects.reroll_cost()
		reroll_btn.disabled = not Run.can_afford(Effects.reroll_cost())

func _fill_offers() -> void:
	for c in offers_box.get_children():
		c.queue_free()
	if gauntlet:
		if gauntlet_done:
			offers_box.add_child(UI.label("Reward taken. Press NEXT.", 20, UI.MUTED))
			return
		if not Run.shop_state.has("gauntlet"):
			Run.shop_state.gauntlet = Effects.gauntlet_choices()
		for o in Run.shop_state.gauntlet:
			var card = Card.new().setup(o.kind, o.id, o, 0)
			card.price = -1
			var oo = o
			card.pressed.connect(func(_c): _take_free(oo, true))
			offers_box.add_child(card)
		return
	var st: Dictionary = Run.shop_state
	var all := []
	for o in st.offers:
		all.append(o)
	if not st.mod.is_empty():
		all.append(st.mod)
	for c in st.capsules:
		all.append(c)
	for o in all:
		if o.get("sold", false):
			var e = Card.new().setup("empty", "", {}, 0)
			e.disabled = true
			offers_box.add_child(e)
			continue
		var card = Card.new().setup(o.kind, o.id, o, 0)
		card.flip_in()
		if not Run.can_afford(o.price):
			card.modulate = Color(1, 1, 1, 0.75)
		var oo = o
		card.pressed.connect(func(_c): _buy(oo))
		offers_box.add_child(card)

# ---------------------------------------------------------------- BUYING
func _buy(o: Dictionary) -> void:
	if cuser.active or not placing.is_empty():
		return
	if not Run.can_afford(o.price):
		main.toast("Not enough Tickets.", UI.RED)
		Sfx.play("tilt", 2.0, -8.0)
		return
	match o.kind:
		"part":
			_begin_place(o, true)
			return
		"firmware":
			if Run.firmware.size() >= Run.firmware_slots:
				main.toast("No free Firmware slot. Sell one first.", UI.RED)
				return
			Run.spend(o.price)
			Run.firmware.append(o.id)
			Run.mark_seen("firmware", o.id)
		"ball":
			if Run.rack.size() >= 10:
				main.toast("Your rack is full (10).", UI.RED)
				return
			Run.spend(o.price)
			Run.rack.append({"mat": o.id, "eng": o.get("eng", "")})
			Run.mark_seen("ball", o.id)
		"blueprint", "tool", "fault":
			if Run.consumables.size() >= Run.cons_slots:
				main.toast("Consumable slots full.", UI.RED)
				return
			Run.spend(o.price)
			Run.give_consumable(o.kind, o.id)
		"mod":
			Run.spend(o.price)
			Run.mods[o.id] = true
			match o.id:
				"expansion_board", "motherboard": Run.firmware_slots += 1
				"insert_coin", "free_play": Run.continues += 1
			main.toast("Mod installed: " + DB.MODS[o.id].name, UI.ORANGE)
		"capsule":
			Run.spend(o.price)
			o.sold = true
			_open_capsule(o.id)
			_fill_offers()
			return
	o.sold = true
	Sfx.play("buy")
	Run.changed.emit()
	_fill_offers()

func _begin_place(o: Dictionary, paid: bool) -> void:
	var sock: String = DB.PARTS[o.id].socket
	var hl := []
	for i in Run.sockets.size():
		if Run.sockets[i].type == sock and Run.can_install_new(i):
			hl.append(i)
	if hl.is_empty():
		main.toast("Minimalist: only 5 sockets may hold Parts. Replace one of your Parts instead.", UI.RED)
		return
	placing = {"offer": o, "paid": paid}
	inv.highlight_sockets = hl
	inv.dim_others = true
	inv.refresh()
	banner = UI.panel(UI.PURPLE.darkened(0.3), 12, 6)
	banner.position = Vector2(420, 820)
	var h := UI.hbox(12)
	h.add_child(UI.label("Install %s: choose a %s socket →" % [DB.PARTS[o.id].name, DB.SOCKET_NAMES[sock]], 19))
	var cancel := UI.button("CANCEL", UI.RED.darkened(0.2), Vector2(110, 40), 16)
	cancel.pressed.connect(_end_place)
	h.add_child(cancel)
	banner.add_child(h)
	add_child(banner)

func _end_place() -> void:
	placing = {}
	if banner:
		banner.queue_free()
		banner = null
	inv.highlight_sockets = []
	inv.dim_others = false
	inv.refresh()

func _place_into(i: int) -> void:
	var o: Dictionary = placing.offer
	if placing.paid:
		if not Run.spend(o.price):
			_end_place()
			return
	var refund := Run.sell_value(i)
	var old: String = Run.sockets[i].part
	Run.install(i, o.id, o.get("finish", ""))
	Run.sockets[i].rental = o.get("rental", false)
	if refund > 0:
		Run.add_tickets(refund)
		main.toast("Replaced %s (+T%d)" % [DB.PARTS[old].name, refund], UI.TICKET)
	o.sold = true
	Sfx.play("buy")
	_end_place()
	_fill_offers()
	Run.changed.emit()

# ---------------------------------------------------------------- CAPSULES / GAUNTLET
func _open_capsule(type: String) -> void:
	var choices := Effects.capsule_choices(type)
	_show_chooser("%s CAPSULE — PICK ONE" % type.to_upper(), choices, false)

func _show_chooser(title: String, choices: Array, _gaunt: bool) -> void:
	chooser = Control.new()
	chooser.set_anchors_preset(Control.PRESET_FULL_RECT)
	chooser.size = Vector2(1600, 900)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = chooser.size
	chooser.add_child(dim)
	var v := UI.vbox(30)
	v.position = Vector2(0, 220)
	v.custom_minimum_size = Vector2(1600, 0)
	var tl := UI.label(title, 36, UI.JACKPOT, "head")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var h := UI.hbox(30)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in choices:
		var card = Card.new().setup(c.kind, c.id, c, 0)
		card.price = -1
		card.set_face_down(true)
		var cc = c
		card.pressed.connect(func(_x):
			if card.face_down:
				return
			chooser.queue_free()
			chooser = null
			_take_free(cc, false))
		h.add_child(card)
		var tw := card.create_tween()
		tw.tween_interval(0.25 + 0.2 * h.get_child_count())
		tw.tween_callback(func(): card.set_face_down(false); card.flip_in(); Sfx.play("card", 1.2))
	v.add_child(h)
	var skip := UI.button("SKIP", UI.PANEL_LIGHT, Vector2(200, 50), 18)
	skip.pressed.connect(func(): chooser.queue_free(); chooser = null)
	var sh := UI.hbox(0)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_child(skip)
	v.add_child(sh)
	chooser.add_child(v)
	add_child(chooser)
	Sfx.play("jackpot", 1.5, -6.0)

func _take_free(o: Dictionary, from_gauntlet: bool) -> void:
	if from_gauntlet:
		gauntlet_done = true
	match o.kind:
		"part":
			_begin_place(o, false)
		"firmware":
			if Run.firmware.size() < Run.firmware_slots:
				Run.firmware.append(o.id)
				Run.mark_seen("firmware", o.id)
			else:
				main.toast("No free Firmware slot — the chip is lost.", UI.RED)
		"ball":
			Run.rack.append({"mat": o.id, "eng": o.get("eng", "")})
			Run.mark_seen("ball", o.id)
		"blueprint":
			main.toast(Effects.apply("blueprint", o.id), UI.PTS)
			Sfx.play("secret", 1.2)
		"tool", "fault":
			var tk := Effects.target_kind(o.kind, o.id)
			if tk == "none" and Effects.can_use(o.kind, o.id) == "":
				main.toast(Effects.apply(o.kind, o.id), UI.PURPLE if o.kind == "tool" else Color("ff4d6d"))
				Sfx.play("secret", 1.0)
			else:
				Run.consumables.append({"kind": o.kind, "id": o.id})
				cuser._begin(Run.consumables.size() - 1)
		"stat":
			Run.add_tickets(8)
	Run.changed.emit()
	_fill_offers()

# ---------------------------------------------------------------- INVENTORY ACTIONS
func _close_popup() -> void:
	if popup:
		popup.queue_free()
		popup = null

func _mk_popup(title: String, desc: String) -> VBoxContainer:
	_close_popup()
	popup = UI.panel(UI.PANEL_DARK, 12, 6)
	popup.position = get_local_mouse_position() + Vector2(-340, -40)
	popup.position.x = clampf(popup.position.x, 420, 1250)
	popup.position.y = clampf(popup.position.y, 20, 700)
	popup.z_index = 30
	var v := UI.vbox(8)
	popup.add_child(UI.margin(v, 8, 6, 8, 6))
	v.add_child(UI.label(title, 20))
	var d := UI.label(desc, 15, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	v.add_child(d)
	add_child(popup)
	return v

func _on_part(i: int) -> void:
	if cuser.active:
		return
	if not placing.is_empty():
		if inv.highlight_sockets.has(i):
			_place_into(i)
		return
	var s = Run.sockets[i]
	if s.part == "" or DB.PARTS[s.part].rarity == "S":
		return
	var v := _mk_popup(DB.PARTS[s.part].name, DB.PARTS[s.part].desc)
	var h := UI.hbox(8)
	var sv := Run.sell_value(i)
	var sell := UI.button("SELL T%d" % sv, UI.TICKET.darkened(0.3), Vector2(110, 44), 16)
	sell.pressed.connect(func():
		Run.remove_part(i)
		Run.add_tickets(sv)
		Sfx.play("coin")
		_close_popup())
	h.add_child(sell)
	if s.wear > 0.0:
		var rep := UI.button("REPAIR T2", UI.GREEN.darkened(0.2), Vector2(120, 44), 16)
		rep.disabled = not Run.can_afford(2)
		rep.pressed.connect(func():
			if Run.spend(2):
				s.wear = 0.0
				Run.changed.emit()
			_close_popup())
		h.add_child(rep)
	var x := UI.button("X", UI.PANEL_LIGHT, Vector2(44, 44), 16)
	x.pressed.connect(_close_popup)
	h.add_child(x)
	v.add_child(h)

func _on_fw(i: int) -> void:
	if cuser.active or not placing.is_empty():
		return
	var fid: String = Run.firmware[i]
	var v := _mk_popup(DB.FIRMWARE[fid].name, DB.FIRMWARE[fid].desc + "\nOrder matters for Mirror ROM.")
	var h := UI.hbox(8)
	var sv := maxi(1, int(DB.FIRMWARE[fid].cost / 2))
	var sell := UI.button("SELL T%d" % sv, UI.TICKET.darkened(0.3), Vector2(110, 44), 16)
	sell.pressed.connect(func():
		Run.firmware.remove_at(i)
		Run.add_tickets(sv)
		Sfx.play("coin")
		_close_popup())
	h.add_child(sell)
	var l := UI.button("◀", UI.PANEL_LIGHT, Vector2(50, 44), 18)
	l.disabled = i == 0
	l.pressed.connect(func(): _swap(Run.firmware, i, i - 1); _close_popup())
	var r := UI.button("▶", UI.PANEL_LIGHT, Vector2(50, 44), 18)
	r.disabled = i >= Run.firmware.size() - 1
	r.pressed.connect(func(): _swap(Run.firmware, i, i + 1); _close_popup())
	h.add_child(l)
	h.add_child(r)
	var x := UI.button("X", UI.PANEL_LIGHT, Vector2(44, 44), 16)
	x.pressed.connect(_close_popup)
	h.add_child(x)
	v.add_child(h)

func _on_ball(i: int) -> void:
	if cuser.active or not placing.is_empty():
		return
	var b = Run.rack[i]
	var d: String = DB.BALLS[b.mat].desc + ("\n" + DB.ENGRAVINGS[b.eng].name + ": " + DB.ENGRAVINGS[b.eng].desc if b.eng != "" else "")
	var v := _mk_popup("%s ball (slot %d)" % [DB.BALLS[b.mat].name, i + 1], d)
	var h := UI.hbox(8)
	var l := UI.button("◀", UI.PANEL_LIGHT, Vector2(50, 44), 18)
	l.disabled = i == 0
	l.pressed.connect(func(): _swap(Run.rack, i, i - 1); _close_popup())
	var r := UI.button("▶", UI.PANEL_LIGHT, Vector2(50, 44), 18)
	r.disabled = i >= Run.rack.size() - 1
	r.pressed.connect(func(): _swap(Run.rack, i, i + 1); _close_popup())
	var sell := UI.button("SELL T1", UI.TICKET.darkened(0.3), Vector2(100, 44), 16)
	sell.disabled = Run.rack.size() <= 3
	sell.tooltip_text = "You need at least 3 balls." if Run.rack.size() <= 3 else ""
	sell.pressed.connect(func():
		Run.rack.remove_at(i)
		Run.add_tickets(1)
		Sfx.play("coin")
		_close_popup())
	h.add_child(l)
	h.add_child(r)
	h.add_child(sell)
	var x := UI.button("X", UI.PANEL_LIGHT, Vector2(44, 44), 16)
	x.pressed.connect(_close_popup)
	h.add_child(x)
	v.add_child(h)

func _swap(arr: Array, a: int, b: int) -> void:
	var t = arr[a]
	arr[a] = arr[b]
	arr[b] = t
	Sfx.play("card")
	Run.changed.emit()

# ---------------------------------------------------------------- MISC
func _reroll() -> void:
	var c := Effects.reroll_cost()
	if not Run.spend(c):
		return
	Effects.reroll()
	Sfx.play("coin", 0.8)
	_fill_offers()
	_refresh_labels()

func _repair() -> void:
	if not Run.spend(2):
		main.toast("Not enough Tickets.", UI.RED)
		return
	for s in Run.sockets:
		s.wear = 0.0
	Run.changed.emit()
	main.toast("All Parts repaired.", UI.GREEN)

func _next() -> void:
	if not placing.is_empty() or cuser.active:
		return
	Run.shop_state.erase("gauntlet")
	if Run.pending_backroom:
		Run.pending_backroom = false
		main.goto("backroom")
	else:
		main.goto("aisle")
