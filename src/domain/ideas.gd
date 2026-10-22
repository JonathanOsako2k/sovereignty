class_name Ideas
extends RefCounted
## Ideas a government takes up: ways of filling its army and navy beyond what
## barracks and docks train. A realm holds one idea for every age it has
## reached (SLOTS); taking one up costs ADOPT_MONTHS of its taxes and it is
## kept. Not every realm can take every idea: press gangs and naval academies
## need a dock of its own; conscription waits for the age of the levée en
## masse. In 1590 the seafaring powers of the west already press men (START);
## others must take the idea up.

const CATALOGUE := {
	"press_gangs": {"name": "Press gangs", "from": 1590, "dock": true,
		"about": "An army in one of our provinces (or a fleet in its dock) seizes some of its common people "
			+ "for the army (or the navy) — once a year a province, at the cost of unrest"},
	"drill_grounds": {"name": "Drill grounds", "from": 1590,
		"about": "Barracks train half as many soldiers again"},
	"naval_academies": {"name": "Naval academies", "from": 1650, "dock": true,
		"about": "Docks train half as many sailors again"},
	"conscription": {"name": "Conscription", "from": 1793,
		"about": "Every man liable to serve: twice the manpower ceiling and its growth"},
}
## Ideas a realm may hold by the year: [from year, slots].
const SLOTS := [[1590, 1], [1650, 2], [1720, 3], [1793, 4]]
## Months of taxes an idea costs to take up (at least ADOPT_MIN ducats).
const ADOPT_MONTHS := 6.0
const ADOPT_MIN := 50.0
## The ideas realms hold in 1590.
const START := {
	"ENG": ["press_gangs"], "NED": ["press_gangs"], "SPA": ["press_gangs"], "POR": ["press_gangs"],
	"VEN": ["press_gangs"],
}


static func name_of(id: String) -> String:
	return CATALOGUE[id].name if CATALOGUE.has(id) else id


static func slots(year: int) -> int:
	var n := 0
	for s: Array in SLOTS:
		if year >= s[0]:
			n = s[1]
	return n


static func has(c: Country, id: String) -> bool:
	return c != null and id in c.ideas


## Why `c` cannot take up an idea ("" if it can). `docked`: whether it has a
## dock of its own.
static func blocked(c: Country, id: String, year: int, docked: bool, cost: float) -> String:
	var idea: Dictionary = CATALOGUE.get(id, {})
	if idea.is_empty():
		return "Unknown idea"
	if id in c.ideas:
		return "Already ours"
	if year < int(idea.from):
		return "Not before %d" % idea.from
	if idea.get("dock", false) and not docked:
		return "Needs a dock of our own"
	if c.ideas.size() >= slots(year):
		return "No room for another idea until the next age" if slots(year) < SLOTS[SLOTS.size() - 1][1] \
			else "No room for another idea"
	if c.treasury < cost:
		return "Needs %d ducats" % int(ceil(cost))
	return ""
