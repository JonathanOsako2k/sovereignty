class_name ColonisationSystem
extends RefCounted
## Colonisation through the scheduler (rules in Colonisation): founding and
## abandoning colonies, their monthly progress and native uprisings, and the
## AI — countries with a colonial policy settle the best land in reach; those
## without one adopt frontier settlement now and then when free land borders
## them (so African kingdoms expand gradually, Siberia fills from Russia).
## A finished colony changes hands through WorldState.transfer_province().

signal colony_founded(province_id: int, tag: String)
signal colony_completed(province_id: int, tag: String)
signal colony_abandoned(province_id: int, tag: String)
signal uprising(province_id: int, tag: String)

const FOUNDED := "Colony founded: %s"
## AI: money kept back when founding, the yearly chance of taking up frontier
## settlement (with free land beside it) or overseas ventures (when rich), and
## how many overseas candidates (nearest first) it weighs.
const AI_RESERVE := 60.0
const AI_ADOPT_FRONTIER := 0.01
const AI_ADOPT_OVERSEAS := 0.01
const AI_OVERSEAS_CANDIDATES := 60

var world: WorldState
var clock: GameClock
var rng: GameRandom
var economy: EconomySystem
var _homes := {}  # tag -> {climate: true}
var _coasts := {}  # tag -> {sea tile id: true} touched by any of our provinces
var _sea_hops := {}  # tag -> {sea tile id: seas crossed from our home ports}
var _colonies := {}  # tag -> Array[int] of provinces being settled
var _colonies_dirty := true


func _init(p_campaign: Campaign, p_economy: EconomySystem) -> void:
	world = p_campaign.world
	clock = p_campaign.clock
	rng = p_campaign.rng
	economy = p_economy
	world.province_owner_changed.connect(_on_owner_changed)
	world.campaign_restored.connect(_reset_caches)


func _reset_caches() -> void:
	_homes.clear()
	_coasts.clear()
	_sea_hops.clear()
	_colonies_dirty = true


## Only the two countries involved see their land, coasts or capital change.
func _on_owner_changed(province_id: int, old_owner: String, new_owner: String) -> void:
	var p := world.get_province(province_id)
	if p != null and p.owner_id != "" and p.colonist != "":
		p.colonist = ""  # taken some other way while being settled
		p.colony_progress = 0.0
		_colonies_dirty = true
	for tag: String in [old_owner, new_owner]:
		_homes.erase(tag)
		_coasts.erase(tag)
		_sea_hops.erase(tag)


# --- What a country can reach -------------------------------------------------------

## The climates near a country's capital: what its settlers are used to.
func home_climates(tag: String) -> Dictionary:
	if not _homes.has(tag):
		var homes := {}
		var c := world.get_country(tag)
		var cap := world.get_province(c.capital_province_id) if c else null
		if cap != null:
			for p: Province in world.ownable_provinces():
				if p.owner_id == tag and DiplomacyActions._haversine(p.lat, p.lon, cap.lat, cap.lon) <= Colonisation.HOME_RADIUS_KM:
					homes[p.climate] = true
		_homes[tag] = homes
	return _homes[tag]


## Sea tiles any of a country's provinces touch (its colonies' too).
func coast_tiles(tag: String) -> Dictionary:
	if not _coasts.has(tag):
		var tiles := {}
		for p: Province in world.ownable_provinces():
			if p.owner_id == tag:
				for s: int in p.sea_ids:
					tiles[s] = true
		_coasts[tag] = tiles
	return _coasts[tag]


## Seas crossed to each sea tile from a country's home ports (its coasts
## within Colonisation.HOME_RADIUS_KM of the capital), by breadth-first search
## over the sea tiles. A country without a home coast cannot sail overseas.
func sea_hops(tag: String) -> Dictionary:
	if not _sea_hops.has(tag):
		var hops := {}
		var queue: Array[int] = []
		var c := world.get_country(tag)
		var cap := world.get_province(c.capital_province_id) if c else null
		for p: Province in world.ownable_provinces():
			if p.owner_id == tag and cap != null and p.is_coastal \
					and DiplomacyActions._haversine(p.lat, p.lon, cap.lat, cap.lon) <= Colonisation.HOME_RADIUS_KM:
				for s: int in p.sea_ids:
					if not hops.has(s):
						hops[s] = 0
						queue.append(s)
		var head := 0
		while head < queue.size():
			var s := queue[head]
			head += 1
			var d: int = hops[s]
			if d >= Colonisation.MAX_SEAS:
				continue
			for n: int in world.get_province(s).neighbour_ids:
				if not hops.has(n):
					hops[n] = d + 1
					queue.append(n)
		_sea_hops[tag] = hops
	return _sea_hops[tag]


## How `tag` reaches a province: {kind ("frontier", "strait", "overseas" or ""),
## seas, factor}.
func access(tag: String, p: Province) -> Dictionary:
	for n: int in p.neighbour_ids:
		if world.get_province(n).owner_id == tag:
			return {"kind": "frontier", "seas": 0, "factor": Colonisation.ACCESS_FRONTIER}
	if p.is_coastal:
		var coasts := coast_tiles(tag)
		for s: int in p.sea_ids:
			if coasts.has(s):
				return {"kind": "strait", "seas": 0, "factor": Colonisation.ACCESS_STRAIT}
		var best := _seas_from_home(tag, p)
		if best >= 0:
			return {"kind": "overseas", "seas": maxi(best, 1), "factor": Colonisation.overseas_factor(maxi(best, 1))}
	return {"kind": "", "seas": 0, "factor": 0.0}


## Fewest seas from `tag`'s home ports to a coastal province (-1 if none).
func _seas_from_home(tag: String, p: Province) -> int:
	var hops := sea_hops(tag)
	var best := -1
	for s: int in p.sea_ids:
		if hops.has(s) and (best < 0 or hops[s] < best):
			best = hops[s]
	return best


## Monthly progress `tag`'s settlers would make in a province, with every
## factor named: {total, factors: [[label, x]], access}.
func rate(tag: String, p: Province) -> Dictionary:
	var a := access(tag, p)
	var homes := home_climates(tag)
	var label: String = {"frontier": "Our frontier", "strait": "Across the water",
		"overseas": "Overseas (%d seas)" % a.seas, "": "Out of reach"}[a.kind]
	var factors := [
		[label, a.factor],
		["The land", Colonisation.land_factor(p)],
		["Climate", Colonisation.familiarity(p, homes)],
		["Natives (%s%s)" % [DrawerPanel.thousands(p.population), ", neighbours" if neighbours(tag, p) else ""],
			Colonisation.native_factor(p.population, neighbours(tag, p))],
		["Disease", Colonisation.disease_factor(p, Colonisation.seasoned(homes), clock.year)],
	]
	if a.kind == "frontier" and Colonisation.FRONTIER_TRADITIONS.has(tag):
		factors.insert(1, Colonisation.FRONTIER_TRADITIONS[tag])
	var total := Colonisation.BASE_PROGRESS
	for f: Array in factors:
		total *= f[1]
	return {"total": total, "factors": factors, "access": a}


## Whether a province's people are neighbours to `tag`'s (the same part of
## the world as its capital): they are absorbed more easily than foreigners.
func neighbours(tag: String, p: Province) -> bool:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id) if c else null
	return cap != null and cap.region == p.region


## Months a colony would take at today's rate (-1 if it would never finish).
func months_to_settle(tag: String, p: Province) -> int:
	var r: float = rate(tag, p).total
	return int(ceil((100.0 - p.colony_progress) / r)) if r > 0.0 else -1


## For maps: months a colony would take (-1 out of reach, -2 closed by
## disease). A country without a policy sees what frontier settlement would give.
func outlook(tag: String, p: Province) -> int:
	var c := world.get_country(tag)
	if c == null or p.owner_id != "":
		return -1
	var a := access(tag, p)
	if a.kind == "" or (a.kind == "overseas" and not Colonisation.POLICY_OVERSEAS[c.colonial_policy]):
		return -1
	if Colonisation.disease_factor(p, Colonisation.seasoned(home_climates(tag)), clock.year) <= 0.0:
		return -2
	return months_to_settle(tag, p)


func founding_cost(tag: String, p: Province) -> float:
	return Colonisation.founding_cost(access(tag, p).seas, world.get_country(tag).inflation)


## Provinces `tag` is settling now.
func colonies_of(tag: String) -> Array:
	if _colonies_dirty:
		_colonies = {}
		for p: Province in world.ownable_provinces():
			if p.colonist != "":
				if not _colonies.has(p.colonist):
					_colonies[p.colonist] = []
				_colonies[p.colonist].append(p.id)
		_colonies_dirty = false
	return _colonies.get(tag, [])


## Why `tag` cannot found a colony in the province now ("" if it can).
func blocked(tag: String, p: Province) -> String:
	var c := world.get_country(tag)
	if c == null or p.is_sea or p.is_wasteland:
		return "Cannot be settled"
	if p.owner_id != "":
		return "Already belongs to %s" % world.get_country(p.owner_id).name
	if p.colonist != "":
		return "Our settlers are already there" if p.colonist == tag \
			else "%s is settling it" % world.get_country(p.colonist).name
	var reason := _reach_blocked(tag, p)
	if reason != "":
		return reason
	var slots: int = Colonisation.POLICY_COLONIES[c.colonial_policy]
	if c.colonial_policy == 0:
		return "Needs a colonial policy (set it in the budget)"
	if colonies_of(tag).size() >= slots:
		return "All our colonists are busy (%d of %d colonies)" % [slots, slots]
	if c.treasury < founding_cost(tag, p):
		return "Needs %d ducats" % int(ceil(founding_cost(tag, p)))
	return ""


## Why the province is beyond `tag`'s settlers whatever its money and
## colonists ("" if reachable): no access, the sea (without the policy), disease.
func _reach_blocked(tag: String, p: Province) -> String:
	var c := world.get_country(tag)
	var a := access(tag, p)
	if a.kind == "":
		return "Out of reach: neither on our frontier nor our seas"
	if a.kind == "overseas" and not Colonisation.POLICY_OVERSEAS[c.colonial_policy] and c.colonial_policy > 0:
		return "Across the sea: needs the policy Overseas ventures"
	if Colonisation.disease_factor(p, Colonisation.seasoned(home_climates(tag)), clock.year) <= 0.0:
		return "Disease: settlers from cooler lands perish inland (until quinine, c. 1850)"
	return ""


# --- Actions -------------------------------------------------------------------

func found_colony(tag: String, p: Province) -> bool:
	if blocked(tag, p) != "":
		return false
	var c := world.get_country(tag)
	economy.post(c, FOUNDED % p.name, -founding_cost(tag, p))
	p.colonist = tag
	p.colony_progress = 0.0
	_colonies_dirty = true
	economy.changed()
	colony_founded.emit(p.id, tag)
	return true


func abandon(tag: String, p: Province) -> bool:
	if p.colonist != tag:
		return false
	p.colonist = ""
	p.colony_progress = 0.0
	_colonies_dirty = true
	economy.changed()
	colony_abandoned.emit(p.id, tag)
	return true


# --- The month and the year ------------------------------------------------------------

func monthly() -> void:
	for p: Province in world.ownable_provinces():
		if p.colonist == "":
			continue
		var tag := p.colonist
		if world.get_country(tag) == null:
			abandon(tag, p)
			continue
		if rng.chance(Colonisation.uprising_chance(p.population, neighbours(tag, p))):
			p.colony_progress = EconomySystem.decimal(maxf(p.colony_progress - Colonisation.UPRISING_LOSS, 0.0))
			uprising.emit(p.id, tag)
			continue
		p.colony_progress = EconomySystem.decimal(minf(p.colony_progress + rate(tag, p).total, 100.0))
		if p.colony_progress >= 100.0:
			_complete(p)


## The colony becomes the settlers' country's: settlers arrive, the natives
## stay on as tribesmen.
func _complete(p: Province) -> void:
	var tag := p.colonist
	p.colonist = ""
	p.colony_progress = 0.0
	_colonies_dirty = true
	var natives := p.population
	p.pops = {"tribesmen": natives}
	for role: String in Estates.ROLES:
		if role != "tribesmen":
			p.pops[role] = 0
	for role: String in Colonisation.SETTLERS:
		p.add_people(role, Colonisation.SETTLERS[role])
	world.transfer_province(p.id, tag)
	colony_completed.emit(p.id, tag)


## AI countries with free colonists found a colony in the best land in reach.
func ai_monthly(player: String) -> void:
	var free_land: Array[Province] = []
	for p: Province in world.ownable_provinces():
		if p.owner_id == "" and p.colonist == "":
			free_land.append(p)
	if free_land.is_empty():
		return
	for c: Country in world.countries.values():
		if c.id == player or c.colonial_policy == 0:
			continue
		if colonies_of(c.id).size() >= Colonisation.POLICY_COLONIES[c.colonial_policy]:
			continue
		if c.treasury < Colonisation.FOUNDING_COST + AI_RESERVE:
			continue
		var best: Province = null
		var best_rate := 0.0
		for p: Province in _ai_candidates(c, free_land):
			if p.colonist != "" or _reach_blocked(c.id, p) != "":
				continue
			var r: float = rate(c.id, p).total
			if r > best_rate:
				best_rate = r
				best = p
		if best != null and c.treasury >= founding_cost(c.id, best) + AI_RESERVE:
			found_colony(c.id, best)


## Free land a country might settle: its frontier, and (with an overseas
## policy) the nearest free coasts.
func _ai_candidates(c: Country, free_land: Array[Province]) -> Array[Province]:
	var out: Array[Province] = []
	var overseas := []  # [seas, province]
	var coasts := coast_tiles(c.id)
	var may_sail: bool = Colonisation.POLICY_OVERSEAS[c.colonial_policy]
	for p: Province in free_land:
		var near := false
		for n: int in p.neighbour_ids:
			if world.get_province(n).owner_id == c.id:
				near = true
				break
		if not near and p.is_coastal:
			for s: int in p.sea_ids:
				if coasts.has(s):
					near = true
					break
		if near:
			out.append(p)
		elif p.is_coastal and may_sail:
			var seas := _seas_from_home(c.id, p)
			if seas >= 0:
				overseas.append([seas, p])
	overseas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in mini(overseas.size(), AI_OVERSEAS_CANDIDATES):
		out.append(overseas[k][1])
	return out


## AI countries take up colonial policies: frontier settlement when free land
## they can settle borders them and they can pay for it; overseas ventures,
## rarely, when they hold a coast and are rich.
func ai_yearly(player: String) -> void:
	var budgets := economy.budgets()
	var frontier := _free_frontiers()
	for c: Country in world.countries.values():
		if c.id == player or c.colonial_policy >= 2 or world.get_province(c.capital_province_id) == null:
			continue
		var net: float = budgets.get(c.id, {}).get("net", 0.0)
		if c.colonial_policy == 0:
			if net > 0.0 and c.treasury > 100.0 and frontier.get(c.id, 0) >= 2 and rng.chance(AI_ADOPT_FRONTIER):
				c.colonial_policy = 1
				economy.changed()
		elif net > 15.0 and c.treasury > 400.0 and not coast_tiles(c.id).is_empty() and rng.chance(AI_ADOPT_OVERSEAS):
			c.colonial_policy = 2
			economy.changed()


## For every country, how many free provinces beside its land its settlers
## could reach (disease permitting) — in one pass over the free land.
func _free_frontiers() -> Dictionary:
	var seen := {}  # tag -> {province id: true}
	var seasoned := {}  # tag -> whether its people are at home in the tropics
	for p: Province in world.ownable_provinces():
		if p.owner_id != "":
			continue
		for n: int in p.neighbour_ids:
			var owner := world.get_province(n).owner_id
			if owner == "" or seen.get(owner, {}).has(p.id):
				continue
			if not seasoned.has(owner):
				seasoned[owner] = Colonisation.seasoned(home_climates(owner))
			if Colonisation.disease_factor(p, seasoned[owner], clock.year) > 0.0:
				if not seen.has(owner):
					seen[owner] = {}
				seen[owner][p.id] = true
	var counts := {}
	for tag: String in seen:
		counts[tag] = seen[tag].size()
	return counts
