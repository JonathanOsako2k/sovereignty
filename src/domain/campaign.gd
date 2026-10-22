class_name Campaign
extends RefCounted
## One running campaign: the world, its calendar and its random stream — the
## complete state a save captures. Static world data (geometry, names,
## adjacency) is not part of it; saves refer to a world-data version instead.

const DEFAULT_SEED := 1590

var world: WorldState
var clock: GameClock
var rng: GameRandom
## The scenario's starting state, so a new campaign can begin without
## reloading the static world data.
var _initial: Dictionary


func _init(p_world: WorldState, p_clock: GameClock = null, p_rng: GameRandom = null) -> void:
	world = p_world
	clock = p_clock if p_clock else GameClock.new()
	rng = p_rng if p_rng else GameRandom.new(DEFAULT_SEED)
	clock.set_date(world.start_date.year, world.start_date.month, world.start_date.day)
	_initial = to_dict()


func to_dict() -> Dictionary:
	return {"date": clock.to_dict(), "random": rng.to_dict(), "world": world.campaign_state(),
		"diplomacy": world.diplomacy.to_dict(), "military": world.military.to_dict(), "claims": world.claims.to_dict()}


## Diagnostics for saved campaign data; empty when `restore` will accept it.
func check(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("campaign must be an object")
		return errors
	errors.append_array(clock.check_dict(data.get("date")))
	errors.append_array(GameRandom.check_dict(data.get("random")))
	errors.append_array(world.check_campaign_state(data.get("world")))
	var known := world.known_tags(data.get("world"))  # the world data's countries and those it founded
	errors.append_array(Diplomacy.check_dict(data.get("diplomacy"), known))
	errors.append_array(Military.check_dict(data.get("military"), world, known))
	errors.append_array(Claims.check_dict(data.get("claims"), world, known))
	return errors


## Replaces the whole campaign state. All or nothing: on any problem the
## campaign is left as it was and the diagnostics are returned. `trusted`: the
## state was made by to_dict() itself (a new campaign's start), so it is
## applied without checking it (checking 5000 provinces twice is most of the
## time a new campaign takes).
func restore(data: Variant, trusted := false) -> PackedStringArray:
	var errors := PackedStringArray() if trusted else check(data)
	if not errors.is_empty():
		return errors
	errors = world.restore_campaign_state(data.world, trusted)
	if not errors.is_empty():
		return errors
	world.diplomacy.load_dict(data.diplomacy)
	clock.load_dict(data.date)
	rng.load_dict(data.random)
	if data.get("military") == null:
		world.military.populate(world, clock.year)  # an older save: forces as at the start
	else:
		world.military.load_dict(data.military)
		world.military.add_missing_docks(world)  # a save from before docks
		world.military.add_missing_barracks(world)  # a save from before barracks
	if data.get("claims") == null:
		world.claims.populate(world, clock.day_number())  # an older save: rights as at the start
	else:
		world.claims.load_dict(data.claims)
	world.military.recount_levies(world)  # men away with the levies are not saved
	world.overseas = Overseas.overseas_ids(world)  # worked out, not saved
	return errors


## Back to the scenario's start, playing `player_tag`, with a fresh random seed.
func start_new(player_tag: String, seed_value: int = DEFAULT_SEED) -> PackedStringArray:
	var data := _initial.duplicate(true)
	data.world.player = player_tag
	var errors := restore(data, world.countries.has(player_tag))
	if errors.is_empty():
		rng.reseed(seed_value)
	return errors


## Short description for save lists: "Kingdom of England, 3 March 1592".
func title() -> String:
	return "%s, %s" % [player_name(), clock.format_date()]


func player_name() -> String:
	var player := world.get_country(world.player_country_id)
	return player.name if player else "Observer"
