class_name Goods
extends RefCounted
## What provinces produce. Raw goods are worked from the land by commoners and
## tribesmen; manufactured goods are made from raw ones by manufactories
## (see Buildings). Prices are fixed for now; a market (Victoria-style, with
## supply and pop demand) will set them later.
##
## Kinds: "farm" (crops and herds, helped by good land), "cash" (plantation
## crops), "mine" (ores and minerals; land does not matter), "wild" (gathered:
## timber, furs, fish, ivory) and "manufactured". `yield`: raw units a month per
## 10,000 workers before development, land and buildings. Goods with an `era`
## matter little before then (petroleum, uranium): cheap until the market says
## otherwise.

const CATALOGUE := {
	# Crops and herds
	"grain": {"name": "Grain", "kind": "farm", "yield": 10.0, "price": 0.20, "color": "#d9c27a"},
	"livestock": {"name": "Livestock", "kind": "farm", "yield": 6.0, "price": 0.35, "color": "#b98a5a"},
	"wine": {"name": "Wine", "kind": "farm", "yield": 5.0, "price": 0.50, "color": "#8e3b5c"},
	"wool": {"name": "Wool", "kind": "farm", "yield": 5.0, "price": 0.45, "color": "#e8e2d0"},
	"silk": {"name": "Raw silk", "kind": "farm", "yield": 2.0, "price": 1.60, "color": "#e0a0c0"},
	# Plantation crops
	"sugar": {"name": "Sugar", "kind": "cash", "yield": 4.0, "price": 0.80, "color": "#f0e6f2"},
	"tobacco": {"name": "Tobacco", "kind": "cash", "yield": 4.0, "price": 0.75, "color": "#9a7a3a"},
	"cotton": {"name": "Cotton", "kind": "cash", "yield": 5.0, "price": 0.50, "color": "#fafaf4"},
	"spices": {"name": "Spices", "kind": "cash", "yield": 2.0, "price": 1.80, "color": "#c2462e"},
	"tea": {"name": "Tea", "kind": "cash", "yield": 3.0, "price": 1.00, "color": "#5a8a3a"},
	"coffee": {"name": "Coffee", "kind": "cash", "yield": 3.0, "price": 1.00, "color": "#5a3a24"},
	"cocoa": {"name": "Cocoa", "kind": "cash", "yield": 3.0, "price": 1.00, "color": "#7a4a2a"},
	"dyes": {"name": "Dyes", "kind": "cash", "yield": 2.0, "price": 1.50, "color": "#3a4ab8"},
	"rubber": {"name": "Rubber", "kind": "cash", "yield": 3.0, "price": 0.60, "color": "#3a5a2a", "era": 1840},
	# Gathered
	"fish": {"name": "Fish", "kind": "wild", "yield": 8.0, "price": 0.27, "color": "#6b9ab8"},
	"timber": {"name": "Timber", "kind": "wild", "yield": 8.0, "price": 0.25, "color": "#5d7a3e"},
	"naval_supplies": {"name": "Naval supplies", "kind": "wild", "yield": 6.0, "price": 0.40, "color": "#4f6e5a"},
	"furs": {"name": "Furs", "kind": "wild", "yield": 2.0, "price": 1.50, "color": "#7a5a44"},
	"ivory": {"name": "Ivory", "kind": "wild", "yield": 1.0, "price": 3.00, "color": "#f2ead2"},
	"tropical_wood": {"name": "Tropical wood", "kind": "wild", "yield": 5.0, "price": 0.50, "color": "#8a4a2a"},
	# Mined
	"salt": {"name": "Salt", "kind": "mine", "yield": 5.0, "price": 0.50, "color": "#f4f4f4"},
	"kaolin": {"name": "Kaolin", "kind": "mine", "yield": 6.0, "price": 0.30, "color": "#ece8de"},
	"iron": {"name": "Iron", "kind": "mine", "yield": 4.0, "price": 0.60, "color": "#6d6f74"},
	"copper": {"name": "Copper", "kind": "mine", "yield": 3.0, "price": 0.90, "color": "#c0703a"},
	"tin": {"name": "Tin", "kind": "mine", "yield": 3.0, "price": 0.90, "color": "#a9b4bb"},
	"silver": {"name": "Silver", "kind": "mine", "yield": 1.0, "price": 4.00, "color": "#d6dde3"},
	"gold": {"name": "Gold", "kind": "mine", "yield": 0.5, "price": 9.00, "color": "#f2c53d"},
	"gems": {"name": "Gems", "kind": "mine", "yield": 0.5, "price": 7.00, "color": "#c03a7a"},
	"coal": {"name": "Coal", "kind": "mine", "yield": 8.0, "price": 0.25, "color": "#2f2f33"},
	"petroleum": {"name": "Petroleum", "kind": "mine", "yield": 6.0, "price": 0.10, "color": "#1a1a1a", "era": 1859},
	"rare_earths": {"name": "Rare earths", "kind": "mine", "yield": 1.0, "price": 2.00, "color": "#7a3ab8", "era": 1940},
	"uranium": {"name": "Uranium", "kind": "mine", "yield": 0.5, "price": 4.00, "color": "#7ad83a", "era": 1940},
	# Made (from raw goods, in manufactories)
	"cloth": {"name": "Cloth", "kind": "manufactured", "price": 0.90, "color": "#a07ab8"},
	"silk_fabric": {"name": "Silk fabric", "kind": "manufactured", "price": 2.80, "color": "#d070a0"},
	"tools": {"name": "Tools", "kind": "manufactured", "price": 1.10, "color": "#4a4f58"},
	"porcelain": {"name": "Porcelain", "kind": "manufactured", "price": 1.80, "color": "#8ab8e0"},
	"leather": {"name": "Leather", "kind": "manufactured", "price": 0.60, "color": "#8a5a30"},
	"furniture": {"name": "Furniture", "kind": "manufactured", "price": 0.45, "color": "#9a6a3a"},
	"spirits": {"name": "Spirits", "kind": "manufactured", "price": 1.30, "color": "#c09050"},
}


static func has(good: String) -> bool:
	return CATALOGUE.has(good)


static func name_of(good: String) -> String:
	return CATALOGUE[good].name if CATALOGUE.has(good) else "—"


static func kind_of(good: String) -> String:
	return CATALOGUE[good].kind if CATALOGUE.has(good) else ""


static func is_raw(good: String) -> bool:
	return CATALOGUE.has(good) and CATALOGUE[good].kind != "manufactured"


static func price_of(good: String) -> float:
	return CATALOGUE[good].price if CATALOGUE.has(good) else 0.0


static func yield_of(good: String) -> float:
	return CATALOGUE[good].get("yield", 0.0) if CATALOGUE.has(good) else 0.0


static func color_of(good: String) -> Color:
	return Color.from_string(CATALOGUE[good].color, Color.GRAY) if CATALOGUE.has(good) else Color.GRAY
