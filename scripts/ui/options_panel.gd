extends Control
## Modal options panel.

const UI = preload("res://scripts/ui/ui.gd")

var main

func build(m) -> Control:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1600, 900)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = size
	add_child(dim)
	var p := UI.panel(UI.PANEL, 18, 8)
	p.position = Vector2(560, 180)
	p.custom_minimum_size = Vector2(480, 0)
	add_child(p)
	var v := UI.vbox(12)
	p.add_child(UI.margin(v, 16, 12, 16, 12))
	v.add_child(UI.label("OPTIONS", 32, UI.CREAM, "head"))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Run.options.volume
	vol.custom_minimum_size = Vector2(300, 30)
	vol.value_changed.connect(func(x): Run.set_option("volume", x); Sfx.play("tick"))
	var vh := UI.hbox(12)
	vh.add_child(UI.label("Volume", 20))
	vh.add_child(vol)
	v.add_child(vh)
	for opt in [["crt", "CRT filter"], ["shake", "Screen shake"], ["relaxed", "Relaxed mode (slow-mo near the drain)"], ["fullscreen", "Fullscreen"], ["unlock_all", "Unlock everything (playtest)"]]:
		var cb := CheckBox.new()
		cb.text = opt[1]
		cb.button_pressed = Run.options[opt[0]]
		cb.add_theme_font_size_override("font_size", 20)
		cb.focus_mode = Control.FOCUS_NONE
		var key: String = opt[0]
		cb.toggled.connect(func(on): Run.set_option(key, on); main.apply_options(); Sfx.play("click"))
		v.add_child(cb)
	var reset := UI.button("RESET SAVE DATA", UI.RED.darkened(0.3), Vector2(200, 44), 16)
	reset.pressed.connect(_reset)
	var close := UI.button("CLOSE", UI.ORANGE, Vector2(200, 52), 22)
	close.pressed.connect(queue_free)
	var bh := UI.hbox(12)
	bh.add_child(reset)
	bh.add_child(close)
	v.add_child(bh)
	return self

func _reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Run.SAVE_PATH))
	Run.meta = {"unlocked": ["classic"], "best_stake": {}, "wins": 0, "runs": 0, "secrets": {}, "seen": {}, "high_scores": {}, "flags": {}, "chassis_won": {}, "faults_used": 0, "daily_best": {}}
	Run.save_meta()
	main.toast("Save data reset.", UI.RED)
	queue_free()
