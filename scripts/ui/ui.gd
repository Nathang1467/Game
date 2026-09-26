extends RefCounted
## Shared look-and-feel helpers. Use with: const UI = preload("res://scripts/ui/ui.gd")

const BG := Color("140f22")
const PANEL := Color("241b38")
const PANEL_LIGHT := Color("33284d")
const PANEL_DARK := Color("181128")
const EDGE := Color("0b0714")
const CREAM := Color("f3e9d2")
const MUTED := Color("a397bd")
const PTS := Color("33b5ff")
const MULT := Color("ff4d5e")
const XMULT := Color("ff9d2e")
const TICKET := Color("ffc233")
const JACKPOT := Color("ff4fd8")
const GREEN := Color("3ecf6e")
const PURPLE := Color("9b6bff")
const ORANGE := Color("ff8a2a")
const BLUE := Color("3a7bff")
const RED := Color("e8394a")
const DMD := Color("ff8a1f")

static var _fonts := {}

static func font(name: String = "main") -> Font:
	if _fonts.has(name):
		return _fonts[name]
	var path: String = {"main": "res://assets/fonts/PixelifySans.ttf", "head": "res://assets/fonts/Silkscreen.ttf", "dmd": "res://assets/fonts/VT323.ttf"}[name]
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path)
	if f == null:
		var ff := FontFile.new()
		if ff.load_dynamic_font(ProjectSettings.globalize_path(path)) == OK:
			f = ff
	if f == null:
		f = ThemeDB.fallback_font
	if f is FontFile:
		(f as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE if name != "main" else TextServer.FONT_ANTIALIASING_GRAY
	_fonts[name] = f
	return f

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("main")
	t.default_font_size = 20
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", EDGE)
	t.set_constant("outline_size", "Label", 6)
	var tip := style(PANEL_DARK, 10, 0, CREAM.darkened(0.3))
	tip.border_width_left = 2
	tip.border_width_right = 2
	tip.border_width_top = 2
	tip.border_width_bottom = 2
	tip.content_margin_left = 10
	tip.content_margin_right = 10
	tip.content_margin_top = 8
	tip.content_margin_bottom = 8
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_DARK
	t.set_stylebox("panel", "PopupPanel", sb)
	t.set_stylebox("scroll", "VScrollBar", style(PANEL_DARK, 6))
	t.set_stylebox("grabber", "VScrollBar", style(MUTED.darkened(0.3), 6))
	t.set_stylebox("grabber_highlight", "VScrollBar", style(MUTED, 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", style(CREAM, 6))
	return t

static func style(col: Color, radius: int = 12, shadow: int = 0, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.corner_detail = 6
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_offset = Vector2(0, shadow)
		s.shadow_size = 0
	if border.a > 0:
		s.border_color = border
		s.border_width_bottom = 3
		s.border_width_top = 3
		s.border_width_left = 3
		s.border_width_right = 3
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func panel(col: Color = PANEL, radius: int = 14, shadow: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(col, radius, shadow))
	return p

static func label(text: String, size: int = 20, col: Color = CREAM, fnt: String = "main", outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(fnt))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", EDGE)
	l.add_theme_constant_override("outline_size", outline)
	return l

static func rich(text: String, size: int = 18) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_override("normal_font", font("main"))
	r.add_theme_font_override("bold_font", font("main"))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", CREAM)
	r.add_theme_color_override("font_outline_color", EDGE)
	r.add_theme_constant_override("outline_size", 4)
	r.text = text
	return r

static func button(text: String, col: Color = ORANGE, min_size: Vector2 = Vector2(160, 52), size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("head"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.2))
	b.add_theme_color_override("font_outline_color", EDGE)
	b.add_theme_constant_override("outline_size", 6)
	var n := style(col, 12, 6)
	var h := style(col.lightened(0.15), 12, 6)
	var p := style(col.darkened(0.1), 12, 2)
	p.content_margin_top = 12
	var d := style(col.darkened(0.55).lerp(Color("2a2438"), 0.5), 12, 6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_entered.connect(func(): if not b.disabled: Sfx.play("hover", randf_range(0.9, 1.1), -8.0))
	b.pressed.connect(func(): Sfx.play("click"))
	return b

static func fmt(n: float) -> String:
	if is_nan(n) or is_inf(n):
		return "naneinf"
	var neg := n < 0
	n = absf(n)
	if n >= 1e12:
		var e := int(floor(log(n) / log(10.0)))
		return ("-" if neg else "") + "%.2fe%d" % [n / pow(10.0, e), e]
	var i := int(round(n))
	var s := str(i)
	var out := ""
	var c := 0
	for k in range(s.length() - 1, -1, -1):
		out = s[k] + out
		c += 1
		if c % 3 == 0 and k > 0:
			out = "," + out
	return ("-" if neg else "") + out

static func fmt_short(n: float) -> String:
	if absf(n) >= 1e12:
		return fmt(n)
	if absf(n) >= 1e6:
		return "%.2fM" % (n / 1e6)
	if absf(n) >= 1e4:
		return "%.1fK" % (n / 1e3)
	if absf(n) - floor(absf(n)) > 0.001 and absf(n) < 100:
		return "%.1f" % n
	return fmt(n)

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func margin(c: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(c)
	return m

static func spacer(h: int = 8, w: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c

static func expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func stat_box(title: String, col: Color, w: int = 150) -> Array:
	## Returns [PanelContainer, value Label]
	var p := panel(col.darkened(0.55), 10, 4)
	p.custom_minimum_size = Vector2(w, 0)
	var v := vbox(0)
	var t := label(title, 14, col.lightened(0.3), "head", 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var val := label("0", 26, CREAM, "main", 6)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(val)
	p.add_child(v)
	return [p, val]

static func kind_color(kind: String) -> Color:
	match kind:
		"part": return Color("d9c9a8")
		"firmware": return Color("3fae7a")
		"ball": return Color("7aa7d8")
		"tool": return Color("9b6bff")
		"blueprint": return Color("3a8bff")
		"fault": return Color("2a2233")
		"mod": return Color("e8a13a")
		"capsule": return Color("ff5aa8")
		"credit": return Color("5ac8c8")
	return PANEL_LIGHT
