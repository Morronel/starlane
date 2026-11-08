class_name Galaxy
extends RefCounted
## Static description of the playable galaxy: systems, stations, gate links,
## economy and the look of each sky.

const COMMODITIES := {
	"ice": {"name": "Ice Cores", "base": 40, "color": Color(0.6, 0.85, 1.0)},
	"cells": {"name": "Fusion Cells", "base": 120, "color": Color(0.4, 1.0, 0.6)},
	"alloy": {"name": "Hull Alloys", "base": 180, "color": Color(0.75, 0.75, 0.8)},
	"gel": {"name": "Medical Gel", "base": 260, "color": Color(1.0, 0.45, 0.55)},
	"wine": {"name": "Starwine", "base": 420, "color": Color(0.85, 0.5, 1.0)},
}

const SYSTEMS := {
	"tessaly": {
		"name": "Tessaly",
		"map": Vector2(0.0, 0.0),
		"links": ["corvan", "nyx", "vesper"],
		"threat": 1,
		"desc": "Quiet core system. Ice mining and frontier medicine.",
		"stations": [
			{"id": "halcyon", "name": "Halcyon Yard", "kind": "Shipyard & Ice Refinery", "accent": Color(0.25, 0.85, 1.0), "variant": 0,
				"prices": {"ice": 0.7, "cells": 0.9, "alloy": 1.1, "gel": 1.2, "wine": 1.1},
				"ships": ["sparrow", "wren", "mule"], "gear": ["pulse_1", "ion", "hornet", "shield_1", "armor_1", "cargo_1", "jump_1"], "parts": ["scrap", "circuit"]},
			{"id": "verdant", "name": "Verdant Spire", "kind": "Agri-Medical Habitat", "accent": Color(1.0, 0.65, 0.25), "variant": 1,
				"prices": {"ice": 1.35, "cells": 1.2, "alloy": 1.05, "gel": 0.85, "wine": 1.25},
				"gear": ["shield_1", "nano", "tractor"], "parts": ["crystal"]},
			{"id": "cinder", "name": "Cinder Post", "kind": "Mining Outpost", "accent": Color(1.0, 0.5, 0.3), "variant": 2,
				"prices": {"ice": 0.8, "cells": 1.3, "alloy": 0.85, "gel": 1.4, "wine": 1.3},
				"gear": ["scatter", "armor_1", "tractor", "cargo_1"], "parts": ["scrap", "coil"]},
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
		"stations": [
			{"id": "ironveil", "name": "Ironveil Foundry", "kind": "Heavy Industry", "accent": Color(1.0, 0.45, 0.2), "variant": 2,
				"prices": {"ice": 1.3, "cells": 1.35, "alloy": 0.7, "gel": 1.15, "wine": 1.3},
				"gear": ["armor_1", "armor_2", "rail", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "lumen", "name": "Lumen Exchange", "kind": "Trade Hub", "accent": Color(0.95, 0.9, 0.4), "variant": 3,
				"prices": {"ice": 1.05, "cells": 0.75, "alloy": 1.0, "gel": 1.0, "wine": 0.9},
				"ships": ["sparrow", "wren", "mule"], "gear": ["pulse_1", "shield_1", "cargo_1", "jump_1", "engine_1", "afterburner"], "parts": ["scrap", "circuit", "coil"]},
			{"id": "bastion", "name": "Bastion Seven", "kind": "Militia Fortress", "accent": Color(0.55, 0.8, 1.0), "variant": 0,
				"prices": {"ice": 1.2, "cells": 1.1, "alloy": 1.3, "gel": 1.35, "wine": 1.45},
				"ships": ["kestrel", "corsair"], "gear": ["pulse_1", "pulse_2", "ion", "rail", "hornet", "lance", "shield_2", "targeting"], "parts": ["circuit"]},
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
		"stations": [
			{"id": "blackwake", "name": "Blackwake Haven", "kind": "Free Port", "accent": Color(1.0, 0.25, 0.3), "variant": 2,
				"prices": {"ice": 1.2, "cells": 1.25, "alloy": 1.35, "gel": 1.55, "wine": 0.65},
				"gear": ["scatter", "plasma", "hornet", "lance", "afterburner", "engine_1"], "parts": ["coil", "crystal"]},
			{"id": "shard", "name": "Shard Observatory", "kind": "Research Outpost", "accent": Color(0.6, 0.45, 1.0), "variant": 1,
				"prices": {"ice": 1.1, "cells": 1.4, "alloy": 1.3, "gel": 1.3, "wine": 1.2},
				"gear": ["shield_2", "targeting", "nano"], "parts": ["crystal", "circuit"], "blueprints": ["bp_aegis", "bp_swarm"]},
			{"id": "rookery", "name": "The Rookery", "kind": "Smugglers' Den", "accent": Color(0.85, 0.55, 0.25), "variant": 2,
				"prices": {"ice": 1.45, "cells": 1.0, "alloy": 0.95, "gel": 1.6, "wine": 0.55},
				"gear": ["ion", "plasma", "tractor", "cargo_1", "jump_1"], "parts": ["scrap", "coil", "void"], "blueprints": ["bp_hellfire"]},
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
		"stations": [
			{"id": "aurora", "name": "Aurora Gardens", "kind": "Luxury Habitat", "accent": Color(0.4, 1.0, 0.75), "variant": 1,
				"prices": {"ice": 1.15, "cells": 1.1, "alloy": 1.25, "gel": 1.05, "wine": 0.6},
				"gear": ["shield_1", "shield_2", "nano", "engine_1"], "parts": ["crystal"]},
			{"id": "meridian", "name": "Meridian Spire", "kind": "Science Station", "accent": Color(0.5, 0.75, 1.0), "variant": 3,
				"prices": {"ice": 0.85, "cells": 1.15, "alloy": 1.2, "gel": 0.8, "wine": 1.35},
				"gear": ["targeting", "afterburner", "jump_1", "tractor"], "parts": ["circuit", "crystal"], "blueprints": ["bp_ghost"]},
			{"id": "lantern", "name": "Lantern Abbey", "kind": "Monastic Retreat", "accent": Color(1.0, 0.85, 0.55), "variant": 1,
				"prices": {"ice": 1.25, "cells": 0.95, "alloy": 1.4, "gel": 0.9, "wine": 1.5},
				"gear": ["shield_2", "nano"], "parts": ["crystal"]},
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
		"stations": [
			{"id": "frostline", "name": "Frostline Depot", "kind": "Ice Refinery", "accent": Color(0.55, 0.9, 1.0), "variant": 0,
				"prices": {"ice": 0.6, "cells": 1.15, "alloy": 1.2, "gel": 1.25, "wine": 1.2},
				"gear": ["cargo_1", "armor_1", "tractor"], "parts": ["scrap", "crystal"]},
			{"id": "academy", "name": "Vesper Academy", "kind": "Flight Academy", "accent": Color(0.75, 0.6, 1.0), "variant": 3,
				"prices": {"ice": 1.2, "cells": 0.85, "alloy": 1.15, "gel": 1.1, "wine": 1.4},
				"gear": ["pulse_2", "targeting", "afterburner", "engine_1", "hornet"], "parts": ["circuit"], "blueprints": ["bp_starbreaker"]},
			{"id": "halo", "name": "Halo Drydock", "kind": "Capital Shipyard", "accent": Color(0.9, 0.95, 1.0), "variant": 2,
				"prices": {"ice": 1.1, "cells": 1.2, "alloy": 0.8, "gel": 1.3, "wine": 1.25},
				"ships": ["wren", "kestrel", "mule", "seraph"], "gear": ["armor_2", "shield_2", "jump_1", "cargo_1", "rail"], "parts": ["scrap", "coil"]},
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
		"stations": [
			{"id": "ashfall", "name": "Ashfall Refinery", "kind": "Gas Refinery", "accent": Color(0.75, 1.0, 0.35), "variant": 2,
				"prices": {"ice": 1.4, "cells": 0.65, "alloy": 1.25, "gel": 1.35, "wine": 1.15},
				"gear": ["armor_2", "cargo_1", "nano"], "parts": ["coil", "scrap"]},
			{"id": "talon", "name": "Red Talon", "kind": "Mercenary Base", "accent": Color(1.0, 0.3, 0.2), "variant": 0,
				"prices": {"ice": 1.3, "cells": 1.2, "alloy": 1.4, "gel": 1.7, "wine": 0.9},
				"ships": ["kestrel", "corsair", "seraph"], "gear": ["plasma", "rail", "scatter", "lance", "hornet", "shield_2", "afterburner"], "parts": ["coil", "void"]},
			{"id": "oracle", "name": "Oracle Array", "kind": "Deep Research", "accent": Color(0.3, 1.0, 0.8), "variant": 3,
				"prices": {"ice": 1.15, "cells": 1.3, "alloy": 1.35, "gel": 1.2, "wine": 1.3},
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "void"], "blueprints": ["bp_aegis", "bp_ghost", "bp_starbreaker"]},
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


## Best place to sell a commodity, for market hints.
static func best_sell(item: String) -> Dictionary:
	var best := {}
	var best_m := 0.0
	for sid in SYSTEMS:
		for st in SYSTEMS[sid]["stations"]:
			var m: float = st["prices"][item]
			if m > best_m:
				best_m = m
				best = {"station": st["id"], "name": st["name"], "system": SYSTEMS[sid]["name"], "mult": m}
	return best
