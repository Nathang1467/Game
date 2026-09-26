extends Node
## Root controller: owns the persistent background, CRT overlay and screen switching.

const UI = preload("res://scripts/ui/ui.gd")

const SCREENS := {
	"title": "res://scripts/screens/title.gd",
	"setup": "res://scripts/screens/setup_run.gd",
	"aisle": "res://scripts/screens/aisle.gd",
	"game": "res://scripts/screens/game.gd",
	"shop": "res://scripts/screens/shop.gd",
	"backroom": "res://scripts/screens/backroom.gd",
	"gameover": "res://scripts/screens/gameover.gd",
	"collection": "res://scripts/screens/collection.gd",
	"howto": "res://scripts/screens/howto.gd",
}

var ui_root: Control
var current: Control
var current_name := ""
var bg_rect: ColorRect
var crt_rect: ColorRect
var fade: ColorRect
var toast_box: VBoxContainer
var theme_res: Theme
var args := {}

func _ready() -> void:
	_setup_input()
	_parse_args()
	theme_res = UI.make_theme()
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bg.gdshader")
	bg_rect.material = mat
	bg_layer.add_child(bg_rect)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 0
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.theme = theme_res
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	var top := CanvasLayer.new()
	top.layer = 40
	add_child(top)
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(560, 20)
	toast_box.custom_minimum_size = Vector2(480, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.theme = theme_res
	top.add_child(toast_box)
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 50
	add_child(crt_layer)
	crt_rect = ColorRect.new()
	crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/crt.gdshader")
	crt_rect.material = cm
	crt_layer.add_child(crt_rect)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.04, 0.02, 0.08, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_layer.add_child(fade)
	apply_options()
	if args.has("autotest"):
		var at = load("res://tests/autotest.gd").new()
		add_child(at)
		at.begin(self, args)
		return
	if args.has("shots"):
		var sh = load("res://tests/screenshots.gd").new()
		add_child(sh)
		sh.begin(self, args)
		return
	goto("title")

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		if "=" in s:
			var kv := s.split("=", true, 1)
			args[kv[0]] = kv[1]
		else:
			args[s] = true

func apply_options() -> void:
	if crt_rect:
		crt_rect.visible = Run.options.crt

func goto(name: String, params: Dictionary = {}, instant: bool = false) -> void:
	if not instant and current != null:
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, 0.12)
		await tw.finished
	if current:
		current.queue_free()
	var scr = load(SCREENS[name]).new()
	current = scr
	current_name = name
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	scr.size = Vector2(1600, 900)
	ui_root.add_child(scr)
	if scr.has_method("setup"):
		scr.setup(self, params)
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.18)

func toast(text: String, col: Color = UI.CREAM, dur: float = 2.2) -> void:
	var p := UI.panel(UI.PANEL_DARK, 10, 4)
	var l := UI.label(text, 20, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(dur)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)

func set_bg_mood(mood: String) -> void:
	var m: ShaderMaterial = bg_rect.material
	match mood:
		"boss":
			m.set_shader_parameter("col_a", Color(0.12, 0.03, 0.06))
			m.set_shader_parameter("col_b", Color(0.3, 0.06, 0.12))
			m.set_shader_parameter("col_c", Color(0.28, 0.12, 0.04))
		"shop":
			m.set_shader_parameter("col_a", Color(0.05, 0.08, 0.14))
			m.set_shader_parameter("col_b", Color(0.06, 0.18, 0.2))
			m.set_shader_parameter("col_c", Color(0.25, 0.2, 0.05))
		"fever":
			m.set_shader_parameter("col_a", Color(0.14, 0.05, 0.03))
			m.set_shader_parameter("col_b", Color(0.32, 0.12, 0.04))
			m.set_shader_parameter("col_c", Color(0.35, 0.05, 0.2))
		_:
			m.set_shader_parameter("col_a", Color(0.09, 0.06, 0.16))
			m.set_shader_parameter("col_b", Color(0.16, 0.08, 0.26))
			m.set_shader_parameter("col_c", Color(0.04, 0.22, 0.28))

func _setup_input() -> void:
	var map := {
		"flip_left": [KEY_A, KEY_LEFT, KEY_Z, KEY_SHIFT],
		"flip_right": [KEY_D, KEY_RIGHT, KEY_SLASH, KEY_M],
		"plunge": [KEY_SPACE, KEY_DOWN, KEY_S],
		"nudge_left": [KEY_Q],
		"nudge_right": [KEY_E],
		"nudge_up": [KEY_W, KEY_UP],
		"phase": [KEY_CTRL, KEY_F],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	# SHIFT is used for Phantom parts, so keep it off the flipper list.
	map.flip_left = [KEY_A, KEY_LEFT, KEY_Z]
	map.phase = [KEY_SHIFT, KEY_F]
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var joy := {"flip_left": JOY_BUTTON_LEFT_SHOULDER, "flip_right": JOY_BUTTON_RIGHT_SHOULDER, "plunge": JOY_BUTTON_A, "nudge_up": JOY_BUTTON_Y, "nudge_left": JOY_BUTTON_X, "nudge_right": JOY_BUTTON_B, "pause": JOY_BUTTON_START}
	for action in joy:
		var jev := InputEventJoypadButton.new()
		jev.button_index = joy[action]
		InputMap.action_add_event(action, jev)
