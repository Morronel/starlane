class_name Items
extends RefCounted
## Catalogue of ships, equipment, crafting parts and blueprints.

const SHIPS := {
	"sparrow": {"name": "Sparrow", "role": "Light interceptor", "price": 6000,
		"hull": 100, "speed": 120, "turn": 1.0, "cargo": 15, "slots": {"primary": 2, "secondary": 1, "utility": 2},
		"desc": "Cheap, nimble and forgiving. Every pilot starts somewhere."},
	"wren": {"name": "Wren", "role": "Fast courier", "price": 14000,
		"hull": 95, "speed": 150, "turn": 1.15, "cargo": 32, "slots": {"primary": 1, "secondary": 1, "utility": 3},
		"desc": "Built for speed. Outruns trouble rather than fighting it."},
	"kestrel": {"name": "Kestrel", "role": "Strike fighter", "price": 26000,
		"hull": 160, "speed": 136, "turn": 1.2, "cargo": 12, "slots": {"primary": 3, "secondary": 2, "utility": 2},
		"desc": "Militia favourite. Three hardpoints and a tight turn."},
	"mule": {"name": "Mule", "role": "Bulk hauler", "price": 32000,
		"hull": 230, "speed": 96, "turn": 0.75, "cargo": 80, "slots": {"primary": 2, "secondary": 1, "utility": 4},
		"desc": "Slow, tough and enormous. Traders love it, raiders love it more."},
	"corsair": {"name": "Corsair", "role": "Heavy gunship", "price": 58000,
		"hull": 320, "speed": 110, "turn": 0.9, "cargo": 30, "slots": {"primary": 4, "secondary": 2, "utility": 3},
		"desc": "Four guns, thick plating. Turns raider nests into scrap fields."},
	"seraph": {"name": "Seraph", "role": "Elite multirole", "price": 95000,
		"hull": 270, "speed": 152, "turn": 1.25, "cargo": 42, "slots": {"primary": 4, "secondary": 3, "utility": 4},
		"desc": "Drydock masterpiece. Fast, deadly and quietly beautiful."},
	# 0.14: eight more hulls. "look" drives the parametric model, "cockpit" picks a cockpit style.
	"otter": {"name": "Otter", "role": "Light hauler", "price": 21000,
		"hull": 140, "speed": 122, "turn": 0.95, "cargo": 55, "slots": {"primary": 2, "secondary": 1, "utility": 3},
		"desc": "A friendly little box with engines. The first ship most traders love.",
		"look": {"len": 11.0, "w": 2.2, "h": 1.6, "wing": 2.5, "pods": 2, "boxy": true, "body": Color(0.95, 0.75, 0.4), "trim": Color(0.45, 0.32, 0.22), "glow": Color(1.0, 0.7, 0.3)}, "cockpit": "mule", "size": 1.35},
	"lark": {"name": "Lark", "role": "Explorer", "price": 30000,
		"hull": 120, "speed": 168, "turn": 1.2, "cargo": 26, "slots": {"primary": 2, "secondary": 1, "utility": 4},
		"desc": "Long legs and a big window. Built for sightseeing at speed.",
		"look": {"len": 13.0, "w": 1.2, "h": 1.0, "wing": 6.0, "pods": 2, "body": Color(0.85, 0.95, 0.9), "trim": Color(0.25, 0.55, 0.5), "glow": Color(0.4, 1.0, 0.8)}, "cockpit": "seraph", "size": 1.15},
	"viper": {"name": "Viper", "role": "Navy interceptor", "price": 42000, "licence": "navy",
		"hull": 170, "speed": 160, "turn": 1.35, "cargo": 10, "slots": {"primary": 3, "secondary": 2, "utility": 2},
		"desc": "Concord Navy issue. Turns like a thought.",
		"look": {"len": 12.0, "w": 1.1, "h": 0.9, "wing": 4.2, "pods": 1, "fins": true, "body": Color(0.35, 0.45, 0.6), "trim": Color(0.15, 0.2, 0.3), "glow": Color(0.4, 0.75, 1.0)}, "cockpit": "kestrel", "size": 1.1},
	"phantom": {"name": "Phantom", "role": "Smuggler's runner", "price": 64000, "licence": "comet",
		"hull": 180, "speed": 178, "turn": 1.2, "cargo": 40, "slots": {"primary": 2, "secondary": 1, "utility": 3}, "hidden": true,
		"desc": "Black Comet special. Shielded hold: customs scans see nothing.",
		"look": {"len": 13.5, "w": 1.6, "h": 0.8, "wing": 5.0, "pods": 2, "fins": true, "body": Color(0.16, 0.15, 0.2), "trim": Color(0.45, 0.1, 0.2), "glow": Color(1.0, 0.25, 0.45)}, "cockpit": "corsair", "size": 1.2},
	"nomad": {"name": "Nomad", "role": "Long hauler", "price": 85000,
		"hull": 300, "speed": 124, "turn": 0.8, "cargo": 115, "slots": {"primary": 2, "secondary": 1, "utility": 4},
		"desc": "Bunks, a galley and a hold the size of a ballroom. Home on the road.",
		"look": {"len": 19.0, "w": 2.8, "h": 2.2, "wing": 3.0, "pods": 3, "boxy": true, "body": Color(0.8, 0.82, 0.78), "trim": Color(0.3, 0.45, 0.35), "glow": Color(0.5, 1.0, 0.6)}, "cockpit": "mule", "size": 1.85},
	"warden": {"name": "Warden", "role": "Navy frigate", "price": 125000, "licence": "navy",
		"hull": 520, "speed": 112, "turn": 0.85, "cargo": 40, "slots": {"primary": 5, "secondary": 3, "utility": 4},
		"desc": "A small warship with a big opinion about pirates.",
		"look": {"len": 20.0, "w": 2.6, "h": 1.8, "wing": 5.5, "pods": 3, "fins": true, "body": Color(0.55, 0.6, 0.68), "trim": Color(0.2, 0.25, 0.35), "glow": Color(0.45, 0.8, 1.0)}, "cockpit": "corsair", "size": 1.95},
	"tortoise": {"name": "Tortoise", "role": "Heavy freighter", "price": 150000,
		"hull": 480, "speed": 88, "turn": 0.6, "cargo": 180, "slots": {"primary": 2, "secondary": 1, "utility": 5},
		"desc": "Slow. Very slow. Also carries a small moon's worth of cargo.",
		"look": {"len": 22.0, "w": 3.8, "h": 3.0, "wing": 1.5, "pods": 4, "boxy": true, "body": Color(0.7, 0.6, 0.4), "trim": Color(0.35, 0.3, 0.2), "glow": Color(1.0, 0.75, 0.35)}, "cockpit": "mule", "size": 2.3},
	"leviathan": {"name": "Leviathan", "role": "Super freighter", "price": 260000,
		"hull": 650, "speed": 92, "turn": 0.55, "cargo": 280, "slots": {"primary": 3, "secondary": 2, "utility": 6},
		"desc": "The end of the road for traders. Stations wave when you go by.",
		"look": {"len": 28.0, "w": 4.4, "h": 3.4, "wing": 4.0, "pods": 4, "boxy": true, "fins": true, "body": Color(0.9, 0.9, 0.95), "trim": Color(0.55, 0.45, 0.25), "glow": Color(1.0, 0.85, 0.5)}, "cockpit": "seraph", "size": 2.7},
}

## slot: primary / secondary / utility. Weapons: dmg, cd (s), speed, life (s), pellets, spread (deg), color.
const GEAR := {
	"pulse_1": {"name": "Pulse Laser", "slot": "primary", "price": 900, "dmg": 8.0, "cd": 0.22, "speed": 950.0, "life": 1.8, "color": Color(0.5, 2.2, 3.0),
		"desc": "Reliable all-rounder."},
	"pulse_2": {"name": "Pulse Laser Mk II", "slot": "primary", "price": 2600, "dmg": 12.0, "cd": 0.2, "speed": 1000.0, "life": 1.8, "color": Color(0.6, 2.4, 3.2),
		"desc": "Hotter coils, faster bolts."},
	"ion": {"name": "Ion Repeater", "slot": "primary", "price": 2200, "dmg": 5.5, "cd": 0.1, "speed": 1100.0, "life": 1.5, "color": Color(0.6, 3.0, 1.0),
		"desc": "Fires a hail of light bolts."},
	"scatter": {"name": "Scatter Blaster", "slot": "primary", "price": 3000, "dmg": 6.0, "cd": 0.42, "speed": 850.0, "life": 1.0, "pellets": 4, "spread": 2.6, "color": Color(3.0, 1.6, 0.5),
		"desc": "Shotgun burst. Brutal up close."},
	"plasma": {"name": "Plasma Lance", "slot": "primary", "price": 5200, "dmg": 22.0, "cd": 0.42, "speed": 800.0, "life": 2.0, "color": Color(3.0, 0.6, 2.6),
		"desc": "Slow, heavy plasma slugs."},
	"rail": {"name": "Rail Driver", "slot": "primary", "price": 7400, "dmg": 38.0, "cd": 0.85, "speed": 1900.0, "life": 1.4, "color": Color(2.4, 2.4, 3.2),
		"desc": "Hypersonic slug. Rewards precise aim."},
	"hellfire": {"name": "Hellfire Repeater", "slot": "primary", "price": 12000, "dmg": 11.0, "cd": 0.085, "speed": 1150.0, "life": 1.6, "color": Color(3.2, 1.2, 0.3), "unique": true,
		"desc": "Workshop-built. A storm of molten bolts."},
	"starbreaker": {"name": "Starbreaker Rail", "slot": "primary", "price": 22000, "dmg": 70.0, "cd": 0.8, "speed": 2200.0, "life": 1.5, "color": Color(1.6, 2.2, 3.4), "unique": true,
		"desc": "Workshop-built. Punches through anything."},

	"hornet": {"name": "Hornet Missiles", "slot": "secondary", "price": 2400, "ammo": "hornet", "dmg": 48.0, "cd": 0.7, "speed": 420.0, "turn": 2.6, "count": 1,
		"desc": "Homing missiles. Lock a target and let go."},
	"lance": {"name": "Lance Torpedo", "slot": "secondary", "price": 4800, "ammo": "lance", "dmg": 150.0, "cd": 2.0, "speed": 300.0, "turn": 1.0, "count": 1,
		"desc": "Slow, lazy homing, devastating blast."},
	"swarm": {"name": "Swarm Pod", "slot": "secondary", "price": 9000, "ammo": "swarm", "dmg": 20.0, "cd": 1.2, "speed": 480.0, "turn": 3.4, "count": 4, "unique": true,
		"desc": "Workshop-built. Four seeker darts per volley."},

	"shield_1": {"name": "Shield Emitter S", "slot": "utility", "price": 1200, "shield": 60.0, "regen": 8.0, "desc": "+60 shield, 8/s recharge."},
	"shield_2": {"name": "Shield Emitter M", "slot": "utility", "price": 4200, "shield": 120.0, "regen": 11.0, "desc": "+120 shield, 11/s recharge."},
	"aegis": {"name": "Aegis Lattice", "slot": "utility", "price": 14000, "shield": 200.0, "regen": 17.0, "unique": true, "desc": "Workshop-built. +200 shield, 17/s recharge."},
	"armor_1": {"name": "Armor Plating", "slot": "utility", "price": 1000, "hull": 40.0, "desc": "+40 hull."},
	"armor_2": {"name": "Composite Armor", "slot": "utility", "price": 3600, "hull": 95.0, "desc": "+95 hull."},
	"engine_1": {"name": "Ion Overdrive", "slot": "utility", "price": 2800, "speed": 0.15, "desc": "+15% top speed."},
	"ghost": {"name": "Ghost Drive", "slot": "utility", "price": 13000, "speed": 0.3, "boost": 0.4, "unique": true, "desc": "Workshop-built. +30% speed, +40% boost."},
	"cargo_1": {"name": "Cargo Pod", "slot": "utility", "price": 800, "cargo": 12, "desc": "+12 cargo space."},
	"jump_1": {"name": "Jump Capacitor", "slot": "utility", "price": 2400, "jump": 1, "desc": "+1 stargate jump charge."},
	"tractor": {"name": "Tractor Beam", "slot": "utility", "price": 1800, "tractor": 420.0, "desc": "Pulls in loot from 420 m."},
	"nano": {"name": "Nano-Repair Bay", "slot": "utility", "price": 3800, "repair": 0.8, "desc": "Slowly repairs hull in flight."},
	"afterburner": {"name": "Afterburner Tank", "slot": "utility", "price": 2000, "boost": 0.6, "desc": "+60% boost capacity."},
	"targeting": {"name": "Targeting Computer", "slot": "utility", "price": 3200, "assist": 7.0, "desc": "Wider aim assist and auto-attack cone."},
	"salvager": {"name": "Salvage Scanner", "slot": "utility", "price": 3000, "salvage": 1, "unique": true, "desc": "Workshop-built. More parts from every wreck."},
}

const AMMO := {
	"hornet": {"name": "Hornet missile", "price": 45},
	"lance": {"name": "Lance torpedo", "price": 130},
	"swarm": {"name": "Swarm dart pack", "price": 70},
}

const PARTS := {
	"scrap": {"name": "Scrap Metal", "price": 30, "color": Color(0.75, 0.7, 0.65)},
	"circuit": {"name": "Circuit Boards", "price": 95, "color": Color(0.35, 1.0, 0.55)},
	"coil": {"name": "Plasma Coils", "price": 170, "color": Color(1.0, 0.45, 0.85)},
	"crystal": {"name": "Lattice Crystal", "price": 240, "color": Color(0.45, 0.85, 1.0)},
	"void": {"name": "Void Shard", "price": 900, "color": Color(0.75, 0.45, 1.0)},
}

## Blueprints: parts + fee -> item (or ammo). "start": known from the beginning.
## Others drop from elite raiders or are sold by research stations.
const BLUEPRINTS := {
	"bp_pulse_2": {"makes": "pulse_2", "parts": {"scrap": 5, "circuit": 2}, "fee": 250, "start": true},
	"bp_hornet_ammo": {"makes": "ammo:hornet:8", "parts": {"scrap": 3, "coil": 1}, "fee": 0, "start": true},
	"bp_armor_2": {"makes": "armor_2", "parts": {"scrap": 8, "crystal": 1}, "fee": 300, "start": true},
	"bp_salvager": {"makes": "salvager", "parts": {"scrap": 6, "circuit": 3}, "fee": 400, "start": true},
	"bp_swarm": {"makes": "swarm", "parts": {"circuit": 4, "coil": 3, "scrap": 4}, "fee": 900, "price": 3500},
	"bp_hellfire": {"makes": "hellfire", "parts": {"coil": 4, "circuit": 4, "void": 1}, "fee": 1200, "price": 5000},
	"bp_aegis": {"makes": "aegis", "parts": {"crystal": 5, "circuit": 3, "void": 1}, "fee": 1500, "price": 5500},
	"bp_ghost": {"makes": "ghost", "parts": {"coil": 5, "crystal": 3, "void": 2}, "fee": 1500, "price": 6500},
	"bp_starbreaker": {"makes": "starbreaker", "parts": {"void": 3, "crystal": 4, "coil": 4}, "fee": 2500, "price": 9000},
}


static func blueprint_name(bp_id: String) -> String:
	var mk: String = BLUEPRINTS[bp_id]["makes"]
	if mk.begins_with("ammo:"):
		var a := mk.split(":")
		return "%s x%s" % [AMMO[a[1]]["name"], a[2]]
	return GEAR[mk]["name"]


static func sell_value(gear_id: String) -> int:
	return int(GEAR[gear_id]["price"] * 0.5)


static func ship_trade_in(ship_id: String) -> int:
	return int(SHIPS[ship_id]["price"] * 0.6)


static func slot_label(slot: String) -> String:
	return {"primary": "PRIMARY WEAPONS", "secondary": "SECONDARY WEAPONS", "utility": "UTILITY"}[slot]


## Short stat line for a piece of gear.
static func gear_stats(gear_id: String) -> String:
	var g: Dictionary = GEAR[gear_id]
	match g["slot"]:
		"primary":
			var dps: float = g["dmg"] * g.get("pellets", 1) / g["cd"]
			return "%.0f dmg  ·  %.1f shots/s  ·  %.0f DPS" % [g["dmg"] * g.get("pellets", 1), 1.0 / g["cd"], dps]
		"secondary":
			return "%.0f dmg x%d  ·  ammo: %s" % [g["dmg"], g["count"], AMMO[g["ammo"]]["name"]]
	return g["desc"]
