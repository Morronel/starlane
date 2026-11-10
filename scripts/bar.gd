class_name Bar
extends RefCounted
## 0.13 "People": every station has a bar. A bartender, three regulars who
## talk too much, rumours that leak upcoming market news, a dice game and a
## jukebox. Rest stops serve coffee and let you nap.

const NAMES := ["Old Mags", "Tiny Rosco", "Dr. Pell", "Juniper", "Captain Nub", "Vash", "Orla", "Bix", "Quill", "Sunny",
	"Grizz", "Momo", "Kettle", "Ines", "Dax", "Pip", "Auntie Vee", "Brass", "Lolo", "Fennick", "Marisol", "Hoot", "Zed", "Wren the Elder"]
const ROLES := ["ice hauler", "retired navy gunner", "mechanic", "Lantern monk", "smuggler (allegedly)", "cook", "poet", "tug pilot",
	"insurance adjuster", "ore miner", "card sharp", "cartographer"]
const BARTENDER_LINES := [
	"What'll it be, pilot? First sip's on the house if you tell me a good story.",
	"Wipe your boots. Not because of dirt. Because of space bees.",
	"You look like someone who's been staring at highway signs too long.",
	"House special's Nebula Fizz. Tastes like purple. Don't ask.",
	"Sit anywhere. Not there. That's Grizz's stool. Nobody knows why.",
]
const LORE := [
	"My grandpa swore there were lanes before the lanes. Lost Lanes, he called them. Roads nobody built.",
	"Ever notice the beacons hum the same note in every system? Somebody tuned them. Long before us.",
	"Pilot I knew took a wrong exit near Kharos and came back a week younger. Never flew again.",
	"The Lantern monks say the stargates aren't ours. We just found the keys under the mat.",
	"There's a signal past the Rift Lighthouse. Seven seconds, every time. Like it's waiting for an answer.",
	"Old maps show a seventh gate in Tessaly. Today's maps don't. Funny, that.",
]
const TIPS := [
	"Producers keep warehouses full, so buy where they make it. Sell where they need it. Sounds dumb. Works.",
	"Don't dump a whole hold in one market. Every crate you sell drops the price for the next one.",
	"Convoys fix shortages. If you see a SHORTAGE on the news, go now, not after lunch.",
	"Cruise on the loop and let the galaxy do its thing. Nobody ever got rich staring at tubes.",
	"Take the exit early. The ramp slows you down, and that's the point.",
	"Rest-stop coffee is real. Fifteen percent faster lanes for a while. Science.",
]

const EVENT_RUMOUR := {
	"strike": "the crews at %s are about to down tools. No %s for a while. Prices will jump.",
	"boom": "%s is sitting on a bumper batch of %s. It'll go cheap soon.",
	"festival": "%s is planning a festival. They'll want every crate of %s they can get.",
	"shortage": "%s is running low on %s. Bring some and name your price.",
	"glut": "a convoy's about to dump %s's whole yard full of %s. Don't sell there.",
}


static func _rng(sid: String, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(sid) + salt * 7919
	return r


static func bartender(sid: String) -> Dictionary:
	var r := _rng(sid, 1)
	return {"name": NAMES[r.randi() % NAMES.size()], "seed": hash(sid) + 11, "line": BARTENDER_LINES[r.randi() % BARTENDER_LINES.size()]}


## Three regulars per station (the same faces every visit).
static func regulars(sid: String) -> Array:
	var out := []
	var r := _rng(sid, 2)
	var used := {bartender(sid)["name"]: true}
	while out.size() < 3:
		var nm: String = NAMES[r.randi() % NAMES.size()]
		if used.has(nm):
			continue
		used[nm] = true
		out.append({"name": nm, "role": ROLES[r.randi() % ROLES.size()], "seed": hash(sid + nm)})
	return out


## What regular `i` says right now. Kinds: event (upcoming market news),
## deal (a price you haven't seen), lore, tip.
static func rumour(sid: String, i: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(sid) + i * 31 + int(Economy.clock / 240.0) * 101
	var kinds := ["event", "deal", "lore", "tip"]
	var kind: String = kinds[(i + int(Economy.clock / 240.0)) % kinds.size()]
	if kind == "event":
		var ne := Economy.peek_next_event()
		if not ne.is_empty():
			var mins := maxi(1, int(ceil(Economy.next_event_in() / 60.0)))
			var txt: String = EVENT_RUMOUR[ne["kind"]] % [Galaxy.station_name(ne["station"]), Economy.good_name(ne["good"])]
			return {"kind": kind, "text": "Between you and me, " + txt + " Give it %d minute%s." % [mins, "" if mins == 1 else "s"], "valuable": true}
		kind = "deal"
	if kind == "deal":
		var best := {}
		for other in Galaxy.all_station_ids():
			if other == sid or Galaxy.hops(Galaxy.system_of(sid), Galaxy.system_of(other)) > 2:
				continue
			for g in Economy.traded(sid):
				if not Economy.trades_here(other, g) or Economy.available(sid, g) < 5:
					continue
				var gain := Economy.sell_price(other, g) - Economy.buy_price(sid, g)
				if gain > int(best.get("gain", 0)):
					best = {"g": g, "to": other, "gain": gain, "sell": Economy.sell_price(other, g)}
		if not best.is_empty():
			return {"kind": "deal", "text": "Cousin of mine just came from %s. They're paying %d a crate for %s. You can get it here for %d." % [
				Galaxy.station_name(best["to"]), best["sell"], Economy.good_name(best["g"]), Economy.buy_price(sid, best["g"])], "valuable": true}
		kind = "lore"
	if kind == "lore":
		return {"kind": kind, "text": LORE[r.randi() % LORE.size()], "valuable": false}
	return {"kind": "tip", "text": TIPS[r.randi() % TIPS.size()], "valuable": false}


## Orbit dice: two dice each. Doubles beat any plain roll (higher doubles win);
## otherwise the higher total wins. Doubles win pays 2:1. Returns the result.
static func orbit(bet: int) -> Dictionary:
	var p := [randi_range(1, 6), randi_range(1, 6)]
	var h := [randi_range(1, 6), randi_range(1, 6)]
	var pd: bool = p[0] == p[1]
	var hd: bool = h[0] == h[1]
	var ps: int = p[0] + p[1] + (100 if pd else 0)
	var hs: int = h[0] + h[1] + (100 if hd else 0)
	var win := 0
	if ps > hs:
		win = bet * (2 if pd else 1)
	elif ps < hs:
		win = -bet
	var line := ""
	if win > 0:
		line = "ORBIT! Doubles pay double." if pd else "You win. The bartender slides your chips over."
	elif win < 0:
		line = "House wins. Grizz laughs way too hard."
	else:
		line = "A tie. Nobody's happy, nobody's sad."
	return {"you": p, "house": h, "win": win, "line": line}
