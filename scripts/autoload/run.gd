extends Node
## Holds the state of the current run plus persistent meta progression.

signal changed

const SAVE_PATH := "user://tilt_save.cfg"
const STAGE_NAMES := ["Warm-Up", "Feature", "Boss"]

# ------------------------------------------------------------------ run state
var active := false
var rng := RandomNumberGenerator.new()
var seed_value := 0
var daily := false
var chassis := "classic"
var stake := 1
var aisle := 1
var stage := 0
var extended := false
var boss := ""
var feature_options: Array = []
var feature := ""
var skip_credits: Array = []      # credit offered for skipping warm-up / feature this aisle
var pending_credits: Array = []   # credits that apply to the next game
var tickets := 4
var jackpot := 0
var sockets: Array = []           # [{type, part, finish, wear, upgrade, rental, side}]
var firmware: Array = []          # [id]
var firmware_slots := 3
var rack: Array = []              # [{mat, eng}]
var consumables: Array = []       # [{kind, id}]
var cons_slots := 2
var levels := {}
var secrets := {}
var mods := {}
var continues := 0
var flags := {}
var graveyard_bonus := 0
var memory_bonus := 0.0
var stats := {}
var last_drained := {}
var shot_counts_aisle := {}
var lamps_memory := {}
var rack_rotation_used := 0
var coupon_rare := false
var coupon_book := false
var shop_state := {}
var last_result := {}
var cashout_lines: Array = []
var rival_mode := false
var pending_backroom := false

# ------------------------------------------------------------------ meta
var meta := {
	"unlocked": ["classic"],
	"best_stake": {},
	"wins": 0,
	"runs": 0,
	"secrets": {},
	"seen": {},
	"high_scores": {},
	"flags": {},
	"chassis_won": {},
	"faults_used": 0,
	"daily_best": {},
}
var options := {"volume": 0.7, "crt": true, "shake": true, "relaxed": false, "unlock_all": false, "fullscreen": false}

func _ready() -> void:
	load_meta()
	_apply_options()

# ================================================================== META SAVE
func load_meta() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in meta.keys():
		meta[k] = cf.get_value("meta", k, meta[k])
	for k in options.keys():
		options[k] = cf.get_value("options", k, options[k])

func save_meta() -> void:
	var cf := ConfigFile.new()
	for k in meta.keys():
		cf.set_value("meta", k, meta[k])
	for k in options.keys():
		cf.set_value("options", k, options[k])
	cf.save(SAVE_PATH)

func _apply_options() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(options.volume, 0.0001)))
	if options.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_option(k: String, v) -> void:
	options[k] = v
	_apply_options()
	if k == "fullscreen" and not v:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_meta()

func is_unlocked(ch: String) -> bool:
	return options.unlock_all or meta.unlocked.has(ch)

func max_stake(ch: String) -> int:
	if options.unlock_all:
		return 8
	return clampi(int(meta.best_stake.get(ch, 0)) + 1, 1, 8)

func mark_seen(kind: String, id: String) -> void:
	var key := kind + ":" + id
	if not meta.seen.has(key):
		meta.seen[key] = true

func unlock(ch: String) -> String:
	if meta.unlocked.has(ch):
		return ""
	meta.unlocked.append(ch)
	save_meta()
	return ch

func meta_flag(f: String) -> void:
	meta.flags[f] = true
	check_unlocks()

func check_unlocks() -> Array:
	var got := []
	var conds := {
		"widebody": meta.wins >= 1,
		"tri_flipper": meta.secrets.has("post_pass"),
		"bagatelle": meta.flags.has("bagatelle_win"),
		"twin_table": meta.flags.has("multiball3"),
		"crooked": meta.flags.has("beat_slant"),
		"pawn_shop": meta.faults_used >= 10,
		"ghost_cabinet": meta.flags.has("beat_blackout"),
		"minimalist": meta.flags.has("minimal_win"),
		"heirloom": meta.flags.has("stake4_win"),
		"gauntlet": meta.wins >= 5,
		"blank_board": meta.chassis_won.size() >= 4,
	}
	for ch in conds:
		if conds[ch] and not meta.unlocked.has(ch):
			meta.unlocked.append(ch)
			got.append(ch)
	if not got.is_empty():
		save_meta()
	return got

# ================================================================== NEW RUN
func new_run(ch: String, stk: int, sd: int = 0, is_daily: bool = false) -> void:
	active = true
	chassis = ch
	stake = stk
	daily = is_daily
	seed_value = sd if sd != 0 else randi()
	rng.seed = seed_value
	aisle = 1
	stage = 0
	extended = false
	tickets = 4
	jackpot = 0
	firmware = []
	firmware_slots = 3
	consumables = []
	cons_slots = 2
	mods = {}
	secrets = {}
	flags = {"curses": [], "outlane_widen": 0, "tilt_mult": 1.0, "balls_minus": 0, "ball_minus_aisle": 0}
	graveyard_bonus = 0
	memory_bonus = 0.0
	pending_credits = []
	shot_counts_aisle = {}
	lamps_memory = {}
	coupon_rare = false
	coupon_book = false
	last_drained = {}
	shop_state = {}
	stats = {"games": 0, "best_shot": 0.0, "total": 0.0, "cashes": 0, "drains": 0, "tilts": 0, "faults": 0, "best_game": 0.0}
	levels = {}
	for s in DB.SHOTS:
		levels[s] = 1
	continues = 1 if stake == 1 else 0
	# sockets
	sockets = []
	var bumper_count := 5 if ch == "widebody" else 3
	for i in bumper_count:
		sockets.append(_sock("bumper"))
	sockets.append(_sock("target"))
	sockets.append(_sock("lanes"))
	var r1 := _sock("ramp"); r1.side = "left"; sockets.append(r1)
	var r2 := _sock("ramp"); r2.side = "right"; sockets.append(r2)
	sockets.append(_sock("orbit"))
	sockets.append(_sock("scoop"))
	sockets.append(_sock("center"))
	var o1 := _sock("outlane"); o1.side = "left"; sockets.append(o1)
	var o2 := _sock("outlane"); o2.side = "right"; sockets.append(o2)
	if ch == "blank_board":
		for s in sockets:
			s.part = ""
		tickets += 10
	# rack
	rack = [{"mat": "steel", "eng": ""}, {"mat": "steel", "eng": ""}, {"mat": "steel", "eng": ""}, {"mat": "steel", "eng": ""}]
	if ch == "widebody":
		firmware_slots = 4
	if ch == "heirloom":
		var pid := DB.random_part(rng, "", "R")
		var idx := first_socket_of(DB.PARTS[pid].socket)
		install(idx, pid, DB.pick(rng, ["chrome", "neon", "holo", "gold"]))
		rack[0] = {"mat": "glass", "eng": ""}
	if ch == "pawn_shop":
		consumables.append({"kind": "fault", "id": DB.pick(rng, DB.FAULTS.keys())})
		consumables.append({"kind": "fault", "id": DB.pick(rng, ["err22", "err55", "err31", "err99"])})
	meta.runs += 1
	save_meta()
	setup_aisle()

func _sock(t: String) -> Dictionary:
	return {"type": t, "part": DB.STOCK_PART[t], "finish": "", "wear": 0.0, "upgrade": 1.0, "rental": false, "side": "", "phantom_forced": false}

func first_socket_of(t: String) -> int:
	for i in sockets.size():
		if sockets[i].type == t and DB.PARTS.get(sockets[i].part, {"rarity": "S"}).rarity == "S":
			return i
	for i in sockets.size():
		if sockets[i].type == t:
			return i
	return 0

func install(idx: int, pid: String, finish: String = "") -> void:
	var s = sockets[idx]
	s.part = pid
	s.finish = finish
	s.wear = 0.0
	s.upgrade = 1.0
	s.rental = false
	if chassis == "ghost_cabinet" and pid != "" and DB.PARTS[pid].rarity != "S":
		s.finish = "phantom"
	mark_seen("part", pid)
	changed.emit()

func remove_part(idx: int) -> void:
	var s = sockets[idx]
	s.part = "" if chassis == "blank_board" else DB.STOCK_PART[s.type]
	s.finish = ""
	s.wear = 0.0
	s.upgrade = 1.0
	s.rental = false
	changed.emit()

func non_stock_count() -> int:
	var n := 0
	for s in sockets:
		if s.part != "" and DB.PARTS[s.part].rarity != "S":
			n += 1
	return n

func can_install_new(idx: int) -> bool:
	if chassis != "minimalist":
		return true
	var cur = sockets[idx].part
	var replacing_nonstock: bool = cur != "" and DB.PARTS[cur].rarity != "S"
	return replacing_nonstock or non_stock_count() < 5

func break_part(idx: int) -> bool:
	## Returns true if Warranty saved it.
	if flags.get("warranty", false):
		flags.warranty = false
		return true
	remove_part(idx)
	return false

# ================================================================== AISLES
func setup_aisle() -> void:
	stage = 0
	if aisle == 8 or (extended and aisle % 8 == 0):
		boss = DB.pick(rng, DB.FINALES.keys())
	else:
		var pool := DB.BOSSES.keys()
		if aisle <= 1:
			pool = pool.filter(func(b): return not ["jam", "pit_boss", "shatter", "blackout"].has(b))
		boss = DB.pick(rng, pool)
	var fk := DB.FEATURES.keys()
	fk.shuffle()
	var a = fk[rng.randi() % fk.size()]
	var b = a
	while b == a:
		b = fk[rng.randi() % fk.size()]
	feature_options = [a, b]
	feature = ""
	skip_credits = [DB.pick(rng, DB.CREDITS.keys()), DB.pick(rng, DB.CREDITS.keys())]
	shot_counts_aisle = {}
	lamps_memory = {}
	flags.phoenix_used = {}
	flags.erase("skipped_0")
	flags.erase("skipped_1")
	changed.emit()

func is_finale() -> bool:
	return DB.FINALES.has(boss) and stage == 2

func boss_active() -> String:
	return boss if stage == 2 else ""

func stage_name() -> String:
	return STAGE_NAMES[stage]

func target_for(stg: int) -> float:
	var base := DB.warmup_target(aisle)
	var m: float = [1.0, 1.5, 2.0][stg]
	if stg == 2 and DB.FINALES.has(boss):
		m = 2.5
		if boss == "endless_ball":
			m = 3.0
	if stake >= 5:
		m *= 1.0 + 0.05 * (stake - 4)
	return round(base * m)

func current_target() -> float:
	if rival_mode:
		return round(DB.warmup_target(aisle) * 0.6)
	return target_for(stage)

func balls_per_game() -> int:
	var n := 3
	if chassis == "widebody":
		n -= 1
	if stake >= 8:
		n -= 1
	n -= int(flags.get("balls_minus", 0))
	n -= int(flags.get("ball_minus_aisle", 0))
	if pending_credits.has("extra_ball"):
		n += 1
	if stage == 1 and feature == "two_balls":
		n = mini(n, 2)
	if is_finale() and (boss == "endless_ball" or boss == "last_call"):
		n = 1
	if rival_mode:
		n = 1
	return maxi(n, 1)

func reward_for_stage(stg: int) -> int:
	return [3, 4, 5][stg]

func skip_stage() -> void:
	var credit = skip_credits[stage]
	apply_credit_immediate(credit)
	stage += 1
	changed.emit()

func apply_credit_immediate(credit: String) -> void:
	match credit:
		"capsule_credit":
			shop_state.free_capsule = "fault"
		"blueprint_rush":
			var ks := DB.NORMAL_SHOTS.duplicate()
			ks.shuffle()
			levels[ks[0]] += 1
			levels[ks[1]] += 1
		"rare_coupon":
			coupon_rare = true
		"jackpot_boost":
			jackpot += 10
		"boss_swap":
			var pool := DB.BOSSES.keys() if not DB.FINALES.has(boss) else DB.FINALES.keys()
			var nb = boss
			while nb == boss:
				nb = DB.pick(rng, pool)
			boss = nb
		"coupon_book":
			coupon_book = true
		_:
			pending_credits.append(credit)

# ================================================================== FIRMWARE / QUERIES
func effective_firmware() -> Array:
	var out := []
	for i in firmware.size():
		var f = firmware[i]
		if f == "mirror_rom":
			if i + 1 < firmware.size() and firmware[i + 1] != "mirror_rom":
				out.append(firmware[i + 1])
		else:
			out.append(f)
	return out

func fw(id: String) -> int:
	var n := 0
	for f in effective_firmware():
		if f == id:
			n += 1
	return n

func has_mod(id: String) -> bool:
	return mods.has(id)

func theme_counts() -> Dictionary:
	var c := {}
	for s in sockets:
		if s.part == "":
			continue
		var t = DB.PARTS[s.part].theme
		if t != "":
			c[t] = c.get(t, 0) + 1
	return c

func theme_set(t: String) -> bool:
	return theme_counts().get(t, 0) >= 3

func min_tickets() -> int:
	var m := 0
	if has_mod("credit_line"):
		m = -10
	if fw("debt_engine") > 0:
		m = -20
	return m

func can_afford(cost: int) -> bool:
	return tickets - cost >= min_tickets()

func price(base: int) -> int:
	var p := float(base)
	if has_mod("liquidation"):
		p *= 0.5
	elif has_mod("clearance_rack"):
		p *= 0.75
	var out := int(round(p))
	if coupon_book:
		out -= 1
	return maxi(out, 1)

func sell_value(idx: int) -> int:
	var s = sockets[idx]
	if s.part == "":
		return 0
	var p = DB.PARTS[s.part]
	if p.rarity == "S":
		return 0
	return maxi(1, int(p.cost / 2))

func add_tickets(n: int) -> void:
	tickets = maxi(tickets + n, min_tickets())
	changed.emit()

func spend(n: int) -> bool:
	if not can_afford(n):
		return false
	tickets -= n
	changed.emit()
	return true

func tilt_factor() -> float:
	var f: float = flags.get("tilt_mult", 1.0)
	if stake >= 5:
		f *= 1.3
	if has_mod("iron_legs"):
		f *= 0.6
	elif has_mod("tilt_dampener"):
		f *= 0.8
	if fw("seismograph") > 0:
		f *= 1.5
	if flags.curses.has("rusty_legs"):
		f *= 1.2
	if chassis == "bagatelle":
		f /= 3.0
	return f

func outlane_widen() -> float:
	var w: float = flags.get("outlane_widen", 0)
	if stake >= 2:
		w += 4
	if chassis == "tri_flipper":
		w += 4
	if flags.curses.has("loose_posts"):
		w += 3
	return clampf(w, 0, 9)

func flipper_scale() -> float:
	var f := 1.0
	if has_mod("flipper_extension"):
		f = 1.2
	elif has_mod("flipper_rubber"):
		f = 1.1
	return f

func ball_saver_time() -> float:
	var t := 0.0 if stake >= 4 else 4.0
	if has_mod("extended_save"):
		t += 10.0
	elif has_mod("ball_saver"):
		t += 5.0
	return t

func rack_value(b: Dictionary) -> int:
	var v: int = DB.BALLS[b.mat].cost
	if b.eng != "":
		v += 3
	return v

func draw_game_balls(n: int) -> Array:
	## Returns rack indices for this game, in order.
	var out := []
	if boss_active() == "pit_boss":
		var idx := range(rack.size())
		idx.sort_custom(func(a, b): return rack_value(rack[a]) < rack_value(rack[b]))
		for i in mini(n, idx.size()):
			out.append(idx[i])
		return out
	for i in mini(n, rack.size()):
		out.append(i)
	while out.size() < n:
		out.append(out[out.size() % maxi(rack.size(), 1)] if not rack.is_empty() else 0)
	return out

func rotate_rack(used_count: int) -> void:
	## Balls that were used go to the back of the queue.
	used_count = mini(used_count, rack.size())
	for i in used_count:
		rack.append(rack.pop_front())

# ================================================================== GAME END
func finish_game(result: Dictionary) -> void:
	## result: {won, score, balls_used, balls_total, burned: [socket idx], shot_counts, destroyed_balls: [rack idx], match}
	last_result = result
	stats.games += 1
	stats.total += result.score
	stats.best_game = maxf(stats.best_game, result.score)
	if not stats.has("types"):
		stats.types = {}
	for k in result.get("shot_counts", {}):
		shot_counts_aisle[k] = shot_counts_aisle.get(k, 0) + result.shot_counts[k]
		stats.types[k] = true
	# remove shattered balls (highest index first)
	var destroyed: Array = result.get("destroyed_balls", [])
	destroyed.sort()
	destroyed.reverse()
	for ri in destroyed:
		if ri < rack.size() and rack.size() > 1:
			rack.remove_at(ri)
	if not result.won:
		return
	var lines := []
	var reward := reward_for_stage(stage)
	if rival_mode:
		reward = 0
	if stage == 0 and stake >= 3:
		reward = 0
	lines.append({"label": "%s cleared" % (stage_name() if not rival_mode else "Rival"), "value": reward})
	var unused: int = result.balls_total - result.balls_used
	if unused > 0:
		lines.append({"label": "Unused balls x%d" % unused, "value": unused * 2})
	if result.get("match", false):
		lines.append({"label": "MATCH!", "value": 5})
	if stage == 1 and feature in ["tickets8", "no_bumpers"]:
		pass
	var feat_reward := ""
	if stage == 1 and feature != "":
		feat_reward = DB.FEATURES[feature].reward
		if feat_reward.begins_with("tickets"):
			lines.append({"label": DB.FEATURES[feature].name + " reward", "value": int(feat_reward.substr(7))})
	var rent := 0
	for s in sockets:
		if s.rental:
			rent += 1
	if rent > 0:
		lines.append({"label": "Rentals", "value": -rent})
	var total := 0
	for l in lines:
		total += l.value
	if pending_credits.has("double_tickets") and total > 0:
		lines.append({"label": "Double Tickets", "value": total})
		total *= 2
	cashout_lines = lines
	# jackpot interest grows (collected later on the table)
	var interest := mini(int(maxi(tickets, 0) / 5), 5)
	if fw("compound_interest") > 0:
		interest *= 2
	if interest > 0:
		jackpot += interest
	result["interest"] = interest
	result["ticket_total"] = total
	result["feature_reward"] = feat_reward
	# wear
	if stake >= 6:
		for s in sockets:
			if s.part != "" and DB.PARTS[s.part].rarity != "S":
				s.wear = minf(s.wear + 0.1, 0.5)
	# ember breaks one burning part
	var burned: Array = result.get("burned", [])
	result["ember_broke"] = ""
	if not burned.is_empty():
		var cands := burned.filter(func(i): return sockets[i].part != "" and DB.PARTS[sockets[i].part].rarity != "S")
		if not cands.is_empty():
			var bi = cands[rng.randi() % cands.size()]
			var nm = DB.PARTS[sockets[bi].part].name
			if not break_part(bi):
				result["ember_broke"] = nm
	# clear one-game credits
	pending_credits = []
	coupon_book = false
	flags.erase("stuck_coil")

func collect_cashout() -> void:
	add_tickets(int(last_result.get("ticket_total", 0)))
	var fr: String = last_result.get("feature_reward", "")
	match fr:
		"blueprint":
			give_consumable("blueprint", DB.pick(rng, DB.NORMAL_SHOTS))
		"tool":
			give_consumable("tool", DB.pick(rng, DB.TOOLS.keys()))
		"fault":
			give_consumable("fault", DB.pick(rng, DB.FAULTS.keys()))
		"part_capsule":
			shop_state.free_capsule = "part"
		"rare_part":
			coupon_rare = true
			shop_state.free_rare = true

func give_consumable(kind: String, id: String) -> bool:
	if consumables.size() >= cons_slots:
		return false
	consumables.append({"kind": kind, "id": id})
	mark_seen(kind, id)
	changed.emit()
	return true

func record_boss_beaten() -> void:
	match boss:
		"slant": meta_flag("beat_slant")
		"blackout": meta_flag("beat_blackout")

func advance_after_win() -> String:
	## Returns the next screen: "shop", "backroom", "victory".
	rival_mode = false
	if stage == 2:
		record_boss_beaten()
		if (aisle == 8 and not extended):
			return "victory"
		return "shop_then_backroom"
	stage += 1
	return "shop"

func next_aisle() -> void:
	aisle += 1
	if has_mod("loan_forgiveness") and tickets < 0:
		tickets = 0
	flags.ball_minus_aisle = flags.get("ball_minus_next", 0)
	flags.ball_minus_next = 0
	setup_aisle()

func win_run() -> Array:
	meta.wins += 1
	meta.best_stake[chassis] = maxi(int(meta.best_stake.get(chassis, 0)), stake)
	meta.chassis_won[chassis] = true
	if stake >= 4:
		meta.flags.stake4_win = true
	if non_stock_count() <= 3:
		meta.flags.minimal_win = true
	var got := check_unlocks()
	save_meta()
	return got

func end_run() -> void:
	active = false
	var hs: Dictionary = meta.high_scores
	var key := chassis
	hs[key] = maxf(float(hs.get(key, 0.0)), stats.get("best_game", 0.0))
	if daily:
		var d := Time.get_date_string_from_system()
		meta.daily_best[d] = maxi(int(meta.daily_best.get(d, 0)), aisle)
	save_meta()

func discover_secret(s: String) -> bool:
	var first: bool = not meta.secrets.has(s)
	secrets[s] = true
	meta.secrets[s] = true
	if first:
		check_unlocks()
		save_meta()
	return first

func daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
