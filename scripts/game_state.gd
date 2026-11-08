extends Node
## Persistent player/economy state for the prototype (autoload "GameState").

signal credits_changed(value: int)
signal message(text: String, color: Color)

const COMMODITIES := {
	"ice": {"name": "Ice Cores", "base": 40},
	"cells": {"name": "Fusion Cells", "base": 120},
	"gel": {"name": "Medical Gel", "base": 260},
}

## Price multipliers per station. Halcyon Yard mines ice and makes cells,
## Verdant Spire is an agri/medical habitat that needs both.
const STATION_PRICES := {
	"halcyon": {"ice": 0.75, "cells": 0.85, "gel": 1.18},
	"verdant": {"ice": 1.35, "cells": 1.25, "gel": 0.9},
}

const UPGRADES := {
	"laser": {"name": "Pulse Lasers", "max": 4, "cost": [0, 900, 2200, 4800], "desc": "+35% damage per level"},
	"shield": {"name": "Shield Emitter", "max": 4, "cost": [0, 700, 1800, 4000], "desc": "+40 shield per level"},
	"engine": {"name": "Ion Drive", "max": 4, "cost": [0, 800, 2000, 4400], "desc": "+15% top speed per level"},
	"cargo": {"name": "Cargo Racks", "max": 4, "cost": [0, 500, 1400, 3200], "desc": "+10 cargo per level"},
}

var credits: int = 1500:
	set(v):
		credits = v
		credits_changed.emit(v)

var cargo: Dictionary = {}          # commodity id -> units
var upgrades := {"laser": 1, "shield": 1, "engine": 1, "cargo": 1}
var hull: float = 100.0
var kills: int = 0
var last_station: String = "halcyon"

## Missions: {id, title, desc, reward, kind, target_station, state}
## state: "offered", "active", "done" (needs turn-in), "paid"
var missions: Array = []
var mission_counter := 0


func _ready() -> void:
	_offer_missions()


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


func price(station: String, item: String) -> int:
	var base: int = COMMODITIES[item]["base"]
	return int(round(base * STATION_PRICES[station][item]))


func buy(station: String, item: String, units: int) -> int:
	var p := price(station, item)
	units = mini(units, cargo_capacity() - cargo_used())
	units = mini(units, credits / p)
	if units <= 0:
		return 0
	credits -= p * units
	cargo[item] = cargo.get(item, 0) + units
	return units


func sell(station: String, item: String) -> int:
	var units: int = cargo.get(item, 0)
	if units <= 0:
		return 0
	var total := price(station, item) * units
	credits += total
	cargo.erase(item)
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


# --- Missions ---------------------------------------------------------------

func _offer_missions() -> void:
	var has_hunt := false
	var has_courier := false
	for m in missions:
		if m["state"] in ["offered", "active", "done"]:
			if m["kind"] == "hunt":
				has_hunt = true
			if m["kind"] == "courier":
				has_courier = true
	if not has_hunt:
		mission_counter += 1
		var n := 3 + mini(mission_counter, 4)
		missions.append({
			"id": mission_counter, "kind": "hunt", "state": "offered",
			"title": "Raider nest at Kessler Beacon",
			"desc": "Raiders are preying on lane traffic near Kessler Beacon. Take the lane, drop out at the beacon and destroy %d raiders." % n,
			"count": n, "left": n, "reward": 700 + n * 220, "station": "",
		})
	if not has_courier:
		mission_counter += 1
		var from: String = ["halcyon", "verdant"][mission_counter % 2]
		var to := "verdant" if from == "halcyon" else "halcyon"
		missions.append({
			"id": mission_counter, "kind": "courier", "state": "offered",
			"title": "Sealed data core to %s" % station_name(to),
			"desc": "Carry a sealed data core to %s. No questions asked, fast pay." % station_name(to),
			"from": from, "station": to, "reward": 650,
		})


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


func active_hunt() -> Dictionary:
	for m in missions:
		if m["kind"] == "hunt" and m["state"] == "active":
			return m
	return {}


func on_enemy_killed(bounty: int) -> void:
	kills += 1
	credits += bounty
	var m := active_hunt()
	if not m.is_empty():
		m["left"] = maxi(0, m["left"] - 1)
		if m["left"] == 0:
			m["state"] = "done"
			message.emit("Mission complete! Dock at any station to collect %d cr." % m["reward"], Color(0.5, 1.0, 0.6))
		else:
			message.emit("Raider down. %d left." % m["left"], Color(1, 0.85, 0.4))


## Called on docking. Returns a list of strings describing payouts.
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
	if not out.is_empty():
		_offer_missions()
	return out


func on_player_destroyed() -> void:
	cargo.clear()
	credits = int(credits * 0.9)
	hull = 100.0
	for m in missions:
		if m["state"] == "active" and m["kind"] == "courier":
			m["state"] = "offered"


static func station_name(id: String) -> String:
	return {"halcyon": "Halcyon Yard", "verdant": "Verdant Spire"}.get(id, id)
