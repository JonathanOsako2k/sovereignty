class_name ProvincePanel
extends DrawerPanel
## Overview of the selected province (progressive disclosure: the key facts
## only): its land, its people by estate, what it produces and is worth, its
## buildings — and, in our own provinces, what we could build. Displays world
## data; requests changes through signals.

signal country_requested(tag: String)
signal debug_transfer_requested(province_id: int)
signal debug_occupy_requested(province_id: int)
signal build_requested(province_id: int, building: String)
signal colony_requested(province_id: int)
signal recruit_requested(province_id: int, unit: String)
signal army_requested(id: int)
signal abandon_colony_requested(province_id: int)

var world: WorldState
var economy: EconomySystem
var colonisation: ColonisationSystem
var military: MilitarySystem
var province_id := 0
var player_tag := ""

var _debug_row: HBoxContainer
var _transfer_button: Button
var _occupy_button: Button


func _init() -> void:
	super()
	_debug_row = HBoxContainer.new()
	_debug_row.add_theme_constant_override("separation", 8)
	_footer.add_child(_debug_row)
	_transfer_button = UITheme.button("Annex (debug)")
	_transfer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transfer_button.pressed.connect(func(): debug_transfer_requested.emit(province_id))
	_debug_row.add_child(_transfer_button)
	_occupy_button = UITheme.button("Occupy (debug)")
	_occupy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_occupy_button.pressed.connect(func(): debug_occupy_requested.emit(province_id))
	_debug_row.add_child(_occupy_button)


func show_province(p_world: WorldState, id: int) -> void:
	world = p_world
	province_id = id
	refresh()


func refresh() -> void:
	var p := world.get_province(province_id) if world else null
	if p == null:
		return
	var owner := world.get_country(p.owner_id)
	var rows: Array
	if p.is_sea:
		var shores: Array[String] = []
		for c in p.coast_ids:
			if shores.size() < 3:
				shores.append(world.get_province(c).name)
		_set_header(p.name, "Lake" if p.terrain == "lake" else "Sea tile", MapModes.SEA_COLOR)
		rows = [
			["Area", "%s km²" % thousands(p.area_km2)],
			["Coasts", str(p.coast_ids.size())],
			["Shores", ", ".join(shores) + ("…" if p.coast_ids.size() > 3 else "") if not shores.is_empty() else "Open water"],
			["Adjacent seas", str(p.neighbour_ids.size())],
			["Ownable", "No"],
		]
	elif p.is_wasteland:
		_set_header(p.name, "Wasteland — impassable", MapModes.WASTE_COLORS.get(p.terrain, MapModes.UNCOLONISED))
		rows = [
			["Topography", Land.display(p.topography)],
			["Vegetation", Land.display(p.vegetation)],
			["Climate", Land.display(p.climate)],
			["Area", "%s km²" % thousands(p.area_km2)],
			["Region", world.region_name(p.region)],
			["Ownable", "No"],
		]
	else:
		_set_header(p.name, owner.name if owner else "Uncolonised", MapModes.country_color(world, p.owner_id))
		var is_capital := owner != null and owner.capital_province_id == p.id
		rows = [
			["Owner", _country_link(p.owner_id) if owner else "Uncolonised"],
			["Controller", _country_link(p.controller_id) if p.is_occupied() and p.controller_id != "" else ("Owner" if not p.is_occupied() else "Rebels")],
			["Population", thousands(p.population)],
			["Development", "%d / 10" % p.development],
			["Produces", Goods.name_of(p.resource)],
			["Unrest", "%.0f %%" % p.unrest],
			["Capital", "Yes" if is_capital else "No"],
		]
		var region := Overseas.region_of(p)
		if region != "":
			rows.append(["Colonial region", Overseas.region_name(region).capitalize() if region == "" else
				Overseas.region_short(region)])
		if world.overseas.has(p.id):
			rows.append(["Overseas", "Yes: no levies; with %d in its region, a colonial nation" % Overseas.NATION_MIN])
		var cores: Array = world.claims.cores_on(p.id)
		var claims: Array = world.claims.claims_on(p.id)
		if owner != null and not p.owner_id in cores:
			var held: Array = world.claims.held.get(p.id, [])
			var years := Claims.CORE_YEARS
			if not held.is_empty() and held[0] == p.owner_id and military != null:
				years = maxi(Claims.CORE_YEARS - (military.clock.day_number() - int(held[1])) / 365, 1)
			rows.append(["Core", "Not yet %s's (in about %d years)" % [MilitarySystem.short_name(world, p.owner_id), years]])
		var others: Array = cores.filter(func(t: String) -> bool: return t != p.owner_id)
		if not others.is_empty():
			rows.append(["Cores of", ", ".join(others.map(func(t: String) -> String: return MilitarySystem.short_name(world, t)))])
		if not claims.is_empty():
			rows.append(["Claimed by", ", ".join(claims.map(func(t: String) -> String: return MilitarySystem.short_name(world, t)))])
	_set_rows(rows)
	_clear_extra()
	var ownable := not p.is_wasteland and not p.is_sea
	if ownable:
		if colonisation != null and p.owner_id == "":
			_colonisation(p)
		if military != null:
			_forces_here(p)
		if economy != null:
			_people(p)
			_production(p)
			_buildings(p)
		if military != null:
			_raise(p)
		_land(p)
	_debug_row.visible = OS.is_debug_build() and ownable and player_tag != ""
	_transfer_button.disabled = p.owner_id == player_tag
	_occupy_button.disabled = p.controller_id == player_tag


# --- Economy -----------------------------------------------------------------------

func _people(p: Province) -> void:
	_section_title("People")
	var incomes := economy.estate_incomes(p, economy.production(p).value)
	var taxes := economy.province_taxes(p)
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 4)
	for h: String in ["", "People", "Earns", "Pays"]:
		_cell(table, h, UITheme.TEXT_DIM, 13)
	for r: String in Estates.ROLES:
		var n: int = p.pops.get(r, 0)
		if n > 0:
			_cell(table, Estates.display(r), UITheme.TEXT_DIM, 15, false)
			_cell(table, thousands(n))
			_cell(table, "%.2f" % incomes[r])
			_cell(table, "%.2f" % taxes.get(r, 0.0) if Estates.taxable(r) else "—")
	_extra.add_child(table)
	_note("Ducats a month. Each estate earns by its numbers and rank — a noble as much as %d commoners — and pays its tax rate on that." % int(Estates.INCOME_WEIGHT.nobility))


func _production(p: Province) -> void:
	_section_title("Production")
	var out := economy.production(p)
	_pair(Goods.name_of(out.raw_good), "%.2f a month" % out.raw_units)
	if out.made_good != "":
		_pair(Goods.name_of(out.made_good) + " (made)", "%.2f a month" % out.made_units)
	_pair("Worth", "%.2f ducats a month" % out.value)
	var owner := world.get_country(p.owner_id)
	if owner != null:
		var tax := 0.0
		var taxes := economy.province_taxes(p)
		for r: String in taxes:
			tax += taxes[r]
		tax += out.value * Buildings.customs_share(p)
		_pair("Taxes to " + owner.name, "%.2f a month" % tax)
	var factors: Array[String] = []
	for f: Array in out.factors.slice(1):
		if absf(f[1] - 1.0) > 0.005:
			factors.append("%s ×%.2f" % [f[0], f[1]])
	if not factors.is_empty():
		_note(" · ".join(factors))
	if not p.found.is_empty():
		var names: Array[String] = []
		for g: String in p.found:
			names.append(Goods.name_of(g))
		_note("Discovered here: " + ", ".join(names))


func _buildings(p: Province) -> void:
	_section_title("Buildings")
	if p.buildings.is_empty() and p.construction.is_empty():
		_note("None.")
	for id: String in p.buildings:
		_pair(Buildings.name_of(id), Buildings.CATALOGUE[id].about, 14)
	if not p.construction.is_empty():
		_pair(Buildings.name_of(p.construction[0]), "Building — %d months left" % p.construction[1])
	if p.owner_id != player_tag or player_tag == "":
		return
	var offers: Array[String] = []
	for id: String in Buildings.CATALOGUE:
		if Buildings.relevant(id, p):
			offers.append(id)
	if offers.is_empty():
		return
	_section_title("Build")
	for id: String in offers:
		var b: Dictionary = Buildings.CATALOGUE[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := UITheme.label(b.name, 16)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var button := UITheme.button("%d ducats" % int(ceil(economy.building_cost(player_tag, id))))
		var why := economy.build_blocked(player_tag, id, p)
		button.disabled = why != ""
		button.pressed.connect(func(): build_requested.emit(province_id, id))
		row.add_child(button)
		_extra.add_child(row)
		_note("%s · %d months" % [b.about, b.months])
		if why != "":
			_note(why, UITheme.DANGER)


## Uncolonised land: who is settling it and how far they are, or what it
## would take us — the pace with every factor named, and the reason if we can't.
func _colonisation(p: Province) -> void:
	_section_title("Colonisation")
	if p.colonist != "":
		_pair("Settled by", world.get_country(p.colonist).name)
		var left := colonisation.months_to_settle(p.colonist, p)
		_pair("Progress", "%d %%%s" % [int(p.colony_progress), " · %s to go" % _duration(left) if left > 0 else ""])
		if p.colonist == player_tag:
			var abandon := UITheme.button("Abandon the colony")
			abandon.add_theme_color_override("font_color", UITheme.DANGER)
			abandon.pressed.connect(func(): abandon_colony_requested.emit(province_id))
			_extra.add_child(abandon)
		return
	if player_tag == "":
		return
	var r := colonisation.rate(player_tag, p)
	var parts: Array[String] = []
	for f: Array in r.factors:
		parts.append("%s ×%.2f" % [f[0], f[1]])
	_note(" · ".join(parts))
	var months := colonisation.months_to_settle(player_tag, p)
	_pair("Our settlers would take", _duration(months) if months > 0 else "—")
	var why := colonisation.blocked(player_tag, p)
	var found := UITheme.primary_button("Found a colony · %d ducats" % int(ceil(colonisation.founding_cost(player_tag, p))))
	found.disabled = why != ""
	found.clip_text = true
	found.pressed.connect(func(): colony_requested.emit(province_id))
	_extra.add_child(found)
	if why != "":
		_note(why, UITheme.DANGER)


static func _duration(months: int) -> String:
	if months < 0:
		return "forever"
	return "%d months" % months if months < 24 else "about %d years" % roundi(months / 12.0)


## Armies and fleets here (and off its coast), and a siege under way.
func _forces_here(p: Province) -> void:
	var m := world.military
	var here: Array[Army] = m.armies_at(p.id)
	here.append_array(m.armies_at(p.id, true))  # fleets in its dock
	for s: int in p.sea_ids:
		here.append_array(m.armies_at(s, true))
	var siege: Dictionary = m.sieges.get(p.id, {})
	var dock := "dock" in p.buildings
	if here.is_empty() and siege.is_empty() and not "fort" in p.buildings and not dock:
		return
	_section_title("Forces")
	if "fort" in p.buildings:
		_note("Fortified: a siege takes about %d days." % int(military.siege_days(p)))
	if dock:
		_note("Dock: fleets of %s and its friends berth here (repairs, half upkeep); ships are built here." %
			world.get_country(p.controller_id).name if world.get_country(p.controller_id) else "Dock")
	if not siege.is_empty():
		_pair("Siege by " + world.get_country(siege.by).name, "%d of %d days" % [int(siege.progress), int(military.siege_days(p))])
	for a: Army in here:
		var b := UITheme.link_button("%s — %s" % [a.name, DrawerPanel.thousands(a.men()) if not a.navy else "%d ships" % a.regiments.size()])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id := a.id
		b.pressed.connect(func(): army_requested.emit(id))
		_extra.add_child(b)


## Regiments (and ships, on a coast) our realm raises in this age, here.
func _raise(p: Province) -> void:
	if p.owner_id != player_tag or player_tag == "" or p.controller_id != player_tag:
		return
	var year := military.clock.year
	var units: Array[String] = UnitTypes.recruitable(world, player_tag, year, "land")
	if "dock" in p.buildings:
		units.append_array(UnitTypes.recruitable(world, player_tag, year, "sea"))
	var queued := world.military.recruiting.filter(func(j: Array) -> bool: return j[1] == p.id)
	if units.is_empty() and queued.is_empty():
		return
	_section_title("Raise")
	if p.is_coastal and not "dock" in p.buildings and not UnitTypes.recruitable(world, player_tag, year, "sea").is_empty():
		_note("Ships are built at a dock: build one here (Buildings) to launch a fleet.")
	for j: Array in queued:
		_pair(UnitTypes.name_of(j[2]), "ready in %d days" % j[3])
	for id: String in units:
		var u := UnitTypes.get_type(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := UITheme.label(u.name, 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
		var button := UITheme.button("%d ducats" % int(ceil(military.recruit_cost(player_tag, id))))
		var why := military.recruit_blocked(player_tag, p, id)
		button.disabled = why != ""
		button.pressed.connect(func(): recruit_requested.emit(province_id, id))
		row.add_child(button)
		_extra.add_child(row)
		_note("%s men · attack %.1f, defence %.1f · %d months%s" % [DrawerPanel.thousands(u.men), u.attack, u.defence,
			u.months, " · " + why if why != "" and not why.begins_with("Needs") else ""])


## The land, below the economy: what colonisation and armies will read.
func _land(p: Province) -> void:
	_section_title("Land")
	_pair("Topography", Land.display(p.topography))
	_pair("Vegetation", Land.display(p.vegetation))
	_pair("Climate", Land.display(p.climate))
	_pair("Elevation", "%s m" % thousands(p.elevation))
	_pair("Area", "%s km²" % thousands(p.area_km2))
	_pair("Division", p.division)
	_pair("Region", world.region_name(p.region))
	_pair("Coastal", "Yes (%d sea tiles)" % p.sea_ids.size() if p.is_coastal else "No")
	_pair("Neighbours", str(p.neighbour_ids.size()))


func _cell(table: GridContainer, text: String, color := UITheme.TEXT, size := 15, right := true) -> void:
	var l := UITheme.label(text, size, color)
	if right:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_child(l)


## A name and a value on one line, inside the extra sections.
func _pair(title: String, value: String, value_size := 15) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := UITheme.label(title, 15, UITheme.TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var v := UITheme.label(value, value_size)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	_extra.add_child(row)


func _note(text: String, color := UITheme.TEXT_DIM) -> void:
	var l := UITheme.label(text, 13, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	_extra.add_child(l)


func _country_link(tag: String) -> Button:
	var b := UITheme.link_button(world.get_country(tag).name)
	b.pressed.connect(func(): country_requested.emit(tag))
	return b
