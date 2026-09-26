extends Node
## Automated playtest: plays whole runs with the flipper autopilot and a simple shopping bot.
## godot --headless --path . --fixed-fps 120 -- --autotest --runs=2 --chassis=classic --stake=1
## Prints one line per game plus a summary, so balance and crashes can be checked quickly.

const Effects = preload("res://scripts/effects.gd")

var main
var runs := 1
var chassis := "classic"
var stake := 1
var max_games := 40
var log_lines: Array = []
var game_start_frame := 0
var chaos := false

func begin(m, args: Dictionary) -> void:
	main = m
	runs = int(args.get("runs", 1))
	chassis = String(args.get("chassis", "classic"))
	stake = int(args.get("stake", 1))
	max_games = int(args.get("max_games", 40))
	chaos = args.has("chaos")
	Run.options.unlock_all = true
	for r in runs:
		var ch := chassis
		if chassis == "all":
			ch = DB.CHASSIS_ORDER[r % DB.CHASSIS_ORDER.size()]
		await _run_one(ch, 1000 + r * 77)
	print("AUTOTEST DONE")
	for l in log_lines:
		print(l)
	get_tree().quit()

func _run_one(ch: String, sd: int) -> void:
	Run.new_run(ch, stake, sd)
	print("=== RUN chassis=%s stake=%d seed=%d" % [ch, stake, sd])
	var games := 0
	var used_continue := false
	while games < max_games:
		# ---- aisle: play the current stage (sometimes skip a warm-up)
		if Run.stage < 2 and Run.rng.randf() < 0.15:
			Run.skip_stage()
			continue
		if Run.stage == 1 and Run.feature == "":
			Run.feature = Run.feature_options[0]
		if chaos:
			_chaos()
		var t0 := Time.get_ticks_msec()
		var stage_name := Run.stage_name()
		var boss := Run.boss if Run.stage == 2 else (Run.feature if Run.stage == 1 else "")
		main.goto("game", {"autopilot": true}, true)
		await get_tree().process_frame
		var g = main.current
		var frames := 0
		while main.current == g and frames < 120 * 60 * 12:
			await get_tree().physics_frame
			frames += 1
		games += 1
		var res: Dictionary = Run.last_result
		var line := "G%02d A%d %-8s %-18s target=%-10s score=%-12s %s  balls=%d/%d  best=%s cash=%d drains=%s sim=%.0fs  real=%.1fs" % [
			games, Run.aisle, stage_name, boss, str(int(res.get("target", 0))), str(int(res.get("score", 0))),
			"WIN " if res.get("won", false) else "LOSE", res.get("balls_used", 0), res.get("balls_total", 0),
			str(int(res.get("best_shot", 0))), res.get("cashes", 0), str(res.get("drain_log", [])), frames / 120.0, (Time.get_ticks_msec() - t0) / 1000.0]
		print(line)
		print("     shots: ", res.get("shot_counts", {}))
		log_lines.append(line)
		if frames >= 120 * 60 * 12:
			print("!! game timed out")
			return
		if main.current_name == "gameover":
			if not res.get("won", false) and Run.continues > 0 and not used_continue:
				used_continue = true
				print("   (inserting coin) ", Effects.apply_continue())
				continue
			var won: bool = main.current.won
			print("=== RUN END: %s at aisle %d, tickets %d" % ["VICTORY" if won else "defeat", Run.aisle, Run.tickets])
			log_lines.append("RUN %s %s aisle=%d" % [ch, "WIN" if won else "LOSS", Run.aisle])
			Run.end_run()
			return
		# ---- shop
		if main.current_name == "shop":
			_shop_bot()
			if Run.pending_backroom:
				Run.pending_backroom = false
				_backroom_bot()
				Run.next_aisle()
	print("=== RUN END: max games")

func _shop_bot() -> void:
	var st: Dictionary = Run.shop_state
	if st.is_empty():
		return
	var all: Array = st.get("offers", []).duplicate()
	if not st.get("mod", {}).is_empty():
		all.append(st.mod)
	all.append_array(st.get("capsules", []))
	all.shuffle()
	for o in all:
		if not Run.can_afford(o.price) or Run.rng.randf() < 0.3:
			continue
		match o.kind:
			"part":
				var idx := Run.first_socket_of(DB.PARTS[o.id].socket)
				if Run.can_install_new(idx):
					Run.spend(o.price)
					Run.add_tickets(Run.sell_value(idx))
					Run.install(idx, o.id, o.get("finish", ""))
					Run.sockets[idx].rental = o.get("rental", false)
			"firmware":
				if Run.firmware.size() < Run.firmware_slots:
					Run.spend(o.price)
					Run.firmware.append(o.id)
			"ball":
				if Run.rack.size() < 6:
					Run.spend(o.price)
					Run.rack.append({"mat": o.id, "eng": o.get("eng", "")})
			"blueprint", "tool", "fault":
				Run.spend(o.price)
				_use(o.kind, o.id)
			"mod":
				Run.spend(o.price)
				Run.mods[o.id] = true
				if o.id in ["expansion_board", "motherboard"]:
					Run.firmware_slots += 1
				if o.id in ["insert_coin", "free_play"]:
					Run.continues += 1
			"capsule":
				Run.spend(o.price)
				var ch := Effects.capsule_choices(o.id)
				if not ch.is_empty():
					var c = ch[0]
					match c.kind:
						"part":
							var idx2 := Run.first_socket_of(DB.PARTS[c.id].socket)
							if Run.can_install_new(idx2):
								Run.install(idx2, c.id, c.get("finish", ""))
						"ball":
							Run.rack.append({"mat": c.id, "eng": c.get("eng", "")})
						"firmware":
							if Run.firmware.size() < Run.firmware_slots:
								Run.firmware.append(c.id)
						_:
							_use(c.kind, c.id)
	# use held consumables too
	while not Run.consumables.is_empty():
		var c = Run.consumables.pop_back()
		_use(c.kind, c.id)
	if Run.stake >= 6 and Run.can_afford(2):
		Run.spend(2)
		for s in Run.sockets:
			s.wear = 0.0

func _use(kind: String, id: String) -> void:
	if Effects.can_use(kind, id) != "":
		return
	var tk := Effects.target_kind(kind, id)
	var targets := []
	var parts := []
	for i in Run.sockets.size():
		var p: String = Run.sockets[i].part
		if p != "" and DB.PARTS[p].rarity != "S":
			parts.append(i)
	match tk:
		"part":
			if parts.is_empty():
				return
			targets = [parts[Run.rng.randi() % parts.size()]]
		"part_pair":
			var found := false
			for a in parts:
				for b in parts:
					if a != b and Run.sockets[a].type == Run.sockets[b].type:
						targets = [a, b]
						found = true
						break
				if found:
					break
			if not found:
				return
		"ball":
			targets = [Run.rng.randi() % Run.rack.size()]
		"ball2":
			targets = [0, mini(1, Run.rack.size() - 1)]
	var msg := Effects.apply(kind, id, targets)
	print("   used %s %s: %s" % [kind, id, msg])

func _backroom_bot() -> void:
	var ev: String = DB.pick(Run.rng, DB.EVENTS.keys())
	match ev:
		"repair_bench":
			for i in Run.sockets.size():
				var p: String = Run.sockets[i].part
				if p != "" and DB.PARTS[p].rarity != "S":
					Run.sockets[i].upgrade *= 1.5
					break
		"operators_deal":
			var d = DB.pick(Run.rng, DB.DEALS)
			print("   deal: ", Effects.apply_deal(d.id))
		"madame_tilt":
			if Run.spend(5):
				var f: String = DB.pick(Run.rng, ["err07", "err22", "err55", "err99", "err77", "err00", "err31"])
				print("   madame: ", Effects.apply("fault", f, []))
	print("   backroom: ", ev)

func _chaos() -> void:
	## Randomise the table heavily to exercise every Part / ball / firmware code path.
	for i in Run.sockets.size():
		var t: String = Run.sockets[i].type
		var pool := DB.part_ids(t, "")
		for l in DB.LEGENDARIES:
			if DB.PARTS[l].socket == t:
				pool.append(l)
		if Run.rng.randf() < 0.8:
			var pid: String = DB.pick(Run.rng, pool)
			Run.install(i, pid, DB.pick(Run.rng, ["", "", "chrome", "neon", "gold", "holo", "phantom"]))
	Run.firmware = []
	var fk := DB.FIRMWARE.keys()
	fk.shuffle()
	for k in Run.firmware_slots:
		Run.firmware.append(fk[k])
	var mats := DB.BALLS.keys()
	for b in Run.rack:
		b.mat = DB.pick(Run.rng, mats)
		b.eng = DB.pick(Run.rng, ["", "", "lucky", "tally", "charm", "phoenix", "fuse", "anchor"])
	for s in DB.SHOTS:
		Run.secrets[s] = true
	if Run.rng.randf() < 0.3:
		Run.boss = DB.pick(Run.rng, DB.BOSSES.keys() + DB.FINALES.keys())
