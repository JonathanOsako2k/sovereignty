class_name Estates
extends RefCounted
## The people of a province by role: nobility, clergy, merchants (burghers:
## towns, trade and crafts), commoners and tribesmen. Commoners and tribesmen
## work the land; every estate takes a share of what the province produces,
## richer per head the higher it stands, and pays tax on it.

const ROLES := ["nobility", "clergy", "merchants", "commoners", "tribesmen"]
const NAMES := {"nobility": "Nobility", "clergy": "Clergy", "merchants": "Merchants",
	"commoners": "Commoners", "tribesmen": "Tribesmen"}
## Share of a province's output each person draws, relative to a commoner.
const INCOME_WEIGHT := {"nobility": 20.0, "clergy": 8.0, "merchants": 6.0, "commoners": 1.0, "tribesmen": 0.7}
## Customary tax, in percent of an estate's income: proportional — the same
## share of what each earns, so the richer estates (nobles, merchants) pay
## more. Tribesmen are hard to assess and pay less; the clergy are exempt.
## Taxing above custom costs the estate's goodwill; below it wins goodwill.
const CUSTOMARY_TAX := {"nobility": 20, "clergy": 0, "merchants": 20, "commoners": 20, "tribesmen": 8}
## The most a government can take from each estate, in percent.
const TAX_MAX := {"nobility": 50, "clergy": 0, "merchants": 50, "commoners": 50, "tribesmen": 25}
## Estates the state cannot tax (for now: the Church).
const TAX_EXEMPT := ["clergy"]
## How much of the province's work each person does.
const LABOUR := {"nobility": 0.0, "clergy": 0.0, "merchants": 0.0, "commoners": 1.0, "tribesmen": 0.5}



static func display(role: String) -> String:
	return NAMES.get(role, role)


static func taxable(role: String) -> bool:
	return not role in TAX_EXEMPT


## Tax rates at custom, in Estates.ROLES order (a new government's policy).
static func customary_rates() -> Array:
	var out := []
	for r: String in ROLES:
		out.append(CUSTOMARY_TAX[r])
	return out


## How a province's people divide at the start: tribal realms and land no
## state rules are mostly tribesmen; towns (development, coasts, capitals)
## have more merchants; theocracies more clergy. Shares, summing to 1.
static func initial_shares(development: int, government: String, owned: bool, coastal: bool,
		capital: bool, nomadic: bool) -> Dictionary:
	if not owned:
		return {"nobility": 0.01, "clergy": 0.01, "merchants": 0.0, "commoners": 0.03, "tribesmen": 0.95}
	var shares := {}
	if government == "tribal":
		shares = {"nobility": 0.02, "clergy": 0.01, "merchants": 0.01, "tribesmen": 0.80}
	else:
		var merchants := clampf(0.01 + 0.01 * (development - 1) + (0.02 if coastal else 0.0) + (0.03 if capital else 0.0), 0.01, 0.15)
		shares = {
			"nobility": 0.015 + (0.005 if capital else 0.0),
			"clergy": 0.03 if government == "theocracy" else 0.01,
			"merchants": merchants,
			"tribesmen": 0.45 if nomadic else 0.0,
		}
	var rest := 1.0
	for r: String in shares:
		rest -= shares[r]
	shares["commoners"] = maxf(rest, 0.0)
	return shares


## Whole people per role from shares, summing exactly to `population`.
static func split(population: int, shares: Dictionary) -> Dictionary:
	var out := {}
	var given := 0
	for r: String in ROLES:
		if r == "commoners":
			continue
		out[r] = int(floor(population * shares.get(r, 0.0)))
		given += out[r]
	out["commoners"] = population - given
	return out
