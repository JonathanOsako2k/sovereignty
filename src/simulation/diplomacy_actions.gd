class_name DiplomacyActions
extends RefCounted
## The rules of diplomacy, shared by the player and the AI: when an action is
## allowed, how the other side judges a proposal (a total of named reasons the
## player can read before deciding), and what doing it changes.
##
## War is not here yet: declaring war arrives with armies.

## A country did something diplomatic (for notices to the player).
signal performed(action: Action, from: String, to: String, accepted: bool)

enum Action {
	IMPROVE_RELATIONS, STOP_IMPROVING, SEND_GIFT, SEND_INSULT, DECLARE_RIVAL, REMOVE_RIVAL,
	PROPOSE_ALLIANCE, BREAK_ALLIANCE, PROPOSE_MARRIAGE, BREAK_MARRIAGE, OFFER_VASSALAGE, RELEASE_SUBJECT,
}
const LABELS := {
	Action.IMPROVE_RELATIONS: "Improve relations", Action.STOP_IMPROVING: "Recall envoy",
	Action.SEND_GIFT: "Send gift", Action.SEND_INSULT: "Send insult",
	Action.DECLARE_RIVAL: "Declare rival", Action.REMOVE_RIVAL: "Remove rival",
	Action.PROPOSE_ALLIANCE: "Propose alliance", Action.BREAK_ALLIANCE: "Break alliance",
	Action.PROPOSE_MARRIAGE: "Propose royal marriage", Action.BREAK_MARRIAGE: "Break royal marriage",
	Action.OFFER_VASSALAGE: "Demand vassalage", Action.RELEASE_SUBJECT: "Release subject",
}
## Proposals the other side must accept.
const PROPOSALS := [Action.PROPOSE_ALLIANCE, Action.PROPOSE_MARRIAGE, Action.OFFER_VASSALAGE]
## Actions that sour relations or end a tie: always confirmed by the player.
const HOSTILE := [Action.SEND_INSULT, Action.DECLARE_RIVAL, Action.BREAK_ALLIANCE, Action.BREAK_MARRIAGE,
	Action.RELEASE_SUBJECT]

const GIFT_OPINION := 25.0
const INSULT_OPINION := -40.0
const BROKE_ALLIANCE_OPINION := -50.0
const BROKE_MARRIAGE_OPINION := -30.0
const RELEASED_OPINION := 40.0
## Gifts and insults to the same country at most once a year.
const COOLDOWN_DAYS := 365
## A rival should be worth the name: at least this share of our strength.
const RIVAL_MIN_STRENGTH := 0.25
const RIVAL_MAX_DISTANCE_KM := 3000.0
## Alliances and marriages get harder beyond these capital distances.
const ALLIANCE_EASY_KM := 1200.0
const MARRIAGE_EASY_KM := 1500.0

var campaign: Campaign
var world: WorldState
var diplomacy: Diplomacy

## Per-country figures for judging (rebuilt after ownership changes).
var _metrics := {}  # tag -> {strength, lat, lon, neighbours: {tag: true}}


func _init(p_campaign: Campaign) -> void:
	campaign = p_campaign
	world = campaign.world
	diplomacy = world.diplomacy
	world.province_owner_changed.connect(func(_id, _a, _b): _metrics.clear())
	world.campaign_restored.connect(func(): _metrics.clear())


# --- Country figures -------------------------------------------------------------

## Realm strength until armies exist: total development.
func strength(tag: String) -> float:
	return maxf(_metric(tag).get("strength", 0.0), 1.0)


## How loyal a subject is to its overlord: its opinion of it, less a share
## for being nearly as strong (beyond half the overlord's development). Below
## DISLOYAL it will not be called to the overlord's wars, unless its own land
## is attacked. [[reason, value]] — the sum is the loyalty.
const DISLOYAL := 0


func loyalty_reasons(subject: String) -> Array:
	var d := world.diplomacy
	var overlord := d.overlord_of(subject)
	if overlord == "":
		return []
	var reasons := [["Opinion of %s" % world.get_country(overlord).name, d.opinion(subject, overlord)]]
	var ratio := strength(subject) / strength(overlord)
	if ratio > 0.5:
		reasons.append(["Nearly as strong (%d %% of its might)" % int(ratio * 100.0), -int((ratio - 0.5) * 100.0)])
	return reasons


func loyalty(subject: String) -> int:
	var total := 0
	for r: Array in loyalty_reasons(subject):
		total += int(r[1])
	return total


func is_loyal(subject: String) -> bool:
	return loyalty(subject) >= DISLOYAL


func distance_km(a: String, b: String) -> float:
	var ma := _metric(a)
	var mb := _metric(b)
	if ma.is_empty() or mb.is_empty():
		return INF
	return _haversine(ma.lat, ma.lon, mb.lat, mb.lon)


## Borders by land, or shares a sea tile's coast.
func are_neighbours(a: String, b: String) -> bool:
	return _metric(a).get("neighbours", {}).has(b)


func neighbours_of(tag: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(_metric(tag).get("neighbours", {}).keys())
	out.sort()
	return out


## Countries that own land.
func active_countries() -> Array[String]:
	if _metrics.is_empty():
		_build_metrics()
	var out: Array[String] = []
	out.assign(_metrics.keys())
	out.sort()
	return out


func _metric(tag: String) -> Dictionary:
	if _metrics.is_empty():
		_build_metrics()
	return _metrics.get(tag, {})


func _build_metrics() -> void:
	var sums := {}
	for p: Province in world.provinces.values():
		if p.is_sea or p.is_wasteland or p.owner_id == "":
			continue
		var m: Dictionary = _metrics.get(p.owner_id, {})
		if m.is_empty():
			m = {"strength": 0.0, "lat": p.lat, "lon": p.lon, "neighbours": {}}
			_metrics[p.owner_id] = m
			sums[p.owner_id] = [0.0, 0.0, 0.0]
		m.strength += p.development
		for n in p.neighbour_ids:
			var other := world.get_province(n).owner_id
			if other != "" and other != p.owner_id:
				m.neighbours[other] = true
	# Coasts on the same sea tile count as neighbours too.
	for sea: Province in world.sea_tiles():
		var owners := {}
		for c in sea.coast_ids:
			var o := world.get_province(c).owner_id
			if o != "":
				owners[o] = true
		for a: String in owners:
			for b: String in owners:
				if a != b:
					_metrics[a].neighbours[b] = true
	for tag: String in _metrics:
		var cap := world.get_province(world.get_country(tag).capital_province_id)
		if cap:
			_metrics[tag].lat = cap.lat
			_metrics[tag].lon = cap.lon


static func _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var p1 := deg_to_rad(lat1)
	var p2 := deg_to_rad(lat2)
	var dp := p2 - p1
	var dl := deg_to_rad(lon2 - lon1)
	var a := sin(dp * 0.5) ** 2 + cos(p1) * cos(p2) * sin(dl * 0.5) ** 2
	return 6371.0 * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))


## What a gift worth GIFT_OPINION in their eyes costs (by their strength).
func gift_cost(to: String) -> int:
	return clampi(int(round(strength(to) * 0.5)), 10, 250)


## Opinion a gift of `amount` ducats buys: in proportion to what they think a
## proper gift (from 2 to twice GIFT_OPINION).
func gift_opinion(to: String, amount: int) -> float:
	return clampf(GIFT_OPINION * amount / float(gift_cost(to)), 2.0, GIFT_OPINION * 2.0)


# --- Rules -----------------------------------------------------------------------

## Why `from` cannot do `action` to `to` right now ("" = it can).
## `amount`: a gift's size in ducats (-1: the usual gift, gift_cost).
func blocked(action: Action, from: String, to: String, amount := -1) -> String:
	if from == to or world.get_country(to) == null or world.get_country(from) == null:
		return "Not possible"
	if world.military.at_war(from, to):
		return "We are at war: make peace first"
	var d := diplomacy
	var name := world.get_country(to).name
	var overlord := d.overlord_of(from)
	var subject_rule := ""
	if overlord != "":
		var kind := d.subject_type(from)
		subject_rule = "%s %s conducts our foreign affairs" % [
			{"vassal": "Our overlord", "personal_union": "Our sovereign", "tributary": "Our suzerain",
				"colony": "Our mother country"}[kind],
			world.get_country(overlord).name]
	var today := campaign.clock.day_number()
	match action:
		Action.IMPROVE_RELATIONS:
			if d.is_improving(from, to):
				return "Our envoy is already at work"
			if d.envoys_of(from).size() >= Diplomacy.ENVOYS:
				return "All %d envoys are busy" % Diplomacy.ENVOYS
		Action.STOP_IMPROVING:
			if not d.is_improving(from, to):
				return "No envoy is there"
		Action.SEND_GIFT:
			if today - d.last_used("gift", from, to) < COOLDOWN_DAYS:
				return "We sent a gift less than a year ago"
			var cost := amount if amount > 0 else gift_cost(to)
			if world.get_country(from).treasury < cost:
				return "Needs %d ducats" % cost
		Action.SEND_INSULT:
			if subject_rule != "":
				return subject_rule
			if d.is_allied(from, to) or d.are_married(from, to):
				return "We are bound to %s" % name
			if d.overlord_of(to) == from or overlord == to:
				return "Not to our own subject or overlord"
			if today - d.last_used("insult", from, to) < COOLDOWN_DAYS:
				return "We insulted them less than a year ago"
		Action.DECLARE_RIVAL:
			if subject_rule != "":
				return subject_rule
			if d.has_rival(from, to):
				return "Already our rival"
			if d.rivals_of(from).size() >= Diplomacy.MAX_RIVALS:
				return "We already have %d rivals" % Diplomacy.MAX_RIVALS
			if d.is_allied(from, to) or d.are_married(from, to):
				return "We are bound to %s" % name
			if d.overlord_of(to) != "":
				return "%s is a subject" % name
			if strength(to) < strength(from) * RIVAL_MIN_STRENGTH:
				return "Too weak to be a worthy rival"
			if not are_neighbours(from, to) and distance_km(from, to) > RIVAL_MAX_DISTANCE_KM:
				return "Too far away to be a rival"
		Action.REMOVE_RIVAL:
			if not d.has_rival(from, to):
				return "Not our rival"
		Action.PROPOSE_ALLIANCE:
			if subject_rule != "":
				return subject_rule
			if d.overlord_of(to) != "":
				return "%s is a subject of %s" % [name, world.get_country(d.overlord_of(to)).name]
			if d.is_allied(from, to):
				return "Already allies"
			if d.are_rivals(from, to):
				return "We are rivals"
		Action.BREAK_ALLIANCE:
			if not d.is_allied(from, to):
				return "Not allies"
		Action.PROPOSE_MARRIAGE:
			if subject_rule != "":
				return subject_rule
			if world.get_country(from).government_type != "monarchy":
				return "Only a monarchy can marry into another dynasty"
			if world.get_country(to).government_type != "monarchy":
				return "%s has no royal house" % name
			if d.overlord_of(to) != "":
				return "%s is a subject" % name
			if d.are_married(from, to):
				return "Already joined by marriage"
			if d.are_rivals(from, to):
				return "We are rivals"
		Action.BREAK_MARRIAGE:
			if not d.are_married(from, to):
				return "No royal marriage"
		Action.OFFER_VASSALAGE:
			if subject_rule != "":
				return subject_rule
			if d.overlord_of(to) != "":
				return "%s already has an overlord" % name
			if not d.subjects_of(to).is_empty():
				return "%s has subjects of its own" % name
			if not are_neighbours(from, to):
				return "Only a neighbour can be made a vassal"
			if strength(to) >= strength(from):
				return "%s is not weaker than us" % name
			if d.are_rivals(from, to):
				return "We are rivals"
		Action.RELEASE_SUBJECT:
			if d.overlord_of(to) != from:
				return "Not our subject"
	return ""


## How `to` judges a proposal from `from`: {total, accept, reasons: [[label, value]]}.
func evaluate(action: Action, from: String, to: String) -> Dictionary:
	var d := diplomacy
	var reasons := []
	var their_opinion := d.opinion(to, from)
	match action:
		Action.PROPOSE_ALLIANCE:
			reasons.append(["Reluctance to be bound", -25])
			reasons.append(["Their opinion of us", clampi(int(round(their_opinion * 0.6)), -60, 60)])
			if _share_rival(from, to):
				reasons.append(["A common rival", 25])
			reasons.append(["Our strength against theirs", _strength_term(from, to, 15.0, 30)])
			reasons.append(["Distance", _distance_term(from, to, ALLIANCE_EASY_KM, 60)])
			var allies := d.allies_of(to).size()
			if allies > 1:
				reasons.append(["They have %d allies already" % allies, -15 * (allies - 1)])
			if d.are_married(from, to):
				reasons.append(["Royal marriage", 15])
		Action.PROPOSE_MARRIAGE:
			reasons.append(["Reluctance", -10])
			reasons.append(["Their opinion of us", clampi(int(round(their_opinion * 0.5)), -50, 50)])
			if d.is_allied(from, to):
				reasons.append(["Allies", 20])
			reasons.append(["Our standing against theirs", _strength_term(from, to, 10.0, 20)])
			reasons.append(["Distance", _distance_term(from, to, MARRIAGE_EASY_KM, 50)])
		Action.OFFER_VASSALAGE:
			reasons.append(["Love of independence", -70])
			reasons.append(["Their opinion of us", clampi(int(round(their_opinion * 0.6)), -60, 60)])
			var ratio := strength(from) / strength(to)
			reasons.append(["Our might (%.0f× theirs)" % ratio, clampi(int(round(20.0 * (log(ratio) / log(2.0) - 2.0))), -80, 60)])
			if d.is_allied(from, to):
				reasons.append(["Allies", 20])
			if d.are_married(from, to):
				reasons.append(["Royal marriage", 10])
			var their_allies := d.allies_of(to).filter(func(t: String) -> bool: return t != from).size()
			if their_allies > 0:
				reasons.append(["Allies who would stand by them", -20 * their_allies])
	reasons = reasons.filter(func(r: Array) -> bool: return r[1] != 0)
	var total := 0
	for r: Array in reasons:
		total += r[1]
	return {"total": total, "accept": total >= 0, "reasons": reasons}


func _share_rival(a: String, b: String) -> bool:
	for r in diplomacy.rivals_of(a):
		if diplomacy.has_rival(b, r):
			return true
	return false


func _strength_term(from: String, to: String, per_doubling: float, cap: int) -> int:
	var ratio := strength(from) / strength(to)
	return clampi(int(round(per_doubling * log(ratio) / log(2.0))), -cap, cap)


func _distance_term(from: String, to: String, easy_km: float, cap: int) -> int:
	if are_neighbours(from, to):
		return 0
	var km := distance_km(from, to)
	return -mini(int(maxf(km - easy_km, 0.0) / 100.0), cap)


# --- Doing it ---------------------------------------------------------------------

## Carries out an action if allowed (and, for proposals, accepted).
## Returns {ok, accepted, message}.
func perform(action: Action, from: String, to: String, amount := -1) -> Dictionary:
	var why := blocked(action, from, to, amount)
	if why != "":
		return {"ok": false, "accepted": false, "message": why}
	var d := diplomacy
	var name := world.get_country(to).name
	var today := campaign.clock.day_number()
	var accepted := true
	var message := ""
	if action in PROPOSALS:
		accepted = evaluate(action, from, to).accept
	match action:
		Action.IMPROVE_RELATIONS:
			d.set_envoy(from, to, true)
			message = "An envoy is on the way to %s" % name
		Action.STOP_IMPROVING:
			d.set_envoy(from, to, false)
			message = "Envoy recalled from %s" % name
		Action.SEND_GIFT:
			var cost := amount if amount > 0 else gift_cost(to)
			var giver := world.get_country(from)
			giver.treasury -= cost
			giver.ledger.append(["Gift to %s" % name, -float(cost)])
			d.add_modifier(to, from, "gift", gift_opinion(to, cost), GIFT_OPINION * 2.0)
			d.mark_used("gift", from, to, today)
			message = "%s received our gift of %d ducats" % [name, cost]
		Action.SEND_INSULT:
			d.add_modifier(to, from, "insult", INSULT_OPINION)
			d.mark_used("insult", from, to, today)
			message = "We insulted %s" % name
		Action.DECLARE_RIVAL:
			d.set_rival(from, to, true)
			message = "%s is now our rival" % name
		Action.REMOVE_RIVAL:
			d.set_rival(from, to, false)
			message = "%s is no longer our rival" % name
		Action.PROPOSE_ALLIANCE:
			if accepted:
				d.set_allied(from, to, true)
			message = ("%s accepted our alliance" if accepted else "%s declined our alliance") % name
		Action.BREAK_ALLIANCE:
			d.set_allied(from, to, false)
			d.add_modifier(to, from, "broke_alliance", BROKE_ALLIANCE_OPINION)
			message = "Our alliance with %s is over" % name
		Action.PROPOSE_MARRIAGE:
			if accepted:
				d.set_married(from, to, true)
			message = ("%s agreed to a royal marriage" if accepted else "%s refused a royal marriage") % name
		Action.BREAK_MARRIAGE:
			d.set_married(from, to, false)
			d.add_modifier(to, from, "broke_marriage", BROKE_MARRIAGE_OPINION)
			message = "Our royal marriage with %s is ended" % name
		Action.OFFER_VASSALAGE:
			if accepted:
				d.set_subject(from, to, "vassal")
				d.set_allied(from, to, false)
				d.set_envoy(from, to, false)
			message = ("%s became our vassal" if accepted else "%s refused to become our vassal") % name
		Action.RELEASE_SUBJECT:
			d.release_subject(to)
			d.add_modifier(to, from, "released", RELEASED_OPINION)
			message = "%s is free" % name
	performed.emit(action, from, to, accepted)
	return {"ok": true, "accepted": accepted, "message": message}
