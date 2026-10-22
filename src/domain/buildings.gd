class_name Buildings
extends RefCounted
## What a government can build in its provinces, one of each, built over some
## months and paid for up front (costs rise with inflation). Buildings do one
## of four things:
## * extraction — more raw goods from the same workers;
## * income — money for the state (customs) or the merchants (markets);
## * protection — forts (sieges take months);
## * military — barracks, which train soldiers into the manpower pool;
## * naval — docks, where fleets berth, ships are built and sailors trained;
## * manufacture — turn part of the province's raw output into a made good.

const CATALOGUE := {
	# Extraction: +share of raw units for goods of these kinds (or these goods).
	"farm_estates": {"name": "Farm estates", "type": "extraction", "cost": 60.0, "months": 12,
		"extraction": 0.30, "kinds": ["farm"], "about": "+30 % crops and herds"},
	"plantation": {"name": "Plantation", "type": "extraction", "cost": 80.0, "months": 18,
		"extraction": 0.40, "kinds": ["cash"], "about": "+40 % cash crops"},
	"mine": {"name": "Mine", "type": "extraction", "cost": 80.0, "months": 18,
		"extraction": 0.50, "kinds": ["mine"], "about": "+50 % ores and minerals"},
	"lumber_camp": {"name": "Lumber camp", "type": "extraction", "cost": 50.0, "months": 9,
		"extraction": 0.30, "goods": ["timber", "naval_supplies", "tropical_wood", "furs", "ivory"],
		"about": "+30 % timber, furs and other gathered goods"},
	"fishing_harbour": {"name": "Fishing harbour", "type": "extraction", "cost": 50.0, "months": 9,
		"extraction": 0.30, "goods": ["fish"], "coastal": true, "about": "+30 % fish"},
	# Income
	"marketplace": {"name": "Marketplace", "type": "income", "cost": 50.0, "months": 9,
		"merchant_bonus": 0.5, "about": "Merchants earn half again as much (and pay tax on it)"},
	"customs_house": {"name": "Customs house", "type": "income", "cost": 70.0, "months": 12,
		"customs": 0.08, "coastal": true, "about": "Tariffs: 8 % of the province's output to the treasury"},
	# Protection
	"fort": {"name": "Fort", "type": "protection", "cost": 100.0, "months": 24, "upkeep": 1.0,
		"about": "A garrison: besiegers need guns and months to take it; before 1800 it bars the roads about it; 1 ducat a month upkeep"},
	# Military
	"barracks": {"name": "Barracks", "type": "military", "cost": 80.0, "months": 12, "upkeep": 1.0,
		"about": "Trains the people into soldiers: more manpower each month, and a higher ceiling; 1 ducat a month upkeep"},
	# Naval
	"dock": {"name": "Dock", "type": "naval", "cost": 80.0, "months": 12, "upkeep": 0.5, "coastal": true,
		"about": "Our fleets berth here — safe, repaired and refilled at half upkeep; ships are built and sailors trained here"},
	# Manufacture: turns half the raw output into the made good.
	"weavery": {"name": "Weavery", "type": "manufacture", "cost": 90.0, "months": 18, "min_development": 3,
		"recipes": {"wool": ["cloth", 1.0], "cotton": ["cloth", 1.0], "silk": ["silk_fabric", 1.0]},
		"about": "Wool or cotton into cloth, raw silk into silk fabric"},
	"ironworks": {"name": "Ironworks", "type": "manufacture", "cost": 100.0, "months": 18, "min_development": 3,
		"recipes": {"iron": ["tools", 1.0], "copper": ["tools", 0.9], "tin": ["tools", 0.9]},
		"about": "Iron, copper or tin into tools"},
	"kilns": {"name": "Porcelain kilns", "type": "manufacture", "cost": 100.0, "months": 18, "min_development": 3,
		"recipes": {"kaolin": ["porcelain", 0.34]}, "about": "Kaolin into porcelain"},
	"tannery": {"name": "Tannery", "type": "manufacture", "cost": 60.0, "months": 12, "min_development": 2,
		"recipes": {"livestock": ["leather", 1.0]}, "about": "Livestock into leather"},
	"joinery": {"name": "Joinery", "type": "manufacture", "cost": 60.0, "months": 12, "min_development": 2,
		"recipes": {"timber": ["furniture", 1.0], "tropical_wood": ["furniture", 1.2]},
		"about": "Timber into furniture"},
	"distillery": {"name": "Distillery", "type": "manufacture", "cost": 70.0, "months": 12, "min_development": 2,
		"recipes": {"sugar": ["spirits", 0.9], "grain": ["spirits", 0.25]}, "about": "Sugar or grain into spirits"},
}
## Share of a province's raw output a manufactory works up.
const MANUFACTURE_SHARE := 0.5
## Manufacturing employs burghers: merchants there earn this much more.
const MANUFACTURE_MERCHANT_BONUS := 0.5


static func name_of(id: String) -> String:
	return CATALOGUE[id].name if CATALOGUE.has(id) else id


## A word for the map: "Fort", "Dock", "Customs" …
static func short_name(id: String) -> String:
	return {"farm_estates": "Estates", "lumber_camp": "Lumber", "fishing_harbour": "Fishery",
		"customs_house": "Customs", "kilns": "Kilns"}.get(id, name_of(id).get_slice(" ", 0))


static func type_of(id: String) -> String:
	return CATALOGUE[id].type if CATALOGUE.has(id) else ""


## Why `id` cannot go in this province ("" if it can).
static func unsuitable(id: String, p: Province) -> String:
	var b: Dictionary = CATALOGUE.get(id, {})
	if b.is_empty():
		return "Unknown building"
	if id in p.buildings:
		return "Already built"
	if not p.construction.is_empty():
		return "Already building %s" % name_of(p.construction[0])
	if b.has("kinds") and not Goods.kind_of(p.resource) in b.kinds:
		return "Of no use for %s" % Goods.name_of(p.resource)
	if b.has("goods") and not p.resource in b.goods:
		return "Of no use for %s" % Goods.name_of(p.resource)
	if b.has("recipes") and not b.recipes.has(p.resource):
		return "Cannot work %s" % Goods.name_of(p.resource)
	if b.type == "manufacture" and _has_manufactory(p):
		return "One manufactory per province"
	if b.get("coastal", false) and not p.is_coastal:
		return "Needs a coast"
	if p.development < b.get("min_development", 0):
		return "Needs development %d" % b.min_development
	return ""


## Whether `id` could ever serve this province as it is (its good and its
## coast), built or not: what a build list offers.
static func relevant(id: String, p: Province) -> bool:
	var b: Dictionary = CATALOGUE.get(id, {})
	if b.is_empty() or id in p.buildings:
		return false
	if b.has("kinds") and not Goods.kind_of(p.resource) in b.kinds:
		return false
	if b.has("goods") and not p.resource in b.goods:
		return false
	if b.has("recipes") and not b.recipes.has(p.resource):
		return false
	return p.is_coastal or not b.get("coastal", false)


static func _has_manufactory(p: Province) -> bool:
	for id: String in p.buildings:
		if type_of(id) == "manufacture":
			return true
	return false


## Raw output multiplier from extraction buildings.
static func extraction_bonus(p: Province) -> float:
	var bonus := 1.0
	for id: String in p.buildings:
		var b: Dictionary = CATALOGUE.get(id, {})
		if b.get("type") != "extraction":
			continue
		if (b.has("kinds") and Goods.kind_of(p.resource) in b.kinds) or (b.has("goods") and p.resource in b.goods):
			bonus += b.extraction
	return bonus


## The province's manufactory recipe for its good: [made good, units per raw unit] or [].
static func recipe(p: Province) -> Array:
	for id: String in p.buildings:
		var recipes: Dictionary = CATALOGUE.get(id, {}).get("recipes", {})
		if recipes.has(p.resource):
			return recipes[p.resource]
	return []


static func merchant_bonus(p: Province) -> float:
	var bonus := 1.0
	for id: String in p.buildings:
		bonus += CATALOGUE.get(id, {}).get("merchant_bonus", 0.0)
	if not recipe(p).is_empty():
		bonus += MANUFACTURE_MERCHANT_BONUS
	return bonus


static func customs_share(p: Province) -> float:
	var share := 0.0
	for id: String in p.buildings:
		share += CATALOGUE.get(id, {}).get("customs", 0.0)
	return share


static func upkeep(p: Province) -> float:
	var total := 0.0
	for id: String in p.buildings:
		total += CATALOGUE.get(id, {}).get("upkeep", 0.0)
	return total
