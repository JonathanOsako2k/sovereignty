class_name NationSystem
extends RefCounted
## Forming nations (Formations) and integrating their people's tribal land;
## and a realm's rise in rank (Ranks), crowned at a price.
## A realm of a nation's culture forms it once no other realm of that culture
## stands apart and it holds at least the nation's `min_provinces` of its
## people's land: it takes the nation's name, claims the rest of its people's
## land, and from then on integrates its people's uncolonised land outright —
## an army standing there and INTEGRATE_COST (+ INTEGRATE_PER_DEVELOPMENT) in
## ducats, instead of years of settling. The AI forms when it can and, yearly
## and monthly, integrates the land beside its own while it can pay.

signal formed(tag: String, id: String)
signal integrated(province_id: int, tag: String)
signal rank_raised(tag: String, rank: int)

const INTEGRATE_COST := 15.0
const INTEGRATE_PER_DEVELOPMENT := 5.0
const AI_RESERVE := 50.0
## The AI seeks a higher rank once its land nears what its rank governs in full.
const AI_RISE_AT := 0.9

var campaign: Campaign
var world: WorldState
var economy: EconomySystem


func _init(p_campaign: Campaign, p_economy: EconomySystem) -> void:
	campaign = p_campaign
	world = campaign.world
	economy = p_economy


## Provinces of a culture each country holds: tag -> count.
func _held(culture: String) -> Dictionary:
	var out := {}
	for p: Province in world.ownable_provinces():
		if p.culture == culture and p.owner_id != "":
			out[p.owner_id] = out.get(p.owner_id, 0) + 1
	return out


## Why `tag` cannot form the nation ("" if it can).
func formation_blocked(tag: String, id: String) -> String:
	var f: Dictionary = Formations.CATALOGUE.get(id, {})
	var c := world.get_country(tag)
	if f.is_empty() or c == null:
		return "Unknown nation"
	if id in c.formed:
		return "Already formed"
	if c.culture != f.culture:
		return "Only a %s realm can form it" % Cultures.name_of(f.culture)
	if world.diplomacy.overlord_of(tag) != "" and world.diplomacy.subject_type(tag) != "tributary":
		return "Not while a subject"  # (a tributary may: Nurhaci was the Ming's)
	var held := _held(f.culture)
	for other: String in held:
		var o := world.get_country(other)
		if other != tag and o != null and o.culture == f.culture:
			return "%s still stands apart" % o.name
	if held.get(tag, 0) < int(f.min_provinces):
		return "Needs %d provinces of %s land (we hold %d)" % [f.min_provinces, Cultures.name_of(f.culture), held.get(tag, 0)]
	return ""


func form(tag: String, id: String) -> bool:
	if formation_blocked(tag, id) != "":
		return false
	var c := world.get_country(tag)
	c.formed.append(id)
	Formations.apply_name(c)
	c.rank = maxi(c.rank, int(Formations.CATALOGUE[id].get("rank", c.rank)))  # crowned as it forms
	economy.changed()
	var culture: String = Formations.CATALOGUE[id].culture
	for p: Province in world.ownable_provinces():
		if p.culture == culture and p.owner_id != "" and p.owner_id != tag:
			world.claims.add_claim(tag, p.id)
	world.countries_changed.emit()  # its name on the map
	formed.emit(tag, id)
	return true


## The culture whose tribal land `tag` integrates ("" if it formed no nation).
func integrating_culture(tag: String) -> String:
	var c := world.get_country(tag)
	if c == null:
		return ""
	for id: String in c.formed:
		return Formations.CATALOGUE[id].culture
	return ""


func integrate_cost(tag: String, p: Province) -> float:
	var c := world.get_country(tag)
	return EconomySystem.decimal((INTEGRATE_COST + INTEGRATE_PER_DEVELOPMENT * p.development) * (1.0 + c.inflation / 100.0))


## Why `tag` cannot integrate the province ("" if it can). `a`: the army
## standing there (the AI's integration is reckoned without one).
func integrate_blocked(tag: String, p: Province, a: Army = null) -> String:
	var culture := integrating_culture(tag)
	if culture == "":
		return "Only a formed nation integrates its people's land"
	if a != null and (a.navy or a.aboard != 0 or a.location != p.id):
		return "Needs an army standing there"
	if p == null or p.is_sea or p.is_wasteland or p.owner_id != "":
		return "Only uncolonised land"
	if p.culture != culture:
		return "Not %s land" % Cultures.name_of(culture)
	if p.colonist != "" and p.colonist != tag:
		return "%s is settling it" % world.get_country(p.colonist).name
	if world.get_country(tag).treasury < integrate_cost(tag, p):
		return "Needs %d ducats" % int(ceil(integrate_cost(tag, p)))
	return ""


func integrate(tag: String, p: Province, a: Army = null) -> bool:
	if integrate_blocked(tag, p, a) != "":
		return false
	economy.post(world.get_country(tag), "Integrating %s" % p.name, -integrate_cost(tag, p))
	p.colonist = ""
	p.colony_progress = 0.0
	world.transfer_province(p.id, tag)
	world.claims.add_core(tag, p.id)  # one people
	economy.touch(p)
	integrated.emit(p.id, tag)
	return true


# --- Rank ------------------------------------------------------------------------------

## Ducats to be crowned to the next rank.
func raise_cost(tag: String) -> float:
	var c := world.get_country(tag)
	if c == null or c.rank >= Ranks.EMPIRE:
		return 0.0
	return EconomySystem.decimal(Ranks.RAISE_COST[c.rank + 1] * (1.0 + c.inflation / 100.0))


## Why `tag` cannot rise to the next rank ("" if it can).
func rank_blocked(tag: String) -> String:
	var c := world.get_country(tag)
	if c == null:
		return "Unknown realm"
	if c.rank >= Ranks.EMPIRE:
		return "There is no higher rank"
	var next := c.rank + 1
	var d := world.diplomacy
	if d.subject_type(tag) == "colony" and next > Ranks.COLONY_MAX:
		return "A colony rises no higher"
	var overlord := d.overlord_of(tag)
	if overlord != "" and next >= world.get_country(overlord).rank:
		return "Not to the rank of our overlord, %s" % world.get_country(overlord).name
	var development := economy.development_of(tag)
	if development < Ranks.DEVELOPMENT[next]:
		return "A %s needs %d development (we hold %d)" % [Ranks.name_of(next).to_lower(), Ranks.DEVELOPMENT[next],
			development]
	if c.legitimacy < Ranks.RAISE_LEGITIMACY:
		return "Needs legitimacy %d" % int(Ranks.RAISE_LEGITIMACY)
	if c.treasury < raise_cost(tag):
		return "Needs %d ducats" % int(ceil(raise_cost(tag)))
	return ""


## Crowned a rank higher: the treasury pays, legitimacy rises, and from now on
## the court costs, the realm governs and the envoys go as the rank's.
func raise_rank(tag: String) -> bool:
	if rank_blocked(tag) != "":
		return false
	var c := world.get_country(tag)
	var next := c.rank + 1
	economy.post(c, "Coronation as %s" % Ranks.name_of(next).to_lower(), -raise_cost(tag))
	c.rank = next
	c.legitimacy = minf(c.legitimacy + Ranks.RAISE_LEGITIMACY_GAIN, WorldState.MAX_LEGITIMACY)
	economy.changed()
	rank_raised.emit(tag, next)
	return true


## AI realms form the nations they can, and rise in rank when their land
## outgrows their rank (AI_RISE_AT of what it governs in full), they can pay
## for the crown twice over and they would still be in surplus with the
## dearer court.
func ai_yearly(player: String) -> void:
	for c: Country in world.countries.values():
		if c.id == player or c.culture == "":
			continue
		for id: String in Formations.for_culture(c.culture):
			if formation_blocked(c.id, id) == "":
				form(c.id, id)
	for c: Country in world.countries.values():
		if c.id == player or rank_blocked(c.id) != "" or c.treasury < 2.0 * raise_cost(c.id):
			continue
		if economy.development_of(c.id) < Ranks.governance(c.rank, campaign.clock.year) * AI_RISE_AT:
			continue
		var b := economy.budget(c.id)
		var colony := world.diplomacy.subject_type(c.id) == "colony"
		var dearer := (Ranks.court(c.rank + 1, b.tax_income, c.government_type, colony)
			- Ranks.court(c.rank, b.tax_income, c.government_type, colony)) * Policies.court_cost(c.spending.court)
		if b.net - dearer > 0.0:
			raise_rank(c.id)


## AI nations integrate one province of their people's land beside their own
## a month, while they can pay for it.
func ai_monthly(player: String) -> void:
	for c: Country in world.countries.values():
		var culture := integrating_culture(c.id)
		if c.id == player or culture == "":
			continue
		for p: Province in world.ownable_provinces():
			if p.owner_id != "" or p.culture != culture:
				continue
			var beside := false
			for n: int in p.neighbour_ids:
				var q := world.get_province(n)
				if q != null and q.owner_id == c.id:
					beside = true
					break
			if beside and c.treasury >= integrate_cost(c.id, p) + AI_RESERVE and integrate_blocked(c.id, p) == "":
				integrate(c.id, p)
				break
