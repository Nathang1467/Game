extends Node
## Screenshot harness: godot --path . -- --shots=title,game --out=/tmp/shots
## Each entry sets up a representative state, waits, then saves a PNG.

var main
var out_dir := "user://shots"
var frames_wait := 90
var place := "250,300"

func begin(m, args: Dictionary) -> void:
	main = m
	out_dir = args.get("out", out_dir)
	frames_wait = int(args.get("wait", 90))
	place = String(args.get("place", place))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var list: Array = String(args.shots).split(",")
	var seq := int(args.get("seq", 1))
	for name in list:
		await _prepare(name)
		for k in seq:
			for i in frames_wait:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			var path: String = out_dir.path_join(name + ("" if seq == 1 else "_%02d" % k) + ".png")
			img.save_png(path)
			print("SHOT ", path)
	get_tree().quit()

func _sample_run() -> void:
	Run.new_run("classic", 1, 12345)
	Run.tickets = 23
	Run.jackpot = 4
	var picks := ["pop_bumper", "hot_bumper", "tesla_coil", "drop_bank", "luck_lanes", "ferris_ramp", "long_ramp", "centrifuge", "ball_lock", "spinner", "kickback", "toll_gate"]
	for i in Run.sockets.size():
		if i < picks.size() and DB.PARTS[picks[i]].socket == Run.sockets[i].type:
			Run.install(i, picks[i], ["", "chrome", "", "neon", "", "", "holo", "", "", "", "", ""][i])
	Run.firmware = ["rack_tactician", "marathon", "mirror_rom"]
	Run.rack = [{"mat": "glass", "eng": "lucky"}, {"mat": "steel", "eng": ""}, {"mat": "rubber", "eng": ""}, {"mat": "ember", "eng": "fuse"}]
	Run.consumables = [{"kind": "blueprint", "id": "ramp"}, {"kind": "fault", "id": "err22"}]
	Run.levels.ramp = 3
	Run.aisle = 3
	Run.setup_aisle()

func _prepare(name: String) -> void:
	match name:
		"title":
			main.goto("title", {}, true)
		"setup":
			main.goto("setup", {}, true)
		"aisle":
			_sample_run()
			main.goto("aisle", {}, true)
		"game_stock", "game_place":
			Run.new_run("classic", 1, 1000)
			main.goto("game", {"autopilot": name == "game_stock"}, true)
			if name == "game_place":
				await get_tree().process_frame
				var t = main.current.table
				var xy: PackedStringArray = String(place).split(",")
				for b in t.balls:
					b.state = "free"
					b.in_lane = float(xy[0]) > 480.0
					b.pos = Vector2(float(xy[0]), float(xy[1]))
					b.vel = Vector2(float(xy[2]) if xy.size() > 2 else 0.0, float(xy[3]) if xy.size() > 3 else 0.0)
				t.state = "play"
		"game_bagatelle", "game_mirror":
			Run.new_run("bagatelle" if name == "game_bagatelle" else "classic", 1, 777)
			if name == "game_mirror":
				Run.flags.mirror = true
				Run.stage = 2
				Run.boss = "blackout"
			main.goto("game", {"autopilot": true}, true)
		"game", "game_boss", "game_fever":
			_sample_run()
			if name == "game_boss":
				Run.stage = 2
				Run.boss = "high_tide"
			main.goto("game", {"autopilot": true}, true)
		"shop":
			_sample_run()
			main.goto("shop", {}, true)
		"backroom":
			_sample_run()
			main.goto("backroom", {"event": "madame_tilt"}, true)
		"gameover":
			_sample_run()
			main.goto("gameover", {"won": false}, true)
		"victory":
			_sample_run()
			main.goto("gameover", {"won": true}, true)
		"collection":
			main.goto("collection", {}, true)
		"howto":
			main.goto("howto", {}, true)
	await get_tree().process_frame
