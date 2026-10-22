extends "res://tests/test_case.gd"
## Cores and claims: every owner's cores, the historical rights of 1590, new
## cores after CORE_YEARS of holding, cores kept on lost land, saving.


func _campaign() -> Campaign:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return Campaign.new(world)


func test_the_rights_of_1590() -> void:
	var c := _campaign()
	var w := c.world
	var cl := w.claims
	var missing := 0
	for p: Province in w.ownable_provinces():
		if p.owner_id != "" and not cl.is_core(p.owner_id, p.id):
			missing += 1
	check_eq(missing, 0, "every owner has a core on its land")
	var calais := w.province_near(50.95, 1.86)
	check(calais.owner_id != "ENG" and cl.is_core("ENG", calais.id), "England's core on %s (%s's)" % [calais.name, calais.owner_id])
	var amsterdam := w.province_near(52.37, 4.9)
	check(cl.is_core("SPA", amsterdam.id), "Spain's core on the Dutch provinces")
	check(cl.has_claim("JAP", w.province_near(35.18, 129.08).id), "Japan claims Busan")
	check(cl.is_core("AUS", w.province_near(47.5, 19.04).id), "Austria's core on Ottoman Buda")
	var grudges := Claims.grudges(w, cl)
	check(grudges.get("SPA", {}).has("NED"), "Spain's grudge against the United Provinces")
	# A new campaign starts with them too.
	c.start_new("FRA")
	check(w.claims.is_core("ENG", calais.id), "kept in a new campaign")


func test_cores_come_with_time_and_stay() -> void:
	var c := _campaign()
	var w := c.world
	var cl := w.claims
	var day := c.clock.day_number()
	var lyon := w.province_near(44.84, -0.58)  # Bordeaux, the king's in 1590 (Lyon held for the League)
	check_eq(lyon.owner_id, "FRA", "Bordeaux is French")
	cl.yearly(w, day)
	w.transfer_province(lyon.id, "SAV")
	cl.yearly(w, day + 365)
	check(not cl.is_core("SAV", lyon.id), "no core at once")
	cl.yearly(w, day + 365 * Claims.CORE_YEARS)
	check(not cl.is_core("SAV", lyon.id), "not quite yet")
	cl.yearly(w, day + 365 * (Claims.CORE_YEARS + 1) + 1)
	check(cl.is_core("SAV", lyon.id), "Savoy's core after %d years" % Claims.CORE_YEARS)
	check(cl.is_core("FRA", lyon.id), "France keeps its core on lost land")
	# Saved and restored; older saves get the start's rights.
	var data := c.to_dict()
	var c2 := _campaign()
	check(c2.restore(data).is_empty(), "restores")
	check(c2.world.claims.is_core("SAV", lyon.id) and c2.world.claims.is_core("FRA", lyon.id), "cores saved")
	data.erase("claims")
	var c3 := _campaign()
	check(c3.restore(data).is_empty(), "an older save restores")
	check(c3.world.claims.is_core("ENG", w.province_near(50.95, 1.86).id), "with the rights of 1590")
