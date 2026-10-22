class_name Religions
extends RefCounted
## The faiths of the world, 1590–1949, in families (christian, muslim, dharmic,
## eastern, pagan). Every province holds one faith (Province.religion), every
## country a state religion (Country.religion). Land of another faith than its
## owner's is restless — the more so across families — and missionaries
## convert it (ReligionSystem).

const CATALOGUE := {
	"catholic": {"name": "Catholic", "family": "christian", "color": Color(0.93, 0.86, 0.42)},
	"protestant": {"name": "Lutheran", "family": "christian", "color": Color(0.36, 0.55, 0.85)},
	"reformed": {"name": "Reformed", "family": "christian", "color": Color(0.55, 0.38, 0.75)},
	"anglican": {"name": "Anglican", "family": "christian", "color": Color(0.86, 0.45, 0.50)},
	"orthodox": {"name": "Orthodox", "family": "christian", "color": Color(0.90, 0.62, 0.26)},
	"oriental": {"name": "Oriental Orthodox", "family": "christian", "color": Color(0.76, 0.50, 0.30)},
	"sunni": {"name": "Sunni", "family": "muslim", "color": Color(0.20, 0.58, 0.30)},
	"shia": {"name": "Shia", "family": "muslim", "color": Color(0.36, 0.74, 0.50)},
	"ibadi": {"name": "Ibadi", "family": "muslim", "color": Color(0.15, 0.42, 0.36)},
	"hindu": {"name": "Hindu", "family": "dharmic", "color": Color(0.30, 0.78, 0.82)},
	"theravada": {"name": "Theravada Buddhist", "family": "eastern", "color": Color(0.95, 0.60, 0.45)},
	"vajrayana": {"name": "Tibetan Buddhist", "family": "eastern", "color": Color(0.75, 0.30, 0.24)},
	"confucian": {"name": "Confucian", "family": "eastern", "color": Color(0.82, 0.76, 0.60)},
	"shinto": {"name": "Shinto", "family": "eastern", "color": Color(0.88, 0.32, 0.38)},
	"animist": {"name": "Animist", "family": "pagan", "color": Color(0.52, 0.42, 0.32)},
}
## Unrest a month's target gains in land of another faith than its owner's:
## of the same family (a heresy), or of another.
const HERETIC_UNREST := 5.0
const HEATHEN_UNREST := 10.0


static func has(id: String) -> bool:
	return CATALOGUE.has(id)


static func name_of(id: String) -> String:
	return CATALOGUE[id].name if CATALOGUE.has(id) else "Unknown"


static func family_of(id: String) -> String:
	return CATALOGUE[id].family if CATALOGUE.has(id) else ""


static func color_of(id: String) -> Color:
	return CATALOGUE[id].color if CATALOGUE.has(id) else Color(0.6, 0.6, 0.6)


## The unrest a province's faith brings under a ruler of `state` faith.
static func unrest(faith: String, state: String) -> float:
	if faith == "" or state == "" or faith == state:
		return 0.0
	return HERETIC_UNREST if family_of(faith) == family_of(state) else HEATHEN_UNREST
