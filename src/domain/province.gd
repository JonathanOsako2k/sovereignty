class_name Province
extends RefCounted
## A province: static definition (from data/world) plus campaign state (from the
## scenario or a save). Ownership is authoritative here; country province lists
## are derived from it.

# Static definition
var id: int
var name: String
var region: String
## Legacy broad terrain (plains, forest, desert...); for wastelands their kind
## (desert, mountains, glacier, tundra), for water "sea" or "lake".
var terrain: String
## EU5-style land (see Land): set for land provinces and wastelands, "" at sea.
var topography := ""
var vegetation := ""
var climate := ""
## Mean elevation in metres.
var elevation := 0
## The good the world data gives it in 1590, and hidden deposits:
## [good, year from which it can be found, chance a year].
var start_resource := ""
var deposits: Array = []
var is_coastal: bool
var area: int  ## in map pixels
var area_km2: int
var lat: float
var lon: float
var neighbour_ids: PackedInt32Array
var label_position: Vector2
var bounds: Rect2i
## The real first-level division (county, department, state...) it lies in.
var division: String
## Wastelands are impassable land that can never be owned; they are not among
## the playable provinces and have no neighbours.
var is_wasteland := false
## Sea tiles (and tiles on large lakes): never owned. For a sea tile,
## neighbour_ids are the adjacent sea tiles and coast_ids the land provinces on
## its shores; for a land province, sea_ids are the sea tiles it touches.
var is_sea := false
var sea_ids: PackedInt32Array
var coast_ids: PackedInt32Array

# Campaign state
var owner_id: String = ""  ## "" = uncolonised
var controller_id: String = ""
var population: int = 0
var development: int = 1
var unrest: float = 0.0
## The good it produces now (a discovery or a new crop can change it).
var resource := ""
## Goods discovered here so far (deposits found).
var found: Array = []
## Buildings standing, and [building, months left] while one is being built.
var buildings: Array = []
var construction: Array = []
## People by role (Estates.ROLES) -> count; `population` is their sum.
var pops := {}
## While uncolonised land is being settled: the settling country and its
## progress in percent (see Colonisation).
var colonist := ""
var colony_progress := 0.0
## Men away with the levies (worked out from the armies; not saved): they do
## not work the land while they serve.
var levied := 0


## Adds people to one estate (or removes them, with a negative count),
## keeping the population their sum.
func add_people(role: String, count: int) -> void:
	pops[role] = maxi(pops.get(role, 0) + count, 0)
	population = 0
	for r: String in pops:
		population += pops[r]


func is_occupied() -> bool:
	return controller_id != owner_id
