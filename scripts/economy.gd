class_name EconomySim
extends Node
## 0.11 "living economy" (autoload "Economy").
## Every station keeps a stock of each good it trades. Price follows stock:
## empty shelves are dear, full warehouses are cheap. Producers drift full,
## consumers drift empty, the pilot's own trades push stock around (and it
## recovers over ~10 minutes), NPC convoys haul goods from where they're
## plentiful to where they're short, and news events shake things up.

signal news_posted(item: Dictionary)
signal stepped(dt: float)   # 0.14: property, factories and the fleet run on this clock

const GOODS := {
	# raw
	"ice": {"name": "Ice Cores", "base": 40, "tier": 0, "color": Color(0.6, 0.85, 1.0)},
	"ore": {"name": "Raw Ore", "base": 55, "tier": 0, "color": Color(0.75, 0.55, 0.4)},
	"gas": {"name": "Nebula Gas", "base": 70, "tier": 0, "color": Color(0.7, 1.0, 0.45)},
	"biomass": {"name": "Biomass", "base": 50, "tier": 0, "color": Color(0.5, 0.85, 0.35)},
	"crystal": {"name": "Raw Crystal", "base": 140, "tier": 0, "color": Color(0.55, 0.9, 1.0)},
	# refined
	"water": {"name": "Pure Water", "base": 85, "tier": 1, "color": Color(0.45, 0.75, 1.0)},
	"cells": {"name": "Fusion Cells", "base": 120, "tier": 1, "color": Color(0.4, 1.0, 0.6)},
	"alloy": {"name": "Hull Alloys", "base": 180, "tier": 1, "color": Color(0.75, 0.75, 0.8)},
	"polymer": {"name": "Polymers", "base": 150, "tier": 1, "color": Color(0.95, 0.75, 0.4)},
	"food": {"name": "Ration Packs", "base": 95, "tier": 1, "color": Color(1.0, 0.85, 0.5)},
	# manufactured
	"gel": {"name": "Medical Gel", "base": 260, "tier": 2, "color": Color(1.0, 0.45, 0.55)},
	"electronics": {"name": "Electronics", "base": 320, "tier": 2, "color": Color(0.4, 0.9, 1.0)},
	"machinery": {"name": "Machinery", "base": 380, "tier": 2, "color": Color(0.85, 0.65, 0.4)},
	"shipparts": {"name": "Ship Components", "base": 450, "tier": 2, "color": Color(0.7, 0.8, 1.0)},
	# luxury
	"wine": {"name": "Starwine", "base": 420, "tier": 3, "color": Color(0.85, 0.5, 1.0)},
	"spice": {"name": "Rift Spice", "base": 520, "tier": 3, "color": Color(1.0, 0.6, 0.3)},
	"art": {"name": "Fine Art", "base": 760, "tier": 3, "color": Color(1.0, 0.85, 0.95)},
	"pets": {"name": "Exotic Pets", "base": 640, "tier": 3, "color": Color(0.6, 1.0, 0.8)},
	# contraband: not traded in the law-abiding core (threat 1 systems)
	"stims": {"name": "Combat Stims", "base": 600, "tier": 4, "color": Color(1.0, 0.35, 0.35), "illegal": true},
	"relics": {"name": "Void Relics", "base": 1100, "tier": 4, "color": Color(0.75, 0.45, 1.0), "illegal": true},
}

const EQ_MAKE := 0.82     # producers settle this full
const EQ_NEED := 0.18     # consumers settle this empty
const EQ_TRADE := 0.5     # goods a station only trades
const RECOVER := 1.0 / 540.0   # stock drifts back with this rate (per second)
const SPREAD := 0.07      # buy price is this much above the sell price

## stock[station][good] = units on the shelf; cap[station][good] = warehouse size
var stock := {}
var cap := {}
var events: Array = []    # [{id, kind, station, good, eq, until, text}]
var shipments: Array = [] # [{good, from, to, units, arrive}]
var news: Array = []      # newest first: [{text, time, color}]
var clock := 0.0          # economy seconds since the galaxy began
var _tick := 0.0
var _convoy_t := 20.0
var _event_t := 90.0
var next_event := {}      # 0.13: the event that's coming (bar rumours leak it)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	stock = {}
	cap = {}
	events = []
	shipments = []
	news = []
	next_event = {}
	clock = 0.0
	for sid in Galaxy.all_station_ids():
		stock[sid] = {}
		cap[sid] = {}
		for g in traded(sid):
			cap[sid][g] = _cap_for(g)
			stock[sid][g] = cap[sid][g] * eq(sid, g)
	post("Welcome to the Starlane markets. Watch the news: it moves prices.", Color(0.7, 0.9, 1.0))


static func good_name(g: String) -> String:
	return GOODS[g]["name"] if GOODS.has(g) else g


static func _cap_for(g: String) -> float:
	var b: float = GOODS[g]["base"]
	return clampf(round(26000.0 / b), 30.0, 420.0)


## Goods a station trades (makes, needs, or simply deals in).
static func traded(sid: String) -> Array:
	var st := Galaxy.station(sid)
	var out := []
	for k in ["makes", "needs", "deals"]:
		for g in st.get(k, []):
			if not out.has(g):
				out.append(g)
	if Galaxy.SYSTEMS[Galaxy.system_of(sid)]["threat"] <= 1:
		out = out.filter(func(g): return not GOODS[g].get("illegal", false))
	return out


static func role(sid: String, g: String) -> String:
	var st := Galaxy.station(sid)
	if st.get("makes", []).has(g):
		return "makes"
	if st.get("needs", []).has(g):
		return "needs"
	return "deals"


## Where stock settles right now (events can move it).
func eq(sid: String, g: String) -> float:
	for e in events:
		if e["station"] == sid and e["good"] == g:
			return e["eq"]
	match role(sid, g):
		"makes":
			return EQ_MAKE
		"needs":
			return EQ_NEED
	return EQ_TRADE


func ratio(sid: String, g: String) -> float:
	if not cap.has(sid) or not cap[sid].has(g):
		return 0.5
	return clampf(stock[sid][g] / cap[sid][g], 0.0, 1.0)


## A unit's worth when the shelf holds `level` units (full shelf = cheap).
func value_at(sid: String, g: String, level: float) -> int:
	var r := 0.5
	if cap.has(sid) and cap[sid].has(g):
		r = clampf(level / cap[sid][g], 0.0, 1.0)
	var f := clampf(1.8 - 1.35 * r, 0.45, 1.8)
	return maxi(1, int(round(GOODS[g]["base"] * f)))


func _level(sid: String, g: String) -> float:
	return stock[sid][g] if stock.has(sid) and stock[sid].has(g) else 0.0


## What the station pays you for one unit: priced at the shelf as it will be
## once your unit is on it. Paired with buy_price (priced at the shelf before
## the unit leaves it) this means buying a unit and selling it straight back
## always loses the spread, however big the stack.
func sell_price(sid: String, g: String) -> int:
	return value_at(sid, g, _level(sid, g) + 1.0)


## What one unit costs you.
func buy_price(sid: String, g: String) -> int:
	return int(ceil(value_at(sid, g, _level(sid, g)) * (1.0 + SPREAD)))


## What a good sells for on average across every station that trades it.
func average_sell(g: String) -> float:
	var t := 0.0
	var n := 0
	for sid in cap:
		if cap[sid].has(g):
			t += sell_price(sid, g)
			n += 1
	return t / n if n > 0 else float(GOODS[g]["base"])


func available(sid: String, g: String) -> int:
	if not stock.has(sid) or not stock[sid].has(g):
		return 0
	return int(floor(stock[sid][g]))


## The pilot's trades move the shelves.
func on_bought(sid: String, g: String, units: int) -> void:
	if stock.has(sid) and stock[sid].has(g):
		stock[sid][g] = maxf(0.0, stock[sid][g] - units)


func on_sold(sid: String, g: String, units: int) -> void:
	if stock.has(sid) and stock[sid].has(g):
		stock[sid][g] = stock[sid][g] + units


func trades_here(sid: String, g: String) -> bool:
	return cap.has(sid) and cap[sid].has(g)


# --- simulation --------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		step(_tick)
		_tick = 0.0


## Advance the whole galaxy by dt seconds (also used to catch up offline time).
func step(dt: float) -> void:
	clock += dt
	var k := 1.0 - exp(-dt * RECOVER)
	for sid in stock:
		for g in stock[sid]:
			var target: float = cap[sid][g] * eq(sid, g)
			stock[sid][g] += (target - stock[sid][g]) * k
	# deliveries
	var still := []
	for s in shipments:
		if clock >= s["arrive"]:
			if stock.has(s["to"]) and stock[s["to"]].has(s["good"]):
				stock[s["to"]][s["good"]] += s["units"]
		else:
			still.append(s)
	shipments = still
	# events expire
	var live := []
	for e in events:
		if clock < e["until"]:
			live.append(e)
		else:
			post(e["end_text"], Color(0.7, 0.85, 1.0))
	events = live
	_convoy_t -= dt
	while _convoy_t <= 0.0:
		_convoy_t += _rng.randf_range(14.0, 30.0)
		_npc_convoy()
	_event_t -= dt
	while _event_t <= 0.0:
		_event_t += _rng.randf_range(150.0, 300.0)
		_random_event()
		next_event = _pick_event()
	stepped.emit(dt)


## NPC traders: find a good that's piled up somewhere and short somewhere else
## and haul a load. This is what keeps any one route from paying forever.
func _npc_convoy() -> void:
	var gs := GOODS.keys()
	for attempt in 6:
		var g: String = gs[_rng.randi() % gs.size()]
		var hi := ""
		var lo := ""
		var rh := 0.0
		var rl := 2.0
		for sid in stock:
			if not stock[sid].has(g):
				continue
			var r := ratio(sid, g)
			if r > rh:
				rh = r
				hi = sid
			if r < rl:
				rl = r
				lo = sid
		if hi == "" or lo == "" or hi == lo or rh - rl < 0.45:
			continue
		var units: float = minf(stock[hi][g] * 0.35, cap[lo][g] * 0.3)
		if units < 5.0:
			continue
		stock[hi][g] -= units
		var h := Galaxy.hops(Galaxy.system_of(hi), Galaxy.system_of(lo))
		shipments.append({"good": g, "from": hi, "to": lo, "units": units, "arrive": clock + 70.0 + h * 60.0})
		if _rng.randf() < 0.35:
			post("Convoy: %d %s from %s heading for %s" % [int(units), good_name(g), Galaxy.station_name(hi), Galaxy.station_name(lo)], Color(0.75, 0.85, 0.95))
		return


const EVENT_KINDS := [
	{"kind": "strike", "on": "makes", "eq": 0.03, "text": "STRIKE at %s: %s production halted. Prices soaring.", "end": "The strike at %s is over: %s flowing again."},
	{"kind": "boom", "on": "makes", "eq": 1.0, "text": "BUMPER OUTPUT at %s: %s warehouses overflowing. Cheap!", "end": "%s output back to normal for %s."},
	{"kind": "festival", "on": "needs", "eq": 0.0, "text": "FESTIVAL at %s: they can't get enough %s.", "end": "The festival at %s winds down. %s demand settles."},
	{"kind": "shortage", "on": "needs", "eq": 0.0, "text": "SHORTAGE at %s: %s urgently wanted, paying top credits.", "end": "%s has its %s again."},
	{"kind": "glut", "on": "needs", "eq": 0.75, "text": "GLUT at %s: a convoy dumped %s. Don't sell there for a while.", "end": "%s has worked through its %s glut."},
]


func _random_event() -> void:
	var ne := next_event
	next_event = {}
	if not ne.is_empty() and event_at(ne["station"], ne["good"]).is_empty():
		start_event(ne["kind"], ne["station"], ne["good"], _rng.randf_range(420.0, 900.0))
		return
	var pk := _pick_event()
	if not pk.is_empty():
		start_event(pk["kind"], pk["station"], pk["good"], _rng.randf_range(420.0, 900.0))


## Choose the next random event (without starting it): {kind, station, good} or {}.
func _pick_event() -> Dictionary:
	var sids: Array = stock.keys()
	for attempt in 8:
		var ek: Dictionary = EVENT_KINDS[_rng.randi() % EVENT_KINDS.size()]
		var sid: String = sids[_rng.randi() % sids.size()]
		var pool: Array = Galaxy.station(sid).get(ek["on"], []).filter(func(g): return trades_here(sid, g))
		if pool.is_empty():
			continue
		var g: String = pool[_rng.randi() % pool.size()]
		var busy := false
		for e in events:
			if e["station"] == sid and e["good"] == g:
				busy = true
		if busy:
			continue
		return {"kind": ek["kind"], "station": sid, "good": g}
	return {}


## The next event, picked now if nothing is lined up yet (bar rumours).
func peek_next_event() -> Dictionary:
	if next_event.is_empty():
		next_event = _pick_event()
	return next_event


## Seconds until the next random event fires.
func next_event_in() -> float:
	return _event_t


func start_event(kind: String, sid: String, g: String, duration: float) -> Dictionary:
	var ek: Dictionary = {}
	for k in EVENT_KINDS:
		if k["kind"] == kind:
			ek = k
	var nm := Galaxy.station_name(sid)
	var e := {"kind": kind, "station": sid, "good": g, "eq": ek["eq"], "until": clock + duration,
		"text": ek["text"] % [nm, good_name(g)], "end_text": ek["end"] % [nm, good_name(g)]}
	events.append(e)
	# events bite quickly
	stock[sid][g] = lerpf(stock[sid][g], cap[sid][g] * e["eq"], 0.45)
	post(e["text"], Color(1.0, 0.8, 0.4))
	return e


func post(text: String, color := Color(0.8, 0.9, 1.0)) -> void:
	var item := {"text": text, "time": clock, "color": color}
	news.push_front(item)
	if news.size() > 30:
		news.resize(30)
	news_posted.emit(item)


func event_at(sid: String, g: String) -> Dictionary:
	for e in events:
		if e["station"] == sid and e["good"] == g:
			return e
	return {}


# --- trade computer ----------------------------------------------------------------

## Best deals from station `here` for a hold of `space` units and `money`
## credits, using only the prices the pilot knows (see GameState.price_memory).
## [{good, buy, to, sell, profit_unit, units, profit, hops, age}] best first.
func best_deals(here: String, space: int, money: int, memory: Dictionary, now: float) -> Array:
	var out := []
	for g in traded(here):
		var avail := available(here, g)
		if avail <= 0:
			continue
		var bp := buy_price(here, g)
		var units := mini(mini(space, avail), money / maxi(bp, 1))
		if units <= 0:
			continue
		for sid in memory:
			if sid == here:
				continue
			var m: Dictionary = memory[sid]
			if not m["p"].has(g):
				continue
			var sp: int = m["p"][g]
			# selling a full hold pushes the price down: estimate the average
			var drop: float = 1.35 * GOODS[g]["base"] * 0.5 * units / maxf(cap.get(sid, {}).get(g, 100.0), 1.0)
			var avg: float = sp - drop
			var pu: float = avg - bp
			if pu <= 0:
				continue
			var hops := Galaxy.hops(Galaxy.system_of(here), Galaxy.system_of(sid))
			out.append({"good": g, "buy": bp, "to": sid, "sell": sp, "profit_unit": int(pu), "units": units,
				"profit": int(pu * units), "hops": hops, "age": now - float(m["t"]), "score": pu * units / (1.0 + hops * 0.6)})
	out.sort_custom(func(a, b): return a["score"] > b["score"])
	return out


## Where a hold of goods would sell best, by the prices you know. One entry
## per station: {to, value, profit, goods: [{good, units, price}], hops, age, score}.
func sell_spots(here: String, hold: Dictionary, cost: Dictionary, memory: Dictionary, now: float) -> Array:
	var out := []
	for sid in memory:
		if sid == here:
			continue
		var m: Dictionary = memory[sid]
		var value := 0.0
		var paid := 0.0
		var lines := []
		for g in hold:
			var units := int(hold[g])
			if units <= 0 or not m["p"].has(g):
				continue
			var sp: int = m["p"][g]
			# selling a stack pushes the price down: estimate the average
			var drop: float = 1.35 * GOODS[g]["base"] * 0.5 * units / maxf(cap.get(sid, {}).get(g, 100.0), 1.0)
			var avg := maxf(1.0, sp - drop)
			value += avg * units
			paid += float(cost.get(g, 0))
			lines.append({"good": g, "units": units, "price": sp})
		if lines.is_empty():
			continue
		lines.sort_custom(func(a, b): return a["price"] * a["units"] > b["price"] * b["units"])
		var hops := Galaxy.hops(Galaxy.system_of(here), Galaxy.system_of(sid))
		out.append({"to": sid, "value": int(value), "profit": int(value - paid), "goods": lines, "hops": hops,
			"age": now - float(m["t"]), "score": value / (1.0 + hops * 0.35)})
	out.sort_custom(func(a, b): return a["score"] > b["score"])
	return out


# --- save / load -------------------------------------------------------------------

func to_save() -> Dictionary:
	return {"stock": stock, "events": events, "shipments": shipments, "news": news.slice(0, 10), "clock": clock,
		"saved_at": Time.get_unix_time_from_system()}


func from_save(d: Dictionary) -> void:
	reset()
	if d.is_empty():
		return
	for sid in d.get("stock", {}):
		if not stock.has(sid):
			continue
		for g in d["stock"][sid]:
			if stock[sid].has(g):
				stock[sid][g] = float(d["stock"][sid][g])
	clock = float(d.get("clock", 0.0))
	events = []
	for e in d.get("events", []):
		if stock.has(e["station"]) and stock[e["station"]].has(e["good"]):
			e["until"] = float(e["until"])
			e["eq"] = float(e["eq"])
			events.append(e)
	shipments = []
	for s in d.get("shipments", []):
		s["arrive"] = float(s["arrive"])
		s["units"] = float(s["units"])
		shipments.append(s)
	news = []
	for n in d.get("news", []):
		n["color"] = Color(0.8, 0.9, 1.0)
		news.append(n)
	# the galaxy kept trading while you were away (up to two hours of it)
	var away := clampf(Time.get_unix_time_from_system() - float(d.get("saved_at", Time.get_unix_time_from_system())), 0.0, 7200.0)
	var t := 0.0
	while t < away:
		var dt := minf(20.0, away - t)
		step(dt)
		t += dt
