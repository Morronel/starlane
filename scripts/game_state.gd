extends Node
## Persistent player/economy state (autoload "GameState"). Saved to user://save.json.

signal credits_changed(value: int)
signal message(text: String, color: Color)
signal mission_completed

const SAVE_PATH := "user://save.json"

const JUMP_CELL_PRICE := 140
const START_EQUIP := {"primary": ["pulse_1", "pulse_1"], "secondary": ["hornet"], "utility": ["shield_1", ""]}

var credits: int = 1500:
	set(v):
		credits = v
		credits_changed.emit(v)

var cargo: Dictionary = {}
var hull: float = 100.0
var kills: int = 0
var last_station: String = "halcyon"
var system_id: String = "tessaly"
var jump_charges: int = 2
var visited := {"tessaly": true}

var ship := "sparrow"
var equip := {}            # slot -> Array of gear ids ("" = empty)
var storage: Array = []    # gear ids kept in the station locker
var ammo := {"hornet": 8}
var parts := {}
var blueprints := {}
var destination := {}      # {} or {"type": "station"|"mission", "id": ...}

var missions: Array = []
var mission_counter := 0

# 0.11 economy
var cargo_cost := {}       # good -> total credits paid for what's in the hold
var price_memory := {}     # station -> {t (Economy.clock), p: {good: sell price}}
var trip := {}             # {t0, cr0, dist} since the last launch
var lifetime := {"profit": 0, "trades": 0, "km": 0.0}

# 0.12+ state. Everything listed in PERSIST is saved as-is (JSON) and
# restored by name, so new features only add a var, a reset and a line here.
var postcards := {}        # id -> {name, desc, system, t}
var rested_until := 0.0    # Economy.clock until the rest-stop coffee wears off
var rep := {}              # faction -> reputation (-100..100)
var licences := {}         # 0.13: faction -> true
# 0.14 ownership / 0.15 empire
var hangar: Array = []     # [{uid, ship, equip, station, paint, pilot, route, leg, t, earned}]
var hangar_counter := 0
var paint := -1            # index into PAINTS, -1 = factory colours
var trinket := ""          # dashboard ornament id
var props: Array = []      # [{kind, station, good, level, earned, status, t, acc}]
var estate_log: Array = [] # newest first [{t, text}]
var estate_bank := 0.0     # running total of everything the estate ever earned
var ranks_seen := {}
var away_report := ""      # "While you were away" summary after loading
const PERSIST := ["postcards", "rested_until", "rep", "licences", "hangar", "hangar_counter", "paint", "trinket", "props",
	"estate_log", "estate_bank", "ranks_seen"]

const PAINTS := [
	{"name": "Sunset Orange", "color": Color(1.0, 0.55, 0.3)}, {"name": "Lagoon", "color": Color(0.3, 0.85, 0.85)},
	{"name": "Royal Violet", "color": Color(0.6, 0.45, 1.0)}, {"name": "Racing Red", "color": Color(1.0, 0.3, 0.3)},
	{"name": "Mint", "color": Color(0.55, 1.0, 0.7)}, {"name": "Midnight", "color": Color(0.35, 0.4, 0.6)},
	{"name": "Gold Leaf", "color": Color(1.0, 0.85, 0.4)}, {"name": "Bubblegum", "color": Color(1.0, 0.6, 0.85)},
]
const TRINKETS := {
	"bobble": {"name": "Bobble-head Astronaut", "price": 250},
	"dice": {"name": "Fuzzy Dice", "price": 180},
	"plant": {"name": "Tiny Cockpit Fern", "price": 320},
	"cat": {"name": "Lucky Waving Cat", "price": 450},
}

const RANKS := {
	"trader": {"title": "Trader", "names": ["Peddler", "Dealer", "Merchant", "Broker", "Magnate", "Tycoon"], "steps": [0, 10000, 50000, 200000, 600000, 2000000]},
	"combat": {"title": "Combat", "names": ["Harmless", "Scrapper", "Gunner", "Ace", "Warden", "Legend"], "steps": [0, 5, 20, 60, 150, 400]},
	"explorer": {"title": "Explorer", "names": ["Tourist", "Wanderer", "Scout", "Pathfinder", "Navigator", "Lanefinder"], "steps": [0, 3, 8, 15, 25, 40]},
}


func _ready() -> void:
	Economy.stepped.connect(_on_economy_step)
	_new_pilot()
	if not load_game():
		_offer_missions()


func _new_pilot() -> void:
	credits = 1500
	cargo = {}
	kills = 0
	last_station = "halcyon"
	system_id = "tessaly"
	visited = {"tessaly": true}
	ship = "sparrow"
	equip = START_EQUIP.duplicate(true)
	storage = []
	ammo = {"hornet": 8}
	parts = {"scrap": 2}
	blueprints = {}
	for bp in Items.BLUEPRINTS:
		if Items.BLUEPRINTS[bp].get("start", false):
			blueprints[bp] = true
	destination = {}
	missions = []
	cargo_cost = {}
	price_memory = {}
	trip = {}
	lifetime = {"profit": 0, "trades": 0, "km": 0.0}
	postcards = {}
	rested_until = 0.0
	rep = {}
	licences = {}
	hangar = []
	hangar_counter = 0
	paint = -1
	trinket = ""
	props = []
	estate_log = []
	estate_bank = 0.0
	ranks_seen = {}
	away_report = ""
	if get_node_or_null("/root/Economy"):
		Economy.reset()
	hull = max_hull()
	jump_charges = max_jump_charges()


# --- derived stats -----------------------------------------------------------

func ship_info() -> Dictionary:
	return Items.SHIPS[ship]


func installed(slot: String) -> Array:
	return equip.get(slot, []).filter(func(g): return g != "")


func _sum(key: String) -> float:
	var t := 0.0
	for g in installed("utility"):
		t += float(Items.GEAR[g].get(key, 0.0))
	return t


func max_hull() -> float:
	return float(ship_info()["hull"]) + _sum("hull")


func cargo_capacity() -> int:
	return int(ship_info()["cargo"] + _sum("cargo"))


func cargo_used() -> int:
	var n := 0
	for k in cargo:
		n += cargo[k]
	return n


func max_shield() -> float:
	return _sum("shield")


func shield_regen() -> float:
	return maxf(_sum("regen"), 0.0)


func top_speed() -> float:
	return float(ship_info()["speed"]) * (1.0 + _sum("speed"))


func turn_mult() -> float:
	return float(ship_info()["turn"])


func boost_mult() -> float:
	return 1.0 + _sum("boost")


func tractor_range() -> float:
	return maxf(70.0, _sum("tractor"))


func hull_repair_rate() -> float:
	return _sum("repair")


func assist_deg() -> float:
	return 9.0 + _sum("assist")


func salvage_bonus() -> int:
	return int(_sum("salvage"))


func max_jump_charges() -> int:
	return 2 + int(_sum("jump"))


## Rough firepower number for UI comparisons.
func firepower() -> float:
	var t := 0.0
	for g in installed("primary"):
		var w: Dictionary = Items.GEAR[g]
		t += w["dmg"] * w.get("pellets", 1) / w["cd"]
	return t


# --- economy -----------------------------------------------------------------

func price(station: String, item: String) -> int:
	return Economy.sell_price(station, item)


func buy_price(station: String, item: String) -> int:
	return Economy.buy_price(station, item)


## Buy up to `units`, one at a time: every unit you take off the shelf makes
## the next one a little dearer. Returns units bought.
func buy(station: String, item: String, units: int) -> int:
	var got := 0
	var paid := 0
	while got < units and cargo_used() < cargo_capacity() and Economy.available(station, item) > 0:
		var p := Economy.buy_price(station, item)
		if credits - paid < p:
			break
		paid += p
		got += 1
		Economy.on_bought(station, item, 1)
	if got <= 0:
		return 0
	credits -= paid
	cargo[item] = cargo.get(item, 0) + got
	cargo_cost[item] = cargo_cost.get(item, 0) + paid
	return got


## Sell up to `units`; each unit you sell fills their shelf and lowers the
## price of the next. Returns the credits made. last_profit holds the profit
## over what you paid.
var last_profit := 0


func sell(station: String, item: String, units := 9999) -> int:
	var have: int = cargo.get(item, 0)
	units = mini(units, have)
	if units <= 0 or not Economy.trades_here(station, item):
		return 0
	var total := 0
	for i in units:
		total += Economy.sell_price(station, item)
		Economy.on_sold(station, item, 1)
	total = int(round(total * sell_bonus(station, item)))
	var cost_each: float = float(cargo_cost.get(item, 0)) / maxf(have, 1)
	var cost := int(round(cost_each * units))
	last_profit = total - cost
	credits += total
	lifetime["profit"] = int(lifetime.get("profit", 0)) + last_profit
	lifetime["trades"] = int(lifetime.get("trades", 0)) + 1
	if total >= 1500:
		add_rep(Factions.of_station(station), 1)
	if units >= have:
		cargo.erase(item)
		cargo_cost.erase(item)
	else:
		cargo[item] = have - units
		cargo_cost[item] = int(cargo_cost.get(item, 0)) - cost
	return total


## What a unit of `item` in the hold cost on average (0 if none).
func avg_cost(item: String) -> int:
	var n: int = cargo.get(item, 0)
	return int(round(float(cargo_cost.get(item, 0)) / n)) if n > 0 else 0


## Remember the prices at a station (and, through the local beacon network,
## every station in its system).
func remember_prices(system: String) -> void:
	for st in Galaxy.SYSTEMS[system]["stations"]:
		var sid: String = st["id"]
		var p := {}
		for g in Economy.traded(sid):
			p[g] = Economy.sell_price(sid, g)
		price_memory[sid] = {"t": Economy.clock, "p": p}


func start_trip() -> void:
	start_races()
	trip = {"t0": Economy.clock, "cr0": credits, "dist": 0.0, "value0": hold_value_at(last_station)}


## What the hold would sell for at a station right now.
func hold_value_at(station: String) -> int:
	var v := 0
	for g in cargo:
		if Economy.trades_here(station, g):
			v += Economy.sell_price(station, g) * int(cargo[g])
	return v


func cargo_paid() -> int:
	var v := 0
	for g in cargo_cost:
		v += int(cargo_cost[g])
	return v


func repair_cost() -> int:
	return int(ceil((max_hull() - hull) * 5.0 * (0.7 if has_licence("miners") else 1.0)))


func repair() -> bool:
	var c := repair_cost()
	if c <= 0 or credits < c:
		return false
	credits -= c
	hull = max_hull()
	return true


func refuel_cost() -> int:
	return (max_jump_charges() - jump_charges) * JUMP_CELL_PRICE


func refuel() -> bool:
	var missing := max_jump_charges() - jump_charges
	if missing <= 0:
		return false
	var affordable := mini(missing, credits / JUMP_CELL_PRICE)
	if affordable <= 0:
		return false
	credits -= affordable * JUMP_CELL_PRICE
	jump_charges += affordable
	return true


# --- outfitting ---------------------------------------------------------------

func free_slot(slot: String) -> int:
	var arr: Array = equip.get(slot, [])
	for i in arr.size():
		if arr[i] == "":
			return i
	return -1


func _normalize_equip() -> void:
	## Make every slot array exactly as long as the ship allows; overflow goes to storage.
	var slots: Dictionary = ship_info()["slots"]
	var out := {}
	for slot in ["primary", "secondary", "utility"]:
		var have: Array = installed(slot)
		var n: int = slots[slot]
		var arr := []
		for i in n:
			arr.append(have[i] if i < have.size() else "")
		for i in range(n, have.size()):
			storage.append(have[i])
		out[slot] = arr
	equip = out
	hull = minf(hull, max_hull())
	jump_charges = mini(jump_charges, max_jump_charges())


## Buy gear: installs into a free slot if there is one, otherwise stores it.
func buy_gear(gear_id: String) -> String:
	var g: Dictionary = Items.GEAR[gear_id]
	if credits < g["price"]:
		return ""
	credits -= g["price"]
	var i := free_slot(g["slot"])
	if i >= 0:
		equip[g["slot"]][i] = gear_id
		_on_gear_installed(gear_id)
		return "installed"
	storage.append(gear_id)
	return "stored"


func _on_gear_installed(gear_id: String) -> void:
	var g: Dictionary = Items.GEAR[gear_id]
	if g.has("hull"):
		hull += g["hull"]
	if g.has("ammo") and not ammo.has(g["ammo"]):
		ammo[g["ammo"]] = 0


func install(storage_index: int) -> bool:
	if storage_index < 0 or storage_index >= storage.size():
		return false
	var gear_id: String = storage[storage_index]
	var slot: String = Items.GEAR[gear_id]["slot"]
	var i := free_slot(slot)
	if i < 0:
		return false
	storage.remove_at(storage_index)
	equip[slot][i] = gear_id
	_on_gear_installed(gear_id)
	return true


func uninstall(slot: String, index: int) -> bool:
	var arr: Array = equip[slot]
	if index >= arr.size() or arr[index] == "":
		return false
	var gear_id: String = arr[index]
	arr[index] = ""
	storage.append(gear_id)
	hull = minf(hull, max_hull())
	jump_charges = mini(jump_charges, max_jump_charges())
	return true


func sell_stored(storage_index: int) -> int:
	if storage_index < 0 or storage_index >= storage.size():
		return 0
	var v := Items.sell_value(storage[storage_index])
	storage.remove_at(storage_index)
	credits += v
	return v


func ship_cost(ship_id: String) -> int:
	return int(Items.SHIPS[ship_id]["price"]) - Items.ship_trade_in(ship)


## Trade in the current hull for a new one. Gear carries over where it fits.
func buy_ship(ship_id: String) -> bool:
	if ship_id == ship or not can_fly(ship_id):
		return false
	var cost := ship_cost(ship_id)
	if credits < cost:
		return false
	credits -= cost
	ship = ship_id
	_normalize_equip()
	hull = max_hull()
	# cargo that no longer fits is left behind at the station
	while cargo_used() > cargo_capacity():
		var k: String = cargo.keys()[0]
		cargo[k] -= 1
		if cargo[k] <= 0:
			cargo.erase(k)
	return true


func ammo_price(kind: String) -> int:
	return int(Items.AMMO[kind]["price"])


func buy_ammo(kind: String, n: int) -> int:
	var p := ammo_price(kind)
	n = mini(n, credits / p)
	if n <= 0:
		return 0
	credits -= p * n
	ammo[kind] = ammo.get(kind, 0) + n
	return n


func part_price(station: String, part: String) -> int:
	var base: int = Items.PARTS[part]["price"]
	return int(round(base * (0.9 + 0.2 * float(hash(station + part) % 100) / 100.0)))


func buy_part(station: String, part: String, n: int) -> int:
	var p := part_price(station, part)
	n = mini(n, credits / p)
	if n <= 0:
		return 0
	credits -= p * n
	parts[part] = parts.get(part, 0) + n
	return n


func sell_part(part: String, n := 1) -> int:
	var have: int = parts.get(part, 0)
	n = mini(n, have)
	if n <= 0:
		return 0
	var v: int = int(Items.PARTS[part]["price"] * 0.6) * n
	parts[part] = have - n
	credits += v
	return v


func add_parts(got: Dictionary) -> void:
	for k in got:
		parts[k] = parts.get(k, 0) + got[k]


func can_craft(bp_id: String) -> bool:
	if not blueprints.has(bp_id):
		return false
	var bp: Dictionary = Items.BLUEPRINTS[bp_id]
	if credits < bp["fee"]:
		return false
	for k in bp["parts"]:
		if parts.get(k, 0) < bp["parts"][k]:
			return false
	return true


## Assemble a blueprint. Returns a short description of what was made, or "".
func craft(bp_id: String) -> String:
	if not can_craft(bp_id):
		return ""
	var bp: Dictionary = Items.BLUEPRINTS[bp_id]
	credits -= bp["fee"]
	for k in bp["parts"]:
		parts[k] -= bp["parts"][k]
	var mk: String = bp["makes"]
	if mk.begins_with("ammo:"):
		var a := mk.split(":")
		ammo[a[1]] = ammo.get(a[1], 0) + int(a[2])
		return Items.blueprint_name(bp_id)
	storage.append(mk)
	return Items.GEAR[mk]["name"]


func buy_blueprint(bp_id: String) -> bool:
	var price: int = Items.BLUEPRINTS[bp_id].get("price", 0)
	if blueprints.has(bp_id) or credits < price:
		return false
	credits -= price
	blueprints[bp_id] = true
	return true


## A blueprint the pilot does not know yet, for loot drops ("" if all known).
func unknown_blueprint(rng: RandomNumberGenerator) -> String:
	var pool := []
	for bp in Items.BLUEPRINTS:
		if not blueprints.has(bp):
			pool.append(bp)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


# --- destination ----------------------------------------------------------------

func set_destination(kind: String, id) -> void:
	destination = {"type": kind, "id": id}


## Resolves the destination to {system, station, beacon, label} or {}.
## 0.13 site missions add "site": "wonder" (the system's wonder).
func destination_info() -> Dictionary:
	if destination.is_empty():
		return {}
	if destination["type"] == "station":
		var sid: String = destination["id"]
		return {"system": Galaxy.system_of(sid), "station": sid, "beacon": false, "label": Galaxy.station_name(sid)}
	for m in missions:
		if m["id"] == int(destination["id"]):
			if m["state"] == "done":
				return {"system": system_id, "station": last_station if Galaxy.system_of(last_station) == system_id else Galaxy.SYSTEMS[system_id]["stations"][0]["id"],
					"beacon": false, "label": "Any station (collect reward)", "mission": m}
			match m["kind"]:
				"hunt":
					if m.has("site"):
						return {"system": m["system"], "station": m["site"], "beacon": false, "label": "Defend " + Galaxy.station_name(m["site"]), "mission": m}
					return {"system": m["system"], "station": "", "beacon": true, "label": "Raider nest, " + Galaxy.SYSTEMS[m["system"]]["name"], "mission": m}
				"salvage", "survey":
					var wd: Dictionary = Galaxy.SYSTEMS[m["system"]].get("wonder", {})
					return {"system": m["system"], "station": "", "beacon": false, "site": "wonder", "label": wd.get("name", "Survey site"), "mission": m}
			return {"system": Galaxy.system_of(m["station"]), "station": m["station"], "beacon": false, "label": Galaxy.station_name(m["station"]), "mission": m}
	destination = {}
	return {}


func _auto_track() -> void:
	if not destination_info().is_empty():
		return
	for m in missions:
		if m["state"] == "active":
			set_destination("mission", m["id"])
			return


# --- missions ----------------------------------------------------------------

const PASSENGERS := ["a retired miner and her very old cat", "two giggling honeymooners", "a nervous accountant with a locked briefcase",
	"a bard with an unreasonably large lute", "a Lantern monk on pilgrimage", "a food critic who hates everything", "a kid going to flight school",
	"a grandmother who knits in zero-g"]
const PARCELS := ["Sealed data core", "Diplomatic pouch", "Medical samples", "Encrypted charts", "Prototype reactor", "A suspiciously warm egg", "Grandma's casserole"]


func _offer_missions() -> void:
	var hunts := 0
	for m in missions:
		if m["state"] in ["offered", "active", "done"] and m["kind"] == "hunt" and not m.has("site"):
			hunts += 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var sys_ids := Galaxy.SYSTEMS.keys()
	var hunt_systems := {}
	for m in missions:
		if m["kind"] == "hunt" and not m.has("site") and m["state"] in ["offered", "active", "done"]:
			hunt_systems[m["system"]] = true
	while hunts < 3:
		mission_counter += 1
		var sid: String = system_id
		if hunt_systems.has(sid):
			var free := sys_ids.filter(func(x): return not hunt_systems.has(x))
			if free.is_empty():
				break
			sid = free[rng.randi() % free.size()]
		hunt_systems[sid] = true
		var threat: int = Galaxy.SYSTEMS[sid]["threat"]
		var n := 3 + mini(mission_counter / 3, 3) + threat - 1
		missions.append({
			"id": mission_counter, "kind": "hunt", "state": "offered", "system": sid, "faction": "navy",
			"title": "Raider nest in %s" % Galaxy.SYSTEMS[sid]["name"],
			"desc": "Raiders are preying on road traffic near the beacon in %s. Drop out at the beacon and destroy %d raiders." % [Galaxy.SYSTEMS[sid]["name"], n],
			"count": n, "left": n, "reward": 800 + n * 260 + threat * 400, "station": "",
		})
		hunts += 1
	# station jobs: every station keeps three offers of its own
	var here := last_station
	var offered_here := 0
	for m in missions:
		if m["state"] == "offered" and m.get("from", "") == here:
			offered_here += 1
	var tries := 0
	while offered_here < 3 and tries < 30:
		tries += 1
		var m := _make_job(here, rng)
		if m.is_empty():
			continue
		mission_counter += 1
		m["id"] = mission_counter
		m["state"] = "offered"
		m["from"] = here
		if not m.has("faction"):
			m["faction"] = Factions.of_station(here)
		missions.append(m)
		offered_here += 1
	# forget stale offers at stations long behind us
	var offers := missions.filter(func(m): return m["state"] == "offered" and m.get("from", "") != "" and m["from"] != here)
	while offers.size() > 30:
		missions.erase(offers.pop_front())


func _pick(rng: RandomNumberGenerator, arr: Array):
	return arr[rng.randi() % arr.size()]


## One contract offered at station `here` (0.13: nine kinds of work).
func _make_job(here: String, rng: RandomNumberGenerator) -> Dictionary:
	var sys := Galaxy.system_of(here)
	var threat: int = Galaxy.SYSTEMS[sys]["threat"]
	var ids := Galaxy.all_station_ids()
	var near := ids.filter(func(x): return x != here and Galaxy.hops(sys, Galaxy.system_of(x)) <= 2)
	var local := ids.filter(func(x): return x != here and Galaxy.system_of(x) == sys)
	var kinds := [["courier", 3.0], ["supply", 3.0], ["passenger", 2.0], ["salvage", 1.2], ["survey", 1.0], ["race", 1.0], ["defence", 1.0], ["chain", 0.8]]
	if threat >= 2:
		kinds.append(["smuggle", 1.4])
	var total := 0.0
	for k in kinds:
		total += k[1]
	var r := rng.randf() * total
	var kind := "courier"
	for k in kinds:
		r -= k[1]
		if r <= 0.0:
			kind = k[0]
			break
	var to: String = _pick(rng, near)
	var h := Galaxy.hops(sys, Galaxy.system_of(to))
	var where := "same system" if h == 0 else "%d jump%s away" % [h, "" if h == 1 else "s"]
	match kind:
		"courier":
			var what: String = _pick(rng, PARCELS)
			return {"kind": "courier", "title": "%s to %s" % [what, Galaxy.station_name(to)], "station": to,
				"desc": "Carry it to %s in %s (%s)." % [Galaxy.station_name(to), Galaxy.SYSTEMS[Galaxy.system_of(to)]["name"], where],
				"reward": 700 + h * 800}
		"supply":
			var needs: Array = Galaxy.station(to).get("needs", []).filter(func(g): return Economy.trades_here(to, g))
			if needs.is_empty():
				return {}
			var g: String = _pick(rng, needs)
			var units := clampi(int(2400.0 / float(Economy.GOODS[g]["base"])) * rng.randi_range(2, 4), 6, 40)
			return {"kind": "supply", "good": g, "units": units, "station": to,
				"title": "Bulk order: %d %s for %s" % [units, Economy.good_name(g), Galaxy.station_name(to)],
				"desc": "%s needs %d %s (%s). Buy them anywhere and deliver: they pay well over market." % [Galaxy.station_name(to), units, Economy.good_name(g), where],
				"reward": int(units * float(Economy.GOODS[g]["base"]) * 1.5) + 300 + h * 400, "faction": Factions.of_station(to)}
		"passenger":
			var who: String = _pick(rng, PASSENGERS)
			var allow := 160.0 + h * 170.0
			return {"kind": "passenger", "station": to, "allow": allow,
				"title": "Passenger to %s" % Galaxy.station_name(to),
				"desc": "Fly %s to %s (%s) within %d:%02d of departure. Late arrivals pay half." % [who, Galaxy.station_name(to), where, int(allow) / 60, int(allow) % 60],
				"reward": 600 + h * 750}
		"salvage":
			var sid: String = sys if rng.randf() < 0.6 else _pick(rng, Galaxy.SYSTEMS[sys]["links"])
			var wd: Dictionary = Galaxy.SYSTEMS[sid].get("wonder", {})
			var t2: int = Galaxy.SYSTEMS[sid]["threat"]
			return {"kind": "salvage", "system": sid, "station": "", "faction": "haulers",
				"title": "Black box near %s" % wd.get("name", "the wreck"),
				"desc": "A courier went dark by %s in %s. Find the wreck and pull its black box (fly close, the tractor does the rest)." % [wd.get("name", "the wonder"), Galaxy.SYSTEMS[sid]["name"]],
				"reward": 900 + t2 * 500 + Galaxy.hops(sys, sid) * 500}
		"survey":
			var others: Array = Galaxy.SYSTEMS.keys().filter(func(x): return Galaxy.hops(sys, x) <= 2)
			var sid2: String = _pick(rng, others)
			var wd2: Dictionary = Galaxy.SYSTEMS[sid2].get("wonder", {})
			return {"kind": "survey", "system": sid2, "station": "", "faction": "lantern",
				"title": "Survey: photograph %s" % wd2.get("name", "the wonder"),
				"desc": "The Lantern Order wants a fresh plate of %s in %s. Point your camera at it and press PHOTO." % [wd2.get("name", "the wonder"), Galaxy.SYSTEMS[sid2]["name"]],
				"reward": 800 + Galaxy.hops(sys, sid2) * 600}
		"smuggle":
			var core := ids.filter(func(x): return Galaxy.SYSTEMS[Galaxy.system_of(x)]["threat"] <= 1 and Galaxy.hops(sys, Galaxy.system_of(x)) <= 3)
			if core.is_empty():
				return {}
			var to2: String = _pick(rng, core)
			var h2 := Galaxy.hops(sys, Galaxy.system_of(to2))
			return {"kind": "smuggle", "station": to2, "faction": "comet",
				"title": "Sealed crate to %s. No questions." % Galaxy.station_name(to2),
				"desc": "Deliver to %s (%d jumps). Core customs scan the lanes: if they find it, you're fined and the deal's off." % [Galaxy.station_name(to2), h2],
				"reward": 2600 + h2 * 1300}
		"race":
			if local.is_empty():
				return {}
			var to3: String = _pick(rng, local)
			var limit := 150.0
			return {"kind": "race", "station": to3, "allow": limit,
				"title": "Hot soup to %s in %d s" % [Galaxy.station_name(to3), int(limit)],
				"desc": "The kitchen at %s swears it's still hot. Launch and dock there within %d seconds. Cold soup pays nothing." % [Galaxy.station_name(to3), int(limit)],
				"reward": 900}
		"defence":
			var site: String = here if local.is_empty() or rng.randf() < 0.5 else _pick(rng, local)
			var n := 3 + threat
			return {"kind": "hunt", "site": site, "system": sys, "station": "", "count": n, "left": n, "faction": "navy",
				"title": "Defend %s" % Galaxy.station_name(site),
				"desc": "Raiders are harassing ships around %s. Fly there and drive them off: %d kills." % [Galaxy.station_name(site), n],
				"reward": 900 + n * 300 + threat * 400}
		"chain":
			var b: String = _pick(rng, near)
			var c: String = _pick(rng, ids.filter(func(x): return x != b and Galaxy.hops(Galaxy.system_of(b), Galaxy.system_of(x)) <= 2))
			return {"kind": "chain", "station": to, "chain": [b, c], "step": 1,
				"title": "The Parcel (part 1 of 3)",
				"desc": "A small box, oddly heavy, addressed to %s. The sender winks. Something tells me it won't end there." % Galaxy.station_name(to),
				"reward": 700 + h * 600}
	return {}


func missions_for(station: String) -> Array:
	var out := []
	for m in missions:
		if m["state"] == "paid":
			continue
		if m["state"] == "offered" and m.get("from", "") != "" and m["from"] != station:
			continue
		if m["state"] == "offered" and m.get("from", "") == "" and m["kind"] != "hunt":
			continue
		out.append(m)
	return out


func accept(m: Dictionary) -> void:
	m["state"] = "active"
	m.erase("spawned")
	if m["kind"] == "passenger":
		m["deadline"] = Economy.clock + float(m["allow"])
	set_destination("mission", m["id"])


func active_hunt(sid := "") -> Dictionary:
	for m in missions:
		if m["kind"] == "hunt" and m["state"] == "active" and (sid == "" or m["system"] == sid):
			return m
	return {}


func on_enemy_killed(bounty: int) -> void:
	kills += 1
	credits += bounty
	var m := active_hunt(system_id)
	if not m.is_empty():
		m["left"] = maxi(0, m["left"] - 1)
		if m["left"] == 0:
			_mission_done(m)
		else:
			message.emit("Raider down (+%d cr). %d left." % [bounty, m["left"]], Color(1, 0.85, 0.4))
	else:
		message.emit("Raider destroyed. Bounty +%d cr" % bounty, Color(1, 0.85, 0.4))


func _mission_done(m: Dictionary) -> void:
	m["state"] = "done"
	message.emit("Mission complete! Dock at any station to collect %d cr." % m["reward"], Color(0.5, 1.0, 0.6))
	mission_completed.emit()


## The system wonder was photographed (surveys).
func on_photo(id: String) -> void:
	for m in missions:
		if m["kind"] == "survey" and m["state"] == "active" and id == "wonder_" + m["system"]:
			_mission_done(m)


## A mission black box was picked up.
func on_salvage(mission_id: int) -> void:
	for m in missions:
		if m["id"] == mission_id and m["state"] == "active":
			_mission_done(m)


## Smuggling contract with cargo aboard bound for a core system (customs bait).
func active_smuggle_here() -> Dictionary:
	for m in missions:
		if m["kind"] == "smuggle" and m["state"] == "active":
			return m
	return {}


func fail_mission(m: Dictionary, why: String) -> void:
	m["state"] = "paid"
	m["reward"] = 0
	missions = missions.filter(func(x): return x["state"] != "paid")
	destination_info()
	message.emit(why, Color(1.0, 0.45, 0.4))


## Races start the clock when you launch from where you took them.
func start_races() -> void:
	for m in missions:
		if m["kind"] == "race" and m["state"] == "active" and m.get("from", "") == last_station:
			m["t0"] = Economy.clock


func turn_in(station: String) -> Array:
	var out := []
	var chained := []
	for m in missions:
		var pay := false
		var amount: int = m["reward"]
		if m["state"] == "done":
			pay = true
		elif m["state"] == "active" and m.get("station", "") == station:
			match m["kind"]:
				"courier", "smuggle":
					pay = true
				"supply":
					var g: String = m["good"]
					var units: int = m["units"]
					if int(cargo.get(g, 0)) >= units:
						var have: int = cargo[g]
						var cost_each: float = float(cargo_cost.get(g, 0)) / maxf(have, 1)
						cargo[g] = have - units
						cargo_cost[g] = int(cargo_cost.get(g, 0)) - int(round(cost_each * units))
						if cargo[g] <= 0:
							cargo.erase(g)
							cargo_cost.erase(g)
						Economy.on_sold(station, g, units)
						pay = true
					else:
						out.append("%s: bring %d %s (you have %d)" % [m["title"], units, Economy.good_name(g), int(cargo.get(g, 0))])
				"passenger":
					pay = true
					if Economy.clock > float(m.get("deadline", INF)):
						amount = amount / 2
						out.append("Your passenger grumbles about the delay. Half pay.")
				"race":
					pay = true
					var took := Economy.clock - float(m.get("t0", -INF))
					if not m.has("t0") or took > float(m["allow"]):
						amount = 0
						out.append("%s: the soup arrived cold. No pay." % m["title"])
					else:
						out.append("Soup delivered in %d s. Still steaming!" % int(took))
				"chain":
					pay = true
					var rest: Array = m.get("chain", [])
					if not rest.is_empty():
						var step: int = int(m.get("step", 1)) + 1
						var nxt: String = rest[0]
						mission_counter += 1
						var final_step := rest.size() == 1
						var h := Galaxy.hops(Galaxy.system_of(station), Galaxy.system_of(nxt))
						chained.append({"id": mission_counter, "kind": "chain", "state": "active", "station": nxt, "chain": rest.slice(1), "step": step,
							"from": station, "faction": m.get("faction", "haulers"),
							"title": "The Parcel (part %d of 3)" % step,
							"desc": ["The clerk sighs: wrong address. It's really for %s." % Galaxy.station_name(nxt),
								"The box is ticking now. Gently. It wants to go to %s." % Galaxy.station_name(nxt)][mini(step - 2, 1)],
							"reward": 900 + h * 700 + (3000 if final_step else 0)})
					elif int(m.get("step", 1)) >= 3:
						out.append("The box opens: a tiny, very grateful robot. It plays you a song and pays the bonus.")
		if pay:
			m["state"] = "paid"
			if amount > 0:
				credits += amount
				out.append("%s: +%d cr" % [m["title"], amount])
				add_rep(m.get("faction", Factions.of_station(station)), 3)
	missions = missions.filter(func(m): return m["state"] != "paid")
	for c in chained:
		missions.append(c)
		destination = {"type": "mission", "id": c["id"]}
	if destination.get("type", "") == "station" and destination["id"] == station:
		destination = {}
	destination_info()   # drops a finished mission destination
	_offer_missions()
	_auto_track()
	return out


func on_player_destroyed() -> void:
	cargo.clear()
	cargo_cost.clear()
	credits = int(credits * 0.9)
	hull = max_hull()
	for m in missions:
		if m["state"] == "active" and m["kind"] == "courier":
			m["state"] = "offered"
	system_id = Galaxy.system_of(last_station)


# --- save / load -------------------------------------------------------------

const SLOT_COUNT := 3


func slot_path(slot: int) -> String:
	## slot 0 is the autosave; 1..SLOT_COUNT are manual slots
	return SAVE_PATH if slot == 0 else "user://slot_%d.json" % slot


func save_game(path := SAVE_PATH) -> void:
	var data := {
		"v": 5, "credits": credits,
		"economy": Economy.to_save(), "price_memory": price_memory, "cargo_cost": cargo_cost, "lifetime": lifetime, "cargo": cargo, "hull": hull, "kills": kills,
		"last_station": last_station, "system_id": system_id, "jump_charges": jump_charges,
		"visited": visited, "missions": missions, "mission_counter": mission_counter,
		"ship": ship, "equip": equip, "storage": storage, "ammo": ammo, "parts": parts,
		"blueprints": blueprints, "destination": destination,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	for k in PERSIST:
		data[k] = get(k)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func save_slot(slot: int) -> void:
	save_game(slot_path(slot))


## Load a slot and make it the running game (the autosave follows it).
func load_slot(slot: int) -> bool:
	if not load_game(slot_path(slot)):
		return false
	if slot != 0:
		save_game()
	return true


func delete_slot(slot: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


## Summary of a save for the slot list, or {} when the slot is empty/unreadable.
func slot_info(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) < 2:
		return {}
	var sid: String = data.get("last_station", "halcyon")
	var sh: String = data.get("ship", "sparrow")
	var when := int(data.get("saved_at", 0))
	if when == 0:
		when = int(FileAccess.get_modified_time(path))
	return {
		"credits": int(data.get("credits", 0)), "kills": int(data.get("kills", 0)),
		"station": Galaxy.station_name(sid), "system": Galaxy.SYSTEMS.get(Galaxy.system_of(sid), {}).get("name", ""),
		"ship": Items.SHIPS.get(sh, Items.SHIPS["sparrow"])["name"], "saved_at": when,
	}


func load_game(path := SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var v := int(data.get("v", 0))
	if v < 2:
		return false
	credits = int(data["credits"])
	cargo = {}
	for k in data["cargo"]:
		cargo[k] = int(data["cargo"][k])
	kills = int(data["kills"])
	last_station = data["last_station"]
	if Galaxy.station(last_station).is_empty():
		last_station = "halcyon"
	system_id = Galaxy.system_of(last_station)
	visited = data["visited"]
	missions = data["missions"]
	for m in missions:
		for k in ["id", "count", "left", "reward"]:
			if m.has(k):
				m[k] = int(m[k])
	mission_counter = int(data["mission_counter"])
	if v >= 3:
		ship = data["ship"]
		equip = {}
		for slot in data["equip"]:
			equip[slot] = Array(data["equip"][slot])
		storage = Array(data["storage"])
		ammo = _ints(data["ammo"])
		parts = _ints(data["parts"])
		blueprints = data["blueprints"]
		destination = data["destination"]
		_normalize_equip()
		hull = clampf(float(data["hull"]), 1.0, max_hull())
		jump_charges = mini(int(data["jump_charges"]), max_jump_charges())
	else:
		# v0.2 save: keep money, cargo, missions and location; fresh starter ship
		hull = max_hull()
		jump_charges = max_jump_charges()
	# v5+: everything in PERSIST (missing keys keep their fresh-pilot values).
	# Restored before the economy so offline catch-up runs your estate too.
	for k in PERSIST:
		if data.has(k) and typeof(data[k]) == typeof(get(k)):
			set(k, data[k])
	_after_load()
	# v4: the living economy (older saves start a fresh market)
	var cr_before := credits
	var bank_before := estate_bank
	_away = {"stall": 0.0, "bar": 0.0, "factory": 0.0, "fleet": 0.0}
	_catching_up = true
	Economy.from_save(data.get("economy", {}))
	_catching_up = false
	away_report = ""
	if estate_bank - bank_before >= 1.0:
		var bits := []
		for k in ["stall", "bar", "factory", "fleet"]:
			if absf(_away[k]) >= 1.0:
				bits.append("%s %s%s cr" % [{"stall": "stalls", "bar": "bars", "factory": "factories", "fleet": "fleet"}[k], "+" if _away[k] >= 0 else "-", StationMenu._fmt(absi(int(_away[k])))])
		away_report = "WHILE YOU WERE AWAY: " + ", ".join(bits) + "  ·  total %s%s cr" % ["+" if credits >= cr_before else "-", StationMenu._fmt(absi(credits - cr_before))]
	price_memory = data.get("price_memory", {})
	cargo_cost = _ints(data.get("cargo_cost", {}))
	lifetime = data.get("lifetime", {"profit": 0, "trades": 0, "km": 0.0})
	# cargo from before 0.11 (or goods a hold can't explain) gets a fair cost basis
	for g in cargo.keys():
		if not Galaxy.COMMODITIES.has(g):
			cargo.erase(g)
			continue
		if not cargo_cost.has(g):
			cargo_cost[g] = int(Galaxy.COMMODITIES[g]["base"]) * int(cargo[g])
	_offer_missions()
	return true


## JSON brings every number back as a float: fix the ones that must be ints.
func _after_load() -> void:
	for f in rep.keys():
		rep[f] = int(rep[f])
	rested_until = float(rested_until)
	hangar_counter = int(hangar_counter)
	paint = int(paint)
	for h in hangar:
		h["uid"] = int(h["uid"])
		if h.has("leg"):
			h["leg"] = int(h["leg"])
		if h.has("earned"):
			h["earned"] = int(h["earned"])
	for p in props:
		p["level"] = int(p["level"])
		p["earned"] = int(p["earned"])


# --- 0.14 ownership --------------------------------------------------------------------

var _away := {}
var _catching_up := false
var _estate_msg_t := 0.0
var _estate_msg_acc := 0.0


func _on_economy_step(dt: float) -> void:
	var got := Estate.step(dt)
	var sum := 0.0
	for k in got:
		sum += got[k]
		if _catching_up:
			_away[k] = float(_away.get(k, 0.0)) + got[k]
	if _catching_up:
		return
	_estate_msg_acc += sum
	_estate_msg_t += dt
	if _estate_msg_t >= 300.0:
		if absf(_estate_msg_acc) >= 1.0:
			message.emit("Estate report: %s%s cr in the last 5 minutes" % ["+" if _estate_msg_acc >= 0 else "-", StationMenu._fmt(absi(int(_estate_msg_acc)))], Color(1.0, 0.86, 0.45))
		_estate_msg_t = 0.0
		_estate_msg_acc = 0.0
	check_ranks()


func hangar_ship(uid: int) -> Dictionary:
	for h in hangar:
		if int(h["uid"]) == uid:
			return h
	return {}


## Store the ship you're flying in the hangar at this station.
func _store_current() -> void:
	hangar_counter += 1
	hangar.append({"uid": hangar_counter, "ship": ship, "equip": equip.duplicate(true), "station": last_station, "paint": paint, "pilot": {}, "route": []})


func can_fly(ship_id: String) -> bool:
	var lic: String = Items.SHIPS[ship_id].get("licence", "")
	return lic == "" or has_licence(lic)


## Buy a ship and keep the old one in your hangar (full price).
func buy_ship_keep(ship_id: String) -> bool:
	var price := int(Items.SHIPS[ship_id]["price"])
	if not can_fly(ship_id) or credits < price:
		return false
	credits -= price
	_store_current()
	ship = ship_id
	equip = {}
	_normalize_equip()
	hull = max_hull()
	paint = -1
	_drop_overflow()
	return true


## Swap the ship you're flying with one stored here.
func switch_ship(uid: int) -> bool:
	var h := hangar_ship(uid)
	if h.is_empty() or h["station"] != last_station or not h.get("pilot", {}).is_empty():
		return false
	var old := {"ship": ship, "equip": equip.duplicate(true), "paint": paint}
	ship = h["ship"]
	equip = {}
	for slot in h["equip"]:
		equip[slot] = Array(h["equip"][slot])
	paint = int(h.get("paint", -1))
	_normalize_equip()
	hull = max_hull()
	h["ship"] = old["ship"]
	h["equip"] = old["equip"]
	h["paint"] = old["paint"]
	_drop_overflow()
	return true


func sell_stored_ship(uid: int) -> int:
	var h := hangar_ship(uid)
	if h.is_empty() or h["station"] != last_station or not h.get("pilot", {}).is_empty():
		return 0
	var v := Items.ship_trade_in(h["ship"])
	credits += v
	hangar.erase(h)
	return v


func _drop_overflow() -> void:
	while cargo_used() > cargo_capacity():
		var k: String = cargo.keys()[0]
		cargo[k] -= 1
		if cargo[k] <= 0:
			cargo.erase(k)
			cargo_cost.erase(k)


func buy_paint(i: int) -> bool:
	if credits < 500 or i == paint:
		return false
	credits -= 500
	paint = i
	return true


func buy_trinket(id: String) -> bool:
	var price := int(TRINKETS[id]["price"])
	if credits < price or trinket == id:
		return false
	credits -= price
	trinket = id
	return true


# --- ranks -------------------------------------------------------------------------------

func rank_value(track: String) -> float:
	match track:
		"trader":
			return float(lifetime.get("profit", 0)) + estate_bank
		"combat":
			return float(kills)
		"explorer":
			return float(visited.size()) + postcards.size() * 2.0 + float(lifetime.get("km", 0.0)) / 400.0
	return 0.0


func rank_index(track: String) -> int:
	var steps: Array = RANKS[track]["steps"]
	var v := rank_value(track)
	var idx := 0
	for i in steps.size():
		if v >= float(steps[i]):
			idx = i
	return idx


func rank_name(track: String) -> String:
	return RANKS[track]["names"][rank_index(track)]


## Announce promotions.
func check_ranks() -> void:
	for track in RANKS:
		var i := rank_index(track)
		if i > int(ranks_seen.get(track, 0)):
			ranks_seen[track] = i
			message.emit("PROMOTED! %s rank: %s" % [RANKS[track]["title"], rank_name(track)], Color(1.0, 0.86, 0.45))


# --- 0.12 the road ---------------------------------------------------------------------

func is_rested() -> bool:
	return Economy.clock < rested_until


## Put goods in the hold for free (salvage, gifts). Returns units that fit.
func add_cargo_free(g: String, n: int) -> int:
	var fit := mini(n, cargo_capacity() - cargo_used())
	if fit <= 0 or not Economy.GOODS.has(g):
		return 0
	cargo[g] = int(cargo.get(g, 0)) + fit
	cargo_cost[g] = int(cargo_cost.get(g, 0))
	return fit


func add_rep(faction: String, n: int) -> void:
	var before := int(rep.get(faction, 0))
	rep[faction] = clampi(before + n, -100, 100)
	if before < Factions.LICENCE_REP and rep[faction] >= Factions.LICENCE_REP and not has_licence(faction):
		message.emit("%s trusts you now: their %s is for sale at their stations." % [Factions.LIST[faction]["name"], Factions.LIST[faction]["licence"]], Factions.LIST[faction]["color"])


func get_rep(faction: String) -> int:
	return int(rep.get(faction, 0))


# --- 0.13 factions and licences ----------------------------------------------------------

func has_licence(faction: String) -> bool:
	return licences.get(faction, false)


func buy_licence(faction: String) -> bool:
	var f: Dictionary = Factions.LIST[faction]
	if has_licence(faction) or get_rep(faction) < Factions.LICENCE_REP or credits < int(f["licence_cost"]):
		return false
	credits -= int(f["licence_cost"])
	licences[faction] = true
	return true


## Licence perks on what a station pays you.
func sell_bonus(station: String, item: String) -> float:
	var b := 1.0
	if has_licence("haulers") and Factions.of_station(station) == "haulers":
		b += 0.05
	if has_licence("comet") and Economy.GOODS.get(item, {}).get("illegal", false):
		b += 0.10
	return b


func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out


func reset_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	mission_counter = 0
	_new_pilot()
	_offer_missions()


static func station_name(id: String) -> String:
	return Galaxy.station_name(id)
