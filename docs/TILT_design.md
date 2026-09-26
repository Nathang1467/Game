# TILT: Game Design Document (v2)

> A pinball roguelite. You build a cursed pinball table over a run and play it through a haunted arcade of rigged machines.
> Pinball shots are the scoring engine, the way poker hands are in Balatro.

**Status:** concept / pre-prototype
**Target run length:** 45–60 min
**Target platform:** PC first (keyboard or controller), Steam Deck-friendly

---

## Contents
1. [Design pillars](#1-design-pillars)
2. [What changed from v1 and why](#2-what-changed-from-v1-and-why)
3. [Core playstyle: the moment-to-moment game](#3-core-playstyle)
4. [The scoring engine](#4-the-scoring-engine)
5. [Run structure](#5-run-structure)
6. [The table: Chassis, Sockets and Parts](#6-the-table)
7. [Firmware: the backbox chips](#7-firmware)
8. [The Ball Rack](#8-the-ball-rack)
9. [Consumables: Blueprints, Tools, Faults](#9-consumables)
10. [Mods (permanent run upgrades)](#10-mods)
11. [Economy: Tickets and the Jackpot](#11-economy)
12. [Skipping and Credits](#12-skipping-and-credits)
13. [Boss Cabinets](#13-boss-cabinets)
14. [The Back Room (between-Aisle events)](#14-the-back-room)
15. [Chassis (starting setups)](#15-chassis)
16. [Operator Settings (difficulty levels)](#16-operator-settings)
17. [Build archetypes](#17-build-archetypes)
18. [Meta progression and the arcade's story](#18-meta-progression)
19. [Presentation and game feel](#19-presentation-and-feel)
20. [Risks: what might not work, and fixes](#20-risks)
21. [Cut list: ideas considered and dropped](#21-cut-list)
22. [Tech notes](#22-tech-notes)
23. [Prototype plan and milestones](#23-prototype-plan)
24. [Content targets for 1.0](#24-content-targets)
25. [Example run](#25-example-run)

---

## 1. Design pillars

1. **Every save is a cash-in.** Points only bank when you save the ball. Greed versus safety is decided by *hand skill*, every few seconds.
2. **Points come from chaos, Mult comes from precision.** Bumpers and spinners give volume. Ramps, orbits and target banks give multipliers. A strong build needs both, so neither pure luck nor pure skill carries a run.
3. **The build is physical.** Where a Part sits on the table changes how you play it. Your table ends up looking like *your* run.
4. **Use real pinball.** Ball save, kickbacks, end-of-ball bonus, tilt, match, skill shots, wizard modes and operator settings are all real pinball features. We use them as roguelike systems instead of inventing fake ones.
5. **Big numbers are part of the theme.** Pinball scores are famously huge, so let them get absurd.

---

## 2. What changed from v1 and why

| v1 idea | Problem | v2 fix |
|---|---|---|
| A Shot cashes when the ball "touches a flipper" | The ball brushes flippers all the time, so this is ambiguous and makes Shots tiny | Shots cash when the ball crosses the **Return Line** and you **save** it with a flip or cradle ([§3](#3-core-playstyle)) |
| Losing the whole Shot on drain | Too harsh at high numbers, and makes players quit runs | The real-pinball **End-of-Ball Bonus** still pays out on a drain. Only a **Tilt** loses everything |
| Parts placed anywhere | Breaks physics (ball traps, softlocks) and is hard to balance | **Typed Sockets** with pre-tested footprints. Rotation only in fixed steps |
| Only physical Parts | Not enough design space for rules-changing effects | Added **Firmware** chips in the backbox: non-physical, joker-like rule changers |
| Nudges as a limited count (the "discards" role) | Unlimited nudges break pinball, and a counter feels unlike pinball | Only a **Tilt meter** that decays over time, with Parts and Mods that interact with it |
| "Tokens" (tarot) next to "Tickets" (money) | Names too similar | Consumables are now **Tools**. Money stays **Tickets** |
| A straight line of games | No route decisions | Each Aisle offers a **choice between 2 Feature machines**, plus **Back Room** events after each boss |
| Games could run 5+ minutes | Runs would take 2+ hours | **Fever** speeds the table up over time, games end the moment you hit the target, and ~2 min per game is the goal |
| Mult and Points came from anywhere | Builds blur together | Clear split: Points come from volume, Mult from precision, ×Mult from risk |

---

## 3. Core playstyle

### Controls
| Input | Action |
|---|---|
| Left / Right flipper | Flip. Hold to **cradle** (catch and hold the ball) |
| Plunger (hold/release) | Launch strength. Aim for the lit **Skill Shot** lane |
| Nudge left / right / up | Push the table. Fills the Tilt meter |
| Both flippers + Nudge up | **Magna / special** (only with certain Parts or Mods) |
| Pause | Look at Parts and see live tooltips for the current Shot |

### The Shot loop (the heart of the game)

```
 LAUNCH/FLIP ──► ball is "live": every hit adds to the SHOT (Points × Mult on the display)
      ▲                                  │
      │                                  ▼
      │                     ball falls past the RETURN LINE
      │                     (just above the flippers; the tally starts flashing)
      │                        ┌─────────┴──────────┐
      │                  YOU SAVE IT             IT DRAINS
      │                (flip or cradle)              │
      │                        │                     ▼
      └──── CASH IN ◄──────────┘          SHOT LOST (0 pts)
      (hitstop + tally,                   End-of-Ball Bonus still pays
       score banked)                      Next ball from the rack
```

- The **Return Line** sits just above the flippers and inlanes. When the ball crosses it heading down, the Shot is "at risk" and the tally on screen starts flashing.
- **Saving** means the ball touches a flipper while it's at risk, either by flipping or by cradling. That **cashes** the Shot.
- If the ball goes back up without being saved (it bounces off a slingshot, for example), the Shot keeps going. Longer, riskier and bigger.
- **Result:** every save is a small clutch moment, and every Shot you let run is a gamble you chose.

### End-of-Ball Bonus (makes drains less brutal)
Real pinball counts up a bonus after every ball. TILT does the same:
- Each Part you hit lights its **Lamp** for the rest of that ball.
- When the ball ends (drained or eaten by a Part), the bonus pays **Lamps lit × Bonus Value × Bonus X**.
- Bonus X goes up by completing lane sets and similar goals.
- **A drain loses the Shot but pays the Bonus. A Tilt loses both.** That makes Tilt the real disaster, just as it is in real pinball.

### Tilt
- Nudging fills the meter. It drains slowly over about 4 seconds.
- **Warning** at 70%. At 100%: **TILT**. The flippers go dead, the ball drains, and you lose the Shot and the Bonus.
- The meter resets for each ball.

### Fever (keeps pacing tight)
- After **45 seconds** on a single ball, the table enters **Fever**. Every 10 seconds gravity goes up 5% *and* all Shots get +1 Mult.
- It stops stalling and "safe forever" play, while greedy players can deliberately push into it.
- A **stuck ball** (no Return Line crossing for 10 seconds) puts the table into Fever immediately.

### Skill Shot
- On launch, one of the top lanes is lit. Hit it and the **next Shot starts with a bonus**. The bonus depends on your Chassis and your Parts. By default it's +3 Mult.
- **Super Skill Shot:** hold the left flipper during the launch to guide the ball into a hidden target. Worth ×2 on the first Shot.

---

## 4. The scoring engine

### Formula
```
SHOT SCORE = (Σ Points) × (Σ Mult) × (Π ×Mult)
GAME SCORE = Σ cashed Shots + Σ End-of-Ball Bonuses
```
Every Shot starts at **0 Points, 1 Mult**.

### Shot types (the "poker hands")
Every playfield feature belongs to a **Shot type**. Each type has a level that Blueprints increase.

| Shot type | Role | Lv1 Points | Lv1 Mult | + per level |
|---|---|---|---|---|
| **Bumper** | Volume | +10 | — | +5 pts |
| **Slingshot** | Volume | +5 | — | +3 pts |
| **Spinner** | Volume (per spin) | +2 | — | +1 pt |
| **Rollover** | Setup | +10 | +1 | +5 / +1 |
| **Target** | Precision | +15 | +1 | +10 / +1 |
| **Bank Clear** | Precision | +30 | +4 | +15 / +2 |
| **Ramp** | Precision | +30 | +2 | +15 / +2 |
| **Orbit** | Precision | +20 | +3 | +10 / +2 |
| **Scoop** | Control | +40 | +1 | +20 / +1 |

**Secret shot types.** They start hidden and are discovered by pulling off real pinball tricks:

| Secret shot | How | Lv1 |
|---|---|---|
| **Death Save** | The ball heads into an outlane and a nudge bounces it back into play | +50 pts, ×2 Mult |
| **Bang Back** | The ball drains down the center, and a hard nudge-up at the right moment sends it back up | +100 pts, ×3 |
| **Airball** | The ball leaves the playfield surface (jumps a ramp lip) and lands still in play | +80 pts, +8 Mult |
| **Post Pass** | Pass the ball from one flipper to the other with a tap | +20 pts, +5 Mult |
| **Super Jackpot** | Hit the Jackpot Saucer during multiball | +500 pts, ×4 |

### Worked example
The ball leaves the right flipper and hits 3 Bumpers (10 each, 30 pts), makes the Ramp (+30 pts, +2 Mult), then the Orbit (+20 pts, +3 Mult). It falls to the Return Line and you save it.
`(30+30+20) × (1+2+3) = 80 × 6 = 480`
Add a *Metronome* (every 4th hit ×1.5) and a Glass ball (×2): `480 × 1.5 × 2 = 1,440`.

### Design rule
- **Points:** mostly from chaos Parts (bumpers, spinners, slingshots).
- **+Mult:** mostly from precision shots (ramps, orbits, banks).
- **×Mult:** mostly from risk (Glass balls, long Shots, Fever, nudging, Faults).
- A Part that breaks this rule should cost something (the Loan Shark, for example).

---

## 5. Run structure

```
AISLE 1 ─► AISLE 2 ─► … ─► AISLE 8 (finale) ─► Extended Play (endless)

Each Aisle:
  [Warm-Up]  ──►  [Feature A  or  Feature B]  ──►  [BOSS CABINET]  ──►  (Back Room event)
   skippable        choose 1 of 2, skippable         shown in advance      1 of 5 event types
      │                  │                              │
    shop               shop                           shop
```

- **Warm-Up:** base target.
- **Feature:** ×1.5 target. You choose between 2 machines, each showing a **Feature Rule** and a reward. For example: *"Drop targets score double, +1 Blueprint"* or *"All bumpers disabled, +8 Tickets"*.
- **Boss Cabinet:** ×2 target and a boss rule. **The boss is revealed when the Aisle starts**, so you can shop and plan around it.
- **A game ends the moment you reach the target.** Each ball you didn't use pays Tickets.
- **You lose** when all balls in a game are gone and you haven't reached the target.

### Score curve (starting point for tuning)
| Aisle | Warm-Up | Feature | Boss |
|---|---|---|---|
| 1 | 1,500 | 2,250 | 3,000 |
| 2 | 4,000 | 6,000 | 8,000 |
| 3 | 10,000 | 15,000 | 20,000 |
| 4 | 25,000 | 37,500 | 50,000 |
| 5 | 60,000 | 90,000 | 120,000 |
| 6 | 130,000 | 195,000 | 260,000 |
| 7 | 250,000 | 375,000 | 500,000 |
| 8 | 450,000 | 675,000 | 1,350,000 (finale ×3) |
| Extended | ×1.8 per Aisle | | |

---

## 6. The table

### Chassis and Sockets
Your table's **Chassis** sets its layout: how many Sockets of each type it has and where they are. Parts only fit their Socket type, and every footprint is **pre-tested** so it can't create ball traps.

| Socket type | Location | Classic Chassis has |
|---|---|---|
| **Bumper Nest** | Upper playfield | 3 |
| **Target Bank** | Left or right side | 1 |
| **Lanes** | Top rollovers | 1 |
| **Ramp** | Ramp entrances | 2 |
| **Orbit** | Outer loop | 1 |
| **Scoop** | Side hole | 1 |
| **Center** | Between the upper and lower playfield | 1 |
| **Outlane** | Left and right outlanes | 2 |
| *(fixed)* **Jackpot Saucer** | Top center | always present |

- Every Socket **starts with a Stock Part** (weak, sells for 0), so the table is always playable. Progression means replacing Stock Parts, like upgrading a standard deck.
- Only **Wrench** Tools can rotate a Part, in 15° steps within that Socket's allowed range.

### Finishes (editions)
| Finish | Effect | Rarity |
|---|---|---|
| **Chrome** | +30 Points whenever this Part scores | Common |
| **Neon** | +4 Mult whenever this Part scores | Uncommon |
| **Gold** | +1 Ticket per hit (max 5 per game) | Uncommon |
| **Holo** | ×1.5 Mult whenever this Part scores | Rare |
| **Phantom** | The ball passes *through* it unless you hold Nudge-up, so you choose when it triggers | Rare |

### Parts catalogue (starter set, about 40)
*C = Common, U = Uncommon, R = Rare, L = Legendary (Legendaries only come from Faults).*

#### Bumper Nest
| Part | R | Effect |
|---|---|---|
| Stock Bumper | — | +5 Points |
| **Pop Bumper** | C | +12 Points |
| **Loan Shark** | C | +2 Mult per hit. Costs 1 Ticket per hit. At 0 Tickets it scores nothing |
| **Mushroom** | C | A passive bumper that doesn't kick. +25 Points and slows the ball (good for control) |
| **Hot Bumper** | U | +1 Mult on the first hit, +2 on the second, +3 on the third… Resets on cash-in |
| **Twin Pop** | U | Copies the score of the best other Bumper hit this Shot |
| **Jitterbug** | R | Wanders around the nest. ×1.5 Mult per hit |
| **Beehive** | R | Each hit releases a Bee (a tiny ball lasting 1.5 seconds) that scores +5 Points per contact |
| **Tesla Coil** | R | Each hit triggers every other Bumper once (1 second cooldown) |

#### Target Bank
| Part | R | Effect |
|---|---|---|
| Stock Standups | — | +10 Points |
| **Drop Bank** | C | 3 drop targets. Clearing the bank gives Bank Clear (+4 Mult) and resets it |
| **Vault Bank** | C | Clearing the bank gives +2 Tickets |
| **Sniper Target** | U | One tiny target. ×2 Mult |
| **Memory Bank** | R | Targets must be hit in the lit order. Completing it gives ×3 Mult, and the ×3 permanently goes up by +0.5 each time |

#### Lanes
| Part | R | Effect |
|---|---|---|
| Stock Lanes | — | Complete them for +1 Bonus X |
| **Lane Change** | C | Flipping rotates which lanes are lit (a real pinball feature). Complete: +5 Mult |
| **Toll Lanes** | C | +1 Ticket per lane, once per ball |
| **L-U-C-K** | U | Completing it in one Shot gives ×2 Mult. Match odds improve (see [§11](#11-economy)) |
| **Hourglass Lanes** | U | Completing them resets the Fever timer, *or* skips ahead into Fever (your choice) |

#### Ramps
| Part | R | Effect |
|---|---|---|
| Stock Ramp | — | Standard Ramp shot |
| **Long Ramp** | C | Harder to hit. +40 Points, +3 Mult |
| **Wireform** | U | Delivers the ball straight onto a raised flipper, so the cash-in is safe. −1 Mult |
| **Accelerator** | U | The ball exits fast. The next Part hit this Shot scores twice |
| **Toll Ramp** | U | +1 Ticket per ramp. +1 Mult for every 5 Tickets you hold |
| **Ferris Ramp** | R | Ramp shots made back-to-back within 6 seconds of each other give ×1, ×2, ×3… Mult |

#### Orbit
| Part | R | Effect |
|---|---|---|
| Stock Loop | — | Standard Orbit shot |
| **Centrifuge** | U | Each extra Orbit in the same Shot doubles Orbit's Mult |
| **Wormhole Loop** | R | Sends the ball back to the plunger. Relaunch it with the Skill Shot active, and the Shot keeps going |

#### Scoop
| Part | R | Effect |
|---|---|---|
| Stock Scoop | — | Holds the ball for 1 second. +15 Points |
| **Hungry Hole** | U | Swallows the ball. The Shot cashes at **×3**. The ball ends (not counted as a drain) and goes back to the rack |
| **Mystery Scoop** | U | A random award: Tickets, Mult, a Tool, a Lamp, or the rarely seen "Nothing" |
| **Ball Lock** | R | Locks the ball. The second lock starts **Multiball** |

#### Center
| Part | R | Effect |
|---|---|---|
| **Spinner** | C | +2 Points per spin. Faster balls spin it longer |
| **Magnet** | U | Hold both flippers to freeze the ball mid-table for 1 second and aim. 2 uses per ball |
| **Gyro Disc** | U | A spinning disc that deflects the ball randomly. ×1.25 Mult per contact |
| **Wrecking Post** | R | A post between the flippers. After 20 hits it breaks and gives ×3 Mult for the rest of the game |

#### Outlane
| Part | R | Effect |
|---|---|---|
| Stock Outlane | — | Drain |
| **Toll Gate** | C | An outlane drain pays 3 Tickets as consolation |
| **Kickback** | U | Kicks the ball back into play once per ball. Completing Lanes recharges it |
| **Graveyard** | U | Every drain this run gives +1 Point to all Bumpers, permanently |
| **Gutter Angel** | R | Saves the first drain each game, *and the Shot stays alive* |

#### Legendaries (from the ERR 00 Fault only)
| Part | Socket | Effect |
|---|---|---|
| **Birdcage** | Scoop | During Multiball, all balls share one Shot, and its Mult is the *sum* of every ball's Mult |
| **The Old Man's Flipper** | Center | A small third flipper, placed at any angle you like |
| **Playfield Doubler** | Center | Every 30 seconds: **PF×2** for 10 seconds. All scoring is doubled (stacks with everything) |
| **Let It Ride** | Outlane | Shots don't cash on a save. They only cash on every *3rd* save, at ×5 |
| **The Wizard** | Lanes | Light every Lamp on the table in one game to start **Wizard Mode**: 20 seconds of multiball with every Part scoring ×3 |

### Themes (optional synergy layer, see [§20](#20-risks))
Every Part has one Theme: **Carnival, Deep Space, Haunted, Wild West, Abyss**.
- 3 Parts of the same Theme gives a set bonus (Carnival: +1 Ticket per cash-in. Space: −10% gravity. Haunted: the first drain each game becomes a Ghost ball that plays one extra Shot. West: Skill Shots ×2. Abyss: +1 Mult per second the ball stays in the upper third).
- Themes also give Firmware something to count (see *Collector's Edition*).

---

## 7. Firmware

Chips that sit in the machine's **backbox**. They have no physical presence on the table and just change the rules. **Start with 3 Firmware slots.**

| Firmware | R | Effect |
|---|---|---|
| **Double-Down** | C | The last ball of each game scores ×2 |
| **Rack Tactician** | C | The first ball of each game gets +5 Mult on every Shot |
| **Bonus Hunter** | C | End-of-Ball Bonus ×3 |
| **Patience** | C | +1 Mult per second the ball is cradled before it's shot (max +10) |
| **Speedrunner** | U | Shots that cash in under 3 seconds get ×1.5 |
| **Marathon** | U | Shots that last 10+ seconds get ×2 |
| **Seismograph** | U | Each nudge gives +1 Mult to the current Shot. Tilt fills 50% faster |
| **Stockbroker** | U | +1 Mult for every 5 Tickets held |
| **Last Rites** | U | A drained Shot carries 50% of its value into the next ball's first Shot |
| **Lamp Lighter** | U | Each Lamp lit this ball gives +5 Points to every Shot |
| **Compound Interest** | U | The Jackpot grows twice as fast |
| **Overclock** | R | The ball is 20% faster. All +Mult is worth 50% more |
| **Mirror ROM** | R | Copies the Firmware to its right (order matters) |
| **Debt Engine** | R | You can go down to −20 Tickets. +1 Mult for each Ticket of debt |
| **Match Maker** | R | Match odds go from 1 in 10 to 1 in 4 |
| **Collector's Edition** | R | ×1 Mult for each different Theme on your table (max ×5) |
| **Glass Jaw** | R | Glass balls last 50% more hits before shattering, and add ×1 more Mult |
| **Bagatelle Code** | R | +2 Mult per second the ball goes without touching a flipper. Resets when you save it |

---

## 8. The Ball Rack

The rack works like a **deck of balls**: an ordered queue.

- Each game **draws the top 3 balls**. Used balls go to the back of the queue. Balls you didn't use stay at the front.
- You can **reorder** the rack in the shop for free.
- **Minimum 3 balls.** More balls isn't automatically better: a big rack means your best ball comes up less often. **Thinning the rack** is a real strategy, the same idea as thinning a deck.

### Materials (ball types)
| Ball | Effect |
|---|---|
| **Steel** | The default |
| **Glass** | ×2 Mult on every Shot. Shatters after 30 hits and is **removed from the rack** |
| **Lead** | Heavy and slow. Ramps give +Mult equal to its weight (+4) |
| **Rubber** | Bounces a lot. Bumpers score ×1.5. Hard to control |
| **Ember** | Sets Parts on fire for the game. A burning Part scores twice, and one random burning Part breaks after the game |
| **Ice** | Almost no friction and slides fast. Spinners spin 3× as long |
| **Magnetic** | Pulled toward metal Parts. Magnet Parts get 2 extra uses |
| **Hollow** | Light and floaty. Airball shots happen much more often |
| **Gold** | +1 Ticket per cash-in |
| **Ghost** | Passes through Bumpers but still scores them (no deflection) |
| **Split** | Splits into 2 balls on its first Bumper hit (a small multiball) |
| **Echo** | Copies the Material *and* Engraving of the last ball that drained |

### Engravings (one per ball)
| Engraving | Effect |
|---|---|
| **Lucky** | 1 in 5 chance a cash-in gets ×2 |
| **Tally** | +1 Bonus X for this ball |
| **Charm** | +2 Tickets if this ball ends without draining |
| **Phoenix** | The first time it drains in each Aisle, it's saved |
| **Fuse** | After 60 seconds it explodes: the current Shot cashes at ×4 and the ball ends |
| **Anchor** | Can't tilt (the Tilt meter is disabled) but can't nudge either |

---

## 9. Consumables

You can hold **2 consumables**. Buy them in the shop, pull them from capsules, or get them from Parts.

### Blueprints (like Planet cards): level up a Shot type
One Blueprint for each Shot type in [§4](#4-the-scoring-engine), plus:
- **Master Plan** (rare): levels up *every* Shot type you've made at least once this run.
- **Secret Blueprints** only show up once you've discovered that secret shot.

### Tools (like Tarot cards): change Parts and balls
| Tool | Effect |
|---|---|
| **Polish** | Add Chrome to a Part |
| **Neon Tube** | Add Neon to a Part |
| **Gold Leaf** | Add Gold to a Part |
| **Wrench** | Rotate a Part within its allowed range |
| **Relocate** | Swap two Parts of the same Socket type |
| **Furnace** | Turn up to 2 balls into Ember |
| **Kiln** | Turn 1 ball into Glass |
| **Engraver** | Add a random Engraving to a ball |
| **Scrapper** | Destroy a Part and get 2× its sell value |
| **Tuning Fork** | Level up the Shot type you made most this Aisle |
| **Duplicator** | Copy a ball (Material and Engraving) |
| **Warranty** | The next Part that breaks this run is restored |
| **Operator's Key** | Create a random Firmware (if you have room) |
| **Repair Kit** | Fully restore Wear on all Parts (Operator Setting 6+) |

### Faults (like Spectral cards): powerful glitches with a cost
| Fault | Effect |
|---|---|
| **ERR 00: Ghost in the Machine** | Create a **Legendary Part**. Destroy every other Part in that Socket group |
| **ERR 07: Gravity Leak** | The table's slope drops 15% for the run (floatier). Outlanes get wider |
| **ERR 13: Short Circuit** | Destroy a Part. The two Parts next to it become Phantom |
| **ERR 22: Stuck Coil** | One flipper is always up for the next game. Every Shot ×3 |
| **ERR 31: Mirror Board** | Flip the whole table left to right. Get a random Rare Part |
| **ERR 40: Rack Crash** | Destroy 1 random ball. Every other ball gets a random Engraving |
| **ERR 55: Overflow** | Double your Tickets (max +30). Set your Jackpot to 0 |
| **ERR 64: Corrupted Save** | Copy a Firmware. Destroy a different random Firmware |
| **ERR 77: Hard Reset** | Replace every Part with random Parts of the same Socket type |
| **ERR 99: Kernel Panic** | +1 Firmware slot. −1 ball per game for the rest of the run |

---

## 10. Mods

Permanent for the whole run. One Mod is offered per shop (in rotation). Each has a **Tier 2** version that unlocks after you buy Tier 1.

| Tier 1 | Tier 2 |
|---|---|
| **Flipper Rubber:** flippers +10% length | **Flipper Extension:** +20% |
| **Ball Saver:** 5 seconds of drain protection per ball | **Extended Save:** 10 seconds |
| **Expansion Board:** +1 Firmware slot | **Motherboard:** +1 more |
| **Tilt Dampener:** Tilt fills 20% slower | **Iron Legs:** 40% slower |
| **Plunger Gauge:** shows the Skill Shot strength | **Perfect Plunge:** hitting the Skill Shot is guaranteed |
| **Clearance Rack:** shop prices −25% | **Liquidation:** −50% |
| **Greased Claw:** rerolls −1 Ticket | **Rigged Claw:** the first reroll in each shop is free |
| **Lamp Memory:** Lamps stay lit between balls | **Lamp Memory+:** they stay lit between games in the same Aisle |
| **Magna-Save:** one outlane magnet button, 1 use per ball | **Twin Magna:** both outlanes |
| **Big Rack:** +1 ball slot in the shop | **Pro Shop:** Rare balls appear in the shop |
| **Credit Line:** you can borrow 10 Tickets | **Loan Forgiveness:** debt is cleared at the end of each Aisle |
| **Insert Coin:** 1 Continue per run (see [§16](#16-operator-settings)) | **Free Play:** 2 Continues |

---

## 11. Economy

### Tickets
| Source | Amount |
|---|---|
| Win a Warm-Up / Feature / Boss | 3 / 4 / 5 |
| Each ball not used | +2 |
| Gold Parts, Gold balls, Toll Parts | varies |
| **Match** (see below) | +5 |

### The Jackpot (this game's version of interest)
- After every game, **+1 Ticket for every 5 you hold** (max +5) is added to your **Jackpot pool**. It isn't taken from you. It's *interest waiting to be collected*.
- The pool shows on the fixed **Jackpot Saucer** at the top of every table. **Land a shot in the saucer during a game to collect the whole pool.**
- Anything you don't collect carries over.
- So saving money pays off, but only if you can make a precise shot. Economy is tied to skill.
- The **Collector** boss steals the pool, so make sure you've cashed it before then.

### Match (a real pinball lottery)
- At the end of every game, a random number from 00 to 90 in steps of 10 spins up. If it **matches the last two digits of your score**, you win **+5 Tickets** (odds are about 1 in 10).
- *L-U-C-K Lanes* and *Match Maker* improve the odds. One archetype is building around Match luck.

### The Shop (the Prize Counter)
- **2 Part slots, 1 Firmware slot, 2 consumable slots, 1 ball slot, 1 Mod, 2 Capsules**
- **Capsules** (packs): *Part Capsule, Blueprint Capsule, Tool Capsule, Fault Capsule, Ball Capsule*. Open one and choose 1 of 3 or 1 of 5.
- **Reroll ("Shake the Claw"):** 3 Tickets, +1 for each reroll in the same shop.
- **Selling:** Parts sell for half their price. Stock Parts sell for 0.
- *Optional feature to test:* the **Claw Machine.** Opening a Capsule becomes a 5-second claw minigame, and your skill decides which of the 3 prizes you pick up. Turn it off if it turns out annoying.

---

## 12. Skipping and Credits

Skip a Warm-Up or Feature and get a **Credit** in place of that game's shop and Tickets.

| Credit | Effect |
|---|---|
| **Extra Ball** | The next game has +1 ball |
| **Capsule Credit** | A free Fault Capsule |
| **Double Tickets** | Tickets from the next game ×2 |
| **Blueprint Rush** | Level up 2 random Shot types you've made this run |
| **Rare Coupon** | The next shop has a Rare Part at 50% off |
| **Jackpot Boost** | +10 in the Jackpot pool |
| **Steady Table** | The next game can't tilt |
| **Boss Swap** | Reroll this Aisle's boss |
| **Hot Start** | The first ball of the next game starts in Fever (+Mult immediately) |
| **Coupon Book** | Everything in the next shop is 1 Ticket cheaper |

---

## 13. Boss Cabinets

Revealed when the Aisle starts. Five kinds, so each one tests something different.

### Physics bosses
| Boss | Rule |
|---|---|
| **The Slant** | The table tilts 8° to the left |
| **Short Change** | Flippers are 30% shorter |
| **The Magnet Heart** | A magnet in the center pulls the ball in and holds it for 2 seconds (it breaks your combos) |
| **High Tide** | The bottom third is "water," so the ball slows near the flippers. Saves are easier, but everything moves slowly |
| **Wind Tunnel** | A fan blows from the left or right, switching every 8 seconds |
| **The Rattle** | The table nudges *itself* at random. It doesn't fill your Tilt meter, but it also disables your nudges |

### Scoring bosses
| Boss | Rule |
|---|---|
| **The Taxman** | Only one Shot type scores. It changes each ball |
| **Flatline** | All +Mult is halved |
| **Rust** | The first Part hit on each ball is disabled for that ball |
| **Jam** | Your highest-scoring Part is disabled |
| **The Mimic** | Copies one of your Parts and places it to block your best shot line |
| **Half Life** | Shots lose 10% of their value every second until you save them |

### Economy bosses
| Boss | Rule |
|---|---|
| **The Collector** | Takes the Jackpot pool if you haven't collected it. Every Bumper hit costs 1 Ticket |
| **Pay to Play** | Each ball costs 2 Tickets to launch |

### Information bosses
| Boss | Rule |
|---|---|
| **Blackout** | Lights off. You can only see around the ball |
| **Scrambled Display** | The Shot tally is hidden until you cash in |
| **Fog of War** | The upper playfield is covered in fog |

### Rack bosses
| Boss | Rule |
|---|---|
| **The Pit Boss** | Uses your *worst* 3 balls |
| **Shatter** | Every ball counts as Glass for shattering, but without Glass's bonus |

### Finale bosses (Aisle 8, one per run)
| Finale | Rule |
|---|---|
| **The Operator** | Changes one Operator Setting at random every ball |
| **The Endless Ball** | One ball, and it can't drain. Every 20 seconds, anything not cashed in drops by 20%. Reach ×3 the target |
| **The Wizard's Cabinet** | Your table is permanently in Multiball (3 balls). The Tilt meter is shared and fills 2× faster |
| **The Mirror Machine** | Every 30 seconds the table flips left to right |
| **Last Call** | 1 ball and 90 seconds. Cash-ins are ×3 |

---

## 14. The Back Room

After each boss (except Aisle 8), you get one random event:

| Event | What happens |
|---|---|
| **Repair Bench** | Upgrade one Part: +50% on all its numbers, *or* remove all Wear |
| **Swap Meet** | Trade a Part for one of 3 random Parts of the same Socket type and rarity (or better) |
| **The Operator's Deal** | A shady offer. *"+1 Firmware slot, but the drain gap is 10% wider."* *"A Legendary Part. Lose half your Tickets."* Take it or leave it |
| **Rival's Ghost** | Play a 60-second, 1-ball challenge against a "ghost" high score. Win a Rare |
| **Madame Tilt** | A fortune-telling machine. Pay 5 Tickets and pick 1 of 3 face-down Faults |

---

## 15. Chassis

| Chassis | Starting rule | Unlock |
|---|---|---|
| **Classic** | The standard layout (see [§6](#6-the-table)) | Available from the start |
| **Widebody** | +2 Bumper Nest sockets and +1 Firmware slot. −1 ball per game | Win 1 run |
| **Tri-Flipper** | A third flipper in the middle. Outlanes are 20% wider | Discover Post Pass |
| **Bagatelle** | **No flippers.** Only nudging and pegs. The Tilt meter is 3× bigger. Every Shot ×3. Shots cash whenever the ball falls into a "cup" | Win with Bagatelle Code |
| **Twin Table** | Always 2 balls in play. Each has its own Shot | Reach a 6-ball Multiball |
| **Crooked** | Random slope each game (from −5° to +5°) | Beat The Slant |
| **Pawn Shop** | Starts with 2 Faults. No Parts in the shop, only Capsules | Use 10 Faults |
| **Ghost Cabinet** | Every Part is Phantom. 3 Parts sockets | Beat Blackout without losing a ball |
| **Minimalist** | 5 Sockets total, all Parts ×2 | Win with 3 or fewer non-Stock Parts |
| **The Heirloom** | Start with 1 random Rare Part (with a Finish) and 1 Glass ball | Win at Operator Setting 4 |
| **Gauntlet** | No shops. After each game, choose 1 of 3 rewards | Win 5 runs |
| **Blank Board** | *All* Sockets empty (no Stock Parts). +10 starting Tickets | Win with every other Chassis |

---

## 16. Operator Settings

Real arcade owners can make machines harder with settings. These work the same way: each level includes all the ones before it. Your best completed level is **stamped on the Chassis** for each Chassis.

| Level | Rule |
|---|---|
| **1: Factory Default** | Normal difficulty. Insert Coin available (1 free Continue) |
| **2: Tight Posts** | Outlane posts moved out, so more balls drain |
| **3: No Freebies** | Warm-Ups give no Tickets |
| **4: Save Off** | The ball saver at the start of each ball is removed |
| **5: Hair Trigger** | The Tilt meter fills 30% faster |
| **6: Wear and Tear** | Parts have Wear. A Part loses 10% effectiveness per game unless you repair it (at the Repair Bench, with a Repair Kit, or for 2 Tickets in the shop) |
| **7: Leased Equipment** | Some shop Parts are Rentals: they cost 1 Ticket per game but are cheap to buy |
| **8: Last Call** | −1 ball per game. Insert Coin is disabled |

**Insert Coin (Continue):** when a game is lost, pay the "coin" to replay that game with 3 fresh balls. The price is **destroying 2 random Parts and adding a random Fault curse**. It's a safety net that still costs you.

---

## 17. Build archetypes

| Archetype | Key pieces | How it plays |
|---|---|---|
| **Bumper Chaos** | Rubber balls, Pop/Hot Bumpers, Tesla Coil, Metronome, Beehive | Long, greedy Shots. Huge Points, which then need a source of Mult |
| **Ramp Sniper** | Lead balls, Long/Ferris Ramp, Wireform, Patience, Ramp Blueprints | Slow, precise, deliberate shots. Low risk, high skill |
| **Nudge Artist** | Seismograph, Iron Legs, Death Save/Bang Back Blueprints | Playing right at the edge of tilting. The most skill-intensive build |
| **Multiball** | Ball Lock, Birdcage, Split balls, Twin Table | Everything happens at once. Enormous numbers |
| **Glass Cannon** | Glass at the front of the rack, Hungry Hole, Glass Jaw, Rack Tactician | Win the game on ball 1, and don't care about the rest |
| **Loan Shark** | Loan Shark, Debt Engine, Credit Line, Toll Parts | Buying Mult with money you don't have |
| **Jackpot Banker** | Compound Interest, Stockbroker, Toll Ramp, precise saucer shots | Build up Tickets and turn them into Mult |
| **Lucky Streak** | L-U-C-K, Match Maker, Lucky Engravings, Mystery Scoop | Gambling |
| **Pacifist** | Bagatelle Chassis/Code, Mushrooms, Magnet | Never touch the flippers |
| **Lamp Lighter** | Lamp Memory+, Lamp Lighter, Bonus Hunter, Tally | Winning through End-of-Ball Bonuses: drains stop mattering |
| **Wizard Rush** | The Wizard, lots of cheap Parts, Lamp Memory | Build toward Wizard Mode every game |

---

## 18. Meta progression

- **The Hall of Fame (Collection):** every Part, Firmware, ball, Fault and boss. Flavor text tells the arcade's story.
- **Unlocks** are tied to *doing things*, not to grinding currency. For example, discovering Death Save unlocks the Nudge Artist items.
- **Onboarding by locked content:** run 1 only has Stock Parts plus about 15 Commons. Firmware unlocks after your first boss, Faults after reaching Aisle 4. Players learn one system at a time.
- **Challenge Tables:** hand-made setups with fixed rules (*"Glass Only," "No Ramps," "One Flipper"*).
- **Daily Machine:** a seeded daily run with a leaderboard. Enter your 3-letter initials, arcade style.
- **High Score boards** for each Chassis.

### The arcade's story
*"The Last Arcade" never closes. At 3 AM the machines play themselves.*
- You play as a pinball wizard's ghost, trapped since your last game.
- Every Boss Cabinet has a backglass painting and a short line of dialogue on the display: the ghosts of other players.
- The Operator is the villain, running the place from the back office. Beat him at all 8 Operator Settings to reach the true ending: **"GAME OVER — INSERT COIN."**
- Tell the story through the Collection and the display screen, never through cutscenes.

---

## 19. Presentation and feel

- **The Dot-Matrix Display (DMD)** is the main UI. It sits above the table and shows the tally for the current Shot, cash-in animations, boss taunts and the End-of-Ball Bonus countdown. It's the most recognizable piece of pinball, and it makes the "big number counts up" moment feel native to the game.
- **Cash-in hitstop:** a 0.1–0.6 second freeze, scaled to the size of the Shot. Play continues immediately afterward, so it never interrupts flow.
- **Trigger ticker:** a scrolling feed of every Part that triggered in the current Shot, so players can see *why* the number is big.
- **Camera:** a 2.5D angled view of the table, plus an option for a pure top-down view.
- **Sound:** mechanical clicks, solenoid thunks, a crowd noise that swells with Mult, and a musical stinger when the table enters Fever.
- **Each Part has its own lighting,** so a built-up table ends the run glowing in its own colors.

---

## 20. Risks

**What might not work, and how the design protects against it.**

| # | Risk | Why it's dangerous | Mitigation |
|---|---|---|---|
| 1 | **Physics randomness makes builds feel like luck** | Players will blame the game, not their choices | Mult comes from *controllable* shots, and chaos only gives Points. Cradling, Magnet, Wireform and Hungry Hole give control. Physics is deterministic per seed |
| 2 | **Runs too long** | 24 games × 3 balls of pinball adds up | Fever, stuck-ball detection, games ending instantly at the target, skippable Warm-Ups. Aim for about 2 minutes per game and time it in testing |
| 3 | **Unreadable scoring** | Balatro works because every trigger is readable. Pinball is simultaneous | DMD tally, the trigger ticker, hitstop, and a replay of the Shot in the pause menu |
| 4 | **Drains feel terrible** | The loss is about luck, not decisions | End-of-Ball Bonus, the ball saver early in each ball, Kickback/Gutter Angel, Last Rites. Only Tilt costs everything |
| 5 | **Players aren't good at pinball** | The skill barrier could scare off Balatro fans | Generous Operator Setting 1 (a long ball saver, wider flippers), assist builds (Wireform/Magnet), an optional "Relaxed" mode with slow-motion near the drain |
| 6 | **Great players steamroll** | Skill can replace good building | Score targets rise steeply; high Operator Settings target skill (Tight Posts, Hair Trigger). Leaderboards give them a goal |
| 7 | **Degenerate loops** | A ball stuck in the Bumper nest scores forever | Stuck-ball detection triggers Fever. Hot/Tesla Bumpers have cooldowns. Patience is capped |
| 8 | **Too many systems** | Parts + Firmware + balls + Engravings + 3 consumable types + Mods + Themes is a lot | Progressive unlocks. **Themes are the first thing to cut** if playtests feel crowded |
| 9 | **Multiball performance and chaos** | Physics cost and a flood of triggers | Cap at 6 balls, a separate tally per ball, Bees are simplified physics bodies |
| 10 | **Nudging feels bad on keyboard** | Nudging is subtle with analog input | Directional nudges on dedicated keys with a clear screen shake. Test on controller early |
| 11 | **Placement is too limited** | Typed Sockets could feel restrictive | Wrench rotation, Relocate, Chassis variety, Legendaries that break the rules (Old Man's Flipper) |
| 12 | **Balancing Mult inflation** | Late-game numbers get absurd | Embrace it (big scores fit pinball), but switch to scientific notation after 1e12, and tune the score curve with simulations |

---

## 21. Cut list

| Idea | Why it was dropped |
|---|---|
| Freeform Part placement | Physics softlocks and too hard to balance. Replaced by typed Sockets |
| A full table editor between games | Scope and pacing. Belongs in an eventual sandbox mode |
| Unlimited nudges with no meter | Breaks pinball |
| Nudges as a fixed count per game | Didn't feel like pinball. The Tilt meter covers it |
| Enemies with HP on the table | Muddies the pure scoring loop. Maybe as a single "Boss Target" gimmick |
| The claw machine minigame (kept on probation) | Could be fun or annoying. It's a toggle in the prototype |

---

## 22. Tech notes

- **Write custom ball physics** instead of relying on a generic engine. Ball-versus-segment/circle collision is simple, and owning it gives you:
  - **Determinism** for seeded runs, the Daily Machine and replays
  - **Continuous collision** so a fast ball doesn't pass through flippers
  - Complete control of how the flippers feel (angular velocity transferred to the ball, cradle friction)
- **Fixed timestep of 240 Hz or more, with substeps.** Rendering is interpolated.
- **Separate random number streams** (physics, shop, boss, Faults), so browsing the shop never changes a run's physics.
- **Engine:** Godot 4 (C# or GDScript, with the physics in a dedicated module) or Unity. Both work. Godot is lighter for a 2.5D table.
- **Data-driven Parts:** every Part is a data file (Socket type, footprint, triggers, effects), so content can grow without new code.
- **Trigger system:** events (`on_hit`, `on_cash`, `on_drain`, `on_nudge`, `on_game_end`…) go through a single scoring pipeline. Firmware order matters (Mirror ROM), so the pipeline has to process them in order.

---

## 23. Prototype plan

| Milestone | Goal | The question it answers |
|---|---|---|
| **M0: Physics feel** | 1 table, flippers, plunger, nudge, Tilt meter. Grey boxes | *Is flipping satisfying?* If not, stop here and fix it |
| **M1: The Shot** | Return Line, save/cash-in, DMD tally, hitstop, End-of-Ball Bonus | **Is letting the Shot ride versus saving it tense?** This decides whether the game works |
| **M2: The build** | Sockets, 10 Parts, 3 balls, 3 Blueprints, a basic shop | Does swapping Parts change how you *play*? |
| **M3: The run** | 3 Aisles, score curve, Tickets, the Jackpot | Is a 15-minute mini run fun to replay? |
| **M4: Bosses** | 6 bosses, Feature choices, Back Room | Do bosses make you change strategy? |
| **M5: Vertical slice** | 8 Aisles, 40 Parts, 12 Firmware, all consumable types, 3 Chassis, 4 Operator Settings | Is it ready to show (a Steam page and demo)? |

---

## 24. Content targets for 1.0

| Content | Count |
|---|---|
| Parts (playfield) | about 75 |
| Firmware | about 30 |
| Legendaries | 5–8 |
| Ball Materials | 12–14 |
| Engravings | 8–10 |
| Shot types (including secret ones) | 9 + 5 |
| Tools | about 18 |
| Faults | about 14 |
| Mods | 12 pairs |
| Credits | 10–12 |
| Bosses | about 24, plus 6 finales |
| Chassis | 12 |
| Operator Settings | 8 |

---

## 25. Example run

> **Chassis: Classic, Operator Setting 1.**
>
> **Aisle 1.** The Warm-Up is all Stock Parts. You cradle and shoot ramps, and win on ball 2 (+2 Tickets for the unused ball). In the shop you buy **Pop Bumper** and a **Ramp Blueprint**. The Feature choice is between *"Targets ×2, +1 Blueprint"* and *"No Bumpers, +8 Tickets"*. You take the Tickets and play without Bumpers, winning on pure ramp shots. The boss is **Short Change**. You struggle, but a Death Save on ball 3 (a secret discovered!) gets you through.
>
> **Back Room: Madame Tilt.** You pay 5 Tickets and flip over **ERR 22: Stuck Coil**.
>
> **Aisle 3.** Your table has **Hot Bumper ×2, Ferris Ramp, Kickback**, and a **Glass ball** at the front of the rack. Firmware: **Rack Tactician, Marathon**. You're building a hybrid: ball 1 is a Glass chaos ball that stays in the Bumper nest for 10+ second Shots (Marathon ×2), then you save it and cash in. You have 22 Tickets in the Jackpot, and in the Feature game you finally land the saucer shot. **+22 Tickets.**
>
> **Aisle 5.** The Glass ball shatters mid-Shot. The Shot is lost, but Lamp Lighter and the End-of-Ball Bonus keep you alive. You buy **Kiln** to make a new Glass ball and use **Stuck Coil** on the boss (**Flatline**) for ×3 on every Shot.
>
> **Aisle 8, finale: The Endless Ball.** One ball that can't drain, where anything not cashed in fades by 20% every 20 seconds. Your Ferris Ramp chain gets to ×6. You save it at the last second: **1.9 million.** The display reads: *"THE OPERATOR IS DISPLEASED."*
