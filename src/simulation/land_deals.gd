class_name LandDeals
extends RefCounted
## Buying, selling and trading land: diplomatic offers one country puts to
## another, judged like any proposal — a sum of named reasons the player reads
## before sending it. A deal (from `from` to `to`): {take: provinces of theirs
## we would get, give: provinces of ours they would get, money: ducats we pay
## them (negative: they pay us)}. A purchase gives no land of ours; a sale
## takes none of theirs (they pay us); an exchange both.
##
## They weigh: a reluctance to part with land (or, buying, to spend on it);
## what they get (money, land of ours as worth to them) against what they give
## up (each province worth PRICE_YEARS of what it yields them; in a sale, the
## price against the land's worth to them); land that is hard for them to
## govern (overseas, far from their capital, cut off from their realm,
## restless, not a core of theirs) goes more easily; land that matters to them
## (cores, rich provinces, land near their capital, a large share of the
## realm) less so; land of ours that fits their realm (beside theirs) is
## welcome, land far from it less so; when money changes hands, their finances
## (in want of money they sell, rich they need not; poor, they cannot pay);
## their opinion of us; rivals refuse.

signal concluded(from: String, to: String, deal: Dictionary, message: String)

## A province is worth this many years of what it yields its owner (at least MIN_WORTH).
const PRICE_YEARS := 10.0
const MIN_WORTH := 15.0
const SALE_RELUCTANCE := -40
const TRADE_RELUCTANCE := -15
const PURCHASE_RELUCTANCE := -10  # they, buying land of ours
const FIT_CAP := 20
## What we offer against what they give up: points per whole share of its worth.
const VALUE_POINTS := 50.0
const VALUE_CAP := 60
const HARD_CAP := 40
const IMPORTANCE_CAP := 50
## A sold or traded province's old owner renounces its core there; the new owner
## is liked a little for a fair bargain.
const BARGAIN_OPINION := 10.0

var campaign: Campaign
var world: WorldState
var economy: EconomySystem
var actions: DiplomacyActions


func _init(p_campaign: Campaign, p_economy: EconomySystem, p_actions: DiplomacyActions) -> void:
	campaign = p_campaign
	world = campaign.world
	economy = p_economy
	actions = p_actions


# --- What land is worth --------------------------------------------------------------

## What a province is worth to its owner: PRICE_YEARS of the taxes and customs
## it yields them (far provinces yield less), at least MIN_WORTH.
func worth(p: Province) -> float:
	var yearly := 0.0
	for role: String in economy.province_taxes(p):
		yearly += economy.province_taxes(p)[role]
	yearly = (yearly + economy.production(p).value * Buildings.customs_share(p)) * 12.0
	return maxf(yearly * PRICE_YEARS, MIN_WORTH)


## What a province would be worth to `tag` were it theirs: its yield at their
## reach (far from their capital, less), more if they hold a core or claim there.
func worth_to(p: Province, tag: String) -> float:
	var reach_now := maxf(economy.reach_of(p), 0.01)
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id) if c else null
	var reach_theirs := EconomySystem.REACH_MIN
	if cap != null:
		var km := DiplomacyActions._haversine(p.lat, p.lon, cap.lat, cap.lon)
		reach_theirs = clampf(1.0 - km / EconomySystem.REACH_KM * (1.0 - EconomySystem.REACH_MIN), EconomySystem.REACH_MIN, 1.0)
	var value := worth(p) / reach_now * reach_theirs
	if world.claims.is_core(tag, p.id):
		value *= 1.5
	elif world.claims.has_claim(tag, p.id):
		value *= 1.25
	return maxf(value, MIN_WORTH)


# --- Rules ------------------------------------------------------------------------------

## Why this deal cannot be offered ("" if it can).
func blocked(from: String, to: String, deal: Dictionary) -> String:
	var them := world.get_country(to)
	var us := world.get_country(from)
	if from == to or them == null or us == null:
		return "Not possible"
	if world.military.at_war(from, to):
		return "We are at war: make peace first"
	var take: Array = deal.get("take", [])
	var give: Array = deal.get("give", [])
	if take.is_empty() and give.is_empty():
		return "Choose land on the map"
	var theirs := 0
	for p: Province in world.ownable_provinces():
		if p.owner_id == to:
			theirs += 1
	for id: int in take:
		var p := world.get_province(id)
		if p == null or p.owner_id != to:
			return "%s is not theirs" % (p.name if p else "That land")
		if p.controller_id != to:
			return "%s is occupied" % p.name
		if them.capital_province_id == id:
			return "They will never give up their capital"
	if take.size() >= theirs:
		return "Not all their land"
	for id: int in give:
		var p := world.get_province(id)
		if p == null or p.owner_id != from:
			return "%s is not ours" % (p.name if p else "That land")
		if p.controller_id != from:
			return "%s is occupied" % p.name
		if us.capital_province_id == id:
			return "Not our capital"
	var money := int(deal.get("money", 0))
	if money > 0 and money > int(maxf(us.treasury, 0.0)):
		return "We have only %d ducats" % int(maxf(us.treasury, 0.0))
	if money < 0 and -money > int(maxf(them.treasury, 0.0)):
		return "They have only %d ducats" % int(maxf(them.treasury, 0.0))
	return ""


## How they judge it: {total, accept, reasons: [[reason, points]], worth: what
## they give up, offered: what they get}.
func evaluate(from: String, to: String, deal: Dictionary) -> Dictionary:
	var d := world.diplomacy
	var take: Array = deal.get("take", [])
	var give: Array = deal.get("give", [])
	var money := int(deal.get("money", 0))
	var reasons := []
	if give.is_empty():
		reasons.append(["Reluctance to part with land", SALE_RELUCTANCE])
	elif take.is_empty():
		reasons.append(["Reluctance to spend on land", PURCHASE_RELUCTANCE])
	else:
		reasons.append(["Reluctance to trade land", TRADE_RELUCTANCE])
	# What they give up against what they get.
	var lost := 0.0
	for id: int in take:
		lost += worth(world.get_province(id))
	var land := 0.0
	for id: int in give:
		land += worth_to(world.get_province(id), to)
	var gained := float(money) + land
	# A sale is weighed against the land's worth to them; otherwise against what they give up.
	var base := maxf(lost if not take.is_empty() else land, MIN_WORTH)
	var label := "What we offer against what it is worth to them"
	if take.is_empty():
		label = "What our land is worth to them against the price"
	elif give.is_empty():
		label = "Our price against what it is worth to them"
	reasons.append([label, clampi(int(round(VALUE_POINTS * (gained - lost) / base)), -VALUE_CAP, VALUE_CAP)])
	if not take.is_empty():
		reasons.append(["Hard for them to govern", _hard_to_govern(to, take)])
		reasons.append(["Important to them", -_importance(to, take)])
	if not give.is_empty():
		reasons.append(["How our land fits their realm", _fit(to, give)])
	if money != 0:
		reasons.append(["Their finances", _finances(to, money)])
	reasons.append(["Their opinion of us", clampi(int(round(d.opinion(to, from) * 0.4)), -40, 40)])
	if d.has_rival(to, from):
		reasons.append(["We are their rival", -50])
	if d.overlord_of(to) == from:
		reasons.append(["Our subject", 20])
	elif d.is_allied(to, from):
		reasons.append(["Allies", 10])
	reasons = reasons.filter(func(r: Array) -> bool: return r[1] != 0)
	var total := 0
	for r: Array in reasons:
		total += r[1]
	return {"total": total, "accept": total >= 0, "reasons": reasons, "worth": lost, "offered": gained}


## Points for land being hard for its owner to govern: per province, overseas,
## far from the capital, cut off from the realm, restless, not a core — weighed
## by what each is worth.
func _hard_to_govern(tag: String, ids: Array) -> int:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id)
	var joined := Overseas._joined_to_capital(world, tag) if cap != null else {}
	var total := 0.0
	var weight := 0.0
	for id: int in ids:
		var p := world.get_province(id)
		var w := worth(p)
		var points := 0.0
		if world.overseas.has(id):
			points += 20.0
		if cap != null:
			var km := DiplomacyActions._haversine(p.lat, p.lon, cap.lat, cap.lon)
			points += 15.0 if km > 3000.0 else (8.0 if km > 1500.0 else 0.0)
			if not joined.has(id):
				points += 10.0
		if p.unrest >= 10.0:
			points += 5.0
		if not world.claims.is_core(tag, id):
			points += 10.0
		total += points * w
		weight += w
	return mini(int(round(total / maxf(weight, 1.0))), HARD_CAP)


## Points for how land of ours would fit their realm: beside their own land
## welcome, cut off from it (and in another world region) less so — weighed by
## what each is worth to them.
func _fit(tag: String, ids: Array) -> int:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id)
	var total := 0.0
	var weight := 0.0
	for id: int in ids:
		var p := world.get_province(id)
		var w := worth_to(p, tag)
		var beside := false
		for n: int in p.neighbour_ids:
			if world.get_province(n).owner_id == tag:
				beside = true
				break
		var points := 10.0 if beside else -10.0
		if not beside and cap != null and p.region != cap.region:
			points -= 10.0  # across the sea in another part of the world
		total += points * w
		weight += w
	return clampi(int(round(total / maxf(weight, 1.0))), -FIT_CAP, FIT_CAP)


## Points for land mattering to its owner: cores, rich provinces, land near the
## capital, forts — and the share of the realm asked for.
func _importance(tag: String, ids: Array) -> int:
	var c := world.get_country(tag)
	var cap := world.get_province(c.capital_province_id)
	var realm := 0.0
	for p: Province in world.ownable_provinces():
		if p.owner_id == tag:
			realm += p.development
	var asked := 0.0
	var total := 0.0
	var weight := 0.0
	for id: int in ids:
		var p := world.get_province(id)
		var w := worth(p)
		var points := 0.0
		if world.claims.is_core(tag, id):
			points += 15.0
		if p.development >= 8:
			points += 10.0
		if "fort" in p.buildings:
			points += 5.0
		if cap != null and DiplomacyActions._haversine(p.lat, p.lon, cap.lat, cap.lon) < 300.0:
			points += 20.0  # the heartland
		total += points * w
		weight += w
		asked += p.development
	var share := asked / maxf(realm, 1.0)
	return mini(int(round(total / maxf(weight, 1.0) + 80.0 * share)), IMPORTANCE_CAP)


## Points for their finances when money changes hands: paid, the poorer and the
## deeper in debt the keener (and the richer, the less they need it); paying,
## the poorer the less able.
func _finances(tag: String, money: int) -> int:
	var c := world.get_country(tag)
	var b: Dictionary = economy.budget(tag)
	var monthly: float = maxf(b.tax_income, 1.0)
	var points := 0
	var poor := c.treasury < 0.0 or c.bankrupt_until > campaign.clock.day_number()
	var debt := c.debt
	var net: float = b.get("net", 0.0)
	if money > 0:
		if poor:
			points += 25
		if debt > 0.0:
			points += mini(int(round(debt / (monthly * 12.0) * 15.0)), 20)
		if net < 0.0:
			points += 10
		if c.treasury > monthly * 12.0:
			points -= 10
	else:
		if c.treasury + money < monthly * 2.0:
			points -= 20
		if net < 0.0:
			points -= 10
	return points


# --- Doing it ----------------------------------------------------------------------------

## Offers the deal; if they accept, the land and money change hands and the old
## owners renounce their cores there. Returns {ok, accepted, message}.
func propose(from: String, to: String, deal: Dictionary) -> Dictionary:
	var why := blocked(from, to, deal)
	if why != "":
		return {"ok": false, "accepted": false, "message": why}
	var them := world.get_country(to)
	var v := evaluate(from, to, deal)
	if not v.accept:
		return {"ok": true, "accepted": false, "message": "%s refuses (%+d)" % [them.name, v.total]}
	var us := world.get_country(from)
	for id: int in deal.get("take", []):
		world.transfer_province(id, from)
		world.claims.remove_core(to, id)
	for id: int in deal.get("give", []):
		world.transfer_province(id, to)
		world.claims.remove_core(from, id)
	var money := int(deal.get("money", 0))
	if money != 0:
		var take_any: bool = not deal.get("take", []).is_empty()
		var give_any: bool = not deal.get("give", []).is_empty()
		var ours := "Land bought from %s" if not give_any else ("Land sold to %s" if not take_any else "Land traded with %s")
		var theirs := "Land sold to %s" if not give_any else ("Land bought from %s" if not take_any else "Land traded with %s")
		economy.post(us, ours % them.name, -money)
		economy.post(them, theirs % us.name, money)
	world.diplomacy.add_modifier(to, from, "improved", BARGAIN_OPINION)
	economy.changed()
	var message := describe(from, to, deal)
	concluded.emit(from, to, deal, message)
	return {"ok": true, "accepted": true, "message": message}


## The deal in words.
func describe(from: String, to: String, deal: Dictionary) -> String:
	var them := world.get_country(to)
	var parts: Array[String] = []
	var take: Array[String] = []
	for id: int in deal.get("take", []):
		take.append(world.get_province(id).name)
	var give: Array[String] = []
	for id: int in deal.get("give", []):
		give.append(world.get_province(id).name)
	if not take.is_empty():
		parts.append("%s %s" % ["we buy" if give.is_empty() else "we receive", ", ".join(take)])
	if not give.is_empty():
		parts.append("%s %s" % ["we sell" if take.is_empty() and int(deal.get("money", 0)) < 0 else "we cede",
			", ".join(give)])
	var money := int(deal.get("money", 0))
	if money > 0:
		parts.append("we pay %d ducats" % money)
	elif money < 0:
		parts.append("%s pays us %d ducats" % [them.name, -money])
	return ("With %s: " % them.name) + "; ".join(parts)
