class_name Estate
extends RefCounted
## 0.14 "Ownership" and 0.15 "Empire": the things you own that earn while you
## fly (or sleep). Market stalls and bars pay rent, factories turn station
## stock into goods (X3-lite: they eat real inputs and flood real markets),
## and hired pilots fly your spare ships on trade routes.
## State lives in GameState (props, fleet, estate_log); this is the logic.

const STALL_COST := 6000
const BAR_COST := 30000
const STALL_RATE := 25.0 / 60.0      # cr per second, per level
const BAR_RATE := 60.0 / 60.0
const FACTORY_CYCLE := 60.0
const FACTORY_BATCH := 4
const INPUT_DISCOUNT := 0.45

## output -> inputs per unit
const RECIPES := {
	"water": {"ice": 2},
	"cells": {"gas": 2},
	"alloy": {"ore": 2, "cells": 1},
	"polymer": {"gas": 1, "biomass": 1},
	"food": {"biomass": 2, "water": 1},
	"gel": {"biomass": 2, "water": 1},
	"electronics": {"crystal": 1, "polymer": 1},
	"machinery": {"alloy": 1, "electronics": 1},
	"shipparts": {"alloy": 2, "electronics": 1},
	"wine": {"biomass": 2, "water": 1},
	"spice": {"biomass": 2, "gas": 1},
	"art": {"crystal": 1, "polymer": 1},
}

const PILOT_SKILLS := ["Rookie", "Steady", "Seasoned", "Ace"]


static func factory_cost(good: String) -> int:
	return 30000 + int(Economy.GOODS[good]["base"]) * 60


static func upgrade_cost(prop: Dictionary) -> int:
	var base := STALL_COST
	match prop["kind"]:
		"bar":
			base = BAR_COST
		"factory":
			base = factory_cost(prop["good"])
	return int(base * 0.8 * prop["level"])


## Factories you could build at a station: every recipe whose output and
## inputs the station trades.
static func recipes_at(sid: String) -> Array:
	var out := []
	for g in RECIPES:
		if not Economy.trades_here(sid, g):
			continue
		var ok := true
		for i in RECIPES[g]:
			if not Economy.trades_here(sid, i):
				ok = false
		if ok:
			out.append(g)
	return out


static func props_at(sid: String) -> Array:
	return GameState.props.filter(func(p): return p["station"] == sid)


static func owns(sid: String, kind: String, good := "") -> bool:
	for p in GameState.props:
		if p["station"] == sid and p["kind"] == kind and (good == "" or p.get("good", "") == good):
			return true
	return false


static func buy(sid: String, kind: String, good := "") -> bool:
	var cost := STALL_COST
	match kind:
		"bar":
			cost = BAR_COST
			if owns(sid, "bar") or GameState.get_rep(Factions.of_station(sid)) < 8:
				return false
		"factory":
			cost = factory_cost(good)
			if owns(sid, "factory", good) or not recipes_at(sid).has(good):
				return false
		"stall":
			if owns(sid, "stall"):
				return false
	if GameState.credits < cost:
		return false
	GameState.credits -= cost
	GameState.props.append({"kind": kind, "station": sid, "good": good, "level": 1, "earned": 0, "status": "", "t": 0.0})
	log_line("Bought a %s at %s." % [kind_name(kind, good), Galaxy.station_name(sid)])
	return true


static func upgrade(prop: Dictionary) -> bool:
	var c := upgrade_cost(prop)
	if prop["level"] >= 3 or GameState.credits < c:
		return false
	GameState.credits -= c
	prop["level"] = int(prop["level"]) + 1
	return true


static func kind_name(kind: String, good := "") -> String:
	match kind:
		"stall":
			return "market stall"
		"bar":
			return "bar"
		"factory":
			return "%s factory" % Economy.good_name(good)
	return kind


static func log_line(text: String) -> void:
	GameState.estate_log.push_front({"t": Economy.clock, "text": text})
	if GameState.estate_log.size() > 40:
		GameState.estate_log.resize(40)


## Advance everything you own by dt seconds (called from every economy step,
## including the offline catch-up). Returns credits earned by category.
static func step(dt: float) -> Dictionary:
	var got := {"stall": 0.0, "bar": 0.0, "factory": 0.0, "fleet": 0.0}
	for p in GameState.props:
		match p["kind"]:
			"stall", "bar":
				var rate := STALL_RATE if p["kind"] == "stall" else BAR_RATE
				var cr := rate * dt * float(p["level"]) * (1.0 + 0.1 * GameState.rank_index("trader"))
				p["acc"] = float(p.get("acc", 0.0)) + cr
				got[p["kind"]] += cr
			"factory":
				p["t"] = float(p.get("t", 0.0)) + dt
				while p["t"] >= FACTORY_CYCLE:
					p["t"] -= FACTORY_CYCLE
					got["factory"] += _factory_cycle(p)
	got["fleet"] = _fleet_step(dt)
	if GameState.home_has("garden"):
		var gcr := 40.0 / 60.0 * dt
		GameState.home["acc"] = float(GameState.home.get("acc", 0.0)) + gcr
		got["stall"] += gcr
		if GameState.home["acc"] >= 1.0:
			var whole := int(GameState.home["acc"])
			GameState.home["acc"] -= whole
			GameState.credits += whole
	# pay out whole credits
	var total := 0.0
	for k in got:
		total += got[k]
	for p in GameState.props:
		if p.has("acc") and p["acc"] >= 1.0:
			var whole := int(p["acc"])
			p["acc"] -= whole
			p["earned"] = int(p["earned"]) + whole
			GameState.credits += whole
	GameState.estate_bank += total
	return got


## One production cycle: eat inputs off the station's shelves, put output on
## them, pocket the difference. Pauses when inputs run out or the market is
## so flooded that it would lose money.
static func _factory_cycle(p: Dictionary) -> float:
	var sid: String = p["station"]
	var g: String = p["good"]
	var recipe: Dictionary = RECIPES[g]
	var batch: int = FACTORY_BATCH * int(p["level"])
	# complexes: a factory next to one making its input gets that input for free
	var linked := {}
	for q in GameState.props:
		if q != p and q["kind"] == "factory" and q["station"] == sid and recipe.has(q["good"]):
			linked[q["good"]] = true
	var n := batch
	for i in recipe:
		if linked.has(i):
			continue
		n = mini(n, Economy.available(sid, i) / int(recipe[i]))
	if n <= 0:
		p["status"] = "waiting for " + ", ".join(recipe.keys().filter(func(i): return not linked.has(i)).map(func(i): return Economy.good_name(i)))
		return 0.0
	# the factory buys its inputs on a bulk contract (well under the shelf
	# price) and ships its output out at the going galaxy rate
	var cost := 0
	for i in recipe:
		if not linked.has(i):
			cost += int(Economy.buy_price(sid, i) * int(recipe[i]) * n * INPUT_DISCOUNT)
	var value := int(Economy.average_sell(g) * n)
	if value <= cost:
		p["status"] = "market flooded, paused"
		return 0.0
	for i in recipe:
		if not linked.has(i):
			Economy.on_bought(sid, i, int(recipe[i]) * n)
	Economy.on_sold(sid, g, n)
	var profit := value - cost
	p["status"] = "made %d %s%s" % [n, Economy.good_name(g), "  ·  complex bonus" if not linked.is_empty() else ""]
	p["acc"] = float(p.get("acc", 0.0)) + profit
	return float(profit)


# --- 0.15 fleet ------------------------------------------------------------------------

## Hire a pilot for a stored ship and send them on a route a <-> b.
static func hire(uid: int, pilot: Dictionary, a: String, b: String) -> bool:
	var sh := GameState.hangar_ship(uid)
	if sh.is_empty() or sh.get("pilot", {}).size() > 0 or GameState.credits < int(pilot["fee"]):
		return false
	GameState.credits -= int(pilot["fee"])
	sh["pilot"] = pilot
	sh["route"] = [a, b]
	sh["leg"] = 0
	sh["t"] = Economy.clock + _leg_time(a, b, sh["ship"])
	sh["earned"] = 0
	sh["station"] = ""
	log_line("%s takes your %s on the %s - %s run." % [pilot["name"], Items.SHIPS[sh["ship"]]["name"], Galaxy.station_name(a), Galaxy.station_name(b)])
	return true


static func dismiss(uid: int, at: String) -> void:
	var sh := GameState.hangar_ship(uid)
	if sh.is_empty():
		return
	log_line("%s parks your %s at %s and says goodbye." % [sh["pilot"].get("name", "Your pilot"), Items.SHIPS[sh["ship"]]["name"], Galaxy.station_name(at)])
	sh["pilot"] = {}
	sh["route"] = []
	sh["station"] = at


static func _leg_time(a: String, b: String, ship_id: String) -> float:
	var h := Galaxy.hops(Galaxy.system_of(a), Galaxy.system_of(b))
	var spd: float = Items.SHIPS[ship_id]["speed"]
	return (100.0 + h * 140.0) * 120.0 / spd


static func _fleet_step(_dt: float) -> float:
	var total := 0.0
	for sh in GameState.hangar:
		if sh.get("pilot", {}).is_empty() or sh.get("route", []).size() < 2:
			continue
		var guard := 0
		while Economy.clock >= float(sh["t"]) and guard < 20:
			guard += 1
			total += _fleet_leg(sh)
	return total


static func _fleet_leg(sh: Dictionary) -> float:
	var route: Array = sh["route"]
	var from: String = route[int(sh["leg"]) % 2]
	var to: String = route[(int(sh["leg"]) + 1) % 2]
	sh["leg"] = (int(sh["leg"]) + 1) % 2
	sh["t"] = float(sh["t"]) + _leg_time(from, to, sh["ship"])
	var pilot: Dictionary = sh["pilot"]
	var cap: int = int(Items.SHIPS[sh["ship"]]["cargo"])
	var skill: int = int(pilot.get("skill", 1))
	# pick the best good for this leg with today's prices
	var best := ""
	var best_gain := 0
	for g in Economy.traded(from):
		if not Economy.trades_here(to, g):
			continue
		var gain := Economy.sell_price(to, g) - Economy.buy_price(from, g)
		if gain > best_gain and Economy.available(from, g) >= 5:
			best_gain = gain
			best = g
	var nm: String = pilot.get("name", "Your pilot")
	if best == "":
		log_line("%s found nothing worth hauling from %s." % [nm, Galaxy.station_name(from)])
		return 0.0
	# buy and sell crate by crate while it still pays (a smart pilot doesn't
	# flood the market)
	var units := 0
	var cost := 0
	var value := 0
	while units < cap and Economy.available(from, best) > 0:
		var bp := Economy.buy_price(from, best)
		var sp := Economy.sell_price(to, best)
		if sp <= int(bp * 1.03):
			break
		Economy.on_bought(from, best, 1)
		Economy.on_sold(to, best, 1)
		cost += bp
		value += sp
		units += 1
	if units == 0:
		log_line("%s found nothing worth hauling from %s." % [nm, Galaxy.station_name(from)])
		return 0.0
	# raiders on dangerous roads (skilled pilots and big hulls dodge better)
	var threat := maxi(Galaxy.SYSTEMS[Galaxy.system_of(from)]["threat"], Galaxy.SYSTEMS[Galaxy.system_of(to)]["threat"])
	var risk := maxf(0.0, (threat - 1) * 0.08 - skill * 0.02)
	if randf() < risk:
		log_line("Raiders jumped %s near %s! Cargo lost (-%s cr)." % [nm, Galaxy.station_name(to), StationMenu._fmt(cost)])
		sh["earned"] = int(sh.get("earned", 0)) - cost
		GameState.credits -= mini(cost, GameState.credits)
		return -float(cost)
	var profit := value - cost
	var wage := int(maxf(0.0, profit) * (0.2 - skill * 0.02 - (0.05 if GameState.home_has("bay") else 0.0)))
	var net := profit - wage
	GameState.credits += net
	sh["earned"] = int(sh.get("earned", 0)) + net
	log_line("%s hauled %d %s %s → %s: +%s cr (wage %d)." % [nm, units, Economy.good_name(best), Galaxy.station_name(from), Galaxy.station_name(to), StationMenu._fmt(net), wage])
	return float(net)


## Pilots looking for work at a station's bar (same faces all day).
static func pilots_for_hire(sid: String) -> Array:
	var out := []
	var r := RandomNumberGenerator.new()
	r.seed = hash(sid) + int(Economy.clock / 900.0) * 17
	for i in 2:
		var skill := r.randi_range(0, 3)
		var nm: String = Bar.NAMES[r.randi() % Bar.NAMES.size()]
		out.append({"name": nm, "seed": hash(sid + nm) + 3, "skill": skill, "fee": 1500 + skill * 1800,
			"blurb": ["Fresh out of the Academy. Eager. Too eager.", "Flies steady, talks less. Perfect.", "Twenty years on the lanes, two crashes, zero regrets.", "Says they once outran a comet. Probably true."][skill]})
	return out
