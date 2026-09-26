extends Node2D
## The pinball table: custom ball physics, the Shot / cash-in scoring engine,
## every Part, ball, boss and rule interaction, and all table drawing.

const UI = preload("res://scripts/ui/ui.gd")
const Layout = preload("res://scripts/table/layout.gd")

signal ended(result: Dictionary)
signal dmd(text: String, col: Color)
signal feed(text: String, col: Color)
signal cashed(value: float, pts: float, mult: float, xm: float)
signal shake_req(amount: float)

const W := 535.0
const H := 975.0
const RETURN_Y := 800.0
const SUBSTEPS := 4
const BASE_G := 1000.0
const MAX_SPEED := 2700.0
const R_BALL := 10.0

# ------------------------------------------------------------------ inner types
class Shot:
	var pts := 0.0
	var mult := 1.0
	var xm := 1.0
	var t := 0.0
	var hits := 0
	var data := {}
	var saves := 0
	func value() -> float:
		return maxf(pts, 0.0) * maxf(mult, 0.0) * maxf(xm, 0.0)

class Ball:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r := 10.0
	var mat := "steel"
	var eng := ""
	var rack_idx := -1
	var primary := true
	var bee := false
	var life := 0.0
	var parent: Ball = null
	var state := "free"   # free, plunger, held, ramp, locked
	var hold_t := 0.0
	var hold_kind := ""
	var eject := Vector2.ZERO
	var ramp_sock := -1
	var ramp_d := 0.0
	var ramp_speed := 0.0
	var ramp_air := false
	var in_lane := false
	var shot: Shot = null
	var at_risk := false
	var hits := 0
	var trail: Array = []
	var dead := false
	var last_flip := -1
	var last_flip_t := -10.0
	var max_up_since_flip := 0.0
	var cradle_t := 0.0
	var in_outlane := ""
	var kicked := false
	var bang := false
	var orbit_t := -10.0
	var since_return := 0.0
	var no_flip_t := 0.0
	var split_done := false
	var accel := 0
	var fuse_t := 0.0
	var rusted := false
	var ghost_in := {}
	var lane_in := {}
	var gyro_in := false
	var spin_side := 0.0
	var haunt_one := false
	var magnet_cd := 0.0
	var hole_cd := 0.0
	var still_t := 0.0
	var low_side := ""
	var flip_contact := false
	var launched_t := 0.0

# ------------------------------------------------------------------ state
var L: Dictionary = {}
var socks: Array = []
var levels: Dictionary = {}
var balls: Array = []
var pending_balls: Array = []
var state := "idle"   # idle, serve, play, bonus, won, lost
var attract := false
var autopilot := false
var paused := false
var rival := false

var chassis := "classic"
var boss := ""
var ball_boss := ""
var feature := ""
var target := 1000.0
var score := 0.0
var game_indices: Array = []
var ball_no := 0
var balls_total := 3
var ball_time := 0.0
var game_time := 0.0
var tilt := 0.0
var tilted := false
var fever := 0
var lamps := {}
var bonus_x := 1
var skill_lane := -1
var skill_t := 0.0
var saver := 0.0
var kick_charge := {"left": true, "right": true}
var magna_used := {}
var magnet_uses := 2
var lane_lit: Array = []
var toll_lanes_paid := {}
var drop_down: Array = []
var drop_reset_t := -1.0
var memory_seq: Array = []
var memory_pos := 0
var wreck_hits := 0
var wreck_broken := false
var locked: Array = []
var pf_t := 0.0
var pf_on := false
var wizard_t := 0.0
var wizard_done := false
var ferris_n := 0
var ferris_last := -100.0
var shot_counts := {}
var destroyed: Array = []
var burned := {}
var disabled := {}
var disabled_ball := {}
var taxman_type := ""
var wind_dir := 1.0
var wind_t := 0.0
var rattle_t := 3.0
var mirror_t := 30.0
var endless_t := 20.0
var endless_total := 180.0
var last_call_t := 90.0
var rival_t := 60.0
var angel_used := false
var haunt_used := false
var carnival_paid := 0
var gold_paid := 0
var last_rites_carry := 0.0
var tesla_cd := 0.0
var stuck_coil := false
var steady := false
var twin_pending := 0.0
var lane_change_flag := {"left": false, "right": false}
var result_sent := false
var bonus_show := {}
var plunge_charge := 0.0
var shift_held := false
var hitstop := 0.0
var cup_hold: Array = []
var _prev_press := {"left": false, "right": false}
var _ai := {"left": 0.0, "right": 0.0, "plunge": -1.0, "charge": 0.8, "cd_left": 0.0, "cd_right": 0.0}
var multiball_peak := 0
var game_stats := {"best_shot": 0.0, "cashes": 0}
var drain_log: Array = []

# visuals
var popups: Array = []
var particles: Array = []
var flashes := {}
var t_anim := 0.0
var mask_rect: ColorRect
var at_risk_any := false
var font_head: Font
var font_main: Font
var font_dmd: Font

func _ready() -> void:
	font_head = UI.font("head")
	font_main = UI.font("main")
	font_dmd = UI.font("dmd")
	mask_rect = ColorRect.new()
	mask_rect.size = Vector2(W, H)
	mask_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/mask.gdshader")
	mask_rect.material = m
	mask_rect.visible = false
	add_child(mask_rect)

# ================================================================== SETUP
func start_attract() -> void:
	attract = true
	autopilot = true
	socks = _demo_sockets()
	levels = {}
	for s in DB.SHOTS:
		levels[s] = 2
	chassis = "classic"
	boss = ""
	feature = ""
	target = 1e18
	balls_total = 999
	game_indices = []
	_reset_game_vars()
	_rebuild()
	serve()

func _demo_sockets() -> Array:
	var d := [
		["bumper", "pop_bumper", "chrome"], ["bumper", "hot_bumper", ""], ["bumper", "tesla_coil", "neon"],
		["target", "drop_bank", ""], ["lanes", "luck_lanes", ""], ["ramp", "ferris_ramp", "", "left"], ["ramp", "long_ramp", "", "right"],
		["orbit", "centrifuge", ""], ["scoop", "ball_lock", ""], ["center", "spinner", ""], ["outlane", "kickback", "", "left"], ["outlane", "kickback", "", "right"],
	]
	var out := []
	for e in d:
		out.append({"type": e[0], "part": e[1], "finish": e[2], "wear": 0.0, "upgrade": 1.0, "rental": false, "side": e[3] if e.size() > 3 else ""})
	return out

func start_game() -> void:
	attract = false
	autopilot = autopilot and true
	rival = Run.rival_mode
	socks = Run.sockets
	levels = Run.levels
	chassis = Run.chassis
	boss = "" if rival else Run.boss_active()
	feature = Run.feature if (Run.stage == 1 and not rival) else ""
	target = Run.current_target()
	balls_total = Run.balls_per_game()
	game_indices = Run.draw_game_balls(balls_total)
	_reset_game_vars()
	stuck_coil = Run.flags.get("stuck_coil", false)
	steady = Run.pending_credits.has("steady_table")
	_rebuild()
	if boss == "jam":
		var best := -1
		var bestv := -1
		for i in socks.size():
			var p: String = socks[i].part
			if p == "" or DB.PARTS[p].rarity == "S":
				continue
			var v: int = DB.PARTS[p].cost
			if v > bestv:
				bestv = v
				best = i
		if best >= 0:
			disabled[best] = true
			_dmd("JAM: %s DISABLED" % DB.PARTS[socks[best].part].name.to_upper(), UI.RED)
	if boss == "collector" and Run.jackpot > 0:
		_dmd("THE COLLECTOR TAKES %d JACKPOT" % Run.jackpot, UI.RED)
		Run.jackpot = 0
	if feature == "no_bumpers":
		for c in L.circles:
			if c.kind == "bumper":
				c.kind = "deadbumper"
	serve()

func _reset_game_vars() -> void:
	for b in balls:
		b.dead = true
	balls = []
	pending_balls = []
	locked = []
	score = 0.0
	ball_no = 0
	game_time = 0.0
	tilt = 0.0
	tilted = false
	fever = 0
	lamps = {}
	if Run.has_mod("lamp_memory_plus") and not attract:
		lamps = Run.lamps_memory.duplicate()
	bonus_x = 1
	wreck_hits = 0
	wreck_broken = false
	pf_t = 0.0
	pf_on = false
	wizard_t = 0.0
	wizard_done = false
	ferris_n = 0
	shot_counts = {}
	destroyed = []
	burned = {}
	disabled = {}
	angel_used = false
	haunt_used = false
	carnival_paid = 0
	gold_paid = 0
	last_rites_carry = 0.0
	result_sent = false
	mirror_t = 30.0
	last_call_t = 90.0
	rival_t = 60.0
	endless_t = 20.0
	endless_total = 180.0
	multiball_peak = 0
	game_stats = {"best_shot": 0.0, "cashes": 0}
	drain_log = []
	popups = []
	particles = []
	memory_pos = 0
	if not attract:
		var gm: float = 0.0
		if chassis == "crooked":
			gm = Run.rng.randf_range(-220.0, 220.0)
		Run.flags["crooked_x"] = gm

func _rebuild(keep_state: bool = false) -> void:
	var mirror: bool = false if attract else Run.flags.get("mirror", false)
	if boss == "mirror_machine" and keep_state:
		mirror = not L.get("mirror", false)
	elif boss == "mirror_machine" and L.has("mirror") and not keep_state:
		mirror = L.mirror
	var cfg := {
		"sockets": socks, "chassis": chassis,
		"widen": 0.0 if attract else Run.outlane_widen(),
		"flip_scale": 1.0 if attract else Run.flipper_scale(),
		"boss": _brule_boss(),
		"mirror": mirror,
	}
	var old_flip_angles := []
	if keep_state and L.has("flippers"):
		for f in L.flippers:
			old_flip_angles.append(f.angle)
	L = Layout.build(cfg)
	lane_lit = []
	for i in L.lanes.size():
		lane_lit.append(false)
	drop_down = []
	for i in L.targets.size():
		drop_down.append(false)
	if memory_seq.size() != L.targets.size():
		memory_seq = range(L.targets.size())
		memory_seq.shuffle()
		memory_pos = 0
	if stuck_coil:
		for f in L.flippers:
			if f.key == "left":
				f.angle = f.up

func _brule_boss() -> String:
	return ball_boss if ball_boss != "" else boss

func brule(id: String) -> bool:
	return boss == id or ball_boss == id

func part(si: int) -> String:
	if si < 0 or si >= socks.size():
		return ""
	return socks[si].part

func has_part(pid: String) -> bool:
	for s in socks:
		if s.part == pid:
			return true
	return false

func sock_of_part(pid: String) -> int:
	for i in socks.size():
		if socks[i].part == pid:
			return i
	return -1

# ================================================================== SERVE / LAUNCH
func serve() -> void:
	state = "serve"
	ball_time = 0.0
	tilt = 0.0
	tilted = false
	fever = 0
	saver = 0.0
	magnet_uses = 2
	magna_used = {}
	kick_charge = {"left": true, "right": true}
	toll_lanes_paid = {}
	disabled_ball = {}
	if not (Run.has_mod("lamp_memory") or Run.has_mod("lamp_memory_plus")) or attract:
		lamps = {}
	bonus_x = 1
	ball_boss = ""
	if boss == "the_operator":
		ball_boss = DB.pick(Run.rng, DB.OPERATOR_POOL)
		_dmd("OPERATOR RULE: %s" % DB.BOSSES[ball_boss].name.to_upper(), UI.RED)
		_rebuild()
	elif boss == "short_change" or boss == "mimic":
		pass
	if brule("taxman"):
		var pool := ["bumper", "ramp", "orbit", "rollover", "sling"]
		if L.targets.size() > 0:
			pool.append("target")
		taxman_type = DB.pick(Run.rng, pool)
		_dmd("TAXMAN: ONLY %s SCORES" % DB.SHOTS[taxman_type].name.to_upper(), UI.TICKET)
	var b := Ball.new()
	b.shot = null
	if not attract:
		var ri: int = game_indices[mini(ball_no, game_indices.size() - 1)] if not game_indices.is_empty() else -1
		b.rack_idx = ri
		if ri >= 0 and ri < Run.rack.size():
			b.mat = Run.rack[ri].mat
			b.eng = Run.rack[ri].eng
		if b.mat == "echo" and not Run.last_drained.is_empty():
			b.mat = Run.last_drained.mat
			b.eng = Run.last_drained.eng
		if b.eng == "tally":
			bonus_x += 1
		if brule("pay_to_play"):
			Run.add_tickets(-2)
			_dmd("PAY TO PLAY: -2 TICKETS", UI.TICKET)
		if (feature == "fever_start") or (ball_no == 0 and Run.pending_credits.has("hot_start")):
			ball_time = 45.0
	b.shot = _new_shot(b)
	_place_on_plunger(b)
	balls.append(b)
	if L.lanes.size() > 0:
		skill_lane = randi() % L.lanes.size()
		skill_t = -1.0
	if chassis == "twin_table" and not attract:
		twin_pending = -1.0
	if not attract:
		var lbl := "BALL %d / %d" % [ball_no + 1, balls_total]
		if boss == "endless_ball":
			lbl = "THE ENDLESS BALL"
		_dmd(lbl, UI.DMD)

func _place_on_plunger(b: Ball) -> void:
	b.state = "plunger"
	b.pos = L.plunger
	b.vel = Vector2.ZERO
	b.in_lane = true
	b.at_risk = false
	b.trail = []

func launch(b: Ball, charge: float) -> void:
	b.state = "free"
	b.in_lane = true
	b.vel = Vector2(0, -(750.0 + 1750.0 * clampf(charge, 0.0, 1.0)))
	b.launched_t = game_time
	if b.primary and ball_time < 1.0:
		saver = 0.0 if attract else Run.ball_saver_time()
	if b.primary:
		skill_t = 5.0
	state = "play"
	Sfx.play("plunge", 0.8 + charge * 0.5)
	if chassis == "twin_table" and b.primary and not attract and twin_pending < 0.0:
		twin_pending = 0.9
	if boss == "wizards_cabinet" and b.primary:
		for k in 2:
			_spawn_temp_to_plunger(0.6 + 0.6 * k)

func _spawn_temp_to_plunger(delay: float) -> void:
	var t := Ball.new()
	t.primary = false
	t.mat = "steel"
	t.shot = _new_shot(t)
	t.state = "held"
	t.hold_kind = "autolaunch"
	t.hold_t = delay
	t.pos = L.plunger
	t.in_lane = true
	pending_balls.append(t)

# ================================================================== MAIN LOOP
func _physics_process(delta: float) -> void:
	t_anim += delta
	_update_visuals(delta)
	if paused or state == "idle":
		queue_redraw()
		return
	if state == "won" or state == "lost":
		queue_redraw()
		return
	if hitstop > 0.0:
		hitstop -= delta
		queue_redraw()
		return
	_input_step(delta)
	if state == "bonus":
		_bonus_step(delta)
		queue_redraw()
		return
	game_time += delta
	_timers(delta)
	var dt := delta / SUBSTEPS
	for k in SUBSTEPS:
		_step_flippers(dt)
		for b in balls:
			if not b.dead:
				_step_ball(b, dt)
		if not pending_balls.is_empty():
			balls.append_array(pending_balls)
			pending_balls = []
	_post_step(delta)
	queue_redraw()

func _post_step(delta: float) -> void:
	at_risk_any = false
	var alive := []
	for b in balls:
		if b.dead:
			continue
		alive.append(b)
		if b.at_risk:
			at_risk_any = true
		if b.state == "free":
			b.trail.append(b.pos)
			if b.trail.size() > 10:
				b.trail.pop_front()
	balls = alive
	var live := _live_count()
	multiball_peak = maxi(multiball_peak, live)
	if live >= 3 and not attract:
		if not Run.meta.flags.has("multiball3"):
			Run.meta_flag("multiball3")
	# turn end check
	if state == "play" and _live_count() == 0 and locked.is_empty():
		_end_turn(true)
	elif state == "play" and _live_count() == 0 and not locked.is_empty():
		_release_locked()
	# win check
	if not attract and state == "play" and score >= target:
		_win()

func _live_count() -> int:
	var n := 0
	for b in balls:
		if not b.dead and not b.bee and b.state != "locked":
			n += 1
	return n

# ================================================================== INPUT
func _pressed(key: String) -> bool:
	if autopilot:
		return _ai[key] > 0.0
	return Input.is_action_pressed("flip_" + key)

func _input_step(delta: float) -> void:
	shift_held = Input.is_action_pressed("phase") and not autopilot
	if autopilot:
		_ai_step(delta)
	for key in ["left", "right"]:
		var p := _pressed(key)
		if p and not _prev_press[key]:
			if not tilted and chassis != "bagatelle":
				Sfx.play("flipper", randf_range(0.95, 1.05))
			_on_flip_pressed(key)
		_prev_press[key] = p
	# magnet: both flippers
	if _pressed("left") and _pressed("right") and L.center.get("part", "") == "magnet" and not disabled.has(L.center.sock):
		_try_magnet()
	# plunger
	for b in balls:
		if b.state == "plunger" and not b.dead:
			var hold: bool = Input.is_action_pressed("plunge") if not autopilot else _ai.plunge > 0.0
			if hold:
				plunge_charge = minf(1.0, plunge_charge + delta * 1.1)
			elif plunge_charge > 0.0:
				launch(b, plunge_charge)
				plunge_charge = 0.0
			break
	if not autopilot:
		if Input.is_action_just_pressed("nudge_left"):
			nudge(Vector2(-1, 0))
		if Input.is_action_just_pressed("nudge_right"):
			nudge(Vector2(1, 0))
		if Input.is_action_just_pressed("nudge_up"):
			nudge(Vector2(0, -1))

func _on_flip_pressed(key: String) -> void:
	if L.lanes_sock >= 0 and part(L.lanes_sock) == "lane_change" and not lane_lit.is_empty():
		if key == "left":
			lane_lit.push_back(lane_lit.pop_front())
		else:
			lane_lit.push_front(lane_lit.pop_back())

func nudge(dir: Vector2, forced: bool = false) -> void:
	if state != "play" and state != "serve":
		return
	if not forced:
		if brule("rattle"):
			_popup_at(Vector2(250, 700), "NUDGE LOCKED", UI.MUTED)
			return
		for b in balls:
			if b.primary and b.eng == "anchor" and not b.dead:
				_popup_at(Vector2(250, 700), "ANCHORED", UI.MUTED)
				return
		# magna save uses the nudge keys when a ball sits in that outlane
		for b in balls:
			if b.dead or b.state != "free":
				continue
			var side := "left" if dir.x < 0 else ("right" if dir.x > 0 else "")
			if side != "" and b.in_outlane == side and _magna_available(side):
				magna_used[side] = true
				b.vel = Vector2(90.0 * (1 if side == "left" else -1), -950.0)
				b.kicked = true
				_popup_at(b.pos, "MAGNA-SAVE", UI.PURPLE)
				Sfx.play("ramp", 1.4)
				return
	var strength := 1.0 if not forced else 0.6
	var push := Vector2(dir.x * 190.0, -70.0 if dir.y == 0 else -300.0) * strength
	for b in balls:
		if b.state == "free" and not b.dead:
			b.vel += push
			if b.bang:
				pass
	Sfx.play("nudge", randf_range(0.9, 1.1))
	shake_req.emit(6.0)
	if forced or attract:
		return
	var fill := 30.0 * Run.tilt_factor()
	if feature == "double_tilt":
		fill *= 2.0
	if boss == "wizards_cabinet":
		fill *= 2.0
	tilt += fill
	var sg := Run.fw("seismograph")
	if sg > 0:
		for b in balls:
			if b.shot and not b.dead:
				b.shot.mult += 1.0 * sg * _mult_factor()
		_popup_at(Vector2(250, 650), "+%d Mult" % sg, UI.MULT)
	if steady:
		tilt = minf(tilt, 95.0)
	if tilt >= 100.0 and not tilted:
		_do_tilt()
	elif tilt >= 70.0:
		_dmd("DANGER", UI.RED)

func _magna_available(side: String) -> bool:
	if attract or magna_used.get(side, false):
		return false
	if Run.has_mod("twin_magna"):
		return true
	if Run.has_mod("magna_save"):
		return side == "left"
	return false

func _do_tilt() -> void:
	tilted = true
	Run.stats.tilts += 1
	_dmd("T I L T", UI.RED)
	Sfx.play("tilt")
	shake_req.emit(16.0)
	for b in balls:
		if b.shot:
			b.shot = _new_shot(b)
			b.shot.mult = 0.0

func _try_magnet() -> void:
	if magnet_uses <= 0:
		return
	for b in balls:
		if b.state == "free" and not b.dead and not b.bee and b.pos.y < 780.0:
			magnet_uses -= 1
			b.state = "held"
			b.hold_kind = "magnet"
			b.hold_t = 1.0
			b.eject = Vector2.ZERO
			b.vel = Vector2.ZERO
			_popup_at(b.pos, "MAGNET (%d)" % magnet_uses, UI.PURPLE)
			Sfx.play("scoop", 1.5)
			return

# ================================================================== TIMERS
func _timers(delta: float) -> void:
	if state == "play":
		ball_time += delta
	saver = maxf(0.0, saver - delta)
	tilt = maxf(0.0, tilt - delta * 25.0)
	if skill_t > 0.0 and not Run.has_mod("perfect_plunge"):
		skill_t -= delta
	tesla_cd = maxf(0.0, tesla_cd - delta)
	if drop_reset_t > 0.0:
		drop_reset_t -= delta
		if drop_reset_t <= 0.0:
			_reset_drops()
	# fever
	var fl := 0
	if ball_time >= 45.0:
		fl = int((ball_time - 45.0) / 10.0) + 1
	if fl > fever:
		var add := fl - fever
		fever = fl
		for b in balls:
			if b.shot:
				b.shot.mult += add
		_dmd("FEVER x%d" % fever, UI.ORANGE)
		Sfx.play("fever")
	# playfield doubler
	if L.center.get("part", "") == "playfield_doubler" and not disabled.has(L.center.sock):
		pf_t += delta
		var cyc := fmod(pf_t, 30.0)
		var on := cyc >= 20.0
		if on and not pf_on:
			_dmd("PLAYFIELD x2", UI.JACKPOT)
			Sfx.play("jackpot", 1.2)
		pf_on = on
	if wizard_t > 0.0:
		wizard_t -= delta
		if wizard_t <= 0.0:
			_dmd("WIZARD MODE OVER", UI.PURPLE)
	if twin_pending > 0.0:
		twin_pending -= delta
		if twin_pending <= 0.0:
			var t := Ball.new()
			t.primary = false
			t.shot = _new_shot(t)
			_place_on_plunger(t)
			t.state = "held"
			t.hold_kind = "autolaunch"
			t.hold_t = 0.05
			pending_balls.append(t)
	# wizard's cabinet keeps 3 balls going while the primary is alive
	if boss == "wizards_cabinet" and state == "play":
		var prim_alive := false
		for b in balls:
			if b.primary and not b.dead:
				prim_alive = true
		var n := _live_count() + pending_balls.size()
		if prim_alive and n < 3 and fmod(game_time, 2.0) < delta:
			_spawn_temp_to_plunger(0.1)
	# bosses
	if brule("wind_tunnel"):
		wind_t += delta
		if wind_t >= 8.0:
			wind_t = 0.0
			wind_dir = -wind_dir
			_dmd("WIND SHIFTS", UI.PTS)
	if brule("rattle"):
		rattle_t -= delta
		if rattle_t <= 0.0:
			rattle_t = randf_range(2.5, 5.0)
			nudge(Vector2(DB.pick(Run.rng, [-1.0, 1.0]), 0), true)
	if brule("half_life"):
		for b in balls:
			if b.shot and b.state == "free":
				b.shot.pts *= pow(0.9, delta)
	if boss == "mirror_machine":
		mirror_t -= delta
		if mirror_t <= 0.0:
			mirror_t = 30.0
			_mirror_flip()
	if boss == "endless_ball":
		endless_t -= delta
		if endless_t <= 0.0:
			endless_t = 20.0
			for b in balls:
				if b.shot:
					b.shot.pts *= 0.8
			_dmd("SHOT FADES -20%", UI.MUTED)
		endless_total -= delta
		if endless_total <= 0.0 and state == "play":
			_dmd("THE ENDLESS BALL ENDS", UI.RED)
			for b in balls:
				b.dead = true
			_end_turn(true)
	if boss == "last_call":
		last_call_t -= delta
		if last_call_t <= 0.0 and state == "play":
			_dmd("LAST CALL!", UI.RED)
			for b in balls:
				b.dead = true
			_end_turn(true)
	if rival:
		rival_t -= delta
		if rival_t <= 0.0 and state == "play":
			for b in balls:
				b.dead = true
			_end_turn(true)
	for b in balls:
		if b.dead or b.bee:
			continue
		if b.shot and b.state == "free":
			b.shot.t += delta
			var bc := Run.fw("bagatelle_code") if not attract else 0
			if bc > 0:
				b.shot.mult += 2.0 * bc * delta * _mult_factor()
			if not attract and Run.theme_set("abyss") and b.pos.y < 325.0:
				b.shot.mult += delta * _mult_factor()
		if b.state == "free":
			b.since_return += delta
			if b.since_return > 10.0 and ball_time < 45.0:
				ball_time = 45.0
				_dmd("STUCK BALL -> FEVER", UI.ORANGE)
			if b.eng == "fuse" and b.primary:
				b.fuse_t += delta
				if b.fuse_t >= 60.0:
					_popup_at(b.pos, "FUSE! x4", UI.ORANGE)
					b.shot.xm *= 4.0
					_cash(b, "fuse")
					_end_ball_no_drain(b)
		b.magnet_cd = maxf(0.0, b.magnet_cd - delta)
		# ball search: a ball that sits still for 4s gets a kick (real machines do this)
		if b.state == "free" and b.vel.length() < 25.0:
			b.still_t += delta
			if b.still_t > 4.0:
				b.still_t = 0.0
				if OS.has_environment("TILT_DEBUG"):
					print("BALL SEARCH at ", b.pos)
				b.vel = Vector2(randf_range(-350, 350), randf_range(-700, -300))
				_dmd("BALL SEARCH", UI.MUTED)
		else:
			b.still_t = 0.0
		b.hole_cd = maxf(0.0, b.hole_cd - delta)

func _mirror_flip() -> void:
	_rebuild(true)
	for b in balls:
		b.pos.x = W - b.pos.x
		b.vel.x = -b.vel.x
		b.trail = []
	_dmd("THE MIRROR TURNS", UI.PURPLE)
	shake_req.emit(10.0)

# ================================================================== FLIPPERS
func _step_flippers(dt: float) -> void:
	for f in L.flippers:
		var up := _pressed(f.key) and not tilted
		if stuck_coil and f.key == "left":
			up = true
		var tgt: float = f.up if up else f.rest
		var spd: float = 24.0 if up else 15.0
		if Run.flags.get("curses", []).has("sticky_flippers") and not attract:
			spd *= 0.85
		var diff: float = tgt - f.angle
		var step := clampf(diff, -spd * dt, spd * dt)
		f.angle += step
		f.omega = step / dt
		f.pressed = up

# ================================================================== BALL STEP
func _gravity() -> Vector2:
	var g := BASE_G
	var gx := 0.0
	if not attract:
		if feature == "low_grav":
			g *= 0.7
		if Run.theme_set("space"):
			g *= 0.9
		if Run.flags.get("gravity_leak", false):
			g *= 0.85
		gx = Run.flags.get("crooked_x", 0.0)
	g *= 1.0 + 0.05 * fever
	if brule("slant"):
		gx -= 260.0 * (-1.0 if L.mirror else 1.0)
	return Vector2(gx, g)

func _step_ball(b: Ball, dt: float) -> void:
	match b.state:
		"plunger":
			b.pos = L.plunger
			return
		"locked":
			return
		"held":
			b.hold_t -= dt
			if b.hold_t <= 0.0:
				if b.hold_kind == "autolaunch":
					_place_on_plunger(b)
					launch(b, randf_range(0.55, 0.9))
				else:
					b.state = "free"
					b.vel = b.eject
					b.hole_cd = 0.6
			return
		"ramp":
			_step_ramp(b, dt)
			return
	if b.bee:
		b.life -= dt
		if b.life <= 0.0:
			b.dead = true
			return
	var prev := b.pos
	var g := _gravity()
	if b.mat == "hollow":
		g *= 0.85
	b.vel += g * dt
	if brule("wind_tunnel"):
		b.vel.x += 320.0 * wind_dir * dt
	if brule("high_tide") and b.pos.y > 650.0:
		b.vel *= 1.0 - 1.6 * dt
	if b.mat != "ice":
		b.vel *= 1.0 - 0.06 * dt
	if b.mat == "magnetic":
		var best := 140.0
		var bp := Vector2.ZERO
		for c in L.circles:
			if c.kind == "bumper" and c.on:
				var d: float = b.pos.distance_to(c.c)
				if d < best:
					best = d
					bp = c.c
		if best < 140.0:
			b.vel += (bp - b.pos).normalized() * 700.0 * dt
	if brule("magnet_heart") and b.magnet_cd <= 0.0 and not b.bee:
		var d2: float = b.pos.distance_to(L.magnet_heart)
		if d2 < 90.0:
			b.vel += (L.magnet_heart - b.pos).normalized() * 1400.0 * dt
		if d2 < 16.0:
			b.state = "held"
			b.hold_kind = "heart"
			b.hold_t = 2.0
			b.pos = L.magnet_heart
			b.eject = Vector2(randf_range(-400, 400), randf_range(150, 450))
			b.magnet_cd = 4.0
			ferris_n = 0
			if b.shot:
				b.shot.data.clear()
			_popup_at(b.pos, "COMBO BROKEN", UI.RED)
			Sfx.play("scoop", 0.6)
			return
	var sp := b.vel.length()
	if sp > MAX_SPEED:
		b.vel *= MAX_SPEED / sp
	b.pos += b.vel * dt
	_collide(b, dt)
	_sensors(b, prev, dt)

func _step_ramp(b: Ball, dt: float) -> void:
	var r: Dictionary = L.ramps[b.ramp_sock]
	b.ramp_d += b.ramp_speed * dt
	var path: PackedVector2Array = r.path
	if b.ramp_d >= r.len:
		b.state = "free"
		b.pos = path[path.size() - 1]
		var ev: Vector2 = r.exit_vel
		if part(b.ramp_sock) == "accelerator":
			ev *= 2.2
			b.accel = 1
		b.vel = ev
		b.at_risk = false
		_ramp_complete(b)
		return
	b.pos = _path_point(path, b.ramp_d)

func _path_point(path: PackedVector2Array, d: float) -> Vector2:
	for k in path.size() - 1:
		var sl := path[k].distance_to(path[k + 1])
		if d <= sl:
			return path[k].lerp(path[k + 1], d / sl)
		d -= sl
	return path[path.size() - 1]

# ================================================================== COLLISION
func _collide(b: Ball, dt: float) -> void:
	var rad := b.r
	for s in L.segs:
		if not s.on:
			continue
		var p := b.pos
		if p.x < s.min.x or p.x > s.max.x or p.y < s.min.y or p.y > s.max.y:
			continue
		if s.kind == "gate" and b.in_lane:
			continue
		if s.kind == "oneway" and b.vel.y < 0.0:
			continue
		if s.kind == "target" and _is_phantom(s.tag) and not shift_held:
			continue
		var a: Vector2 = s.a
		var ab: Vector2 = s.b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var cp: Vector2 = a + ab * t
		var d := p - cp
		var d2 := d.length_squared()
		if d2 >= rad * rad or d2 < 0.000001:
			continue
		var dist := sqrt(d2)
		var n := d / dist
		if s.kind == "mouth":
			if b.pos.y < s.a.y:
				continue  # the ball rolls underneath the ramp
			if _try_enter_ramp(b, s):
				return
		b.pos = cp + n * rad
		var vn := b.vel.dot(n)
		if vn < 0.0:
			var e: float = s.e + _rest_bonus(b)
			b.vel -= (1.0 + e) * vn * n
			match s.kind:
				"sling":
					if vn < -60.0:
						b.vel += n * 560.0 * _kick_mult(b)
						_on_sling(b, s)
				"target":
					if vn < -60.0:
						_on_target(b, s)
	for c in L.circles:
		if not c.on:
			continue
		var d: Vector2 = b.pos - c.c
		var rr: float = rad + c.r
		var d2: float = d.length_squared()
		if d2 >= rr * rr or d2 < 0.000001:
			if c.kind == "bumper" and b.ghost_in.has(c.tag):
				b.ghost_in.erase(c.tag)
			continue
		if c.kind == "bumper" and _is_phantom(c.tag) and not shift_held:
			continue
		if c.kind == "bumper" and (b.mat == "ghost" and not b.bee):
			if not b.ghost_in.has(c.tag):
				b.ghost_in[c.tag] = true
				_on_bumper(b, c)
			continue
		var dist: float = sqrt(d2)
		var n: Vector2 = d / dist
		b.pos = c.c + n * rr
		var vn := b.vel.dot(n)
		if vn < 0.0:
			var e: float = c.e + _rest_bonus(b)
			b.vel -= (1.0 + e) * vn * n
			match c.kind:
				"bumper":
					var pid := part(c.tag)
					if pid != "mushroom":
						var kick := 640.0 * _kick_mult(b)
						b.vel += n * maxf(0.0, kick - b.vel.dot(n))
					else:
						b.vel *= 0.55
					_on_bumper(b, c)
				"mimic":
					b.vel += n * 500.0
					c.flash = 1.0
					Sfx.play("bumper", 0.6)
				"wreck":
					_on_wreck(b, c)
				"deadbumper":
					pass
	for fi in L.flippers.size():
		_collide_flipper(b, L.flippers[fi], fi)

func _rest_bonus(b: Ball) -> float:
	match b.mat:
		"rubber": return 0.2
		"lead": return -0.15
	return 0.0

func _kick_mult(b: Ball) -> float:
	var k := 1.0
	if b.mat == "lead":
		k *= 0.75
	if b.mat == "rubber":
		k *= 1.15
	if not attract and Run.fw("overclock") > 0:
		k *= 1.2
	return k

func _is_phantom(si: int) -> bool:
	return si >= 0 and si < socks.size() and socks[si].finish == "phantom"

func _collide_flipper(b: Ball, f: Dictionary, fi: int) -> void:
	var dir := Vector2(cos(f.angle), sin(f.angle))
	var pv: Vector2 = f.pivot
	var ln: float = f.len
	var rel := b.pos - pv
	var t := clampf(rel.dot(dir) / ln, 0.0, 1.0)
	var cp := pv + dir * (t * ln)
	var fr: float = lerpf(f.r0, f.r1, t)
	var d := b.pos - cp
	var rr := b.r + fr
	var d2 := d.length_squared()
	if d2 >= rr * rr or d2 < 0.000001:
		return
	var dist := sqrt(d2)
	var n := d / dist
	b.pos = cp + n * rr
	var arm := cp - pv
	var vc: Vector2 = f.omega * Vector2(-arm.y, arm.x)
	var vrel := b.vel - vc
	var vn := vrel.dot(n)
	if vn < 0.0:
		vrel -= (1.0 + 0.3 + _rest_bonus(b) * 0.5) * vn * n
		b.vel = vc + vrel
	_on_flipper_contact(b, fi, f)

# ================================================================== EVENTS
func _on_flipper_contact(b: Ball, fi: int, f: Dictionary) -> void:
	if b.bee:
		return
	b.no_flip_t = 0.0
	# post pass: slow ball goes from one flipper to the other without going up
	if b.last_flip >= 0 and b.last_flip != fi and game_time - b.last_flip_t < 1.6 and b.max_up_since_flip > 760.0 and b.vel.length() < 700.0 and not b.at_risk:
		if L.flippers[b.last_flip].key != f.key:
			_secret(b, "post_pass")
	if b.last_flip != fi or game_time - b.last_flip_t > 0.3:
		b.max_up_since_flip = b.pos.y
	b.last_flip = fi
	b.last_flip_t = game_time
	if f.pressed and b.vel.length() < 90.0:
		b.cradle_t += 1.0 / 120.0 / SUBSTEPS * 4.0
	if OS.has_environment("TILT_DEBUG") and b.at_risk:
		print("SAVE contact fi=%d pos=%s shot=%s" % [fi, b.pos, b.shot.value() if b.shot else -1.0])
	if b.at_risk:
		b.at_risk = false
		b.since_return = 0.0
		_cash(b, "save")
		if b.haunt_one:
			_end_ball_no_drain(b)

func _on_bumper(b: Ball, c: Dictionary) -> void:
	c.flash = 1.0
	_spark(b.pos, DB.THEME_COLORS.get(DB.PARTS.get(part(c.tag), {"theme": ""}).theme, UI.CREAM), 6)
	Sfx.play("bumper", randf_range(0.9, 1.15))
	if b.bee:
		_hit(b, "", c.tag, c.c, {"pts": 5})
		Sfx.play("bee", 1.0, -6.0)
		return
	if brule("collector") and not attract:
		Run.add_tickets(-1)
	_hit(b, "bumper", c.tag, c.c)
	var pid := part(c.tag)
	if pid == "tesla_coil" and tesla_cd <= 0.0 and not disabled.has(c.tag):
		tesla_cd = 1.0
		for oc in L.circles:
			if oc.kind == "bumper" and oc.tag != c.tag and oc.on:
				oc.flash = 1.0
				_hit(b, "bumper", oc.tag, oc.c)
		_popup_at(c.c + Vector2(0, -30), "ZAP!", UI.PTS)
	if pid == "beehive" and not disabled.has(c.tag):
		_spawn_bee(b, c.c)
	if b.mat == "split" and not b.split_done and b.primary:
		b.split_done = true
		var t := Ball.new()
		t.primary = false
		t.mat = "steel"
		t.shot = _new_shot(t)
		t.pos = b.pos + Vector2(6, 0)
		t.vel = Vector2(-b.vel.x, b.vel.y) + Vector2(80, -80)
		t.state = "free"
		t.in_lane = false
		pending_balls.append(t)
		_popup_at(b.pos, "SPLIT!", UI.GREEN)

func _spawn_bee(b: Ball, at: Vector2) -> void:
	var bee := Ball.new()
	bee.bee = true
	bee.r = 5.0
	bee.life = 1.5
	bee.parent = b
	bee.shot = b.shot
	bee.pos = at + Vector2(randf_range(-30, 30), -30)
	bee.vel = Vector2(randf_range(-500, 500), randf_range(-600, -200))
	bee.in_lane = false
	pending_balls.append(bee)

func _on_sling(b: Ball, s: Dictionary) -> void:
	Sfx.play("sling", randf_range(0.9, 1.1))
	flashes["sling_" + s.side] = 1.0
	if b.bee:
		_hit(b, "", -1, b.pos, {"pts": 5})
		return
	_hit(b, "sling", -1, b.pos)

func _on_wreck(b: Ball, c: Dictionary) -> void:
	if b.bee or disabled.has(c.tag):
		return
	wreck_hits += 1
	c.flash = 1.0
	_hit(b, "", c.tag, c.c, {"pts": 5})
	Sfx.play("target", 1.4)
	if wreck_hits >= 20 and not wreck_broken:
		wreck_broken = true
		c.on = false
		_dmd("WRECKING POST BROKE: x3 ALL GAME", UI.XMULT)
		shake_req.emit(12.0)
		_spark(c.c, UI.XMULT, 20)

func _on_target(b: Ball, s: Dictionary) -> void:
	if b.bee:
		return
	var si: int = s.tag
	var ti: int = s.ti
	var tp := part(si)
	Sfx.play("target", randf_range(0.9, 1.1))
	flashes["t%d" % ti] = 1.0
	match tp:
		"stock_standups":
			_hit(b, "target", si, s.a.lerp(s.b, 0.5))
		"sniper_target":
			_hit(b, "target", si, s.a.lerp(s.b, 0.5), {"xm": 2.0})
		"drop_bank", "vault_bank":
			if drop_down[ti]:
				return
			drop_down[ti] = true
			s.on = false
			_hit(b, "target", si, s.a.lerp(s.b, 0.5))
			if not drop_down.has(false):
				_hit(b, "bank", si, s.a.lerp(s.b, 0.5))
				if tp == "vault_bank":
					_tickets(2, "VAULT +2")
				drop_reset_t = 1.2
		"memory_bank":
			if memory_seq.is_empty():
				return
			if memory_seq[memory_pos] == ti:
				memory_pos += 1
				_hit(b, "target", si, s.a.lerp(s.b, 0.5))
				if memory_pos >= memory_seq.size():
					var xm := 3.0 + Run.memory_bonus
					_hit(b, "bank", si, s.a.lerp(s.b, 0.5), {"xm": xm})
					if not attract:
						Run.memory_bonus += 0.5
					memory_seq.shuffle()
					memory_pos = 0
			else:
				memory_pos = 0
				_hit(b, "target", si, s.a.lerp(s.b, 0.5), {"pts_only": true})
				_popup_at(s.a, "WRONG ORDER", UI.MUTED)
		_:
			_hit(b, "target", si, s.a.lerp(s.b, 0.5))

func _reset_drops() -> void:
	for i in drop_down.size():
		drop_down[i] = false
	for t in L.targets:
		L.segs[t.seg].on = true

func _try_enter_ramp(b: Ball, s: Dictionary) -> bool:
	var si: int = s.tag
	if b.bee or disabled.has(si) or (_is_phantom(si) and not shift_held):
		return false
	var speed := b.vel.length()
	var need := 380.0
	if part(si) == "long_ramp":
		need = 620.0
	if b.vel.y > -150.0 or speed < need or b.pos.y < s.a.y:
		return false
	b.state = "ramp"
	b.ramp_sock = si
	b.ramp_d = 0.0
	b.ramp_speed = clampf(speed * 0.9, 520.0, 1500.0)
	var air_need := 1450.0 if b.mat != "hollow" else 1050.0
	b.ramp_air = speed > air_need
	b.at_risk = false
	Sfx.play("ramp", 1.0 + clampf(speed / 3000.0, 0.0, 0.6))
	return true

func _ramp_complete(b: Ball) -> void:
	var si := b.ramp_sock
	var pid := part(si)
	var opts := {}
	if pid == "long_ramp":
		opts = {"pts": 40, "mult": 3}
	if pid == "ferris_ramp" and not disabled.has(si):
		if game_time - ferris_last <= 6.0:
			ferris_n += 1
		else:
			ferris_n = 1
		ferris_last = game_time
		opts["xm"] = float(ferris_n)
		if ferris_n > 1:
			_popup_at(b.pos + Vector2(0, -40), "FERRIS x%d" % ferris_n, UI.XMULT)
	if pid == "toll_ramp" and not disabled.has(si):
		_tickets(1, "+1 TICKET")
		opts["mult"] = int(maxi(Run.tickets, 0) / 5)
	_hit(b, "ramp", si, b.pos, opts)
	if b.ramp_air:
		_secret(b, "airball")
	flashes["ramp%d" % si] = 1.0
	if pid == "wireform" and not disabled.has(si):
		if b.shot:
			b.shot.mult -= 1.0
		_cash(b, "wireform")

func _sensors(b: Ball, prev: Vector2, dt: float) -> void:
	# ---- plunger lane
	if b.in_lane:
		var lx0: float = L.lane_x0
		var lx1: float = L.lane_x1
		if b.pos.y < 262.0 or b.pos.x < lx0 - 2.0 or b.pos.x > lx1 + 2.0:
			b.in_lane = false
		elif b.pos.y > L.plunger.y - 1.0 and b.vel.length() < 120.0 and not b.bee:
			_place_on_plunger(b)
			return
	# ---- return line: the save / cash-in moment
	if not b.in_lane and not b.bee:
		if prev.y <= RETURN_Y and b.pos.y > RETURN_Y and b.vel.y > 0.0:
			b.at_risk = b.shot != null and (b.shot.pts > 0.0 or b.shot.hits > 0)
			b.since_return = 0.0
		elif b.at_risk and b.pos.y < RETURN_Y - 14.0 and b.vel.y < 0.0:
			b.at_risk = false
		if b.pos.y > RETURN_Y:
			b.since_return = 0.0
		b.max_up_since_flip = minf(b.max_up_since_flip, b.pos.y) if b.last_flip >= 0 else b.max_up_since_flip
		if game_time - b.last_flip_t < 1.6:
			b.max_up_since_flip = minf(b.max_up_since_flip, b.pos.y)
	# patience: bank cradle time when the ball heads back up the table
	if b.cradle_t > 0.0 and b.pos.y < 760.0 and b.shot and not attract:
		var pc := Run.fw("patience")
		if pc > 0:
			var add := minf(10.0, b.cradle_t) * pc
			b.shot.mult += add * _mult_factor()
			if add >= 1.0:
				_popup_at(b.pos, "+%d Mult (Patience)" % int(add), UI.MULT)
		b.cradle_t = 0.0
	if b.bee:
		if b.pos.y > H + 20.0:
			b.dead = true
		return
	# ---- lanes
	for i in L.lanes.size():
		var ln = L.lanes[i]
		var inside: bool = b.pos.distance_to(ln.c) < ln.r
		if inside and not b.lane_in.has(i):
			b.lane_in[i] = true
			_on_lane(b, i)
		elif not inside and b.lane_in.has(i):
			b.lane_in.erase(i)
	# ---- orbit
	var ob = L.orbit_bottom
	var ot = L.orbit_top
	if b.pos.x > ob.x0 and b.pos.x < ob.x1:
		if prev.y >= ob.y and b.pos.y < ob.y and b.vel.y < 0.0:
			b.orbit_t = game_time
		if prev.y >= ot.y and b.pos.y < ot.y and b.vel.y < 0.0 and game_time - b.orbit_t < 2.5:
			b.orbit_t = -10.0
			_on_orbit(b)
	# ---- scoop
	if not L.scoop.is_empty() and b.state == "free" and b.hole_cd <= 0.0:
		if b.pos.distance_to(L.scoop.c) < L.scoop.r and b.vel.length() < 1500.0 and not (_is_phantom(L.scoop.sock) and not shift_held):
			_on_scoop(b)
			return
	# ---- jackpot saucer
	if b.state == "free" and b.hole_cd <= 0.0 and b.pos.distance_to(L.saucer.c) < L.saucer.r and b.vel.length() < 1500.0:
		_on_saucer(b)
		return
	# ---- center pieces
	var cpart: String = L.center.get("part", "")
	if cpart == "spinner" and not disabled.has(L.center.sock):
		var a: Vector2 = L.center.a
		var bb: Vector2 = L.center.b
		if b.pos.x > a.x and b.pos.x < bb.x and ((prev.y - a.y) * (b.pos.y - a.y) < 0.0):
			var spins := int(b.vel.length() / 60.0)
			if b.mat == "ice":
				spins *= 3
			if spins > 0 and not (_is_phantom(L.center.sock) and not shift_held):
				flashes["spinner"] = float(spins)
				_hit(b, "spinner", L.center.sock, a.lerp(bb, 0.5), {"count": spins})
				Sfx.play("tick", 1.2)
	if cpart == "gyro_disc" and not disabled.has(L.center.sock):
		var inside: bool = b.pos.distance_to(L.center.c) < L.center.r
		if inside and not b.gyro_in:
			b.gyro_in = true
			b.vel = b.vel.rotated(deg_to_rad(randf_range(35, 80)) * DB.pick(Run.rng, [-1.0, 1.0]))
			_hit(b, "", L.center.sock, L.center.c, {"xm": 1.25})
			Sfx.play("tick", 0.7)
		elif not inside:
			b.gyro_in = false
	# ---- outlanes
	var d0: float = L.outlane_div[0]
	var d1: float = L.outlane_div[1]
	var side := _outlane_side(b.pos)
	if side != "" and b.in_outlane == "":
		b.kicked = false
	if side == "" and b.in_outlane != "" and b.pos.y < 700.0 and b.vel.y < 0.0:
		if not b.kicked:
			_secret(b, "death_save")
		b.in_outlane = ""
	elif side != "":
		b.in_outlane = side
	elif b.pos.y < 700.0:
		b.in_outlane = ""
	if side != "" and b.pos.y > 895.0:
		var osi: int = L.outlane_socks.get(side, -1)
		if osi >= 0 and part(osi) == "kickback" and kick_charge.get(side, false) and not disabled.has(osi):
			kick_charge[side] = false
			b.vel = Vector2(0, -1500)
			b.kicked = true
			_popup_at(b.pos, "KICKBACK", UI.GREEN)
			Sfx.play("sling", 0.6)
			shake_req.emit(5.0)
	# ---- bang back
	if b.pos.y > 902.0 and b.pos.x > 200.0 and b.pos.x < 335.0 and not L.bagatelle:
		b.bang = true
	elif b.bang and b.pos.y < 865.0:
		b.bang = false
		_secret(b, "bang_back")
	# ---- bagatelle cups
	if L.bagatelle:
		for cup in L.cups:
			if absf(b.pos.x - cup.c.x) < cup.w - 8.0 and b.pos.y > 935.0 and b.pos.y < 968.0:
				_on_cup(b)
				return
	# ---- which way did it leave the flippers? (for outlane-drain Parts)
	if prev.y < 900.0 and b.pos.y >= 900.0:
		b.low_side = _outlane_side(Vector2(b.pos.x, 745.0)) if L.flippers.size() < 2 else _below_side(b.pos.x)
	# ---- drain
	if b.pos.y > H + 12.0:
		_on_drain(b, b.low_side if b.low_side != "" else side)

func _below_side(x: float) -> String:
	var a: float = minf(L.flippers[0].pivot.x, L.flippers[1].pivot.x)
	var c: float = maxf(L.flippers[0].pivot.x, L.flippers[1].pivot.x)
	if x < a - 2.0:
		return "left"
	if x > c + 2.0:
		return "right"
	return ""

func _outlane_side(p: Vector2) -> String:
	if p.y < 740.0:
		return ""
	var d0: float = L.outlane_div[0]
	var d1: float = L.outlane_div[1]
	var lx: float = d0
	var rx: float = d1
	if L.flippers.size() >= 2 and p.y > 790.0:
		lx = maxf(d0, minf(L.flippers[0].pivot.x, L.flippers[1].pivot.x) - 4.0)
		rx = minf(d1, maxf(L.flippers[0].pivot.x, L.flippers[1].pivot.x) + 4.0)
		# under the inlane guides counts as the outlane
		var gl: float = 770.0 + (p.x - d0) * 0.72
		if p.x > d0 and p.x < lx and p.y > gl + 8.0:
			return "left"
		var gr: float = 770.0 + (d1 - p.x) * 0.72
		if p.x < d1 and p.x > rx and p.y > gr + 8.0 and (L.mirror or p.x < L.lane_x0):
			return "right"
	if p.x < d0 and (not L.mirror or p.x > L.lane_x1):
		return "left"
	if p.x > d1 and (L.mirror or p.x < L.lane_x0):
		return "right"
	return ""

func _on_lane(b: Ball, i: int) -> void:
	if disabled.has(L.lanes_sock):
		return
	Sfx.play("lane", 1.0 + i * 0.08)
	var lp := part(L.lanes_sock)
	var skilled := false
	if skill_lane >= 0 and skill_t > 0.0 and b.primary:
		if i == skill_lane:
			skilled = true
		if skilled or not Run.has_mod("perfect_plunge"):
			skill_t = 0.0
	if skilled:
		var bonus := 3.0
		if not attract and Run.theme_set("west"):
			bonus *= 2.0
		b.shot.mult += bonus * _mult_factor()
		_dmd("SKILL SHOT +%d MULT" % int(bonus), UI.JACKPOT)
		Sfx.play("secret", 1.3)
		skill_lane = -1
	var opts := {}
	if feature == "lanes_mult":
		opts["mult"] = 3
	if lp == "toll_lanes" and not toll_lanes_paid.has(i):
		toll_lanes_paid[i] = true
		_tickets(1, "+1 TICKET")
	_hit(b, "rollover", L.lanes_sock, L.lanes[i].c, opts)
	if lane_lit[i]:
		return
	lane_lit[i] = true
	if b.shot:
		b.shot.data["lanes_" + str(i)] = true
	if not lane_lit.has(false):
		_lanes_complete(b, lp)

func _lanes_complete(b: Ball, lp: String) -> void:
	for k in lane_lit.size():
		lane_lit[k] = false
	kick_charge = {"left": true, "right": true}
	match lp:
		"stock_lanes", "the_wizard":
			bonus_x += 1
			_dmd("BONUS %dX" % bonus_x, UI.GREEN)
		"lane_change":
			b.shot.mult += 5.0 * _mult_factor()
			_popup_at(Vector2(350, 170), "+5 Mult", UI.MULT)
		"luck_lanes":
			var all_this_shot := true
			for k in L.lanes.size():
				if not b.shot.data.has("lanes_" + str(k)):
					all_this_shot = false
			if all_this_shot:
				b.shot.xm *= 2.0
				_dmd("L-U-C-K x2", UI.GREEN)
			else:
				_dmd("L-U-C-K", UI.GREEN)
		"hourglass_lanes":
			if ball_time > 35.0 and ball_time < 45.0:
				ball_time = 45.0
				_dmd("INTO THE FEVER", UI.ORANGE)
			else:
				ball_time = 0.0
				fever = 0
				_dmd("FEVER TIMER RESET", UI.PTS)
		"toll_lanes":
			pass
	Sfx.play("secret", 1.0)

func _on_orbit(b: Ball) -> void:
	var si: int = L.orbit_sock
	if si < 0 or part(si) == "" or disabled.has(si):
		return
	if _is_phantom(si) and not shift_held:
		return
	var pid := part(si)
	flashes["orbit"] = 1.0
	Sfx.play("ramp", 1.3)
	var n: int = b.shot.data.get("orbits", 0) + 1 if b.shot else 1
	if b.shot:
		b.shot.data["orbits"] = n
	var opts := {}
	if pid == "centrifuge" and n > 1:
		var lv := DB.shot_value("orbit", levels.get("orbit", 1))
		opts["mult"] = lv.mult * (pow(2.0, n - 1) - 1.0)
		_popup_at(b.pos + Vector2(20, 0), "CENTRIFUGE x%d" % int(pow(2, n - 1)), UI.MULT)
	_hit(b, "orbit", si, b.pos, opts)
	if pid == "wormhole_loop":
		_place_on_plunger(b)
		skill_lane = randi() % maxi(L.lanes.size(), 1) if L.lanes.size() > 0 else -1
		skill_t = 5.0
		b.launched_t = game_time
		_popup_at(L.plunger + Vector2(-40, -40), "WORMHOLE", UI.PURPLE)
		if autopilot:
			_ai.plunge = 0.0

func _on_scoop(b: Ball) -> void:
	var si: int = L.scoop.sock
	var pid := part(si)
	if disabled.has(si):
		b.vel = L.scoop.eject
		b.hole_cd = 0.6
		return
	b.pos = L.scoop.c
	b.vel = Vector2.ZERO
	Sfx.play("scoop")
	flashes["scoop"] = 1.0
	match pid:
		"hungry_hole":
			_hit(b, "scoop", si, b.pos)
			if b.shot:
				b.shot.xm *= 3.0
			_popup_at(b.pos, "HUNGRY x3", UI.XMULT)
			_cash(b, "hungry")
			_end_ball_no_drain(b)
			return
		"mystery_scoop":
			_hit(b, "scoop", si, b.pos)
			_mystery(b)
		"ball_lock", "birdcage":
			_hit(b, "scoop", si, b.pos)
			if locked.is_empty() and not b.bee:
				b.state = "locked"
				locked.append(b)
				_dmd("BALL LOCKED", UI.TICKET)
				Sfx.play("jackpot", 0.8)
				var t := Ball.new()
				t.primary = false
				t.shot = _new_shot(t)
				_place_on_plunger(t)
				pending_balls.append(t)
				if autopilot:
					_ai.plunge = 0.0
				return
			else:
				_start_multiball(b)
				return
		_:
			_hit(b, "scoop", si, b.pos)
	b.state = "held"
	b.hold_kind = "scoop"
	b.hold_t = 1.0
	b.eject = L.scoop.eject

func _start_multiball(b: Ball) -> void:
	_dmd("M U L T I B A L L", UI.JACKPOT)
	Sfx.play("jackpot")
	shake_req.emit(10.0)
	var shared: Shot = null
	if has_part("birdcage"):
		shared = b.shot
	for lb in locked:
		lb.state = "held"
		lb.hold_kind = "scoop"
		lb.hold_t = 0.2
		lb.eject = L.scoop.eject.rotated(-0.3)
		lb.pos = L.scoop.c
		if shared:
			lb.shot = shared
	locked = []
	b.state = "held"
	b.hold_kind = "scoop"
	b.hold_t = 0.6
	b.eject = L.scoop.eject
	var t := Ball.new()
	t.primary = false
	t.shot = shared if shared else _new_shot(t)
	_place_on_plunger(t)
	t.state = "held"
	t.hold_kind = "autolaunch"
	t.hold_t = 0.3
	pending_balls.append(t)

func _release_locked() -> void:
	for lb in locked:
		lb.state = "held"
		lb.hold_kind = "scoop"
		lb.hold_t = 0.4
		lb.eject = L.scoop.eject
		lb.pos = L.scoop.c
	locked = []
	_dmd("LOCK RELEASED", UI.TICKET)

func _mystery(b: Ball) -> void:
	var roll := randi() % 6
	match roll:
		0:
			_tickets(3, "MYSTERY: +3 TICKETS")
		1:
			if b.shot:
				b.shot.mult += 5.0
			_dmd("MYSTERY: +5 MULT", UI.MULT)
		2:
			if not attract and Run.give_consumable("tool", DB.pick(Run.rng, DB.TOOLS.keys())):
				_dmd("MYSTERY: A TOOL", UI.PURPLE)
			else:
				_dmd("MYSTERY: NOTHING", UI.MUTED)
		3:
			for i in socks.size():
				lamps[i] = true
			_dmd("MYSTERY: ALL LAMPS LIT", UI.TICKET)
		4:
			bonus_x += 2
			_dmd("MYSTERY: +2 BONUS X", UI.GREEN)
		5:
			_dmd("MYSTERY: NOTHING", UI.MUTED)

func _on_saucer(b: Ball) -> void:
	b.pos = L.saucer.c
	b.vel = Vector2.ZERO
	b.state = "held"
	b.hold_kind = "saucer"
	b.hold_t = 0.8
	b.eject = L.saucer.eject
	flashes["saucer"] = 1.0
	Sfx.play("scoop", 1.2)
	_hit(b, "scoop", -1, b.pos)
	if _live_count() >= 2:
		_secret(b, "super_jackpot")
	if not attract and Run.jackpot > 0:
		var j := Run.jackpot
		Run.jackpot = 0
		Run.add_tickets(j)
		_dmd("JACKPOT! +%d TICKETS" % j, UI.JACKPOT)
		Sfx.play("jackpot")
		shake_req.emit(10.0)
		_spark(b.pos, UI.JACKPOT, 24)

func _on_cup(b: Ball) -> void:
	if b.shot:
		_cash(b, "cup")
	_popup_at(b.pos, "CUP!", UI.GREEN)
	Sfx.play("lane")
	if b.primary:
		_place_on_plunger(b)
		if autopilot:
			_ai.plunge = 0.0
	else:
		b.dead = true

func _secret(b: Ball, s: String) -> void:
	if attract or b.bee:
		return
	var first := Run.discover_secret(s)
	_hit(b, s, -1, b.pos)
	if first:
		_dmd("SECRET SHOT FOUND: %s!" % DB.SHOTS[s].name.to_upper(), UI.JACKPOT)
	else:
		_dmd(DB.SHOTS[s].name.to_upper() + "!", UI.JACKPOT)
	Sfx.play("secret")
	shake_req.emit(8.0)

# ================================================================== SCORING
func _mult_factor() -> float:
	var f := 1.0
	if brule("flatline"):
		f *= 0.5
	if not attract and Run.fw("overclock") > 0:
		f *= 1.5
	return f

func _new_shot(b: Ball) -> Shot:
	var s := Shot.new()
	s.mult = 1.0 + fever
	if not attract and b.primary and ball_no == 0 and Run.fw("rack_tactician") > 0:
		s.mult += 5.0 * Run.fw("rack_tactician")
	if last_rites_carry > 0.0 and b.primary:
		s.pts += last_rites_carry
		last_rites_carry = 0.0
	return s

func _part_factor(si: int) -> float:
	if si < 0 or attract:
		return 1.0
	var s = socks[si]
	var f: float = s.upgrade * (1.0 - s.wear)
	if chassis == "minimalist" and s.part != "" and DB.PARTS[s.part].rarity != "S":
		f *= 2.0
	return f

func _hit(b: Ball, type: String, si: int = -1, pos: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> void:
	if b == null or tilted:
		return
	var shot: Shot = b.shot
	if b.bee and b.parent:
		shot = b.parent.shot
	if shot == null:
		return
	if si >= 0 and (disabled.has(si) or disabled_ball.has(si)):
		return
	var pid := part(si)
	if brule("rust") and si >= 0 and not b.rusted and b.primary and pid != "" and DB.PARTS[pid].rarity != "S":
		b.rusted = true
		disabled_ball[si] = true
		_popup_at(pos, "RUSTED", UI.MUTED)
		return
	var p := 0.0
	var m := 0.0
	var x := 1.0
	if type != "":
		var lv := DB.shot_value(type, levels.get(type, 1))
		p = lv.pts
		m = lv.mult
		x = lv.xm
	p += opts.get("pts", 0.0)
	m += opts.get("mult", 0.0)
	x *= opts.get("xm", 1.0)
	var count: int = opts.get("count", 1)
	if opts.get("pts_only", false):
		m = 0.0
		x = 1.0
	# feature rules
	if feature == "targets_double" and (type == "target" or type == "bank"):
		p *= 2.0
		m *= 2.0
	if feature == "ramps_mult" and type == "ramp":
		x *= 1.5
	# part effects
	var pf := _part_factor(si)
	var repeat := 1
	if si >= 0 and pid != "":
		match pid:
			"stock_bumper": p += 5
			"pop_bumper": p += 12
			"mushroom": p += 25
			"loan_shark":
				if attract or Run.tickets > Run.min_tickets():
					if not attract:
						Run.add_tickets(-1)
					m += 2
				else:
					p = 0
					m = 0
			"hot_bumper":
				var hc: int = shot.data.get("hot", 0) + 1
				shot.data["hot"] = hc
				m += hc
			"twin_pop":
				var best: float = shot.data.get("best_bumper", 0.0)
				if best > 0.0:
					p = best
				else:
					p *= 2.0
			"jitterbug": x *= 1.5
			"stock_standups": p += 10
		if type == "bumper":
			p += (0 if attract else Run.graveyard_bonus)
		p *= pf
		m *= pf
		if x != 1.0:
			x = 1.0 + (x - 1.0) * pf
		var fin: String = socks[si].finish
		match fin:
			"chrome": p += 30
			"neon": m += 4
			"holo": x *= 1.5
			"gold":
				if gold_paid < 5:
					gold_paid += 1
					_tickets(1, "")
		if b.mat == "ember" and not attract:
			burned[si] = true
		if burned.has(si):
			repeat = 2
		lamps[si] = true
		if not wizard_done and has_part("the_wizard") and _all_lamps_lit():
			_start_wizard(b)
	if type == "bumper" and pid != "twin_pop":
		shot.data["best_bumper"] = maxf(shot.data.get("best_bumper", 0.0), p)
	# ball materials
	if type == "bumper" and b.mat == "rubber":
		p *= 1.5
	if type == "ramp" and b.mat == "lead":
		m += 4
	if b.accel > 0 and si >= 0 and type != "ramp":
		b.accel = 0
		repeat *= 2
		_popup_at(pos + Vector2(0, -24), "ACCEL x2", UI.XMULT)
	# boss: taxman
	if brule("taxman") and type != taxman_type and type != "":
		p = 0.0
	m *= _mult_factor()
	p *= count
	m *= count
	for k in repeat:
		shot.pts += p
		shot.mult += m
		shot.xm *= x
	shot.hits += 1
	if type != "":
		shot_counts[type] = shot_counts.get(type, 0) + 1
	# glass / shatter
	if b.primary and not b.bee and si >= 0:
		b.hits += 1
		var limit := 30
		if b.mat == "glass" and not attract and Run.fw("glass_jaw") > 0:
			limit = 45
		if (b.mat == "glass" or brule("shatter")) and b.hits >= limit:
			_shatter(b)
	# popups + feed
	var label := ""
	if p > 0.0:
		label = "+" + UI.fmt_short(p * repeat)
		_popup_at(pos, label, UI.PTS)
	if m > 0.0:
		_popup_at(pos + Vector2(0, 18), "+%s Mult" % UI.fmt_short(m * repeat), UI.MULT)
	if x > 1.001:
		_popup_at(pos + Vector2(0, 36), "x%s" % UI.fmt_short(x), UI.XMULT)
	if si >= 0 and pid != "" and DB.PARTS[pid].rarity != "S":
		feed.emit(DB.PARTS[pid].name, DB.RARITY_COLORS[DB.PARTS[pid].rarity])
	elif type != "":
		feed.emit(DB.SHOTS[type].name, UI.MUTED)

func _all_lamps_lit() -> bool:
	if L.lamps.is_empty():
		return false
	for si in L.lamps:
		if not lamps.has(si):
			return false
	return true

func _start_wizard(b: Ball) -> void:
	wizard_done = true
	wizard_t = 20.0
	_dmd("W I Z A R D   M O D E", UI.PURPLE)
	Sfx.play("jackpot", 0.9)
	shake_req.emit(14.0)
	for k in 2:
		_spawn_temp_to_plunger(0.3 + 0.4 * k)

func _shatter(b: Ball) -> void:
	_popup_at(b.pos, "SHATTERED!", UI.PTS)
	Sfx.play("shatter")
	_spark(b.pos, DB.BALLS.glass.color, 30)
	shake_req.emit(10.0)
	if b.mat == "glass" and b.rack_idx >= 0 and not destroyed.has(b.rack_idx):
		destroyed.append(b.rack_idx)
	b.shot = null
	b.dead = true
	if _live_count() == 0 and locked.is_empty():
		_end_turn(true, true)

func _cash(b: Ball, reason: String) -> void:
	var shot: Shot = b.shot
	if shot == null:
		return
	if shot.hits == 0 and shot.pts <= 0.0:
		return
	if tilted:
		return
	if reason == "save" and has_part("let_it_ride") and not disabled.has(sock_of_part("let_it_ride")):
		shot.saves += 1
		if shot.saves % 3 != 0:
			_popup_at(b.pos + Vector2(0, -30), "LET IT RIDE %d/3" % shot.saves, UI.TICKET)
			return
		shot.xm *= 5.0
	var pts := shot.pts
	var mult := shot.mult
	var xm := shot.xm
	if not attract:
		var sb := Run.fw("stockbroker")
		if sb > 0:
			mult += int(maxi(Run.tickets, 0) / 5) * sb * _mult_factor()
		var de := Run.fw("debt_engine")
		if de > 0 and Run.tickets < 0:
			mult += -Run.tickets * de * _mult_factor()
		var ll := Run.fw("lamp_lighter")
		if ll > 0:
			pts += 5.0 * lamps.size() * ll
		if b.mat == "glass":
			xm *= 3.0 if Run.fw("glass_jaw") > 0 else 2.0
		var dd := Run.fw("double_down")
		if dd > 0 and ball_no == balls_total - 1:
			xm *= pow(2.0, dd)
		var sr := Run.fw("speedrunner")
		if sr > 0 and shot.t < 3.0:
			xm *= pow(1.5, sr)
		var mr := Run.fw("marathon")
		if mr > 0 and shot.t >= 10.0:
			xm *= pow(2.0, mr)
		var ce := Run.fw("collectors_edition")
		if ce > 0:
			xm *= pow(1.0 + 0.5 * Run.theme_counts().size(), ce)
		if b.eng == "lucky" and randf() < 0.2:
			xm *= 2.0
			_popup_at(b.pos + Vector2(0, -50), "LUCKY x2", UI.GREEN)
		if stuck_coil:
			xm *= 3.0
		if chassis == "bagatelle":
			xm *= 3.0
		if boss == "last_call":
			xm *= 3.0
		if b.mat == "gold":
			_tickets(1, "")
		if Run.theme_set("carnival") and carnival_paid < 5:
			carnival_paid += 1
			_tickets(1, "")
	if pf_on:
		xm *= 2.0
	if wreck_broken:
		xm *= 3.0
	if wizard_t > 0.0:
		xm *= 3.0
	var v := maxf(pts, 0.0) * maxf(mult, 0.0) * maxf(xm, 0.0)
	score += v
	game_stats.cashes += 1
	game_stats.best_shot = maxf(game_stats.best_shot, v)
	if not attract:
		Run.stats.cashes += 1
		Run.stats.best_shot = maxf(Run.stats.best_shot, v)
	cashed.emit(v, pts, mult, xm)
	var big := v >= target * 0.25 and not attract
	var col := UI.TICKET if big else UI.CREAM
	_popup_at(b.pos + Vector2(0, -20), UI.fmt(v), col, 30 if big else 22, 1.4)
	Sfx.play("big_cash" if big else "cash", clampf(0.9 + log(maxf(v, 1.0)) / 40.0, 0.9, 1.6))
	hitstop = clampf(0.04 + (v / maxf(target, 1.0)) * 0.5, 0.04, 0.45) if not attract else 0.0
	shake_req.emit(clampf(3.0 + v / maxf(target, 1.0) * 30.0, 3.0, 18.0))
	_spark(b.pos, col, 10 + int(clampf(v / maxf(target, 1.0) * 40.0, 0, 30)))
	# reset shot (shared for birdcage balls)
	var ns := _new_shot(b)
	for ob in balls:
		if ob.shot == shot:
			ob.shot = ns
	b.shot = ns

# ================================================================== DRAIN / TURN
func _on_drain(b: Ball, side: String) -> void:
	if b.bee:
		b.dead = true
		return
	b.at_risk = false
	if attract:
		b.dead = true
		if b.primary:
			serve()
		return
	if tilted:
		b.dead = true
		return
	if side != "":
		var osi: int = L.outlane_socks.get(side, -1)
		if osi >= 0 and part(osi) == "toll_gate" and not disabled.has(osi):
			_tickets(3, "TOLL GATE +3")
	if not b.primary:
		b.dead = true
		_popup_at(Vector2(b.pos.x, H - 40), "BALL LOST", UI.MUTED)
		return
	# saves
	if saver > 0.0:
		_dmd("BALL SAVED", UI.GREEN)
		b.shot = _new_shot(b)
		_place_on_plunger(b)
		saver = 0.0
		Sfx.play("coin")
		if autopilot:
			_ai.plunge = 0.0
		return
	if boss == "endless_ball":
		_dmd("THE BALL RETURNS", UI.PURPLE)
		b.shot = _new_shot(b)
		_place_on_plunger(b)
		if autopilot:
			_ai.plunge = 0.0
		return
	if has_part("gutter_angel") and not angel_used and not disabled.has(sock_of_part("gutter_angel")):
		angel_used = true
		_dmd("GUTTER ANGEL: SHOT SAVED", UI.PURPLE)
		_place_on_plunger(b)
		Sfx.play("secret", 0.8)
		if autopilot:
			_ai.plunge = 0.0
		return
	if b.eng == "phoenix" and not Run.flags.get("phoenix_used", {}).has(b.rack_idx):
		if not Run.flags.has("phoenix_used"):
			Run.flags.phoenix_used = {}
		Run.flags.phoenix_used[b.rack_idx] = true
		_dmd("PHOENIX RISES", UI.ORANGE)
		b.shot = _new_shot(b)
		_place_on_plunger(b)
		if autopilot:
			_ai.plunge = 0.0
		return
	if Run.theme_set("haunted") and not haunt_used:
		haunt_used = true
		_dmd("A GHOST BALL RETURNS", UI.PURPLE)
		b.mat = "ghost"
		b.haunt_one = true
		b.shot = _new_shot(b)
		_place_on_plunger(b)
		if autopilot:
			_ai.plunge = 0.0
		return
	# a real drain
	if OS.has_environment("TILT_DEBUG"):
		var tr := []
		for q in b.trail:
			tr.append("(%d,%d)" % [int(q.x), int(q.y)])
		print("DRAIN side=%s pos=%s vel=%s trail=%s" % [side, b.pos, b.vel, " ".join(tr)])
	drain_log.append("%s@%d,%d" % [side if side != "" else "center", int(b.pos.x), int(game_time)])
	if b.shot and b.shot.value() > 0.0:
		_popup_at(Vector2(clampf(b.pos.x, 60, 440), H - 60), "SHOT LOST", UI.RED, 24)
		if Run.fw("last_rites") > 0:
			last_rites_carry = b.shot.value() * 0.5 / maxf(1.0, 1.0 + fever)
	Run.stats.drains += 1
	Run.last_drained = {"mat": b.mat, "eng": b.eng}
	if has_part("graveyard"):
		Run.graveyard_bonus += 1
	b.dead = true
	Sfx.play("drain")
	shake_req.emit(6.0)
	if _live_count() == 0 and locked.is_empty():
		_end_turn(true)

func _end_ball_no_drain(b: Ball) -> void:
	b.dead = true
	if b.primary and b.eng == "charm" and not attract:
		_tickets(2, "CHARM +2")
	if _live_count() == 0 and locked.is_empty():
		_end_turn(false)

func _end_turn(drained: bool, shattered: bool = false) -> void:
	if state != "play" and state != "serve":
		return
	for b in balls:
		b.dead = true
	if attract:
		serve()
		return
	# end-of-ball bonus
	var lit := lamps.size()
	var per := maxf(10.0, round(target * 0.012))
	var bx := bonus_x
	var hunter := Run.fw("bonus_hunter")
	var total := 0.0 if tilted else lit * per * bx * pow(3.0, hunter)
	bonus_show = {"lit": lit, "per": per, "x": bx, "hunter": hunter, "total": total, "t": 0.0, "tilted": tilted, "drained": drained}
	state = "bonus"
	if Run.has_mod("lamp_memory_plus"):
		Run.lamps_memory = lamps.duplicate()

func _bonus_step(delta: float) -> void:
	bonus_show.t += delta
	var dur := 1.6 if bonus_show.total > 0 else 0.7
	if autopilot:
		dur *= 0.3
	if bonus_show.t >= dur:
		score += bonus_show.total
		if bonus_show.total > 0:
			cashed.emit(bonus_show.total, bonus_show.total, 1, 1)
			Sfx.play("cash", 0.8)
		bonus_show = {}
		if not attract and score >= target:
			_win()
			return
		ball_no += 1
		state = "play"
		if ball_no >= balls_total or boss == "last_call" or rival:
			_lose()
		else:
			serve()

func _win() -> void:
	if result_sent:
		return
	state = "won"
	result_sent = true
	for b in balls:
		b.dead = true
	Sfx.play("win")
	_dmd("TARGET REACHED!", UI.GREEN)
	shake_req.emit(12.0)
	var odds := 0.1
	if has_part("luck_lanes"):
		odds = 0.18
	if Run.fw("match_maker") > 0:
		odds = maxf(odds, 0.25) + (0.07 if has_part("luck_lanes") else 0.0)
	var matched := randf() < odds
	if chassis == "bagatelle" and Run.fw("bagatelle_code") > 0:
		Run.meta_flag("bagatelle_win")
	var res := _result(true)
	res["match"] = matched
	res["match_digit"] = int(floor(score / 10.0)) % 10
	await get_tree().create_timer(1.1).timeout
	ended.emit(res)

func _lose() -> void:
	if result_sent:
		return
	state = "lost"
	result_sent = true
	Sfx.play("lose")
	_dmd("GAME OVER", UI.RED)
	var res := _result(false)
	await get_tree().create_timer(1.1).timeout
	ended.emit(res)

func _result(won: bool) -> Dictionary:
	var used := mini(ball_no + 1, balls_total)
	return {
		"won": won, "score": score, "target": target, "balls_used": used, "balls_total": balls_total,
		"burned": burned.keys(), "shot_counts": shot_counts, "destroyed_balls": destroyed.duplicate(),
		"match": false, "best_shot": game_stats.best_shot, "rival": rival, "cashes": game_stats.cashes,
		"drain_log": drain_log.duplicate(),
	}

func _tickets(n: int, msg: String) -> void:
	if attract:
		return
	Run.add_tickets(n)
	Sfx.play("coin", randf_range(0.95, 1.1), -4.0)
	if msg != "":
		_popup_at(Vector2(250, 620), msg, UI.TICKET)

# ================================================================== FOCUS / HUD HELPERS
func focus_ball() -> Ball:
	var best: Ball = null
	for b in balls:
		if b.dead or b.bee or b.shot == null:
			continue
		if best == null or b.shot.value() > best.shot.value():
			best = b
	return best

func balls_left() -> int:
	return maxi(0, balls_total - ball_no - (1 if state == "play" or state == "serve" or state == "bonus" else 0))

# ================================================================== AUTOPILOT
func _ai_step(delta: float) -> void:
	for k in ["left", "right"]:
		_ai[k] = maxf(0.0, _ai[k] - delta)
		_ai["cd_" + k] = maxf(0.0, _ai["cd_" + k] - delta)
	for b in balls:
		if b.dead or b.state != "free" or b.bee:
			continue
		if b.pos.y > 770.0 and b.pos.y < 900.0 and b.vel.y > -120.0:
			var mid := W * 0.5 - 17.5
			var key := "left" if b.pos.x < mid else "right"
			if L.mirror:
				key = "left" if b.pos.x < W * 0.5 + 17.5 else "right"
			# a slow ball near the flipper tip is the moment to shoot; otherwise react late-ish
			var ready: bool = b.vel.length() < 150.0 or b.pos.y > 815.0
			if ready and _ai["cd_" + key] <= 0.0 and randf() < 0.9:
				_ai[key] = 0.2
				_ai["cd_" + key] = 0.45
	for b in balls:
		if b.state == "plunger" and not b.dead:
			if _ai.plunge <= 0.0:
				_ai.plunge = 0.01
				_ai.charge = randf_range(0.45, 1.0)
			if plunge_charge < _ai.charge:
				_ai.plunge = 1.0
			else:
				_ai.plunge = 0.0
				_ai.charge = 0.0
	if randf() < delta * 0.15 and state == "play" and not attract:
		nudge(Vector2(DB.pick(Run.rng, [-1.0, 1.0]), 0))

# ================================================================== VISUALS
func _update_visuals(delta: float) -> void:
	for p in popups:
		p.t += delta
		p.pos.y -= delta * 40.0
	popups = popups.filter(func(p): return p.t < p.life)
	for p in particles:
		p.t += delta
		p.pos += p.vel * delta
		p.vel *= 1.0 - 3.0 * delta
	particles = particles.filter(func(p): return p.t < p.life)
	for k in flashes.keys():
		flashes[k] = maxf(0.0, flashes[k] - delta * 3.0)
	if L.has("circles"):
		for c in L.circles:
			c.flash = maxf(0.0, c.flash - delta * 4.0)
		# jitterbug wander
		for si in L.bumpers:
			if part(si) == "jitterbug":
				var home: Vector2 = L.bumpers[si].home
				var np := home + Vector2(cos(t_anim * 1.7 + si), sin(t_anim * 2.3 + si)) * 16.0
				L.bumpers[si].c = np
				for c in L.circles:
					if c.kind == "bumper" and c.tag == si:
						c.c = np
	# mask overlays
	var showmask := brule("blackout") or brule("fog")
	mask_rect.visible = showmask
	if showmask:
		var m: ShaderMaterial = mask_rect.material
		m.set_shader_parameter("mode", 0 if brule("blackout") else 1)
		var pts := []
		for b in balls:
			if not b.dead and not b.bee and pts.size() < 6:
				pts.append(b.pos)
		while pts.size() < 6:
			pts.append(Vector2(-999, -999))
		m.set_shader_parameter("lights", PackedVector2Array(pts))
		m.set_shader_parameter("light_count", 6)
		m.set_shader_parameter("radius", 110.0)

func _popup_at(pos: Vector2, text: String, col: Color, size: int = 16, life: float = 0.9) -> void:
	if popups.size() > 60:
		popups.pop_front()
	popups.append({"pos": pos + Vector2(randf_range(-6, 6), 0), "text": text, "col": col, "t": 0.0, "life": life, "size": size})

func _spark(pos: Vector2, col: Color, n: int) -> void:
	if particles.size() > 300:
		return
	for i in n:
		var a := randf() * TAU
		var s := randf_range(80, 360)
		particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * s, "t": 0.0, "life": randf_range(0.25, 0.6), "col": col})

func _dmd(text: String, col: Color) -> void:
	dmd.emit(text, col)

# ---------------------------------------------------------------- DRAW
func _draw() -> void:
	if L.is_empty():
		return
	_draw_playfield()
	_draw_ramps_under()
	_draw_lanes_and_lamps()
	_draw_parts()
	_draw_walls()
	_draw_flippers()
	_draw_return_line()
	for b in balls:
		if not b.dead and b.state != "ramp":
			_draw_ball(b)
	_draw_ramps_over()
	for b in balls:
		if not b.dead and b.state == "ramp":
			_draw_ball(b, 1.25)
	_draw_plunger()
	_draw_boss_fx()
	for p in particles:
		var a: float = 1.0 - p.t / p.life
		var c: Color = p.col
		c.a = a
		draw_rect(Rect2(p.pos - Vector2(2, 2), Vector2(4, 4)), c)
	for p in popups:
		var a2: float = clampf(1.0 - (p.t / p.life) * (p.t / p.life), 0.0, 1.0)
		var c2: Color = p.col
		c2.a = a2
		var sz: int = p.size
		var tw := font_head.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var pos: Vector2 = p.pos - Vector2(tw * 0.5, 0)
		draw_string_outline(font_head, pos, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 5, Color(0.04, 0.02, 0.08, a2))
		draw_string(font_head, pos, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c2)
	if tilted:
		var blink := int(t_anim * 4.0) % 2 == 0
		if blink:
			_center_text(Vector2(W * 0.5, 480), "TILT", 90, UI.RED)
	if state == "bonus" and not bonus_show.is_empty():
		_draw_bonus()
	if state == "serve" and not attract:
		_center_text(Vector2(W * 0.5, 560), "HOLD  SPACE  TO  PLUNGE", 16, Color(1, 1, 1, 0.5 + 0.3 * sin(t_anim * 4.0)))

func _center_text(c: Vector2, txt: String, size: int, col: Color, f: Font = null) -> void:
	if f == null:
		f = font_head
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(f, c - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, UI.EDGE)
	draw_string(f, c - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw_playfield() -> void:
	# cabinet body
	draw_style_box(UI.style(Color("0d0918"), 26), Rect2(Vector2(-14, -14), Vector2(W + 28, H + 28)))
	var body := UI.style(Color("2b1f44"), 24)
	body.border_color = Color("47346e")
	body.border_width_left = 4
	body.border_width_right = 4
	body.border_width_top = 4
	body.border_width_bottom = 4
	draw_style_box(body, Rect2(Vector2(-10, -10), Vector2(W + 20, H + 20)))
	# playfield gradient
	var top := Color("1c2446")
	var bot := Color("2c1638")
	if fever > 0:
		top = top.lerp(Color("4a1c1c"), clampf(fever * 0.2, 0.0, 0.7))
	var steps := 24
	for i in steps:
		var y0 := H * i / steps
		draw_rect(Rect2(Vector2(0, y0), Vector2(W, H / steps + 1)), top.lerp(bot, float(i) / steps))
	# art: faint rings + rays
	var cc := Vector2(250, 470)
	for i in 7:
		draw_arc(cc, 60.0 + i * 55.0, 0, TAU, 64, Color(1, 1, 1, 0.025 + 0.01 * (i % 2)), 10)
	for i in 16:
		var a := i * TAU / 16.0 + t_anim * 0.05
		draw_line(cc, cc + Vector2(cos(a), sin(a)) * 520.0, Color(1, 1, 1, 0.018), 18)
	# center logo
	var logo := "TILT"
	_center_text(cc + Vector2(0, 30), logo, 70, Color(1, 1, 1, 0.05), font_head)
	# plunger lane darker
	draw_rect(Rect2(Vector2(L.lane_x0, 300), Vector2(L.lane_x1 - L.lane_x0, H - 300)), Color(0, 0, 0, 0.25))
	# drain gap glow
	draw_rect(Rect2(Vector2(160, H - 10), Vector2(180, 10)), Color(1, 0.2, 0.3, 0.15))
	# lamp inserts
	for si in L.lamps:
		if si >= socks.size() or socks[si].part == "":
			continue
		var pos := _lamp_pos(si)
		if pos == Vector2.INF:
			continue
		var th: String = DB.PARTS[socks[si].part].theme
		var col: Color = DB.THEME_COLORS.get(th, UI.CREAM)
		var lit := lamps.has(si)
		var c := col if lit else col.darkened(0.7)
		c.a = 1.0 if lit else 0.6
		var pts := PackedVector2Array([pos + Vector2(0, -8), pos + Vector2(7, 5), pos + Vector2(-7, 5)])
		draw_colored_polygon(pts, c)
		if lit:
			draw_circle(pos, 12, Color(col.r, col.g, col.b, 0.15 + 0.1 * sin(t_anim * 5.0 + si)))

func _lamp_pos(si: int) -> Vector2:
	var s = socks[si]
	var p := Vector2.INF
	match s.type:
		"bumper":
			if L.bumpers.has(si):
				p = L.bumpers[si].home + Vector2(0, 34)
		"target": p = Vector2(446, 555)
		"lanes": p = Vector2(350, 180)
		"ramp":
			if L.ramps.has(si) and L.ramps[si].has("a"):
				p = L.ramps[si].a.lerp(L.ramps[si].b, 0.5) + Vector2(0, 22)
				return p
		"orbit": p = Vector2(39, 590)
		"scoop": p = Vector2(98, 452)
		"center": p = Vector2(250, 640)
	if p != Vector2.INF and L.mirror and s.type in ["target", "lanes", "orbit", "scoop", "center"]:
		p = Layout.mx(p)
	return p

func _draw_walls() -> void:
	var wall := Color("efe3c8")
	var edge := Color("0b0714")
	for pts in L.walls_draw:
		draw_polyline(pts, edge, 11.0, true)
	for pts in L.walls_draw:
		draw_polyline(pts, wall, 6.0, true)
	for s in L.segs:
		if s.draw and s.on:
			draw_line(s.a, s.b, edge, 9.0)
			draw_line(s.a, s.b, wall, 5.0)
	# slings
	for sp in L.sling_polys:
		var seg = L.segs[sp.seg]
		var side: String = seg.side
		var fl: float = flashes.get("sling_" + side, 0.0)
		draw_colored_polygon(sp.pts, Color("3a2c58").lerp(Color("ff6b5e"), fl * 0.6))
		var outline: PackedVector2Array = sp.pts.duplicate()
		outline.append(sp.pts[0])
		draw_polyline(outline, edge, 9.0)
		draw_polyline(outline, wall, 5.0)
		draw_line(seg.a, seg.b, Color("ff4d5e").lerp(Color.WHITE, fl), 6.0)
	# gate
	for s in L.segs:
		if s.kind == "oneway":
			draw_line(s.a, s.b, Color("5ab8ff"), 4.0)
		if s.kind == "gate":
			draw_line(s.a, s.b, Color("ffc233"), 4.0)
		if s.kind == "floor":
			draw_line(s.a, s.b, edge, 6.0)
	# posts / pegs
	for c in L.circles:
		if not c.on:
			continue
		match c.kind:
			"post", "peg":
				draw_circle(c.c, c.r + 2.0, edge)
				draw_circle(c.c, c.r, wall)
			"wreck":
				draw_circle(c.c, c.r + 3.0, edge)
				draw_circle(c.c, c.r + 1.0, Color("b889ff").lerp(Color.WHITE, c.flash))
				_center_text(c.c + Vector2(0, -12), str(20 - wreck_hits), 12, UI.CREAM)
			"mimic":
				draw_circle(c.c + Vector2(0, 4), c.r, Color(0, 0, 0, 0.4))
				draw_circle(c.c, c.r, Color("5a1030").lerp(Color.WHITE, c.flash * 0.5))
				draw_circle(c.c, c.r * 0.7, Color("ff4d6d"))
				draw_circle(c.c + Vector2(-5, -3), 3, UI.EDGE)
				draw_circle(c.c + Vector2(5, -3), 3, UI.EDGE)

func _draw_parts() -> void:
	# bumpers
	for c in L.circles:
		if c.kind != "bumper" and c.kind != "deadbumper":
			continue
		var si: int = c.tag
		var pid := part(si)
		var th: String = DB.PARTS[pid].theme if pid != "" else ""
		var col: Color = DB.THEME_COLORS.get(th, UI.CREAM)
		if pid == "stock_bumper":
			col = Color("8d87a8")
		if c.kind == "deadbumper" or disabled.has(si):
			col = Color("3a3448")
		var ph := _is_phantom(si) and not shift_held
		var alpha := 0.35 if ph else 1.0
		var r: float = c.r * (1.0 + c.flash * 0.15)
		draw_circle(c.c + Vector2(0, 5), r, Color(0, 0, 0, 0.4 * alpha))
		draw_circle(c.c, r + 3, Color(UI.EDGE.r, UI.EDGE.g, UI.EDGE.b, alpha))
		draw_circle(c.c, r, Color(col.r, col.g, col.b, alpha).lerp(Color.WHITE, c.flash * 0.7))
		draw_circle(c.c, r * 0.62, Color(0.95, 0.91, 0.82, alpha))
		draw_circle(c.c + Vector2(-r * 0.2, -r * 0.2), r * 0.18, Color(1, 1, 1, 0.9 * alpha))
		var fin: String = socks[si].finish
		if fin != "" and fin != "phantom":
			draw_arc(c.c, r + 5, 0, TAU, 32, DB.FINISHES[fin].color, 2.0)
		if burned.has(si):
			draw_arc(c.c, r + 8 + sin(t_anim * 10.0) * 2.0, 0, TAU, 24, UI.ORANGE, 3.0)
		if pid == "tesla_coil" and tesla_cd <= 0.0:
			for k in 3:
				var a := t_anim * 6.0 + k * TAU / 3.0
				draw_line(c.c + Vector2(cos(a), sin(a)) * r, c.c + Vector2(cos(a), sin(a)) * (r + 8), UI.PTS, 2.0)
		if pid == "beehive":
			draw_arc(c.c, r * 0.4, 0, TAU, 12, UI.TICKET, 3.0)
		if pid == "loan_shark":
			_center_text(c.c + Vector2(0, 5), "T", 14, UI.TICKET)
		if pid == "hot_bumper":
			draw_circle(c.c, r * 0.3, UI.ORANGE)
	# target bank
	for ti in L.targets.size():
		var tg = L.targets[ti]
		var s = L.segs[tg.seg]
		var si: int = s.tag
		var pid := part(si)
		var col := Color("ffc233")
		if pid == "memory_bank" and not memory_seq.is_empty():
			col = UI.PTS if memory_seq[memory_pos] == ti else Color("3a5070")
		if pid == "sniper_target":
			col = UI.RED
		if disabled.has(si):
			col = Color("3a3448")
		var fl: float = flashes.get("t%d" % ti, 0.0)
		if s.on:
			draw_line(s.a, s.b, UI.EDGE, 12.0)
			draw_line(s.a, s.b, col.lerp(Color.WHITE, fl), 7.0)
		else:
			draw_line(s.a, s.b, Color(1, 1, 1, 0.12), 3.0)
	# scoop + saucer
	if not L.scoop.is_empty():
		var sc: Vector2 = L.scoop.c
		var pid := part(L.scoop.sock)
		var ring := Color("efe3c8")
		if pid == "hungry_hole":
			ring = Color("3fd6b0")
		elif pid == "ball_lock" or pid == "birdcage":
			ring = UI.TICKET
		elif pid == "mystery_scoop":
			ring = Color.from_hsv(fmod(t_anim * 0.3, 1.0), 0.6, 1.0)
		draw_circle(sc, 17, UI.EDGE)
		draw_circle(sc, 13, Color("06040b"))
		draw_arc(sc, 16, 0, TAU, 24, ring.lerp(Color.WHITE, flashes.get("scoop", 0.0)), 3.0)
		for i in locked.size():
			draw_circle(sc + Vector2(-26 + i * 10, -22), 5, UI.TICKET)
	var sau: Vector2 = L.saucer.c
	var jp: bool = Run.jackpot > 0 and not attract
	draw_circle(sau, 17, UI.EDGE)
	draw_circle(sau, 12, Color("06040b"))
	var jc := UI.JACKPOT if jp else Color("5a3a66")
	draw_arc(sau, 16, 0, TAU, 24, jc.lerp(Color.WHITE, flashes.get("saucer", 0.0)), 3.0 + (1.5 * sin(t_anim * 6.0) if jp else 0.0))
	if jp:
		_center_text(sau + Vector2(0, -24), "JACKPOT %d" % Run.jackpot, 12, UI.JACKPOT)
	# orbit lamp
	var ob = L.orbit_bottom
	if L.orbit_sock >= 0 and part(L.orbit_sock) != "":
		var oc := Vector2((ob.x0 + ob.x1) * 0.5, ob.y + 12)
		var ocol := Color("5ab8ff").lerp(Color.WHITE, flashes.get("orbit", 0.0))
		draw_colored_polygon(PackedVector2Array([oc + Vector2(0, -12), oc + Vector2(9, 4), oc + Vector2(-9, 4)]), ocol)
	# center piece
	var cpart: String = L.center.get("part", "")
	match cpart:
		"spinner":
			var a: Vector2 = L.center.a
			var b: Vector2 = L.center.b
			var sp: float = flashes.get("spinner", 0.0)
			var th := 4.0 + absf(sin(t_anim * (6.0 + sp * 8.0))) * 6.0 * minf(1.0, sp)
			draw_line(a + Vector2(-6, 0), b + Vector2(6, 0), UI.EDGE, 4.0)
			draw_rect(Rect2(a - Vector2(0, th * 0.5), Vector2(b.x - a.x, th)), Color("e8b04a"))
		"gyro_disc":
			var c: Vector2 = L.center.c
			var rr: float = L.center.r
			draw_circle(c, rr, Color("123a3a"))
			for k in 6:
				var ang := t_anim * 4.0 + k * TAU / 6.0
				draw_line(c, c + Vector2(cos(ang), sin(ang)) * rr, Color("3fd6b0"), 3.0)
			draw_arc(c, rr, 0, TAU, 32, Color("3fd6b0"), 2.0)
		"magnet":
			var c: Vector2 = L.center.c
			draw_arc(c, 18, 0, TAU, 24, Color("5ab8ff"), 3.0)
			draw_arc(c, 10, 0, TAU, 24, Color("5ab8ff"), 2.0)
			_center_text(c + Vector2(0, 34), "MAGNET %d" % magnet_uses, 11, Color("5ab8ff"))
		"playfield_doubler":
			var c: Vector2 = L.center.c
			var col := UI.JACKPOT if pf_on else Color("5a3a66")
			draw_circle(c, 22, UI.EDGE)
			draw_circle(c, 18, col)
			_center_text(c + Vector2(0, 7), "x2", 18, UI.CREAM)
	# outlane parts markers
	for side in L.outlane_socks:
		var osi: int = L.outlane_socks[side]
		var pid := part(osi)
		if pid == "" or pid == "stock_outlane":
			continue
		var x: float = (L.outlane_div[0] + (30.0 if not L.mirror else 65.0)) * 0.5 if side == "left" else (L.outlane_div[1] + (470.0 if not L.mirror else 505.0)) * 0.5
		var col := UI.GREEN
		if pid == "kickback":
			col = UI.GREEN if kick_charge.get(side, false) else Color("2a4a33")
		elif pid == "toll_gate":
			col = UI.TICKET
		elif pid == "graveyard" or pid == "gutter_angel":
			col = UI.PURPLE
		elif pid == "let_it_ride":
			col = UI.XMULT
		draw_rect(Rect2(Vector2(x - 9, 930), Vector2(18, 8)), col)
	# bagatelle cups
	for cup in L.cups:
		draw_rect(Rect2(cup.c - Vector2(cup.w, 18), Vector2(cup.w * 2, 36)), Color(0.24, 0.81, 0.43, 0.15))

func _draw_lanes_and_lamps() -> void:
	for i in L.lanes.size():
		var ln = L.lanes[i]
		var lit: bool = lane_lit[i] if i < lane_lit.size() else false
		var col := Color("ffc233") if lit else Color("4a3a24")
		var skill: bool = i == skill_lane and (skill_t > 0.0 or state == "serve" or Run.has_mod("perfect_plunge"))
		if skill and int(t_anim * 6.0) % 2 == 0:
			col = UI.JACKPOT
		var c: Vector2 = ln.c
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(8, 6), c + Vector2(-8, 6)]), col)
		if part(L.lanes_sock) == "luck_lanes":
			_center_text(c + Vector2(0, 28), "LUCK"[i], 12, col)

func _draw_ramps_under() -> void:
	for si in L.ramps:
		var r = L.ramps[si]
		if not r.has("path"):
			continue
		var pid := part(si)
		if pid == "":
			continue
		var th: String = DB.PARTS[pid].theme
		var col: Color = DB.THEME_COLORS.get(th, Color("9a93a8"))
		var mid: Vector2 = r.a.lerp(r.b, 0.5)
		var fl: float = flashes.get("ramp%d" % si, 0.0)
		var ac := col.lerp(Color.WHITE, fl)
		draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -14), mid + Vector2(12, 6), mid + Vector2(-12, 6)]), ac)

func _draw_ramps_over() -> void:
	for si in L.ramps:
		var r = L.ramps[si]
		if not r.has("path"):
			continue
		var pid := part(si)
		if pid == "":
			continue
		var th: String = DB.PARTS[pid].theme
		var col: Color = DB.THEME_COLORS.get(th, Color("9a93a8"))
		var ph := _is_phantom(si) and not shift_held
		var body := Color(col.r, col.g, col.b, 0.16 if not ph else 0.07)
		draw_polyline(r.path, body, 30.0, true)
		var rail := Color(0.95, 0.9, 0.8, 0.55 if not ph else 0.2)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for k in r.path.size():
			var p: Vector2 = r.path[k]
			var d: Vector2
			if k < r.path.size() - 1:
				d = (r.path[k + 1] - p).normalized()
			else:
				d = (p - r.path[k - 1]).normalized()
			var nrm := d.orthogonal()
			left.append(p + nrm * 15.0)
			right.append(p - nrm * 15.0)
		draw_polyline(left, rail, 2.0, true)
		draw_polyline(right, rail, 2.0, true)
		# moving chevrons
		var total: float = r.len
		var off := fmod(t_anim * 90.0, 60.0)
		var d2 := off
		while d2 < total:
			var p := _path_point(r.path, d2)
			var p2 := _path_point(r.path, d2 + 4.0)
			var dd := (p2 - p).normalized()
			var nn := dd.orthogonal()
			var cc := Color(col.r, col.g, col.b, 0.35 if not ph else 0.12)
			draw_line(p - nn * 7.0 - dd * 4.0, p + dd * 3.0, cc, 2.0)
			draw_line(p + nn * 7.0 - dd * 4.0, p + dd * 3.0, cc, 2.0)
			d2 += 60.0

func _draw_flippers() -> void:
	for f in L.flippers:
		var dir := Vector2(cos(f.angle), sin(f.angle))
		var p0: Vector2 = f.pivot
		var p1: Vector2 = f.pivot + dir * f.len
		var nrm := dir.orthogonal()
		var col := Color("f3e9d2") if not tilted else Color("5a5468")
		var rub := Color("ff4d5e") if not tilted else Color("5a3a44")
		var poly := PackedVector2Array([p0 + nrm * f.r0, p1 + nrm * f.r1, p1 - nrm * f.r1, p0 - nrm * f.r0])
		# shadow
		var sh := PackedVector2Array()
		for v in poly:
			sh.append(v + Vector2(0, 5))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
		draw_circle(p0 + Vector2(0, 5), f.r0 + 2, Color(0, 0, 0, 0.35))
		draw_circle(p0, f.r0 + 3, UI.EDGE)
		draw_circle(p1, f.r1 + 3, UI.EDGE)
		var big := PackedVector2Array([p0 + nrm * (f.r0 + 3), p1 + nrm * (f.r1 + 3), p1 - nrm * (f.r1 + 3), p0 - nrm * (f.r0 + 3)])
		draw_colored_polygon(big, UI.EDGE)
		draw_colored_polygon(poly, rub)
		var inner := PackedVector2Array([p0 + nrm * (f.r0 - 3), p1 + nrm * (f.r1 - 2.5), p1 - nrm * (f.r1 - 2.5), p0 - nrm * (f.r0 - 3)])
		draw_colored_polygon(inner, col)
		draw_circle(p0, f.r0, rub)
		draw_circle(p1, f.r1, rub)
		draw_circle(p0, f.r0 - 3, col)
		draw_circle(p0, 3, Color("8d87a8"))

func _draw_return_line() -> void:
	if L.bagatelle:
		return
	var col := Color(1, 0.3, 0.35, 0.35 + 0.45 * absf(sin(t_anim * 10.0))) if at_risk_any else Color(1, 1, 1, 0.12)
	var x := 32.0
	var x1 := 468.0
	if L.mirror:
		x += 35.0
		x1 += 35.0
	while x < x1:
		draw_line(Vector2(x, RETURN_Y), Vector2(minf(x + 10.0, x1), RETURN_Y), col, 2.0 if not at_risk_any else 3.0)
		x += 18.0

func _draw_ball(b: Ball, sc: float = 1.0) -> void:
	var col: Color = DB.BALLS.get(b.mat, DB.BALLS.steel).color
	var r := b.r * sc
	if b.bee:
		draw_circle(b.pos, r + 1, UI.EDGE)
		draw_circle(b.pos, r, UI.TICKET)
		draw_circle(b.pos + Vector2(-3, -4), 3, Color(1, 1, 1, 0.7))
		draw_circle(b.pos + Vector2(3, -4), 3, Color(1, 1, 1, 0.7))
		return
	# trail
	for i in b.trail.size():
		var a := float(i) / maxf(b.trail.size(), 1) * 0.35
		var tc := col
		tc.a = a
		if b.mat == "ember":
			tc = Color(1, 0.5, 0.1, a * 1.5)
		draw_circle(b.trail[i], r * (0.4 + 0.6 * float(i) / b.trail.size()), tc)
	var alpha := 1.0
	if b.mat in ["glass", "ghost"]:
		alpha = 0.6
	draw_circle(b.pos + Vector2(3, 6) * sc, r, Color(0, 0, 0, 0.35))
	draw_circle(b.pos, r + 1.5, Color(UI.EDGE.r, UI.EDGE.g, UI.EDGE.b, alpha))
	draw_circle(b.pos, r, Color(col.r, col.g, col.b, alpha))
	var dk := col.darkened(0.3)
	draw_circle(b.pos + Vector2(r * 0.18, r * 0.2), r * 0.72, Color(dk.r, dk.g, dk.b, alpha))
	draw_circle(b.pos + Vector2(-r * 0.05, -r * 0.05), r * 0.7, Color(col.r, col.g, col.b, alpha))
	draw_circle(b.pos + Vector2(-r * 0.35, -r * 0.38), r * 0.28, Color(1, 1, 1, 0.9))
	if b.eng != "":
		draw_arc(b.pos, r + 4, 0, TAU, 20, UI.TICKET, 1.5)
	if b.mat == "ember" and randf() < 0.5:
		_spark(b.pos, UI.ORANGE, 1)
	if b.at_risk:
		draw_arc(b.pos, r + 7 + sin(t_anim * 16.0) * 2.0, 0, TAU, 20, UI.RED, 2.0)
	if b.state == "held" and b.hold_kind == "magnet":
		draw_arc(b.pos, r + 10, 0, TAU, 20, UI.PURPLE, 2.0)

func _draw_plunger() -> void:
	var p: Vector2 = L.plunger
	var comp := plunge_charge * 34.0
	var top := p.y + 12.0 + comp
	draw_rect(Rect2(Vector2(p.x - 10, top), Vector2(20, 8)), Color("ff4d5e"))
	var y := top + 8.0
	while y < H - 4.0:
		draw_line(Vector2(p.x - 8, y), Vector2(p.x + 8, y + 3), Color("c9ced8"), 2.0)
		y += 4.0 - plunge_charge * 1.5
	if plunge_charge > 0.0 or state == "serve":
		var mx: float = L.lane_x0 - 16.0 if not L.mirror else L.lane_x1 + 8.0
		var r := Rect2(Vector2(mx, 760), Vector2(8, 170))
		draw_rect(r, Color(0, 0, 0, 0.5))
		var h := 170.0 * plunge_charge
		draw_rect(Rect2(Vector2(mx, 930 - h), Vector2(8, h)), UI.ORANGE.lerp(UI.RED, plunge_charge))
		if not attract and Run.has_mod("plunger_gauge"):
			draw_rect(Rect2(Vector2(mx - 3, 930 - 170 * 0.42), Vector2(14, 3)), UI.JACKPOT)

func _draw_boss_fx() -> void:
	if brule("high_tide"):
		draw_rect(Rect2(Vector2(0, 650), Vector2(W, H - 650)), Color(0.2, 0.5, 1.0, 0.13))
		var pts := PackedVector2Array()
		for i in 28:
			var x := i * W / 27.0
			pts.append(Vector2(x, 650 + sin(t_anim * 2.0 + i * 0.6) * 5.0))
		draw_polyline(pts, Color(0.5, 0.8, 1.0, 0.5), 3.0)
	if brule("wind_tunnel"):
		for i in 6:
			var y := 150.0 + i * 130.0
			var x := fmod(t_anim * 260.0 * wind_dir + i * 90.0, W)
			if x < 0:
				x += W
			draw_line(Vector2(x, y), Vector2(x + 30.0 * wind_dir, y), Color(1, 1, 1, 0.2), 2.0)
	if brule("magnet_heart"):
		var c: Vector2 = L.magnet_heart
		var s := 1.0 + 0.12 * sin(t_anim * 6.0)
		draw_circle(c + Vector2(-6, -3) * s, 9 * s, Color("ff2d55"))
		draw_circle(c + Vector2(6, -3) * s, 9 * s, Color("ff2d55"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 0) * s, c + Vector2(14, 0) * s, c + Vector2(0, 16) * s]), Color("ff2d55"))
		draw_arc(c, 90, 0, TAU, 48, Color(1, 0.2, 0.3, 0.12), 2.0)
	if fever > 0:
		var fc := Color(1, 0.4, 0.1, 0.25 + 0.2 * sin(t_anim * 8.0))
		draw_rect(Rect2(Vector2(0, 0), Vector2(W, H)), fc, false, 6.0)
	if pf_on:
		draw_rect(Rect2(Vector2(3, 3), Vector2(W - 6, H - 6)), Color(1, 0.3, 0.85, 0.3 + 0.2 * sin(t_anim * 10.0)), false, 4.0)
	if wizard_t > 0.0:
		draw_rect(Rect2(Vector2(6, 6), Vector2(W - 12, H - 12)), Color.from_hsv(fmod(t_anim, 1.0), 0.7, 1.0, 0.5), false, 5.0)

func _draw_bonus() -> void:
	var b := bonus_show
	var r := Rect2(Vector2(60, 380), Vector2(W - 120, 170))
	draw_style_box(UI.style(Color(0.05, 0.03, 0.1, 0.92), 14), r)
	if b.tilted:
		_center_text(Vector2(W * 0.5, 450), "TILTED", 36, UI.RED)
		_center_text(Vector2(W * 0.5, 500), "NO BONUS", 20, UI.MUTED)
		return
	_center_text(Vector2(W * 0.5, 420), "END OF BALL BONUS", 20, UI.DMD, font_head)
	var line := "%d LAMPS x %s x %dX" % [b.lit, UI.fmt(b.per), b.x]
	if b.hunter > 0:
		line += " x%d" % int(pow(3, b.hunter))
	_center_text(Vector2(W * 0.5, 462), line, 20, UI.CREAM, font_head)
	var shown: float = b.total * clampf(b.t / 1.0, 0.0, 1.0)
	_center_text(Vector2(W * 0.5, 520), UI.fmt(shown), 38, UI.TICKET, font_head)
