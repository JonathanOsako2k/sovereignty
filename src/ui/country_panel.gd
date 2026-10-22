class_name CountryPanel
extends DrawerPanel
## Overview of a country: government, capital, territory, people and treasury,
## and its diplomacy. For another country: how it regards us (with every
## reason), our ties, and the actions we can take, each previewed with the
## other side's likely answer. For our own: allies, rivals, subjects, envoys.
## While the player is choosing a country, it offers "Play as …" instead.

signal province_requested(province_id: int)
signal country_requested(tag: String)
signal play_requested(tag: String)
signal locate_requested(tag: String)
signal diplomacy_requested(action: int, tag: String)
signal gift_requested(tag: String, amount: int)
## Paying them a subsidy of this many ducats a month (0: stopping it).
signal subsidy_requested(tag: String, amount: int)
## Forming a nation (Formations).
signal form_requested(id: String)
## Rising a rank (Ranks).
signal rank_requested
## A land deal with them: LandDealPanel.Kind (buy, sell, exchange).
signal land_deal_requested(tag: String, kind: int)
## Declaring war on them, calling our allies or not.
signal war_requested(tag: String, call_allies: bool)
signal treaty_requested(war_id: int, with: String)
signal levies_requested(raise: bool)
signal military_requested
signal budget_requested(tag: String)

var world: WorldState
var actions: DiplomacyActions
## Whether declaring war calls our allies (the toggle above Declare war).
var _call_allies := true
var tag := ""
var player_tag := ""
var choosing := false

var _play_button: Button
var _locate_button: Button


var military: MilitarySystem
var nations: NationSystem
var _gift_amounts := {}  # tag -> ducats last chosen
var _flag: FlagArt


func _init() -> void:
	super()
	wide = true  # long names, reasons and actions need the room
	_flag = FlagArt.new()  # the flag in place of the colour swatch
	_flag.custom_minimum_size = Vector2(60, 40)
	_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_flag)
	_header.move_child(_flag, 0)
	_swatch.visible = false
	_play_button = UITheme.primary_button("")
	_play_button.clip_text = true
	_play_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_play_button.pressed.connect(func(): play_requested.emit(tag))
	_footer.add_child(_play_button)
	_locate_button = UITheme.button("Show on map")
	_locate_button.pressed.connect(func(): locate_requested.emit(tag))
	_footer.add_child(_locate_button)


func show_country(p_world: WorldState, p_tag: String) -> void:
	world = p_world
	tag = p_tag
	refresh()


func refresh() -> void:
	if _dragging:
		return  # rebuilt when the slider is let go (next refresh)
	var c := world.get_country(tag) if world else null
	if c == null:
		return
	var d := world.diplomacy
	var stats := world.country_stats(tag)
	_flag.show_flag(world, tag)
	var government := c.government_type.capitalize() if c.government_type != "" else "—"
	var subtitle := government
	var overlord := d.overlord_of(tag)
	if overlord != "":
		subtitle += " · " + _subject_phrase(d.subject_type(tag), world.get_country(overlord).name)
	elif tag == player_tag and not choosing:
		subtitle += " · your country"
	_set_header(c.name, subtitle, MapModes.country_color(world, tag))
	var capital := world.get_province(c.capital_province_id)
	var rows := [
		["Government", government],
		["Rank", Ranks.name_of(c.rank)],
		["Capital", _province_link(capital) if capital else "None"],
	]
	if overlord != "":
		rows.append([{"vassal": "Overlord", "personal_union": "Sovereign", "tributary": "Suzerain",
			"colony": "Mother country"}[d.subject_type(tag)],
			_country_link(overlord)])
	rows.append(["Provinces", thousands(stats.provinces)])
	if stats.occupied > 0:
		rows.append(["Occupied by others", thousands(stats.occupied)])
	if stats.occupying > 0:
		rows.append(["Occupying", "%s foreign" % thousands(stats.occupying)])
	rows.append_array([
		["Population", thousands(stats.population)],
		["Development", thousands(stats.development)],
		["Area", "%s km²" % thousands(stats.area_km2)],
		["Governance", _governance_text(c, stats.development)],
		["Diplomatic ties", "%d of %d" % [actions.ties(tag), actions.ties_max(tag)] if actions else "—"],
		["Treasury", _budget_link("%s ducats" % thousands(roundi(c.treasury)))],
		["Legitimacy", "%d / 100" % roundi(c.legitimacy)],
		["Stability", "%+d" % c.stability if c.stability != 0 else "0"],
		["Primary culture", Cultures.name_of(c.culture)],
		["State religion", Religions.name_of(c.religion)],
		["Ideas", ", ".join(c.ideas.map(func(i: String) -> String: return Ideas.name_of(i))) if not c.ideas.is_empty()
			else "None"],
	])
	_set_rows(rows)
	_clear_extra()
	if actions != null:
		if not choosing and player_tag != "" and tag != player_tag:
			# At war the war comes first, and peace is the only diplomacy.
			if world.military.at_war(player_tag, tag):
				_war_with()
				_foreign_diplomacy()
			else:
				_foreign_diplomacy()
				_war_with()
		_forces(tag == player_tag and not choosing)
		if tag == player_tag and not choosing:
			_rank()
			_nation()
		_ties(tag == player_tag and not choosing)
	_play_button.visible = choosing
	_play_button.text = "Play as %s" % c.name
	_locate_button.disabled = capital == null


static func _subject_phrase(kind: String, overlord: String) -> String:
	match kind:
		"personal_union":
			return "in personal union with %s" % overlord
		"tributary":
			return "tributary of %s" % overlord
		"colony":
			return "colony of %s" % overlord
	return "vassal of %s" % overlord


# --- Any country's ties ----------------------------------------------------------

## The country's own diplomatic web (ours, or any other's): overlord,
## subjects, allies, marriages, rivals — each name opens that country.
func _ties(own: bool) -> void:
	var d := world.diplomacy
	_section_title("Our diplomacy" if own else "Their diplomacy")
	var overlord := d.overlord_of(tag)
	if overlord != "":
		_tag_list({"vassal": "Overlord", "personal_union": "Sovereign (personal union)",
			"tributary": "Suzerain (tributary)", "colony": "Mother country (colony)"}[d.subject_type(tag)],
			[overlord] as Array[String])
	var subjects := d.subjects_of(tag)
	if not subjects.is_empty():
		_tag_list("Subjects", subjects, func(t: String) -> String:
			return {"vassal": "vassal", "personal_union": "personal union", "tributary": "tributary",
				"colony": "colony"}[d.subject_type(t)])
	_tag_list("Allies", d.allies_of(tag))
	_tag_list("Royal marriages", d.marriages_of(tag))
	_tag_list("Rivals (%d / %d)" % [d.rivals_of(tag).size(), Diplomacy.MAX_RIVALS], d.rivals_of(tag))
	var rivalled_by: Array[String] = []
	for other in actions.active_countries():
		if d.has_rival(other, tag):
			rivalled_by.append(other)
	_tag_list("Counted a rival by", rivalled_by)
	if own:
		_tag_list("Envoys (%d / %d) improving relations with" % [d.envoys_of(tag).size(), actions.envoys_max(tag)], d.envoys_of(tag))


## A titled list of country links (`note` adds e.g. the kind of subject).
func _tag_list(title: String, tags: Array[String], note := Callable()) -> void:
	_extra.add_child(UITheme.label(title, 15, UITheme.TEXT_DIM))
	if tags.is_empty():
		_extra.add_child(UITheme.label("None", 16))
		return
	for t in tags:
		var link := _country_link(t)
		if note.is_valid():
			link.text = "%s (%s)  ›" % [world.get_country(t).name, note.call(t)]
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_extra.add_child(link)


# --- Another country ------------------------------------------------------------------

func _foreign_diplomacy() -> void:
	var d := world.diplomacy
	var me := player_tag
	_section_title("Relations")
	var ties := PackedStringArray()
	if d.overlord_of(tag) == me:
		ties.append({"vassal": "Our vassal", "personal_union": "Our junior partner in personal union",
			"tributary": "Our tributary"}[d.subject_type(tag)])
	if d.overlord_of(me) == tag:
		ties.append("Our overlord")
	if d.is_allied(me, tag):
		ties.append("Allies")
	if d.are_married(me, tag):
		ties.append("Royal marriage")
	if d.has_rival(me, tag):
		ties.append("Our rival")
	if d.has_rival(tag, me):
		ties.append("Counts us a rival")
	if d.is_improving(me, tag):
		ties.append("Our envoy is there")
	if d.subsidy(me, tag) > 0:
		ties.append("We pay them %d a month" % d.subsidy(me, tag))
	if d.subsidy(tag, me) > 0:
		ties.append("They pay us %d a month" % d.subsidy(tag, me))
	if not ties.is_empty():
		var tie_label := UITheme.label(" · ".join(ties), 16)
		tie_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_extra.add_child(tie_label)
	_opinion_block("Their opinion of us", d.opinion(tag, me), d.opinion_reasons(tag, me))
	_opinion_block("Our opinion of them", d.opinion(me, tag), [])

	if world.military.at_war(me, tag):
		var note := UITheme.label("We are at war: no envoys, gifts, marriages or alliances until peace is made.", 14, UITheme.TEXT_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_extra.add_child(note)
		return
	_section_title("Actions")
	var A := DiplomacyActions.Action
	var list := []
	list.append(A.STOP_IMPROVING if d.is_improving(me, tag) else A.IMPROVE_RELATIONS)
	list.append(A.PROPOSE_ALLIANCE if not d.is_allied(me, tag) else A.BREAK_ALLIANCE)
	list.append(A.PROPOSE_MARRIAGE if not d.are_married(me, tag) else A.BREAK_MARRIAGE)
	list.append(A.REMOVE_RIVAL if d.has_rival(me, tag) else A.DECLARE_RIVAL)
	list.append(A.SEND_INSULT)
	list.append(A.RELEASE_SUBJECT if d.overlord_of(tag) == me else A.OFFER_VASSALAGE)
	_gift_row()
	_subsidy_row()
	for action: int in list:
		_extra.add_child(_action_button(action))
	for spec: Array in [["Request to purchase land", "Choose provinces of theirs and a price", LandDealPanel.Kind.BUY],
			["Offer to sell land", "Choose provinces of ours and a price for them", LandDealPanel.Kind.SELL],
			["Exchange territory", "Land of ours for land of theirs, money to even it out", LandDealPanel.Kind.EXCHANGE]]:
		var b := UITheme.button(spec[0] + "\n" + spec[1])
		b.add_theme_font_size_override("font_size", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 52
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var deal_kind: int = spec[2]
		b.pressed.connect(func(): land_deal_requested.emit(tag, deal_kind))
		_extra.add_child(b)


# --- War --------------------------------------------------------------------------

## War with this country: declare it (who would fight on each side), or, at
## war, the score and the way to the peace table (the treaty screen).
func _war_with() -> void:
	if military == null:
		return
	var m := world.military
	var war := m.war_between(player_tag, tag)
	_section_title("War")
	if war.is_empty():
		var why := military.war_blocked(player_tag, tag)
		var detail := why
		if why == "" and not world.diplomacy.allies_of(player_tag).is_empty():
			var call := UITheme.button(("☑  " if _call_allies else "☐  ") + "Call our allies to arms", true)
			call.set_pressed_no_signal(_call_allies)
			call.alignment = HORIZONTAL_ALIGNMENT_LEFT
			call.toggled.connect(func(on: bool):
				_call_allies = on
				refresh())
			_extra.add_child(call)
		if why == "":
			var sides := military.war_sides(player_tag, tag, _call_allies)
			detail = "With us: %s · against us: %s" % [_names(sides.attackers), _names(sides.defenders)]
			if not sides.refused.is_empty():
				detail += " · disloyal, staying out: %s" % _names(sides.refused)
		var b := _two_line_button("Declare war", detail, why != "")
		b.add_theme_color_override("font_color", UITheme.DANGER)
		b.pressed.connect(func(): war_requested.emit(tag, _call_allies))
		_extra.add_child(b)
		return
	_war_summary(war)
	# Leader with leader: the war ends. A leader with anyone else on the other
	# side: that one leaves the war. Two who do not lead: not between them.
	var we_lead := military.is_war_leader(war, player_tag)
	var they_lead := military.is_war_leader(war, tag)
	var detail := "Ends the war"
	if not we_lead and not they_lead:
		var their_lead: String = war.defenders[0] if Military.side_of(war, player_tag) == 0 else war.attackers[0]
		detail = "Neither of us leads: sue %s instead" % world.get_country(their_lead).name
	elif not we_lead:
		detail = "We leave the war; our side fights on"
	elif not they_lead:
		detail = "They leave the war; the rest fight on"
	var b := _two_line_button("Sue for peace", detail, not we_lead and not they_lead)
	var id: int = war.id
	b.pressed.connect(func(): treaty_requested.emit(id, tag))
	_extra.add_child(b)


func _war_summary(war: Dictionary) -> void:
	var side := Military.side_of(war, player_tag)
	var score := military.war_score(war) * (1.0 if side == 0 else -1.0)
	var head := HBoxContainer.new()
	var name_label := UITheme.label(war.name, 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	head.add_child(UITheme.label("%+d" % int(score), 18, _opinion_color(int(score))))
	_extra.add_child(head)
	var ours: Array = war.attackers if side == 0 else war.defenders
	var theirs: Array = war.defenders if side == 0 else war.attackers
	var line := UITheme.label("Our side: %s\nTheirs: %s" % [_names(ours), _names(theirs)], 13, UITheme.TEXT_DIM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.add_child(line)


## Forces: men under arms, levies, ships; for us, our wars and the levies button.
func _forces(own: bool) -> void:
	if military == null:
		return
	var m := world.military
	var standing := 0
	var levies := 0
	var ships := 0
	for a: Army in m.armies.values():
		if a.owner != tag:
			continue
		if a.navy:
			ships += a.regiments.size()
			continue
		for r: Array in a.regiments:
			if r[0] == "levy":
				levies += r[1]
			else:
				standing += r[1]
	_section_title("Our forces" if own else "Their forces")
	var potential := 0
	if levies == 0:
		for p: Province in world.ownable_provinces():
			if p.owner_id == tag and p.controller_id == tag:
				potential += MilitarySystem.levy_men(p)
	for row: Array in [["Standing army", DrawerPanel.thousands(standing)],
			["Levies", DrawerPanel.thousands(levies) if levies > 0 else "At home (about %s)" % DrawerPanel.thousands(potential)],
			["Ships", str(ships)]]:
		var line := HBoxContainer.new()
		var name_label := UITheme.label(row[0], 15, UITheme.TEXT_DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		line.add_child(UITheme.label(row[1], 15))
		_extra.add_child(line)
	var wars := m.wars_of(tag)
	for w: Dictionary in wars:
		if own:
			_war_summary(w)
		else:
			var l := UITheme.label("At war: " + w.name, 14, UITheme.DANGER)
			_extra.add_child(l)
	if own:
		var link := UITheme.link_button("Military tab: mobilisation, manpower, armies")
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		link.pressed.connect(func(): military_requested.emit())
		_extra.add_child(link)


func _names(tags: Array) -> String:
	var out: Array[String] = []
	for t: String in tags:
		out.append(MilitarySystem.short_name(world, t))
	return ", ".join(out)


func _two_line_button(title: String, detail: String, disabled: bool) -> Button:
	var b := UITheme.button(title + ("\n" + detail if detail != "" else ""))
	b.add_theme_font_size_override("font_size", 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = disabled
	b.custom_minimum_size.y = 52
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return b


## A gift of the player's choosing: a slider in ducats (steps of 5, up to four
## times what they would think a proper gift, or what we have), the opinion it
## buys, and Send.
func _gift_row() -> void:
	var c := world.get_country(player_tag)
	var proper := actions.gift_cost(tag)
	var top := clampi(mini(proper * 4, int(c.treasury)) / 5 * 5, 10, 10000)
	var amounts: Array[int] = []
	for v in range(10, top + 1, 5):
		amounts.append(v)
	var chosen: int = _gift_amounts.get(tag, proper)
	var index := 0
	for i in amounts.size():
		if amounts[i] <= chosen:
			index = i
	var head := HBoxContainer.new()
	var title := UITheme.label("Send gift", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var value := UITheme.label("", 16, UITheme.ACCENT)
	head.add_child(value)
	_extra.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var slider := UITheme.level_slider(amounts.size(), index, mini(amounts.size(), 9))
	row.add_child(slider)
	var send := UITheme.button("Send")
	row.add_child(send)
	_extra.add_child(row)
	var note := UITheme.label("", 13, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.add_child(note)
	var show := func(i: int) -> void:
		var amount := amounts[clampi(i, 0, amounts.size() - 1)]
		_gift_amounts[tag] = amount
		value.text = "%d ducats" % amount
		var why := actions.blocked(DiplomacyActions.Action.SEND_GIFT, player_tag, tag, amount)
		send.disabled = why != ""
		note.text = why if why != "" else "Their opinion of us +%d (a proper gift to them: %d ducats)" % [
			int(actions.gift_opinion(tag, amount)), proper]
	show.call(index)
	slider.value_changed.connect(func(v: float): show.call(int(v)))
	slider.drag_started.connect(func(): _dragging = true)
	slider.drag_ended.connect(func(_changed: bool): _dragging = false)
	send.pressed.connect(func(): gift_requested.emit(tag, _gift_amounts.get(tag, proper)))


## A subsidy: ducats a month (steps of 5, up to half our tax income), paid
## until stopped, while we have money and are at peace with them.
func _subsidy_row() -> void:
	var d := world.diplomacy
	var now := d.subsidy(player_tag, tag)
	var budget: Dictionary = military.economy.budget(player_tag) if military != null else {}
	var top := maxi(int(budget.get("tax_income", 0.0) * 0.5) / 5 * 5, maxi(now, 5))
	var steps: Array[int] = []
	for v in range(0, top + 1, 5):
		steps.append(v)
	var chosen: int = now
	var head := HBoxContainer.new()
	var title := UITheme.label("Subsidise them", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var value := UITheme.label("", 16, UITheme.ACCENT)
	head.add_child(value)
	_extra.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var slider := UITheme.level_slider(steps.size(), maxi(steps.find(now), 0), mini(steps.size(), 9))
	row.add_child(slider)
	var set_button := UITheme.button("Set")
	row.add_child(set_button)
	_extra.add_child(row)
	var note := UITheme.label("Paid every month while we have money; they think the better of us for it.", 13, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.add_child(note)
	var why := actions.subsidy_blocked(player_tag, tag, 5) if actions else ""
	if why != "":
		var full := UITheme.label(why, 13, UITheme.DANGER)
		full.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_extra.add_child(full)
	var show := func(i: int) -> void:
		chosen = steps[clampi(i, 0, steps.size() - 1)]
		value.text = "%d a month" % chosen if chosen > 0 else "None"
		set_button.disabled = chosen == now or (why != "" and chosen > 0)
	show.call(maxi(steps.find(now), 0))
	slider.value_changed.connect(func(v: float): show.call(int(v)))
	slider.drag_started.connect(func(): _dragging = true)
	slider.drag_ended.connect(func(_changed: bool): _dragging = false)
	set_button.pressed.connect(func(): subsidy_requested.emit(tag, chosen))


## How much of its land the realm governs in full: "444 of 600 development",
## and, beyond it, the share of taxes its overstretched administration collects.
func _governance_text(c: Country, development: int) -> String:
	var year: int = world.start_date.year
	if nations != null:
		year = nations.campaign.clock.year
	var cap := Ranks.governance(c.rank, year)
	var text := "%s of %s development" % [thousands(development), thousands(cap)]
	if development > cap:
		text += " · taxes ×%.2f" % Ranks.efficiency(c.rank, year, development)
	return text


## Our rank: what it costs and gives, and rising to the next (the coronation).
func _rank() -> void:
	var c := world.get_country(tag)
	if nations == null or c == null:
		return
	_section_title("Rank: %s" % Ranks.name_of(c.rank))
	var year := nations.campaign.clock.year
	var terms := _rank_terms(c.rank, year, c.government_type)
	var about := UITheme.label(terms.left(1).to_upper() + terms.substr(1), 13, UITheme.TEXT_DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.add_child(about)
	if c.rank >= Ranks.EMPIRE:
		return
	var next := c.rank + 1
	var then := UITheme.label("As a %s: %s" % [Ranks.name_of(next).to_lower(), _rank_terms(next, year,
		c.government_type)], 13, UITheme.TEXT_DIM)
	then.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.add_child(then)
	var why := nations.rank_blocked(tag)
	var b := UITheme.primary_button("Rise to %s · %d ducats" % [Ranks.name_of(next).to_lower(),
		int(ceil(nations.raise_cost(tag)))])
	b.disabled = why != ""
	b.pressed.connect(func(): rank_requested.emit())
	_extra.add_child(b)
	if why != "":
		var note := UITheme.label(why, 13, UITheme.DANGER)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_extra.add_child(note)


static func _rank_terms(rank: int, year: int, government: String) -> String:
	var court := "court %s + %d %% of taxes a month" % [str(snappedf(Ranks.COURT_BASE[rank], 0.01)),
		roundi(Ranks.COURT_SHARE[rank] * 100.0)]
	if government == "tribal":
		court += " (half: tribal)"
	return "%s; governs %d development in full; keeps %d ties; %d envoy%s" % [court, Ranks.governance(rank, year),
		Ranks.ties_max(rank), Ranks.envoys(rank), "" if Ranks.envoys(rank) == 1 else "s"]


## Our people's nation, if we can form one: what it takes, and the button.
func _nation() -> void:
	var c := world.get_country(tag)
	if nations == null or c == null:
		return
	for id: String in Formations.for_culture(c.culture):
		if id in c.formed:
			continue
		var f: Dictionary = Formations.CATALOGUE[id]
		_section_title("Form %s" % f.name)
		var about := UITheme.label(f.about, 13, UITheme.TEXT_DIM)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_extra.add_child(about)
		var why := nations.formation_blocked(tag, id)
		var b := UITheme.primary_button("Form %s" % f.name)
		b.disabled = why != ""
		b.pressed.connect(func(): form_requested.emit(id))
		_extra.add_child(b)
		if why != "":
			var note := UITheme.label(why, 13, UITheme.DANGER)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_extra.add_child(note)


func _opinion_block(title: String, value: int, reasons: Array) -> void:
	var row := HBoxContainer.new()
	var name_label := UITheme.label(title, 16, UITheme.TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var v := UITheme.label("%+d" % value if value != 0 else "0", 18, _opinion_color(value))
	row.add_child(v)
	_extra.add_child(row)
	for r: Array in reasons:
		var line := HBoxContainer.new()
		var why := UITheme.label("   " + r[0], 14, UITheme.TEXT_DIM)
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		why.clip_text = true
		why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(why)
		line.add_child(UITheme.label("%+d" % r[1], 14, _opinion_color(r[1])))
		_extra.add_child(line)


static func _opinion_color(v: int) -> Color:
	if v > 0:
		return Color(0.55, 0.82, 0.48)
	if v < 0:
		return UITheme.DANGER
	return UITheme.TEXT


## A two-line button: the action, then why not / what they would say / cost.
func _action_button(action: int) -> Button:
	var A := DiplomacyActions
	var why := actions.blocked(action, player_tag, tag)
	var detail := why
	if why == "":
		if action in A.PROPOSALS:
			var v := actions.evaluate(action, player_tag, tag)
			detail = "%s (%+d)" % ["Likely to accept" if v.accept else "Would refuse", v.total]
		elif action == A.Action.SEND_GIFT:
			detail = "%d ducats" % actions.gift_cost(tag)
		elif action == A.Action.IMPROVE_RELATIONS:
			detail = "+%d a month, up to +%d" % [int(Diplomacy.IMPROVE_PER_MONTH), int(Diplomacy.IMPROVE_CAP)]
	var b := UITheme.button(A.LABELS[action] + ("\n" + detail if detail != "" else ""))
	b.add_theme_font_size_override("font_size", 15)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = why != ""
	b.custom_minimum_size.y = 52
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(func(): diplomacy_requested.emit(action, tag))
	return b


func _budget_link(text: String) -> Button:
	var b := UITheme.link_button(text)
	b.pressed.connect(func(): budget_requested.emit(tag))
	return b


func _province_link(p: Province) -> Button:
	var b := UITheme.link_button(p.name)
	b.pressed.connect(func(): province_requested.emit(p.id))
	return b


func _country_link(t: String) -> Button:
	var b := UITheme.link_button(world.get_country(t).name)
	b.pressed.connect(func(): country_requested.emit(t))
	return b
