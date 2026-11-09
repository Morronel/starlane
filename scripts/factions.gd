class_name Factions
extends RefCounted
## 0.13 "People": who runs the stations, how much they like you, and the
## licences you can buy once they do.

const LIST := {
	"haulers": {"name": "Haulers' Guild", "color": Color(1.0, 0.78, 0.4),
		"desc": "Truckers, traders and the folks who keep the rest stops' coffee hot.",
		"licence": "Guild Licence", "licence_cost": 6000,
		"perk": "Guild stations pay you 5% more for cargo."},
	"navy": {"name": "Concord Navy", "color": Color(0.5, 0.75, 1.0),
		"desc": "Patrols, fortresses and paperwork. They like pirates gone.",
		"licence": "Navy Commission", "licence_cost": 12000,
		"perk": "Buy military hulls; customs waves you through."},
	"miners": {"name": "Free Miners' Union", "color": Color(1.0, 0.55, 0.3),
		"desc": "Ice, ore and gas. Loud bars, honest prices.",
		"licence": "Union Card", "licence_cost": 5000,
		"perk": "Repairs cost 30% less everywhere."},
	"lantern": {"name": "Lantern Order", "color": Color(0.75, 1.0, 0.85),
		"desc": "Scholars, monks and stargazers chasing the Lost Lanes.",
		"licence": "Pilgrim's Seal", "licence_cost": 7000,
		"perk": "Rumours are on the house; postcards pay 50% more."},
	"comet": {"name": "Black Comet", "color": Color(1.0, 0.35, 0.45),
		"desc": "Smugglers and fixers. Never call them pirates to their face.",
		"licence": "Comet Mark", "licence_cost": 9000,
		"perk": "Road pirates let you pass; contraband sells 10% higher."},
}

const LICENCE_REP := 25


static func of_station(sid: String) -> String:
	return Galaxy.station(sid).get("faction", "haulers")


static func standing(rep: int) -> String:
	if rep >= 60:
		return "Family"
	if rep >= 25:
		return "Trusted"
	if rep >= 8:
		return "Friendly"
	if rep > -8:
		return "Neutral"
	if rep > -30:
		return "Wary"
	return "Hostile"


static func standing_color(rep: int) -> Color:
	if rep >= 25:
		return Color(0.45, 1.0, 0.6)
	if rep >= 8:
		return Color(0.7, 1.0, 0.8)
	if rep > -8:
		return Color(0.75, 0.82, 0.9)
	return Color(1.0, 0.45, 0.4)
