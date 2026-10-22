class_name MapModes
extends RefCounted
## Colour rules for each map mode. Pure functions of world state.

enum Mode { POLITICAL, CONTROL, DIPLOMACY, COLONISATION, ECONOMY, GOODS, TOPOGRAPHY, VEGETATION, CLIMATE, POPULATION,
	COLONIAL_REGIONS, RELIGION, BUILDINGS, CULTURE }

const NAMES := {
	Mode.POLITICAL: "Political",
	Mode.CONTROL: "Control",
	Mode.DIPLOMACY: "Diplomacy",
	Mode.COLONISATION: "Colonisation",
	Mode.ECONOMY: "Economy",
	Mode.GOODS: "Goods",
	Mode.TOPOGRAPHY: "Topography",
	Mode.VEGETATION: "Vegetation",
	Mode.CLIMATE: "Climate",
	Mode.POPULATION: "Population",
	Mode.COLONIAL_REGIONS: "Colonial regions",
	Mode.RELIGION: "Religion",
	Mode.BUILDINGS: "Buildings",
	Mode.CULTURE: "Culture",
}
## The bottom bar shows these groups; a group's modes slide out above it.
const GROUPS := [
	["Realm", [Mode.POLITICAL, Mode.CONTROL, Mode.DIPLOMACY, Mode.COLONISATION, Mode.COLONIAL_REGIONS]],
	["Economy", [Mode.ECONOMY, Mode.GOODS, Mode.BUILDINGS]],
	["Land", [Mode.TOPOGRAPHY, Mode.VEGETATION, Mode.CLIMATE]],
	["People", [Mode.POPULATION, Mode.CULTURE, Mode.RELIGION]],
]
## Modes that write each province's value on the map (info_text), from the
## region zoom in; country names then keep to the world view.
const INFO_MODES := [Mode.COLONISATION, Mode.ECONOMY, Mode.GOODS, Mode.TOPOGRAPHY, Mode.VEGETATION, Mode.CLIMATE,
	Mode.POPULATION, Mode.COLONIAL_REGIONS, Mode.RELIGION, Mode.BUILDINGS, Mode.CULTURE]
## Info modes whose values are categories: connected provinces sharing one
## are named once, across their whole extent (like a country), and country
## names step aside. (Economy and population values differ province by
## province and stay on each.)
const REGION_LABEL_MODES := [Mode.GOODS, Mode.TOPOGRAPHY, Mode.VEGETATION, Mode.CLIMATE, Mode.COLONIAL_REGIONS,
	Mode.RELIGION, Mode.CULTURE]

## Land no state claims in 1590.
const UNCOLONISED := Color(0.64, 0.61, 0.55)
const TOPOGRAPHY_COLORS := {
	"flatland": Color(0.74, 0.76, 0.52), "hills": Color(0.69, 0.60, 0.40),
	"plateau": Color(0.80, 0.68, 0.50), "mountains": Color(0.54, 0.51, 0.49),
	"wetlands": Color(0.38, 0.56, 0.52),
}
const VEGETATION_COLORS := {
	"desert": Color(0.91, 0.83, 0.57), "sparse": Color(0.78, 0.74, 0.57),
	"grasslands": Color(0.70, 0.79, 0.42), "farmland": Color(0.89, 0.75, 0.36),
	"woods": Color(0.45, 0.63, 0.33), "forest": Color(0.24, 0.46, 0.24), "jungle": Color(0.10, 0.37, 0.19),
}
## After the usual Köppen map colours: blues tropical, reds/oranges dry,
## yellow Mediterranean, greens temperate, purples cold continental, grey polar.
const CLIMATE_COLORS := {
	"equatorial": Color(0.16, 0.34, 0.76), "tropical": Color(0.33, 0.60, 0.88),
	"hot_arid": Color(0.88, 0.36, 0.26), "cold_arid": Color(0.94, 0.70, 0.45),
	"mediterranean": Color(0.94, 0.84, 0.32), "subtropical": Color(0.47, 0.75, 0.36),
	"oceanic": Color(0.28, 0.55, 0.36), "continental": Color(0.69, 0.56, 0.84),
	"subarctic": Color(0.45, 0.36, 0.64), "arctic": Color(0.80, 0.85, 0.88),
}

## Vassals and junior partners in a personal union are drawn in a shade of
## their overlord's colour, each subject its own shade: [lighten (+) or
## darken (-), hue shift].
const SUBJECT_SHADES := [[0.22, 0.0], [-0.24, 0.0], [0.38, 0.025], [-0.36, -0.025], [0.12, 0.05],
	[-0.12, -0.05], [0.30, -0.05], [-0.30, 0.05]]

## Diplomacy map: everyone as seen from one country (the selected one, or the player's).
const DIPLO_SELF := Color(0.86, 0.70, 0.38)
const DIPLO_SUBJECT := Color(0.66, 0.54, 0.86)
const DIPLO_OVERLORD := Color(0.45, 0.32, 0.70)
const DIPLO_ALLY := Color(0.26, 0.50, 0.86)
const DIPLO_MARRIAGE := Color(0.46, 0.76, 0.84)
const DIPLO_RIVAL := Color(0.84, 0.24, 0.22)
const DIPLO_HOSTILE := Color(0.70, 0.42, 0.36)
const DIPLO_NEUTRAL := Color(0.73, 0.71, 0.65)
const DIPLO_FRIENDLY := Color(0.44, 0.68, 0.42)


## Colonisation map (seen from one country): free land from quick (green) to
## slow (amber) to settle, closed by disease, out of reach; other countries faded.
const COLONY_FAST := Color(0.36, 0.66, 0.33)
const COLONY_SLOW := Color(0.86, 0.62, 0.30)
const COLONY_CLOSED := Color(0.45, 0.30, 0.28)
const COLONY_FAST_MONTHS := 12.0
const COLONY_SLOW_MONTHS := 240.0
const FADED := Color(0.80, 0.78, 0.74)


## Wastelands look the same in every map mode: muted terrain, hatched by the shader.
const WASTE_COLORS := {
	"desert": Color(0.74, 0.66, 0.50),
	"mountains": Color(0.50, 0.48, 0.47),
	"glacier": Color(0.88, 0.91, 0.94),
	"tundra": Color(0.70, 0.72, 0.71),
}
## Palette alpha values marking wastelands and sea tiles for the map shader.
const WASTE_MARKER := 255
const SEA_MARKER := 254
const SEA_COLOR := Color(0.20, 0.34, 0.44)
## Economy map: what a province produces in ducats a month, pale (little) to
## deep green (much).
const TAX_LOW := Color(0.90, 0.88, 0.80)
const TAX_HIGH := Color(0.22, 0.48, 0.24)
const POP_LOW := Color(0.93, 0.89, 0.76)
const POP_HIGH := Color(0.55, 0.13, 0.12)
## Buildings map: none (pale), a few, many (deep); under way, a step on.
const BUILT_NONE := Color(0.90, 0.88, 0.82)
const BUILT_MANY := Color(0.20, 0.30, 0.62)
const BUILT_SCALE := 5.0
## Share of each stripe period covered by occupation stripes.
const OCCUPATION_STRIPE := 0.42


## `perspective`: the country the diplomacy map is seen from; `cache` holds
## per-country colours for one palette refresh.
static func province_color(world: WorldState, p: Province, mode: Mode, density_scale: float,
		perspective := "", cache := {}) -> Color:
	if p.is_wasteland:
		return WASTE_COLORS.get(p.terrain, UNCOLONISED)
	if p.is_sea:
		return SEA_COLOR
	match mode:
		Mode.POLITICAL:
			return _cached_color(world, p.owner_id, cache).lightened(_jitter(p.id))
		Mode.CONTROL:
			return _cached_color(world, p.controller_id, cache)
		Mode.COLONIAL_REGIONS:
			return colonial_region_color(world, p, perspective)
		Mode.DIPLOMACY:
			if not cache.has(p.owner_id):
				cache[p.owner_id] = diplomacy_color(world, p.owner_id, perspective)
			return cache[p.owner_id]
		Mode.COLONISATION:
			# cache: "outlook:<id>" -> months (-1 out of reach, -2 disease).
			if p.owner_id == perspective and perspective != "":
				return _cached_color(world, p.owner_id, cache)
			if p.owner_id != "":
				return _cached_color(world, p.owner_id, cache).lerp(FADED, 0.65)
			var months: int = cache.get("outlook:%d" % p.id, -1)
			if months == -2:
				return COLONY_CLOSED
			if months < 0:
				return UNCOLONISED
			var t := clampf((months - COLONY_FAST_MONTHS) / (COLONY_SLOW_MONTHS - COLONY_FAST_MONTHS), 0.0, 1.0)
			return COLONY_FAST.lerp(COLONY_SLOW, sqrt(t))
		Mode.ECONOMY:
			if p.owner_id == "":
				return UNCOLONISED
			# cache: "value:<id>" -> output value a month, "value_scale" -> top of the ramp.
			var value: float = cache.get("value:%d" % p.id, 0.0)
			var t := log(1.0 + value) / log(1.0 + maxf(cache.get("value_scale", 1.0), 1e-6))
			return TAX_LOW.lerp(TAX_HIGH, clampf(t, 0.0, 1.0))
		Mode.GOODS:
			return Goods.color_of(p.resource).lerp(Color(0.5, 0.5, 0.5), 0.12) if Goods.has(p.resource) else UNCOLONISED
		Mode.TOPOGRAPHY:
			return TOPOGRAPHY_COLORS.get(p.topography, UNCOLONISED)
		Mode.VEGETATION:
			return VEGETATION_COLORS.get(p.vegetation, UNCOLONISED)
		Mode.CLIMATE:
			return CLIMATE_COLORS.get(p.climate, UNCOLONISED)
		Mode.POPULATION:
			var density := float(p.population) / maxf(p.area_km2, 1.0)
			var t := log(1.0 + density) / log(1.0 + maxf(density_scale, 1e-6))
			return POP_LOW.lerp(POP_HIGH, clampf(t, 0.0, 1.0))
		Mode.RELIGION:
			return Religions.color_of(p.religion) if p.religion != "" else UNCOLONISED
		Mode.CULTURE:
			return Cultures.color_of(p.culture) if p.culture != "" else UNCOLONISED
		Mode.BUILDINGS:
			if p.owner_id == "":
				return UNCOLONISED
			var n := p.buildings.size() + (0.5 if not p.construction.is_empty() else 0.0)
			return BUILT_NONE.lerp(BUILT_MANY, clampf(n / BUILT_SCALE, 0.0, 1.0))
	return UNCOLONISED


## Index into GROUPS of the group holding `mode`.
static func group_of(mode: Mode) -> int:
	for g in GROUPS.size():
		if mode in GROUPS[g][1]:
			return g
	return 0


## What the map writes on a province in this mode ("" for nothing): its
## climate, its good (and what a manufactory makes of it), its output value…
static func info_text(p: Province, mode: Mode, economy: EconomySystem = null) -> String:
	if p.is_sea or p.is_wasteland:
		return ""
	match mode:
		Mode.ECONOMY:
			return "%.1f ducats" % economy.production(p).value if economy != null else ""
		Mode.GOODS:
			var made := Buildings.recipe(p)
			return Goods.name_of(p.resource) + (" → " + Goods.name_of(made[0]) if not made.is_empty() else "")
		Mode.TOPOGRAPHY:
			return Land.display(p.topography)
		Mode.VEGETATION:
			return Land.display(p.vegetation)
		Mode.CLIMATE:
			return Land.display(p.climate)
		Mode.POPULATION:
			return compact_number(p.population)
		Mode.COLONIAL_REGIONS:
			var region := Overseas.region_of(p)
			return Overseas.region_short(region) if region != "" else ""
		Mode.RELIGION:
			return Religions.name_of(p.religion) if p.religion != "" else ""
		Mode.CULTURE:
			return Cultures.name_of(p.culture) if p.culture != "" else ""
		Mode.BUILDINGS:
			var names: Array[String] = []
			for id: String in p.buildings:
				names.append(Buildings.short_name(id))
			if not p.construction.is_empty():
				names.append(Buildings.short_name(p.construction[0]) + " …")
			return " · ".join(names)
	return ""


## The colonial regions map: each region in its own muted hue (overseas land
## of the perspective country's, and its colonies', brighter); Europe and the
## Middle East, which have none, greyed.
static func colonial_region_color(world: WorldState, p: Province, perspective: String) -> Color:
	var region := Overseas.region_of(p)
	if region == "":
		return FADED
	var i := 0
	for r: Array in Overseas.REGIONS:
		if r[0] == region:
			break
		i += 1
	var hue := fmod(i * 0.381966, 1.0)  # the golden ratio spreads neighbours' hues apart
	var ours := perspective != "" and (p.owner_id == perspective or world.diplomacy.overlord_of(p.owner_id) == perspective)
	return Color.from_hsv(hue, 0.55 if ours else 0.32, 0.86 if ours else 0.72)


## 1,234,567 → "1.2M", 313,100 → "313k", 950 → "950".
static func compact_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%dk" % roundi(n / 1000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


## Occupation stripes: the occupier's colour over the owner's on the political
## map, the owner's colour over the occupier's on the control map; on the
## diplomacy map, the perspective country's colour over others' land it has
## cores on (claims: thinner). Alpha is the stripe width (0 = no stripes).
static func stripe_color(world: WorldState, p: Province, mode: Mode, perspective := "") -> Color:
	if mode == Mode.DIPLOMACY and perspective != "" and p.owner_id != "" and p.owner_id != perspective \
			and not p.is_sea and not p.is_wasteland:
		var core := world.claims.is_core(perspective, p.id)
		if core or world.claims.has_claim(perspective, p.id):
			var c := _country_color(world, perspective)
			c.a = OCCUPATION_STRIPE if core else OCCUPATION_STRIPE * 0.55
			return c
	if p.colonist != "" and p.owner_id == "" and mode in [Mode.POLITICAL, Mode.COLONISATION]:
		var settler := _country_color(world, p.colonist)  # a colony under way
		settler.a = OCCUPATION_STRIPE
		return settler
	if p.is_wasteland or p.is_sea or not p.is_occupied():
		return Color(0, 0, 0, 0)
	var c: Color
	match mode:
		Mode.POLITICAL:
			c = _country_color(world, p.controller_id)
		Mode.CONTROL:
			c = _country_color(world, p.owner_id)
		_:
			return Color(0, 0, 0, 0)
	c.a = OCCUPATION_STRIPE
	return c


## The country whose borders a province is drawn inside: its controller on the
## control map, its owner everywhere else.
static func border_country(p: Province, mode: Mode) -> String:
	return p.controller_id if mode == Mode.CONTROL else p.owner_id


## A country's colour on the diplomacy map: its tie to the player, else how
## it regards the player (red hostile, grey indifferent, green friendly).
static func diplomacy_color(world: WorldState, tag: String, perspective := "") -> Color:
	var me := perspective if perspective != "" else world.player_country_id
	if tag == "":
		return UNCOLONISED
	if tag == me:
		return DIPLO_SELF
	var d := world.diplomacy
	if d.overlord_of(tag) == me:
		return DIPLO_SUBJECT
	if d.overlord_of(me) == tag:
		return DIPLO_OVERLORD
	if d.are_rivals(me, tag):
		return DIPLO_RIVAL
	if d.is_allied(me, tag):
		return DIPLO_ALLY
	if d.are_married(me, tag):
		return DIPLO_MARRIAGE
	var o := d.opinion(tag, me)
	if o >= 0:
		return DIPLO_NEUTRAL.lerp(DIPLO_FRIENDLY, clampf(o / 100.0, 0.0, 1.0))
	return DIPLO_NEUTRAL.lerp(DIPLO_HOSTILE, clampf(-o / 100.0, 0.0, 1.0))


## People per km² at the 98th percentile: the top of the population colour ramp.
static func population_density_scale(world: WorldState) -> float:
	var densities := PackedFloat32Array()
	for p: Province in world.ownable_provinces():
		densities.append(float(p.population) / maxf(p.area_km2, 1.0))
	if densities.is_empty():
		return 1.0
	densities.sort()
	return densities[int((densities.size() - 1) * 0.98)]


static func _country_color(world: WorldState, tag: String) -> Color:
	return country_color(world, tag)


static func _cached_color(world: WorldState, tag: String, cache: Dictionary) -> Color:
	var key := "c:" + tag
	if not cache.has(key):
		cache[key] = country_color(world, tag)
	return cache[key]


## A country's colour on the map and in panels: its own, or — for a vassal or
## a junior partner in a personal union — a shade of its overlord's, so the
## tie shows at a glance. Tributaries keep their own colours.
static func country_color(world: WorldState, tag: String) -> Color:
	var c := world.get_country(tag)
	if c == null:
		return UNCOLONISED
	var d := world.diplomacy
	var overlord := d.overlord_of(tag)
	if overlord == "" or d.subject_type(tag) == "tributary" or world.get_country(overlord) == null:
		return c.color
	var base := country_color(world, overlord)
	var shaded := d.subjects_of(overlord).filter(func(t: String) -> bool: return d.subject_type(t) != "tributary")
	var shade: Array = SUBJECT_SHADES[maxi(shaded.find(tag), 0) % SUBJECT_SHADES.size()]
	var col := base.lightened(shade[0]) if shade[0] > 0.0 else base.darkened(-shade[0])
	col.h = fposmod(col.h + shade[1], 1.0)
	return col


## Small per-province brightness variation so neighbours stay distinguishable.
static func _jitter(id: int) -> float:
	return float((id * 2654435761) % 7) * 0.012
