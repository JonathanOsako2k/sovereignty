extends "res://tests/test_case.gd"


func _sequence(rng: GameRandom, n := 20) -> Array:
	var out := []
	for i in n:
		out.append(rng.randi_range(0, 1_000_000))
	return out


func test_same_seed_same_sequence() -> void:
	check_eq(_sequence(GameRandom.new(42)), _sequence(GameRandom.new(42)), "seed 42")
	check(_sequence(GameRandom.new(42)) != _sequence(GameRandom.new(43)), "different seeds differ")


func test_state_survives_json_and_continues_the_stream() -> void:
	var a := GameRandom.new(1590)
	_sequence(a, 37)
	var saved: Variant = JSON.parse_string(JSON.stringify(a.to_dict()))
	check(GameRandom.check_dict(saved).is_empty(), "saved state is valid: %s" % [GameRandom.check_dict(saved)])
	var b := GameRandom.new(7)
	b.load_dict(saved)
	check_eq(b.get_seed(), 1590, "seed restored")
	check_eq(_sequence(b), _sequence(a), "continues exactly where it was saved")


func test_large_seeds_are_kept_exactly() -> void:
	var big := 9_007_199_254_740_993  # 2^53 + 1: not representable as a JSON double
	var a := GameRandom.new(big)
	var b := GameRandom.new(0)
	b.load_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	check_eq(b.get_seed(), big, "64-bit seed")
	check_eq(_sequence(b), _sequence(a), "64-bit seed sequence")


func test_rejects_malformed_state() -> void:
	check(not GameRandom.check_dict({"seed": "12", "state": 34.0}).is_empty(), "numeric state is rejected")
	check(not GameRandom.check_dict({"seed": "x"}).is_empty(), "garbage is rejected")
	check(not GameRandom.check_dict([]).is_empty(), "non-object is rejected")


func test_helpers_stay_in_range() -> void:
	var rng := GameRandom.new(5)
	var hits := 0
	for i in 2000:
		var v := rng.randi_range(3, 6)
		check(v >= 3 and v <= 6, "randi_range in bounds")
		if rng.chance(0.25):
			hits += 1
	check(hits > 400 and hits < 600, "chance(0.25) hit %d of 2000" % hits)
	check_eq(rng.weighted_index(PackedFloat32Array([0.0, 0.0])), -1, "all-zero weights")
	for i in 50:
		check_eq(rng.weighted_index(PackedFloat32Array([0.0, 2.0, 0.0])), 1, "only positive weight wins")
	check(rng.pick(["a", "b"]) in ["a", "b"], "pick returns an element")
