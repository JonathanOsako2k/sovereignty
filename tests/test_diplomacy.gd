extends "res://tests/test_case.gd"
## Diplomacy: the 1590 starting relations, the rules of each action, opinion,
## monthly fading and envoys, saving, and the AI.

const A := DiplomacyActions.Action


func _campaign() -> Campaign:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return Campaign.new(world)


func test_iberian_union_keeps_portugal_its_own_country() -> void:
	var c := _campaign()
	var d := c.world.diplomacy
	check_eq(d.overlord_of("POR"), "SPA", "Portugal's sovereign")
	check_eq(d.subject_type("POR"), "personal_union", "a personal union, not a merger")
	check_eq(c.world.province_near(38.72, -9.14).owner_id, "POR", "Lisbon stays Portuguese")
	check(c.world.get_country("POR").capital_province_id != 0, "Portugal keeps its capital")
	check(c.world.country_stats("POR").provinces > 5, "and its provinces")


func test_1590_subjects_and_treaties() -> void:
	var d := _campaign().world.diplomacy
	for vassal in ["CRI", "WAL", "MOL", "TRA"]:
		check_eq(d.overlord_of(vassal), "TUR", "%s under the Ottomans" % vassal)
	for vassal in ["TKG", "MRI", "UES", "SMZ", "CHO", "UKT", "SAN"]:
		check_eq(d.overlord_of(vassal), "JAP", "%s a Toyotomi vassal" % vassal)
	for free in ["HOJ", "DTE", "MGM", "NNB", "STK", "KSI", "AKT", "TSG", "SMI"]:
		check_eq(d.overlord_of(free), "", "%s not yet under Hideyoshi" % free)
	check_eq(d.subject_type("JOS"), "tributary", "Joseon a Ming tributary")
	check(d.is_allied("ENG", "NED"), "Treaty of Nonsuch")
	check(d.are_married("SCO", "DEN"), "James VI and Anne of Denmark")
	check(d.has_rival("ENG", "SPA") and d.has_rival("SPA", "ENG"), "England and Spain")
	check(d.has_rival("JAP", "HOJ"), "Hideyoshi against the Hōjō")


func test_opinion_is_a_sum_of_named_reasons() -> void:
	var d := _campaign().world.diplomacy
	var reasons := d.opinion_reasons("NED", "ENG")
	check(reasons.any(func(r: Array) -> bool: return r[0] == "Allies" and r[1] == Diplomacy.OPINION_ALLIED), "alliance listed: %s" % [reasons])
	check(reasons.any(func(r: Array) -> bool: return r[0] == "Common rival"), "common rival (Spain) listed")
	var total := 0
	for r: Array in reasons:
		total += r[1]
	check_eq(d.opinion("NED", "ENG"), total, "opinion is the sum")
	check(d.opinion("SPA", "ENG") < 0, "Spain dislikes England")


func test_gift_costs_money_raises_opinion_and_waits_a_year() -> void:
	var c := _campaign()
	var acts := DiplomacyActions.new(c)
	var before := c.world.diplomacy.opinion("SCO", "ENG")
	var treasury := c.world.get_country("ENG").treasury
	var r := acts.perform(A.SEND_GIFT, "ENG", "SCO")
	check(r.ok, "gift sent: %s" % r.message)
	check_eq(c.world.get_country("ENG").treasury, treasury - acts.gift_cost("SCO"), "treasury paid")
	check_eq(c.world.diplomacy.opinion("SCO", "ENG"), before + int(DiplomacyActions.GIFT_OPINION), "opinion up")
	check(acts.blocked(A.SEND_GIFT, "ENG", "SCO") != "", "not again this year")
	for i in 366:
		c.clock.step_day()
	check_eq(acts.blocked(A.SEND_GIFT, "ENG", "SCO"), "", "allowed a year later")


func test_insult_and_rival_rules() -> void:
	var c := _campaign()
	var acts := DiplomacyActions.new(c)
	var before := c.world.diplomacy.opinion("FRA", "ENG")
	check(acts.blocked(A.SEND_INSULT, "ENG", "NED") != "", "cannot insult an ally")
	acts.perform(A.SEND_INSULT, "ENG", "SCO")
	check(c.world.diplomacy.opinion("SCO", "ENG") < before, "insult lowers opinion")
	check(acts.blocked(A.DECLARE_RIVAL, "SPA", "LUC") != "", "Lucca is too small to rival Spain: %s" % acts.blocked(A.DECLARE_RIVAL, "SPA", "LUC"))
	check(acts.blocked(A.DECLARE_RIVAL, "ENG", "MNG") != "", "Ming is too far to rival England")
	check(acts.blocked(A.DECLARE_RIVAL, "POR", "FRA") != "", "Portugal's affairs are Spain's")
	check(acts.perform(A.DECLARE_RIVAL, "ENG", "SCO").ok, "England may rival Scotland")
	check(c.world.diplomacy.has_rival("ENG", "SCO"), "rival recorded")


func test_proposals_are_judged_with_reasons() -> void:
	var c := _campaign()
	var acts := DiplomacyActions.new(c)
	check(acts.blocked(A.PROPOSE_ALLIANCE, "ENG", "SPA") != "", "rivals cannot ally")
	check(acts.blocked(A.PROPOSE_MARRIAGE, "ENG", "NED") != "", "a republic has no royal house")
	check(acts.blocked(A.PROPOSE_ALLIANCE, "ENG", "POR") != "", "Portugal cannot ally on its own")
	var v := acts.evaluate(A.PROPOSE_ALLIANCE, "FRA", "SWI")
	var total := 0
	for r: Array in v.reasons:
		total += r[1]
	check_eq(v.total, total, "verdict is the sum of its reasons")
	# Win them over, then they agree.
	c.world.diplomacy.add_modifier("SCO", "ENG", "improved", 50.0)
	c.world.diplomacy.add_modifier("SCO", "ENG", "gift", 60.0)
	var r := acts.perform(A.PROPOSE_ALLIANCE, "ENG", "SCO")
	check(r.accepted and c.world.diplomacy.is_allied("ENG", "SCO"), "friendly neighbour accepts: %s" % [acts.evaluate(A.PROPOSE_ALLIANCE, "ENG", "SCO")])
	acts.perform(A.BREAK_ALLIANCE, "ENG", "SCO")
	check(not c.world.diplomacy.is_allied("ENG", "SCO"), "alliance broken")
	check(c.world.diplomacy.modifier("SCO", "ENG", "broke_alliance") < 0, "and remembered")


func test_vassals_and_release() -> void:
	var c := _campaign()
	var acts := DiplomacyActions.new(c)
	var d := c.world.diplomacy
	check(acts.blocked(A.OFFER_VASSALAGE, "TUR", "CRI") != "", "already a vassal")
	check(acts.perform(A.RELEASE_SUBJECT, "TUR", "CRI").ok, "release Crimea")
	check_eq(d.overlord_of("CRI"), "", "Crimea free")
	check(d.opinion("CRI", "TUR") > 0, "and grateful")
	# Lucca next to its giant, mighty friend Tuscany? Make Tuscany adore... a tiny neighbour of Spain's Milan.
	d.add_modifier("LUC", "TUS", "gift", 100.0)
	d.add_modifier("LUC", "TUS", "improved", 50.0)
	var v := acts.evaluate(A.OFFER_VASSALAGE, "TUS", "LUC")
	check(v.reasons.size() >= 2, "vassalage reasons listed: %s" % [v])


func test_envoys_and_fading() -> void:
	var c := _campaign()
	var acts := DiplomacyActions.new(c)
	var d := c.world.diplomacy
	acts.perform(A.IMPROVE_RELATIONS, "ENG", "SCO")
	acts.perform(A.IMPROVE_RELATIONS, "ENG", "FRA")
	check_eq(acts.envoys_max("ENG"), 3, "a major kingdom sends three envoys")
	check(acts.blocked(A.IMPROVE_RELATIONS, "ENG", "DEN") == "", "a third")
	acts.perform(A.IMPROVE_RELATIONS, "ENG", "NED")
	check(acts.blocked(A.IMPROVE_RELATIONS, "ENG", "DEN") != "", "only %d envoys" % acts.envoys_max("ENG"))
	for month in 30:
		d.monthly_update()
	check_eq(d.modifier("SCO", "ENG", "improved"), Diplomacy.IMPROVE_CAP, "envoy work is capped")
	acts.perform(A.STOP_IMPROVING, "ENG", "SCO")
	acts.perform(A.SEND_INSULT, "ENG", "DEN")
	for month in 10:
		d.monthly_update()
	check_eq(d.modifier("SCO", "ENG", "improved"), Diplomacy.IMPROVE_CAP - 10.0, "fades once recalled")
	check_eq(d.modifier("DEN", "ENG", "insult"), DiplomacyActions.INSULT_OPINION + 10.0, "insults fade too")


func test_diplomacy_survives_save_and_load() -> void:
	var a := _campaign()
	var acts := DiplomacyActions.new(a)
	acts.perform(A.IMPROVE_RELATIONS, "ENG", "SCO")
	acts.perform(A.SEND_INSULT, "ENG", "DEN")
	acts.perform(A.DECLARE_RIVAL, "ENG", "SCO")
	a.world.diplomacy.monthly_update()
	var copy: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict(), "", false, true))
	var b := _campaign()
	var errors := b.restore(copy)
	check(errors.is_empty(), "restore: %s" % [errors])
	check_eq(b.world.diplomacy.to_dict(), a.world.diplomacy.to_dict(), "diplomacy identical")
	check_eq(b.world.diplomacy.opinion("DEN", "ENG"), a.world.diplomacy.opinion("DEN", "ENG"), "opinion identical")
	copy.diplomacy.subjects.append(["SPA", "XXX", "vassal"])
	check(not b.restore(copy).is_empty(), "unknown country in diplomacy refused")


func test_ai_months_are_reproducible() -> void:
	var results := []
	for run in 2:
		var c := _campaign()
		var acts := DiplomacyActions.new(c)
		var system := DiplomacySystem.new(c, acts)
		for month in 12:
			system.monthly()
		results.append(JSON.stringify(c.world.diplomacy.to_dict()))
	check_eq(results[0], results[1], "same seed, same diplomacy")
	var d: Dictionary = JSON.parse_string(results[0])
	check(d.envoys.size() > 20, "AI envoys at work (%d)" % d.envoys.size())
	check(d.alliances.size() >= 6, "alliances kept or made (%d)" % d.alliances.size())
	check_eq(d.subjects.filter(func(s: Array) -> bool: return s[1] == "POR").size(), 1, "the union holds")


func test_vassals_are_drawn_in_shades_of_their_overlord() -> void:
	var c := _campaign()
	var w := c.world
	var jap := MapModes.country_color(w, "JAP")
	var seen := {}
	for vassal in w.diplomacy.subjects_of("JAP"):
		var col := MapModes.country_color(w, vassal)
		check(col != jap, "%s differs from its overlord" % vassal)
		check(_distance(col, jap) < 0.6, "%s is a shade of Toyotomi red (%s vs %s)" % [vassal, col, jap])
		check(not seen.has(col.to_html()), "%s has its own shade" % vassal)
		seen[col.to_html()] = true
	check(_distance(MapModes.country_color(w, "POR"), MapModes.country_color(w, "SPA")) < 0.6, "Portugal a shade of Spain")
	check_eq(MapModes.country_color(w, "JOS"), w.get_country("JOS").color, "tributaries keep their colours")
	DiplomacyActions.new(c).perform(A.RELEASE_SUBJECT, "TUR", "CRI")
	check_eq(MapModes.country_color(w, "CRI"), w.get_country("CRI").color, "a released vassal gets its colour back")


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
