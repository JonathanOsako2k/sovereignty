extends "res://tests/test_case.gd"
## The people of 1590 (tools/world1590/population_1590.gd, from the research
## report): the world's total, the great realms, the great cities standing in
## their provinces, people following the land (the Jiangnan delta against
## Yunnan's mountains, the Nile against Sinai), and every settled realm's seat
## a town at least.


func _world() -> WorldState:
	var loader := WorldLoader.new()
	var world := loader.load_world()
	for e in loader.errors:
		failures.append("load error: " + e)
	return world


func _people(w: WorldState, tag: String) -> int:
	return w.country_stats(tag).population


func _density(p: Province) -> float:
	return p.population / maxf(p.area_km2, 1.0)


func test_the_world_and_its_great_realms() -> void:
	var w := _world()
	var total := 0
	for p: Province in w.ownable_provinces():
		total += p.population
	check(total > 560_000_000 and total < 610_000_000, "about 583 million people in 1590 (%d)" % total)
	var ming := _people(w, "MNG")
	check(ming > 160_000_000 and ming < 190_000_000, "the Ming hold about 175 million (%d)" % ming)
	check(_people(w, "MUG") > 50_000_000, "Akbar's empire tens of millions (%d)" % _people(w, "MUG"))
	check(_people(w, "FRA") + _people(w, "LEA") > 15_000_000, "France and the League together (%d)" % (_people(w, "FRA") + _people(w, "LEA")))
	check(_people(w, "ENG") > 3_500_000 and _people(w, "ENG") < 6_000_000, "England about four million (%d)" % _people(w, "ENG"))


func test_great_cities_stand_in_their_provinces() -> void:
	var w := _world()
	for row: Array in [["Rome", 41.90, 12.48, 100_000], ["Paris", 48.86, 2.35, 245_000], ["London", 51.51, -0.12, 187_000],
			["Istanbul", 41.01, 28.97, 600_000], ["Beijing", 39.91, 116.40, 700_000], ["Naples", 40.85, 14.27, 224_000],
			["Lisbon", 38.71, -9.14, 90_000], ["Agra", 27.18, 78.02, 400_000]]:
		var p := w.province_near(row[1], row[2])
		var best := p
		for n: int in p.neighbour_ids:  # (a harbour city may sit in the province across the water)
			var q := w.get_province(n)
			if q != null and not q.is_sea and q.population > best.population:
				best = q
		check(best.population >= row[3], "%s's province holds the city (%s: %d)" % [row[0], best.name, best.population])


func test_people_follow_the_land() -> void:
	var w := _world()
	var jiangnan := _density(w.province_near(30.25, 120.17))  # Hangzhou
	var yunnan := _density(w.province_near(25.0, 102.7))  # Kunming
	check(jiangnan > 3.0 * yunnan, "the Jiangnan delta far denser than Yunnan (%.0f, %.0f)" % [jiangnan, yunnan])
	var nile := _density(w.province_near(25.69, 32.64))  # Luxor
	var sinai := _density(w.province_near(29.5, 34.0))
	check(nile > 10.0 * sinai, "the Nile valley against the Sinai (%.1f, %.2f)" % [nile, sinai])


func test_every_settled_seat_is_a_town() -> void:
	var w := _world()
	for c: Country in w.countries.values():
		var cap := w.get_province(c.capital_province_id)
		if cap == null or cap.owner_id != c.id or c.government_type == "tribal":
			continue
		if cap.population < 5000:
			failures.append("%s's seat %s holds only %d" % [c.name, cap.name, cap.population])
