class_name Colonisation
extends RefCounted
## Colonisation rules: who may settle an uncolonised province, how fast and at
## what cost. Pure functions of the world; ColonisationSystem applies them
## month by month.
##
## A country settles land through its colonial policy — the idea it has
## adopted: none, settling its own frontier (by land or across a strait),
## overseas ventures, or a colonial empire. A colony advances every month by
## a rate made of named factors:
## * access — the frontier next to our land is easiest, across a strait
##   (a sea one of our coasts touches, colonies' too) nearly as easy;
##   overseas is harder the more seas lie between it and our home ports (the
##   coasts near our capital: settlers sail from home, not from distant
##   colonies). Inland provinces can only be settled from our own land beside
##   them, so colonies creep inland from the coast;
## * the land — open farmland and grassland settle fast; forest, jungle,
##   desert, mountains and marsh slowly; arctic land hardly at all;
## * the climate — settlers from a like climate (Russians in Siberia) do
##   well; far from home they struggle;
## * the natives — the more people already live there, the slower (and the
##   more often they rise against the settlers); neighbouring peoples (land in
##   the settler's own part of the world) are absorbed far more easily than
##   foreigners overseas;
## * disease — the tropics of Africa and New Guinea killed settlers from
##   cooler lands: before quinine (c. 1850) only their coasts can be held,
##   and slowly; the interior opens with quinine, steamboats and railways.
##   Peoples at home in the tropics are not held back.
## Until technology exists, the calendar stands in for the medical revolution.

const POLICIES := ["None", "Settle the frontier", "Overseas ventures", "Colonial empire"]
## Colonies a country can found at once, whether it may cross the sea, and the
## colonial office's monthly cost, per policy.
const POLICY_COLONIES := [0, 2, 2, 4]
const POLICY_OVERSEAS := [false, false, true, true]
const POLICY_UPKEEP := [0.0, 1.0, 3.0, 6.0]
## Each colony's monthly upkeep, and the cost of founding one (more across
## more seas); both rise with inflation.
const COLONY_UPKEEP := 1.0
const FOUNDING_COST := 30.0
const FOUNDING_COST_PER_SEA := 2.0

## Percent a month under ideal conditions, before the factors.
const BASE_PROGRESS := 2.5
const ACCESS_FRONTIER := 1.5
const ACCESS_STRAIT := 1.1
const ACCESS_OVERSEAS := 0.7
## Sea tiles to cross at which the overseas factor halves; beyond the limit
## the sea is too wide.
const OVERSEAS_HALF_SEAS := 10.0
const MAX_SEAS := 60

const VEGETATION_EASE := {"farmland": 1.0, "grasslands": 1.0, "woods": 0.85, "sparse": 0.75, "forest": 0.7,
	"jungle": 0.45, "desert": 0.4}
const TOPOGRAPHY_EASE := {"flatland": 1.0, "hills": 0.85, "plateau": 0.85, "mountains": 0.6, "wetlands": 0.6}
const ARCTIC_EASE := 0.4

## Climates on a warmth scale (dry ones flagged), for how far a land is from
## the settlers' home climates (those within HOME_RADIUS_KM of the capital).
const CLIMATE_WARMTH := {"arctic": 0.0, "subarctic": 1.0, "continental": 1.8, "cold_arid": 2.0, "oceanic": 2.3,
	"mediterranean": 3.0, "subtropical": 3.5, "hot_arid": 4.0, "tropical": 4.5, "equatorial": 5.0}
const DRY_CLIMATES := ["cold_arid", "hot_arid"]
const FAMILIARITY_PER_STEP := 0.15
const DRY_PENALTY := 0.15
const MIN_FAMILIARITY := 0.4
const HOME_RADIUS_KM := 1500.0

## Natives at which settling goes at half speed; their monthly chance of
## rising (with many natives) and the progress an uprising undoes. Neighbouring
## peoples count NEIGHBOURS_EASE times fewer and rise half as often.
const NATIVE_SCALE := 25000.0
const UPRISING_CHANCE := 0.02
const UPRISING_LOSS := 10.0
const NEIGHBOURS_EASE := 2.0

## Disease for settlers not at home in the tropics, by year until technology
## exists: [from year, factor on the coast, factor inland (0 = closed)].
const MEDICINE := [[0, 0.3, 0.0], [1850, 0.7, 0.4], [1880, 1.0, 0.8]]
const TROPICAL := ["tropical", "equatorial"]

## Peoples with a tradition of settling the land beside them: [label, factor
## on frontier colonies]. Russia's Cossacks and promyshlenniki crossed Siberia
## to the Pacific within sixty years of Yermak (the user asked for it).
const FRONTIER_TRADITIONS := {"RUS": ["Cossack frontier", 1.6]}

## Settlers who arrive when a colony is complete; the natives stay, as tribesmen.
const SETTLERS := {"nobility": 30, "clergy": 40, "merchants": 80, "commoners": 1500}


## Tropical Africa and New Guinea: the lands where disease held settlers from
## cooler climates back until the 19th century.
static func in_disease_zone(p: Province) -> bool:
	if p.lat > -11.0 and p.lat < 0.5 and p.lon > 130.8 and p.lon < 151.0:
		return true  # New Guinea
	var africa := p.lat > -26.0 and p.lat < 18.0 and p.lon > -18.0 and p.lon < 52.0
	return africa and (p.climate in TROPICAL or p.vegetation == "jungle" or p.topography == "wetlands")


## Whether settlers from these home climates are at home in the tropics.
static func seasoned(home_climates: Dictionary) -> bool:
	for c: String in TROPICAL:
		if home_climates.has(c):
			return true
	return false


## [from year, coast factor, inland factor] for a year.
static func medicine(year: int) -> Array:
	var stage: Array = MEDICINE[0]
	for m: Array in MEDICINE:
		if year >= m[0]:
			stage = m
	return stage


static func disease_factor(p: Province, is_seasoned: bool, year: int) -> float:
	if is_seasoned or not in_disease_zone(p):
		return 1.0
	var stage := medicine(year)
	return stage[1] if p.is_coastal else stage[2]


## How easily the land itself takes settlers.
static func land_factor(p: Province) -> float:
	var f: float = VEGETATION_EASE.get(p.vegetation, 0.8) * TOPOGRAPHY_EASE.get(p.topography, 0.8)
	return f * ARCTIC_EASE if p.climate == "arctic" else f


## How familiar a province's climate is to settlers from these home climates.
static func familiarity(p: Province, home_climates: Dictionary) -> float:
	if home_climates.is_empty():
		return 1.0
	var best := MIN_FAMILIARITY
	var warmth: float = CLIMATE_WARMTH.get(p.climate, 2.5)
	for h: String in home_climates:
		var f := 1.0 - FAMILIARITY_PER_STEP * absf(CLIMATE_WARMTH.get(h, 2.5) - warmth)
		if (h in DRY_CLIMATES) != (p.climate in DRY_CLIMATES):
			f -= DRY_PENALTY
		best = maxf(best, f)
	return minf(best, 1.0)


static func native_factor(natives: int, neighbours := false) -> float:
	var scale := NATIVE_SCALE * (NEIGHBOURS_EASE if neighbours else 1.0)
	return 1.0 / (1.0 + natives / scale)


static func uprising_chance(natives: int, neighbours := false) -> float:
	var scale := NATIVE_SCALE * (NEIGHBOURS_EASE if neighbours else 1.0)
	return UPRISING_CHANCE * (0.5 if neighbours else 1.0) * natives / (natives + scale)


## Overseas access across `seas` sea tiles.
static func overseas_factor(seas: int) -> float:
	return ACCESS_OVERSEAS / (1.0 + seas / OVERSEAS_HALF_SEAS)


static func founding_cost(seas: int, inflation: float) -> float:
	return EconomySystem.decimal((FOUNDING_COST + FOUNDING_COST_PER_SEA * seas) * (1.0 + inflation / 100.0))
