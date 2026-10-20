class_name Land
extends RefCounted
## EU5-style description of a province's land, the basis for colonisation:
## what the ground is shaped like (topography), what grows on it (vegetation)
## and its climate. Generated from real data (Köppen-Geiger climate, ETOPO1
## elevation) by tools/world1590/land_1590.gd; vegetation reflects 1590
## settlement (farmland where people were thick on the ground).

const TOPOGRAPHY := ["flatland", "hills", "plateau", "mountains", "wetlands"]
const VEGETATION := ["desert", "sparse", "grasslands", "farmland", "woods", "forest", "jungle"]
const CLIMATE := ["equatorial", "tropical", "subtropical", "mediterranean", "oceanic", "continental",
	"subarctic", "arctic", "hot_arid", "cold_arid"]


## "hot_arid" -> "Hot arid".
static func display(value: String) -> String:
	if value == "":
		return "—"
	var text := value.replace("_", " ")
	return text.left(1).to_upper() + text.substr(1)


static func is_valid(topography: String, vegetation: String, climate: String) -> bool:
	return topography in TOPOGRAPHY and vegetation in VEGETATION and climate in CLIMATE
