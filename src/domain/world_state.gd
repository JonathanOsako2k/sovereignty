class_name WorldState
extends RefCounted
## Authoritative campaign world: provinces, countries and map metadata.
## Views read from it and listen to its signals; they never write to it directly.

signal province_owner_changed(province_id: int, old_owner: String, new_owner: String)
signal province_controller_changed(province_id: int, old_controller: String, new_controller: String)
signal player_changed(tag: String)
## The whole campaign state was replaced (a save was loaded or a new campaign
## began): views should rebuild everything that depends on it.
signal campaign_restored
## A country was founded (a colonial nation): names and capitals redraw.
signal countries_changed

## Province campaign fields in the order a saved province row stores them
## (pops: counts in Estates.ROLES order; population is their sum).
const PROVINCE_FIELDS := ["owner", "controller", "population", "development", "unrest", "resource",
	"buildings", "construction", "found", "pops", "colonist", "colony_progress"]
const MAX_POPULATION := 1_000_000_000
const MAX_DEVELOPMENT := 100
const MAX_UNREST := 100.0
const MIN_STABILITY := -3
const MAX_STABILITY := 3
const MAX_LEGITIMACY := 100.0

var data_version := 0
## MD5 of the province-id map: two worlds with the same version but a
## different fingerprint number their provinces differently (saves must not
## mix them). Other static data (names, terrain) may change freely.
var data_fingerprint := ""
## Fingerprints of earlier drawings of this same map (provinces neither
## renumbered nor renamed, only redrawn): saves made with them still load.
var compatible_fingerprints: Array = []
var map_size := Vector2i.ZERO
var id_texture_path := ""
var height_texture_path := ""
## Region id -> {name, quota} from the world data.
var regions: Dictionary = {}
## Map projection (Mercator): {lon_west, lat_north, lat_south}.
var projection: Dictionary = {}
var player_country_id := ""
var start_date := {"year": 1590, "month": 1, "day": 1}

var provinces: Dictionary = {}  # int -> Province
var countries: Dictionary = {}  # String -> Country
## Subjects, alliances, marriages, rivalries and opinion between countries.
var diplomacy := Diplomacy.new()
var military := Military.new()
## Cores and claims: which countries count a province as rightfully theirs.
var claims := Claims.new()
## Sorted country tags; a country's index here is stable for the session and is
## used by the map shader to tell country borders apart.
var country_order: Array[String] = []
## Countries founded during the campaign (colonial nations), in order: not in
## the world data, so saved with the campaign (`created`) and dropped when a
## campaign without them is restored.
var created: Array[String] = []
## Province id -> true for overseas provinces (Overseas.update keeps it).
var overseas := {}
var _ownable: Array[Province] = []
var _ownable_count := -1


func get_province(province_id: int) -> Province:
	return provinces.get(province_id)


func get_country(tag: String) -> Country:
	return countries.get(tag)


## Provinces that can be owned (everything except wastelands and sea tiles).
## Every province that can be owned, in id order. Built once (wastelands and
## sea tiles never change); callers must not change the array.
func ownable_provinces() -> Array[Province]:
	if _ownable.is_empty() or _ownable_count != provinces.size():
		_ownable = []
		var ids: Array = provinces.keys()
		ids.sort()
		for id: int in ids:
			var p: Province = provinces[id]
			if not p.is_wasteland and not p.is_sea:
				_ownable.append(p)
		_ownable_count = provinces.size()
	return _ownable


func sea_tiles() -> Array[Province]:
	var result: Array[Province] = []
	for p: Province in provinces.values():
		if p.is_sea:
			result.append(p)
	return result


## Map-space position (pixels of the province-ID map) of a latitude/longitude.
func latlon_to_map(lat: float, lon: float) -> Vector2:
	var lon_west: float = projection.get("lon_west", -180.0)
	var merc := func(deg: float) -> float: return log(tan(PI * 0.25 + deg_to_rad(clampf(deg, -85.0, 85.0)) * 0.5))
	var top: float = merc.call(projection.get("lat_north", 85.0))
	var bottom: float = merc.call(projection.get("lat_south", -85.0))
	var x := fposmod(lon - lon_west, 360.0) / 360.0 * map_size.x
	var y: float = (top - merc.call(lat)) / (top - bottom) * map_size.y
	return Vector2(x, y)


func region_name(region_id: String) -> String:
	return regions.get(region_id, {}).get("name", region_id)


## The ownable province whose recorded position is nearest to a latitude/longitude
## (or any tile, including wastelands and seas, with include_unownable).
func province_near(lat: float, lon: float, include_unownable := false) -> Province:
	var best: Province = null
	var best_d := INF
	for p: Province in provinces.values():
		if (p.is_wasteland or p.is_sea) and not include_unownable:
			continue
		var dlon := absf(p.lon - lon)
		dlon = minf(dlon, 360.0 - dlon) * cos(deg_to_rad(lat))
		var d := (p.lat - lat) * (p.lat - lat) + dlon * dlon
		if d < best_d:
			best_d = d
			best = p
	return best


func country_index(tag: String) -> int:
	return country_order.find(tag)


## The map's mark for a country's land (1..253; it wraps beyond 253 countries,
## so two such neighbours would share a border colour). 0 for none.
func country_marker(tag: String) -> int:
	var i := country_index(tag)
	return 0 if i < 0 else i % 253 + 1


## Founds a new country (a colonial nation): a fresh tag ("C01", "C02"…),
## landless until provinces are handed to it.
func create_country(name: String, adjective: String, color: Color, government: String, tag := "") -> Country:
	if tag == "":
		var n := 1
		while countries.has("C%02d" % n):
			n += 1
		tag = "C%02d" % n
	var c := Country.new()
	c.id = tag
	c.name = name
	c.adjective = adjective
	c.color = color
	c.government_type = government
	countries[tag] = c
	country_order.append(tag)
	created.append(tag)
	countries_changed.emit()
	return c


## The countries a campaign state knows: the world data's, and those it founded.
func known_tags(state: Variant) -> Dictionary:
	var out := {}
	for tag: String in country_order:
		if not tag in created:
			out[tag] = true
	if state is Dictionary and state.get("created") is Array:
		for row: Variant in state.created:
			if row is Array and not row.is_empty() and row[0] is String:
				out[row[0]] = true
	return out


func owned_province_ids(tag: String) -> Array[int]:
	var result: Array[int] = []
	for p: Province in provinces.values():
		if p.owner_id == tag:
			result.append(p.id)
	result.sort()
	return result


func total_population(tag: String) -> int:
	var total := 0
	for p: Province in provinces.values():
		if p.owner_id == tag:
			total += p.population
	return total


## Totals for a country in one pass: provinces owned, population, development,
## area, own provinces controlled by someone else (occupied) and foreign
## provinces it controls (occupying).
func country_stats(tag: String) -> Dictionary:
	var stats := {"provinces": 0, "population": 0, "development": 0, "area_km2": 0, "occupied": 0, "occupying": 0}
	for p: Province in provinces.values():
		if p.is_wasteland or p.is_sea:
			continue
		if p.owner_id == tag:
			stats.provinces += 1
			stats.population += p.population
			stats.development += p.development
			stats.area_km2 += p.area_km2
			if p.controller_id != tag:
				stats.occupied += 1
		elif p.controller_id == tag:
			stats.occupying += 1
	return stats


## A tax rate (percent) for every estate, none above its maximum.
static func _tax_rates_ok(taxes: Variant) -> bool:
	if not (taxes is Array and taxes.size() == Estates.ROLES.size()):
		return false
	for i in taxes.size():
		var x: Variant = taxes[i]
		if not (x is float or x is int) or x < 0 or x > Estates.TAX_MAX[Estates.ROLES[i]]:
			return false
	return true


## How a province's people divide by role at the start of a campaign.
func initial_pops(p: Province) -> Dictionary:
	var owner := get_country(p.owner_id)
	var nomadic := p.climate in ["cold_arid", "hot_arid"] and p.vegetation in ["grasslands", "sparse", "desert"]
	var shares := Estates.initial_shares(p.development, owner.government_type if owner else "", owner != null,
		p.is_coastal, owner != null and owner.capital_province_id == p.id, nomadic)
	return Estates.split(p.population, shares)


func are_neighbours(a: int, b: int) -> bool:
	var p := get_province(a)
	return p != null and b in p.neighbour_ids


## The single way to change ownership. Also hands control to the new owner unless
## `keep_controller` is set (e.g. a treaty ceding an occupied province).
func transfer_province(province_id: int, new_owner: String, keep_controller := false) -> bool:
	var p := get_province(province_id)
	if p == null or p.is_wasteland or p.is_sea or (new_owner != "" and not countries.has(new_owner)):
		push_error("transfer_province: invalid province %d or country '%s'" % [province_id, new_owner])
		return false
	if p.owner_id == new_owner:
		return false
	var old_owner := p.owner_id
	p.owner_id = new_owner
	for c: Country in countries.values():
		if c.capital_province_id == province_id and c.id != new_owner:
			c.capital_province_id = 0
	province_owner_changed.emit(province_id, old_owner, new_owner)
	if not keep_controller:
		set_controller(province_id, new_owner)
	return true


func set_controller(province_id: int, controller: String) -> bool:
	var p := get_province(province_id)
	if p == null or p.is_wasteland or p.is_sea or (controller != "" and not countries.has(controller)):
		push_error("set_controller: invalid province %d or country '%s'" % [province_id, controller])
		return false
	if p.controller_id == controller:
		return false
	var old := p.controller_id
	p.controller_id = controller
	province_controller_changed.emit(province_id, old, controller)
	return true


func set_player_country(tag: String) -> bool:
	if not countries.has(tag):
		push_error("set_player_country: unknown country '%s'" % tag)
		return false
	if player_country_id != tag:
		player_country_id = tag
		player_changed.emit(tag)
	return true


# --- Campaign state (saves) ----------------------------------------------------
# Only campaign state is saved; static data (geometry, names, adjacency) comes
# from data/world and must be the same version.

## Everything about the world that can change during a campaign, keyed by stable
## ids. Province rows follow PROVINCE_FIELDS, prefixed with the province id.
func campaign_state() -> Dictionary:
	var country_states := {}
	for tag: String in country_order:
		var c: Country = countries[tag]
		country_states[tag] = {
			"capital": c.capital_province_id,
			"government": c.government_type,
			"treasury": c.treasury,
			"ledger": c.ledger.duplicate(true),
			"loans": c.loans.duplicate(true),
			"policies": {"taxes": c.tax_rates.duplicate(), "colonial": c.colonial_policy, "court": c.spending.court,
				"mint": c.spending.mint, "forts": c.spending.forts, "army": c.spending.army, "navy": c.spending.navy},
			"inflation": c.inflation,
			"satisfaction": c.satisfaction.duplicate(),
			"bankrupt_until": c.bankrupt_until,
			"last_bankruptcy": c.last_bankruptcy,
			"legitimacy": c.legitimacy,
			"stability": c.stability,
		}
	var ids: Array = provinces.keys()
	ids.sort()
	var rows := []
	for id: int in ids:
		var p: Province = provinces[id]
		if p.is_wasteland or p.is_sea:
			continue
		var pops := []
		for r: String in Estates.ROLES:
			pops.append(p.pops.get(r, 0))
		rows.append([p.id, p.owner_id, p.controller_id, p.population, p.development, p.unrest, p.resource,
			p.buildings.duplicate(), p.construction.duplicate(), p.found.duplicate(), pops, p.colonist,
			p.colony_progress])
	var created_rows := []
	for tag: String in created:
		var c: Country = countries[tag]
		created_rows.append([tag, c.name, c.adjective, c.color.to_html(false), c.government_type, c.colonial_region])
	return {
		"player": player_country_id,
		"created": created_rows,
		"countries": country_states,
		"province_fields": PROVINCE_FIELDS.duplicate(),
		"provinces": rows,
	}


## Diagnostics for a campaign state; empty when `restore_campaign_state` will
## accept it. Never modifies the world.
func check_campaign_state(state: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not state is Dictionary:
		errors.append("world state must be an object")
		return errors
	var known := known_tags(state)
	var made: Variant = state.get("created", [])
	if not made is Array:
		errors.append("'created' must be a list")
	else:
		for row: Variant in made:
			if not (row is Array and row.size() == 6 and row.all(func(v: Variant) -> bool: return v is String)
					and row[0] != "" and not (countries.has(row[0]) and not row[0] in created)):
				errors.append("malformed founded country %s" % var_to_str(row).left(80))
	var player: Variant = state.get("player")
	if not (player is String and known.has(player)):
		errors.append("player country %s does not exist" % var_to_str(player))

	var country_states: Variant = state.get("countries")
	if not country_states is Dictionary:
		errors.append("'countries' must be an object")
	else:
		for tag: Variant in country_states:
			if not known.has(tag):
				errors.append("unknown country '%s'" % tag)
				continue
			var s: Variant = country_states[tag]
			if not s is Dictionary:
				errors.append("country %s: state must be an object" % tag)
				continue
			var capital: Variant = s.get("capital")
			_check_number(errors, "country %s capital", tag, capital, 0, 0xFFFF, true)
			if (capital is float or capital is int) and int(capital) != 0:
				var cap := get_province(int(capital))
				if cap == null or cap.is_wasteland or cap.is_sea:
					errors.append("country %s: capital %d is not an ownable province" % [tag, int(capital)])
			if not s.get("government") is String:
				errors.append("country %s: government must be text" % tag)
			_check_number(errors, "country %s treasury", tag, s.get("treasury"), -1e12, 1e12)
			var loans: Variant = s.get("loans")
			if not (loans is Array and loans.all(func(l: Variant) -> bool:
					return l is Array and l.size() == 3 and l.all(func(x: Variant) -> bool: return x is float or x is int))):
				errors.append("country %s: loans must be a list of [amount, rate, day]" % tag)
			var pol: Variant = s.get("policies")
			if not (pol is Dictionary and _tax_rates_ok(pol.get("taxes"))):
				errors.append("country %s: tax rates must be 0 to each estate's maximum" % tag)
			elif not (pol.get("colonial") == null or ((pol.colonial is float or pol.colonial is int)
					and pol.colonial >= 0 and pol.colonial < Colonisation.POLICIES.size())):
				errors.append("country %s: bad colonial policy" % tag)
			else:
				for key: String in Policies.RANGES:
					if not Policies.is_valid(key, pol.get(key)):
						errors.append("country %s: %s must be %d to %d %%" % [tag, key, Policies.RANGES[key][0],
							Policies.RANGES[key][1]])
			_check_number(errors, "country %s inflation", tag, s.get("inflation"), 0.0, 1000.0)
			var sat: Variant = s.get("satisfaction")
			if not (sat is Array and sat.size() == Estates.ROLES.size()):
				errors.append("country %s: satisfaction must list every estate" % tag)
			_check_number(errors, "country %s bankrupt_until", tag, s.get("bankrupt_until"), -1, 1e7, true)
			_check_number(errors, "country %s last_bankruptcy", tag, s.get("last_bankruptcy"), -1, 1e7, true)
			var ledger: Variant = s.get("ledger")
			if not (ledger is Array and ledger.all(func(e: Variant) -> bool:
					return e is Array and e.size() == 2 and e[0] is String and (e[1] is float or e[1] is int))):
				errors.append("country %s: ledger must be a list of [source, amount]" % tag)
			_check_number(errors, "country %s legitimacy", tag, s.get("legitimacy"), 0.0, MAX_LEGITIMACY)
			_check_number(errors, "country %s stability", tag, s.get("stability"), MIN_STABILITY, MAX_STABILITY, true)
		for tag: String in known:
			if not country_states.has(tag):
				errors.append("country %s is missing" % tag)

	var fields: Variant = state.get("province_fields")
	if not (fields is Array and fields == PROVINCE_FIELDS):
		errors.append("province fields %s do not match %s" % [var_to_str(fields), var_to_str(PROVINCE_FIELDS)])
		return errors
	var rows: Variant = state.get("provinces")
	if not rows is Array:
		errors.append("'provinces' must be an array")
		return errors
	var seen := {}
	for row: Variant in rows:
		if not (row is Array and row.size() == PROVINCE_FIELDS.size() + 1 and (row[0] is float or row[0] is int)):
			errors.append("malformed province row %s" % var_to_str(row).left(60))
			continue
		var id := int(row[0])
		var p := get_province(id)
		if p == null:
			errors.append("unknown province id %d" % id)
			continue
		if p.is_wasteland or p.is_sea:
			errors.append("province %d is a wasteland or sea tile and cannot have campaign state" % id)
			continue
		if seen.has(id):
			errors.append("province %d appears twice" % id)
		seen[id] = true
		for k in [1, 2]:
			if not (row[k] is String and (row[k] == "" or known.has(row[k]))):
				errors.append("province %d: unknown %s '%s'" % [id, PROVINCE_FIELDS[k - 1], row[k]])
		_check_number(errors, "province %d population", id, row[3], 0, MAX_POPULATION, true)
		_check_number(errors, "province %d development", id, row[4], 0, MAX_DEVELOPMENT, true)
		_check_number(errors, "province %d unrest", id, row[5], 0.0, MAX_UNREST)
		# null resource / pops (an upgraded older save) mean "as at the start".
		if not (row[6] == null or (row[6] is String and Goods.has(row[6]))):
			errors.append("province %d: unknown good %s" % [id, var_to_str(row[6])])
		if not (row[7] is Array and row[7].all(func(b: Variant) -> bool: return b is String and Buildings.CATALOGUE.has(b))):
			errors.append("province %d: bad buildings %s" % [id, var_to_str(row[7])])
		if not (row[8] is Array and (row[8].is_empty() or (row[8].size() == 2 and row[8][0] is String
				and Buildings.CATALOGUE.has(row[8][0]) and (row[8][1] is float or row[8][1] is int)))):
			errors.append("province %d: bad construction %s" % [id, var_to_str(row[8])])
		if not (row[9] is Array and row[9].all(func(g: Variant) -> bool: return g is String and Goods.has(g))):
			errors.append("province %d: bad discoveries %s" % [id, var_to_str(row[9])])
		if not (row[10] == null or (row[10] is Array and row[10].size() == Estates.ROLES.size()
				and row[10].all(func(n: Variant) -> bool: return (n is float or n is int) and n >= 0))):
			errors.append("province %d: bad pops %s" % [id, var_to_str(row[10])])
		elif row[10] != null and (row[3] is float or row[3] is int) and int(row[10].reduce(func(a, n): return a + n, 0)) != int(row[3]):
			errors.append("province %d: estates add up to %d, not the population %d"
				% [id, int(row[10].reduce(func(a, n): return a + n, 0)), int(row[3])])
		if not (row[11] is String and (row[11] == "" or known.has(row[11]))):
			errors.append("province %d: unknown colonist '%s'" % [id, row[11]])
		elif row[11] != "" and row[1] != "":
			errors.append("province %d: settled by %s but already owned" % [id, row[11]])
		_check_number(errors, "province %d colony progress", id, row[12], 0.0, 100.0)
	for p: Province in provinces.values():
		if not p.is_wasteland and not p.is_sea and not seen.has(p.id):
			errors.append("province %d is missing" % p.id)
			if errors.size() > 50:
				break
	return errors


## The founded countries a state holds: those of the world now are dropped and
## these made again (same tags, so the rest of the state finds them).
func _apply_created(rows: Array) -> void:
	for tag: String in created:
		countries.erase(tag)
		country_order.erase(tag)
	created.clear()
	for row: Array in rows:
		var c := create_country(row[1], row[2], Color.html(row[3]), row[4], row[0])
		c.colonial_region = row[5]


## Replaces the campaign state. All or nothing: returns diagnostics and leaves
## the world untouched if the state is invalid or would leave it inconsistent.
func restore_campaign_state(state: Variant) -> PackedStringArray:
	var errors := check_campaign_state(state)
	if not errors.is_empty():
		return errors
	var previous := campaign_state()
	_apply_campaign_state(state)
	errors = validate()
	if not errors.is_empty():
		_apply_campaign_state(previous)
		return errors
	campaign_restored.emit()
	return errors


func _apply_campaign_state(state: Dictionary) -> void:
	_apply_created(state.get("created", []))
	player_country_id = state.player
	var country_states: Dictionary = state.countries
	for tag: String in country_states:
		var c: Country = countries[tag]
		var s: Dictionary = country_states[tag]
		c.capital_province_id = int(s.capital)
		c.government_type = s.government
		c.treasury = float(s.treasury)
		c.ledger = []
		for e: Array in s.ledger:
			c.ledger.append([e[0], float(e[1])])
		c.loans = []
		for l: Array in s.loans:
			c.loans.append([float(l[0]), float(l[1]), int(l[2])])
		c.tax_rates = []
		for x in s.policies.taxes:
			c.tax_rates.append(int(x))
		var colonial: Variant = s.policies.get("colonial")
		c.colonial_policy = int(colonial) if colonial != null else c.start_colonial_policy
		c.spending = {}
		for key: String in Policies.RANGES:
			c.spending[key] = int(s.policies[key])
		c.inflation = float(s.inflation)
		c.satisfaction = []
		for x in s.satisfaction:
			c.satisfaction.append(float(x))
		c.bankrupt_until = int(s.bankrupt_until)
		c.last_bankruptcy = int(s.last_bankruptcy)
		c.legitimacy = float(s.legitimacy)
		c.stability = int(s.stability)
	for row: Array in state.provinces:
		var p: Province = provinces[int(row[0])]
		p.owner_id = row[1]
		p.controller_id = row[2]
		p.population = int(row[3])
		p.development = int(row[4])
		p.unrest = float(row[5])
		p.resource = row[6] if row[6] != null else p.start_resource
		p.buildings = Array(row[7])
		p.construction = [row[8][0], int(row[8][1])] if not row[8].is_empty() else []
		p.found = Array(row[9])
		if row[10] == null:
			p.pops = initial_pops(p)
		else:
			p.pops = {}
			for i in Estates.ROLES.size():
				p.pops[Estates.ROLES[i]] = int(row[10][i])
			p.population = 0
			for r: String in p.pops:
				p.population += p.pops[r]
		p.colonist = row[11]
		p.colony_progress = float(row[12])


## Appends a diagnostic if `value` is not a number in lo..hi (whole if asked).
## The subject (`what_format % what_arg`) is only formatted on failure: this
## runs for every province field of every save.
static func _check_number(errors: PackedStringArray, what_format: String, what_arg: Variant, value: Variant,
		lo: float, hi: float, whole := false) -> void:
	if (value is float or value is int) and float(value) >= lo and float(value) <= hi 			and (not whole or float(value) == floorf(float(value))):
		return
	var what := what_format % what_arg
	if not (value is float or value is int):
		errors.append("%s must be a number, got %s" % [what, var_to_str(value)])
	elif whole and float(value) == float(value) and float(value) != floorf(float(value)):
		errors.append("%s must be a whole number, got %s" % [what, str(value)])
	else:
		errors.append("%s %s is outside %s..%s" % [what, str(value), str(lo), str(hi)])


## Returns human-readable problems; an empty array means the world is consistent.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if map_size.x <= 0 or map_size.y <= 0:
		errors.append("map size is not set")
	for p: Province in provinces.values():
		if p.id <= 0 or p.id > 0xFFFF:
			errors.append("province id %d out of range 1..65535" % p.id)
		for n in p.neighbour_ids:
			var other := get_province(n)
			if other == null:
				errors.append("province %d lists unknown neighbour %d" % [p.id, n])
			elif not (p.id in other.neighbour_ids):
				errors.append("adjacency %d -> %d is not symmetric" % [p.id, n])
		if p.owner_id != "" and not countries.has(p.owner_id):
			errors.append("province %d has unknown owner '%s'" % [p.id, p.owner_id])
		if p.controller_id != "" and not countries.has(p.controller_id):
			errors.append("province %d has unknown controller '%s'" % [p.id, p.controller_id])
		if p.population < 0:
			errors.append("province %d has negative population" % p.id)
		if p.is_wasteland and (p.owner_id != "" or not p.neighbour_ids.is_empty()):
			errors.append("wasteland %d must be unowned and have no neighbours" % p.id)
		if p.is_sea and p.owner_id != "":
			errors.append("sea tile %d cannot be owned" % p.id)
		for s in p.sea_ids:
			var sea := get_province(s)
			if sea == null or not sea.is_sea or not (p.id in sea.coast_ids):
				errors.append("province %d lists sea %d without a matching coast" % [p.id, s])
	for c: Country in countries.values():
		if c.capital_province_id != 0:
			var cap := get_province(c.capital_province_id)
			if cap == null:
				errors.append("country %s has unknown capital %d" % [c.id, c.capital_province_id])
			elif cap.owner_id != c.id:
				errors.append("country %s does not own its capital %d" % [c.id, c.capital_province_id])
	if player_country_id != "" and not countries.has(player_country_id):
		errors.append("player country '%s' does not exist" % player_country_id)
	return errors
