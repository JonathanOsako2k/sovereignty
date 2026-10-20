class_name DiplomacySystem
extends RefCounted
## Monthly diplomacy: opinion effects fade, envoys build relations, and the
## AI countries act — through the same DiplomacyActions rules as the player.
##
## The AI is deliberately simple and readable (structure.md §13): each month
## every AI country looks at a short list of candidates and, with modest odds
## from the campaign's random stream (so results are reproducible), keeps its
## envoys busy, picks rivals among neighbours of similar strength, seeks
## alliances and marriages the other side would accept, and now and then
## insults a rival or courts a friend with a gift. It never proposes to the
## player (that needs an answer screen) and never demands vassalage.

const RIVAL_CHANCE := 0.06
const ALLIANCE_CHANCE := 0.08
const MARRIAGE_CHANCE := 0.03
const INSULT_CHANCE := 0.02
const GIFT_CHANCE := 0.02
const WANTED_RIVALS := 2
const WANTED_ALLIES := 2

var campaign: Campaign
var actions: DiplomacyActions


func _init(p_campaign: Campaign, p_actions: DiplomacyActions) -> void:
	campaign = p_campaign
	actions = p_actions


func monthly() -> void:
	campaign.world.diplomacy.monthly_update()
	var player := campaign.world.player_country_id
	for tag in actions.active_countries():
		if tag != player:
			_think(tag, player)


func _think(tag: String, player: String) -> void:
	var d := campaign.world.diplomacy
	var rng := campaign.rng
	var A := DiplomacyActions.Action
	var overlord := d.overlord_of(tag)
	if overlord != "":
		# Subjects court their overlord and otherwise follow its lead.
		if d.opinion(overlord, tag) < 40:
			actions.perform(A.IMPROVE_RELATIONS, tag, overlord)
		return
	var neighbours := actions.neighbours_of(tag)

	if d.rivals_of(tag).size() < WANTED_RIVALS and rng.chance(RIVAL_CHANCE):
		var best := ""
		var best_score := -INF
		for n in neighbours:
			var ratio := actions.strength(n) / actions.strength(tag)
			if ratio < 0.5 or ratio > 2.5 or actions.blocked(A.DECLARE_RIVAL, tag, n) != "":
				continue
			var score := -float(d.opinion(tag, n)) - absf(log(ratio)) * 20.0
			if score > best_score:
				best_score = score
				best = n
		if best != "":
			actions.perform(A.DECLARE_RIVAL, tag, best)

	var allies := d.allies_of(tag).size()
	var candidates := _partner_candidates(tag, neighbours)
	if allies < WANTED_ALLIES and rng.chance(ALLIANCE_CHANCE):
		for c in candidates:
			if c == player or actions.blocked(A.PROPOSE_ALLIANCE, tag, c) != "":
				continue
			# Both sides must want it.
			if actions.evaluate(A.PROPOSE_ALLIANCE, tag, c).accept and actions.evaluate(A.PROPOSE_ALLIANCE, c, tag).accept:
				actions.perform(A.PROPOSE_ALLIANCE, tag, c)
				break

	if rng.chance(MARRIAGE_CHANCE):
		for c in candidates:
			if c == player or actions.blocked(A.PROPOSE_MARRIAGE, tag, c) != "":
				continue
			if actions.evaluate(A.PROPOSE_MARRIAGE, tag, c).accept and actions.evaluate(A.PROPOSE_MARRIAGE, c, tag).accept:
				actions.perform(A.PROPOSE_MARRIAGE, tag, c)
				break

	# Envoys work on the most promising partner not yet won over.
	for c in candidates:
		if d.envoys_of(tag).size() >= Diplomacy.ENVOYS:
			break
		if d.is_allied(tag, c) or d.is_improving(tag, c):
			continue
		if actions.evaluate(A.PROPOSE_ALLIANCE, tag, c).total >= -40:
			actions.perform(A.IMPROVE_RELATIONS, tag, c)
	for c in d.envoys_of(tag):
		if d.modifier(c, tag, "improved") >= Diplomacy.IMPROVE_CAP or d.is_allied(tag, c):
			actions.perform(A.STOP_IMPROVING, tag, c)

	if not d.rivals_of(tag).is_empty() and rng.chance(INSULT_CHANCE):
		var target: String = rng.pick(d.rivals_of(tag))
		if actions.blocked(A.SEND_INSULT, tag, target) == "":
			actions.perform(A.SEND_INSULT, tag, target)

	if not candidates.is_empty() and rng.chance(GIFT_CHANCE):
		var friend: String = candidates[0]
		var treasury := campaign.world.get_country(tag).treasury
		if treasury >= actions.gift_cost(friend) * 3 and actions.blocked(A.SEND_GIFT, tag, friend) == "":
			actions.perform(A.SEND_GIFT, tag, friend)


## Neighbours (and near countries) worth befriending, best first: those who
## share a rival, then stronger ones, then by how they regard us.
func _partner_candidates(tag: String, neighbours: Array[String]) -> Array[String]:
	var d := campaign.world.diplomacy
	var scored := []
	for n in neighbours:
		if d.are_rivals(tag, n) or d.overlord_of(n) != "":
			continue
		var score := float(d.opinion(n, tag)) + 10.0 * log(actions.strength(n) / actions.strength(tag))
		for r in d.rivals_of(tag):
			if d.has_rival(n, r):
				score += 40.0
		scored.append([score, n])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var out: Array[String] = []
	for s: Array in scored.slice(0, 6):
		out.append(s[1])
	return out
