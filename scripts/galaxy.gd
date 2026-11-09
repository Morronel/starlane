class_name Galaxy
extends RefCounted
## Static description of the playable galaxy: systems, stations, gate links,
## economy and the look of each sky.

## 0.11: the goods live in the economy simulation (scripts/economy.gd).
const COMMODITIES := EconomySim.GOODS

const SYSTEMS := {
	"tessaly": {
		"name": "Tessaly",
		"map": Vector2(0.00, -0.10),
		"links": ["corvan", "aldmere", "vesper", "brightwater", "elysia"],
		"region": "Core Worlds",
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
		"map": Vector2(1.10, -0.60),
		"links": ["tessaly", "vesper", "orchard"],
		"region": "Core Worlds",
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
		"map": Vector2(-2.10, -0.40),
		"links": ["aldmere", "kharos", "sable", "solace"],
		"region": "Dark Reach",
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
		"map": Vector2(-0.40, -1.60),
		"links": ["tessaly", "solace", "orchard"],
		"region": "Rim Gardens",
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
		"map": Vector2(1.20, 0.50),
		"links": ["tessaly", "corvan", "farhaven"],
		"region": "Core Worlds",
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
		"map": Vector2(-2.00, 0.70),
		"links": ["nyx", "gloam", "sable"],
		"region": "Dark Reach",
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
	"aldmere": {
		"name": "Aldmere",
		"map": Vector2(-1.00, -0.60),
		"links": ["tessaly", "solace", "nyx", "gloam"],
		"region": "Core Worlds",
		"threat": 1,
		"desc": "Breadbasket of the core. Wheat domes as far as the scanner sees.",
		"wonder": {"name": "The Harvest Moon", "kind": "geyser", "desc": "A moon wrapped in greenhouse glass, glowing amber at dusk."},
		"stations": [
			{"id": "aldm_aldmere", "faction": "haulers", "name": "Aldmere Granary", "kind": "Agri Dome", "accent": Color(1.00, 0.78, 0.45), "variant": 1,
				"makes": ["food", "biomass"], "needs": ["water", "cells", "polymer"], "deals": ["wine"],
				"gear": ["shield_1", "nano", "tractor"], "parts": ["crystal"]},
			{"id": "aldm_copperbe", "faction": "miners", "name": "Copperbell Works", "kind": "Foundry", "accent": Color(0.96, 1.00, 0.45), "variant": 3,
				"makes": ["alloy", "machinery"], "needs": ["ore", "cells", "food"], "deals": ["ice"],
				"gear": ["armor_1", "armor_2", "rail"], "parts": ["scrap", "coil"]},
			{"id": "aldm_ophira", "faction": "lantern", "name": "St. Ophira Hospital Ring", "kind": "Research Station", "accent": Color(0.69, 1.00, 0.45), "variant": 1,
				"makes": ["crystal", "gel"], "needs": ["electronics", "food", "cells"], "deals": ["relics"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "circuit"]},
			{"id": "rest_aldmere", "faction": "haulers", "name": "Pancake Point", "kind": "Rest Stop", "rest": true, "accent": Color(0.60, 0.76, 1.00), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.35, 0.24, 0.07), "b": Color(0.34, 0.45, 0.11), "c": Color(1.00, 0.95, 0.50), "seed": 156.7,
			"plane": Vector3(-0.27, 1.00, -0.33), "sun": Vector3(0.33, 0.37, -0.80), "sun_col": Color(1.00, 0.93, 0.70),
			"planet_dir": Vector3(0.63, -0.25, -0.75), "planet_size": 0.18, "rings": true,
			"p1": Color(0.68, 0.75, 0.41), "p2": Color(0.36, 0.40, 0.20), "p3": Color(0.91, 0.95, 0.76)},
	},
	"brightwater": {
		"name": "Brightwater",
		"map": Vector2(0.10, 1.00),
		"links": ["tessaly", "gloam", "cinderfall"],
		"region": "Core Worlds",
		"threat": 1,
		"desc": "Water world refineries and the core's busiest shipyards.",
		"wonder": {"name": "The Glass Falls", "kind": "crystal", "desc": "A frozen waterfall hanging in orbit, light pouring through it."},
		"stations": [
			{"id": "brig_brightwa", "faction": "miners", "name": "Brightwater Springs", "kind": "Refinery", "accent": Color(0.45, 0.83, 1.00), "variant": 2,
				"makes": ["cells", "water"], "needs": ["ice", "gas", "food"], "deals": ["ore"],
				"gear": ["cargo_1", "armor_1", "nano"], "parts": ["scrap", "coil"]},
			{"id": "brig_kestrel", "faction": "navy", "name": "Kestrel Row Yards", "kind": "Shipyard", "accent": Color(0.45, 0.57, 1.00), "variant": 1,
				"makes": ["shipparts"], "needs": ["alloy", "electronics", "machinery"], "deals": ["cells"],
				"gear": ["pulse_1", "shield_1", "cargo_1", "jump_1", "afterburner"], "parts": ["scrap", "circuit"], "ships": ["sparrow", "wren", "otter", "kestrel", "nomad"]},
			{"id": "brig_tidewell", "faction": "haulers", "name": "Tidewell Fabricators", "kind": "Fabricator", "accent": Color(0.59, 0.45, 1.00), "variant": 1,
				"makes": ["electronics", "polymer"], "needs": ["crystal", "gas", "food"], "deals": ["cells"],
				"gear": ["pulse_1", "shield_1", "engine_1"], "parts": ["circuit", "scrap"]},
			{"id": "rest_brightwater", "faction": "haulers", "name": "The Sleepy Comet Motel", "kind": "Rest Stop", "rest": true, "accent": Color(1.00, 0.72, 0.60), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.07, 0.27, 0.35), "b": Color(0.12, 0.11, 0.45), "c": Color(0.50, 0.70, 1.00), "seed": 83.6,
			"plane": Vector3(0.01, 1.00, -0.57), "sun": Vector3(-0.42, 0.36, -0.80), "sun_col": Color(0.70, 0.86, 1.00),
			"planet_dir": Vector3(0.07, -0.17, -0.75), "planet_size": 0.20, "rings": true,
			"p1": Color(0.41, 0.45, 0.75), "p2": Color(0.20, 0.22, 0.40), "p3": Color(0.76, 0.78, 0.95)},
	},
	"solace": {
		"name": "Solace",
		"map": Vector2(-1.50, -1.50),
		"links": ["elysia", "aldmere", "nyx"],
		"region": "Rim Gardens",
		"threat": 1,
		"desc": "Quiet cloisters and soft green light. The Lantern Order's home.",
		"wonder": {"name": "The Bell Pillars", "kind": "pillars", "desc": "Nebula columns that ring on the radio when you pass."},
		"stations": [
			{"id": "sola_solace", "faction": "lantern", "name": "Solace Cloister", "kind": "Research Station", "accent": Color(0.45, 1.00, 0.60), "variant": 3,
				"makes": ["crystal", "gel"], "needs": ["electronics", "food", "cells"], "deals": ["relics"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "circuit"], "blueprints": ["bp_aegis"]},
			{"id": "sola_greenman", "faction": "haulers", "name": "Greenmantle Domes", "kind": "Agri Dome", "accent": Color(0.45, 1.00, 0.87), "variant": 2,
				"makes": ["food", "biomass"], "needs": ["water", "cells", "polymer"], "deals": ["wine"],
				"gear": ["shield_1", "nano", "tractor"], "parts": ["crystal"]},
			{"id": "sola_hushwate", "faction": "miners", "name": "Hushwater Depot", "kind": "Refinery", "accent": Color(0.45, 0.87, 1.00), "variant": 0,
				"makes": ["cells", "water"], "needs": ["ice", "gas", "food"], "deals": ["ore"],
				"gear": ["cargo_1", "armor_1", "nano"], "parts": ["scrap", "coil"]},
			{"id": "rest_solace", "faction": "haulers", "name": "Teapot Station", "kind": "Rest Stop", "rest": true, "accent": Color(1.00, 0.60, 0.89), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.07, 0.35, 0.15), "b": Color(0.11, 0.45, 0.45), "c": Color(0.50, 1.00, 0.79), "seed": 177.1,
			"plane": Vector3(0.37, 1.00, 0.24), "sun": Vector3(-0.22, 0.16, -0.80), "sun_col": Color(0.70, 1.00, 0.84),
			"planet_dir": Vector3(0.73, -0.10, -0.75), "planet_size": 0.13, "rings": true,
			"p1": Color(0.41, 0.75, 0.71), "p2": Color(0.20, 0.40, 0.38), "p3": Color(0.76, 0.95, 0.93)},
	},
	"orchard": {
		"name": "Orchard",
		"map": Vector2(0.70, -1.50),
		"links": ["elysia", "marigold", "corvan"],
		"region": "Rim Gardens",
		"threat": 1,
		"desc": "Fruit-tree habitats and the best cider in the Rim.",
		"wonder": {"name": "The Seed Ark", "kind": "wreck", "desc": "A colony ark that never landed, now a drifting forest."},
		"stations": [
			{"id": "orch_orchard", "faction": "haulers", "name": "Orchard Prime", "kind": "Agri Dome", "accent": Color(0.72, 1.00, 0.45), "variant": 1,
				"makes": ["food", "biomass"], "needs": ["water", "cells", "polymer"], "deals": ["wine"],
				"gear": ["shield_1", "nano", "tractor"], "parts": ["crystal"]},
			{"id": "orch_applewoo", "faction": "haulers", "name": "Applewood Exchange", "kind": "Pleasure Habitat", "accent": Color(0.46, 1.00, 0.45), "variant": 2,
				"makes": ["wine", "art"], "needs": ["food", "water", "electronics"], "deals": ["pets", "spice"],
				"gear": ["shield_2", "nano", "engine_1"], "parts": ["crystal"]},
			{"id": "orch_bramble", "faction": "haulers", "name": "Bramble Fab", "kind": "Fabricator", "accent": Color(0.45, 1.00, 0.70), "variant": 1,
				"makes": ["electronics", "polymer"], "needs": ["crystal", "gas", "food"], "deals": ["cells"],
				"gear": ["pulse_1", "shield_1", "engine_1"], "parts": ["circuit", "scrap"]},
			{"id": "rest_orchard", "faction": "haulers", "name": "Cider Stop", "kind": "Rest Stop", "rest": true, "accent": Color(0.80, 0.60, 1.00), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.21, 0.35, 0.07), "b": Color(0.11, 0.45, 0.19), "c": Color(0.60, 1.00, 0.50), "seed": 91.6,
			"plane": Vector3(0.12, 1.00, 0.37), "sun": Vector3(0.32, 0.31, -0.80), "sun_col": Color(0.80, 1.00, 0.70),
			"planet_dir": Vector3(0.76, -0.07, -0.75), "planet_size": 0.20, "rings": false,
			"p1": Color(0.41, 0.75, 0.45), "p2": Color(0.20, 0.40, 0.22), "p3": Color(0.76, 0.95, 0.78)},
	},
	"marigold": {
		"name": "Marigold",
		"map": Vector2(1.80, -1.60),
		"links": ["orchard", "verena"],
		"region": "Rim Gardens",
		"threat": 2,
		"desc": "A gold-lit bazaar system. Everything is for sale, twice.",
		"wonder": {"name": "The Golden Arc", "kind": "arc", "desc": "A ring-segment plated in gold. Nobody admits to building it."},
		"stations": [
			{"id": "mari_marigold", "faction": "haulers", "name": "Marigold Bazaar", "kind": "Pleasure Habitat", "accent": Color(1.00, 0.85, 0.45), "variant": 1,
				"makes": ["wine", "art"], "needs": ["food", "water", "electronics"], "deals": ["pets", "spice"],
				"gear": ["shield_2", "nano", "engine_1"], "parts": ["crystal"]},
			{"id": "mari_saffron", "faction": "comet", "name": "Saffron Spire", "kind": "Free Port", "accent": Color(0.89, 1.00, 0.45), "variant": 3,
				"makes": ["stims", "spice"], "needs": ["food", "gel", "alloy"], "deals": ["relics", "wine"],
				"gear": ["scatter", "plasma", "hornet", "afterburner"], "parts": ["coil", "void"]},
			{"id": "mari_petalwor", "faction": "haulers", "name": "Petalworks", "kind": "Fabricator", "accent": Color(0.63, 1.00, 0.45), "variant": 1,
				"makes": ["electronics", "polymer"], "needs": ["crystal", "gas", "food"], "deals": ["cells"],
				"gear": ["pulse_1", "shield_1", "engine_1"], "parts": ["circuit", "scrap"]},
			{"id": "rest_marigold", "faction": "haulers", "name": "Honey Pot Diner", "kind": "Rest Stop", "rest": true, "accent": Color(0.60, 0.71, 1.00), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.35, 0.27, 0.07), "b": Color(0.30, 0.45, 0.11), "c": Color(0.99, 1.00, 0.50), "seed": 179.5,
			"plane": Vector3(0.43, 1.00, 0.09), "sun": Vector3(0.29, 0.12, -0.80), "sun_col": Color(1.00, 0.97, 0.70),
			"planet_dir": Vector3(-0.44, -0.13, -0.75), "planet_size": 0.13, "rings": false,
			"p1": Color(0.64, 0.75, 0.41), "p2": Color(0.34, 0.40, 0.20), "p3": Color(0.89, 0.95, 0.76)},
	},
	"verena": {
		"name": "Verena",
		"map": Vector2(2.70, -0.90),
		"links": ["marigold", "farhaven"],
		"region": "Rim Gardens",
		"threat": 2,
		"desc": "Navy watchtowers over the vineyards at the edge of the Rim.",
		"wonder": {"name": "The Watchtower", "kind": "lighthouse", "desc": "An old navy beacon, still sweeping for ships that never came home."},
		"stations": [
			{"id": "vere_verena", "faction": "navy", "name": "Verena Watch", "kind": "Navy Outpost", "accent": Color(0.89, 0.45, 1.00), "variant": 0,
				"makes": ["shipparts"], "needs": ["food", "gel", "alloy", "wine"], "deals": ["cells"],
				"gear": ["pulse_2", "rail", "hornet", "lance", "shield_2", "targeting"], "parts": ["circuit"], "ships": ["viper", "kestrel", "warden"]},
			{"id": "vere_lastligh", "faction": "haulers", "name": "Lastlight Vineyards", "kind": "Pleasure Habitat", "accent": Color(1.00, 0.45, 0.85), "variant": 2,
				"makes": ["wine", "art"], "needs": ["food", "water", "electronics"], "deals": ["pets", "spice"],
				"gear": ["shield_2", "nano", "engine_1"], "parts": ["crystal"]},
			{"id": "vere_glasshou", "faction": "lantern", "name": "Glasshouse Labs", "kind": "Research Station", "accent": Color(1.00, 0.45, 0.58), "variant": 1,
				"makes": ["crystal", "gel"], "needs": ["electronics", "food", "cells"], "deals": ["relics"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "circuit"]},
			{"id": "rest_verena", "faction": "haulers", "name": "Edge of the Map Café", "kind": "Rest Stop", "rest": true, "accent": Color(0.68, 1.00, 0.60), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.29, 0.07, 0.35), "b": Color(0.45, 0.11, 0.27), "c": Color(1.00, 0.50, 0.95), "seed": 107.9,
			"plane": Vector3(-0.27, 1.00, 0.16), "sun": Vector3(-0.19, 0.25, -0.80), "sun_col": Color(0.99, 0.70, 1.00),
			"planet_dir": Vector3(-0.46, -0.14, -0.75), "planet_size": 0.25, "rings": true,
			"p1": Color(0.75, 0.41, 0.61), "p2": Color(0.40, 0.20, 0.32), "p3": Color(0.95, 0.76, 0.87)},
	},
	"gloam": {
		"name": "Gloam",
		"map": Vector2(-0.95, 0.70),
		"links": ["kharos", "ashgrave", "brightwater", "aldmere"],
		"region": "Dark Reach",
		"threat": 2,
		"desc": "Murky nebula markets lit by lamps and bad decisions.",
		"wonder": {"name": "The Sunken Choir", "kind": "pillars", "desc": "Dark columns humming with static choirs."},
		"stations": [
			{"id": "gloa_gloam", "faction": "comet", "name": "Gloam Market", "kind": "Free Port", "accent": Color(0.63, 0.45, 1.00), "variant": 2,
				"makes": ["stims", "spice"], "needs": ["food", "gel", "alloy"], "deals": ["relics", "wine"],
				"gear": ["scatter", "plasma", "hornet", "afterburner"], "parts": ["coil", "void"]},
			{"id": "gloa_murkwell", "faction": "miners", "name": "Murkwell Mine", "kind": "Mining Outpost", "accent": Color(0.89, 0.45, 1.00), "variant": 3,
				"makes": ["ore", "ice"], "needs": ["food", "machinery", "cells"], "deals": ["water"],
				"gear": ["armor_1", "tractor", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "gloa_lampligh", "faction": "lantern", "name": "The Lamplighter", "kind": "Research Station", "accent": Color(1.00, 0.45, 0.85), "variant": 1,
				"makes": ["crystal", "gel"], "needs": ["electronics", "food", "cells"], "deals": ["relics"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "circuit"]},
			{"id": "rest_gloam", "faction": "haulers", "name": "Night Owl Rest", "kind": "Rest Stop", "rest": true, "accent": Color(0.87, 1.00, 0.60), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.16, 0.07, 0.35), "b": Color(0.45, 0.11, 0.44), "c": Color(0.81, 0.50, 1.00), "seed": 157.8,
			"plane": Vector3(-0.39, 1.00, 0.27), "sun": Vector3(-0.47, 0.25, -0.80), "sun_col": Color(0.85, 0.70, 1.00),
			"planet_dir": Vector3(0.78, 0.08, -0.75), "planet_size": 0.20, "rings": false,
			"p1": Color(0.72, 0.41, 0.75), "p2": Color(0.38, 0.20, 0.40), "p3": Color(0.93, 0.76, 0.95)},
	},
	"ashgrave": {
		"name": "Ashgrave",
		"map": Vector2(-1.20, 1.70),
		"links": ["gloam"],
		"region": "Dark Reach",
		"threat": 3,
		"desc": "Ash storms, deep pits and people who don't ask questions.",
		"wonder": {"name": "The Bone Fleet", "kind": "wreck", "desc": "White hulls of an old war fleet, picked clean."},
		"stations": [
			{"id": "ashg_ashgrave", "faction": "miners", "name": "Ashgrave Pit", "kind": "Mining Outpost", "accent": Color(1.00, 0.61, 0.45), "variant": 2,
				"makes": ["ore", "ice"], "needs": ["food", "machinery", "cells"], "deals": ["water"],
				"gear": ["armor_1", "tractor", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "ashg_cinderja", "faction": "miners", "name": "Cinderjaw Foundry", "kind": "Foundry", "accent": Color(1.00, 0.88, 0.45), "variant": 3,
				"makes": ["alloy", "machinery"], "needs": ["ore", "cells", "food"], "deals": ["ice"],
				"gear": ["armor_1", "armor_2", "rail"], "parts": ["scrap", "coil"]},
			{"id": "ashg_grave", "faction": "comet", "name": "Grave Harbour", "kind": "Free Port", "accent": Color(0.86, 1.00, 0.45), "variant": 0,
				"makes": ["stims", "spice"], "needs": ["food", "gel", "alloy"], "deals": ["relics", "wine"],
				"gear": ["scatter", "plasma", "hornet", "afterburner"], "parts": ["coil", "void"], "blueprints": ["bp_hellfire"]},
			{"id": "rest_ashgrave", "faction": "haulers", "name": "Last Chance Grill", "kind": "Rest Stop", "rest": true, "accent": Color(0.60, 0.88, 1.00), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.35, 0.15, 0.07), "b": Color(0.44, 0.45, 0.11), "c": Color(1.00, 0.80, 0.50), "seed": 162.2,
			"plane": Vector3(0.33, 1.00, -0.33), "sun": Vector3(-0.66, 0.23, -0.80), "sun_col": Color(1.00, 0.84, 0.70),
			"planet_dir": Vector3(-0.37, -0.17, -0.75), "planet_size": 0.25, "rings": false,
			"p1": Color(0.75, 0.72, 0.41), "p2": Color(0.40, 0.38, 0.20), "p3": Color(0.95, 0.93, 0.76)},
	},
	"sable": {
		"name": "Sable",
		"map": Vector2(-3.00, 0.10),
		"links": ["nyx", "kharos"],
		"region": "Dark Reach",
		"threat": 3,
		"desc": "Black rock and blacker markets. Mercenary country.",
		"wonder": {"name": "The Black Lighthouse", "kind": "lighthouse", "desc": "A beacon that shines darkness. Instruments disagree about it."},
		"stations": [
			{"id": "sabl_sable", "faction": "comet", "name": "Sable Rock", "kind": "Free Port", "accent": Color(1.00, 0.45, 0.71), "variant": 2,
				"makes": ["stims", "spice"], "needs": ["food", "gel", "alloy"], "deals": ["relics", "wine"],
				"gear": ["scatter", "plasma", "hornet", "afterburner"], "parts": ["coil", "void"]},
			{"id": "sabl_hollowme", "faction": "miners", "name": "Hollowmere Refinery", "kind": "Gas Skimmer", "accent": Color(1.00, 0.45, 0.45), "variant": 3,
				"makes": ["gas"], "needs": ["food", "machinery", "cells"], "deals": ["ice"],
				"gear": ["armor_1", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "sabl_obsidian", "faction": "navy", "name": "Obsidian Spire", "kind": "Navy Outpost", "accent": Color(1.00, 0.71, 0.45), "variant": 2,
				"makes": ["shipparts"], "needs": ["food", "gel", "alloy", "wine"], "deals": ["cells"],
				"gear": ["pulse_2", "rail", "hornet", "lance", "shield_2", "targeting"], "parts": ["circuit"], "ships": ["corsair", "phantom", "seraph"]},
			{"id": "rest_sable", "faction": "haulers", "name": "Dead Calm Diner", "kind": "Rest Stop", "rest": true, "accent": Color(0.60, 1.00, 0.81), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.35, 0.07, 0.20), "b": Color(0.45, 0.19, 0.11), "c": Color(1.00, 0.50, 0.59), "seed": 185.2,
			"plane": Vector3(0.19, 1.00, -0.13), "sun": Vector3(0.58, 0.28, -0.80), "sun_col": Color(1.00, 0.70, 0.79),
			"planet_dir": Vector3(-0.38, -0.15, -0.75), "planet_size": 0.20, "rings": true,
			"p1": Color(0.75, 0.45, 0.41), "p2": Color(0.40, 0.22, 0.20), "p3": Color(0.95, 0.78, 0.76)},
	},
	"farhaven": {
		"name": "Farhaven",
		"map": Vector2(2.20, 0.00),
		"links": ["vesper", "wayfarer", "verena"],
		"region": "The Frontier",
		"threat": 2,
		"desc": "First stop past the core. Pioneers, prospectors and flapjacks.",
		"wonder": {"name": "The Pioneer Arc", "kind": "arc", "desc": "The first gate-builders' scaffold, left standing as a monument."},
		"stations": [
			{"id": "farh_farhaven", "faction": "navy", "name": "Farhaven Landing", "kind": "Shipyard", "accent": Color(1.00, 0.94, 0.45), "variant": 0,
				"makes": ["shipparts"], "needs": ["alloy", "electronics", "machinery"], "deals": ["cells"],
				"gear": ["pulse_1", "shield_1", "cargo_1", "jump_1", "afterburner"], "parts": ["scrap", "circuit"], "ships": ["otter", "lark", "mule", "nomad", "tortoise"]},
			{"id": "farh_pioneer", "faction": "haulers", "name": "Pioneer Granary", "kind": "Agri Dome", "accent": Color(0.79, 1.00, 0.45), "variant": 2,
				"makes": ["food", "biomass"], "needs": ["water", "cells", "polymer"], "deals": ["wine"],
				"gear": ["shield_1", "nano", "tractor"], "parts": ["crystal"]},
			{"id": "farh_wildcat", "faction": "haulers", "name": "Wildcat Fabricators", "kind": "Fabricator", "accent": Color(0.53, 1.00, 0.45), "variant": 1,
				"makes": ["electronics", "polymer"], "needs": ["crystal", "gas", "food"], "deals": ["cells"],
				"gear": ["pulse_1", "shield_1", "engine_1"], "parts": ["circuit", "scrap"]},
			{"id": "rest_farhaven", "faction": "haulers", "name": "Frontier Flapjacks", "kind": "Rest Stop", "rest": true, "accent": Color(0.60, 0.64, 1.00), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.35, 0.32, 0.07), "b": Color(0.24, 0.45, 0.11), "c": Color(0.90, 1.00, 0.50), "seed": 111.5,
			"plane": Vector3(0.48, 1.00, -0.12), "sun": Vector3(-0.39, 0.50, -0.80), "sun_col": Color(0.98, 1.00, 0.70),
			"planet_dir": Vector3(0.02, -0.25, -0.75), "planet_size": 0.13, "rings": false,
			"p1": Color(0.58, 0.75, 0.41), "p2": Color(0.30, 0.40, 0.20), "p3": Color(0.85, 0.95, 0.76)},
	},
	"wayfarer": {
		"name": "Wayfarer",
		"map": Vector2(2.30, 1.10),
		"links": ["farhaven", "drift", "cinderfall"],
		"region": "The Frontier",
		"threat": 2,
		"desc": "Crossroads of the frontier. Traders, drifters and dust.",
		"wonder": {"name": "The Signpost", "kind": "lighthouse", "desc": "An ancient marker pointing somewhere nobody has gone."},
		"stations": [
			{"id": "wayf_wayfarer", "faction": "haulers", "name": "Wayfarer's Crossing", "kind": "Pleasure Habitat", "accent": Color(0.45, 1.00, 0.84), "variant": 1,
				"makes": ["wine", "art"], "needs": ["food", "water", "electronics"], "deals": ["pets", "spice"],
				"gear": ["shield_2", "nano", "engine_1"], "parts": ["crystal"], "ships": ["lark", "nomad", "leviathan"]},
			{"id": "wayf_dustbowl", "faction": "miners", "name": "Dustbowl Mine", "kind": "Mining Outpost", "accent": Color(0.45, 0.90, 1.00), "variant": 3,
				"makes": ["ore", "ice"], "needs": ["food", "machinery", "cells"], "deals": ["water"],
				"gear": ["armor_1", "tractor", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "wayf_signal", "faction": "lantern", "name": "Signal Hill", "kind": "Research Station", "accent": Color(0.45, 0.64, 1.00), "variant": 1,
				"makes": ["crystal", "gel"], "needs": ["electronics", "food", "cells"], "deals": ["relics"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "circuit"], "blueprints": ["bp_ghost"]},
			{"id": "rest_wayfarer", "faction": "haulers", "name": "Wanderer's Rest", "kind": "Rest Stop", "rest": true, "accent": Color(1.00, 0.60, 0.72), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.07, 0.35, 0.27), "b": Color(0.11, 0.31, 0.45), "c": Color(0.50, 1.00, 1.00), "seed": 93.2,
			"plane": Vector3(0.35, 1.00, -0.09), "sun": Vector3(-0.61, 0.25, -0.80), "sun_col": Color(0.70, 1.00, 0.96),
			"planet_dir": Vector3(0.79, 0.02, -0.75), "planet_size": 0.26, "rings": false,
			"p1": Color(0.41, 0.65, 0.75), "p2": Color(0.20, 0.34, 0.40), "p3": Color(0.76, 0.89, 0.95)},
	},
	"drift": {
		"name": "The Drift",
		"map": Vector2(3.30, 0.70),
		"links": ["wayfarer", "quiet_lane"],
		"region": "The Frontier",
		"threat": 3,
		"desc": "Edge of charted space. The signal from beyond gets louder here.",
		"wonder": {"name": "The Frozen Wave", "kind": "crystal", "desc": "A shockwave caught in ice, mid-crash, for a million years."},
		"stations": [
			{"id": "drif_drift", "faction": "comet", "name": "Drift Anchorage", "kind": "Free Port", "accent": Color(0.45, 0.60, 1.00), "variant": 2,
				"makes": ["stims", "spice"], "needs": ["food", "gel", "alloy"], "deals": ["relics", "wine"],
				"gear": ["scatter", "plasma", "hornet", "afterburner"], "parts": ["coil", "void"]},
			{"id": "drif_longwatc", "faction": "miners", "name": "Longwatch Refinery", "kind": "Gas Skimmer", "accent": Color(0.56, 0.45, 1.00), "variant": 3,
				"makes": ["gas"], "needs": ["food", "machinery", "cells"], "deals": ["ice"],
				"gear": ["armor_1", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "drif_halfway", "faction": "haulers", "name": "Halfway House", "kind": "Agri Dome", "accent": Color(0.82, 0.45, 1.00), "variant": 3,
				"makes": ["food", "biomass"], "needs": ["water", "cells", "polymer"], "deals": ["wine"],
				"gear": ["shield_1", "nano", "tractor"], "parts": ["crystal"]},
			{"id": "rest_drift", "faction": "haulers", "name": "Nowhere Noodles", "kind": "Rest Stop", "rest": true, "accent": Color(1.00, 0.89, 0.60), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.07, 0.15, 0.35), "b": Color(0.26, 0.11, 0.45), "c": Color(0.51, 0.50, 1.00), "seed": 183.3,
			"plane": Vector3(0.26, 1.00, 0.22), "sun": Vector3(0.05, 0.21, -0.80), "sun_col": Color(0.70, 0.73, 1.00),
			"planet_dir": Vector3(0.23, -0.23, -0.75), "planet_size": 0.18, "rings": true,
			"p1": Color(0.52, 0.41, 0.75), "p2": Color(0.26, 0.20, 0.40), "p3": Color(0.82, 0.76, 0.95)},
	},
	"cinderfall": {
		"name": "Cinderfall",
		"map": Vector2(1.20, 1.60),
		"links": ["wayfarer", "brightwater"],
		"region": "The Frontier",
		"threat": 3,
		"desc": "Volcanic moons and forge-worlds. Hot, rich and dangerous.",
		"wonder": {"name": "The Ember Geysers", "kind": "geyser", "desc": "Lava fountains on a moon, frozen into glass as they fly."},
		"stations": [
			{"id": "cind_cinderfa", "faction": "miners", "name": "Cinderfall Forge", "kind": "Foundry", "accent": Color(1.00, 0.52, 0.45), "variant": 2,
				"makes": ["alloy", "machinery"], "needs": ["ore", "cells", "food"], "deals": ["ice"],
				"gear": ["armor_1", "armor_2", "rail"], "parts": ["scrap", "coil"]},
			{"id": "cind_emberlin", "faction": "miners", "name": "Emberline Mine", "kind": "Mining Outpost", "accent": Color(1.00, 0.78, 0.45), "variant": 3,
				"makes": ["ore", "ice"], "needs": ["food", "machinery", "cells"], "deals": ["water"],
				"gear": ["armor_1", "tractor", "cargo_1"], "parts": ["scrap", "coil"]},
			{"id": "cind_red", "faction": "navy", "name": "Red Dune Outpost", "kind": "Navy Outpost", "accent": Color(0.96, 1.00, 0.45), "variant": 2,
				"makes": ["shipparts"], "needs": ["food", "gel", "alloy", "wine"], "deals": ["cells"],
				"gear": ["pulse_2", "rail", "hornet", "lance", "shield_2", "targeting"], "parts": ["circuit"], "ships": ["viper", "corsair", "warden"]},
			{"id": "rest_cinderfall", "faction": "haulers", "name": "Hot Rocks Diner", "kind": "Rest Stop", "rest": true, "accent": Color(0.60, 0.95, 1.00), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.35, 0.10, 0.07), "b": Color(0.45, 0.40, 0.11), "c": Color(1.00, 0.71, 0.50), "seed": 134.4,
			"plane": Vector3(0.45, 1.00, -0.28), "sun": Vector3(0.00, 0.17, -0.80), "sun_col": Color(1.00, 0.79, 0.70),
			"planet_dir": Vector3(0.66, 0.22, -0.75), "planet_size": 0.16, "rings": false,
			"p1": Color(0.75, 0.66, 0.41), "p2": Color(0.40, 0.34, 0.20), "p3": Color(0.95, 0.90, 0.76)},
	},
	"quiet_lane": {
		"name": "The Quiet Lane",
		"map": Vector2(3.40, -0.40),
		"links": ["drift"],
		"region": "The Frontier",
		"hidden": true,
		"threat": 1,
		"desc": "The first lane. Older than the gates. It has been waiting for you.",
		"wonder": {"name": "The First Lane", "kind": "arc", "desc": "The arc where every road began. It hums your name."},
		"stations": [
			{"id": "quie_lantern", "faction": "lantern", "name": "The Lantern Gate", "kind": "Research Station", "accent": Color(0.45, 1.00, 1.00), "variant": 3,
				"makes": ["crystal", "gel"], "needs": ["electronics", "food", "cells"], "deals": ["relics"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "circuit"]},
			{"id": "quie_quiet", "faction": "haulers", "name": "Quiet Harbour", "kind": "Pleasure Habitat", "accent": Color(0.45, 0.74, 1.00), "variant": 2,
				"makes": ["wine", "art"], "needs": ["food", "water", "electronics"], "deals": ["pets", "spice"],
				"gear": ["shield_2", "nano", "engine_1"], "parts": ["crystal"]},
			{"id": "quie_keepers", "faction": "lantern", "name": "Keeper's Archive", "kind": "Research Station", "accent": Color(0.45, 0.47, 1.00), "variant": 1,
				"makes": ["crystal", "gel"], "needs": ["electronics", "food", "cells"], "deals": ["relics"],
				"gear": ["targeting", "tractor", "jump_1"], "parts": ["crystal", "circuit"], "ships": ["lark", "seraph"], "blueprints": ["bp_starbreaker", "bp_swarm"]},
			{"id": "rest_quiet_lane", "faction": "haulers", "name": "The Kettle at World's End", "kind": "Rest Stop", "rest": true, "accent": Color(1.00, 0.60, 0.60), "variant": 1,
				"makes": ["food"], "needs": ["water", "cells"], "deals": ["wine", "gel"],
				"gear": ["shield_1", "cargo_1"], "parts": ["scrap"]},
		],
		"sky": {"a": Color(0.07, 0.35, 0.35), "b": Color(0.11, 0.21, 0.45), "c": Color(0.50, 0.85, 1.00), "seed": 156.7,
			"plane": Vector3(-0.42, 1.00, 0.32), "sun": Vector3(0.06, 0.41, -0.80), "sun_col": Color(0.70, 0.95, 1.00),
			"planet_dir": Vector3(0.05, -0.30, -0.75), "planet_size": 0.17, "rings": false,
			"p1": Color(0.41, 0.55, 0.75), "p2": Color(0.20, 0.28, 0.40), "p3": Color(0.76, 0.84, 0.95)},
	},
}


## 1.0: hidden systems (the Quiet Lane) open when the story says so.
static func is_open(sid: String) -> bool:
	if not SYSTEMS[sid].get("hidden", false):
		return true
	return GameState.story_step >= GameState.STORY_UNLOCK


## Stargate links that are open right now.
static func links(sid: String) -> Array:
	return (SYSTEMS[sid]["links"] as Array).filter(func(l): return is_open(l))


static func open_systems() -> Array:
	return SYSTEMS.keys().filter(func(k): return is_open(k))


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
		for n in links(cur):
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
		for n in links(cur):
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	if not prev.has(to):
		return []
	var p := [to]
	while p[0] != from:
		p.push_front(prev[p[0]])
	return p
