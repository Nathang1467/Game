extends RefCounted
## Handles "use a consumable" flows, including picking target Parts / balls on an inventory panel.

const UI = preload("res://scripts/ui/ui.gd")
const Effects = preload("res://scripts/effects.gd")

var main
var inv
var host: Control
var active := false
var mode := ""
var pending := {}
var picked: Array = []
var banner: PanelContainer
var in_game := false
var on_done: Callable

func _init(m, inventory, host_control: Control, game_mode: bool = false) -> void:
	main = m
	inv = inventory
	host = host_control
	in_game = game_mode
	inv.consumable_clicked.connect(_on_consumable)
	inv.part_clicked.connect(_on_part)
	inv.ball_clicked.connect(_on_ball)

func _on_consumable(i: int) -> void:
	if active:
		return
	if i >= Run.consumables.size():
		return
	var c = Run.consumables[i]
	var menu := _popup()
	var v := UI.vbox(8)
	menu.add_child(UI.margin(v, 8, 6, 8, 6))
	var title := UI.label(DB.item_name(c.kind, c.id), 20, UI.CREAM)
	v.add_child(title)
	var d := UI.label(DB.item_desc(c.kind, c.id), 16, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(280, 0)
	v.add_child(d)
	var h := UI.hbox(8)
	var tk := Effects.target_kind(c.kind, c.id)
	var usable := true
	if in_game and c.kind != "blueprint":
		usable = false
	var why := Effects.can_use(c.kind, c.id)
	var use := UI.button("USE", UI.GREEN.darkened(0.1), Vector2(90, 44), 18)
	use.disabled = not usable or why != ""
	if why != "":
		use.tooltip_text = why
	if not usable:
		use.tooltip_text = "Only Blueprints can be used mid-game. Use this in the shop or between games."
	use.pressed.connect(func(): menu.queue_free(); _begin(i))
	var sell := UI.button("SELL T1", UI.TICKET.darkened(0.3), Vector2(90, 44), 16)
	sell.pressed.connect(func():
		menu.queue_free()
		Run.consumables.remove_at(i)
		Run.add_tickets(1)
		Sfx.play("coin"))
	var cancel := UI.button("X", UI.PANEL_LIGHT, Vector2(44, 44), 18)
	cancel.pressed.connect(menu.queue_free)
	h.add_child(use)
	h.add_child(sell)
	h.add_child(cancel)
	v.add_child(h)

func _popup() -> PanelContainer:
	var p := UI.panel(UI.PANEL_DARK, 12, 6)
	p.position = host.get_local_mouse_position() + Vector2(-150, -170)
	p.position.x = clampf(p.position.x, 10, 1280)
	p.position.y = clampf(p.position.y, 10, 700)
	p.z_index = 20
	host.add_child(p)
	return p

func _begin(i: int) -> void:
	var c = Run.consumables[i]
	var tk := Effects.target_kind(c.kind, c.id)
	pending = {"index": i, "kind": c.kind, "id": c.id, "target": tk}
	picked = []
	if tk == "none":
		_finish()
		return
	active = true
	mode = tk
	var msg := ""
	match tk:
		"part": msg = "Choose a Part for %s" % DB.item_name(c.kind, c.id)
		"part_pair": msg = "Choose two Parts of the same Socket type"
		"ball": msg = "Choose a ball"
		"ball2": msg = "Choose up to 2 balls, then press DONE"
	_show_banner(msg, tk == "ball2")
	if tk.begins_with("part"):
		var hl := []
		for k in Run.sockets.size():
			var p: String = Run.sockets[k].part
			if p != "" and DB.PARTS[p].rarity != "S":
				hl.append(k)
		inv.highlight_sockets = hl
		inv.dim_others = true
		inv.refresh()

func _show_banner(msg: String, with_done: bool) -> void:
	banner = UI.panel(UI.PURPLE.darkened(0.3), 12, 6)
	banner.position = Vector2(520, 820)
	banner.z_index = 20
	var h := UI.hbox(12)
	h.add_child(UI.label(msg, 20))
	if with_done:
		var done := UI.button("DONE", UI.GREEN, Vector2(90, 40), 16)
		done.pressed.connect(func(): if not picked.is_empty(): _finish())
		h.add_child(done)
	var cancel := UI.button("CANCEL", UI.RED.darkened(0.2), Vector2(110, 40), 16)
	cancel.pressed.connect(_cancel)
	h.add_child(cancel)
	banner.add_child(h)
	host.add_child(banner)

func _on_part(k: int) -> void:
	if not active or not mode.begins_with("part"):
		return
	if not inv.highlight_sockets.has(k):
		return
	if mode == "part":
		picked = [k]
		_finish()
	elif mode == "part_pair":
		if picked.is_empty():
			picked.append(k)
			var t: String = Run.sockets[k].type
			inv.highlight_sockets = inv.highlight_sockets.filter(func(x): return Run.sockets[x].type == t and x != k)
			inv.selected_parts = [k]
			inv.refresh()
			if inv.highlight_sockets.is_empty():
				main.toast("No other Part of that type to swap with.", UI.RED)
				_cancel()
		else:
			picked.append(k)
			_finish()

func _on_ball(k: int) -> void:
	if not active or not mode.begins_with("ball"):
		return
	if mode == "ball":
		picked = [k]
		_finish()
	elif mode == "ball2":
		if not picked.has(k):
			picked.append(k)
		inv.selected_balls = picked.duplicate()
		inv.refresh()
		if picked.size() >= 2:
			_finish()

func _finish() -> void:
	var msg := Effects.apply(pending.kind, pending.id, picked)
	Run.consumables.remove_at(pending.index)
	Sfx.play("secret" if pending.kind == "fault" else "buy")
	main.toast(msg, UI.kind_color(pending.kind).lightened(0.3) if pending.kind != "fault" else Color("ff4d6d"))
	_end()
	if on_done.is_valid():
		on_done.call()

func _cancel() -> void:
	_end()

func _end() -> void:
	active = false
	mode = ""
	picked = []
	if banner:
		banner.queue_free()
		banner = null
	inv.highlight_sockets = []
	inv.selected_parts = []
	inv.selected_balls = []
	inv.dim_others = false
	Run.changed.emit()
