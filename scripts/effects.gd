extends RefCounted
## Applies consumables, deals and curses to the run, and generates shops.

static func target_kind(kind: String, id: String) -> String:
	match kind:
		"tool": return DB.TOOLS[id].target
		"fault": return DB.FAULTS[id].target
	return "none"

static func can_use(kind: String, id: String) -> String:
	## Returns "" if usable, else a reason.
	match id:
		"operators_key":
			if Run.firmware.size() >= Run.firmware_slots:
				return "No free Firmware slot"
		"duplicator":
			if Run.rack.size() >= 10:
				return "Rack is full"
		"err40":
			if Run.rack.size() <= 3:
				return "Need more than 3 balls"
		"err64":
			if Run.firmware.is_empty():
				return "No Firmware to copy"
	return ""

static func apply(kind: String, id: String, targets: Array = []) -> String:
	var rng := Run.rng
	Run.mark_seen(kind, id)
	match kind:
		"blueprint":
			if id == "master_plan":
				var n := 0
				for t in Run.stats.get("types", {}):
					Run.levels[t] += 1
					n += 1
				if n == 0:
					for t in DB.NORMAL_SHOTS:
						Run.levels[t] += 1
				return "Master Plan: every Shot type you've made levels up!"
			Run.levels[id] += 1
			return "%s is now level %d" % [DB.SHOTS[id].name, Run.levels[id]]
		"tool":
			return _tool(id, targets, rng)
		"fault":
			Run.stats.faults = Run.stats.get("faults", 0) + 1
			Run.meta.faults_used += 1
			Run.check_unlocks()
			return _fault(id, targets, rng)
	return ""

static func _tool(id: String, t: Array, rng: RandomNumberGenerator) -> String:
	match id:
		"polish", "neon_tube", "gold_leaf":
			var fin: String = {"polish": "chrome", "neon_tube": "neon", "gold_leaf": "gold"}[id]
			Run.sockets[t[0]].finish = fin
			return "%s is now %s" % [DB.PARTS[Run.sockets[t[0]].part].name, DB.FINISHES[fin].name]
		"wrench":
			Run.sockets[t[0]].upgrade *= 1.25
			return "%s upgraded +25%%" % DB.PARTS[Run.sockets[t[0]].part].name
		"relocate":
			var a = Run.sockets[t[0]]
			var b = Run.sockets[t[1]]
			for k in ["part", "finish", "wear", "upgrade", "rental"]:
				var tmp = a[k]
				a[k] = b[k]
				b[k] = tmp
			return "Parts swapped"
		"furnace":
			for bi in t:
				Run.rack[bi].mat = "ember"
			return "Balls are now Ember"
		"kiln":
			Run.rack[t[0]].mat = "glass"
			return "Ball is now Glass"
		"engraver":
			var e: String = DB.pick(rng, DB.ENGRAVINGS.keys())
			Run.rack[t[0]].eng = e
			return "Engraved: %s" % DB.ENGRAVINGS[e].name
		"scrapper":
			var v := Run.sell_value(t[0]) * 2
			var nm: String = DB.PARTS[Run.sockets[t[0]].part].name
			Run.remove_part(t[0])
			Run.add_tickets(v)
			return "Scrapped %s for %d Tickets" % [nm, v]
		"tuning_fork":
			var best := ""
			var bn := -1
			for k in Run.shot_counts_aisle:
				if Run.shot_counts_aisle[k] > bn and not DB.SHOTS[k].secret:
					bn = Run.shot_counts_aisle[k]
					best = k
			if best == "":
				best = DB.pick(rng, DB.NORMAL_SHOTS)
			Run.levels[best] += 1
			return "%s levelled up" % DB.SHOTS[best].name
		"duplicator":
			Run.rack.append(Run.rack[t[0]].duplicate())
			return "Ball duplicated"
		"warranty":
			Run.flags.warranty = true
			return "Warranty active"
		"operators_key":
			var f := DB.random_firmware(rng, Run.firmware)
			Run.firmware.append(f)
			Run.mark_seen("firmware", f)
			return "New Firmware: %s" % DB.FIRMWARE[f].name
		"repair_kit":
			for s in Run.sockets:
				s.wear = 0.0
			return "All Parts repaired"
	return ""

static func _legendary_install(rng: RandomNumberGenerator, destroy_others: bool) -> String:
	var lid: String = DB.pick(rng, DB.LEGENDARIES)
	var sock: String = DB.PARTS[lid].socket
	var idxs := []
	for i in Run.sockets.size():
		if Run.sockets[i].type == sock:
			idxs.append(i)
	if destroy_others:
		for i in idxs:
			Run.remove_part(i)
	var target: int = idxs[0] if not destroy_others else idxs[0]
	if not destroy_others:
		target = Run.first_socket_of(sock)
	Run.install(target, lid)
	return lid

static func _fault(id: String, t: Array, rng: RandomNumberGenerator) -> String:
	match id:
		"err00":
			var lid := _legendary_install(rng, true)
			return "GHOST IN THE MACHINE: %s!" % DB.PARTS[lid].name
		"err07":
			Run.flags.gravity_leak = true
			Run.flags.outlane_widen = Run.flags.get("outlane_widen", 0) + 3
			return "Gravity leaks. The table floats."
		"err13":
			Run.remove_part(t[0])
			var cands := []
			for i in Run.sockets.size():
				var p: String = Run.sockets[i].part
				if p != "" and DB.PARTS[p].rarity != "S" and i != t[0]:
					cands.append(i)
			cands.shuffle()
			for k in mini(2, cands.size()):
				Run.sockets[cands[k]].finish = "phantom"
			return "Short circuit! Parts went Phantom."
		"err22":
			Run.flags.stuck_coil = true
			return "Next game: left flipper stuck up, every Shot x3"
		"err31":
			Run.flags.mirror = not Run.flags.get("mirror", false)
			var pid := DB.random_part(rng, "", "R")
			Run.install(Run.first_socket_of(DB.PARTS[pid].socket), pid)
			return "The table is mirrored. Got %s" % DB.PARTS[pid].name
		"err40":
			var di := rng.randi() % Run.rack.size()
			Run.rack.remove_at(di)
			for b in Run.rack:
				b.eng = DB.pick(rng, DB.ENGRAVINGS.keys())
			return "Rack crash: a ball is gone, the rest are engraved"
		"err55":
			var gain := clampi(Run.tickets, 0, 30)
			Run.add_tickets(gain)
			Run.jackpot = 0
			return "Overflow: +%d Tickets, Jackpot emptied" % gain
		"err64":
			var fws := Run.firmware.duplicate()
			var a: String = DB.pick(rng, fws)
			var others := fws.filter(func(x): return x != a)
			if not others.is_empty():
				Run.firmware.erase(DB.pick(rng, others))
			Run.firmware.append(a)
			return "Copied %s" % DB.FIRMWARE[a].name
		"err77":
			var up := {"C": "U", "U": "R", "R": "R"}
			for i in Run.sockets.size():
				var p: String = Run.sockets[i].part
				if p == "" or DB.PARTS[p].rarity in ["S", "L"]:
					continue
				var np := DB.random_part(rng, Run.sockets[i].type, up[DB.PARTS[p].rarity])
				if np != "":
					var fin: String = Run.sockets[i].finish
					Run.install(i, np, fin)
			return "Hard reset: every Part rerolled upward"
		"err99":
			Run.firmware_slots += 1
			Run.flags.balls_minus = Run.flags.get("balls_minus", 0) + 1
			return "Kernel panic: +1 Firmware slot, -1 ball"
	return ""

static func apply_deal(deal_id: String) -> String:
	var rng := Run.rng
	match deal_id:
		"slot_for_drain":
			Run.firmware_slots += 1
			Run.flags.outlane_widen = Run.flags.get("outlane_widen", 0) + 4
			return "+1 Firmware slot. The outlanes widen."
		"legend_for_tickets":
			var lid := _legendary_install(rng, false)
			Run.tickets = int(Run.tickets / 2)
			return "Got %s. Half your Tickets are gone." % DB.PARTS[lid].name
		"tickets_for_ball":
			Run.add_tickets(15)
			Run.flags.ball_minus_next = 1
			return "+15 Tickets. -1 ball next Aisle."
		"levels_for_tilt":
			var ks := DB.NORMAL_SHOTS.duplicate()
			ks.shuffle()
			for i in 3:
				Run.levels[ks[i]] += 1
			Run.flags.tilt_mult = Run.flags.get("tilt_mult", 1.0) * 1.25
			return "3 Shot types levelled. Tilt is touchier."
		"glass_for_part":
			Run.rack.append({"mat": "glass", "eng": ""})
			Run.rack.append({"mat": "glass", "eng": ""})
			var best := -1
			var bc := -1
			for i in Run.sockets.size():
				var p: String = Run.sockets[i].part
				if p != "" and DB.PARTS[p].rarity != "S" and DB.PARTS[p].cost > bc:
					bc = DB.PARTS[p].cost
					best = i
			if best >= 0:
				var nm: String = DB.PARTS[Run.sockets[best].part].name
				Run.remove_part(best)
				return "2 Glass balls. Lost %s." % nm
			return "2 Glass balls."
	return ""

static func apply_continue() -> String:
	var rng := Run.rng
	Run.continues -= 1
	var cands := []
	for i in Run.sockets.size():
		var p: String = Run.sockets[i].part
		if p != "" and DB.PARTS[p].rarity != "S":
			cands.append(i)
	cands.shuffle()
	var lost := []
	for k in mini(2, cands.size()):
		lost.append(DB.PARTS[Run.sockets[cands[k]].part].name)
		Run.remove_part(cands[k])
	var curse: String = DB.pick(rng, DB.CURSES.keys())
	Run.flags.curses.append(curse)
	var msg := "Coin inserted. Curse: %s." % DB.CURSES[curse].name
	if not lost.is_empty():
		msg += " Lost: " + ", ".join(lost)
	return msg

# ------------------------------------------------------------------ SHOP
static func consumable_price(kind: String) -> int:
	return {"blueprint": 3, "tool": 3, "fault": 5}.get(kind, 3)

static func capsule_price(type: String) -> int:
	return {"part": 4, "blueprint": 4, "tool": 4, "fault": 6, "ball": 4, "firmware": 6}.get(type, 4)

static func random_consumable(rng: RandomNumberGenerator) -> Dictionary:
	var r := rng.randf()
	if r < 0.45:
		var pool := DB.NORMAL_SHOTS.duplicate()
		for s in Run.secrets:
			pool.append(s)
		if rng.randf() < 0.06:
			return {"kind": "blueprint", "id": "master_plan"}
		return {"kind": "blueprint", "id": DB.pick(rng, pool)}
	elif r < 0.85:
		var tools := DB.TOOLS.keys()
		if Run.stake < 6:
			tools.erase("repair_kit")
		return {"kind": "tool", "id": DB.pick(rng, tools)}
	return {"kind": "fault", "id": DB.pick(rng, DB.FAULTS.keys().filter(func(x): return x != "err00"))}

static func random_ball(rng: RandomNumberGenerator) -> Dictionary:
	var mats := DB.BALLS.keys()
	mats.erase("steel")
	var m: String = DB.pick(rng, mats)
	var e := ""
	if Run.has_mod("pro_shop") or rng.randf() < 0.2:
		e = DB.pick(rng, DB.ENGRAVINGS.keys())
	return {"mat": m, "eng": e}

static func gen_part_offer(rng: RandomNumberGenerator, rarity: String = "") -> Dictionary:
	var pid := DB.random_part(rng, "", rarity)
	var fin := ""
	var fr := rng.randf()
	if fr < 0.08:
		fin = "chrome"
	elif fr < 0.13:
		fin = "neon"
	elif fr < 0.16:
		fin = "gold"
	elif fr < 0.18:
		fin = "holo"
	var base: int = DB.PARTS[pid].cost + {"": 0, "chrome": 2, "neon": 3, "gold": 3, "holo": 4}[fin]
	var off := {"kind": "part", "id": pid, "finish": fin, "price": Run.price(base), "rental": false}
	if Run.stake >= 7 and rng.randf() < 0.3:
		off.rental = true
		off.price = maxi(1, int(off.price * 0.4))
	return off

static func generate_shop() -> void:
	var rng := Run.rng
	var st := {"offers": [], "rerolls": 0, "mod": {}, "capsules": []}
	var keep_free: String = Run.shop_state.get("free_capsule", "")
	var free_rare: bool = Run.shop_state.get("free_rare", false)
	st.offers = _roll_offers(rng)
	if Run.coupon_rare and Run.chassis != "pawn_shop":
		var o := gen_part_offer(rng, "R")
		o.price = 0 if free_rare else maxi(1, int(o.price / 2))
		o["coupon"] = true
		st.offers[0] = o
		Run.coupon_rare = false
	# mod
	var mod_pool := []
	for m in DB.MODS:
		if Run.mods.has(m):
			continue
		var md = DB.MODS[m]
		if md.tier == 1:
			if m == "insert_coin" and Run.stake >= 8:
				continue
			mod_pool.append(m)
		else:
			for m1 in DB.MODS:
				if DB.MODS[m1].get("next", "") == m and Run.mods.has(m1):
					mod_pool.append(m)
	if not mod_pool.is_empty():
		var mid: String = DB.pick(rng, mod_pool)
		st.mod = {"kind": "mod", "id": mid, "price": Run.price(10 if DB.MODS[mid].tier == 1 else 12)}
	# capsules
	var ncap := 2 if Run.chassis != "pawn_shop" else 4
	for i in ncap:
		var ty: String = DB.pick(rng, ["part", "blueprint", "tool", "fault", "ball", "firmware", "part", "blueprint"])
		st.capsules.append({"kind": "capsule", "id": ty, "price": Run.price(capsule_price(ty))})
	if keep_free != "":
		st.capsules.append({"kind": "capsule", "id": keep_free, "price": 0, "free": true})
	Run.shop_state = st

static func _roll_offers(rng: RandomNumberGenerator) -> Array:
	var offers := []
	if Run.chassis != "pawn_shop":
		offers.append(gen_part_offer(rng))
		offers.append(gen_part_offer(rng))
	var fid := DB.random_firmware(rng, Run.firmware)
	if fid != "":
		offers.append({"kind": "firmware", "id": fid, "price": Run.price(DB.FIRMWARE[fid].cost)})
	var nballs := 2 if Run.has_mod("big_rack") else 1
	for i in nballs:
		var b := random_ball(rng)
		offers.append({"kind": "ball", "id": b.mat, "eng": b.eng, "price": Run.price(DB.BALLS[b.mat].cost + (2 if b.eng != "" else 0))})
	for i in 2:
		var c := random_consumable(rng)
		c["price"] = Run.price(consumable_price(c.kind))
		offers.append(c)
	return offers

static func reroll_cost() -> int:
	var base := 3 + int(Run.shop_state.get("rerolls", 0))
	if Run.has_mod("greased_claw"):
		base -= 1
	if Run.has_mod("rigged_claw") and int(Run.shop_state.get("rerolls", 0)) == 0:
		return 0
	return maxi(base, 0)

static func reroll() -> void:
	Run.shop_state.rerolls = int(Run.shop_state.get("rerolls", 0)) + 1
	var kept := []
	for o in Run.shop_state.offers:
		if o.get("coupon", false):
			kept.append(o)
	var fresh := _roll_offers(Run.rng)
	for i in kept.size():
		fresh[i] = kept[i]
	Run.shop_state.offers = fresh

static func capsule_choices(type: String) -> Array:
	var rng := Run.rng
	var out := []
	var n := 3
	if type in ["fault", "firmware"]:
		n = 2
	var used := []
	for i in n:
		match type:
			"part":
				var o := gen_part_offer(rng)
				var tries := 0
				while used.has(o.id) and tries < 6:
					o = gen_part_offer(rng)
					tries += 1
				used.append(o.id)
				o.price = -1
				o.rental = false
				out.append(o)
			"blueprint":
				var c := random_consumable(rng)
				while c.kind != "blueprint":
					c = random_consumable(rng)
				out.append(c)
			"tool":
				var tl := DB.TOOLS.keys()
				if Run.stake < 6:
					tl.erase("repair_kit")
				out.append({"kind": "tool", "id": DB.pick(rng, tl)})
			"fault":
				var fk := DB.FAULTS.keys()
				if rng.randf() > 0.25:
					fk.erase("err00")
				out.append({"kind": "fault", "id": DB.pick(rng, fk)})
			"ball":
				var b := random_ball(rng)
				out.append({"kind": "ball", "id": b.mat, "eng": b.eng})
			"firmware":
				var f := DB.random_firmware(rng, Run.firmware + used)
				used.append(f)
				out.append({"kind": "firmware", "id": f})
	return out

static func gauntlet_choices() -> Array:
	var rng := Run.rng
	var out := []
	var kinds := ["part", "consumable", "firmware", "ball", "tickets"]
	kinds.shuffle()
	for i in 3:
		match kinds[i]:
			"part":
				var o := gen_part_offer(rng)
				o.price = -1
				o.rental = false
				out.append(o)
			"consumable":
				out.append(random_consumable(rng))
			"firmware":
				out.append({"kind": "firmware", "id": DB.random_firmware(rng, Run.firmware)})
			"ball":
				var b := random_ball(rng)
				out.append({"kind": "ball", "id": b.mat, "eng": b.eng})
			"tickets":
				out.append({"kind": "stat", "id": "tickets", "title": "+8 Tickets", "desc": "Take the money.", "big": "T8"})
	return out
