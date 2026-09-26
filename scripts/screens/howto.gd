extends Control

const UI = preload("res://scripts/ui/ui.gd")

var main

const PAGES := [
	["THE BASICS", """[b]TILT[/b] is a pinball roguelite. Each run is [color=#ffc233]8 Aisles[/color] of rigged machines. Every Aisle has a [color=#3a7bff]Warm-Up[/color], a [color=#9b6bff]Feature[/color] (you pick 1 of 2 rule sets) and a [color=#e8394a]Boss[/color]. Reach the target score before your balls run out. Beat the Aisle 8 finale to win.

[b]Controls[/b]
  A / Left  — left flipper        D / Right — right flipper
  SPACE (hold, release) — plunger    Q / E / W — nudge left / right / up
  SHIFT — make Phantom parts solid    ESC — pause
  Hold BOTH flippers — use a Magnet part

Hitting the lit top lane right after launching is a [color=#ff4fd8]Skill Shot[/color] (+3 Mult)."""],
	["THE SHOT (THE MOST IMPORTANT RULE)", """Everything the ball hits adds [color=#33b5ff]Points[/color] and [color=#ff4d5e]Mult[/color] to the current [b]Shot[/b].

[b]Shot score = Points x Mult x (xMult)[/b]

Points [b]only bank when you save the ball[/b]. When the ball falls past the dashed [color=#ff4d5e]Return Line[/color] above the flippers, the Shot starts flashing. Touch it with a flipper to [b]cash in[/b].

If the ball drains while a Shot is unsaved, [color=#ff4d5e]the whole Shot is lost[/color]. So every few seconds you choose: save it now, or let it ride for a bigger number?

[b]End-of-Ball Bonus:[/b] every Part you hit lights its lamp. When a ball ends, you get Lamps x Bonus Value x Bonus X, even if it drained. A [color=#ff4d5e]TILT[/color] loses the Shot AND the bonus.

[b]Fever:[/b] after 45 seconds on one ball the table heats up. Gravity rises, but every Shot gets +1 Mult per Fever level."""],
	["BUILDING YOUR TABLE", """[b]Parts[/b] go in typed sockets (Bumper Nest, Target Bank, Lanes, Ramps, Orbit, Scoop, Center, Outlanes). They replace Stock Parts. Parts have Themes: 3 of the same Theme gives a set bonus.
[b]Finishes[/b]: Chrome (+Points), Neon (+Mult), Gold (Tickets), Holo (xMult), Phantom (solid only while holding SHIFT).

[b]Firmware[/b] chips sit in the backbox and change the rules. Their order matters (Mirror ROM copies the chip to its right).

[b]The Ball Rack[/b] is your deck: each game plays the first balls in the rack, and used balls go to the back. Glass balls hit hard but shatter. A small rack means your best ball comes up more often.

[b]Blueprints[/b] level up Shot types. [b]Tools[/b] modify Parts and balls. [b]Faults[/b] are powerful glitches with a cost. [b]Mods[/b] are permanent upgrades for the run."""],
	["ECONOMY & RISK", """[color=#ffc233]Tickets[/color] are money. You earn them by winning games, from unused balls, from Gold parts and from Match.

[color=#ff4fd8]The Jackpot[/color] is your interest. After each game, +1 per 5 Tickets you hold goes into the Jackpot pool. You only get it by landing a shot in the [b]Jackpot Saucer[/b] (top left) during a game.

[b]Match:[/b] after each win, a digit spins. If it matches your score's tens digit, +5 Tickets.

[b]Skipping[/b] a Warm-Up or Feature gives you a Credit instead of that game's reward.

[b]The Back Room[/b] appears after each boss: Repair Bench, Swap Meet, the Operator's Deal, a Rival's Ghost challenge, or Madame Tilt's fortune.

[b]Operator Settings[/b] 1–8 are stacking difficulty levels. Win on a Chassis to unlock the next Setting for it."""],
	["SECRET SHOTS", """Five hidden Shot types unlock by pulling off real pinball tricks:

  • [b]Death Save[/b] — the ball heads into an outlane and a nudge bounces it back into play.
  • [b]Bang Back[/b] — the ball drains down the middle and a hard nudge-up (W) sends it back up.
  • [b]Airball[/b] — shoot a ramp so fast the ball flies off the lip.
  • [b]Post Pass[/b] — pass a slow ball from one flipper to the other.
  • [b]Super Jackpot[/b] — hit the Jackpot Saucer during multiball.

Once found, their Blueprints can appear in the shop."""],
]

var page := 0
var body: RichTextLabel
var ttl: Label

func setup(m, _p: Dictionary) -> void:
	main = m
	var p := UI.panel(Color(0.08, 0.05, 0.14, 0.94), 20, 10)
	p.position = Vector2(200, 50)
	p.custom_minimum_size = Vector2(1200, 800)
	add_child(p)
	var v := UI.vbox(14)
	p.add_child(UI.margin(v, 30, 20, 30, 20))
	ttl = UI.label("", 38, UI.TICKET, "head")
	v.add_child(ttl)
	body = UI.rich("", 22)
	body.custom_minimum_size = Vector2(1120, 600)
	v.add_child(body)
	v.add_child(UI.expander())
	var h := UI.hbox(14)
	var back := UI.button("BACK", UI.PANEL_LIGHT, Vector2(180, 56))
	back.pressed.connect(func(): main.goto("title"))
	h.add_child(back)
	h.add_child(UI.expander())
	var prev := UI.button("◀ PREV", UI.BLUE, Vector2(160, 56), 18)
	prev.pressed.connect(func(): page = (page - 1 + PAGES.size()) % PAGES.size(); _show())
	var nxt := UI.button("NEXT ▶", UI.ORANGE, Vector2(160, 56), 18)
	nxt.pressed.connect(func(): page = (page + 1) % PAGES.size(); _show())
	h.add_child(prev)
	h.add_child(nxt)
	v.add_child(h)
	_show()

func _show() -> void:
	ttl.text = "%d/%d  %s" % [page + 1, PAGES.size(), PAGES[page][0]]
	body.text = PAGES[page][1]
