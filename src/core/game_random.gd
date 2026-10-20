class_name GameRandom
extends RefCounted
## The campaign's own random stream. Every roll that affects the campaign goes
## through it, never through global randomness, so a saved seed and state
## reproduce the same outcomes (structure.md §12.3). Visual-only randomness
## (scenery scatter) may use its own generators.
##
## Seed and state are 64-bit; they are saved as decimal strings because JSON
## numbers are doubles and would lose the low bits.

var _rng := RandomNumberGenerator.new()
var _seed := 0


func _init(seed_value := 1590) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value


func get_seed() -> int:
	return _seed


## Uniform float in [0, 1).
func randf() -> float:
	return _rng.randf()


## Uniform integer in [from, to], both inclusive.
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## True with the given probability (0..1).
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## A random element of a non-empty array.
func pick(items: Array) -> Variant:
	assert(not items.is_empty(), "pick from an empty array")
	return items[_rng.randi_range(0, items.size() - 1)]


## Index chosen in proportion to non-negative weights; -1 if all are zero.
func weighted_index(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	for i in weights.size():
		roll -= maxf(weights[i], 0.0)
		if roll < 0.0:
			return i
	return weights.size() - 1


func to_dict() -> Dictionary:
	return {"seed": str(_seed), "state": str(_rng.state)}


## Problems with saved random data; empty when `load_dict` will accept it.
static func check_dict(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("random state must be an object")
		return errors
	for key in ["seed", "state"]:
		var value: Variant = data.get(key)
		if not (value is String and (value as String).is_valid_int()):
			errors.append("random %s must be an integer string, got %s" % [key, var_to_str(value)])
	return errors


func load_dict(data: Dictionary) -> void:
	reseed(String(data.seed).to_int())
	_rng.state = String(data.state).to_int()
