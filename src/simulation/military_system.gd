class_name MilitarySystem
extends RefCounted
## War through the scheduler (the state lives in Military):
## * marching along the quickest road — A* over the province graph, a leg's
##   days set by distance, the army's pace and the ground; armies cross a sea
##   zone where their own fleet holds it; neutral land is closed to them; before
##   1800 enemy forts bar the roads about them (fort_zones);
## * battles when enemies meet (strength, ground, forts, luck; the loser falls
##   back as far as its technology allows — see retreat_steps — destroyed only
##   when cut off or overwhelmed), sieges of forts (monthly tries, guns,
##   storming) and occupation of open land — control only, never ownership;
##   occupied land may be handed to an ally in the war;
## * manpower and sailors: pools trained by barracks and docks, refilling
##   regiments and crews; ideas that add to them (press gangs);
## * fleets carrying armies over the sea (ships' capacity; boarding at a port
##   or offshore, landing on a coast of the fleet's sea);
## * attrition where the land cannot feed an army, reinforcements and
##   recovering spirit at home; levies raised for war (taken from the fields;
##   their dead lost to the people) and sent home in peace; regiments and
##   ships raised in provinces;
## * war declarations calling allies and subjects; war score from battles and
##   occupation; peace — white peace, ceding occupied land, surrender — and
##   truces; the AI that fights, makes peace and, now and then, war.

signal battle_fought(report: Dictionary)
signal province_occupied(province_id: int, by: String)
## In a civil war a province taken is annexed outright.
signal province_annexed(province_id: int, by: String, from: String)
signal war_declared(war: Dictionary)
signal peace_made(war: Dictionary, summary: String)
## An AI side's leader offers the player a treaty (see conclude): accepting
## signs it as `from` put it.
signal peace_offered(war: Dictionary, treaty: Dictionary, from: String)
## Forts were pulled down by a peace.
signal forts_changed
signal regiment_raised(province_id: int, tag: String, unit: String)
## A subject that had stayed out of its overlord's war joins it: its land was attacked.
signal war_joined(war: Dictionary, tag: String)

# --- Marching ---
const MIN_LEG_DAYS := 2.0
const TOPOGRAPHY_DAYS := {"flatland": 1.0, "hills": 1.3, "plateau": 1.2, "mountains": 1.8, "wetlands": 1.5}
const VEGETATION_DAYS := {"jungle": 1.5, "forest": 1.25, "woods": 1.1, "desert": 1.3}
const STRAIT_DAYS := 3.0
# --- Battle ---
const DEFENCE_TOPOGRAPHY := {"hills": 1.15, "plateau": 1.1, "mountains": 1.3, "wetlands": 1.15}
const DEFENCE_VEGETATION := {"forest": 1.1, "jungle": 1.15}
const FORT_DEFENCE := 1.25
const BATTLE_LUCK := 0.2
const BATTLE_SCORE_CAP := 40.0
## A beaten host is destroyed outright only when it has nowhere to fall back
## to, or the victors outnumber what is left of it this many times over.
const STACKWIPE_RATIO := 10.0
## How far a beaten army falls back, by the technology it fields: [until the
## year its units come from, provinces]. The armies of the pike-and-shot age
## broke and fled far before they could be rallied; as technology develops —
## drill, firepower, fronts held by entrenched divisions — the fall-back
## shrinks. Until technology exists, the age of an army's units stands in.
const RETREAT_BY_AGE := [[1750, 5], [1830, 4], [1900, 3], [100000, 2]]
## An army all on horseback (its slowest at least this fast, km a day) falls
## back one province further.
const MOUNTED_SPEED := 30.0
# --- Over the sea ---
const LANDING_DAYS := 3.0
## Before this year a fort bars the roads about it to its enemies (fort_zones).
const FORT_ZOC_UNTIL := 1800
# --- Sieges ---
## Open land falls to an army standing on it in OCCUPY_DAYS (sooner with guns).
## A fort holds a garrison (FORT_GARRISON men; fewer if its upkeep is
## neglected, half again at a capital: fort_strength) and needs at least as
## many besiegers. A capital without a fort is never simply occupied: its old
## walls and watch hold like a fort of CITY_WALLS strength (walled). Every SIEGE_PHASE_DAYS they try their luck (siege_odds):
## SIEGE_BASE, plus SIEGE_PER_PHASE for every try that failed (to
## SIEGE_TIME_CAP: hunger, disease, breaches), plus their numbers
## (SIEGE_PER_GARRISON for every garrison's worth beyond the first, to
## SIEGE_NUMBERS_CAP), plus their guns (the share of siege power in the army ×
## SIEGE_ARTILLERY, to SIEGE_ARTILLERY_CAP), minus the walls (SIEGE_WALLS ×
## the fort's strength) and, short of siege equipment — guns, or the ladders
## and saps of a great host (IMPROVISED_SIEGE a man), against
## SIEGE_EQUIPMENT_NEED a man of the garrison — up to SIEGE_NO_EQUIPMENT.
## Or they storm it (assault): ASSAULT_BASE + the siege's chance ×
## ASSAULT_FACTOR (to ASSAULT_MAX), after ASSAULT_MIN_DAYS and no more than
## once every ASSAULT_EVERY_DAYS, losing ASSAULT_LOSS of the stormers if it
## falls and ASSAULT_FAIL_LOSS if it holds. AI armies storm at
## AI_ASSAULT_CHANCE or better.
const OCCUPY_DAYS := 10.0
const CAPITAL_SIEGE := 1.5
const CITY_WALLS := 0.6
const MIN_SIEGE_MEN := 1000
const FORT_GARRISON := 1000
const SIEGE_PHASE_DAYS := 30
const SIEGE_BASE := 10.0
const SIEGE_PER_PHASE := 5.0
const SIEGE_TIME_CAP := 40.0
const SIEGE_PER_GARRISON := 4.0
const SIEGE_NUMBERS_CAP := 16.0
const SIEGE_ARTILLERY := 100.0
const SIEGE_ARTILLERY_CAP := 30.0
const SIEGE_WALLS := 10.0
const SIEGE_NO_EQUIPMENT := 42.0
const SIEGE_EQUIPMENT_NEED := 0.5
const IMPROVISED_SIEGE := 0.05
const SIEGE_MAX_CHANCE := 90.0
const ASSAULT_MIN_DAYS := 10
const ASSAULT_EVERY_DAYS := 15
const ASSAULT_BASE := 5.0
const ASSAULT_FACTOR := 1.5
const ASSAULT_MAX := 80.0
const ASSAULT_LOSS := 0.1
const ASSAULT_FAIL_LOSS := 0.25
const ASSAULT_MORALE := 0.3
const AI_ASSAULT_CHANCE := 60.0
# --- Levies, supply, recovery ---
const LEVY_SHARE := 0.004  # of commoners and tribesmen
const MIN_LEVY_REGIMENT := 200
## Levies muster at the realm's great towns, each drawing the provinces
## within this distance (one army each, never over the stack limit).
const MUSTER_KM := 350.0
const SUPPLY_BASE := 4000.0
const SUPPLY_PER_DEVELOPMENT := 1500.0
const SUPPLY_PER_PERSON := 0.02
const HARSH_SUPPLY := {"desert": 0.4, "arctic": 0.3, "subarctic": 0.6, "mountains": 0.6, "jungle": 0.6}
const REINFORCE_SHARE := 0.1
const REINFORCE_COST := 0.5
const MORALE_RECOVERY := 0.2
const REINFORCEMENTS := "Reinforcements"
## Soldiers for regular (professional) regiments — not levies — and sailors for
## ships' crews come from pools. Each has a ceiling: MANPOWER_SHARE of the
## people of the land a country holds (SAILOR_SHARE of those on its coasts),
## plus TRAINED_MONTHS of what its barracks and docks train. A pool refills by
## itself only slowly (its people's share over POOL_GROWTH_MONTHS), but mostly
## from training: a barracks turns BARRACKS_SHARE of its province's people a
## month into soldiers (at least BARRACKS_MIN), a dock DOCK_SHARE into sailors
## (at least DOCK_MIN). Over its ceiling (land lost, men pressed) a pool loses
## POOL_EXCESS_LOSS of the excess a month. Ideas: drill grounds and naval
## academies train IDEA_TRAINING times as many; conscription multiplies the
## people's share by CONSCRIPTION; press gangs seize PRESS_SHARE of a
## province's commoners (once in PRESS_EVERY_DAYS, PRESS_UNREST unrest).
const MANPOWER_SHARE := 0.003
const SAILOR_SHARE := 0.002
const POOL_GROWTH_MONTHS := 240.0
const BARRACKS_SHARE := 0.0004
const BARRACKS_MIN := 100.0
const DOCK_SHARE := 0.0003
const DOCK_MIN := 30.0
const TRAINED_MONTHS := 12.0
const POOL_EXCESS_LOSS := 0.1
const IDEA_TRAINING := 1.5
const CONSCRIPTION := 2.0
const PRESS_SHARE := 0.01
const PRESS_EVERY_DAYS := 365
const PRESS_UNREST := 10.0
const PRESS_MIN := 50
const RECRUITMENT := "Raising %s"
# --- Peace and the AI ---
const OCCUPATION_WEIGHT := 0.6
const PEACE_DEMAND := 50.0
const WHITE_PEACE_YEARS := 4.0
const OFFER_EVERY_DAYS := 180
const AI_WAR_CHANCE := 0.05
## Realms readier for war than most: tag -> [times the yearly chance, odds it
## needs]. Nurhaci's Jianzhou, uniting the Jurchens.
const AI_AGGRESSION := {"JIA": [8.0, 1.0]}
const AI_WAR_ODDS := 1.5
## AI planning: the nearest targets it weighs, the provinces a route search may
## open before giving up, and the days an army with no target waits to look again.
const AI_TARGETS := 3
const AI_SEARCH_LIMIT := 1200
const AI_SEARCHES_PER_DAY := 8
## And at most this many provinces opened by all of a day's searches together
## (a failed search opens up to AI_SEARCH_LIMIT): the rest plan tomorrow.
const AI_NODES_PER_DAY := 2500
const AI_REST_DAYS := 28
## A target an army could not reach is left alone this long (from where it
## stood): it tries the next nearest instead.
const AI_UNREACHABLE_DAYS := 120
const AI_TARGETS_DAYS := 7  # how long a side's list of targets is kept

var world: WorldState
var clock: GameClock
var rng: GameRandom
var economy: EconomySystem
var actions: DiplomacyActions
var m: Military
var _levy_dead := {}  # home province -> levies lost since the last count
var _plan_after := {}  # army id -> day before which the AI does not look for targets again
var _targets := {}  # war id -> [attackers' targets, defenders'] (provinces to take or free)
var _targets_day := -1000000  # when they were worked out
## Provinces the last route search opened (the AI's daily budget).
var last_search_nodes := 0
var _unreachable := {}  # "owner:from" -> {target id: day until which the AI does not try that road again}


func _init(p_campaign: Campaign, p_economy: EconomySystem, p_actions: DiplomacyActions) -> void:
	world = p_campaign.world
	clock = p_campaign.clock
	rng = p_campaign.rng
	economy = p_economy
	actions = p_actions
	m = world.military
	m.reset.connect(_after_reset)
	m.changed.connect(economy.changed)
	world.province_controller_changed.connect(func(_id: int, _old: String, _new: String): _zones_key = "")
	forts_changed.connect(func():
		_forts_key = ""
		_zones_key = "")
	_fill_pools()


func _after_reset() -> void:
	_zones_key = ""
	_forts_key = ""
	_fill_pools()
	_recount_levies()
	economy.changed()


# --- Where armies may go --------------------------------------------------------------

## Whether `tag`'s armies may enter a land province: its own and its friends'
## (allies, overlord, subjects), uncolonised land, and its enemies'.
func can_enter(tag: String, p: Province) -> bool:
	if p == null or p.is_wasteland or p.is_sea:
		return false
	if p.owner_id == "" or p.owner_id == tag or p.controller_id == tag:
		return true
	return _friendly(tag, p.owner_id) or m.at_war(tag, p.owner_id) \
		or (p.controller_id != "" and m.at_war(tag, p.controller_id)) or _open_subject(tag, p.owner_id)


## A subject that refused its overlord's war against `tag`: its land is open
## to `tag` (and entering it brings the subject into the war).
func _open_subject(tag: String, subject: String) -> bool:
	for id: int in m.refusing_wars(subject):
		var overlord := world.diplomacy.overlord_of(subject)
		var side := m.side_in(id, overlord)
		if side >= 0 and m.side_in(id, tag) == 1 - side:
			return true
	return false


# --- Forts barring the roads -----------------------------------------------------------

## Before FORT_ZOC_UNTIL a fort bars the roads about it to its enemies: an army
## in its zone — the fort and the land beside it that the fort's side holds —
## may march into the fort, or out of the zone, but not on to another province
## of the zone: it must take the fort, or go round. Retreats are not barred.
var _zones := {}  # tag -> {province id: [ids of hostile forts whose zone it is in]}
var _zones_key := ""  # the day and wars they hold for ("" after control changed)
var _fort_list: Array[Province] = []
var _fort_land := {}  # fort province id -> its land neighbours
var _forts_key := ""  # the month the fort list holds for ("" after forts were pulled down)
var _zoc_hit := false  # the last road search was barred by a fort


## The zones of the forts hostile to `tag` (none from FORT_ZOC_UNTIL, nor at
## peace): province id -> [fort province ids].
func fort_zones(tag: String) -> Dictionary:
	if clock.year >= FORT_ZOC_UNTIL or not m.in_any_war(tag):
		return {}
	# Forts are built a month at a time: the list (with each fort's land
	# neighbours) holds for the month.
	var month := "%d-%d" % [clock.year, clock.month]
	if month != _forts_key:
		_forts_key = month
		_fort_list.clear()
		_fort_land.clear()
		for p: Province in world.ownable_provinces():
			if "fort" in p.buildings:
				_fort_list.append(p)
				var land: Array[Province] = []
				for n: int in p.neighbour_ids:
					var q := world.get_province(n)
					if q != null and not q.is_sea and not q.is_wasteland:
						land.append(q)
				_fort_land[p.id] = land
	# Zones hold until control, the wars or the forts change.
	var key := "%d:%s" % [m.wars_version, _forts_key]
	if key != _zones_key:
		_zones.clear()
		_zones_key = key
	if not _zones.has(tag):
		var enemies := _enemies_of(tag)
		var zones := {}
		for f: Province in _fort_list:
			if not enemies.has(f.controller_id):
				continue
			_zone_add(zones, f.id, f.id)
			for q: Province in _fort_land[f.id]:
				if enemies.has(q.controller_id):
					_zone_add(zones, q.id, f.id)
		_zones[tag] = zones
	return _zones[tag]


## The countries `tag` is at war with (tag -> true).
func _enemies_of(tag: String) -> Dictionary:
	var out := {}
	var index := m.war_index()
	var sides: Dictionary = index[0]
	for id: int in index[1].get(tag, []):
		var war: Dictionary = sides[id]
		var mine: int = war[tag]
		for t: String in war:
			if war[t] != mine:
				out[t] = true
	return out


static func _zone_add(zones: Dictionary, id: int, fort: int) -> void:
	if not zones.has(id):
		zones[id] = []
	zones[id].append(fort)


## Whether a fort's zone bars the march from one province to the next (into
## a hostile fort itself, never: it may always be besieged).
static func zoc_blocks(zones: Dictionary, from: int, to: int) -> bool:
	if not zones.has(from) or not zones.has(to) or to in zones[to]:
		return false
	for f: int in zones[from]:
		if f != to and f in zones[to]:
			return true
	return false


var _ports := {}  # province id -> the sea its dock opens on


## The sea a province's dock opens on (see Military.port_sea).
func port_of(p: Province) -> int:
	if not _ports.has(p.id):
		_ports[p.id] = Military.port_sea(world, p)
	return _ports[p.id]


## Whether `tag`'s fleets may berth here: a dock held by us or a friend.
func can_berth(tag: String, p: Province) -> bool:
	return not p.is_sea and "dock" in p.buildings and p.controller_id != "" and _friendly(tag, p.controller_id)


func _friendly(a: String, b: String) -> bool:
	var d := world.diplomacy
	return a == b or d.is_allied(a, b) or d.overlord_of(b) == a or d.overlord_of(a) == b


## Days to march from one province to the next (a strait crossing adds days).
func leg_days(from: Province, to: Province, speed: float) -> float:
	var km := DiplomacyActions._haversine(from.lat, from.lon, to.lat, to.lon)
	if to.is_sea or from.is_sea:  # at sea, or into port
		return maxf(1.0, km / speed)
	var ground: float = TOPOGRAPHY_DAYS.get(to.topography, 1.0) * VEGETATION_DAYS.get(to.vegetation, 1.0)
	var days := maxf(MIN_LEG_DAYS, km / speed * ground)
	if not to.id in from.neighbour_ids:
		days += STRAIT_DAYS  # ferried across by our fleet
	return days


## Sea zones where `tag` (or an ally) has a fleet, at sea or in a port on
## them: its armies may cross them.
func _fleet_seas(tag: String) -> Dictionary:
	var out := {}
	for a: Army in m.armies.values():
		if a.navy and _friendly(tag, a.owner):
			var p := world.get_province(a.location)
			out[a.location if p.is_sea else port_of(p)] = true
	return out


## The quickest road for an army (a fleet: the quickest course, ending at sea
## or in a dock open to it), not counting where it stands; [] if there is none
## (or, with `limit`, none found after opening that many provinces).
func find_path(army: Army, target: int, limit := 0) -> Array[int]:
	var goal := world.get_province(target)
	var start := world.get_province(army.location)
	if goal == null or start == null or target == army.location:
		return []
	if army.navy:
		if not goal.is_sea and not can_berth(army.owner, goal):
			return []
	elif goal.is_sea or not can_enter(army.side(), goal):
		return []
	var seas := {} if army.navy else _fleet_seas(army.owner)
	var zones := {} if army.navy else fort_zones(army.side())
	_zoc_hit = false
	var speed := army.speed()
	var g := {army.location: 0.0}
	var came := {}
	var heap := _Heap.new()
	heap.push(army.location, 0.0)
	var done := {}
	var enter := {}  # province id -> whether the army may go there (asked once a search)
	var to_goal := {}  # province id -> days to the goal as the crow flies (the estimate)
	while not heap.is_empty():
		var cur := heap.pop()
		if cur == target:
			break
		if done.has(cur):
			continue
		done[cur] = true
		if limit > 0 and done.size() > limit:
			last_search_nodes = done.size()
			return []
		var cp := world.get_province(cur)
		var here: float = g[cur]
		var steps: Array = []  # [province id, days]
		if army.navy:
			for n: int in _steps(army, cp, seas, target):
				steps.append([n, leg_days(cp, world.get_province(n), speed)])
		else:
			# Roads: each edge's distance and ground worked out once a game.
			var edges := _edges(cp)
			var ids: PackedInt32Array = edges[0]
			var kms: PackedFloat64Array = edges[1]
			var grounds: PackedFloat64Array = edges[2]
			for i in ids.size():
				var n := ids[i]
				if done.has(n):
					continue
				if not enter.has(n):
					enter[n] = can_enter(army.side(), world.get_province(n))
				if enter[n]:
					if not zones.is_empty() and zoc_blocks(zones, cur, n):
						_zoc_hit = true
						continue
					steps.append([n, maxf(MIN_LEG_DAYS, kms[i] / speed * grounds[i])])
			# Across a sea zone our fleet holds.
			for sea_id: int in cp.sea_ids:
				if not seas.has(sea_id):
					continue
				for c: int in world.get_province(sea_id).coast_ids:
					if c == cur or c in cp.neighbour_ids or done.has(c):
						continue
					if not enter.has(c):
						enter[c] = can_enter(army.side(), world.get_province(c))
					if enter[c]:
						if not zones.is_empty() and zoc_blocks(zones, cur, c):
							_zoc_hit = true
							continue
						steps.append([c, leg_days(cp, world.get_province(c), speed)])
		for step: Array in steps:
			var n: int = step[0]
			if done.has(n):
				continue
			var cost: float = here + step[1]
			if cost < g.get(n, INF):
				g[n] = cost
				came[n] = cur
				if not to_goal.has(n):
					var np := world.get_province(n)
					to_goal[n] = DiplomacyActions._haversine(np.lat, np.lon, goal.lat, goal.lon) / speed
				heap.push(n, cost + to_goal[n])
	last_search_nodes = done.size()
	if not came.has(target):
		return []
	var path: Array[int] = []
	var at := target
	while at != army.location:
		path.push_front(at)
		at = came[at]
	return path


var _edge_cache := {}  # province id -> [neighbour ids, km to each, its ground's slowness]


## A province's roads: its land neighbours, the distance to each and how slow
## its ground is (a leg: km / pace × ground, at least MIN_LEG_DAYS, as in
## leg_days).
func _edges(p: Province) -> Array:
	if not _edge_cache.has(p.id):
		var ids := PackedInt32Array()
		var kms := PackedFloat64Array()
		var grounds := PackedFloat64Array()
		for n: int in p.neighbour_ids:
			var to := world.get_province(n)
			if to == null or to.is_sea:
				continue
			ids.append(n)
			kms.append(DiplomacyActions._haversine(p.lat, p.lon, to.lat, to.lon))
			grounds.append(TOPOGRAPHY_DAYS.get(to.topography, 1.0) * VEGETATION_DAYS.get(to.vegetation, 1.0))
		_edge_cache[p.id] = [ids, kms, grounds]
	return _edge_cache[p.id]


## Where an army can go next from a province. A fleet leaves a dock by its
## port's sea, and enters a dock only at the end of its course (`target`).
func _steps(army: Army, p: Province, seas: Dictionary, target := -1) -> Array[int]:
	var out: Array[int] = []
	if army.navy:
		if not p.is_sea:
			if port_of(p) != 0:
				out.append(port_of(p))
			return out
		for n: int in p.neighbour_ids:
			if world.get_province(n).is_sea:
				out.append(n)
		var goal := world.get_province(target) if target >= 0 else null
		if goal != null and not goal.is_sea and port_of(goal) == p.id and can_berth(army.owner, goal):
			out.append(target)
		return out
	for n: int in p.neighbour_ids:
		if can_enter(army.side(), world.get_province(n)):
			out.append(n)
	for s: int in p.sea_ids:
		if seas.has(s):
			for c: int in world.get_province(s).coast_ids:
				if c != p.id and not c in out and can_enter(army.side(), world.get_province(c)):
					out.append(c)
	return out


## Days a whole road takes an army.
func path_days(army: Army, path: Array[int]) -> float:
	if army.aboard != 0 and path.size() == 1:
		return army.leg_total  # going ashore
	var total := 0.0
	var at := world.get_province(army.location)
	for id: int in path:
		var next := world.get_province(id)
		total += leg_days(at, next, army.speed())
		at = next
	return total


## Sends an army on its way ("" if it goes; else why not). `limit` bounds the
## route search (the AI's).
func order_move(army: Army, target: int, limit := 0) -> String:
	if army.retreating:
		return "Retreating: no orders until it reaches safety"
	if army.aboard != 0:
		return order_landing(army, target)
	var goal_p := world.get_province(target)
	if not army.navy and goal_p != null and goal_p.is_sea:
		var fleet := _boarding_fleet(army, target)
		if fleet != null:
			return board(army, fleet)
		return "Armies cannot march on water (tap a fleet of ours offshore to board it)"
	if army.location == target:
		stop(army)
		return ""
	var path := find_path(army, target, limit)
	if path.is_empty():
		var goal := world.get_province(target)
		if goal != null and army.navy and not goal.is_sea and not can_berth(army.owner, goal):
			return "That dock is not open to us" if "dock" in goal.buildings else "Fleets keep to the sea or berth at our docks"
		if goal != null and not army.navy and goal.is_sea:
			return "Armies cannot march on water"
		if goal != null and not army.navy and not can_enter(army.side(), goal):
			return "%s's land is closed to us (not at war)" % world.get_country(goal.owner_id).name
		if _zoc_hit:
			return "Enemy forts bar the road: take them, or go round"
		return "No way there"
	army.path = path
	army.leg_total = leg_days(world.get_province(army.location), world.get_province(path[0]), army.speed())
	army.leg_days = army.leg_total
	m.changed.emit()
	return ""


func stop(army: Army) -> void:
	if army.retreating:
		return
	army.path.clear()
	army.leg_days = 0.0
	m.changed.emit()


# --- Over the sea: boarding and landing -----------------------------------------------------

## Men aboard a fleet.
func cargo_men(fleet: Army) -> int:
	var total := 0
	for a: Army in m.cargo_of(fleet.id):
		total += a.men()
	return total


func free_capacity(fleet: Army) -> int:
	return maxi(fleet.capacity() - cargo_men(fleet), 0)


## Our fleet that can take an army aboard: in port where it stands or on a sea
## beside it (`sea`: only that sea tile), idle, with room; the one in port
## first, then the roomiest. null if none.
func _boarding_fleet(army: Army, sea := -1) -> Army:
	var p := world.get_province(army.location)
	if p == null or p.is_sea:
		return null
	var best: Army = null
	var best_room := -1
	for f: Army in m.armies_of(army.owner, true):
		if f.is_moving() or f.retreating:
			continue
		if sea >= 0 and f.location != sea:
			continue
		if f.location != p.id and not f.location in p.sea_ids:
			continue
		var room := free_capacity(f) + (1000000 if f.location == p.id else 0)
		if free_capacity(f) >= army.men() and room > best_room:
			best_room = room
			best = f
	return best


## Why an army cannot board a fleet now ("" if it can).
func board_blocked(army: Army) -> String:
	if army.navy:
		return "Fleets do not board fleets"
	if army.aboard != 0:
		return "Already aboard"
	if army.retreating:
		return "Retreating"
	if army.is_moving():
		return "Halt it first"
	if _boarding_fleet(army) != null:
		return ""
	var room := 0
	var p := world.get_province(army.location)
	for f: Army in m.armies_of(army.owner, true):
		if f.location == p.id or f.location in p.sea_ids:
			room = maxi(room, free_capacity(f))
	if room > 0:
		return "Our fleet here has room for only %s men" % DrawerPanel.thousands(room)
	return "No fleet of ours in port here or offshore"


## Why an army cannot board this fleet ("" if it can): ours, idle, in port
## where the army stands or on a sea beside it, with room.
func board_onto_blocked(army: Army, fleet: Army) -> String:
	if army.navy or army.aboard != 0:
		return "Already aboard" if army.aboard != 0 else "Fleets do not board fleets"
	if army.retreating:
		return "Retreating"
	if fleet == null or not fleet.navy or fleet.owner != army.owner:
		return "Not a fleet of ours"
	if fleet.is_moving():
		return "The fleet is under sail"
	var p := world.get_province(army.location)
	if p.is_sea or (fleet.location != p.id and not fleet.location in p.sea_ids):
		return "Too far: march to a coast beside the fleet first"
	if free_capacity(fleet) < army.men():
		return "The fleet has room for only %s more men" % DrawerPanel.thousands(free_capacity(fleet))
	return ""


## Takes an army aboard (`fleet`: that one, else the best at hand). "" if it boards.
func board(army: Army, fleet: Army = null) -> String:
	var why := board_blocked(army) if fleet == null else board_onto_blocked(army, fleet)
	if why != "":
		return why
	if fleet == null:
		fleet = _boarding_fleet(army)
	army.aboard = fleet.id
	army.location = fleet.location
	army.path.clear()
	army.leg_days = 0.0
	m.changed.emit()
	return ""


## Where the troops aboard a fleet may land: a coast of the sea it is on, or
## the port it lies in.
func can_land_at(fleet: Army, p: Province) -> bool:
	if p == null or p.is_sea or fleet.is_moving():
		return false
	var at := world.get_province(fleet.location)
	if not at.is_sea:
		return p.id == at.id
	return p.id in at.coast_ids


## Sends an army ashore from its fleet ("" if it goes).
func order_landing(army: Army, target: int) -> String:
	var fleet := m.get_army(army.aboard)
	var p := world.get_province(target)
	if fleet == null:
		return "Its fleet is gone"
	if p == null or p.is_sea:
		return "Aboard, it sails with its fleet: select the fleet to move it"
	if fleet.is_moving():
		return "The fleet is under sail: land when it has stopped"
	if not can_land_at(fleet, p):
		return "Land on a coast of the sea the fleet is on"
	if not can_enter(army.side(), p):
		return "%s's land is closed to us (not at war)" % world.get_country(p.owner_id).name
	army.path = [target] as Array[int]
	army.leg_total = 1.0 if fleet.location == target else LANDING_DAYS
	army.leg_days = army.leg_total
	m.changed.emit()
	return ""


## Lands everything a fleet carries on a coast ("" if they go).
func land_cargo(fleet: Army, target: int) -> String:
	var cargo := m.cargo_of(fleet.id)
	if cargo.is_empty():
		return "The fleet carries no troops"
	var why := ""
	for a: Army in cargo:
		why = order_landing(a, target)
		if why != "":
			return why
	return ""


## Armies aboard go where their fleet goes; a fleet lost takes them down with
## it, and a fleet with too few ships left loses the men it cannot carry.
func _cargo() -> void:
	var fleets := {}  # id -> [fleet, men aboard]
	for a: Army in m.armies.values():
		if a.aboard == 0:
			continue
		var f: Army = m.armies.get(a.aboard)
		if f == null:
			_remove(a)  # lost with its ships
			continue
		if not a.is_moving():
			a.location = f.location
		if not fleets.has(f.id):
			fleets[f.id] = [f, 0]
		fleets[f.id][1] += a.men()
	for id: int in fleets:
		var f: Army = fleets[id][0]
		var men: int = fleets[id][1]
		var room := f.capacity()
		if men > room and men > 0:
			_casualties(m.cargo_of(id), 1.0 - float(room) / men)


# --- The day ------------------------------------------------------------------------

func daily() -> void:
	_recruitment_day()
	_march()
	_cargo()
	_fight()
	_cargo()
	_besiege()
	_unberth()
	_cargo()


## Fleets in a dock no longer open to them (taken, ceded, razed) put to sea.
func _unberth() -> void:
	var moved := false
	for a: Army in m.armies.values():
		if not a.navy:
			continue
		var p := world.get_province(a.location)
		if p.is_sea or can_berth(a.owner, p) or port_of(p) == 0:
			continue
		a.location = port_of(p)
		a.path.clear()
		a.leg_days = 0.0
		moved = true
	if moved:
		economy.changed()  # out of port: full upkeep
		m.changed.emit()


func _march() -> void:
	var moved := false
	var berthing := false
	for a: Army in m.armies.values():
		if a.path.is_empty():
			continue
		a.leg_days -= 1.0
		while a.leg_days <= 0.0 and not a.path.is_empty():
			var next := world.get_province(a.path[0])
			if not a.navy and not can_enter(a.side(), next):
				a.path.clear()  # a peace closed the road
				break
			if not a.navy and not a.retreating and zoc_blocks(fort_zones(a.side()), a.location, next.id):
				a.path.clear()  # an enemy fort bars the road now
				break
			if a.navy and not next.is_sea and not can_berth(a.owner, next):
				a.path.clear()  # the dock is closed to us now
				break
			if a.navy and (not next.is_sea or not world.get_province(a.location).is_sea):
				berthing = true
			a.location = a.path.pop_front()
			moved = true
			if a.aboard != 0 and not next.is_sea:
				a.aboard = 0  # ashore
			if not a.navy and next.owner_id != "" and not m.refusing_wars(next.owner_id).is_empty():
				_attacked_subject(a.owner, next.owner_id)
			if not a.retreating and _enemies_at(a).size() > 0:
				a.path.clear()  # battle
				break
			if not a.path.is_empty():
				a.leg_total = leg_days(world.get_province(a.location), world.get_province(a.path[0]), a.speed())
				a.leg_days += a.leg_total
		if a.path.is_empty():
			a.leg_days = 0.0
			a.retreating = false  # safe at last
	if berthing:
		economy.changed()  # a fleet in or out of port: its upkeep
	if moved:
		m.changed.emit()


## Enemies standing where `a` is that it would fight (not those aboard
## ships or falling back).
func _enemies_at(a: Army) -> Array[Army]:
	var out: Array[Army] = []
	for b: Army in m.armies.values():
		if b.location == a.location and b.navy == a.navy and b.owner != a.owner and b.aboard == 0 \
				and not b.retreating and m.at_war(a.side(), b.side()):
			out.append(b)
	return out


## An army of `tag` entered the land of a subject that had stayed out of a war
## against it: the subject joins that war on its overlord's side.
func _attacked_subject(tag: String, subject: String) -> void:
	for id: int in m.refusing_wars(subject).duplicate():
		var war := m.get_war(id)
		var side := m.side_in(id, world.diplomacy.overlord_of(subject))
		if side >= 0 and m.side_in(id, tag) == 1 - side:
			m.join_war(war, subject, side)
			war_joined.emit(war, subject)
			m.wars_changed.emit()


# --- Battles ------------------------------------------------------------------------

func _fight() -> void:
	var places := {}
	for a: Army in m.armies.values():
		if a.aboard != 0 or a.retreating:
			continue
		var key := a.location * 2 + (1 if a.navy else 0)
		if not places.has(key):
			places[key] = []
		places[key].append(a)
	for key: int in places:
		var here: Array = places[key]
		for _bout in 4:  # several wars may meet in one place
			if here.size() < 2:
				break
			var pair := _hostile_pair(here)
			if pair.is_empty():
				break
			var war := m.war_between(pair[0].side(), pair[1].side())
			var side0 := Military.side_of(war, pair[0].side())
			var a_side: Array[Army] = []
			var b_side: Array[Army] = []
			for x: Army in here:
				var s := Military.side_of(war, x.side())
				if s == side0:
					a_side.append(x)
				elif s >= 0:
					b_side.append(x)
			battle(a_side, b_side, war)
			here = here.filter(func(x: Army) -> bool:
				return m.armies.has(x.id) and not x.retreating and x.location * 2 + (1 if x.navy else 0) == key)


func _hostile_pair(armies: Array) -> Array:
	for i in armies.size():
		for j in range(i + 1, armies.size()):
			if m.at_war(armies[i].side(), armies[j].side()):
				return [armies[i], armies[j]]
	return []


## How a battle between these armies would likely go: {power: [ours, theirs],
## chance: of our winning (0-1)}. The side holding the province defends.
func estimate(ours: Array, theirs: Array, location: int) -> Dictionary:
	var p := world.get_province(location)
	var a := 0.0
	var b := 0.0
	for x: Army in ours:
		a += x.power()
	for x: Army in theirs:
		b += x.power()
	if not p.is_sea and not theirs.is_empty() and _holds(theirs[0].owner, p):
		b *= defence_bonus(p)
	elif not p.is_sea and not ours.is_empty() and _holds(ours[0].owner, p):
		a *= defence_bonus(p)
	# Luck spreads each side by ±BATTLE_LUCK: the chance one draw beats the other.
	var r := a / maxf(b, 1.0)
	var chance := clampf(0.5 + (r - 1.0) / (2.0 * BATTLE_LUCK * 2.0), 0.0, 1.0)
	return {"power": [a, b], "chance": chance}


func _holds(tag: String, p: Province) -> bool:
	return p.controller_id == tag or (p.controller_id != "" and _friendly(tag, p.controller_id))


## The ground's help to a defender: hills, mountains, marsh, forest, a fort.
func defence_bonus(p: Province) -> float:
	var f: float = DEFENCE_TOPOGRAPHY.get(p.topography, 1.0) * DEFENCE_VEGETATION.get(p.vegetation, 1.0)
	return f * (FORT_DEFENCE if "fort" in p.buildings else 1.0)


## Fights it out: the side holding the province defends. Losses fall on both,
## heavier on the loser, whose armies retreat to friendly ground beside or are
## destroyed. The winner's side gains battle score.
func battle(a_side: Array[Army], b_side: Array[Army], war: Dictionary) -> Dictionary:
	var location := a_side[0].location
	var p := world.get_province(location)
	var navy := a_side[0].navy
	var a_defends := not navy and _holds(a_side[0].owner, p)
	var defenders := a_side if a_defends else b_side
	var attackers := b_side if a_defends else a_side
	var att := 0.0
	var dfn := 0.0
	for x: Army in attackers:
		att += x.power()
	for x: Army in defenders:
		dfn += x.power()
	if not navy:
		dfn *= defence_bonus(p)
	att *= rng.randf_range(1.0 - BATTLE_LUCK, 1.0 + BATTLE_LUCK)
	dfn *= rng.randf_range(1.0 - BATTLE_LUCK, 1.0 + BATTLE_LUCK)
	var attackers_win := att > dfn
	var winners := attackers if attackers_win else defenders
	var losers := defenders if attackers_win else attackers
	var ratio := maxf(att, dfn) / maxf(minf(att, dfn), 1.0)
	var lost_losers := _casualties(losers, clampf(0.12 + 0.08 * (ratio - 1.0), 0.12, 0.4))
	var lost_winners := _casualties(winners, clampf(0.02 + 0.06 / ratio, 0.03, 0.08))
	for x: Army in winners:
		x.morale = maxf(x.morale * 0.85, 0.1)
	var destroyed := 0
	var winners_men := 0
	for x: Army in winners:
		winners_men += x.men()
	var losers_men := 0
	for x: Army in losers:
		losers_men += x.men()
	var overwhelmed := winners_men >= STACKWIPE_RATIO * maxi(losers_men, 1)
	for x: Army in losers:
		if not m.armies.has(x.id):
			continue  # broke up under its losses
		x.morale = maxf(x.morale * 0.4, 0.05)
		x.path.clear()
		var road := [] as Array[int] if overwhelmed else retreat_path(x)
		if road.is_empty():
			destroyed += x.men()
			_remove(x)
		else:
			x.path = road
			x.retreating = true
			x.leg_total = leg_days(world.get_province(x.location), world.get_province(road[0]), x.speed())
			x.leg_days = x.leg_total
	var winner_side := Military.side_of(war, winners[0].side())
	var gain := clampf((lost_losers + destroyed) / 2000.0, 1.0, 15.0)
	war.battle_score = clampf(war.battle_score + (gain if winner_side == 0 else -gain), -BATTLE_SCORE_CAP, BATTLE_SCORE_CAP)
	_apply_levy_deaths()
	# Sides by who fights the war (volunteers count for their hosts); `tags`, the
	# countries whose armies were there.
	var report := {"province": location, "navy": navy, "attacker": attackers[0].side(), "defender": defenders[0].side(),
		"winner": winners[0].side(), "attacker_losses": lost_winners if attackers_win else lost_losers + destroyed,
		"defender_losses": lost_losers + destroyed if attackers_win else lost_winners, "war": war.id,
		"tags": _tags_of(attackers + defenders)}
	m.changed.emit()
	battle_fought.emit(report)
	return report


static func _tags_of(armies: Array) -> Array:
	var out := []
	for x: Army in armies:
		if not x.owner in out:
			out.append(x.owner)
	return out


## Takes a share of every regiment's men; returns the men lost. Regiments worn
## below fifty men break up; levies who fall are lost to their home province.
func _casualties(armies: Array, share: float) -> int:
	var lost := 0
	for x: Army in armies:
		for r: Array in x.regiments:
			var n := int(round(r[1] * share))
			r[1] -= n
			lost += n
			if r[0] == "levy" and r[2] != 0:
				_levy_dead[r[2]] = _levy_dead.get(r[2], 0) + n
		x.regiments = x.regiments.filter(func(r: Array) -> bool: return r[1] >= 50)
		if x.regiments.is_empty():
			_remove(x)
	return lost


func _remove(a: Army) -> void:
	m.remove_army(a.id)


## The dead among levies leave their provinces' people (commoners first).
func _apply_levy_deaths() -> void:
	if _levy_dead.is_empty():
		return
	for id: int in _levy_dead:
		var p := world.get_province(id)
		var n: int = _levy_dead[id]
		var commoners: int = mini(p.pops.get("commoners", 0), n)
		p.add_people("commoners", -commoners)
		p.add_people("tribesmen", -(n - commoners))
		economy.touch(p)
	_levy_dead.clear()
	_recount_levies()


## How many provinces (sea zones) a beaten army or fleet falls back: by the
## age of the units it fields (their men-weighted year), one more if mounted.
func retreat_steps(a: Army) -> int:
	var men := 0.0
	var years := 0.0
	for r: Array in a.regiments:
		years += float(UnitTypes.get_type(r[0]).get("from", 1590)) * r[1]
		men += r[1]
	var year := years / maxf(men, 1.0)
	var steps := 5
	for band: Array in RETREAT_BY_AGE:
		if year < band[0]:
			steps = band[1]
			break
	if not a.navy and a.speed() >= MOUNTED_SPEED:
		steps += 1
	return steps


## Where a beaten army falls back: up to retreat_steps provinces
## (sea zones, for a fleet; a port of ours may end it) through ground free of
## the enemy's armies — to friendly ground if any is in reach (the one nearest
## home), else as far as it can get towards home. The road there; [] if it is
## cut off.
func retreat_path(a: Army) -> Array[int]:
	var c := world.get_country(a.owner)
	var home := world.get_province(c.capital_province_id) if c else null
	var hostile := {}  # province (or sea) ids where enemies of `a` stand
	for x: Army in m.armies.values():
		if x.navy == a.navy and x.aboard == 0 and m.at_war(a.side(), x.side()):
			hostile[x.location] = true
	var came := {a.location: -1}
	var depth := {a.location: 0}
	var frontier: Array[int] = [a.location]
	var best := 0
	var best_score := -INF
	var reach := retreat_steps(a)
	while not frontier.is_empty():
		var next: Array[int] = []
		for cur: int in frontier:
			var cp := world.get_province(cur)
			var steps: Array[int] = []
			if a.navy:
				if not cp.is_sea:
					if port_of(cp) != 0:
						steps.append(port_of(cp))
				else:
					for n: int in cp.neighbour_ids:
						if world.get_province(n).is_sea:
							steps.append(n)
					for n: int in cp.coast_ids:
						if can_berth(a.owner, world.get_province(n)) and port_of(world.get_province(n)) == cur:
							steps.append(n)
			else:
				for n: int in cp.neighbour_ids:
					if can_enter(a.side(), world.get_province(n)):
						steps.append(n)
			for n: int in steps:
				if came.has(n) or hostile.has(n):
					continue
				came[n] = cur
				var steps_out: int = depth[cur] + 1
				depth[n] = steps_out
				var p := world.get_province(n)
				var safe := can_berth(a.owner, p) if a.navy and not p.is_sea else \
					(a.navy or (p.controller_id != "" and _friendly(a.side(), p.controller_id)))
				var km := DiplomacyActions._haversine(p.lat, p.lon, home.lat, home.lon) if home else 0.0
				# Friendly ground first (nearest home); else the farthest reach towards home.
				var score: float = (1e7 if safe else steps_out * 1e5) - km
				if score > best_score:
					best_score = score
					best = n
				if steps_out < reach and not (a.navy and not p.is_sea):
					next.append(n)
		frontier = next
	if best == 0:
		return []
	var road: Array[int] = []
	var at := best
	while at != a.location:
		road.push_front(at)
		at = came[at]
	return road


# --- Sieges -------------------------------------------------------------------------

## Whether a province must be besieged: a fort, or a capital (its city walls).
static func walled(world: WorldState, p: Province) -> bool:
	if "fort" in p.buildings:
		return true
	var owner := world.get_country(p.owner_id)
	return owner != null and owner.capital_province_id == p.id


## How strong a fort is: its upkeep (neglected, weaker) and more at a capital;
## a capital without one, its city walls (CITY_WALLS); open land, 0.
func fort_strength(p: Province) -> float:
	var owner := world.get_country(p.owner_id)
	var capital := owner != null and owner.capital_province_id == p.id
	if not "fort" in p.buildings:
		return CITY_WALLS if capital else 0.0
	var strength := maxf(0.25, (owner.spending.forts if owner else 100) / 100.0)
	if capital:
		strength *= CAPITAL_SIEGE
	return strength


## Men holding a fort or a capital's walls (0 for open land).
func garrison(p: Province) -> int:
	return int(FORT_GARRISON * fort_strength(p)) if walled(world, p) else 0


## Armies standing at a province (not marching, not aboard) at war with its holder.
func besiegers_at(loc: int) -> Array[Army]:
	var p := world.get_province(loc)
	var out: Array[Army] = []
	if p == null or p.controller_id == "":
		return out
	for a: Army in m.armies_at(loc):
		if not a.navy and a.path.is_empty() and a.aboard == 0 and m.at_war(a.side(), p.controller_id):
			out.append(a)
	return out


## The chance (percent) that a fort falls at the next try, and why:
## {chance, reasons: [[reason, points]], men, garrison}. `armies`: the
## besiegers (by default those there); `phases`: tries failed so far (by
## default the siege's).
func siege_odds(p: Province, armies: Array = [], phases := -1) -> Dictionary:
	if armies.is_empty():
		armies = besiegers_at(p.id)
	if phases < 0:
		phases = int(m.sieges.get(p.id, {}).get("phases", 0))
	var men := 0
	var guns := 0.0
	for a: Army in armies:
		men += a.men()
		guns += a.siege_power() * a.men()
	var held := maxf(garrison(p), 1.0)
	var reasons := [["Fortune of the siege", SIEGE_BASE]]
	if phases > 0:
		reasons.append(["Months under siege (%d)" % phases, minf(phases * SIEGE_PER_PHASE, SIEGE_TIME_CAP)])
	var numbers := clampf((men / held - 1.0) * SIEGE_PER_GARRISON, 0.0, SIEGE_NUMBERS_CAP)
	if numbers > 0.0:
		reasons.append(["Our numbers against the garrison", numbers])
	var artillery := minf(guns / maxf(men, 1.0) * SIEGE_ARTILLERY, SIEGE_ARTILLERY_CAP)
	if artillery > 0.0:
		reasons.append(["Artillery", artillery])
	var short := clampf(1.0 - (guns + men * IMPROVISED_SIEGE) / (held * SIEGE_EQUIPMENT_NEED), 0.0, 1.0)
	if short > 0.0:
		reasons.append(["Short of siege equipment", -SIEGE_NO_EQUIPMENT * short])
	reasons.append(["The walls" if "fort" in p.buildings else "The city walls", -SIEGE_WALLS * fort_strength(p)])
	var total := 0.0
	for r: Array in reasons:
		total += r[1]
	return {"chance": clampf(total, 0.0, SIEGE_MAX_CHANCE), "reasons": reasons, "men": men, "garrison": int(held)}


## The odds (percent) of storming a fort whose siege stands at `chance`.
static func assault_chance(chance: float) -> float:
	return clampf(ASSAULT_BASE + chance * ASSAULT_FACTOR, 0.0, ASSAULT_MAX)


## Days until the next try at a fort under siege.
func days_to_try(loc: int) -> int:
	var s: Dictionary = m.sieges.get(loc, {})
	if s.is_empty():
		return SIEGE_PHASE_DAYS
	return maxi(ceili((int(s.get("phases", 0)) + 1) * SIEGE_PHASE_DAYS - float(s.progress)), 0)


func _besiege() -> void:
	var standing := {}
	for a: Army in m.armies.values():
		if not a.navy and a.path.is_empty() and a.aboard == 0 and m.in_any_war(a.side()):
			if not standing.has(a.location):
				standing[a.location] = []
			standing[a.location].append(a)
	var active := {}
	for loc: int in standing:
		var p := world.get_province(loc)
		if p.controller_id == "":
			continue
		var here: Array = standing[loc]
		var besiegers := here.filter(func(a: Army) -> bool: return m.at_war(a.side(), p.controller_id))
		if besiegers.is_empty():
			continue
		var lead: Army = besiegers[0]
		for b: Army in besiegers:
			if b.men() > lead.men():
				lead = b
		if here.any(func(a: Army) -> bool: return m.at_war(a.side(), lead.side())):
			continue  # the defenders are still in the field here
		var men := 0
		var siege := 0.0
		for b: Army in besiegers:
			men += b.men()
			siege += b.siege_power() * b.men()
		var fort := walled(world, p)
		if men < MIN_SIEGE_MEN or (fort and men < garrison(p)):
			continue  # too few to shut the garrison in
		var s: Dictionary = m.sieges.get(loc, {})
		if s.is_empty() or not (s.by == lead.side() or _friendly(s.by, lead.side())):
			s = {"by": lead.side(), "progress": 0.0, "phases": 0, "assault": -1}
		m.sieges[loc] = s
		active[loc] = true
		if not fort:
			s.progress += 1.0 + siege / men
			if s.progress >= OCCUPY_DAYS:
				_fall(p, lead.side())
				active.erase(loc)
			continue
		s.progress += 1.0
		var odds := siege_odds(p, besiegers, int(s.phases))
		s["chance"] = odds.chance
		if s.progress >= (int(s.phases) + 1) * SIEGE_PHASE_DAYS:
			if rng.randf() * 100.0 < odds.chance:
				_fall(p, lead.side())
				active.erase(loc)
			else:
				s.phases = int(s.phases) + 1
		elif lead.owner != world.player_country_id and assault_chance(odds.chance) >= AI_ASSAULT_CHANCE \
				and assault_blocked(lead.owner, loc) == "":
			assault(lead.owner, loc)  # the AI storms when the odds are good
			if not m.sieges.has(loc):
				active.erase(loc)
	for loc: int in m.sieges.keys():
		if not active.has(loc):
			m.sieges.erase(loc)


## A province falls to `by`: freed if it was its own or its side's, else held
## — or, in a civil war, taken from the other claimant outright (annexed).
func _fall(p: Province, by: String) -> void:
	m.sieges.erase(p.id)
	var war := m.war_between(by, p.controller_id)
	var liberating := p.owner_id == by or (not war.is_empty()
		and Military.side_of(war, p.owner_id) == Military.side_of(war, by))
	var taker := p.owner_id if liberating else by
	var leaders: Array = [war.attackers[0], war.defenders[0]] if not war.is_empty() else []
	if not liberating and war.get("civil", false) and taker in leaders and p.owner_id in leaders:
		var loser := p.owner_id
		var annexed: Array = war.get("annexed", [0.0, 0.0])
		annexed[Military.side_of(war, taker)] += p.development
		war["annexed"] = annexed
		world.transfer_province(p.id, taker)
		province_annexed.emit(p.id, taker, loser)
		if world.country_stats(loser).provinces == 0:
			var summary := "%s is no more: %s holds the realm" % [_name(loser), _name(taker)]
			_end_war(war)
			peace_made.emit(war, summary)
		return
	world.set_controller(p.id, taker)
	province_occupied.emit(p.id, taker)


## Two countries of one culture, one holding a core on the other's capital:
## a war between them is a civil war (see Military.civil_war).
func is_civil_war(a: String, b: String) -> bool:
	return Military.civil_war(world, a, b)


## Our armies besieging a province.
func our_besiegers(tag: String, loc: int) -> Array[Army]:
	var out: Array[Army] = []
	for a: Army in besiegers_at(loc):
		if a.owner == tag:
			out.append(a)
	return out


## Why `tag` cannot storm the fort at `loc` ("" if it can).
func assault_blocked(tag: String, loc: int) -> String:
	var p := world.get_province(loc)
	if p == null or not walled(world, p):
		return "Only forts and capitals are stormed (open land is simply occupied)"
	var s: Dictionary = m.sieges.get(loc, {})
	if s.is_empty():
		return "We are not besieging it"
	if our_besiegers(tag, loc).is_empty():
		return "None of our armies besiege it"
	if float(s.progress) < ASSAULT_MIN_DAYS:
		return "The siege works need %d more days" % ceili(ASSAULT_MIN_DAYS - float(s.progress))
	var last := int(s.get("assault", -1))
	if last >= 0 and clock.day_number() - last < ASSAULT_EVERY_DAYS:
		return "Our men need %d more days after the last assault" % (ASSAULT_EVERY_DAYS - (clock.day_number() - last))
	return ""


## Storms a fort under siege with our armies there: it falls or holds by the
## odds, and the stormers lose men (ASSAULT_LOSS of them if it falls,
## ASSAULT_FAIL_LOSS if it holds) and spirit. {taken, lost, chance} ({} if it
## cannot be stormed).
func assault(tag: String, loc: int) -> Dictionary:
	if assault_blocked(tag, loc) != "":
		return {}
	var p := world.get_province(loc)
	var s: Dictionary = m.sieges[loc]
	var ours := our_besiegers(tag, loc)
	var chance := assault_chance(siege_odds(p, besiegers_at(loc), int(s.phases)).chance)
	var taken := rng.randf() * 100.0 < chance
	for a: Army in ours:
		a.morale = maxf(a.morale - (ASSAULT_MORALE * 0.5 if taken else ASSAULT_MORALE), 0.0)
	var lost := _casualties(ours, ASSAULT_LOSS if taken else ASSAULT_FAIL_LOSS)
	s["assault"] = clock.day_number()
	if taken:
		_fall(p, ours[0].side() if not ours.is_empty() else tag)
	m.changed.emit()
	return {"taken": taken, "lost": lost, "chance": chance}


# --- Civil wars and their rebels -----------------------------------------------------------

## A civil war (Military.civil_war) is fought for the realm itself: what a
## leader takes from the other is annexed outright (no occupation), and its war
## score (civil_score, the attackers') is the battles, the land each side has
## annexed from the other (its development's share of both realms, at
## CIVIL_ANNEX_WEIGHT), and a monthly tick of CIVIL_TICK — for the state while
## the rebels hold under REBELS_FEW of the realm, for the rebels while they hold
## over REBELS_MANY (to CIVIL_TICK_CAP either way).
## Its peace never trades land: the rebels have demands, each worth points
## (REBEL_DEMANDS); they lay down arms once the demands granted are worth at
## least their price — REBEL_PRICE less the state's war score (nothing when the
## state is clearly winning) — and the state concedes no more than that. Their
## land then returns to the crown, unless their leaders keep it as vassals.
const CIVIL_ANNEX_WEIGHT := 1.0
const CIVIL_TICK := 2.0
const CIVIL_TICK_CAP := 40.0
const REBELS_FEW := 0.25
const REBELS_MANY := 0.5
const REBEL_PRICE := 20.0
const REBEL_DEMANDS := {
	"amnesty": {"name": "An amnesty for all who took up arms", "value": 5},
	"pensions": {"name": "Pensions for their leaders (half a year of our taxes)", "value": 10},
	"privileges": {"name": "Their nobles' and clergy's privileges confirmed", "value": 15},
	"governorships": {"name": "Their leaders keep their lands, as our vassals", "value": 25},
	"faith": {"name": "A ruler of their faith", "value": 30},
	"throne": {"name": "The crown for their claimant", "value": 60},
}


## The state (the crown) and the rebels in a civil war: [state, rebels].
func civil_parties(war: Dictionary) -> Array:
	var rebels: String = war.get("rebels", "")
	if rebels == "":
		rebels = war.defenders[0]
	return [war.attackers[0] if rebels == war.defenders[0] else war.defenders[0], rebels]


## The attackers' war score in a civil war (see above).
func civil_score(war: Dictionary) -> float:
	var parties := civil_parties(war)
	var dev := 0.0
	for p: Province in world.ownable_provinces():
		if p.owner_id in parties:
			dev += p.development
	var annexed: Array = war.get("annexed", [0.0, 0.0])
	var land: float = (annexed[0] - annexed[1]) / maxf(dev, 1.0) * 100.0 * CIVIL_ANNEX_WEIGHT
	return clampf(land + war.battle_score + float(war.get("tick", 0.0)), -100.0, 100.0)


## The share of the realm (both parties' development) the rebels hold.
func rebel_share(war: Dictionary) -> float:
	var parties := civil_parties(war)
	var dev := [0.0, 0.0]
	for p: Province in world.ownable_provinces():
		var i := parties.find(p.owner_id)
		if i >= 0:
			dev[i] += p.development
	return dev[1] / maxf(dev[0] + dev[1], 1.0)


func _civil_ticks() -> void:
	for w: Dictionary in m.wars:
		if not w.get("civil", false):
			continue
		var share := rebel_share(w)
		var state_attacks: bool = civil_parties(w)[0] == w.attackers[0]
		var step := 0.0
		if share < REBELS_FEW:
			step = CIVIL_TICK
		elif share > REBELS_MANY:
			step = -CIVIL_TICK
		w["tick"] = clampf(float(w.get("tick", 0.0)) + (step if state_attacks else -step), -CIVIL_TICK_CAP, CIVIL_TICK_CAP)


## The war score of the state (the crown) in a civil war.
func state_score(war: Dictionary) -> float:
	return civil_score(war) * (1.0 if civil_parties(war)[0] == war.attackers[0] else -1.0)


## The rebels' demands in this war (a ruler of their faith only if theirs differs).
func rebel_demands(war: Dictionary) -> Array[String]:
	var parties := civil_parties(war)
	var state := world.get_country(parties[0])
	var rebels := world.get_country(parties[1])
	var out: Array[String] = []
	for id: String in REBEL_DEMANDS:
		if id == "faith" and (state == null or rebels == null or state.religion == rebels.religion):
			continue
		out.append(id)
	return out


func demands_value(granted: Array) -> int:
	var total := 0
	for id: String in granted:
		total += int(REBEL_DEMANDS.get(id, {}).get("value", 0))
	return total


## What the rebels' demands must be worth for them to lay down arms now.
func rebel_price(war: Dictionary) -> float:
	return maxf(REBEL_PRICE - state_score(war), 0.0)


## Whether the other party agrees: granted by the state, the rebels take it if
## it is worth their price; pressed by the rebels, the state yields if it is
## worth no more than that.
func civil_accepted(war: Dictionary, from: String, granted: Array) -> bool:
	var value := float(demands_value(granted))
	if from == civil_parties(war)[0]:
		return value >= rebel_price(war)
	return value <= rebel_price(war)


## The cheapest set of demands worth the rebels' price (the throne last of all).
func cheapest_settlement(war: Dictionary) -> Array[String]:
	var price := rebel_price(war)
	var ids := rebel_demands(war)
	ids.sort_custom(func(a: String, b: String) -> bool: return REBEL_DEMANDS[a].value < REBEL_DEMANDS[b].value)
	var out: Array[String] = []
	var total := 0
	for id: String in ids:
		if float(total) >= price:
			break
		out.append(id)
		total += int(REBEL_DEMANDS[id].value)
	return out


## The rebels lay down arms on the demands granted: their land returns to the
## crown (or, governorships granted, they keep it as its vassals).
func _settle_civil_war(war: Dictionary, granted: Array) -> String:
	var parties := civil_parties(war)
	var state := world.get_country(parties[0])
	var rebels := world.get_country(parties[1])
	var summary := describe_treaty(war, parties[0], {"granted": granted})
	war["signed"] = parties.duplicate()
	if "pensions" in granted:
		economy.post(state, "Pensions to the %s leaders" % rebels.adjective,
			-minf(economy.budget(state.id).tax_income * 6.0, maxf(state.treasury, 0.0)))
	if "privileges" in granted:
		for i in [0, 1]:  # nobility and clergy
			state.satisfaction[i] = minf(state.satisfaction[i] + 20.0, 100.0)
	if "faith" in granted:
		state.religion = rebels.religion
	if "throne" in granted:
		state.legitimacy = 25.0
		state.stability = maxi(state.stability - 2, WorldState.MIN_STABILITY)
	var rebel_land: Array[int] = []
	for p: Province in world.ownable_provinces():
		if p.owner_id == rebels.id:
			rebel_land.append(p.id)
	_end_war(war)
	if "governorships" in granted:
		world.diplomacy.set_subject(state.id, rebels.id, "vassal")
	else:
		for a: Army in m.armies.values():
			if a.owner == rebels.id:
				m.remove_army(a.id)  # they go home and disband
		for id: int in rebel_land:
			world.transfer_province(id, state.id)
			if "amnesty" in granted:
				var p := world.get_province(id)
				p.unrest = maxf(p.unrest - 10.0, 0.0)
	economy.changed()
	peace_made.emit(war, summary)
	return summary


## A civil war's AI: rebels clearly beaten submit (their demands refused); a
## state that cannot win grants the cheapest settlement after a year; offers
## to the player instead of signing for it.
func _ai_civil_peace(w: Dictionary, player: String, today: int) -> void:
	var parties := civil_parties(w)
	var price := rebel_price(w)
	var years := (today - int(w.start)) / 365.0
	var granted: Array[String] = []
	if price <= 0.0:
		granted = []  # they submit
	elif years >= 1.0 and state_score(w) < 0.0:
		granted = cheapest_settlement(w)
		if "throne" in granted and state_score(w) > -40.0:
			return  # the crown holds on
	else:
		return
	var state: String = parties[0]
	var rebels: String = parties[1]
	if state == player or rebels == player:
		var by := rebels if state == player else state
		if _may_offer(w, by, today):
			peace_offered.emit(w, {"with": player, "granted": granted}, by)
		return
	_settle_civil_war(w, granted)


# --- Volunteers -------------------------------------------------------------------------

## An army sent to fight in another country's war without its own country
## joining it (Army.volunteer_for): it marches, fights and besieges as the
## host's, and what it takes is the host's; its own country pays for it and
## stays at peace with the host's enemies. It comes home when the host's wars
## end, when its country goes to war with the host, or when recalled.

## Countries an army of `tag` may volunteer for: at war, not with us, in wars we are not in.
func volunteer_hosts(tag: String) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for w: Dictionary in m.wars:
		if Military.side_of(w, tag) >= 0:
			continue
		for t: String in w.attackers + w.defenders:
			if not seen.has(t) and t != tag and not m.at_war(tag, t) and world.get_country(t) != null:
				seen[t] = true
				out.append(t)
	out.sort_custom(func(a: String, b: String) -> bool: return _name(a) < _name(b))
	return out


## Why an army cannot go to fight for `host` ("" if it can).
func volunteer_blocked(a: Army, host: String) -> String:
	if a.navy:
		return "Fleets do not go as volunteers"
	if a.volunteer_for != "":
		return "Already fighting for %s" % _name(a.volunteer_for)
	if a.aboard != 0 or a.retreating:
		return "Not while aboard ship or falling back"
	if a.has_levies():
		return "Levies serve at home"
	if host == a.owner or world.get_country(host) == null:
		return "Not here"
	if not m.in_any_war(host):
		return "%s is at peace" % _name(host)
	if m.at_war(a.owner, host):
		return "We are at war with %s" % _name(host)
	for w: Dictionary in m.wars_of(host):
		if Military.side_of(w, a.owner) >= 0:
			return "We fight in that war ourselves"
	return ""


func send_volunteers(a: Army, host: String) -> bool:
	if volunteer_blocked(a, host) != "":
		return false
	a.volunteer_for = host
	a.path.clear()
	m.changed.emit()
	return true


## Volunteers come home: out of land closed to their own country, to its capital.
func recall_volunteers(a: Army) -> void:
	if a.volunteer_for == "":
		return
	a.volunteer_for = ""
	a.path.clear()
	if a.aboard == 0 and not can_enter(a.owner, world.get_province(a.location)):
		var cap := world.get_province(world.get_country(a.owner).capital_province_id)
		if cap != null:
			a.location = cap.id
	m.changed.emit()


## Volunteers whose host is at peace again, or at war with their own country, come home.
func _check_volunteers() -> void:
	for a: Army in m.armies.values():
		var host := a.volunteer_for
		if host != "" and (world.get_country(host) == null or not m.in_any_war(host) or m.at_war(a.owner, host)):
			recall_volunteers(a)


# --- Handing over occupied land --------------------------------------------------------

## Who `from` may hand an enemy province it holds to: those fighting on its
## side in the war with the province's owner.
func occupation_partners(from: String, p: Province) -> Array[String]:
	var out: Array[String] = []
	if p == null or p.controller_id != from or p.owner_id == from or p.owner_id == "":
		return out
	var war := m.war_between(from, p.owner_id)
	if war.is_empty():
		return out
	for t: String in (war.attackers if Military.side_of(war, from) == 0 else war.defenders):
		if t != from and world.get_country(t) != null:
			out.append(t)
	return out


## Why `from` cannot hand the province to `to` ("" if it can).
func transfer_occupation_blocked(from: String, to: String, p: Province) -> String:
	if p == null or p.controller_id != from:
		return "We do not hold it"
	if p.owner_id == from:
		return "It is our own land"
	if m.war_between(from, p.owner_id).is_empty():
		return "Not taken in a war"
	if not to in occupation_partners(from, p):
		return "%s does not fight on our side in this war" % _name(to)
	return ""


## Hands an enemy province we hold to an ally in the war: they hold it now.
func transfer_occupation(from: String, to: String, province_id: int) -> bool:
	var p := world.get_province(province_id)
	if transfer_occupation_blocked(from, to, p) != "":
		return false
	m.sieges.erase(province_id)
	world.set_controller(province_id, to)
	m.changed.emit()
	return true


# --- The month -----------------------------------------------------------------------

func monthly() -> void:
	_check_volunteers()
	_civil_ticks()
	_refill_pools()
	_supply()
	_reinforce()
	_apply_levy_deaths()
	m.changed.emit()


## Armies too large for the land to feed lose men; in enemy land a little more.
func _supply() -> void:
	var by_place := {}
	for a: Army in m.armies.values():
		if not a.navy and a.aboard == 0:
			if not by_place.has(a.location):
				by_place[a.location] = []
			by_place[a.location].append(a)
	for loc: int in by_place:
		var p := world.get_province(loc)
		var here: Array = by_place[loc]
		var men := 0
		for a: Army in here:
			men += a.men()
		var harsh: float = minf(HARSH_SUPPLY.get(p.vegetation, 1.0), minf(HARSH_SUPPLY.get(p.climate, 1.0),
			HARSH_SUPPLY.get(p.topography, 1.0)))
		var supply := (SUPPLY_BASE + p.development * SUPPLY_PER_DEVELOPMENT + p.population * SUPPLY_PER_PERSON) * harsh
		for a: Army in here:
			var share := 0.0
			var hostile := p.controller_id != "" and m.at_war(a.side(), p.controller_id)
			var limit := supply * (0.5 if hostile else 1.0)
			if men > limit:
				share += minf(0.1, 0.01 + 0.04 * (men / limit - 1.0))
			if hostile:
				share += 0.01
			if share > 0.0:
				_casualties([a], share)


# --- Manpower and sailors ---------------------------------------------------------------

## Each country's pools: tag -> {manpower, sailors: ceilings; manpower_growth,
## sailors_growth: a month; trained, crews: soldiers its barracks and sailors
## its docks train a month} (see MANPOWER_SHARE).
func pools() -> Dictionary:
	var out := {}
	for p: Province in world.ownable_provinces():
		if p.owner_id == "" or p.controller_id != p.owner_id:
			continue
		if not out.has(p.owner_id):
			out[p.owner_id] = {"people": 0.0, "coast": 0.0, "trained": 0.0, "crews": 0.0}
		var o: Dictionary = out[p.owner_id]
		o.people += p.population * MANPOWER_SHARE
		if p.is_coastal:
			o.coast += p.population * SAILOR_SHARE
		if "barracks" in p.buildings:
			o.trained += maxf(BARRACKS_MIN, p.population * BARRACKS_SHARE)
		if "dock" in p.buildings:
			o.crews += maxf(DOCK_MIN, p.population * DOCK_SHARE)
	for tag: String in out:
		var o: Dictionary = out[tag]
		var c := world.get_country(tag)
		if Ideas.has(c, "conscription"):
			o.people *= CONSCRIPTION
		if Ideas.has(c, "drill_grounds"):
			o.trained *= IDEA_TRAINING
		if Ideas.has(c, "naval_academies"):
			o.crews *= IDEA_TRAINING
		o["manpower"] = o.people + o.trained * TRAINED_MONTHS
		o["manpower_growth"] = o.people / POOL_GROWTH_MONTHS + o.trained
		o["sailors"] = o.coast + o.crews * TRAINED_MONTHS
		o["sailors_growth"] = o.coast / POOL_GROWTH_MONTHS + o.crews
	return out


func pool(tag: String) -> Dictionary:
	return pools().get(tag, {"manpower": 0.0, "manpower_growth": 0.0, "sailors": 0.0, "sailors_growth": 0.0,
		"trained": 0.0, "crews": 0.0})


func manpower_limit(tag: String) -> float:
	return pool(tag).manpower


func manpower(tag: String) -> float:
	return m.manpower.get(tag, 0.0)


## Monthly growth of manpower (by itself and from barracks).
func manpower_growth(tag: String) -> float:
	return pool(tag).manpower_growth


func sailor_limit(tag: String) -> float:
	return pool(tag).sailors


func sailors(tag: String) -> float:
	return m.sailors.get(tag, 0.0)


func sailor_growth(tag: String) -> float:
	return pool(tag).sailors_growth


## The pool a unit draws its men from: ships' crews from sailors, the rest
## from manpower.
static func pool_of(type: String) -> String:
	return "sailors" if UnitTypes.get_type(type).domain == "sea" else "manpower"


func _pool_men(tag: String, which: String) -> float:
	return sailors(tag) if which == "sailors" else manpower(tag)


func _draw(tag: String, which: String, men: float) -> void:
	if which == "sailors":
		m.sailors[tag] = sailors(tag) - men
	else:
		m.manpower[tag] = manpower(tag) - men


## Pools a country has never had (a new campaign, an older save without
## sailors) start full.
func _fill_pools() -> void:
	var all := pools()
	for tag: String in all:
		if not m.manpower.has(tag):
			m.manpower[tag] = float(int(all[tag].manpower))
		if not m.sailors.has(tag):
			m.sailors[tag] = float(int(all[tag].sailors))


func _refill_pools() -> void:
	var all := pools()
	for tag: String in world.countries:
		var o: Dictionary = all.get(tag, {})
		m.manpower[tag] = _grow(manpower(tag), o.get("manpower", 0.0), o.get("manpower_growth", 0.0))
		m.sailors[tag] = _grow(sailors(tag), o.get("sailors", 0.0), o.get("sailors_growth", 0.0))
	var today := clock.day_number()
	for id: int in m.pressed.keys():
		if today - int(m.pressed[id]) >= PRESS_EVERY_DAYS:
			m.pressed.erase(id)


## A pool's next month: up towards its ceiling, or (over it) some way down.
static func _grow(now: float, top: float, growth: float) -> float:
	if now > top:
		return EconomySystem.decimal(now - (now - top) * POOL_EXCESS_LOSS, 1.0)
	return EconomySystem.decimal(minf(now + growth, top), 1.0)


# --- Ideas ------------------------------------------------------------------------------

## What taking up an idea costs `tag`: Ideas.ADOPT_MONTHS of its taxes (at
## least Ideas.ADOPT_MIN), with inflation.
func idea_cost(tag: String) -> float:
	var c := world.get_country(tag)
	return EconomySystem.decimal(maxf(Ideas.ADOPT_MIN, economy.budget(tag).tax_income * Ideas.ADOPT_MONTHS)
		* (1.0 + c.inflation / 100.0))


func _has_dock(tag: String) -> bool:
	for p: Province in world.ownable_provinces():
		if p.owner_id == tag and "dock" in p.buildings:
			return true
	return false


func idea_blocked(tag: String, id: String) -> String:
	var c := world.get_country(tag)
	if c == null:
		return "No such country"
	return Ideas.blocked(c, id, clock.year, _has_dock(tag), idea_cost(tag))


func adopt_idea(tag: String, id: String) -> bool:
	if idea_blocked(tag, id) != "":
		return false
	_adopt(world.get_country(tag), id, idea_cost(tag))
	return true


func _adopt(c: Country, id: String, cost: float) -> void:
	economy.post(c, "Taking up %s" % Ideas.name_of(id), -cost)
	c.ideas.append(id)
	m.changed.emit()


## AI realms take up an idea when they have room and the money (IDEA_RESERVE
## times its cost and AI_IDEA_SPARE more): seafaring ones (a dock and a navy)
## press gangs and naval academies first, the others drill grounds; any of them
## conscription in its age.
const AI_IDEA_RESERVE := 1.5
const AI_IDEA_SPARE := 50.0
## AI realms at war press men while a pool is under this share of its ceiling.
const AI_PRESS_BELOW := 0.25


func ai_yearly_ideas(player: String) -> void:
	var year := clock.year
	var docked := {}
	for p: Province in world.ownable_provinces():
		if "dock" in p.buildings and p.owner_id != "":
			docked[p.owner_id] = true
	var navies := {}
	for a: Army in m.armies.values():
		if a.navy:
			navies[a.owner] = true
	# Priced first, all from one budget pass: each idea taken up changes the
	# budgets, and pricing after it would work them all out again.
	var costs := {}
	for tag: String in world.countries:
		var c := world.get_country(tag)
		if tag != player and c.ideas.size() < Ideas.slots(year) and c.capital_province_id != 0:
			costs[tag] = idea_cost(tag)
	for tag: String in costs:
		var c := world.get_country(tag)
		var cost: float = costs[tag]
		if c.treasury < cost * AI_IDEA_RESERVE + AI_IDEA_SPARE:
			continue
		var seafaring: bool = docked.has(tag) and navies.has(tag)
		var order := ["conscription"] + (["press_gangs", "naval_academies", "drill_grounds"] if seafaring
			else ["drill_grounds", "press_gangs", "naval_academies"])
		for id: String in order:
			if Ideas.blocked(c, id, year, docked.has(tag), cost) == "":
				_adopt(c, id, cost)
				break


## AI armies (and fleets in port) at war press men at home while their pool
## runs low.
func ai_monthly_press(player: String) -> void:
	var all := {}
	for a: Army in m.armies.values():
		if a.owner == player or not Ideas.has(world.get_country(a.owner), "press_gangs") or not m.in_any_war(a.owner):
			continue
		if all.is_empty():
			all = pools()
		var o: Dictionary = all.get(a.owner, {})
		var low: bool = sailors(a.owner) < o.get("sailors", 0.0) * AI_PRESS_BELOW if a.navy \
			else manpower(a.owner) < o.get("manpower", 0.0) * AI_PRESS_BELOW
		if low and press_blocked(a) == "":
			press_men(a)


# --- Press gangs ------------------------------------------------------------------------

## Men press gangs would seize where they stand: PRESS_SHARE of its commoners.
static func press_count(p: Province) -> int:
	return int(p.pops.get("commoners", 0) * PRESS_SHARE)


## Why an army (or fleet) cannot press men where it stands ("" if it can):
## the idea, our own province (a fleet: its dock), once a year.
func press_blocked(a: Army) -> String:
	if not Ideas.has(world.get_country(a.owner), "press_gangs"):
		return "Needs the idea Press gangs"
	if a.aboard != 0:
		return "Not from aboard ship"
	var p := world.get_province(a.location)
	if p.is_sea:
		return "Only in port, at a dock of ours"
	if p.owner_id != a.owner or p.controller_id != a.owner:
		return "Only in our own provinces"
	if m.pressed.has(p.id):
		var wait := int(m.pressed[p.id]) + PRESS_EVERY_DAYS - clock.day_number()
		if wait > 0:
			return "Its people were pressed lately: again in %d days" % wait
	if press_count(p) < PRESS_MIN:
		return "Too few common people here"
	return ""


## Press gangs seize PRESS_SHARE of the province's commoners for the army (a
## fleet's: for the navy): they leave the land, and unrest rises. The men taken.
func press_men(a: Army) -> int:
	if press_blocked(a) != "":
		return 0
	var p := world.get_province(a.location)
	var n := press_count(p)
	p.add_people("commoners", -n)
	p.unrest = minf(p.unrest + PRESS_UNREST, WorldState.MAX_UNREST)
	_draw(a.owner, "sailors" if a.navy else "manpower", -n)
	m.pressed[p.id] = clock.day_number()
	economy.touch(p)
	m.changed.emit()
	return n


## Armies on friendly ground and fleets in port fill their ranks (paid for,
## and from manpower) and recover spirit, up to what their maintenance allows;
## elsewhere (fleets at sea) spirit comes back slowly; levies are not replaced.
func _reinforce() -> void:
	var costs := {}
	var owners_at := {}  # (location, navy) -> owners there: enemies nearby are looked up, not searched for
	for a: Army in m.armies.values():
		var key := a.location * 2 + (1 if a.navy else 0)
		if not owners_at.has(key):
			owners_at[key] = {}
		owners_at[key][a.side()] = true
	for a: Army in m.armies.values():
		var c := world.get_country(a.owner)
		if c == null:
			continue
		var p := world.get_province(a.location)
		var friendly := not p.is_sea and a.aboard == 0 and p.controller_id != "" and _friendly(a.side(), p.controller_id)
		var top: float = Policies.max_morale(c.spending.navy if a.navy else c.spending.army)
		a.morale = minf(top, a.morale + (MORALE_RECOVERY if friendly else MORALE_RECOVERY * 0.25))
		if not friendly:
			continue
		var others: Dictionary = owners_at[a.location * 2 + (1 if a.navy else 0)]
		if others.size() > 1 and others.keys().any(func(o: String) -> bool: return o != a.side() and m.at_war(a.side(), o)):
			continue
		var which := "sailors" if a.navy else "manpower"
		for r: Array in a.regiments:
			var u := UnitTypes.get_type(r[0])
			if r[0] == "levy" or r[1] >= u.men:
				continue
			var add := mini(mini(u.men - r[1], int(u.men * REINFORCE_SHARE)), int(_pool_men(a.owner, which)))
			if add <= 0:
				continue
			_draw(a.owner, which, add)
			r[1] += add
			costs[a.owner] = costs.get(a.owner, 0.0) + u.cost * REINFORCE_COST * add / float(u.men)
	for tag: String in costs:
		var c := world.get_country(tag)
		economy.post(c, REINFORCEMENTS, -costs[tag] * (1.0 + c.inflation / 100.0))


# --- Levies and regiments ---------------------------------------------------------------

func _recount_levies() -> void:
	for id: int in m.recount_levies(world):
		economy.touch(world.get_province(id))


## Men a province would give as levies.
static func levy_men(p: Province) -> int:
	return int((p.pops.get("commoners", 0) + p.pops.get("tribesmen", 0)) * LEVY_SHARE)


## Why `tag` cannot call its levies now ("" if it can).
func levies_blocked(tag: String) -> String:
	if m.levies_raised.has(tag):
		return "Our levies are already under arms"
	if not m.in_any_war(tag):
		return "Levies are called only in war"
	return ""


## The realm's levy regions: its most populous province musters the provinces
## within MUSTER_KM, then the most populous left, and so on — over all the land
## it owns at home (overseas land raises no levies), held or not, so the
## regions stay put. Each: {muster: province id,
## name, ids: [province ids], ready: men that can be called now (held, not
## already called), out: men under arms}.
func levy_districts(tag: String) -> Array:
	var pending: Array[Province] = []
	for p: Province in world.ownable_provinces():
		if p.owner_id == tag and levy_men(p) >= MIN_LEVY_REGIMENT and not world.overseas.has(p.id):
			pending.append(p)
	pending.sort_custom(func(x: Province, y: Province) -> bool:
		return x.population > y.population or (x.population == y.population and x.id < y.id))
	var out := []
	while not pending.is_empty():
		var muster: Province = pending[0]
		var ids: Array[int] = []
		var rest: Array[Province] = []
		var ready := 0
		var under_arms := 0
		for p: Province in pending:
			if DiplomacyActions._haversine(p.lat, p.lon, muster.lat, muster.lon) <= MUSTER_KM:
				ids.append(p.id)
				under_arms += p.levied
				if p.controller_id == tag and p.levied == 0:
					ready += levy_men(p)
			else:
				rest.append(p)
		pending = rest
		out.append({"muster": muster.id, "name": muster.name, "ids": ids, "ready": ready, "out": under_arms})
	return out


func _district(tag: String, muster_id: int) -> Dictionary:
	for d: Dictionary in levy_districts(tag):
		if d.muster == muster_id:
			return d
	return {}


## Calls a region's levies: each held province not already called gives its
## men, mustering at the region's town (or, if that is lost, the first of its
## provinces we hold); one army per stack limit. Returns men raised.
func _raise_district(tag: String, d: Dictionary) -> int:
	var regiments: Array = []
	var raised := 0
	var at: Province = null
	for id: int in d.ids:
		var p := world.get_province(id)
		if p.controller_id != tag or p.levied > 0:
			continue
		if at == null:
			at = p
		var men := levy_men(p)
		while men >= MIN_LEVY_REGIMENT:
			var n := mini(men, 1000)
			regiments.append(["levy", n, p.id])
			men -= n
			raised += n
	if regiments.is_empty():
		return 0
	var muster := world.get_province(d.muster)
	if muster.controller_id == tag:
		at = muster
	var per_army := UnitTypes.MAX_STACK / 1000
	for start in range(0, regiments.size(), per_army):
		m.add_army(tag, at.id, regiments.slice(start, start + per_army), false, "Levies of %s" % d.name)
	return raised


## Why a region's levies cannot be called now ("" if they can).
func district_blocked(tag: String, muster_id: int) -> String:
	if not m.in_any_war(tag):
		return "Levies are called only in war"
	var d := _district(tag, muster_id)
	if d.is_empty():
		return "No such region"
	if d.ready < MIN_LEVY_REGIMENT:
		return "Already under arms" if d.out > 0 else "No one left to call (occupied, or too few people)"
	return ""


## Why no levies can be called at all now ("" if some region can).
func mobilise_blocked(tag: String) -> String:
	if not m.in_any_war(tag):
		return "Levies are called only in war"
	for d: Dictionary in levy_districts(tag):
		if d.ready >= MIN_LEVY_REGIMENT:
			return ""
	return "Every region's levies are under arms"


## Calls one region's levies. Returns men raised.
func raise_district(tag: String, muster_id: int) -> int:
	if district_blocked(tag, muster_id) != "":
		return 0
	var raised := _raise_district(tag, _district(tag, muster_id))
	if raised > 0:
		m.levies_raised[tag] = true
		_recount_levies()
		m.changed.emit()
	return raised


## Calls the levies of every region not yet called (in war only). Returns men
## raised.
func raise_levies(tag: String) -> int:
	if not m.in_any_war(tag):
		return 0
	var raised := 0
	for d: Dictionary in levy_districts(tag):
		raised += _raise_district(tag, d)
	m.levies_raised[tag] = true
	_recount_levies()
	m.changed.emit()
	return raised


## Sends one region's levies home.
func disband_district(tag: String, muster_id: int) -> void:
	var d := _district(tag, muster_id)
	if d.is_empty():
		return
	var home := {}
	for id: int in d.ids:
		home[id] = true
	var any_left := false
	for a: Army in m.armies_of(tag):
		a.regiments = a.regiments.filter(func(r: Array) -> bool: return not (r[0] == "levy" and home.has(r[2])))
		if a.regiments.is_empty():
			m.remove_army(a.id)
		elif a.has_levies():
			any_left = true
	if not any_left:
		m.levies_raised.erase(tag)
	_recount_levies()
	m.changed.emit()


## Sends the levies home: their regiments leave every army.
func disband_levies(tag: String) -> void:
	for a: Army in m.armies_of(tag):
		a.regiments = a.regiments.filter(func(r: Array) -> bool: return r[0] != "levy")
		if a.regiments.is_empty():
			m.remove_army(a.id)
	m.levies_raised.erase(tag)
	_recount_levies()
	m.changed.emit()


## Why `tag` cannot raise a unit of `type` in a province ("" if it can).
func recruit_blocked(tag: String, p: Province, type: String) -> String:
	var c := world.get_country(tag)
	if c == null or p.owner_id != tag or p.controller_id != tag:
		return "Not under our control"
	var u := UnitTypes.get_type(type)
	if not UnitTypes.available(type, clock.year, UnitTypes.groups_of(world, tag), tag):
		return "Not raised by us in this age"
	if u.domain == "air":
		return "Air power arrives with the age of flight"
	if u.domain == "sea" and not "dock" in p.buildings:
		return "Ships are built at a dock"
	var cost := recruit_cost(tag, type)
	if c.treasury < cost:
		return "Needs %d ducats" % int(ceil(cost))
	if _pool_men(tag, pool_of(type)) < u.men:
		return "Needs %s %s" % [DrawerPanel.thousands(u.men), pool_of(type)]
	return ""


func recruit_cost(tag: String, type: String) -> float:
	return EconomySystem.decimal(UnitTypes.get_type(type).cost * (1.0 + world.get_country(tag).inflation / 100.0))


## Pays for a regiment (or ship); it joins our forces there when trained.
func recruit(tag: String, p: Province, type: String) -> bool:
	if recruit_blocked(tag, p, type) != "":
		return false
	economy.post(world.get_country(tag), RECRUITMENT % UnitTypes.name_of(type), -recruit_cost(tag, type))
	_draw(tag, pool_of(type), UnitTypes.get_type(type).men)
	m.recruiting.append([tag, p.id, type, int(UnitTypes.get_type(type).months) * 30])
	return true


func _recruitment_day() -> void:
	var left: Array = []
	for job: Array in m.recruiting:
		job[3] -= 1
		if job[3] > 0:
			left.append(job)
			continue
		var tag: String = job[0]
		var p := world.get_province(job[1])
		if world.get_country(tag) == null or p.owner_id != tag:
			continue  # the province was lost: the recruits scatter
		var u := UnitTypes.get_type(job[2])
		var navy: bool = u.domain == "sea"
		var place: int = p.id  # ships are launched into the dock
		var joined := false
		for a: Army in m.armies_at(place, navy):
			if a.owner == tag and not a.is_moving() and a.men() + u.men <= UnitTypes.MAX_STACK:
				a.regiments.append([job[2], u.men, 0])
				joined = true
				break
		if not joined:
			var c := world.get_country(tag)
			m.add_army(tag, place, [[job[2], u.men, 0]], navy, ("%s Fleet" % c.adjective) if navy else "Army of %s" % p.name)
		regiment_raised.emit(p.id, tag, job[2])
		m.changed.emit()
	m.recruiting = left


# --- Organising armies -----------------------------------------------------------------

## Why these armies cannot be merged ("" if they can).
func merge_blocked(armies: Array) -> String:
	if armies.size() < 2:
		return "Select two or more armies"
	var first: Army = armies[0]
	var men := 0
	for a: Army in armies:
		if a.owner != first.owner:
			return "Only our own armies"
		if a.aboard != 0:
			return "Not while aboard ship"
		if a.retreating:
			return "Not while falling back"
		if a.navy != first.navy:
			return "Fleets and armies stay apart"
		if a.location != first.location:
			return "They must stand in the same place"
		men += a.men()
	if men > UnitTypes.MAX_STACK:
		return "At most %s men in one army" % DrawerPanel.thousands(UnitTypes.MAX_STACK)
	return ""


## Merges into the first army (spirit averaged by men); returns its id.
func merge(armies: Array) -> int:
	if merge_blocked(armies) != "":
		return 0
	var into: Army = armies[0]
	var men := float(into.men())
	var spirit := into.morale * men
	for a: Army in armies.slice(1):
		spirit += a.morale * a.men()
		men += a.men()
		into.regiments.append_array(a.regiments)
		for cargo: Army in m.cargo_of(a.id):
			cargo.aboard = into.id  # the troops change ships with the fleet
		m.remove_army(a.id)
	into.morale = spirit / maxf(men, 1.0)
	into.path.clear()
	m.changed.emit()
	return into.id


## Why an army cannot be split or disbanded now ("" if it can).
func split_blocked(army: Army) -> String:
	if army.regiments.size() < 2:
		return "Only one regiment"
	return disband_blocked(army)


func disband_blocked(army: Army) -> String:
	if army.retreating:
		return "Falling back"
	if army.aboard != 0:
		return "Land it first"
	if army.navy and not m.cargo_of(army.id).is_empty():
		return "Land the troops aboard first"
	return ""


## Splits off half the regiments as a new army in the same place; returns it.
func split(army: Army) -> Army:
	if split_blocked(army) != "":
		return null
	var half := army.regiments.size() / 2
	var moved := army.regiments.slice(half)
	army.regiments = army.regiments.slice(0, half)
	var other := m.add_army(army.owner, army.location, moved, army.navy, army.name + " (detached)")
	other.morale = army.morale
	m.changed.emit()
	return other


func disband(army: Army) -> void:
	if disband_blocked(army) != "":
		return
	m.remove_army(army.id)
	_recount_levies()
	m.changed.emit()


# --- War and peace ---------------------------------------------------------------------

## Why `attacker` cannot declare war on `defender` now ("" if it can).
func war_blocked(attacker: String, defender: String) -> String:
	var d := world.diplomacy
	if attacker == defender or world.get_country(defender) == null:
		return "Not possible"
	if d.overlord_of(attacker) != "":
		return "Subjects cannot declare war"
	if m.at_war(attacker, defender):
		return "Already at war"
	if d.is_allied(attacker, defender):
		return "We are allies (break the alliance first)"
	if d.overlord_of(defender) == attacker:
		return "They are our subject"
	var truce := m.truce_left(attacker, defender, clock.day_number())
	if truce > 0:
		return "Truce for %d more months" % ceili(truce / 30.0)
	if world.get_country(defender).capital_province_id == 0 and world.country_stats(defender).provinces == 0:
		return "They hold no land"
	return ""


## Who would fight: {attackers, defenders, refused}. The defender's overlord
## leads its defence; loyal subjects follow their overlords, disloyal ones
## stay out (`refused`: their land is open to the enemy, and attacking it
## brings them in); the defender's allies come to its aid; the attacker's
## allies, if it calls them (`call_allies`), join when they think well of the
## cause.
func war_sides(attacker: String, defender: String, call_allies := true) -> Dictionary:
	var d := world.diplomacy
	var lead := d.overlord_of(defender) if d.overlord_of(defender) != "" else defender
	var attackers: Array = [attacker]
	var defenders: Array = [lead]
	var refused: Array = []
	if lead != defender:
		defenders.append(defender)
	for s: String in d.subjects_of(attacker):
		if not s in defenders:
			if actions.is_loyal(s):
				attackers.append(s)
			else:
				refused.append(s)
	for s: String in d.subjects_of(lead):
		if not s in defenders and not s in attackers:
			if actions.is_loyal(s):
				defenders.append(s)
			elif not s in refused:
				refused.append(s)
	for ally: String in d.allies_of(lead):
		if not ally in attackers and not ally in defenders and not d.is_allied(ally, attacker) \
				and d.overlord_of(ally) == "":
			defenders.append(ally)
	for ally: String in d.allies_of(attacker) if call_allies else []:
		if not ally in attackers and not ally in defenders and not d.is_allied(ally, lead) \
				and d.overlord_of(ally) == "" and d.opinion(ally, attacker) >= 50:
			attackers.append(ally)
	return {"attackers": attackers, "defenders": defenders, "refused": refused}


static func short_name(world: WorldState, tag: String) -> String:
	var c := world.get_country(tag)
	if c == null:
		return tag
	for prefix in ["Kingdom of ", "Tsardom of ", "Duchy of ", "Grand Duchy of ", "Empire of ", "Sultanate of ",
			"Republic of ", "Principality of ", "Khanate of ", "Emirate of "]:
		if c.name.begins_with(prefix):
			return c.name.trim_prefix(prefix)
	return c.name


## Declares war. Nobody's levies are called by it: each country (the AI in its
## planning, the player in the Military tab) decides to mobilise.
func declare_war(attacker: String, defender: String, _player := "", call_allies := true) -> Dictionary:
	if war_blocked(attacker, defender) != "":
		return {}
	var sides := war_sides(attacker, defender, call_allies)
	var war := {"id": m.next_war, "name": "%s–%s War" % [short_name(world, attacker), short_name(world, defender)],
		"attackers": sides.attackers, "defenders": sides.defenders, "start": clock.day_number(), "battle_score": 0.0,
		"refused": sides.refused, "civil": is_civil_war(attacker, defender), "annexed": [0.0, 0.0], "tick": 0.0}
	war["rebels"] = Military.rebels_of(world, attacker, defender) if war.civil else ""
	if war.civil:
		war.name = "%s Civil War" % world.get_country(attacker).adjective
	m.next_war += 1
	m.add_war(war)
	world.diplomacy.add_modifier(defender, attacker, "war", -60.0)
	m.wars_changed.emit()
	economy.changed()
	war_declared.emit(war)
	return war


## The war's score for the attackers (-100..100): battles, and the share of
## each side's development the other holds (capitals count double).
## Each war's land in one pass over the provinces: war id -> {dev: [the
## development of each side's land], lost: [what each side has lost, capitals
## double], held: [[the other side's provinces each side holds]]}. Pass it to
## war_score, held_by and the treaty functions when weighing many wars.
func war_stats() -> Dictionary:
	var out := {}
	for w: Dictionary in m.wars:
		out[w.id] = {"dev": [0.0, 0.0], "lost": [0.0, 0.0], "held": [[], []]}
	var index := m.war_index()
	var war_sides: Dictionary = index[0]
	var tag_wars: Dictionary = index[1]
	for p: Province in world.ownable_provinces():
		if not tag_wars.has(p.owner_id):
			continue
		for id: int in tag_wars[p.owner_id]:
			var sides: Dictionary = war_sides[id]
			var s: int = sides[p.owner_id]
			var st: Dictionary = out[id]
			st.dev[s] += p.development
			var held: int = sides.get(p.controller_id, -1)
			if held >= 0 and held != s:
				var c := world.get_country(p.owner_id)
				st.lost[s] += p.development * (2.0 if c.capital_province_id == p.id else 1.0)
				st.held[held].append(p)
	return out


func _stats_of(war: Dictionary, stats: Dictionary) -> Dictionary:
	return stats[war.id] if stats.has(war.id) else war_stats().get(war.id, {"dev": [0.0, 0.0], "lost": [0.0, 0.0], "held": [[], []]})


func war_score(war: Dictionary, stats := {}) -> float:
	if war.get("civil", false):
		return civil_score(war)
	var st := _stats_of(war, stats)
	var dev: Array = st.dev
	var lost: Array = st.lost
	var occupation: float = (lost[1] / maxf(dev[1], 1.0) - lost[0] / maxf(dev[0], 1.0)) * 100.0
	return clampf(occupation * OCCUPATION_WEIGHT + war.battle_score, -100.0, 100.0)


## Provinces of one side held by the other: [province] that `side` holds.
func held_by(war: Dictionary, side: int, stats := {}) -> Array[Province]:
	var out: Array[Province] = []
	out.assign(_stats_of(war, stats).held[side])
	return out


# --- Peace treaties ---------------------------------------------------------------

## A treaty is what a participant in a war (`from`) puts to one on the other
## side (`with`; by default that side's leader). Between the two leaders it
## ends the war; otherwise it is a separate peace, and whichever of the two is
## not a leader leaves the war (with the subjects that followed it in). Its
## terms, all optional:
## * provinces: land of theirs (their side's, between leaders) to take — what
##   our side holds goes to its holder, the rest to `from`;
## * give: land of ours (our side's) to cede — to whichever of theirs holds it,
##   else to them;
## * money: ducats they pay (negative: ducats we pay them); forts: provinces of
##   theirs whose forts come down;
## * subjugate: they become our vassal; release / transfer: subjects of theirs
##   set free, or made ours; break: countries they must break alliance with.
## Each demand costs war score: land what holding it earns (its share of their
## development; capitals double; land we do not hold double again; halved for
## our cores, less for our claims), money by their year of taxes, forts,
## vassals and alliances by fixed or weighted points (vassalage by their might
## against ours, up to half off for holding their land). Land we give is worth its
## share of ours, money we pay them by their year of taxes. They sign when our
## score and what we give cover what we ask (asking nothing, unless they are
## clearly winning).
const TREATY_BASE := 5.0
const MONEY_PER_YEAR_OF_TAXES := 25.0
const FORT_COST := 4.0
const UNHELD_LAND := 2.0
const CORE_DISCOUNT := 0.5
const CLAIM_DISCOUNT := 0.75
const SUBJUGATE_BASE := 40.0
const SUBJUGATE_PER_STRENGTH := 60.0  # × their might against ours
const RELEASE_BASE := 10.0
const RELEASE_PER_STRENGTH := 30.0  # × the subject's might against its overlord's
const TRANSFER_FACTOR := 1.5
const BREAK_ALLIANCE_COST := 8.0
## An AI country (not leading its side) that has lost this share of its land
## makes a separate peace, ceding what the enemy holds.
const SEPARATE_PEACE_LOSS := 0.5

const _TERM_LISTS := ["provinces", "give", "forts", "release", "transfer", "break"]


func _other_leader(war: Dictionary, from: String) -> String:
	return war.defenders[0] if Military.side_of(war, from) == 0 else war.attackers[0]


func is_war_leader(war: Dictionary, tag: String) -> bool:
	return not war.is_empty() and (tag == war.attackers[0] or tag == war.defenders[0])


## Who a treaty is with: its `with`, else the other side's leader.
func treaty_with(war: Dictionary, from: String, treaty: Dictionary) -> String:
	var to: String = treaty.get("with", "")
	return to if to != "" else _other_leader(war, from)


## Both leaders: the treaty ends the war.
func is_full_peace(war: Dictionary, from: String, to: String) -> bool:
	return is_war_leader(war, from) and is_war_leader(war, to)


## Who a treaty may touch: in a full peace a whole side, else the party alone.
func _in_scope(war: Dictionary, tag: String, party: String, full: bool) -> bool:
	if full:
		return tag != "" and Military.side_of(war, tag) == Military.side_of(war, party)
	return tag == party


## War score `from` holds (positive when its side is winning).
func score_for(war: Dictionary, from: String, stats := {}) -> float:
	return war_score(war, stats) * (1.0 if Military.side_of(war, from) == 0 else -1.0)


## War score `from` holds against `to`: the war's own between the leaders; in
## a separate peace, how much of each other's land each side holds (theirs
## against ours) and the battles.
func peace_score(war: Dictionary, from: String, to: String, stats := {}) -> float:
	if is_full_peace(war, from, to):
		return score_for(war, from, stats)
	var lost := _land_lost(war, [from, to])
	var battles: float = war.battle_score * (1.0 if Military.side_of(war, from) == 0 else -1.0)
	return clampf((lost[to] - lost[from]) * 100.0 * OCCUPATION_WEIGHT + battles, -100.0, 100.0)


## The share of each country's own land the other side holds (capitals double).
func _land_lost(war: Dictionary, tags: Array) -> Dictionary:
	var dev := {}
	var lost := {}
	for t: String in tags:
		dev[t] = 0.0
		lost[t] = 0.0
	for p: Province in world.ownable_provinces():
		if not dev.has(p.owner_id):
			continue
		dev[p.owner_id] += p.development
		var held := Military.side_of(war, p.controller_id)
		if held >= 0 and held != Military.side_of(war, p.owner_id):
			var capital := world.get_country(p.owner_id).capital_province_id == p.id
			lost[p.owner_id] += p.development * (2.0 if capital else 1.0)
	var out := {}
	for t: String in tags:
		out[t] = lost[t] / maxf(dev[t], 1.0)
	return out


## The development a treaty's land is weighed against: a side's in a full
## peace, else the party's own.
func scope_development(war: Dictionary, party: String, full: bool, stats: Dictionary) -> float:
	if full:
		return _stats_of(war, stats).dev[Military.side_of(war, party)]
	var total := 0.0
	for p: Province in world.ownable_provinces():
		if p.owner_id == party:
			total += p.development
	return total


## Who gets a province `from` demands: the holder on our side, else `from`.
func _receiver(war: Dictionary, from: String, p: Province) -> String:
	var ours := Military.side_of(war, from)
	if p.controller_id != p.owner_id and Military.side_of(war, p.controller_id) == ours:
		return p.controller_id
	return from


## War score a demanded province costs (`their_dev`: what it is weighed against).
func province_cost(war: Dictionary, from: String, p: Province, their_dev: float) -> float:
	var capital := world.get_country(p.owner_id).capital_province_id == p.id
	var cost := p.development / maxf(their_dev, 1.0) * 100.0 * OCCUPATION_WEIGHT * (2.0 if capital else 1.0)
	if Military.side_of(war, p.controller_id) != Military.side_of(war, from):
		cost *= UNHELD_LAND
	var receiver := _receiver(war, from, p)
	if world.claims.is_core(receiver, p.id):
		cost *= CORE_DISCOUNT
	elif world.claims.has_claim(receiver, p.id):
		cost *= CLAIM_DISCOUNT
	return cost


## War score `from`'s demands cost (land, money, forts, vassals, alliances).
func treaty_cost(war: Dictionary, from: String, treaty: Dictionary, stats := {}) -> float:
	var to := treaty_with(war, from, treaty)
	var full := is_full_peace(war, from, to)
	var cost := 0.0
	var provinces: Array = treaty.get("provinces", [])
	if not provinces.is_empty():
		var their_dev := scope_development(war, to, full, stats)
		for id: int in provinces:
			cost += province_cost(war, from, world.get_province(id), their_dev)
	if int(treaty.get("money", 0)) > 0:
		cost += float(treaty.money) / _year_of_taxes(to) * MONEY_PER_YEAR_OF_TAXES
	for id: int in treaty.get("forts", []):
		var p := world.get_province(id)
		cost += FORT_COST * (2.0 if world.get_country(p.owner_id).capital_province_id == p.id else 1.0)
	if treaty.get("subjugate", false):
		# Cheaper the more of their own land we hold (up to half off).
		var held: float = minf(_land_lost(war, [to])[to], 1.0)
		cost += (SUBJUGATE_BASE + SUBJUGATE_PER_STRENGTH * clampf(actions.strength(to) / actions.strength(from), 0.0, 1.0)) 			* (1.0 - 0.5 * held)
	for s: String in treaty.get("release", []):
		cost += RELEASE_BASE + RELEASE_PER_STRENGTH * clampf(actions.strength(s) / actions.strength(to), 0.0, 1.0)
	for s: String in treaty.get("transfer", []):
		cost += (RELEASE_BASE + RELEASE_PER_STRENGTH * clampf(actions.strength(s) / actions.strength(to), 0.0, 1.0)) \
			* TRANSFER_FACTOR
	cost += BREAK_ALLIANCE_COST * treaty.get("break", []).size()
	if cost > 0.0:
		cost += TREATY_BASE
	return minf(cost, 100.0)


## What the land and money `from` gives are worth to them, in war score.
func treaty_value(war: Dictionary, from: String, treaty: Dictionary, stats := {}) -> float:
	var give: Array = treaty.get("give", [])
	var paid := -int(treaty.get("money", 0))
	if give.is_empty() and paid <= 0:
		return 0.0
	var to := treaty_with(war, from, treaty)
	var value := 0.0
	if paid > 0:
		value += float(paid) / _year_of_taxes(to) * MONEY_PER_YEAR_OF_TAXES
	if give.is_empty():
		return value
	var our_dev := scope_development(war, from, is_full_peace(war, from, to), stats)
	for id: int in give:
		var p := world.get_province(id)
		var capital := world.get_country(p.owner_id).capital_province_id == p.id
		value += p.development / maxf(our_dev, 1.0) * 100.0 * OCCUPATION_WEIGHT * (2.0 if capital else 1.0)
	return value


## A year of a country's taxes (at least 60 ducats): what reparations are weighed by.
func _year_of_taxes(tag: String) -> float:
	return maxf(economy.budget(tag).tax_income * 12.0, 60.0)


static func _empty_treaty(treaty: Dictionary) -> bool:
	for key: String in _TERM_LISTS:
		if not treaty.get(key, []).is_empty():
			return false
	return int(treaty.get("money", 0)) == 0 and not treaty.get("subjugate", false)


## Why `from` cannot put this treaty ("" if it can).
func treaty_blocked(war: Dictionary, from: String, treaty: Dictionary) -> String:
	if war.is_empty():
		return "No such war"
	var side := Military.side_of(war, from)
	if side < 0:
		return "We are not in this war"
	if war.get("civil", false) and is_full_peace(war, from, treaty_with(war, from, treaty)):
		for key: String in _TERM_LISTS:
			if not treaty.get(key, []).is_empty():
				return "In a civil war no land changes hands at the peace: grant or press the rebels' demands"
		if int(treaty.get("money", 0)) != 0 or treaty.get("subjugate", false):
			return "In a civil war the peace is the rebels' demands, granted or not"
		for id: String in treaty.get("granted", []):
			if not id in rebel_demands(war):
				return "Not one of their demands"
	var to := treaty_with(war, from, treaty)
	if Military.side_of(war, to) != 1 - side:
		return "%s is not our enemy in this war" % _name(to)
	if not is_war_leader(war, from) and not is_war_leader(war, to):
		return "Only with %s, who leads their side" % _name(_other_leader(war, from))
	var full := is_full_peace(war, from, to)
	var d := world.diplomacy
	for id: int in treaty.get("provinces", []):
		var p := world.get_province(id)
		if p == null or not _in_scope(war, p.owner_id, to, full):
			return "We can only take %s land" % ("their side's" if full else _name(to) + "'s")
	for id: int in treaty.get("give", []):
		var p := world.get_province(id)
		if p == null or not _in_scope(war, p.owner_id, from, full):
			return "We can only give %s land" % ("our side's" if full else "our own")
		if id in treaty.get("provinces", []):
			return "Not both taken and given"
	var payer := world.get_country(to)
	if int(treaty.get("money", 0)) > int(maxf(payer.treasury, 0.0)):
		return "They have only %d ducats" % int(maxf(payer.treasury, 0.0))
	var us := world.get_country(from)
	if -int(treaty.get("money", 0)) > int(maxf(us.treasury, 0.0)):
		return "We have only %d ducats" % int(maxf(us.treasury, 0.0))
	for id: int in treaty.get("forts", []):
		var p := world.get_province(id)
		if p == null or not "fort" in p.buildings or not _in_scope(war, p.owner_id, to, full):
			return "Only their forts can be pulled down"
	if treaty.get("subjugate", false):
		if d.overlord_of(from) != "":
			return "A subject cannot take vassals"
		if d.overlord_of(to) != "":
			return "They are already %s's subject" % _name(d.overlord_of(to))
		if actions.strength(to) >= actions.strength(from):
			return "They are too strong to become our vassal"
	for s: String in treaty.get("release", []) + treaty.get("transfer", []):
		if d.overlord_of(s) != to:
			return "%s is not their subject" % _name(s)
	for s: String in treaty.get("transfer", []):
		if s in treaty.get("release", []):
			return "Not both released and taken"
		if d.overlord_of(from) != "":
			return "A subject cannot take vassals"
	for t: String in treaty.get("break", []):
		if t == from or not d.is_allied(to, t):
			return "They are not allied with %s" % _name(t)
	return ""


func _name(tag: String) -> String:
	var c := world.get_country(tag)
	return c.name if c else tag


## Whether they sign: our score and what we give cover what we ask; a white
## peace unless they are clearly winning. (A civil war: see civil_accepted.)
func treaty_accepted(war: Dictionary, from: String, treaty: Dictionary, stats := {}) -> bool:
	if treaty_blocked(war, from, treaty) != "":
		return false
	if war.get("civil", false) and is_full_peace(war, from, treaty_with(war, from, treaty)):
		return civil_accepted(war, from, treaty.get("granted", []))
	var score := peace_score(war, from, treaty_with(war, from, treaty), stats)
	if _empty_treaty(treaty):
		return score >= -10.0
	var cost := treaty_cost(war, from, treaty, stats)
	# Asking nothing (only giving), as a white peace.
	return score + treaty_value(war, from, treaty, stats) >= (cost if cost > 0.0 else -10.0)


## The treaty in words.
func describe_treaty(war: Dictionary, from: String, treaty: Dictionary) -> String:
	var to := treaty_with(war, from, treaty)
	if war.get("civil", false) and is_full_peace(war, from, to):
		var granted: Array = treaty.get("granted", [])
		var parts: Array[String] = []
		for id: String in granted:
			parts.append(REBEL_DEMANDS[id].name)
		var rebels: String = war.get("rebels", "")
		return ("%s lays down arms" % _name(rebels)) + (": " + "; ".join(parts) if not parts.is_empty()
			else ", its demands refused")
	var parts: Array[String] = []
	var land: Array[String] = []
	for id: int in treaty.get("provinces", []):
		var p := world.get_province(id)
		var receiver := _receiver(war, from, p)
		# Land an ally holds goes to that ally.
		land.append(p.name if receiver == from else "%s (to %s)" % [p.name, short_name(world, receiver)])
	if not land.is_empty():
		parts.append("%s takes %s" % [_name(from), ", ".join(land)])
	var given: Array[String] = []
	for id: int in treaty.get("give", []):
		given.append(world.get_province(id).name)
	if not given.is_empty():
		parts.append("%s cedes %s" % [_name(from), ", ".join(given)])
	if int(treaty.get("money", 0)) > 0:
		parts.append("%s pays %d ducats" % [_name(to), int(treaty.money)])
	elif int(treaty.get("money", 0)) < 0:
		parts.append("%s pays %d ducats" % [_name(from), -int(treaty.money)])
	var forts: Array[String] = []
	for id: int in treaty.get("forts", []):
		forts.append(world.get_province(id).name)
	if not forts.is_empty():
		parts.append("forts pulled down at %s" % ", ".join(forts))
	if treaty.get("subjugate", false):
		parts.append("%s becomes %s's vassal" % [_name(to), short_name(world, from)])
	for s: String in treaty.get("release", []):
		parts.append("%s is set free" % _name(s))
	for s: String in treaty.get("transfer", []):
		parts.append("%s passes to %s" % [_name(s), short_name(world, from)])
	for t: String in treaty.get("break", []):
		parts.append("%s breaks its alliance with %s" % [short_name(world, to), short_name(world, t)])
	var text := "; ".join(parts) if not parts.is_empty() else "White peace: every province back to its owner"
	if not is_full_peace(war, from, to):
		var leaver := to if is_war_leader(war, from) else from
		text += "; %s leaves the war" % _name(leaver)
	return text


## The simple peaces as treaties with the other side's leader: "white",
## "demand" (the land our side holds) and "surrender" (we give up the land of
## ours their side holds).
func treaty_for(war: Dictionary, from: String, terms: String, stats := {}) -> Dictionary:
	var side := Military.side_of(war, from)
	var ids: Array[int] = []
	match terms:
		"demand":
			for p: Province in held_by(war, side, stats):
				ids.append(p.id)
		"surrender":
			for p: Province in held_by(war, 1 - side, stats):
				ids.append(p.id)
			return {"provinces": [], "give": ids, "money": 0, "forts": []}
	return {"provinces": ids, "money": 0, "forts": []}


## Surrender to `to`: we give up the land of ours (our side's, if both lead)
## that their side holds.
func surrender_treaty(war: Dictionary, from: String, to: String) -> Dictionary:
	var full := is_full_peace(war, from, to)
	if war.get("civil", false) and full:
		# The crown gives the rebels all they ask; rebels submit, asking nothing.
		return {"with": to, "granted": rebel_demands(war) if from == civil_parties(war)[0] else []}
	var ids: Array[int] = []
	for p: Province in held_by(war, 1 - Military.side_of(war, from)):
		if _in_scope(war, p.owner_id, from, full):
			ids.append(p.id)
	return {"with": to, "give": ids}


## Whether the other side's leader accepts `from`'s terms (the simple peaces).
func peace_accepted(war: Dictionary, from: String, terms: String) -> bool:
	if terms == "surrender":
		return true
	return treaty_accepted(war, from, treaty_for(war, from, terms))


func peace_blocked(war: Dictionary, from: String, terms: String) -> String:
	if war.is_empty():
		return "No such war"
	if not is_war_leader(war, from):
		return "%s leads our side" % _name(war.attackers[0] if Military.side_of(war, from) == 0 else war.defenders[0])
	if terms == "demand" and held_by(war, Military.side_of(war, from)).is_empty():
		return "We hold none of their land"
	return ""


## Ends a war on one of the simple terms (white, demand, surrender).
func make_peace(war: Dictionary, from: String, terms: String, _player := "") -> String:
	return conclude(war, from, treaty_for(war, from, terms))


## Signs a treaty `from` put: land changes hands, reparations are paid, forts
## come down, vassals and alliances change. Between the leaders the war ends:
## every other occupation ends, truces follow, levies go home and armies leave
## land now closed to them. Otherwise the one leaving makes its own peace (see
## _leave).
func conclude(war: Dictionary, from: String, treaty: Dictionary) -> String:
	var to := treaty_with(war, from, treaty)
	var full := is_full_peace(war, from, to)
	if war.get("civil", false) and full:
		return _settle_civil_war(war, treaty.get("granted", []))
	var summary := describe_treaty(war, from, treaty)
	war["signed"] = [from, to]  # who made this peace (a separate one leaves them out of the war)
	var d := world.diplomacy
	for id: int in treaty.get("provinces", []):
		var p := world.get_province(id)
		world.transfer_province(p.id, _receiver(war, from, p), true)
	for id: int in treaty.get("give", []):
		var p := world.get_province(id)
		var holder := p.controller_id
		var receiver := holder if holder != p.owner_id and Military.side_of(war, holder) == Military.side_of(war, to) else to
		world.transfer_province(p.id, receiver, true)
	var amount := int(treaty.get("money", 0))
	if amount != 0:
		# Positive: they pay us reparations; negative: we pay for the peace.
		var payer := world.get_country(to if amount > 0 else from)
		var payee := world.get_country(from if amount > 0 else to)
		var what := "War reparations" if amount > 0 else "Paid for peace"
		amount = mini(absi(amount), int(maxf(payer.treasury, 0.0)))
		economy.post(payer, "%s to %s" % [what, payee.name], -amount)
		economy.post(payee, "%s from %s" % [what, payer.name], amount)
	var razed := false
	for id: int in treaty.get("forts", []):
		var p := world.get_province(id)
		if "fort" in p.buildings:
			p.buildings.erase("fort")
			economy.touch(p)
			razed = true
	for s: String in treaty.get("release", []):
		d.release_subject(s)
	for s: String in treaty.get("transfer", []):
		d.set_subject(from, s, d.subject_type(s))
	if treaty.get("subjugate", false):
		for s: String in d.subjects_of(to):
			d.release_subject(s)  # a vassal keeps no vassals of its own
		d.set_subject(from, to, "vassal")
	for t: String in treaty.get("break", []):
		d.set_allied(to, t, false)
	if full:
		_end_war(war)
	else:
		_leave(war, to if is_war_leader(war, from) else from)
	if razed:
		forts_changed.emit()
	m.wars_changed.emit()
	m.changed.emit()
	economy.changed()
	peace_made.emit(war, summary)
	return summary


## The war is over: occupations between its sides end, truces follow, levies
## go home and armies leave land now closed to them.
func _end_war(war: Dictionary) -> void:
	for p: Province in world.ownable_provinces():
		var so := Military.side_of(war, p.owner_id)
		var sc := Military.side_of(war, p.controller_id)
		if so >= 0 and sc >= 0 and so != sc:
			world.set_controller(p.id, p.owner_id)
			m.sieges.erase(p.id)
		elif so >= 0 and m.sieges.has(p.id) and Military.side_of(war, m.sieges[p.id].by) == 1 - so:
			m.sieges.erase(p.id)
	var today := clock.day_number()
	for a: String in war.attackers:
		for d: String in war.defenders:
			m.set_truce(a, d, today + Military.TRUCE_DAYS)
	m.remove_war(war)
	for tag: String in war.attackers + war.defenders:
		if not m.in_any_war(tag):
			if m.levies_raised.has(tag):
				disband_levies(tag)
			_send_home(tag)
	_check_volunteers()


## A separate peace: `leaver` (and the subjects that followed it in) leaves
## the war. Occupations between them and the other side end, truces follow,
## levies go home and armies leave land now closed to them.
func _leave(war: Dictionary, leaver: String) -> void:
	var side := Military.side_of(war, leaver)
	var group: Array = [leaver]
	for s: String in world.diplomacy.subjects_of(leaver):
		if Military.side_of(war, s) == side and not is_war_leader(war, s):
			group.append(s)
	var others: Array = (war.defenders if side == 0 else war.attackers).duplicate()
	for p: Province in world.ownable_provinces():
		var ours := p.owner_id in group
		var theirs := Military.side_of(war, p.owner_id) == 1 - side
		var held_by_them := Military.side_of(war, p.controller_id) == 1 - side
		var held_by_us := p.controller_id in group
		if (ours and held_by_them) or (theirs and held_by_us):
			world.set_controller(p.id, p.owner_id)
			m.sieges.erase(p.id)
		elif m.sieges.has(p.id) and ((ours and m.sieges[p.id].by in others) or (theirs and m.sieges[p.id].by in group)):
			m.sieges.erase(p.id)
	var today := clock.day_number()
	for t: String in group:
		for o: String in others:
			m.set_truce(t, o, today + Military.TRUCE_DAYS)
		m.leave_war(war, t)
	for tag: String in group + others:
		if not m.in_any_war(tag):
			if m.levies_raised.has(tag):
				disband_levies(tag)
		_send_home(tag)
	_check_volunteers()


## Armies standing where they may no longer be go home to the capital.
func _send_home(tag: String) -> void:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id) if c else null
	for a: Army in m.armies_of(tag):
		if a.aboard == 0 and not can_enter(tag, world.get_province(a.location)):
			a.path.clear()
			a.retreating = false
			if cap != null:
				a.location = cap.id


# --- The AI -----------------------------------------------------------------------------

## A rough measure of a country's might: its armies and the levies it could
## call (`population`: the country's, if already known).
func power(tag: String, population := -1) -> float:
	var total := 0.0
	for a: Army in m.armies_of(tag):
		total += a.power()
	if not m.levies_raised.has(tag):
		var people: int = population if population >= 0 else world.country_stats(tag).population
		total += people * LEVY_SHARE * 0.55
	return total


## Daily, a seventh of the armies each day (so no day carries the whole
## war): AI countries at war decide to call their levies, gather idle armies
## standing together (weekly), and march on the nearest enemy-held land they
## can take (or free their own), avoiding hosts much stronger than
## themselves. Route searches are rationed per day; an army that finds no
## target waits a few weeks before looking again.
func ai_daily(player: String) -> void:
	var today := clock.day_number()
	if today % 7 == 0:
		for w: Dictionary in m.wars:
			for tag: String in w.attackers + w.defenders:
				if tag != player and levies_blocked(tag) == "":
					raise_levies(tag)  # the AI's own decision to mobilise
		_ai_merge(player)
	var searches := 0
	var nodes := 0
	for a: Army in m.armies.values():
		if searches >= AI_SEARCHES_PER_DAY or nodes >= AI_NODES_PER_DAY:
			break
		if a.id % 7 != today % 7 or a.navy or a.owner == player or a.is_moving() or a.aboard != 0 or a.men() < MIN_SIEGE_MEN:
			continue
		if _plan_after.get(a.id, -1) > today or not m.in_any_war(a.side()) or not _enemies_at(a).is_empty():
			continue
		if m.sieges.has(a.location) and m.at_war(a.side(), world.get_province(a.location).controller_id):
			continue  # keep at the siege
		var options: Array = []
		for w: Dictionary in m.wars_of(a.side()):  # volunteers campaign for their host
			options.append_array(_side_targets(w, Military.side_of(w, a.side()), today))
		var marched := false
		var searched := false
		var start := "%s:%d" % [a.side(), a.location]
		var blocked: Dictionary = _unreachable.get(start, {})
		for p: Province in _nearest(world.get_province(a.location), options, AI_TARGETS, blocked, today):
			var defenders: Array = m.armies_at(p.id).filter(func(x: Army) -> bool: return m.at_war(a.side(), x.side()))
			if not defenders.is_empty() and estimate([a], defenders, p.id).chance < 0.45:
				continue
			searches += 1
			searched = true
			last_search_nodes = 0
			var why := order_move(a, p.id, AI_SEARCH_LIMIT)
			nodes += last_search_nodes
			if why == "":
				marched = true
			else:
				blocked[p.id] = today + AI_UNREACHABLE_DAYS  # next time, the next target
				_unreachable[start] = blocked
			break  # one search per army a day
		if not marched and not searched:
			_plan_after[a.id] = today + AI_REST_DAYS  # nothing worth a march: rest
	if today % 120 == 0:
		_unreachable = {}  # every road worth another look


## A side's targets: every war's worked out together, at most once a week
## (and when a war has begun since).
func _side_targets(war: Dictionary, side: int, today: int) -> Array:
	if today - _targets_day >= AI_TARGETS_DAYS or not _targets.has(war.id):
		_targets = _all_war_targets()
		_targets_day = today
	return _targets[war.id][side] if _targets.has(war.id) else []


## Every war's targets in one pass: war id -> [attackers' targets, defenders'].
## A province is a target of the side that does not hold it (when its owner
## fights in that war): the enemy's own land, or ours they occupy.
func _all_war_targets() -> Dictionary:
	var out := {}
	for w: Dictionary in m.wars:
		out[w.id] = [[], []]
	var index := m.war_index()
	var war_sides: Dictionary = index[0]
	var tag_wars: Dictionary = index[1]
	for p: Province in world.ownable_provinces():
		if not tag_wars.has(p.controller_id):
			continue
		for id: int in tag_wars[p.controller_id]:
			var sides: Dictionary = war_sides[id]
			if sides.has(p.owner_id):
				out[id][1 - int(sides[p.controller_id])].append(p)
	return out


## The `count` provinces nearest `here` (each distance worked out once),
## leaving out those `skip` holds until after `today`.
static func _nearest(here: Province, options: Array, count: int, skip := {}, today := 0) -> Array[Province]:
	var best: Array = []  # [km, province], nearest first
	for p: Province in options:
		if not skip.is_empty() and skip.get(p.id, -1) > today:
			continue
		var km := DiplomacyActions._haversine(p.lat, p.lon, here.lat, here.lon)
		if best.size() < count or km < best[best.size() - 1][0]:
			var i := best.size()
			while i > 0 and best[i - 1][0] > km:
				i -= 1
			best.insert(i, [km, p])
			if best.size() > count:
				best.pop_back()
	var out: Array[Province] = []
	for e: Array in best:
		out.append(e[1])
	return out


func _ai_merge(player: String) -> void:
	var groups := {}
	for a: Army in m.armies.values():
		if a.owner == player or a.is_moving() or a.aboard != 0:
			continue
		var key := "%s:%d:%s" % [a.owner, a.location, a.navy]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(a)
	for key: String in groups:
		var list: Array = groups[key]
		while list.size() >= 2:
			if merge_blocked(list) == "":
				merge(list)
				break
			list.pop_back()  # too many men together: leave the smallest apart


## Monthly: AI war leaders make peace — demanding the land they hold (and
## reparations with the score to spare) when clearly winning, surrendering what
## the enemy holds when crushed, a white peace after years of stalemate; AI
## countries not leading their side make a separate peace, ceding what the
## enemy holds, once they have lost SEPARATE_PEACE_LOSS of their land. Offers
## to the player arrive as peace_offered (at most every half year per war and
## country).
func ai_monthly_peace(player: String) -> void:
	var today := clock.day_number()
	var stats := war_stats()
	for w: Dictionary in m.wars.duplicate():
		if w.get("civil", false):
			_ai_civil_peace(w, player, today)
			continue
		var score := war_score(w, stats)
		var years := (today - int(w.start)) / 365.0
		var ended := false
		for side in [0, 1]:
			var lead: String = w.attackers[0] if side == 0 else w.defenders[0]
			if lead == player:
				continue
			var mine := score if side == 0 else -score
			var other: String = w.defenders[0] if side == 0 else w.attackers[0]
			var treaty := {}
			var surrender := false
			if mine >= PEACE_DEMAND and not held_by(w, side, stats).is_empty():
				treaty = treaty_for(w, lead, "demand", stats)
				# Reparations with whatever score is left (up to half their treasury).
				var spare := mine - treaty_cost(w, lead, treaty, stats)
				var payer := world.get_country(other)
				if spare > 0.0 and payer.treasury > 0.0:
					treaty.money = int(clampf(spare / MONEY_PER_YEAR_OF_TAXES * _year_of_taxes(other), 0.0, payer.treasury * 0.5) / 10) * 10
			elif mine <= -80.0:
				surrender = true  # we give up what they hold
				treaty = treaty_for(w, lead, "surrender", stats)
			elif years >= WHITE_PEACE_YEARS and absf(score) < 25.0:
				treaty = {"provinces": [], "money": 0, "forts": []}
			else:
				continue
			if other == player:
				if _may_offer(w, lead, today):
					peace_offered.emit(w, treaty, lead)
				break
			if surrender or treaty_accepted(w, lead, treaty, stats):
				conclude(w, lead, treaty)
				stats = war_stats()  # land changed hands
				ended = true
				break
		if not ended:
			_ai_separate_peaces(w, player, today)


## AI countries that do not lead their side (nor follow an overlord into the
## war) and have lost SEPARATE_PEACE_LOSS of their land cede what the enemy
## holds and leave.
func _ai_separate_peaces(w: Dictionary, player: String, today: int) -> void:
	var tags: Array = []
	for t: String in w.attackers + w.defenders:
		if t != player and not is_war_leader(w, t) and world.diplomacy.overlord_of(t) == "":
			tags.append(t)
	if tags.is_empty():
		return
	var lost := _land_lost(w, tags)
	for t: String in tags:
		if lost[t] < SEPARATE_PEACE_LOSS or Military.side_of(w, t) < 0:
			continue
		var to := _other_leader(w, t)
		var treaty := surrender_treaty(w, t, to)
		if to == player:
			if _may_offer(w, t, today):
				peace_offered.emit(w, treaty, t)
			continue
		conclude(w, t, treaty)


## At most one offer to the player every OFFER_EVERY_DAYS per war and country.
func _may_offer(w: Dictionary, tag: String, today: int) -> bool:
	var key := "offered:" + tag
	if today - int(w.get(key, -OFFER_EVERY_DAYS)) < OFFER_EVERY_DAYS:
		return false
	w[key] = today
	return true


## Yearly: an AI country now and then turns on a neighbouring rival, or a
## neighbour holding its cores or claims, that it far outmatches (counting
## both sides' allies' help at half).
func ai_yearly_wars(player: String) -> void:
	var d := world.diplomacy
	var people := {}  # one pass for every country's people (power counts its levies)
	for p: Province in world.ownable_provinces():
		if p.owner_id != "":
			people[p.owner_id] = people.get(p.owner_id, 0) + p.population
	var grudges := Claims.grudges(world, world.claims)
	for c: Country in world.countries.values():
		if c.id == player or d.overlord_of(c.id) != "" or m.in_any_war(c.id):
			continue
		var targets: Array = d.rivals_of(c.id).duplicate()
		for owner: String in grudges.get(c.id, {}):
			if not owner in targets:
				targets.append(owner)
		for rival: String in targets:
			if not people.has(rival) or not actions.are_neighbours(c.id, rival) or war_blocked(c.id, rival) != "":
				continue
			var sides := war_sides(c.id, rival)
			var ours := 0.0
			var theirs := 0.0
			for t: String in sides.attackers:
				ours += power(t, people.get(t, 0)) * (1.0 if t == c.id else 0.5)
			for t: String in sides.defenders:
				theirs += power(t, people.get(t, 0)) * (1.0 if t == rival else 0.5)
			var bold: Array = AI_AGGRESSION.get(c.id, [1.0, AI_WAR_ODDS])
			if ours >= theirs * bold[1] and rng.chance(minf(AI_WAR_CHANCE * bold[0], 1.0)):
				declare_war(c.id, rival, player)
				break


# --- A small binary heap for A* ------------------------------------------------------

class _Heap:
	var keys := PackedFloat64Array()
	var items := PackedInt32Array()

	func is_empty() -> bool:
		return items.is_empty()

	func push(item: int, key: float) -> void:
		keys.append(key)
		items.append(item)
		var i := items.size() - 1
		while i > 0:
			var parent := (i - 1) / 2
			if keys[parent] <= keys[i]:
				break
			_swap(i, parent)
			i = parent

	func pop() -> int:
		var top := items[0]
		var last := items.size() - 1
		_swap(0, last)
		keys.resize(last)
		items.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var smallest := i
			if l < last and keys[l] < keys[smallest]:
				smallest = l
			if r < last and keys[r] < keys[smallest]:
				smallest = r
			if smallest == i:
				break
			_swap(i, smallest)
			i = smallest
		return top

	func _swap(a: int, b: int) -> void:
		var k := keys[a]
		keys[a] = keys[b]
		keys[b] = k
		var t := items[a]
		items[a] = items[b]
		items[b] = t
