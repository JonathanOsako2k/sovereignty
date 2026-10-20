class_name Army
extends RefCounted
## A land army or a fleet: regiments (ships, for a fleet) of one country, where
## it stands and where it is marching. Levy regiments remember the province
## they were raised from: their men are missing from its fields while they
## serve, and those who die are lost to its people.

var id := 0
var owner := ""
var name := ""
var navy := false
## Province id (a sea tile for a fleet).
var location := 0
## Regiments: [unit type, men, home province (levies; 0 otherwise)].
var regiments: Array = []
## Share of the regiments' full fighting spirit (0-1); battles break it, rest
## restores it.
var morale := 1.0
## Provinces still to march through, the next first; and days left to reach
## it (of the leg's total, for drawing the march).
var path: Array[int] = []
var leg_days := 0.0
var leg_total := 0.0
## The fleet carrying this army over the sea (0: on land). Aboard, it goes
## where the fleet goes and neither fights nor besieges.
var aboard := 0
## Falling back after a lost battle: it cannot be caught or ordered until it
## reaches the end of its retreat.
var retreating := false


func men() -> int:
	var total := 0
	for r: Array in regiments:
		total += r[1]
	return total


## Men at full strength.
func full_men() -> int:
	var total := 0
	for r: Array in regiments:
		total += UnitTypes.get_type(r[0]).men
	return total


func is_moving() -> bool:
	return not path.is_empty()


func has_levies() -> bool:
	return regiments.any(func(r: Array) -> bool: return r[0] == "levy")


## Soldiers a fleet can carry: its ships' capacity, as far as they are manned.
func capacity() -> int:
	var total := 0.0
	for r: Array in regiments:
		var u := UnitTypes.get_type(r[0])
		total += float(u.get("capacity", 0)) * r[1] / maxf(float(u.men), 1.0)
	return int(total)


## Fighting power: men × the unit's attack and defence × its spirit × ours.
func power() -> float:
	var total := 0.0
	for r: Array in regiments:
		var u := UnitTypes.get_type(r[0])
		total += r[1] * (u.attack + u.defence) * 0.5 * u.morale
	return total * maxf(morale, 0.1)


## How well an army takes forts (artillery and the like), per man.
func siege_power() -> float:
	var total := 0.0
	for r: Array in regiments:
		total += r[1] * UnitTypes.get_type(r[0]).get("siege", 0.0)
	return total / maxf(men(), 1.0)


## km a day: the slowest regiment's pace.
func speed() -> float:
	var s := INF
	for r: Array in regiments:
		s = minf(s, UnitTypes.get_type(r[0]).speed)
	return s if s < INF else 20.0


## Monthly upkeep at full maintenance (before the maintenance policy and prices).
func upkeep() -> float:
	var total := 0.0
	for r: Array in regiments:
		var u := UnitTypes.get_type(r[0])
		total += u.upkeep * r[1] / maxf(u.men, 1.0)
	return total


## Regiments by unit type: type -> [regiments, men].
func by_type() -> Dictionary:
	var out := {}
	for r: Array in regiments:
		var e: Array = out.get(r[0], [0, 0])
		e[0] += 1
		e[1] += r[1]
		out[r[0]] = e
	return out


func to_array() -> Array:
	return [id, owner, name, navy, location, regiments.duplicate(true), morale, Array(path), leg_days, leg_total,
		aboard, retreating]


static func from_array(a: Array) -> Army:
	var army := Army.new()
	army.id = int(a[0])
	army.owner = a[1]
	army.name = a[2]
	army.navy = bool(a[3])
	army.location = int(a[4])
	for r: Array in a[5]:
		army.regiments.append([r[0], int(r[1]), int(r[2])])
	army.morale = float(a[6])
	for id: Variant in a[7]:
		army.path.append(int(id))
	army.leg_days = float(a[8])
	army.leg_total = float(a[9])
	if a.size() >= 12:
		army.aboard = int(a[10])
		army.retreating = bool(a[11])
	return army
