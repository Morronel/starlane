extends Node
## Persistent player/economy state (autoload "GameState"). Saved to user://save.json.

signal credits_changed(value: int)
signal message(text: String, color: Color)
signal mission_completed

const SAVE_PATH := "user://save.json"

const UPGRADES := {
	"laser": {"name": "Pulse Lasers", "max": 4, "cost": [0, 900, 2200, 4800], "desc": "+35% damage per level"},
	"shield": {"name": "Shield Emitter", "max": 4, "cost": [0, 700, 1800, 4000], "desc": "+40 shield capacity per level"},
	"engine": {"name": "Ion Drive", "max": 4, "cost": [0, 800, 2000, 4400], "desc": "+15% top speed per level"},
	"cargo": {"name": "Cargo Racks", "max": 4, "cost": [0, 500, 1400, 3200], "desc": "+10 cargo units per level"},
	"jump": {"name": "Jump Capacitors", "max": 4, "cost": [0, 1200, 2600, 5200], "desc": "+1 stargate jump charge per level"},
}

const JUMP_CELL_PRICE := 140

var credits: int = 1500:
	set(v):
		credits = v
		credits_changed.emit(v)

var cargo: Dictionary = {}
var upgrades := {"laser": 1, "shield": 1, "engine": 1, "cargo": 1, "jump": 1}
var hull: float = 100.0
var kills: int = 0
var last_station: String = "halcyon"
var system_id: String = "tessaly"
var jump_charges: int = 2
var visited := {"tessaly": true}

var missions: Array = []
var mission_counter := 0


func _ready() -> void:
	if not load_game():
		_offer_missions()


# --- derived stats -----------------------------------------------------------

func cargo_capacity() -> int:
	return 10 + upgrades["cargo"] * 10


func cargo_used() -> int:
	var n := 0
	for k in cargo:
		n += cargo[k]
	return n


func max_shield() -> float:
	return 60.0 + upgrades["shield"] * 40.0


func laser_damage() -> float:
	return 9.0 * (1.0 + (upgrades["laser"] - 1) * 0.35)


func top_speed() -> float:
	return 120.0 * (1.0 + (upgrades["engine"] - 1) * 0.15)


func max_jump_charges() -> int:
	return 1 + upgrades["jump"]


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


func upgrade(id: String) -> bool:
	var lvl: int = upgrades[id]
	var info: Dictionary = UPGRADES[id]
	if lvl >= info["max"]:
		return false
	var cost: int = info["cost"][lvl]
	if credits < cost:
		return false
	credits -= cost
	upgrades[id] = lvl + 1
	if id == "jump":
		jump_charges += 1
	return true


func repair_cost() -> int:
	return int(ceil((100.0 - hull) * 6.0))


func repair() -> bool:
	var c := repair_cost()
	if c <= 0 or credits < c:
		return false
	credits -= c
	hull = 100.0
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
	while hunts < 2:
		mission_counter += 1
		var sid: String = system_id
		if hunt_systems.has(sid):
			var free := sys_ids.filter(func(x): return not hunt_systems.has(x))
			sid = free[rng.randi() % free.size()]
		hunt_systems[sid] = true
		var threat: int = Galaxy.SYSTEMS[sid]["threat"]
		var n := 3 + mini(mission_counter / 2, 3) + threat - 1
		missions.append({
			"id": mission_counter, "kind": "hunt", "state": "offered", "system": sid,
			"title": "Raider nest in %s" % Galaxy.SYSTEMS[sid]["name"],
			"desc": "Raiders are preying on lane traffic near the beacon in %s. Drop out at the beacon and destroy %d raiders." % [Galaxy.SYSTEMS[sid]["name"], n],
			"count": n, "left": n, "reward": 600 + n * 220 + threat * 300, "station": "",
		})
		hunts += 1
	var ids := Galaxy.all_station_ids()
	while couriers < 3:
		mission_counter += 1
		var from: String = ids[rng.randi() % ids.size()]
		var to: String = ids[rng.randi() % ids.size()]
		if to == from:
			continue
		var h := Galaxy.hops(Galaxy.system_of(from), Galaxy.system_of(to))
		var kind_word: String = ["Sealed data core", "Diplomatic pouch", "Medical samples", "Encrypted charts"][rng.randi() % 4]
		missions.append({
			"id": mission_counter, "kind": "courier", "state": "offered",
			"title": "%s to %s" % [kind_word, Galaxy.station_name(to)],
			"desc": "Carry it to %s in %s (%d jump%s away)." % [Galaxy.station_name(to), Galaxy.SYSTEMS[Galaxy.system_of(to)]["name"], h, "" if h == 1 else "s"],
			"from": from, "station": to, "reward": 450 + h * 650,
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
	_offer_missions()
	return out


func on_player_destroyed() -> void:
	cargo.clear()
	credits = int(credits * 0.9)
	hull = 100.0
	for m in missions:
		if m["state"] == "active" and m["kind"] == "courier":
			m["state"] = "offered"
	system_id = Galaxy.system_of(last_station)


# --- save / load -------------------------------------------------------------

func save_game() -> void:
	var data := {
		"v": 2, "credits": credits, "cargo": cargo, "upgrades": upgrades, "hull": hull, "kills": kills,
		"last_station": last_station, "system_id": system_id, "jump_charges": jump_charges,
		"visited": visited, "missions": missions, "mission_counter": mission_counter,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != 2:
		return false
	credits = int(data["credits"])
	cargo = {}
	for k in data["cargo"]:
		cargo[k] = int(data["cargo"][k])
	for k in data["upgrades"]:
		upgrades[k] = int(data["upgrades"][k])
	hull = float(data["hull"])
	kills = int(data["kills"])
	last_station = data["last_station"]
	system_id = Galaxy.system_of(last_station)
	jump_charges = int(data["jump_charges"])
	visited = data["visited"]
	missions = data["missions"]
	for m in missions:
		for k in ["id", "count", "left", "reward"]:
			if m.has(k):
				m[k] = int(m[k])
	mission_counter = int(data["mission_counter"])
	_offer_missions()
	return true


func reset_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	credits = 1500
	cargo = {}
	upgrades = {"laser": 1, "shield": 1, "engine": 1, "cargo": 1, "jump": 1}
	hull = 100.0
	kills = 0
	last_station = "halcyon"
	system_id = "tessaly"
	jump_charges = 2
	visited = {"tessaly": true}
	missions = []
	_offer_missions()


static func station_name(id: String) -> String:
	return Galaxy.station_name(id)
