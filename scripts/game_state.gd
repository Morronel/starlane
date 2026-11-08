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


func _ready() -> void:
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
	var base: int = Galaxy.COMMODITIES[item]["base"]
	var st := Galaxy.station(station)
	return int(round(base * float(st["prices"][item])))


func buy(station: String, item: String, units: int) -> int:
	var p := price(station, item)
	units = mini(units, cargo_capacity() - cargo_used())
	units = mini(units, credits / p)
	if units <= 0:
		return 0
	credits -= p * units
	cargo[item] = cargo.get(item, 0) + units
	return units


func sell(station: String, item: String, units := 9999) -> int:
	var have: int = cargo.get(item, 0)
	units = mini(units, have)
	if units <= 0:
		return 0
	var total := price(station, item) * units
	credits += total
	if units >= have:
		cargo.erase(item)
	else:
		cargo[item] = have - units
	return total


func repair_cost() -> int:
	return int(ceil((max_hull() - hull) * 5.0))


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
	if ship_id == ship:
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
			if m["kind"] == "hunt":
				return {"system": m["system"], "station": "", "beacon": true, "label": "Raider nest, " + Galaxy.SYSTEMS[m["system"]]["name"], "mission": m}
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

func _offer_missions() -> void:
	var hunts := 0
	var couriers := 0
	for m in missions:
		if m["state"] in ["offered", "active", "done"]:
			if m["kind"] == "hunt":
				hunts += 1
			else:
				couriers += 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var sys_ids := Galaxy.SYSTEMS.keys()
	var hunt_systems := {}
	for m in missions:
		if m["kind"] == "hunt" and m["state"] in ["offered", "active", "done"]:
			hunt_systems[m["system"]] = true
	while hunts < 3:
		mission_counter += 1
		var sid: String = system_id
		if hunt_systems.has(sid):
			var free := sys_ids.filter(func(x): return not hunt_systems.has(x))
			sid = free[rng.randi() % free.size()]
		hunt_systems[sid] = true
		var threat: int = Galaxy.SYSTEMS[sid]["threat"]
		var n := 3 + mini(mission_counter / 3, 3) + threat - 1
		missions.append({
			"id": mission_counter, "kind": "hunt", "state": "offered", "system": sid,
			"title": "Raider nest in %s" % Galaxy.SYSTEMS[sid]["name"],
			"desc": "Raiders are preying on lane traffic near the beacon in %s. Drop out at the beacon and destroy %d raiders." % [Galaxy.SYSTEMS[sid]["name"], n],
			"count": n, "left": n, "reward": 800 + n * 260 + threat * 400, "station": "",
		})
		hunts += 1
	var ids := Galaxy.all_station_ids()
	while couriers < 4:
		mission_counter += 1
		var from: String = ids[rng.randi() % ids.size()]
		var to: String = ids[rng.randi() % ids.size()]
		if to == from:
			continue
		var h := Galaxy.hops(Galaxy.system_of(from), Galaxy.system_of(to))
		var kind_word: String = ["Sealed data core", "Diplomatic pouch", "Medical samples", "Encrypted charts", "Prototype reactor"][rng.randi() % 5]
		missions.append({
			"id": mission_counter, "kind": "courier", "state": "offered",
			"title": "%s to %s" % [kind_word, Galaxy.station_name(to)],
			"desc": "Carry it to %s in %s (%s)." % [Galaxy.station_name(to), Galaxy.SYSTEMS[Galaxy.system_of(to)]["name"],
				"same system" if h == 0 else "%d jump%s away" % [h, "" if h == 1 else "s"]],
			"from": from, "station": to, "reward": 700 + h * 800,
		})
		couriers += 1


func missions_for(station: String) -> Array:
	var out := []
	for m in missions:
		if m["state"] == "paid":
			continue
		if m["state"] == "offered" and m["kind"] == "courier" and m["from"] != station:
			continue
		out.append(m)
	return out


func accept(m: Dictionary) -> void:
	m["state"] = "active"
	m.erase("spawned")
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
			m["state"] = "done"
			message.emit("Mission complete! Dock at any station to collect %d cr." % m["reward"], Color(0.5, 1.0, 0.6))
			mission_completed.emit()
		else:
			message.emit("Raider down (+%d cr). %d left." % [bounty, m["left"]], Color(1, 0.85, 0.4))
	else:
		message.emit("Raider destroyed. Bounty +%d cr" % bounty, Color(1, 0.85, 0.4))


func turn_in(station: String) -> Array:
	var out := []
	for m in missions:
		var pay := false
		if m["state"] == "done":
			pay = true
		elif m["state"] == "active" and m["kind"] == "courier" and m["station"] == station:
			pay = true
		if pay:
			m["state"] = "paid"
			credits += m["reward"]
			out.append("%s: +%d cr" % [m["title"], m["reward"]])
	missions = missions.filter(func(m): return m["state"] != "paid")
	if destination.get("type", "") == "station" and destination["id"] == station:
		destination = {}
	destination_info()   # drops a finished mission destination
	_offer_missions()
	_auto_track()
	return out


func on_player_destroyed() -> void:
	cargo.clear()
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
		"v": 3, "credits": credits, "cargo": cargo, "hull": hull, "kills": kills,
		"last_station": last_station, "system_id": system_id, "jump_charges": jump_charges,
		"visited": visited, "missions": missions, "mission_counter": mission_counter,
		"ship": ship, "equip": equip, "storage": storage, "ammo": ammo, "parts": parts,
		"blueprints": blueprints, "destination": destination,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
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
	_offer_missions()
	return true


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
