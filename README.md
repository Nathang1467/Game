# TILT — a pinball roguelite (playtest build)

Build a cursed pinball table over a run and take it through an arcade of rigged machines.
Pinball shots are the scoring engine: **Points × Mult**, cashed in only when you save the ball.

The full design is in [`docs/TILT_design.md`](docs/TILT_design.md).

## Running it

1. Install **Godot 4.3** (standard build, no .NET needed) from <https://godotengine.org/download>.
2. Open Godot → **Import** → choose this folder's `project.godot`.
3. Press **F5** (Run Project).

The project uses the Compatibility renderer, so it runs on almost any GPU.

## Controls

| Key | Action |
|---|---|
| `A` / `←` / `Z` | Left flipper |
| `D` / `→` / `/` / `M` | Right flipper |
| `Space` / `↓` / `S` (hold, release) | Plunger — hit the flashing top lane for a Skill Shot |
| `Q` / `E` / `W` / `↑` | Nudge left / right / up (fills the Tilt meter) |
| `Shift` / `F` | Make Phantom Parts solid while held |
| Both flippers | Use a Magnet Part |
| `Esc` / `P` | Pause |

A gamepad also works (shoulders = flippers, A = plunger, X/B/Y = nudges).

## How a run works

- **8 Aisles**, each with a Warm-Up, a Feature (choose 1 of 2 rule sets) and a Boss. Aisle 8 has a Finale boss.
- Reach the target score before your balls run out. Skip a Warm-Up or Feature to get a Credit instead.
- **The Shot:** everything the ball hits adds Points and Mult. The Shot only banks when the ball falls
  past the dashed Return Line and you touch it with a flipper. If it drains first, that Shot is lost.
- Lit lamps pay an **End-of-Ball Bonus** even on a drain. A **Tilt** loses everything.
- **Fever:** after 45 s on one ball, gravity rises but every Shot gets extra Mult.
- Spend **Tickets** at the Prize Counter on Parts (installed into typed sockets), Firmware chips,
  balls, Blueprints, Tools, Faults, Mods and Capsules.
- Your **Jackpot** (interest) only pays out when you hit the Jackpot Saucer on the table.
- After each boss: a **Back Room** event (Repair Bench, Swap Meet, Operator's Deal, Rival's Ghost, Madame Tilt).
- Win to unlock Chassis and higher **Operator Settings** (difficulty 1–8).

## What's in this build

| System | Content |
|---|---|
| Parts | 39 to buy (including 5 Legendaries) plus 8 Stock Parts, 8 socket types, 5 Themes with set bonuses, 5 Finishes |
| Firmware | 18 chips (order matters: Mirror ROM) |
| Balls | 12 materials, 6 Engravings; the rack plays in order like a deck |
| Consumables | 9 Blueprints + 5 secret-shot Blueprints + Master Plan, 14 Tools, 10 Faults |
| Mods | 12 tier-1 / tier-2 pairs |
| Bosses | 19 bosses + 5 Finales, 8 Feature rule sets |
| Chassis | 12 (Classic, Widebody, Tri-Flipper, Bagatelle, Twin Table, Crooked, Pawn Shop, Ghost Cabinet, Minimalist, Heirloom, Gauntlet, Blank Board) |
| Difficulty | 8 stacking Operator Settings, Insert Coin continues |
| Secrets | Death Save, Bang Back, Airball, Post Pass, Super Jackpot |
| Other | Multiball, Wizard Mode, Playfield ×2, Match lottery, Daily seeded run, Collection, Options |

Everything unlocks through play, or tick **Options → Unlock everything (playtest)** to try it all now.

## Design changes made while building

These are the places where the build differs from the design doc, and why:

- **Wrench** upgrades a Part by +25% instead of rotating it (Parts sit in fixed, pre-tested sockets).
- Only **Blueprints** can be used mid-game. Tools and Faults are used in the shop or between games,
  because changing the table mid-ball would desync the physics.
- The **Endless Ball** finale has a 3-minute cap so a game can always end.
- A real-pinball **ball search** kicks any ball that sits motionless for 4 seconds.
- The **Super Skill Shot** and **claw-machine capsules** from the doc aren't in this build.

## Automated tests

```sh
# Plays whole runs with a flipper autopilot and a shopping bot, printing one line per game
godot --headless --path . --fixed-fps 120 -- --autotest --runs=2
# Randomises every Part/ball/Firmware/boss each game to exercise all code paths, on every Chassis
godot --headless --path . --fixed-fps 120 -- --autotest --runs=12 --max_games=3 --chassis=all --chaos
# Screenshots of each screen
godot --path . -- --shots=title,aisle,game,shop,backroom,gameover,collection --out=/tmp/shots
```

## Credits

Fonts: Pixelify Sans, Silkscreen and VT323, all under the SIL Open Font License (see `assets/fonts/`).
All sounds are synthesised in code (`scripts/autoload/sfx.gd`).
