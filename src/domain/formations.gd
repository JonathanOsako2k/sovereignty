class_name Formations
extends RefCounted
## Nations a realm may form by uniting its people (see NationSystem): the
## culture whose land it must hold, how much of it, and what it becomes. A
## formed nation keeps its tag; its name and adjective change (saved as
## Country.formed), it gains claims on the rest of its people's land, and it
## may integrate their uncolonised land outright.

const CATALOGUE := {
	"manchuria": {"name": "Manchuria", "adjective": "Manchu", "culture": "jurchen", "min_provinces": 6,
		"rank": Ranks.MINOR_KINGDOM,
		"about": "The Jurchen tribes united under one khan: claims on all Jurchen land, and the Wild Jurchens' "
			+ "country integrated by a march and a payment instead of years of settling"},
}


static func name_of(id: String) -> String:
	return CATALOGUE[id].name if CATALOGUE.has(id) else id


## A country's name and adjective after the nations it has formed (the
## last one's), else its own.
static func apply_name(c: Country) -> void:
	if c.base_name == "":
		c.base_name = c.name
		c.base_adjective = c.adjective
	var f: Dictionary = CATALOGUE.get(c.formed[c.formed.size() - 1], {}) if not c.formed.is_empty() else {}
	c.name = f.name if not f.is_empty() else c.base_name
	c.adjective = f.adjective if not f.is_empty() else c.base_adjective


## Nations a country of this culture could form.
static func for_culture(culture: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in CATALOGUE:
		if CATALOGUE[id].culture == culture:
			out.append(id)
	return out
