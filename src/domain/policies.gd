class_name Policies
extends RefCounted
## Government spending and coinage, set in percent on sliders (user, 19 Oct
## 2026: finer than a few levels): court spending against a normal court, coin
## minted as a share of tax income, and fort, army and navy upkeep against full
## maintenance. Their effects scale smoothly with the setting.

## Policy -> [lowest, highest, slider step, default] in percent.
const RANGES := {
	"court": [50, 250, 5, 100],
	"mint": [0, 30, 1, 0],
	"forts": [0, 150, 5, 100],
	"army": [25, 150, 5, 100],
	"navy": [25, 150, 5, 100],
}
const NAMES := {"court": "Court", "mint": "Minting", "forts": "Fort maintenance", "army": "Army maintenance",
	"navy": "Navy maintenance"}
## Days a fort holds out at full maintenance (before a capital's walls).
const FORT_DAYS := 90.0


static func defaults() -> Dictionary:
	var out := {}
	for key: String in RANGES:
		out[key] = RANGES[key][3]
	return out


static func clamp_value(policy: String, value: int) -> int:
	var r: Array = RANGES[policy]
	return clampi(value, r[0], r[1])


static func is_valid(policy: String, value: Variant) -> bool:
	var r: Array = RANGES[policy]
	return (value is int or value is float) and value >= r[0] and value <= r[1]


# --- Court: legitimacy and the nobles' goodwill for its cost ---

static func court_cost(pct: int) -> float:
	return pct / 100.0


## Legitimacy a month: a frugal court (50 %) costs 0.3, a lavish one (240 %)
## earns 0.4.
static func court_legitimacy(pct: int) -> float:
	if pct < 100:
		return -0.6 * (100 - pct) / 100.0
	return 0.4 * (pct - 100) / 140.0


## The nobles' goodwill target: -12 at a frugal court, +12 at a lavish one.
static func court_nobles(pct: int) -> float:
	if pct < 100:
		return -24.0 * (100 - pct) / 100.0
	return 12.0 * (pct - 100) / 140.0


# --- Minting: coin now, inflation that raises every cost ---

static func mint_share(pct: int) -> float:
	return pct / 100.0


## Inflation (percentage points) a month.
static func mint_inflation(pct: int) -> float:
	return 0.015 * pct


# --- Forts, army and navy ---

static func upkeep_cost(pct: int) -> float:
	return pct / 100.0


## Days a besieger needs for one of our forts (a capital holds longer).
static func fort_days(pct: int) -> float:
	return FORT_DAYS * maxf(0.25, pct / 100.0)


## The spirit an army or navy recovers to: 85 % at full maintenance, all of
## it from about 130 %.
static func max_morale(pct: int) -> float:
	return clampf(0.3 + 0.55 * pct / 100.0, 0.3, 1.0)
