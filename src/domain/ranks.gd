class_name Ranks
extends RefCounted
## A realm's rank: county, duchy, minor kingdom, major kingdom or empire. The
## higher the title, the more its court is expected to spend — a base and a
## share of its taxes (half for a tribal realm, a quarter for a colony's
## viceregal household) — and the more it can govern and the more ties it can
## keep:
## * governance: the development it governs in full; beyond it, its taxes
##   fall (an overstretched administration), and it grows with the ages;
## * diplomacy: alliances, royal marriages, subjects (not colonies) and
##   subsidies paid count as ties; at its limit it takes on no new ones, and
##   beyond it its subjects grow less loyal; and the envoys it sends.
## A realm rises a rank once it holds the development for it, paying for the
## coronation (NationSystem.raise_rank); it never falls.

enum { COUNTY, DUCHY, MINOR_KINGDOM, MAJOR_KINGDOM, EMPIRE }

const NAMES := ["County", "Duchy", "Minor kingdom", "Major kingdom", "Empire"]
## Development a realm needs for each rank (and, in 1590, where a realm without
## a title of its own stands).
const DEVELOPMENT := [0, 12, 40, 150, 500]
## Court: COURT_BASE ducats a month plus COURT_SHARE of the tax income.
const COURT_BASE := [0.25, 0.75, 2.0, 4.0, 8.0]
const COURT_SHARE := [0.04, 0.06, 0.08, 0.10, 0.12]
const TRIBAL_COURT := 0.5
const COLONIAL_COURT := 0.25
## Development governed in full (in 1590; times the age's GOVERNANCE_AGES).
const GOVERNANCE := [15, 50, 180, 600, 2000]
const GOVERNANCE_AGES := [[1590, 1.0], [1650, 1.25], [1720, 1.5], [1793, 2.0], [1870, 2.5]]
## Beyond it, taxes are (capacity / development) ^ OVERSTRETCH, at least OVERSTRETCH_MIN.
const OVERSTRETCH := 0.5
const OVERSTRETCH_MIN := 0.4
## Ties kept, and envoys sent.
const TIES := [2, 3, 4, 6, 9]
const ENVOYS := [1, 1, 2, 3, 4]
## A subject's loyalty for each tie its overlord keeps beyond its limit.
const LOYALTY_PER_TIE_OVER := -10
## Ducats to be crowned to a rank, and the legitimacy it needs and brings.
const RAISE_COST := [0, 100, 250, 600, 1500]
const RAISE_LEGITIMACY := 50.0
const RAISE_LEGITIMACY_GAIN := 10.0
## Colonial nations rise no higher than this.
const COLONY_MAX := MINOR_KINGDOM

## Titles that hold a realm at a rank, whatever its size (the German princes,
## the Japanese daimyo, the Irish lords).
const TITLE_MAX := [
	["County", COUNTY], ["Lordship", COUNTY],
	["Duchy", DUCHY], ["Principality", DUCHY], ["Margraviate", DUCHY], ["Landgraviate", DUCHY],
	["Prince-Bishopric", DUCHY], ["Archbishopric", DUCHY], ["Clan", DUCHY], ["Order of", DUCHY],
]
## Ranks in 1590 above what size alone would give: the emperors and the
## crowned heads of great kingdoms.
const START := {
	"MNG": EMPIRE, "MUG": EMPIRE, "TUR": EMPIRE, "SPA": EMPIRE,
	"AUS": EMPIRE,  # Rudolf II, Holy Roman Emperor
	"SAF": EMPIRE,  # the shahanshah
	"JAP": MAJOR_KINGDOM,  # Hideyoshi's Japan, its daimyo sworn to him
	"ABY": MINOR_KINGDOM,  # the Solomonic emperors, their realm much reduced
}


static func name_of(rank: int) -> String:
	return NAMES[clampi(rank, 0, NAMES.size() - 1)]


## Where a realm stands by its development, held down by its title.
static func by_size(name: String, development: int) -> int:
	var rank := COUNTY
	for r in DEVELOPMENT.size():
		if development >= DEVELOPMENT[r]:
			rank = r
	for t: Array in TITLE_MAX:
		if name.contains(t[0]):
			rank = mini(rank, t[1])
	return rank


## A realm's rank at the start of a campaign.
static func start_rank(tag: String, name: String, development: int) -> int:
	return maxi(START.get(tag, COUNTY), by_size(name, development))


static func for_colony(name: String, development: int) -> int:
	return mini(by_size(name, development), COLONY_MAX)


## Ducats a month its court costs at normal spending, before inflation.
static func court(rank: int, tax_income: float, government: String, colony: bool) -> float:
	var r := clampi(rank, 0, NAMES.size() - 1)
	var cost: float = COURT_BASE[r] + COURT_SHARE[r] * maxf(tax_income, 0.0)
	if government == "tribal":
		cost *= TRIBAL_COURT
	if colony:
		cost *= COLONIAL_COURT
	return cost


static func age_factor(year: int) -> float:
	var f := 1.0
	for a: Array in GOVERNANCE_AGES:
		if year >= a[0]:
			f = a[1]
	return f


## Development governed in full.
static func governance(rank: int, year: int) -> int:
	return roundi(GOVERNANCE[clampi(rank, 0, NAMES.size() - 1)] * age_factor(year))


## The share of its taxes a realm of this development collects.
static func efficiency(rank: int, year: int, development: int) -> float:
	var cap := governance(rank, year)
	if development <= cap:
		return 1.0
	return maxf(pow(float(cap) / development, OVERSTRETCH), OVERSTRETCH_MIN)


static func ties_max(rank: int) -> int:
	return TIES[clampi(rank, 0, NAMES.size() - 1)]


static func envoys(rank: int) -> int:
	return ENVOYS[clampi(rank, 0, NAMES.size() - 1)]


## The ties a realm keeps: [[kind, tag]] — allies, royal marriages, subjects
## (colonies are governed, not courted) and those it pays subsidies.
static func ties_of(d: Diplomacy, tag: String) -> Array:
	var out := []
	for t: String in d.allies_of(tag):
		out.append(["ally", t])
	for t: String in d.marriages_of(tag):
		out.append(["marriage", t])
	for t: String in d.subjects_of(tag):
		if d.subject_type(t) != "colony":
			out.append(["subject", t])
	for row: Array in d.subsidies():
		if row[0] == tag:
			out.append(["subsidy", row[1]])
	return out
