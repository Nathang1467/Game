extends RefCounted
## Builds the physical table from the current Chassis + sockets.
## World space is 535 x 975, y points down (towards the flippers).

const W := 535.0
const H := 975.0
const RETURN_Y := 800.0

static func build(cfg: Dictionary) -> Dictionary:
	var socks: Array = cfg.sockets
	var chassis: String = cfg.get("chassis", "classic")
	var widen: float = cfg.get("widen", 0.0)
	var fscale: float = cfg.get("flip_scale", 1.0)
	var boss: String = cfg.get("boss", "")
	var L := {
		"segs": [], "circles": [], "flippers": [], "lanes": [], "lane_posts": [], "targets": [],
		"ramps": {}, "bumpers": {}, "cups": [], "walls_draw": [], "sling_polys": [], "lamps": [],
		"plunger": Vector2(497.5, 944.0), "plunger_floor": 955.0, "lane_x0": 480.0, "lane_x1": 515.0,
		"orbit_bottom": {"y": 555.0, "x0": 20.0, "x1": 58.0}, "orbit_top": {"y": 285.0, "x0": 20.0, "x1": 58.0},
		"orbit_sock": -1, "scoop": {}, "saucer": {"c": Vector2(178, 200), "r": 14.0, "eject": Vector2(120, 380)},
		"center": {}, "outlane_div": [62.0 + widen, 438.0 - widen], "mirror": cfg.get("mirror", false),
		"lanes_sock": -1, "target_sock": -1, "center_sock": -1, "scoop_sock": -1, "outlane_socks": {},
		"bagatelle": chassis == "bagatelle", "mimic": boss == "mimic", "magnet_heart": Vector2(250, 470),
	}
	# ---------------- index sockets
	var bumper_idx := []
	for i in socks.size():
		var s = socks[i]
		match s.type:
			"bumper": bumper_idx.append(i)
			"target": L.target_sock = i
			"lanes": L.lanes_sock = i
			"orbit": L.orbit_sock = i
			"scoop": L.scoop_sock = i
			"center": L.center_sock = i
			"ramp": L.ramps[i] = {"side": s.side}
			"outlane": L.outlane_socks[s.side] = i
	# ---------------- outer walls
	var arc := PackedVector2Array()
	var cx := 267.5
	var rr := 247.5
	for k in 37:
		var t := PI * float(k) / 36.0
		arc.append(Vector2(cx + rr * cos(t), 250.0 - rr * sin(t)))
	_poly(L, arc, 0.35)
	# side walls kink inward above the slingshots, so a ball hugging a wall
	# gets thrown back toward the slings instead of dropping straight into an outlane
	_poly(L, PackedVector2Array([Vector2(20, 250), Vector2(20, 560), Vector2(68, 648), Vector2(30, 698), Vector2(30, 990)]), 0.4)
	_poly(L, PackedVector2Array([Vector2(515, 250), Vector2(515, 990)]), 0.4)
	_poly(L, PackedVector2Array([Vector2(480, 300), Vector2(480, 990)]), 0.4)
	_poly(L, PackedVector2Array([Vector2(480, 560), Vector2(432, 648), Vector2(470, 698), Vector2(470, 990)]), 0.4)
	_seg(L, Vector2(480, 955), Vector2(515, 955), 0.1, "floor")
	_seg(L, Vector2(480, 300), Vector2(515, 262), 0.3, "gate")
	# orbit inner wall + one-way gate: balls going up the orbit pass,
	# balls coming down off the top arc get deflected into the playfield.
	_poly(L, PackedVector2Array([Vector2(58, 322), Vector2(58, 560)]), 0.45)
	_circle(L, Vector2(58, 322), 5, 0.5, "post")
	_seg(L, Vector2(20, 262), Vector2(60, 300), 0.3, "oneway", -1, false)
	_circle(L, Vector2(58, 560), 5, 0.5, "post")
	# ---------------- lanes
	var lanes_part: String = socks[L.lanes_sock].part if L.lanes_sock >= 0 else ""
	if lanes_part != "":
		var xs := [290.0, 350.0, 410.0]
		var posts := [260.0, 320.0, 380.0, 440.0]
		if lanes_part == "luck_lanes":
			xs = [275.0, 325.0, 375.0, 425.0]
			posts = [250.0, 300.0, 350.0, 400.0, 450.0]
		for x in xs:
			L.lanes.append({"c": Vector2(x, 140), "r": 13.0})
		for x in posts:
			_seg(L, Vector2(x, 122), Vector2(x, 158), 0.4, "wall", -1, true)
			L.lane_posts.append(Vector2(x, 122))
	# ---------------- bumpers
	var bpos := [Vector2(205, 318), Vector2(300, 300), Vector2(258, 392), Vector2(160, 410), Vector2(352, 392)]
	for n in bumper_idx.size():
		var si: int = bumper_idx[n]
		var pid: String = socks[si].part
		if pid == "":
			continue
		L.bumpers[si] = {"c": bpos[n], "home": bpos[n], "r": 22.0}
		_circle(L, bpos[n], 22.0, 0.5, "bumper", si)
	# ---------------- target bank
	if L.target_sock >= 0 and socks[L.target_sock].part != "":
		var tp: String = socks[L.target_sock].part
		var ys := [430.0, 470.0, 510.0]
		var half := 15.0
		if tp == "sniper_target":
			ys = [470.0]
			half = 6.0
		for k in ys.size():
			var y: float = ys[k]
			var sidx: int = L.segs.size()
			_seg(L, Vector2(469, y - half), Vector2(469, y + half), 0.5, "target", L.target_sock)
			L.segs[sidx]["ti"] = k
			L.targets.append({"seg": sidx, "c": Vector2(469, y), "half": half})
	# ---------------- ramps
	var left_path := PackedVector2Array([Vector2(117, 522), Vector2(112, 440), Vector2(100, 340), Vector2(110, 240), Vector2(150, 150), Vector2(230, 95), Vector2(330, 90), Vector2(420, 130), Vector2(455, 220), Vector2(460, 330), Vector2(452, 450), Vector2(440, 560), Vector2(430, 650), Vector2(423, 705)])
	for ri in L.ramps.keys():
		var side: String = L.ramps[ri].side
		var path := left_path.duplicate()
		var ma := Vector2(94, 522)
		var mb := Vector2(140, 522)
		if side == "right":
			path = _mirror_path(left_path, 500.0)
			ma = Vector2(360, 522)
			mb = Vector2(406, 522)
		L.ramps[ri]["path"] = path
		L.ramps[ri]["a"] = ma
		L.ramps[ri]["b"] = mb
		L.ramps[ri]["exit_vel"] = Vector2(0, 260)
		L.ramps[ri]["len"] = _path_len(path)
		_circle(L, ma, 6, 0.5, "post")
		_circle(L, mb, 6, 0.5, "post")
		var kind := "mouth" if socks[ri].part != "" else "wall"
		var mi: int = L.segs.size()
		_seg(L, ma, mb, 0.35, kind, ri, true)
		L.ramps[ri]["seg"] = mi
	# ---------------- scoop
	if L.scoop_sock >= 0 and socks[L.scoop_sock].part != "":
		L.scoop = {"c": Vector2(98, 420), "r": 14.0, "eject": Vector2(430, 200), "sock": L.scoop_sock}
	# ---------------- center
	if L.center_sock >= 0:
		var cp: String = socks[L.center_sock].part
		L.center = {"part": cp, "sock": L.center_sock}
		match cp:
			"spinner":
				L.center.a = Vector2(222, 600)
				L.center.b = Vector2(278, 600)
			"gyro_disc":
				L.center.c = Vector2(250, 600)
				L.center.r = 26.0
			"magnet":
				L.center.c = Vector2(250, 560)
			"wrecking_post":
				L.center.c = Vector2(250, 906)
				_circle(L, Vector2(250, 906), 7.0, 0.6, "wreck", L.center_sock)
			"playfield_doubler":
				L.center.c = Vector2(250, 600)
	if L.mimic:
		_circle(L, Vector2(383, 500), 18.0, 0.5, "mimic")
	# ---------------- slingshots + inlanes
	var d0: float = L.outlane_div[0]
	var d1: float = L.outlane_div[1]
	if not L.bagatelle:
		_sling(L, Vector2(92, 640), Vector2(92, 750), Vector2(150, 790), "left")
		_sling(L, Vector2(408, 640), Vector2(408, 750), Vector2(350, 790), "right")
		_circle(L, Vector2(d0, 690), 5, 0.5, "post")
		_circle(L, Vector2(d1, 690), 5, 0.5, "post")
		_poly(L, PackedVector2Array([Vector2(d0, 690), Vector2(d0, 770), Vector2(161, 840)]), 0.3)
		_poly(L, PackedVector2Array([Vector2(d1, 690), Vector2(d1, 770), Vector2(339, 840)]), 0.3)
		var fl := 70.0 * fscale
		if boss == "short_change":
			fl *= 0.7
		L.flippers.append(_flipper(Vector2(158, 850), fl, deg_to_rad(28), deg_to_rad(-32), "left"))
		L.flippers.append(_flipper(Vector2(342, 850), fl, deg_to_rad(152), deg_to_rad(212), "right"))
		if chassis == "tri_flipper":
			L.flippers.append(_flipper(Vector2(150, 625), 52.0 * fscale, deg_to_rad(20), deg_to_rad(-25), "left"))
		if L.center.get("part", "") == "old_mans_flipper":
			L.flippers.append(_flipper(Vector2(350, 625), 52.0 * fscale, deg_to_rad(160), deg_to_rad(205), "right"))
	else:
		# Bagatelle: sling walls stay, flippers become a peg field over three cups
		_sling(L, Vector2(92, 640), Vector2(92, 750), Vector2(150, 790), "left")
		_sling(L, Vector2(408, 640), Vector2(408, 750), Vector2(350, 790), "right")
		_circle(L, Vector2(d0, 690), 5, 0.5, "post")
		_circle(L, Vector2(d1, 690), 5, 0.5, "post")
		_poly(L, PackedVector2Array([Vector2(d0, 690), Vector2(d0, 800)]), 0.3)
		_poly(L, PackedVector2Array([Vector2(d1, 690), Vector2(d1, 800)]), 0.3)
		for row in 5:
			var y := 810.0 + row * 30.0
			var off := 22.0 if row % 2 == 1 else 0.0
			var x := 95.0 + off
			while x <= 410.0:
				if not (row == 4 and _near_cup(x)):
					_circle(L, Vector2(x, y), 4.5, 0.55, "peg")
				x += 44.0
		for cxp in [120.0, 250.0, 380.0]:
			L.cups.append({"c": Vector2(cxp, 950), "w": 24.0})
			_seg(L, Vector2(cxp - 24, 928), Vector2(cxp - 24, 968), 0.3, "wall", -1, true)
			_seg(L, Vector2(cxp + 24, 928), Vector2(cxp + 24, 968), 0.3, "wall", -1, true)
			_seg(L, Vector2(cxp - 24, 968), Vector2(cxp + 24, 968), 0.1, "wall", -1, true)
	# ---------------- lamps (for drawing inserts)
	for i in socks.size():
		var s = socks[i]
		if s.part == "" or s.type == "outlane" or s.part == "stock_center":
			continue
		L.lamps.append(i)
	if L.mirror:
		_apply_mirror(L)
	return L

static func _near_cup(x: float) -> bool:
	for c in [120.0, 250.0, 380.0]:
		if absf(x - c) < 32.0:
			return true
	return false

static func _flipper(pivot: Vector2, length: float, rest: float, up: float, key: String) -> Dictionary:
	return {"pivot": pivot, "len": length, "r0": 10.0, "r1": 6.0, "rest": rest, "up": up, "key": key, "angle": rest, "omega": 0.0, "pressed": false}

static func _sling(L: Dictionary, a: Vector2, b: Vector2, c: Vector2, side: String) -> void:
	_seg(L, a, b, 0.4, "wall", -1, false)
	_seg(L, b, c, 0.4, "wall", -1, false)
	var i: int = L.segs.size()
	_seg(L, a, c, 0.6, "sling", -1, false)
	L.segs[i]["side"] = side
	L.sling_polys.append({"pts": PackedVector2Array([a, b, c]), "seg": i})
	_circle(L, a, 4, 0.5, "post")
	_circle(L, c, 4, 0.5, "post")

static func _poly(L: Dictionary, pts: PackedVector2Array, e: float) -> void:
	for k in pts.size() - 1:
		_seg(L, pts[k], pts[k + 1], e, "wall", -1, false)
	L.walls_draw.append(pts)

static func _seg(L: Dictionary, a: Vector2, b: Vector2, e: float, kind: String, tag: int = -1, draw: bool = false) -> void:
	var mn := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(14, 14)
	var mx := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(14, 14)
	L.segs.append({"a": a, "b": b, "e": e, "kind": kind, "tag": tag, "on": true, "min": mn, "max": mx, "draw": draw})

static func _circle(L: Dictionary, c: Vector2, r: float, e: float, kind: String, tag: int = -1) -> void:
	L.circles.append({"c": c, "r": r, "e": e, "kind": kind, "tag": tag, "on": true, "flash": 0.0})

static func _mirror_path(p: PackedVector2Array, axis2: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	for v in p:
		o.append(Vector2(axis2 - v.x, v.y))
	return o

static func _path_len(p: PackedVector2Array) -> float:
	var l := 0.0
	for k in p.size() - 1:
		l += p[k].distance_to(p[k + 1])
	return l

static func mx(v: Vector2) -> Vector2:
	return Vector2(W - v.x, v.y)

static func _apply_mirror(L: Dictionary) -> void:
	for s in L.segs:
		s.a = mx(s.a)
		s.b = mx(s.b)
		var mn := Vector2(minf(s.a.x, s.b.x), minf(s.a.y, s.b.y)) - Vector2(14, 14)
		var mxx := Vector2(maxf(s.a.x, s.b.x), maxf(s.a.y, s.b.y)) + Vector2(14, 14)
		s.min = mn
		s.max = mxx
		if s.has("side"):
			s.side = "right" if s.side == "left" else "left"
	for c in L.circles:
		c.c = mx(c.c)
	for f in L.flippers:
		f.pivot = mx(f.pivot)
		f.rest = PI - f.rest
		f.up = PI - f.up
		f.angle = f.rest
		f.key = "right" if f.key == "left" else "left"
	for ln in L.lanes:
		ln.c = mx(ln.c)
	for i in L.lane_posts.size():
		L.lane_posts[i] = mx(L.lane_posts[i])
	for t in L.targets:
		t.c = mx(t.c)
	for b in L.bumpers.values():
		b.c = mx(b.c)
		b.home = mx(b.home)
	for r in L.ramps.values():
		if r.has("path"):
			var p := PackedVector2Array()
			for v in r.path:
				p.append(mx(v))
			r.path = p
			r.a = mx(r.a)
			r.b = mx(r.b)
		r.side = "right" if r.side == "left" else "left"
	for w in L.walls_draw.size():
		var p := PackedVector2Array()
		for v in L.walls_draw[w]:
			p.append(mx(v))
		L.walls_draw[w] = p
	for sp in L.sling_polys:
		var p := PackedVector2Array()
		for v in sp.pts:
			p.append(mx(v))
		sp.pts = p
	for cup in L.cups:
		cup.c = mx(cup.c)
	L.plunger = mx(L.plunger)
	var x0: float = L.lane_x0
	L.lane_x0 = W - L.lane_x1
	L.lane_x1 = W - x0
	for key in ["orbit_bottom", "orbit_top"]:
		var o = L[key]
		var a: float = o.x0
		o.x0 = W - o.x1
		o.x1 = W - a
	if not L.scoop.is_empty():
		L.scoop.c = mx(L.scoop.c)
		L.scoop.eject.x = -L.scoop.eject.x
	L.saucer.c = mx(L.saucer.c)
	L.saucer.eject.x = -L.saucer.eject.x
	for k in ["a", "b", "c"]:
		if L.center.has(k):
			L.center[k] = mx(L.center[k])
	L.outlane_div = [W - L.outlane_div[1], W - L.outlane_div[0]]
	var os := {}
	for side in L.outlane_socks:
		os["right" if side == "left" else "left"] = L.outlane_socks[side]
	L.outlane_socks = os
	L.magnet_heart = mx(L.magnet_heart)
