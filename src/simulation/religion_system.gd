class_name ReligionSystem
extends RefCounted
## Missionaries (monthly, through the scheduler). A country sends one to a
## province of its own (held, not occupied) whose faith is not its state
## religion: it costs SEND_COST + SEND_PER_DEVELOPMENT ducats to send and
## Missionaries upkeep in the budget (EconomySystem) while it works, and
## converts the province in months_to_convert() — BASE_MONTHS, longer the
## more developed the land, longer across families of faith, quicker among
## animists. A realm keeps as many missionaries at once as its age allows
## (SLOTS). Land lost or occupied ends the mission. The AI sends its own to
## the quickest conversions it can afford.

signal converted(province_id: int, religion: String)

const SLOTS := [[1590, 1], [1650, 2], [1750, 3], [1850, 4]]
const SEND_COST := 20.0
const SEND_PER_DEVELOPMENT := 5.0
const BASE_MONTHS := 60.0
const PER_DEVELOPMENT := 0.1  # months × (1 + this × development)
const OTHER_FAMILY := 1.6
const ANIMIST := 0.6
## The AI keeps this much in hand after sending one.
const AI_RESERVE := 100.0

var campaign: Campaign
var world: WorldState
var economy: EconomySystem


func _init(p_campaign: Campaign, p_economy: EconomySystem) -> void:
	campaign = p_campaign
	world = campaign.world
	economy = p_economy


func slots(_tag := "") -> int:
	var n := 0
	for s: Array in SLOTS:
		if campaign.clock.year >= s[0]:
			n = s[1]
	return n


## Provinces where `tag`'s missionaries are at work.
func missions_of(tag: String) -> Array[int]:
	var out: Array[int] = []
	for id: int in world.missions:
		if world.missions[id][0] == tag:
			out.append(id)
	out.sort()
	return out


func send_cost(tag: String, p: Province) -> float:
	var c := world.get_country(tag)
	return EconomySystem.decimal((SEND_COST + SEND_PER_DEVELOPMENT * p.development) * (1.0 + c.inflation / 100.0))


## Months a missionary needs to convert the province to `tag`'s faith.
func months_to_convert(tag: String, p: Province) -> int:
	var c := world.get_country(tag)
	var months := BASE_MONTHS * (1.0 + PER_DEVELOPMENT * p.development)
	if p.religion == "animist":
		months *= ANIMIST
	elif c != null and Religions.family_of(p.religion) != Religions.family_of(c.religion):
		months *= OTHER_FAMILY
	return int(ceil(months))


## Why `tag` cannot send a missionary there ("" if it can).
func blocked(tag: String, p: Province) -> String:
	var c := world.get_country(tag)
	if c == null or p == null or p.is_sea or p.is_wasteland:
		return "Not here"
	if p.owner_id != tag:
		return "Only to our own provinces"
	if p.controller_id != tag:
		return "Not while it is occupied"
	if c.religion == "" or p.religion == c.religion:
		return "Already of our faith"
	if world.missions.has(p.id):
		return "Our missionary is at work here" if world.missions[p.id][0] == tag else "A missionary is at work here"
	if missions_of(tag).size() >= slots(tag):
		return "All our missionaries are at work (%d)" % slots(tag)
	if c.treasury < send_cost(tag, p):
		return "Needs %d ducats" % int(ceil(send_cost(tag, p)))
	return ""


func send(tag: String, p: Province) -> bool:
	if blocked(tag, p) != "":
		return false
	economy.post(world.get_country(tag), "Missionary to %s" % p.name, -send_cost(tag, p))
	world.missions[p.id] = [tag, 0.0]
	economy.changed()  # upkeep in the budget
	return true


func recall(tag: String, p: Province) -> bool:
	if not world.missions.has(p.id) or world.missions[p.id][0] != tag:
		return false
	world.missions.erase(p.id)
	economy.changed()
	return true


## Percent done of the mission there (-1: none).
func progress(p: Province) -> float:
	return float(world.missions[p.id][1]) if world.missions.has(p.id) else -1.0


func monthly() -> void:
	var ended := false
	for id: int in world.missions.keys():
		var p := world.get_province(id)
		var tag: String = world.missions[id][0]
		var c := world.get_country(tag)
		if c == null or p.owner_id != tag or p.controller_id != tag or p.religion == c.religion:
			world.missions.erase(id)  # lost, occupied, or of its faith already
			ended = true
			continue
		var done: float = world.missions[id][1] + 100.0 / months_to_convert(tag, p)
		if done < 99.999:  # (a month's share, added up, may fall a hair short of 100)
			world.missions[id][1] = done
			continue
		world.missions.erase(id)
		ended = true
		p.religion = c.religion
		economy.touch(p)
		converted.emit(id, c.religion)
	if ended:
		economy.changed()


## AI countries send missionaries where they have room and money: the quickest
## conversions first.
func ai_monthly(player: String) -> void:
	var busy := {}
	for id: int in world.missions:
		busy[world.missions[id][0]] = busy.get(world.missions[id][0], 0) + 1
	var room := slots()
	var best := {}  # tag -> [months, province]
	for p: Province in world.ownable_provinces():
		var tag := p.owner_id
		if tag == "" or tag == player or p.controller_id != tag or world.missions.has(p.id) \
				or busy.get(tag, 0) >= room:
			continue
		var c := world.get_country(tag)
		if c == null or c.religion == "" or p.religion == c.religion:
			continue
		var months := months_to_convert(tag, p)
		if not best.has(tag) or months < best[tag][0]:
			best[tag] = [months, p]
	for tag: String in best:
		var p: Province = best[tag][1]
		var c := world.get_country(tag)
		if c.treasury >= send_cost(tag, p) + AI_RESERVE:
			send(tag, p)
