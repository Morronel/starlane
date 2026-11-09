class_name Galaxy
extends RefCounted
## Static description of the playable galaxy: systems, stations, gate links,
## economy and the look of each sky.

## 0.11: the goods live in the economy simulation (scripts/economy.gd).
const COMMODITIES := EconomySim.GOODS

const SYSTEMS := {
	"tessaly": {
		"name": "Tessaly",
		"map": Vector2(0.0, 0.0),
		"links": ["corvan", "nyx", "vesper"],
		"threat": 1,
		"desc": "Quiet core system. Ice mining and frontier medicine.",
		"wonder": {"name": "The Frozen Choir", "kind": "geyser", "desc": "Ice geysers on a shepherd moon that hum when the sun hits them."},
		"stations": [
			{"id": "halcyon", "faction": "haulers", "name": "Halcyon Yard", "kind": "Shipyard & Ice Refinery", "accent": Color(0.25, 0.85, 1.0), "variant": 0,
				"makes": ["water", "shipparts"], "needs": ["ice", "alloy", "electronics", "food"], "deals": ["cells"],
				"ships": ["sparrow", "wren", "mule", "otter"], "gear": ["pulse_1", "ion", "hornet", "shield_1", "armor_1", "cargo_1", "jump_1"], "parts": ["scrap", "circuit"]},
			{"id": "verdant", "faction": "lantern", "name": "Verdant Spire", "kind": "Agri-Medical Habitat", "accent": Color(1.0, 0.65, 0.25), "variant": 1,
				"makes": ["food", "gel", "biomass"], "needs": ["water", "cells", "polymer"], "deals": ["wine"],
				"gear": ["shield_1", "nano", "tractor"], "parts": ["crystal"]},
			{"id": "cinder", "faction": "miners", "name": "Cinder Post", "kind": "Mining Outpost", "accent": Color(1.0, 0.5, 0.3), "variant": 2,
				"makes": ["ice", "ore"], "needs": ["food", "machinery", "cells"], "deals": ["water"],
				"gear": ["scatter", "armor_1", "tractor", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "rest_tessaly", "faction": "haulers", "name": "Mom's Orbit Diner", "kind": "Rest Stop", "rest": true, "accent": Color(1.0, 0.75, 0.55), "variant": 1,
				"makes": ["food"], "needs": ["ice", "gel"], "deals": ["water", "cells"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.1, 0.2, 0.55), "b": Color(0.55, 0.12, 0.45), "c": Color(0.95, 0.55, 0.35), "seed": 3.7,
			"plane": Vector3(0.25, 1.0, 0.35), "sun": Vector3(-0.45, 0.25, -0.85), "sun_col": Color(1.0, 0.88, 0.7),
			"planet_dir": Vector3(0.55, -0.22, -0.8), "planet_size": 0.17, "rings": true,
			"p1": Color(0.85, 0.62, 0.42), "p2": Color(0.55, 0.32, 0.25), "p3": Color(0.95, 0.88, 0.75)},
	},
	"corvan": {
		"name": "Corvan Reach",
		"map": Vector2(1.0, -0.55),
		"links": ["tessaly", "elysia", "vesper"],
		"threat": 1,
		"desc": "Industrial heartland. Foundries hungry for ice and cells.",
		"wonder": {"name": "The Old Foundry Arc", "kind": "arc", "desc": "Half a ring-forge from the first settlers, still glowing after two centuries."},
		"stations": [
			{"id": "ironveil", "faction": "miners", "name": "Ironveil Foundry", "kind": "Heavy Industry", "accent": Color(1.0, 0.45, 0.2), "variant": 2,
				"makes": ["alloy", "machinery"], "needs": ["ore", "cells", "gas", "food"], "deals": ["ice"],
				"ships": ["tortoise"], "gear": ["armor_1", "armor_2", "rail", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "lumen", "faction": "haulers", "name": "Lumen Exchange", "kind": "Trade Hub", "accent": Color(0.95, 0.9, 0.4), "variant": 3,
				"makes": ["electronics", "polymer"], "needs": ["crystal", "gas", "food", "art"], "deals": ["cells", "water", "alloy", "gel", "wine", "spice"],
				"ships": ["sparrow", "wren", "mule", "otter", "nomad"], "gear": ["pulse_1", "shield_1", "cargo_1", "jump_1", "engine_1", "afterburner"], "parts": ["scrap", "circuit", "coil"]},
			{"id": "bastion", "faction": "navy", "name": "Bastion Seven", "kind": "Militia Fortress", "accent": Color(0.55, 0.8, 1.0), "variant": 0,
				"makes": ["shipparts"], "needs": ["food", "gel", "alloy", "electronics", "wine"], "deals": ["cells"],
				"ships": ["kestrel", "corsair", "viper", "warden"], "gear": ["pulse_1", "pulse_2", "ion", "rail", "hornet", "lance", "shield_2", "targeting"], "parts": ["circuit"]},
			{"id": "rest_corvan", "faction": "haulers", "name": "The Greasy Spanner", "kind": "Rest Stop", "rest": true, "accent": Color(1.0, 0.6, 0.35), "variant": 1,
				"makes": ["food"], "needs": ["water", "wine"], "deals": ["cells", "machinery"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.45, 0.22, 0.08), "b": Color(0.7, 0.35, 0.12), "c": Color(1.0, 0.8, 0.45), "seed": 11.2,
			"plane": Vector3(-0.4, 1.0, 0.1), "sun": Vector3(0.6, 0.35, -0.7), "sun_col": Color(1.0, 0.7, 0.45),
			"planet_dir": Vector3(-0.7, -0.1, -0.7), "planet_size": 0.22, "rings": false,
			"p1": Color(0.55, 0.4, 0.32), "p2": Color(0.35, 0.22, 0.18), "p3": Color(0.85, 0.6, 0.4)},
	},
	"nyx": {
		"name": "Nyx Hollow",
		"map": Vector2(-0.95, -0.75),
		"links": ["tessaly", "elysia", "kharos"],
		"threat": 3,
		"desc": "Lawless dark nebula. Raider territory, rich prices.",
		"wonder": {"name": "The Drowned Fleet", "kind": "wreck", "desc": "A dreadnought graveyard in the dark. Nobody agrees on who sank it."},
		"stations": [
			{"id": "blackwake", "faction": "comet", "name": "Blackwake Haven", "kind": "Free Port", "accent": Color(1.0, 0.25, 0.3), "variant": 2,
				"makes": ["stims", "spice"], "needs": ["food", "gel", "machinery", "wine"], "deals": ["relics", "alloy"],
				"gear": ["scatter", "plasma", "hornet", "lance", "afterburner", "engine_1"], "parts": ["coil", "crystal"]},
			{"id": "shard", "faction": "lantern", "name": "Shard Observatory", "kind": "Research Outpost", "accent": Color(0.6, 0.45, 1.0), "variant": 1,
				"makes": ["crystal"], "needs": ["electronics", "food", "cells", "water"], "deals": ["relics"],
				"gear": ["shield_2", "targeting", "nano"], "parts": ["crystal", "circuit"], "blueprints": ["bp_aegis", "bp_swarm"]},
			{"id": "rookery", "faction": "comet", "name": "The Rookery", "kind": "Smugglers' Den", "accent": Color(0.85, 0.55, 0.25), "variant": 2,
				"makes": ["pets", "relics"], "needs": ["gel", "stims", "alloy", "electronics"], "deals": ["wine", "spice"],
				"ships": ["phantom"], "gear": ["ion", "plasma", "tractor", "cargo_1", "jump_1"], "parts": ["scrap", "coil", "void"], "blueprints": ["bp_hellfire"]},
			{"id": "rest_nyx", "faction": "haulers", "name": "Last Light Inn", "kind": "Rest Stop", "rest": true, "accent": Color(1.0, 0.45, 0.5), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["stims", "spice"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.35, 0.03, 0.12), "b": Color(0.12, 0.03, 0.3), "c": Color(0.95, 0.3, 0.35), "seed": 23.9,
			"plane": Vector3(0.6, 1.0, -0.3), "sun": Vector3(0.2, -0.3, -0.9), "sun_col": Color(1.0, 0.45, 0.4),
			"planet_dir": Vector3(-0.3, 0.35, -0.9), "planet_size": 0.12, "rings": true,
			"p1": Color(0.35, 0.3, 0.45), "p2": Color(0.18, 0.12, 0.25), "p3": Color(0.7, 0.5, 0.75)},
	},
	"elysia": {
		"name": "Elysia Drift",
		"map": Vector2(0.15, -1.55),
		"links": ["corvan", "nyx"],
		"threat": 2,
		"desc": "Luminous gardens and vineyards on the galactic rim.",
		"wonder": {"name": "The Garden Pillars", "kind": "pillars", "desc": "Luminous nebula columns, light-years tall. Painters cry here."},
		"stations": [
			{"id": "aurora", "faction": "haulers", "name": "Aurora Gardens", "kind": "Luxury Habitat", "accent": Color(0.4, 1.0, 0.75), "variant": 1,
				"makes": ["wine", "food", "art"], "needs": ["water", "polymer", "electronics"], "deals": ["pets"],
				"gear": ["shield_1", "shield_2", "nano", "engine_1"], "parts": ["crystal"]},
			{"id": "meridian", "faction": "lantern", "name": "Meridian Spire", "kind": "Science Station", "accent": Color(0.5, 0.75, 1.0), "variant": 3,
				"makes": ["electronics", "gel"], "needs": ["crystal", "cells", "biomass"], "deals": ["water"],
				"ships": ["lark"], "gear": ["targeting", "afterburner", "jump_1", "tractor"], "parts": ["circuit", "crystal"], "blueprints": ["bp_ghost"]},
			{"id": "lantern", "faction": "lantern", "name": "Lantern Abbey", "kind": "Monastic Retreat", "accent": Color(1.0, 0.85, 0.55), "variant": 1,
				"makes": ["art", "spice"], "needs": ["wine", "food", "water", "cells"], "deals": ["pets"],
				"gear": ["shield_2", "nano"], "parts": ["crystal"]},
			{"id": "rest_elysia", "faction": "haulers", "name": "Vineyard Lay-by", "kind": "Rest Stop", "rest": true, "accent": Color(0.6, 1.0, 0.7), "variant": 1,
				"makes": ["wine", "food"], "needs": ["water"], "deals": ["cells", "art"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.05, 0.35, 0.4), "b": Color(0.1, 0.5, 0.35), "c": Color(0.75, 0.95, 1.0), "seed": 41.4,
			"plane": Vector3(0.1, 1.0, 0.6), "sun": Vector3(-0.7, 0.4, -0.55), "sun_col": Color(0.8, 0.95, 1.0),
			"planet_dir": Vector3(0.75, 0.1, -0.65), "planet_size": 0.2, "rings": true,
			"p1": Color(0.45, 0.65, 0.8), "p2": Color(0.25, 0.4, 0.6), "p3": Color(0.85, 0.95, 1.0)},
	},
	"vesper": {
		"name": "Vesper Deep",
		"map": Vector2(1.0, 0.65),
		"links": ["tessaly", "corvan", "kharos"],
		"threat": 2,
		"desc": "Frozen blue giant and the galaxy's best shipwrights.",
		"wonder": {"name": "The Crystal Bloom", "kind": "crystal", "desc": "A frozen comet split open like a geode, the size of a city."},
		"stations": [
			{"id": "frostline", "faction": "miners", "name": "Frostline Depot", "kind": "Ice Refinery", "accent": Color(0.55, 0.9, 1.0), "variant": 0,
				"makes": ["ice", "water"], "needs": ["food", "machinery", "cells"], "deals": ["gas"],
				"ships": ["otter"], "gear": ["cargo_1", "armor_1", "tractor"], "parts": ["scrap", "crystal"]},
			{"id": "academy", "faction": "navy", "name": "Vesper Academy", "kind": "Flight Academy", "accent": Color(0.75, 0.6, 1.0), "variant": 3,
				"makes": ["electronics"], "needs": ["food", "gel", "wine", "shipparts"], "deals": ["cells"],
				"ships": ["lark", "viper"], "gear": ["pulse_2", "targeting", "afterburner", "engine_1", "hornet"], "parts": ["circuit"], "blueprints": ["bp_starbreaker"]},
			{"id": "halo", "faction": "navy", "name": "Halo Drydock", "kind": "Capital Shipyard", "accent": Color(0.9, 0.95, 1.0), "variant": 2,
				"makes": ["shipparts", "machinery"], "needs": ["alloy", "electronics", "polymer", "cells"], "deals": ["ore"],
				"ships": ["wren", "kestrel", "mule", "seraph", "nomad", "warden", "tortoise", "leviathan"], "gear": ["armor_2", "shield_2", "jump_1", "cargo_1", "rail"], "parts": ["scrap", "coil"]},
			{"id": "rest_vesper", "faction": "haulers", "name": "Snowglobe Stop", "kind": "Rest Stop", "rest": true, "accent": Color(0.7, 0.9, 1.0), "variant": 1,
				"makes": ["food", "water"], "needs": ["cells"], "deals": ["ice", "electronics"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.05, 0.12, 0.4), "b": Color(0.25, 0.15, 0.55), "c": Color(0.6, 0.85, 1.0), "seed": 57.3,
			"plane": Vector3(-0.2, 1.0, -0.5), "sun": Vector3(0.3, 0.5, -0.8), "sun_col": Color(0.75, 0.88, 1.0),
			"planet_dir": Vector3(-0.6, -0.25, -0.75), "planet_size": 0.26, "rings": true,
			"p1": Color(0.5, 0.7, 0.95), "p2": Color(0.2, 0.32, 0.6), "p3": Color(0.9, 0.95, 1.0)},
	},
	"kharos": {
		"name": "Kharos Rift",
		"map": Vector2(-0.75, 0.8),
		"links": ["vesper", "nyx"],
		"threat": 3,
		"desc": "A torn, toxic nebula. Mercenaries and strange signals.",
		"wonder": {"name": "The Rift Lighthouse", "kind": "lighthouse", "desc": "An alien beacon that has pulsed every 7 seconds since before humans had fire."},
		"stations": [
			{"id": "ashfall", "faction": "miners", "name": "Ashfall Refinery", "kind": "Gas Refinery", "accent": Color(0.75, 1.0, 0.35), "variant": 2,
				"makes": ["gas", "cells"], "needs": ["food", "water", "machinery"], "deals": ["ore"],
				"gear": ["armor_2", "cargo_1", "nano"], "parts": ["coil", "scrap"]},
			{"id": "talon", "faction": "comet", "name": "Red Talon", "kind": "Mercenary Base", "accent": Color(1.0, 0.3, 0.2), "variant": 0,
				"makes": ["stims"], "needs": ["gel", "shipparts", "wine", "food", "alloy"], "deals": ["relics", "spice"],
				"ships": ["kestrel", "corsair", "seraph", "phantom"], "gear": ["plasma", "rail", "scatter", "lance", "hornet", "shield_2", "afterburner"], "parts": ["coil", "void"]},
			{"id": "oracle", "faction": "lantern", "name": "Oracle Array", "kind": "Deep Research", "accent": Color(0.3, 1.0, 0.8), "variant": 3,
				"makes": ["crystal", "relics"], "needs": ["electronics", "cells", "food", "art"], "deals": ["pets"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "void"], "blueprints": ["bp_aegis", "bp_ghost", "bp_starbreaker"]},
			{"id": "rest_kharos", "faction": "haulers", "name": "Gasp & Go", "kind": "Rest Stop", "rest": true, "accent": Color(0.8, 1.0, 0.45), "variant": 1,
				"makes": ["cells"], "needs": ["food", "water"], "deals": ["gas", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.18, 0.3, 0.05), "b": Color(0.45, 0.2, 0.05), "c": Color(0.85, 1.0, 0.4), "seed": 71.9,
			"plane": Vector3(0.5, 1.0, 0.4), "sun": Vector3(-0.3, 0.2, -0.95), "sun_col": Color(0.95, 1.0, 0.6),
			"planet_dir": Vector3(0.6, 0.3, -0.75), "planet_size": 0.15, "rings": false,
			"p1": Color(0.6, 0.65, 0.3), "p2": Color(0.3, 0.35, 0.12), "p3": Color(0.9, 0.95, 0.6)},
	},
}


static func system(id: String) -> Dictionary:
	return SYSTEMS[id]


static func station(id: String) -> Dictionary:
	for sid in SYSTEMS:
		for st in SYSTEMS[sid]["stations"]:
			if st["id"] == id:
				return st
	return {}


static func system_of(station_id: String) -> String:
	for sid in SYSTEMS:
		for st in SYSTEMS[sid]["stations"]:
			if st["id"] == station_id:
				return sid
	return "tessaly"


static func station_name(id: String) -> String:
	var st := station(id)
	return st.get("name", id)


static func all_station_ids() -> Array:
	var out := []
	for sid in SYSTEMS:
		for st in SYSTEMS[sid]["stations"]:
			out.append(st["id"])
	return out


## Breadth-first hop count between systems through stargates.
static func hops(from: String, to: String) -> int:
	if from == to:
		return 0
	var seen := {from: 0}
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n in SYSTEMS[cur]["links"]:
			if not seen.has(n):
				seen[n] = seen[cur] + 1
				if n == to:
					return seen[n]
				queue.append(n)
	return 99


## Path of system ids from -> to (inclusive).
static func path(from: String, to: String) -> Array:
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to:
			break
		for n in SYSTEMS[cur]["links"]:
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	if not prev.has(to):
		return []
	var p := [to]
	while p[0] != from:
		p.push_front(prev[p[0]])
	return p
