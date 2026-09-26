extends Node
## Content database for TILT. Everything data-driven lives here.

const SOCKETS := ["bumper", "target", "lanes", "ramp", "orbit", "scoop", "center", "outlane"]
const SOCKET_NAMES := {
	"bumper": "Bumper Nest", "target": "Target Bank", "lanes": "Lanes", "ramp": "Ramp",
	"orbit": "Orbit", "scoop": "Scoop", "center": "Center", "outlane": "Outlane",
}
const THEMES := ["carnival", "space", "haunted", "west", "abyss"]
const THEME_NAMES := {"carnival": "Carnival", "space": "Deep Space", "haunted": "Haunted", "west": "Wild West", "abyss": "Abyss"}
const THEME_COLORS := {
	"carnival": Color("ff7a3d"), "space": Color("5ab8ff"), "haunted": Color("b889ff"),
	"west": Color("e8b04a"), "abyss": Color("3fd6b0"), "": Color("9a93a8"),
}
const THEME_SET_DESC := {
	"carnival": "+1 Ticket per cash-in (max 5 per game)",
	"space": "-10% gravity",
	"haunted": "First drain each game returns as a Ghost ball",
	"west": "Skill Shots x2",
	"abyss": "+1 Mult per second the ball spends in the upper third",
}

const RARITY_NAMES := {"S": "Stock", "C": "Common", "U": "Uncommon", "R": "Rare", "L": "Legendary"}
const RARITY_COLORS := {"S": Color("8d8799"), "C": Color("4fa3ff"), "U": Color("3ecf6e"), "R": Color("ff4f6d"), "L": Color("ffcc33")}
const RARITY_WEIGHT := {"C": 70, "U": 25, "R": 5}

# ---------------------------------------------------------------- SHOT TYPES
# pts / mult = level-1 values; lp / lm = added per level.
const SHOTS := {
	"bumper": {"name": "Bumper", "pts": 10, "mult": 0, "lp": 5, "lm": 0, "secret": false},
	"sling": {"name": "Slingshot", "pts": 5, "mult": 0, "lp": 3, "lm": 0, "secret": false},
	"spinner": {"name": "Spinner", "pts": 2, "mult": 0, "lp": 1, "lm": 0, "secret": false},
	"rollover": {"name": "Rollover", "pts": 10, "mult": 1, "lp": 5, "lm": 1, "secret": false},
	"target": {"name": "Target", "pts": 15, "mult": 1, "lp": 10, "lm": 1, "secret": false},
	"bank": {"name": "Bank Clear", "pts": 30, "mult": 4, "lp": 15, "lm": 2, "secret": false},
	"ramp": {"name": "Ramp", "pts": 30, "mult": 2, "lp": 15, "lm": 2, "secret": false},
	"orbit": {"name": "Orbit", "pts": 20, "mult": 3, "lp": 10, "lm": 2, "secret": false},
	"scoop": {"name": "Scoop", "pts": 40, "mult": 1, "lp": 20, "lm": 1, "secret": false},
	"death_save": {"name": "Death Save", "pts": 50, "mult": 0, "xm": 2.0, "lp": 25, "lm": 2, "secret": true,
		"how": "Ball heads into an outlane and a nudge bounces it back into play."},
	"bang_back": {"name": "Bang Back", "pts": 100, "mult": 0, "xm": 3.0, "lp": 40, "lm": 3, "secret": true,
		"how": "Ball drains down the middle and a hard nudge-up sends it back up."},
	"airball": {"name": "Airball", "pts": 80, "mult": 8, "lp": 30, "lm": 3, "secret": true,
		"how": "Launch the ball up a ramp so fast it flies off the lip."},
	"post_pass": {"name": "Post Pass", "pts": 20, "mult": 5, "lp": 10, "lm": 2, "secret": true,
		"how": "Pass a slow ball from one flipper to the other without it going up the table."},
	"super_jackpot": {"name": "Super Jackpot", "pts": 500, "mult": 0, "xm": 4.0, "lp": 150, "lm": 4, "secret": true,
		"how": "Hit the Jackpot Saucer during multiball."},
}
const NORMAL_SHOTS := ["bumper", "sling", "spinner", "rollover", "target", "bank", "ramp", "orbit", "scoop"]
const SECRET_SHOTS := ["death_save", "bang_back", "airball", "post_pass", "super_jackpot"]

# ---------------------------------------------------------------- PARTS
const PARTS := {
	# Bumper Nest
	"stock_bumper": {"name": "Stock Bumper", "socket": "bumper", "rarity": "S", "cost": 0, "theme": "", "desc": "+5 Points per hit."},
	"pop_bumper": {"name": "Pop Bumper", "socket": "bumper", "rarity": "C", "cost": 4, "theme": "carnival", "desc": "+12 Points per hit."},
	"loan_shark": {"name": "Loan Shark", "socket": "bumper", "rarity": "C", "cost": 4, "theme": "west", "desc": "+2 Mult per hit. Costs 1 Ticket per hit. Scores nothing when broke."},
	"mushroom": {"name": "Mushroom", "socket": "bumper", "rarity": "C", "cost": 3, "theme": "abyss", "desc": "Passive (no kick). +25 Points per hit and slows the ball."},
	"hot_bumper": {"name": "Hot Bumper", "socket": "bumper", "rarity": "U", "cost": 6, "theme": "carnival", "desc": "+1 Mult on the 1st hit, +2 on the 2nd, +3 on the 3rd... Resets each Shot."},
	"twin_pop": {"name": "Twin Pop", "socket": "bumper", "rarity": "U", "cost": 6, "theme": "space", "desc": "Scores as much as the best other Bumper hit this Shot (x2 if none)."},
	"jitterbug": {"name": "Jitterbug", "socket": "bumper", "rarity": "R", "cost": 9, "theme": "carnival", "desc": "Wanders around its nest. x1.5 Mult per hit."},
	"beehive": {"name": "Beehive", "socket": "bumper", "rarity": "R", "cost": 9, "theme": "west", "desc": "Each hit releases a Bee (a tiny ball) that scores +5 Points per contact."},
	"tesla_coil": {"name": "Tesla Coil", "socket": "bumper", "rarity": "R", "cost": 10, "theme": "space", "desc": "Each hit fires every other Bumper once (1s cooldown)."},
	# Target Bank
	"stock_standups": {"name": "Stock Standups", "socket": "target", "rarity": "S", "cost": 0, "theme": "", "desc": "3 standup targets. +10 Points per hit."},
	"drop_bank": {"name": "Drop Bank", "socket": "target", "rarity": "C", "cost": 4, "theme": "west", "desc": "3 drop targets. Clearing the bank scores Bank Clear and resets it."},
	"vault_bank": {"name": "Vault Bank", "socket": "target", "rarity": "C", "cost": 4, "theme": "carnival", "desc": "3 drop targets. Clearing the bank gives +2 Tickets."},
	"sniper_target": {"name": "Sniper Target", "socket": "target", "rarity": "U", "cost": 6, "theme": "west", "desc": "One tiny target. x2 Mult when hit."},
	"memory_bank": {"name": "Memory Bank", "socket": "target", "rarity": "R", "cost": 9, "theme": "space", "desc": "Hit targets in the lit order. Completing gives x3 Mult, growing +0.5 each time."},
	# Lanes
	"stock_lanes": {"name": "Stock Lanes", "socket": "lanes", "rarity": "S", "cost": 0, "theme": "", "desc": "3 rollovers. Completing them gives +1 Bonus X."},
	"lane_change": {"name": "Lane Change", "socket": "lanes", "rarity": "C", "cost": 4, "theme": "space", "desc": "Flipping rotates the lit lanes. Complete for +5 Mult."},
	"toll_lanes": {"name": "Toll Lanes", "socket": "lanes", "rarity": "C", "cost": 4, "theme": "carnival", "desc": "+1 Ticket per lane, once per ball."},
	"luck_lanes": {"name": "L-U-C-K Lanes", "socket": "lanes", "rarity": "U", "cost": 6, "theme": "haunted", "desc": "4 lanes. Complete in one Shot for x2 Mult. Better Match odds."},
	"hourglass_lanes": {"name": "Hourglass Lanes", "socket": "lanes", "rarity": "U", "cost": 5, "theme": "abyss", "desc": "Completing resets the Fever timer, or jumps straight into Fever if you're close."},
	"the_wizard": {"name": "The Wizard", "socket": "lanes", "rarity": "L", "cost": 20, "theme": "haunted", "desc": "Light every Lamp on the table in one game to start Wizard Mode (3-ball multiball, x3 scoring, 20s)."},
	# Ramps
	"stock_ramp": {"name": "Stock Ramp", "socket": "ramp", "rarity": "S", "cost": 0, "theme": "", "desc": "A standard Ramp shot."},
	"long_ramp": {"name": "Long Ramp", "socket": "ramp", "rarity": "C", "cost": 5, "theme": "space", "desc": "Needs more speed. +40 Points, +3 Mult."},
	"wireform": {"name": "Wireform", "socket": "ramp", "rarity": "U", "cost": 6, "theme": "abyss", "desc": "Auto-cashes the Shot as the ball comes off the ramp (a safe cash-in). -1 Mult."},
	"accelerator": {"name": "Accelerator", "socket": "ramp", "rarity": "U", "cost": 6, "theme": "space", "desc": "Ball exits fast. The next Part hit this Shot scores twice."},
	"toll_ramp": {"name": "Toll Ramp", "socket": "ramp", "rarity": "U", "cost": 6, "theme": "west", "desc": "+1 Ticket per ramp. +1 Mult for every 5 Tickets you hold."},
	"ferris_ramp": {"name": "Ferris Ramp", "socket": "ramp", "rarity": "R", "cost": 10, "theme": "carnival", "desc": "Consecutive ramps within 6s: x1, x2, x3... Mult."},
	# Orbit
	"stock_loop": {"name": "Stock Loop", "socket": "orbit", "rarity": "S", "cost": 0, "theme": "", "desc": "A standard Orbit shot."},
	"centrifuge": {"name": "Centrifuge", "socket": "orbit", "rarity": "U", "cost": 6, "theme": "space", "desc": "Each extra Orbit in the same Shot doubles Orbit's Mult."},
	"wormhole_loop": {"name": "Wormhole Loop", "socket": "orbit", "rarity": "R", "cost": 9, "theme": "abyss", "desc": "Sends the ball back to the plunger with the Skill Shot lit. The Shot keeps going."},
	# Scoop
	"stock_scoop": {"name": "Stock Scoop", "socket": "scoop", "rarity": "S", "cost": 0, "theme": "", "desc": "Holds the ball for 1s. Scores Scoop."},
	"hungry_hole": {"name": "Hungry Hole", "socket": "scoop", "rarity": "U", "cost": 6, "theme": "abyss", "desc": "Swallows the ball. The Shot cashes at x3. The ball ends, but it doesn't count as a drain."},
	"mystery_scoop": {"name": "Mystery Scoop", "socket": "scoop", "rarity": "U", "cost": 5, "theme": "haunted", "desc": "Random award: Tickets, Mult, a Tool, a Lamp... or Nothing."},
	"ball_lock": {"name": "Ball Lock", "socket": "scoop", "rarity": "R", "cost": 9, "theme": "west", "desc": "Locks balls. The 2nd lock starts a 3-ball Multiball."},
	"birdcage": {"name": "Birdcage", "socket": "scoop", "rarity": "L", "cost": 20, "theme": "carnival", "desc": "Locks balls like Ball Lock. During Multiball, all balls share one Shot."},
	# Center
	"stock_center": {"name": "Empty Center", "socket": "center", "rarity": "S", "cost": 0, "theme": "", "desc": "Nothing here yet."},
	"spinner": {"name": "Spinner", "socket": "center", "rarity": "C", "cost": 4, "theme": "west", "desc": "+2 Points per spin. Faster balls spin it longer."},
	"magnet": {"name": "Magnet", "socket": "center", "rarity": "U", "cost": 6, "theme": "space", "desc": "Hold both flippers to freeze the ball for 1s. 2 uses per ball."},
	"gyro_disc": {"name": "Gyro Disc", "socket": "center", "rarity": "U", "cost": 5, "theme": "abyss", "desc": "Spins the ball off in a random direction. x1.25 Mult per pass."},
	"wrecking_post": {"name": "Wrecking Post", "socket": "center", "rarity": "R", "cost": 9, "theme": "haunted", "desc": "Post between the flippers. Breaks after 20 hits, then x3 Mult for the rest of the game."},
	"old_mans_flipper": {"name": "Old Man's Flipper", "socket": "center", "rarity": "L", "cost": 20, "theme": "haunted", "desc": "A third flipper mid-table, worked by the right flipper button."},
	"playfield_doubler": {"name": "Playfield Doubler", "socket": "center", "rarity": "L", "cost": 20, "theme": "carnival", "desc": "Every 30s: PFx2 for 10s. All cash-ins are doubled."},
	# Outlane
	"stock_outlane": {"name": "Stock Outlane", "socket": "outlane", "rarity": "S", "cost": 0, "theme": "", "desc": "Drains the ball."},
	"toll_gate": {"name": "Toll Gate", "socket": "outlane", "rarity": "C", "cost": 3, "theme": "west", "desc": "Draining down this outlane pays 3 Tickets."},
	"kickback": {"name": "Kickback", "socket": "outlane", "rarity": "U", "cost": 6, "theme": "carnival", "desc": "Kicks the ball back into play once per ball. Completing Lanes recharges it."},
	"graveyard": {"name": "Graveyard", "socket": "outlane", "rarity": "U", "cost": 5, "theme": "haunted", "desc": "Every drain this run gives all Bumpers +1 Point, permanently."},
	"gutter_angel": {"name": "Gutter Angel", "socket": "outlane", "rarity": "R", "cost": 9, "theme": "haunted", "desc": "Saves the first drain each game, and the Shot stays alive."},
	"let_it_ride": {"name": "Let It Ride", "socket": "outlane", "rarity": "L", "cost": 20, "theme": "west", "desc": "Shots only cash on every 3rd save, but at x5."},
}
const STOCK_PART := {
	"bumper": "stock_bumper", "target": "stock_standups", "lanes": "stock_lanes", "ramp": "stock_ramp",
	"orbit": "stock_loop", "scoop": "stock_scoop", "center": "stock_center", "outlane": "stock_outlane",
}
const LEGENDARIES := ["birdcage", "old_mans_flipper", "playfield_doubler", "let_it_ride", "the_wizard"]

const FINISHES := {
	"chrome": {"name": "Chrome", "desc": "+30 Points when this Part scores", "color": Color("d8e4f0")},
	"neon": {"name": "Neon", "desc": "+4 Mult when this Part scores", "color": Color("ff4fd8")},
	"gold": {"name": "Gold", "desc": "+1 Ticket per hit (max 5 per game)", "color": Color("ffc233")},
	"holo": {"name": "Holo", "desc": "x1.5 Mult when this Part scores", "color": Color("7dfcff")},
	"phantom": {"name": "Phantom", "desc": "Ball passes through unless you hold SHIFT", "color": Color("b7a6ff")},
}

# ---------------------------------------------------------------- FIRMWARE
const FIRMWARE := {
	"double_down": {"name": "Double-Down", "rarity": "C", "cost": 4, "desc": "The last ball of each game scores x2."},
	"rack_tactician": {"name": "Rack Tactician", "rarity": "C", "cost": 4, "desc": "The first ball of each game gets +5 Mult on every Shot."},
	"bonus_hunter": {"name": "Bonus Hunter", "rarity": "C", "cost": 4, "desc": "End-of-Ball Bonus x3."},
	"patience": {"name": "Patience", "rarity": "C", "cost": 5, "desc": "+1 Mult per second the ball is cradled before a shot (max +10)."},
	"speedrunner": {"name": "Speedrunner", "rarity": "U", "cost": 6, "desc": "Shots that cash in under 3s get x1.5."},
	"marathon": {"name": "Marathon", "rarity": "U", "cost": 6, "desc": "Shots lasting 10s or more get x2."},
	"seismograph": {"name": "Seismograph", "rarity": "U", "cost": 6, "desc": "Each nudge gives +1 Mult to the current Shot. Tilt fills 50% faster."},
	"stockbroker": {"name": "Stockbroker", "rarity": "U", "cost": 6, "desc": "+1 Mult per 5 Tickets held."},
	"last_rites": {"name": "Last Rites", "rarity": "U", "cost": 6, "desc": "A drained Shot carries 50% of its value into the next ball's first Shot."},
	"lamp_lighter": {"name": "Lamp Lighter", "rarity": "U", "cost": 5, "desc": "+5 Points per lit Lamp on every Shot this ball."},
	"compound_interest": {"name": "Compound Interest", "rarity": "U", "cost": 6, "desc": "The Jackpot grows twice as fast."},
	"overclock": {"name": "Overclock", "rarity": "R", "cost": 8, "desc": "Ball is 20% faster. All +Mult is worth 50% more."},
	"mirror_rom": {"name": "Mirror ROM", "rarity": "R", "cost": 9, "desc": "Copies the Firmware to its right."},
	"debt_engine": {"name": "Debt Engine", "rarity": "R", "cost": 8, "desc": "Go down to -20 Tickets. +1 Mult per Ticket of debt."},
	"match_maker": {"name": "Match Maker", "rarity": "R", "cost": 7, "desc": "Match odds go from 1 in 10 to 1 in 4."},
	"collectors_edition": {"name": "Collector's Edition", "rarity": "R", "cost": 8, "desc": "x0.5 Mult per different Theme on your table (on top of x1)."},
	"glass_jaw": {"name": "Glass Jaw", "rarity": "R", "cost": 7, "desc": "Glass balls last 50% more hits and add x1 more Mult."},
	"bagatelle_code": {"name": "Bagatelle Code", "rarity": "R", "cost": 8, "desc": "+2 Mult per second without a flipper touch. Resets on save."},
}

# ---------------------------------------------------------------- BALLS
const BALLS := {
	"steel": {"name": "Steel", "cost": 2, "color": Color("c9ced8"), "desc": "The default ball."},
	"glass": {"name": "Glass", "cost": 7, "color": Color("9ff6ff"), "desc": "x2 Mult on every Shot. Shatters after 30 hits."},
	"lead": {"name": "Lead", "cost": 5, "color": Color("5d6170"), "desc": "Heavy and slow. Ramps give +4 Mult."},
	"rubber": {"name": "Rubber", "cost": 5, "color": Color("ff6f9a"), "desc": "Bounces a lot. Bumpers score x1.5."},
	"ember": {"name": "Ember", "cost": 6, "color": Color("ff8a2a"), "desc": "Sets Parts on fire. Burning Parts score twice. One burning Part breaks after the game."},
	"ice": {"name": "Ice", "cost": 5, "color": Color("bfe8ff"), "desc": "Almost no friction. Spinners spin 3x as long."},
	"magnetic": {"name": "Magnetic", "cost": 5, "color": Color("8a7dff"), "desc": "Pulled toward Bumpers. Magnet Parts get +2 uses."},
	"hollow": {"name": "Hollow", "cost": 5, "color": Color("f2e6c9"), "desc": "Light and floaty. Airballs happen much more easily."},
	"gold": {"name": "Gold", "cost": 7, "color": Color("ffcc33"), "desc": "+1 Ticket per cash-in."},
	"ghost": {"name": "Ghost", "cost": 6, "color": Color("e9e4ff"), "desc": "Passes through Bumpers but still scores them."},
	"split": {"name": "Split", "cost": 6, "color": Color("7dff9a"), "desc": "Splits into 2 balls on its first Bumper hit."},
	"echo": {"name": "Echo", "cost": 6, "color": Color("c77dff"), "desc": "Copies the Material and Engraving of the last ball that drained."},
}
const ENGRAVINGS := {
	"lucky": {"name": "Lucky", "desc": "1 in 5 chance a cash-in gets x2."},
	"tally": {"name": "Tally", "desc": "+1 Bonus X for this ball."},
	"charm": {"name": "Charm", "desc": "+2 Tickets if this ball ends without draining."},
	"phoenix": {"name": "Phoenix", "desc": "The first time it drains each Aisle, it's saved."},
	"fuse": {"name": "Fuse", "desc": "After 60s it explodes: the Shot cashes at x4 and the ball ends."},
	"anchor": {"name": "Anchor", "desc": "Can't tilt, but can't nudge either."},
}

# ---------------------------------------------------------------- CONSUMABLES
const TOOLS := {
	"polish": {"name": "Polish", "desc": "Add Chrome to a Part.", "target": "part"},
	"neon_tube": {"name": "Neon Tube", "desc": "Add Neon to a Part.", "target": "part"},
	"gold_leaf": {"name": "Gold Leaf", "desc": "Add Gold to a Part.", "target": "part"},
	"wrench": {"name": "Wrench", "desc": "Upgrade a Part: +25% on all its numbers.", "target": "part"},
	"relocate": {"name": "Relocate", "desc": "Swap two Parts of the same Socket type.", "target": "part_pair"},
	"furnace": {"name": "Furnace", "desc": "Turn up to 2 balls into Ember.", "target": "ball2"},
	"kiln": {"name": "Kiln", "desc": "Turn 1 ball into Glass.", "target": "ball"},
	"engraver": {"name": "Engraver", "desc": "Add a random Engraving to a ball.", "target": "ball"},
	"scrapper": {"name": "Scrapper", "desc": "Destroy a Part. Gain 2x its sell value.", "target": "part"},
	"tuning_fork": {"name": "Tuning Fork", "desc": "Level up the Shot type you made most this Aisle.", "target": "none"},
	"duplicator": {"name": "Duplicator", "desc": "Copy a ball (Material and Engraving).", "target": "ball"},
	"warranty": {"name": "Warranty", "desc": "The next Part that breaks this run is restored.", "target": "none"},
	"operators_key": {"name": "Operator's Key", "desc": "Create a random Firmware (needs a free slot).", "target": "none"},
	"repair_kit": {"name": "Repair Kit", "desc": "Remove all Wear from all Parts.", "target": "none"},
}
const FAULTS := {
	"err00": {"name": "ERR 00: Ghost in the Machine", "desc": "Create a Legendary Part. Destroys the other Parts of that Socket type.", "target": "none"},
	"err07": {"name": "ERR 07: Gravity Leak", "desc": "Table slope -15% for the run (floatier). Outlanes get wider.", "target": "none"},
	"err13": {"name": "ERR 13: Short Circuit", "desc": "Destroy a Part. Two random Parts become Phantom.", "target": "part"},
	"err22": {"name": "ERR 22: Stuck Coil", "desc": "Next game: the left flipper stays up. Every Shot x3.", "target": "none"},
	"err31": {"name": "ERR 31: Mirror Board", "desc": "Flip the whole table left to right. Get a random Rare Part.", "target": "none"},
	"err40": {"name": "ERR 40: Rack Crash", "desc": "Destroy 1 random ball. Every other ball gets a random Engraving.", "target": "none"},
	"err55": {"name": "ERR 55: Overflow", "desc": "Double your Tickets (max +30). Jackpot set to 0.", "target": "none"},
	"err64": {"name": "ERR 64: Corrupted Save", "desc": "Copy a random Firmware. Destroy a different random Firmware.", "target": "none"},
	"err77": {"name": "ERR 77: Hard Reset", "desc": "Replace every non-Stock Part with a random Part of the same Socket type and one rarity higher.", "target": "none"},
	"err99": {"name": "ERR 99: Kernel Panic", "desc": "+1 Firmware slot. -1 ball per game for the rest of the run.", "target": "none"},
}

# ---------------------------------------------------------------- MODS
const MODS := {
	"flipper_rubber": {"name": "Flipper Rubber", "tier": 1, "next": "flipper_extension", "desc": "Flippers +10% longer."},
	"flipper_extension": {"name": "Flipper Extension", "tier": 2, "desc": "Flippers +20% longer."},
	"ball_saver": {"name": "Ball Saver", "tier": 1, "next": "extended_save", "desc": "+5s drain protection at the start of each ball."},
	"extended_save": {"name": "Extended Save", "tier": 2, "desc": "+10s drain protection at the start of each ball."},
	"expansion_board": {"name": "Expansion Board", "tier": 1, "next": "motherboard", "desc": "+1 Firmware slot."},
	"motherboard": {"name": "Motherboard", "tier": 2, "desc": "+1 more Firmware slot."},
	"tilt_dampener": {"name": "Tilt Dampener", "tier": 1, "next": "iron_legs", "desc": "Tilt fills 20% slower."},
	"iron_legs": {"name": "Iron Legs", "tier": 2, "desc": "Tilt fills 40% slower."},
	"plunger_gauge": {"name": "Plunger Gauge", "tier": 1, "next": "perfect_plunge", "desc": "Shows the Skill Shot sweet spot on the plunger meter."},
	"perfect_plunge": {"name": "Perfect Plunge", "tier": 2, "desc": "The Skill Shot lane stays lit until you hit it."},
	"clearance_rack": {"name": "Clearance Rack", "tier": 1, "next": "liquidation", "desc": "Shop prices -25%."},
	"liquidation": {"name": "Liquidation", "tier": 2, "desc": "Shop prices -50%."},
	"greased_claw": {"name": "Greased Claw", "tier": 1, "next": "rigged_claw", "desc": "Rerolls cost 1 Ticket less."},
	"rigged_claw": {"name": "Rigged Claw", "tier": 2, "desc": "The first reroll in each shop is free."},
	"lamp_memory": {"name": "Lamp Memory", "tier": 1, "next": "lamp_memory_plus", "desc": "Lamps stay lit between balls."},
	"lamp_memory_plus": {"name": "Lamp Memory+", "tier": 2, "desc": "Lamps stay lit between games in the same Aisle."},
	"magna_save": {"name": "Magna-Save", "tier": 1, "next": "twin_magna", "desc": "Left outlane magnet (press Q while the ball is in it), 1 use per ball."},
	"twin_magna": {"name": "Twin Magna", "tier": 2, "desc": "Both outlanes get magnets (Q / E)."},
	"big_rack": {"name": "Big Rack", "tier": 1, "next": "pro_shop", "desc": "+1 ball slot in the shop."},
	"pro_shop": {"name": "Pro Shop", "tier": 2, "desc": "Balls in the shop come with Engravings."},
	"credit_line": {"name": "Credit Line", "tier": 1, "next": "loan_forgiveness", "desc": "You can borrow down to -10 Tickets."},
	"loan_forgiveness": {"name": "Loan Forgiveness", "tier": 2, "desc": "Any debt is cleared at the end of each Aisle."},
	"insert_coin": {"name": "Insert Coin", "tier": 1, "next": "free_play", "desc": "+1 Continue this run."},
	"free_play": {"name": "Free Play", "tier": 2, "desc": "+1 more Continue this run."},
}

# ---------------------------------------------------------------- CREDITS (skip rewards)
const CREDITS := {
	"extra_ball": {"name": "Extra Ball", "desc": "The next game has +1 ball."},
	"capsule_credit": {"name": "Capsule Credit", "desc": "A free Fault Capsule."},
	"double_tickets": {"name": "Double Tickets", "desc": "Tickets from the next game x2."},
	"blueprint_rush": {"name": "Blueprint Rush", "desc": "Level up 2 random Shot types."},
	"rare_coupon": {"name": "Rare Coupon", "desc": "The next shop has a Rare Part at 50% off."},
	"jackpot_boost": {"name": "Jackpot Boost", "desc": "+10 in the Jackpot pool."},
	"steady_table": {"name": "Steady Table", "desc": "The next game can't tilt."},
	"boss_swap": {"name": "Boss Swap", "desc": "Reroll this Aisle's boss."},
	"hot_start": {"name": "Hot Start", "desc": "The first ball of the next game starts in Fever."},
	"coupon_book": {"name": "Coupon Book", "desc": "Everything in the next shop is 1 Ticket cheaper."},
}

# ---------------------------------------------------------------- FEATURE RULES
const FEATURES := {
	"targets_double": {"name": "Target Practice", "desc": "Target hits score double.", "reward": "blueprint", "reward_desc": "+1 Blueprint"},
	"no_bumpers": {"name": "Unplugged", "desc": "All Bumpers are switched off.", "reward": "tickets8", "reward_desc": "+8 Tickets"},
	"ramps_mult": {"name": "Ramp Night", "desc": "Ramps give x1.5 Mult.", "reward": "tool", "reward_desc": "+1 Tool"},
	"low_grav": {"name": "Moon Table", "desc": "30% lower gravity.", "reward": "part_capsule", "reward_desc": "+1 Part Capsule"},
	"fever_start": {"name": "Hot Table", "desc": "Every ball starts in Fever.", "reward": "tickets6", "reward_desc": "+6 Tickets"},
	"two_balls": {"name": "Short Game", "desc": "Only 2 balls.", "reward": "rare_part", "reward_desc": "+1 Rare Part"},
	"double_tilt": {"name": "Rickety Legs", "desc": "Tilt fills twice as fast.", "reward": "fault", "reward_desc": "+1 Fault"},
	"lanes_mult": {"name": "Lane Luck", "desc": "Each lane gives +3 Mult.", "reward": "tickets5", "reward_desc": "+5 Tickets"},
}

# ---------------------------------------------------------------- BOSSES
const BOSSES := {
	"slant": {"name": "The Slant", "kind": "Physics", "desc": "The table tilts to the left."},
	"short_change": {"name": "Short Change", "kind": "Physics", "desc": "Flippers are 30% shorter."},
	"magnet_heart": {"name": "The Magnet Heart", "kind": "Physics", "desc": "A central magnet grabs the ball for 2s and breaks your combos."},
	"high_tide": {"name": "High Tide", "kind": "Physics", "desc": "The bottom third is water. The ball slows near the flippers."},
	"wind_tunnel": {"name": "Wind Tunnel", "kind": "Physics", "desc": "Wind blows sideways, switching direction every 8s."},
	"rattle": {"name": "The Rattle", "kind": "Physics", "desc": "The table nudges itself. Your nudges are disabled."},
	"taxman": {"name": "The Taxman", "kind": "Scoring", "desc": "Only one Shot type scores Points. It changes each ball."},
	"flatline": {"name": "Flatline", "kind": "Scoring", "desc": "All +Mult is halved."},
	"rust": {"name": "Rust", "kind": "Scoring", "desc": "The first Part hit on each ball is disabled for that ball."},
	"jam": {"name": "Jam", "kind": "Scoring", "desc": "Your best Part is disabled."},
	"mimic": {"name": "The Mimic", "kind": "Scoring", "desc": "A copy of a bumper blocks your right ramp."},
	"half_life": {"name": "Half Life", "kind": "Scoring", "desc": "An uncashed Shot loses 10% every second."},
	"collector": {"name": "The Collector", "kind": "Economy", "desc": "Takes your uncollected Jackpot. Bumper hits cost 1 Ticket."},
	"pay_to_play": {"name": "Pay to Play", "kind": "Economy", "desc": "Each ball costs 2 Tickets to launch."},
	"blackout": {"name": "Blackout", "kind": "Information", "desc": "Lights off. You can only see around the ball."},
	"scrambled": {"name": "Scrambled Display", "kind": "Information", "desc": "The Shot tally is hidden until you cash in."},
	"fog": {"name": "Fog of War", "kind": "Information", "desc": "Fog covers the upper playfield."},
	"pit_boss": {"name": "The Pit Boss", "kind": "Rack", "desc": "Plays your 3 worst balls."},
	"shatter": {"name": "Shatter", "kind": "Rack", "desc": "Every ball shatters after 30 hits like Glass, without Glass's bonus."},
}
const FINALES := {
	"the_operator": {"name": "The Operator", "kind": "Finale", "desc": "A random boss rule every ball."},
	"endless_ball": {"name": "The Endless Ball", "kind": "Finale", "desc": "One ball that can't drain. Every 20s, the uncashed Shot drops 20%. The target is x1.5 higher."},
	"wizards_cabinet": {"name": "The Wizard's Cabinet", "kind": "Finale", "desc": "Always 3-ball Multiball. Tilt fills 2x faster."},
	"mirror_machine": {"name": "The Mirror Machine", "kind": "Finale", "desc": "The table flips left to right every 30s."},
	"last_call": {"name": "Last Call", "kind": "Finale", "desc": "1 ball, 90 seconds. Cash-ins x3."},
}
const OPERATOR_POOL := ["slant", "short_change", "magnet_heart", "high_tide", "wind_tunnel", "flatline", "fog", "half_life"]

# ---------------------------------------------------------------- CHASSIS
const CHASSIS := {
	"classic": {"name": "Classic", "desc": "The standard table. 3 balls, 3 Firmware slots.", "unlock": "Available from the start."},
	"widebody": {"name": "Widebody", "desc": "+2 Bumper sockets, +1 Firmware slot. -1 ball per game.", "unlock": "Win 1 run."},
	"tri_flipper": {"name": "Tri-Flipper", "desc": "A third flipper mid-table (left button). Outlanes are wider.", "unlock": "Discover Post Pass."},
	"bagatelle": {"name": "Bagatelle", "desc": "No flippers. Nudge the ball through pegs into cups. 3x Tilt meter. Every Shot x3.", "unlock": "Win a game using Bagatelle Code."},
	"twin_table": {"name": "Twin Table", "desc": "Always 2 balls in play. Each has its own Shot.", "unlock": "Start a 3-ball Multiball."},
	"crooked": {"name": "Crooked", "desc": "Random slope every game.", "unlock": "Beat The Slant."},
	"pawn_shop": {"name": "Pawn Shop", "desc": "Start with 2 Faults. The shop only has Capsules.", "unlock": "Use 10 Faults."},
	"ghost_cabinet": {"name": "Ghost Cabinet", "desc": "Every Part you buy is Phantom (hold SHIFT to make it solid).", "unlock": "Beat Blackout."},
	"minimalist": {"name": "Minimalist", "desc": "Only 5 sockets can hold Parts, but every Part is x2.", "unlock": "Win with 3 or fewer non-Stock Parts."},
	"heirloom": {"name": "The Heirloom", "desc": "Start with a random Rare Part (with a Finish) and a Glass ball.", "unlock": "Win at Operator Setting 4."},
	"gauntlet": {"name": "Gauntlet", "desc": "No shops. After each game, choose 1 of 3 rewards.", "unlock": "Win 5 runs."},
	"blank_board": {"name": "Blank Board", "desc": "Every socket starts empty. +10 starting Tickets.", "unlock": "Win with 4 different Chassis."},
}
const CHASSIS_ORDER := ["classic", "widebody", "tri_flipper", "bagatelle", "twin_table", "crooked", "pawn_shop", "ghost_cabinet", "minimalist", "heirloom", "gauntlet", "blank_board"]

# ---------------------------------------------------------------- OPERATOR SETTINGS
const SETTINGS := [
	{"name": "Factory Default", "desc": "Normal difficulty. 1 free Continue."},
	{"name": "Tight Posts", "desc": "Outlane posts moved out, so more balls drain."},
	{"name": "No Freebies", "desc": "Warm-Ups give no Tickets."},
	{"name": "Save Off", "desc": "No free ball saver at the start of each ball."},
	{"name": "Hair Trigger", "desc": "The Tilt meter fills 30% faster."},
	{"name": "Wear and Tear", "desc": "Parts wear 10% per game. Repair in the shop."},
	{"name": "Leased Equipment", "desc": "Some shop Parts are Rentals: cheap, but 1 Ticket per game."},
	{"name": "Last Call", "desc": "-1 ball per game. No Continues."},
]

# ---------------------------------------------------------------- BACK ROOM
const EVENTS := {
	"repair_bench": {"name": "Repair Bench", "desc": "Upgrade one Part: +50% on all its numbers, and remove its Wear."},
	"swap_meet": {"name": "Swap Meet", "desc": "Trade a Part for 1 of 3 random Parts of the same Socket type and at least the same rarity."},
	"operators_deal": {"name": "The Operator's Deal", "desc": "A shady offer. Take it or leave it."},
	"rivals_ghost": {"name": "Rival's Ghost", "desc": "A 60-second, 1-ball challenge against a ghost's score. Win a Rare Part."},
	"madame_tilt": {"name": "Madame Tilt", "desc": "Pay 5 Tickets and pick 1 of 3 face-down Faults."},
}
const DEALS := [
	{"id": "slot_for_drain", "desc": "+1 Firmware slot, but outlanes are wider."},
	{"id": "legend_for_tickets", "desc": "A random Legendary Part. Lose half your Tickets."},
	{"id": "tickets_for_ball", "desc": "+15 Tickets. -1 ball per game for the next Aisle."},
	{"id": "levels_for_tilt", "desc": "Level up 3 Shot types. Tilt fills 25% faster for the rest of the run."},
	{"id": "glass_for_part", "desc": "Two Glass balls. Destroy your best Part."},
]
const CURSES := {
	"rusty_legs": {"name": "Rusty Legs", "desc": "Tilt fills 20% faster."},
	"loose_posts": {"name": "Loose Posts", "desc": "Outlanes wider."},
	"sticky_flippers": {"name": "Sticky Flippers", "desc": "Flippers are 15% weaker."},
}

# ---------------------------------------------------------------- SCORE CURVE
const WARMUP_TARGETS := [1500, 4000, 10000, 25000, 60000, 130000, 250000, 450000]

func warmup_target(aisle: int) -> float:
	if aisle <= 8:
		return WARMUP_TARGETS[aisle - 1]
	return WARMUP_TARGETS[7] * pow(1.8, aisle - 8)

# ---------------------------------------------------------------- HELPERS
func part_ids(socket: String = "", rarity: String = "") -> Array:
	var out := []
	for id in PARTS:
		var p = PARTS[id]
		if socket != "" and p.socket != socket:
			continue
		if rarity != "" and p.rarity != rarity:
			continue
		if p.rarity == "S" or (p.rarity == "L" and rarity != "L"):
			continue
		out.append(id)
	return out

func roll_rarity(rng: RandomNumberGenerator, rare_boost: float = 0.0) -> String:
	var total := 0.0
	var w := {"C": RARITY_WEIGHT.C * (1.0 - rare_boost), "U": RARITY_WEIGHT.U * (1.0 + rare_boost), "R": RARITY_WEIGHT.R * (1.0 + rare_boost * 3.0)}
	for k in w:
		total += w[k]
	var r := rng.randf() * total
	for k in ["C", "U", "R"]:
		r -= w[k]
		if r <= 0.0:
			return k
	return "C"

func random_part(rng: RandomNumberGenerator, socket: String = "", rarity: String = "", exclude: Array = []) -> String:
	if rarity == "":
		rarity = roll_rarity(rng)
	var pool := part_ids(socket, rarity)
	pool = pool.filter(func(x): return not exclude.has(x))
	if pool.is_empty():
		pool = part_ids(socket, "").filter(func(x): return not exclude.has(x))
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]

func random_firmware(rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var rar := roll_rarity(rng)
	var pool := []
	for id in FIRMWARE:
		if FIRMWARE[id].rarity == rar and not exclude.has(id):
			pool.append(id)
	if pool.is_empty():
		for id in FIRMWARE:
			if not exclude.has(id):
				pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]

func pick(rng: RandomNumberGenerator, arr: Array):
	if arr.is_empty():
		return null
	return arr[rng.randi() % arr.size()]

func shot_value(type: String, level: int) -> Dictionary:
	var s = SHOTS[type]
	var l := maxi(level, 1) - 1
	return {"pts": s.pts + s.lp * l, "mult": s.mult + s.lm * l, "xm": s.get("xm", 1.0) + 0.25 * l * (1 if s.has("xm") else 0)}

func item_name(kind: String, id: String) -> String:
	match kind:
		"part": return PARTS[id].name
		"firmware": return FIRMWARE[id].name
		"ball": return BALLS[id].name
		"tool": return TOOLS[id].name
		"fault": return FAULTS[id].name
		"blueprint": return (SHOTS[id].name + " Blueprint") if id != "master_plan" else "Master Plan"
		"mod": return MODS[id].name
	return id

func item_desc(kind: String, id: String) -> String:
	match kind:
		"part": return PARTS[id].desc
		"firmware": return FIRMWARE[id].desc
		"ball": return BALLS[id].desc
		"tool": return TOOLS[id].desc
		"fault": return FAULTS[id].desc
		"blueprint":
			if id == "master_plan":
				return "Level up every Shot type you've made this run."
			var s = SHOTS[id]
			var d := "Level up %s: +%d Points" % [s.name, s.lp]
			if s.lm > 0:
				d += ", +%d Mult" % s.lm
			return d + "."
		"mod": return MODS[id].desc
	return ""
