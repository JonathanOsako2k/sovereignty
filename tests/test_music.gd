extends "res://tests/test_case.gd"
## The soundtrack's choice of age (the players themselves are not started).


func test_ages_follow_the_calendar() -> void:
	check_eq(MusicPlayer.age_of(1590), 0, "1590: Absolutism")
	check_eq(MusicPlayer.age_of(1689), 0, "1689 still")
	check_eq(MusicPlayer.age_of(1690), 1, "1690: Enlightenment")
	check_eq(MusicPlayer.age_of(1750), 2, "1750: Revolutionary")
	check_eq(MusicPlayer.age_of(1830), 3, "1830: Industrialisation")
	check_eq(MusicPlayer.age_of(1900), 4, "1900: Totality")
	check_eq(MusicPlayer.age_of(1949), 4, "to the end")


func test_tracks_by_age_and_region() -> void:
	var music := MusicPlayer.new()
	music._scan()
	if not music.has_music():
		music.free()
		return  # no soundtrack in this checkout
	check(music._tracks.has(0), "music for the first age")
	music._region = "EUR"
	for path: String in music._pool(0):
		check(path.begins_with("res://music/1 "), "%s belongs to the first age" % path)
	# An age without music borrows the nearest earlier one's.
	music._year = 1800
	var age := music._pick_age()
	check(music._tracks.has(age) and age <= 2, "1800 plays an age that has music (%d)" % age)
	# Near the turn of an age, the next age's music creeps in.
	music._year = 1689
	var next := 0
	for i in 200:
		if music._pick_age() == 1:
			next += 1
	check(next > 100, "a year before the turn, mostly the next age (%d of 200)" % next)
	music._year = 1650
	for i in 50:
		check_eq(music._pick_age(), 0, "decades before, only this age")
	# A region without its own folder hears what there is.
	music._region = "CJK"
	check(not music._pool(0).is_empty(), "East Asia borrows Europe's music for now")
	music.free()
