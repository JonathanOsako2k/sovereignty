extends RefCounted
## World regions, province quotas, population estimates, terrain rules and
## historical names used by build_world.gd.

const TOTAL_PROVINCES := 5000

## Region id -> [display name, share of all provinces].
const REGIONS := {
	# 15 provinces moved from inland China to Germany at the user's request
	# (16 Oct 2026): Europe 1265, China/Korea/Japan 885.
	"EUR": ["Europe", 0.253],
	"CJK": ["China, Korea and Japan", 0.177],
	"IND": ["Indian Subcontinent", 0.13],
	"MECA": ["Middle East and Central Asia", 0.11],
	"AFR": ["Africa", 0.10],
	"SEA": ["South East Asia", 0.08],
	"NAM": ["North America", 0.065],
	"SAM": ["South America", 0.045],
	"OCE": ["Oceania and Pacific Islands", 0.015],
	"OTH": ["Other Territories", 0.025],
}

## Natural Earth ADM0_A3 code -> region. Zone overrides (see zone_key) refine
## Russia, China and the USA.
const COUNTRY_REGION := {
	# Europe
	"ALB": "EUR", "AND": "EUR", "AUT": "EUR", "BEL": "EUR", "BGR": "EUR", "BIH": "EUR", "BLR": "EUR",
	"CHE": "EUR", "CZE": "EUR", "DEU": "EUR", "DNK": "EUR", "ESP": "EUR", "EST": "EUR", "FIN": "EUR",
	"FRA": "EUR", "FRO": "EUR", "GBR": "EUR", "GGY": "EUR", "GRC": "EUR", "HRV": "EUR", "HUN": "EUR",
	"IMN": "EUR", "IRL": "EUR", "ISL": "EUR", "ITA": "EUR", "JEY": "EUR", "KOS": "EUR", "LIE": "EUR",
	"LTU": "EUR", "LUX": "EUR", "LVA": "EUR", "MCO": "EUR", "MDA": "EUR", "MKD": "EUR", "MLT": "EUR",
	"MNE": "EUR", "NLD": "EUR", "NOR": "EUR", "POL": "EUR", "PRT": "EUR", "ROU": "EUR", "RUS": "EUR",
	"SMR": "EUR", "SRB": "EUR", "SVK": "EUR", "SVN": "EUR", "SWE": "EUR", "UKR": "EUR", "VAT": "EUR",
	"ALD": "EUR",
	# Middle East and Central Asia
	"TUR": "MECA", "CYP": "MECA", "CYN": "MECA", "SYR": "MECA", "LBN": "MECA", "ISR": "MECA",
	"PSX": "MECA", "JOR": "MECA", "IRQ": "MECA", "IRN": "MECA", "SAU": "MECA", "YEM": "MECA",
	"OMN": "MECA", "ARE": "MECA", "QAT": "MECA", "BHR": "MECA", "KWT": "MECA", "GEO": "MECA",
	"ARM": "MECA", "AZE": "MECA", "AFG": "MECA", "UZB": "MECA", "TKM": "MECA", "TJK": "MECA",
	"KGZ": "MECA", "KAZ": "MECA", "CHN_XJ": "MECA",
	# Indian subcontinent
	"IND": "IND", "PAK": "IND", "BGD": "IND", "NPL": "IND", "BTN": "IND", "LKA": "IND", "MDV": "IND",
	"KAS": "IND",
	# China, Korea, Japan
	"CHN": "CJK", "CHN_NE": "CJK", "TWN": "CJK", "HKG": "CJK", "MAC": "CJK", "KOR": "CJK",
	"PRK": "CJK", "JPN": "CJK",
	# South East Asia
	"MMR": "SEA", "THA": "SEA", "LAO": "SEA", "KHM": "SEA", "VNM": "SEA", "MYS": "SEA", "SGP": "SEA",
	"BRN": "SEA", "IDN": "SEA", "PHL": "SEA", "TLS": "SEA",
	# Africa
	"DZA": "AFR", "AGO": "AFR", "BEN": "AFR", "BWA": "AFR", "BFA": "AFR", "BDI": "AFR", "CMR": "AFR",
	"CPV": "AFR", "CAF": "AFR", "TCD": "AFR", "COM": "AFR", "COD": "AFR", "COG": "AFR", "CIV": "AFR",
	"DJI": "AFR", "EGY": "AFR", "GNQ": "AFR", "ERI": "AFR", "ETH": "AFR", "GAB": "AFR", "GMB": "AFR",
	"GHA": "AFR", "GIN": "AFR", "GNB": "AFR", "KEN": "AFR", "LSO": "AFR", "LBR": "AFR", "LBY": "AFR",
	"MDG": "AFR", "MWI": "AFR", "MLI": "AFR", "MRT": "AFR", "MUS": "AFR", "MAR": "AFR", "MOZ": "AFR",
	"NAM": "AFR", "NER": "AFR", "NGA": "AFR", "RWA": "AFR", "STP": "AFR", "SEN": "AFR", "SYC": "AFR",
	"SLE": "AFR", "SOM": "AFR", "SOL": "AFR", "ZAF": "AFR", "SDS": "AFR", "SDN": "AFR", "SWZ": "AFR",
	"TZA": "AFR", "TGO": "AFR", "TUN": "AFR", "UGA": "AFR", "ZMB": "AFR", "ZWE": "AFR", "SAH": "AFR",
	"SHN": "AFR",
	# North America
	"USA": "NAM", "USA_AK": "NAM", "CAN": "NAM", "MEX": "NAM", "GTM": "NAM", "BLZ": "NAM", "SLV": "NAM",
	"HND": "NAM", "NIC": "NAM", "CRI": "NAM", "PAN": "NAM", "CUB": "NAM", "JAM": "NAM", "HTI": "NAM",
	"DOM": "NAM", "PRI": "NAM", "BHS": "NAM", "TCA": "NAM", "CYM": "NAM", "BMU": "NAM", "VGB": "NAM",
	"VIR": "NAM", "AIA": "NAM", "KNA": "NAM", "ATG": "NAM", "MSR": "NAM", "DMA": "NAM", "LCA": "NAM",
	"VCT": "NAM", "BRB": "NAM", "GRD": "NAM", "TTO": "NAM", "ABW": "NAM", "CUW": "NAM", "SXM": "NAM",
	"MAF": "NAM", "BLM": "NAM", "SPM": "NAM",
	# South America
	"COL": "SAM", "VEN": "SAM", "GUY": "SAM", "SUR": "SAM", "ECU": "SAM", "PER": "SAM", "BOL": "SAM",
	"BRA": "SAM", "PRY": "SAM", "URY": "SAM", "ARG": "SAM", "CHL": "SAM", "FLK": "SAM",
	# Oceania and the Pacific
	"AUS": "OCE", "NZL": "OCE", "PNG": "OCE", "SLB": "OCE", "VUT": "OCE", "NCL": "OCE", "FJI": "OCE",
	"WSM": "OCE", "ASM": "OCE", "TON": "OCE", "NIU": "OCE", "COK": "OCE", "PYF": "OCE", "PCN": "OCE",
	"KIR": "OCE", "TUV": "OCE", "MHL": "OCE", "FSM": "OCE", "PLW": "OCE", "GUM": "OCE", "MNP": "OCE",
	"NRU": "OCE", "WLF": "OCE", "NFK": "OCE", "ATC": "OCE", "IOA": "OCE", "USA_HI": "OCE",
	# Other territories
	"GRL": "OTH", "MNG": "OTH", "RUS_A": "OTH", "CHN_TB": "OTH", "CHN_IM": "OTH", "ATF": "OTH",
	"HMD": "OTH", "SGS": "OTH", "IOT": "OTH", "ATA": "OTH",
}

## Countries whose Natural Earth polygons include far-flung overseas territory
## that had nothing to do with that country in 1590 (e.g. French Guiana).
const EUROPEAN_ONLY := ["FRA", "NLD", "NOR", "DNK", "GBR", "BEL", "DEU", "ITA"]


static func in_europe_box(lat: float, lon: float) -> bool:
	return lat > 34.0 and lat < 72.0 and lon > -32.0 and lon < 45.0


## Population/region zone for a land pixel. Mostly the modern country, with
## sub-zones where one modern state spans very different 1590 worlds.
static func zone_key(code: String, lat: float, lon: float) -> String:
	match code:
		"RUS":
			return "RUS" if lon > 0.0 and lon < 60.0 else "RUS_A"
		"CHN":
			if lon < 96.0 and lat > 35.5:
				return "CHN_XJ"
			if lat > 27.8 and lat < 39.0 and lon < (101.0 if lat < 34.5 else 100.5):
				return "CHN_TB"
			if (lat > 41.5 and lon < 119.5) or (lat > 39.8 and lon < 106.0) or (lat > 38.6 and lat < 41.5 and lon > 105.0 and lon < 111.5):
				return "CHN_IM"
			if lat > 42.0 and lon >= 119.5:
				return "CHN_NE"
			return "CHN"
		"USA":
			if lon < -150.0 and lat < 30.0:
				return "USA_HI"
			if lon < -130.0 and lat > 50.0:
				return "USA_AK"
			return "USA"
	if code in EUROPEAN_ONLY and not in_europe_box(lat, lon):
		if lon < -30.0:
			return "OVERSEAS_NAM" if lat > 12.0 else "OVERSEAS_SAM"
		return "OVERSEAS_AFR"
	return code


static func zone_region(zone: String) -> String:
	if zone.begins_with("OVERSEAS_"):
		return zone.trim_prefix("OVERSEAS_")
	return COUNTRY_REGION.get(zone, "OTH")


## Approximate population around 1600, in thousands, per zone. Sources:
## McEvedy & Jones (1978) style regional estimates, rounded. Used to spread
## provinces (denser where people lived) and to seed province populations.
const POPULATION_K := {
	# Europe
	"ALB": 300, "AND": 5, "AUT": 1800, "BEL": 1300, "BGR": 1200, "BIH": 600, "BLR": 1700, "CHE": 1000,
	"CZE": 2600, "DEU": 15000, "DNK": 600, "ESP": 8100, "EST": 250, "FIN": 300, "FRA": 18500, "FRO": 4,
	"GBR": 4900, "GGY": 8, "GRC": 1500, "HRV": 700, "HUN": 1200, "IMN": 10, "IRL": 1000, "ISL": 50,
	"ITA": 13100, "JEY": 10, "KOS": 200, "LIE": 3, "LTU": 700, "LUX": 80, "LVA": 350, "MCO": 2,
	"MDA": 250, "MKD": 300, "MLT": 30, "MNE": 120, "NLD": 1500, "NOR": 450, "POL": 3500, "PRT": 1100,
	"ROU": 2000, "RUS": 8500, "SMR": 3, "SRB": 900, "SVK": 900, "SVN": 350, "SWE": 800, "UKR": 4000,
	"VAT": 1, "ALD": 5,
	# Middle East and Central Asia
	"TUR": 7500, "CYP": 150, "CYN": 50, "SYR": 1300, "LBN": 300, "ISR": 200, "PSX": 150, "JOR": 150,
	"IRQ": 1200, "IRN": 7000, "SAU": 1600, "YEM": 2000, "OMN": 350, "ARE": 40, "QAT": 20, "BHR": 30,
	"KWT": 20, "GEO": 600, "ARM": 300, "AZE": 600, "AFG": 3000, "UZB": 2500, "TKM": 300, "TJK": 700,
	"KGZ": 300, "KAZ": 700, "CHN_XJ": 800,
	# Indian subcontinent
	"IND": 110000, "PAK": 11000, "BGD": 11000, "NPL": 1500, "BTN": 100, "LKA": 1500, "MDV": 40, "KAS": 800,
	# China, Korea, Japan
	"CHN": 155000, "CHN_NE": 600, "TWN": 150, "HKG": 20, "MAC": 10, "KOR": 6500, "PRK": 3500, "JPN": 17000,
	# South East Asia
	"MMR": 3500, "THA": 2200, "LAO": 600, "KHM": 1200, "VNM": 5000, "MYS": 500, "SGP": 3, "BRN": 50,
	"IDN": 10000, "PHL": 900, "TLS": 100,
	# Africa
	"EGY": 3500, "LBY": 500, "TUN": 800, "DZA": 2500, "MAR": 3000, "SAH": 30, "MRT": 200, "MLI": 1600,
	"NER": 1000, "TCD": 1000, "SDN": 2500, "SDS": 900, "ERI": 300, "ETH": 4000, "DJI": 40, "SOM": 500,
	"SOL": 300, "KEN": 2000, "UGA": 1500, "TZA": 2500, "RWA": 500, "BDI": 400, "COD": 6000, "COG": 400,
	"GAB": 200, "GNQ": 40, "CAF": 800, "CMR": 2000, "NGA": 10000, "BEN": 700, "TGO": 400, "GHA": 1500,
	"CIV": 1200, "LBR": 300, "SLE": 500, "GIN": 1000, "GNB": 200, "GMB": 150, "SEN": 1000, "BFA": 1600,
	"AGO": 1500, "ZMB": 600, "MWI": 600, "MOZ": 1500, "ZWE": 800, "BWA": 100, "NAM": 100, "ZAF": 1200,
	"LSO": 50, "SWZ": 50, "MDG": 1200, "COM": 40, "CPV": 15, "STP": 10,
	# North America
	"USA": 2200, "USA_AK": 50, "CAN": 400, "MEX": 2500, "GTM": 500, "BLZ": 40, "SLV": 120, "HND": 150,
	"NIC": 120, "CRI": 30, "PAN": 50, "CUB": 25, "JAM": 3, "HTI": 20, "DOM": 30, "PRI": 15, "BHS": 1,
	"TTO": 15,
	# South America
	"COL": 1000, "VEN": 300, "GUY": 30, "SUR": 30, "ECU": 600, "PER": 1300, "BOL": 700, "BRA": 1500,
	"PRY": 200, "URY": 10, "ARG": 400, "CHL": 600,
	# Oceania
	"AUS": 300, "NZL": 100, "PNG": 600, "SLB": 100, "VUT": 50, "NCL": 40, "FJI": 100, "WSM": 40,
	"TON": 30, "PYF": 50, "FSM": 20, "GUM": 20, "USA_HI": 250,
	# Other
	"GRL": 5, "MNG": 600, "RUS_A": 200, "CHN_TB": 1500, "CHN_IM": 600,
}

## Terrain classes. Index order is stored per pixel by the generator.
const TERRAINS := ["plains", "forest", "hills", "mountains", "marsh", "desert", "steppe", "jungle", "tundra", "glacier"]

## Relative population density by terrain (people follow farmland and water).
const TERRAIN_POP := {
	"plains": 1.0, "forest": 0.55, "hills": 0.7, "mountains": 0.3, "marsh": 0.4,
	"desert": 0.05, "steppe": 0.35, "jungle": 0.35, "tundra": 0.03, "glacier": 0.0,
}
## Population weight of land held by tribal polities (herders, forest peoples)
## against farmland in the same zone (user, 19 Oct 2026: Southern Mongolia had
## 5 million people, priced as part of Ming China).
const TRIBAL_POP := 0.04

## Relative province density by terrain (sparse land gets bigger provinces).
const TERRAIN_SEED := {
	"plains": 1.0, "forest": 0.8, "hills": 0.85, "mountains": 0.6, "marsh": 0.7,
	"desert": 0.25, "steppe": 0.6, "jungle": 0.6, "tundra": 0.3, "glacier": 0.1,
}

## Natural Earth geography region -> terrain. Unlisted names fall back to the
## per-class defaults in geo_class_terrain.
const GEO_NAME_TERRAIN := {
	"PLATEAU OF TIBET": "mountains", "ALTIPLANO": "mountains", "PAMIRS": "mountains",
	"KAZAKH UPLAND": "steppe", "MONGOLIAN PLATEAU": "steppe", "Khorat Plat.": "plains",
	"CENTRAL SIBERIAN PLATEAU": "forest", "PUTORANA PLATEAU": "tundra", "Aldan Upland": "forest",
	"STANOVOY UPLAND": "forest", "BRAZILIAN HIGHLANDS": "steppe", "PLANALTO CENTRAL": "steppe",
	"Campos Sertão": "steppe", "PLANALTO DO MATO GROSSO": "steppe", "GUIANA SHIELD": "jungle",
	"WESTERN PLATEAU": "desert", "KIMBERLEY PLATEAU": "steppe", "Ustyurt Plateau": "desert",
	"COLORADO PLATEAU": "desert", "COLUMBIA PLAT.": "steppe", "FRASER PLATEAU": "forest",
	"YUKON PLATEAU": "forest", "Edwards Plateau": "steppe", "ALTI-PLANICIE MEXICANA": "steppe",
	"DECCAN PLATEAU": "plains", "CENTRAL RUSSIAN UPLAND": "plains", "Superior Upland": "forest",
	"CAATINGAS": "steppe", "PUNJAB": "plains",
	"CANADIAN SHIELD": "forest",
	"PONTIC STEPPE": "steppe", "KAZAKH STEPPE": "steppe", "GREAT PLAINS": "steppe", "PAMPAS": "steppe",
	"LLANOS": "steppe", "SAHEL": "steppe", "TURAN LOWLAND": "desert", "Iwembere Steppe": "steppe",
	"CHACO AUSTRAL": "steppe", "CHACO BOREAL": "steppe", "GRAN CHACO": "steppe",
	"NULLARBOR PLAIN": "desert", "NORTH SLOPE": "tundra", "Yukon Flats": "forest",
	"LES LAURENTIDES": "forest",
	"AMAZON BASIN": "jungle", "CONGO BASIN": "jungle", "TARIM BASIN": "desert", "Junggar Basin": "desert",
	"Qaidam Basin": "desert", "GREAT BASIN": "desert", "SICHUAN BASIN": "plains",
	"GREAT ARTESIAN BASIN": "steppe", "MURRAY-DARLING BASIN": "steppe",
	"CASPIAN DEPRESSION": "steppe", "KOLYMA LOWLAND": "tundra", "NORTH SIBERIAN LOWLAND": "tundra",
	"VYCHEGDA LOWLAND": "forest", "WESTERN SIBERIAN PLAIN": "forest",
	"PIEDMONT": "hills", "SELVAS": "jungle", "YUNGAS": "jungle",
	"ANATOLIA": "hills", "BALUCHISTAN": "desert", "Ogaden": "desert", "PATAGONIA": "steppe",
	"Mesopotamia": "plains", "Hexi Corridor": "desert", "LAPLAND": "forest", "SIBERIA": "forest",
	"ALASKA": "forest", "Riverina": "plains", "Banaadir Coast": "steppe", "JUTLAND": "plains",
	"SUDD": "marsh", "KNUD RASMUSSEN LAND": "tundra",
	"Fergana Valley": "plains", "Central Valley": "plains", "GREAT RIFT VALLEY": "hills",
	"Valle Longitudinal": "plains",
	"Danube Delta": "marsh", "Volga Delta": "marsh", "Lena Delta": "marsh", "Niger Delta": "marsh",
	"Amazon Delta": "marsh", "Zambezi Delta": "marsh", "Mississippi Delta": "marsh",
	"Irrawaddy Delta": "marsh", "Nile Delta": "plains", "Ganges Delta": "plains", "Mekong Delta": "plains",
	"Indus Delta": "plains",
}

const GEO_CLASS_TERRAIN := {
	"Range/mtn": "mountains", "Plateau": "hills", "Desert": "desert", "Tundra": "tundra",
	"Wetlands": "marsh", "Plain": "plains", "Basin": "plains", "Lowland": "plains",
	"Foothills": "hills", "Geoarea": "", "Valley": "plains", "Delta": "plains",
}

## Draw order: broad areas first so ranges and deserts win where they overlap.
const GEO_CLASS_ORDER := ["Geoarea", "Lowland", "Plain", "Basin", "Plateau", "Tundra", "Wetlands",
	"Valley", "Delta", "Foothills", "Desert", "Range/mtn"]


static func geo_terrain(cla: String, name: String) -> String:
	if GEO_NAME_TERRAIN.has(name):
		return GEO_NAME_TERRAIN[name]
	return GEO_CLASS_TERRAIN.get(cla, "")


## Fallback terrain from latitude/longitude where no geography region applies.
static func climate_terrain(lat: float, lon: float, noise: float) -> String:
	var alat := absf(lat)
	if alat >= 66.0:
		return "tundra"
	if lat >= 58.0:
		return "forest"
	var tropical_forest := (lon > -15.0 and lon < 32.0 and alat < 7.0) \
		or (lon > -82.0 and lon < -35.0 and alat < 8.0) \
		or (lon > 94.0 and lon < 155.0 and alat < 9.0) \
		or (lon > 97.0 and lon < 110.0 and lat > 8.0 and lat < 20.0 and noise > 0.45)
	if tropical_forest:
		return "jungle"
	# Heavier woodland in the Russian and North American forest belts; long-farmed
	# western Europe and the rest default to mostly open country.
	var forest_belt := alat > 50.0 and alat < 58.0 and (lon > 22.0 or lon < -50.0)
	var forest_share := 0.55 if forest_belt else 0.25
	return "forest" if noise < forest_share else "plains"


## Historical names for well-known places whose modern names postdate 1590.
const HISTORIC_NAMES := {
	"Istanbul": "Constantinople", "İzmir": "Smyrna", "Izmir": "Smyrna", "Thessaloniki": "Salonica",
	"Edirne": "Adrianople", "Ankara": "Angora", "Trabzon": "Trebizond", "Antalya": "Adalia",
	"Plovdiv": "Philippopolis", "Bratislava": "Pressburg", "Ljubljana": "Laibach", "Gdańsk": "Danzig",
	"Gdansk": "Danzig", "Wrocław": "Breslau", "Wroclaw": "Breslau", "Szczecin": "Stettin",
	"Kaliningrad": "Königsberg", "Tallinn": "Reval", "Tartu": "Dorpat", "Vilnius": "Vilna",
	"Lviv": "Lwów", "Kyiv": "Kiev", "Bilhorod-Dnistrovskyi": "Akkerman", "Odesa": "Hacıbey",
	"Odessa": "Hacıbey", "Sevastopol": "Akhtiar", "Simferopol": "Aqmescit", "Dnipro": "Samar",
	"Dnipropetrovsk": "Samar", "Zaporizhzhia": "Khortytsia", "Zaporizhzhya": "Khortytsia",
	"Saint Petersburg": "Neva", "St. Petersburg": "Neva", "Volgograd": "Tsaritsyn",
	"Yekaterinburg": "Iset", "Krasnodar": "Kuban", "Rostov": "Don", "Orenburg": "Yaik",
	"Murmansk": "Kola", "Kirov": "Khlynov", "Trollhättan": "Bohuslän", "Novorossiysk": "Sujuk-Kale", "Makhachkala": "Tarki",
	"Tel Aviv-Yafo": "Jaffa", "Tel Aviv": "Jaffa", "Riyadh": "Hajr", "Doha": "Bida",
	"Ashgabat": "Nisa", "Mumbai": "Bombaim", "Kolkata": "Satgaon", "Chennai": "Mylapore",
	"Bengaluru": "Bangalore", "Hyderabad": "Golconda", "Karachi": "Debal", "Pune": "Poona",
	"Nagpur": "Deogarh", "Jaipur": "Amber", "Thiruvananthapuram": "Trivandrum", "Kochi": "Cochin",
	"Kozhikode": "Calicut", "Mangaluru": "Mangalore", "Chandigarh": "Sirhind", "New Delhi": "Delhi",
	"Tokyo": "Edo", "Sapporo": "Ishikari", "Seoul": "Hanseong", "Busan": "Dongnae", "Dalian": "Lüshun",
	"Qingdao": "Jiaozhou", "Ulaanbaatar": "Tuul", "Ho Chi Minh City": "Prey Nokor", "Hanoi": "Thăng Long",
	"Yangon": "Dagon", "Rangoon": "Dagon", "Kuala Lumpur": "Klang", "Singapore": "Singapura",
	"Jakarta": "Jayakarta", "Naypyidaw": "Pyinmana", "Bandung": "Sumedang", "Medan": "Deli",
	"Quezon City": "Tondo", "Addis Ababa": "Shewa", "Dar es Salaam": "Mzizima", "Kinshasa": "Malebo",
	"Brazzaville": "Mfoa", "Lagos": "Eko", "Khartoum": "Qerri", "Maputo": "Delagoa",
	"Djibouti": "Tadjoura", "Rabat": "Salé", "Casablanca": "Anfa", "Mexico City": "Mexico",
	"Bogota": "Santa Fe de Bogotá", "Bogotá": "Santa Fe de Bogotá", "Recife": "Olinda",
}

## Modern first-level region names (from Natural Earth places) -> the
## historical province or land name used in 1590.
const HISTORIC_REGIONS := {
	# France
	"Aquitaine": "Guyenne", "Basse-Normandie": "Lower Normandy", "Haute-Normandie": "Upper Normandy",
	"Bourgogne": "Burgundy", "Bretagne": "Brittany", "Centre": "Orléanais", "Champagne-Ardenne": "Champagne",
	"Corse": "Corsica", "Languedoc-Roussillon": "Languedoc", "Midi-Pyrénées": "Gascony",
	"Nord-Pas-de-Calais": "Artois", "Pays de la Loire": "Anjou", "Picardie": "Picardy",
	"Poitou-Charentes": "Poitou", "Provence-Alpes-Côte-d'Azur": "Provence", "Rhône-Alpes": "Lyonnais",
	"Île-de-France": "Île-de-France",
	# Holy Roman Empire
	"Nordrhein-Westfalen": "Westphalia", "Baden-Württemberg": "Swabia", "Rheinland-Pfalz": "Rhineland",
	"Niedersachsen": "Lower Saxony", "Sachsen-Anhalt": "Altmark", "Mecklenburg-Vorpommern": "Mecklenburg",
	"Schleswig-Holstein": "Holstein", "Bayern": "Bavaria", "Hessen": "Hesse", "Thüringen": "Thuringia",
	"Sachsen": "Meissen", "Saarland": "Saarbrücken",
	# Iberia
	"Castilla y León": "Old Castile", "Castilla-La Mancha": "New Castile", "Comunidad Valenciana": "Valencia",
	"Andalucía": "Andalusia", "Cataluña": "Catalonia", "País Vasco": "Biscay", "Foral de Navarra": "Navarre",
	# Britain
	"Tyne and Wear": "Northumberland", "West Midlands": "Warwickshire", "Merseyside": "Lancashire",
	"Greater Manchester": "Salford", "Bath and North East Somerset": "Somerset", "South Yorkshire": "Hallamshire",
	"West Yorkshire": "West Riding", "North Yorkshire": "North Riding", "Greater London": "Middlesex",
}

## Wastelands: impassable, unownable land outside the 5000 provinces.
## Desert cores (geography regions whose name contains one of these), kept back
## from coasts and major rivers so the Nile and coastal strips stay habitable.
const WASTE_DESERTS := ["SAHARA", "LIBYAN", "NUBIAN", "WESTERN DESERT", "RUB", "TAKLIMAKAN", "GOBI",
	"GREAT SANDY", "GREAT VICTORIA", "GIBSON", "NAMIB", "ATACAMA", "LUT DESERT", "EL DJOUF", "GRAND ERG",
	"HAMADA", "MURZUQ", "TÉNÉRÉ", "ERG CHECH", "TASSILI", "KALANSHIYU", "GARAGUM", "QIZILQUM",
	"BETPAQDALA", "SYRIAN"]
## Impassable mountain cores.
const WASTE_RANGES := ["HIMALAYAS", "KARAKORAM", "KUNLUN", "PAMIRS", "ALTUN", "QUILIAN", "TIAN SHAN",
	"HINDU KUSH", "AHAGGAR", "TIBESTI", "BROOKS RANGE", "ALASKA RANGE", "CHERSKIY", "VERKHOYANSK",
	"KOLYMA RANGE", "PUTORANA", "PLATEAU OF TIBET"]
## Minimum distance (pixels) inside a desert/range region before it becomes wasteland.
const WASTE_DESERT_DEPTH := 10
const WASTE_RANGE_DEPTH := 6
## The Tibetan plateau is wasteland only deep inside it (the empty Changtang);
## its river valleys (Yarlung Tsangpo) stay habitable through the river rule.
const TIBET_PLATEAU_DEPTH := 22
## Tundra regions (Barren Grounds, North Siberian Lowland...) are wasteland
## this far inside, clear of coasts and rivers.
const WASTE_TUNDRA_DEPTH := 10
const WASTE_RIVER_CLEARANCE := 8
const WASTE_COAST_CLEARANCE := 6
## Islands whose centre lies this far north are wholly wasteland (Novaya
## Zemlya, the Canadian Arctic islands); mainland coasts are never cut by a
## latitude line. Land this far south (Antarctic islands) is ice.
const ARCTIC_ISLAND_LAT := 70.0
const ANTARCTIC_WASTE_LAT := -58.0
## Conventional names for wasteland regions, matched by name prefix.
const WASTE_NAMES := [
	["PLATEAU OF TIBET", "Changtang"], ["RUB", "Rub' al Khali"], ["SAR", "Calanshio Sand Sea"],
	["‘ERG CHECH", "Erg Chech"], ["ERG CHECH", "Erg Chech"], ["IDH", "Murzuq Sand Sea"],
	["TASSILI OUA", "Tassili n'Ahaggar"], ["TASSILI N", "Tassili n'Ajjer"], ["HAMADA", "Hamada du Draa"],
	["ALTUN", "Altun Shan"], ["KARAKORAM", "Karakoram"], ["AHAGGAR", "Ahaggar"], ["TIBESTI", "Tibesti"],
	["QUILIAN", "Qilian Shan"], ["KUNLUN", "Kunlun Shan"], ["TIAN SHAN", "Tian Shan"],
]


## Water that existed in 1590 but is land (or a shrunken lake) in modern data:
## [name, polygon of [lat, lon]]. Painted as water over the modern map.
const HISTORIC_WATER := [
	# The Aral Sea before its 20th-century shrinkage (~68,000 km²).
	["Aral Sea", [[46.80, 61.10], [46.65, 61.75], [46.20, 61.95], [45.70, 61.60], [45.20, 61.30], [44.70, 61.00],
		[44.25, 60.60], [43.80, 60.00], [43.55, 59.45], [43.55, 58.90], [43.85, 58.55], [44.40, 58.30],
		[45.00, 58.20], [45.60, 58.35], [46.10, 58.70], [46.45, 59.20], [46.65, 59.90], [46.80, 60.50]]],
	# Zuiderzee: the Flevoland polders (drained 1957-68) were open water...
	["Zuiderzee", [[52.60, 5.40], [52.66, 5.62], [52.60, 5.86], [52.47, 5.88], [52.36, 5.70], [52.30, 5.55],
		[52.32, 5.25], [52.34, 5.08], [52.42, 5.12], [52.50, 5.30]]],
	# ...as were the Noordoostpolder (1942) and the Wieringermeer (1930)...
	["Zuiderzee", [[52.85, 5.70], [52.82, 5.95], [52.70, 5.97], [52.62, 5.82], [52.65, 5.62], [52.75, 5.58]]],
	["Zuiderzee", [[52.88, 4.95], [52.90, 5.10], [52.80, 5.15], [52.75, 5.05], [52.78, 4.93]]],
	# ...and the Afsluitdijk (1932) did not yet close it off from the Wadden Sea.
	["Zuiderzee", [[52.92, 4.98], [53.08, 5.28], [53.06, 5.38], [52.90, 5.06]]],
]
## Modern lake names that had other names in 1590.
const HISTORIC_WATER_NAMES := {"IJsselmeer": "Zuiderzee", "Waddenzee": "Wadden Sea"}


## Sea tiles: every water body at least this large is split into tiles, about
## SEA_COASTAL_KM apart along coasts, widening to SEA_OPEN_KM in open ocean
## (SEA_OPEN_DISTANCE_KM or more from land).
const MIN_SEA_BODY_KM2 := 15000.0
const SEA_COASTAL_KM := 330.0
const SEA_OPEN_KM := 1300.0
const SEA_OPEN_DISTANCE_KM := 500.0
## Narrow seas that always get a tile of their own, seeded before the random
## ones (otherwise a change anywhere upstream can let a neighbouring tile
## swallow them): straits and channels that matter for 1590 naval play.
const SEA_ANCHORS := [
	[50.15, -1.20],  # English Channel
	[53.90, -5.00],  # Irish Sea
	[57.90, 9.30],  # Skagerrak
	[56.90, 11.40],  # Kattegat
	[40.75, 28.10],  # Sea of Marmara
	[43.70, 8.80],  # Ligurian Sea
	[59.85, 25.80],  # Gulf of Finland
	[36.05, -3.60],  # Alboran Sea
	[3.00, 100.60],  # Strait of Malacca
	[24.00, 119.40],  # Taiwan Strait
	[26.40, 56.60],  # Strait of Hormuz
	[12.70, 43.30],  # Bab-el-Mandeb
]
## Natural Earth marine areas, drawn broad to narrow so straits win over seas.
const MARINE_ORDER := ["ocean", "generic", "sea", "gulf", "bay", "sound", "lagoon", "channel", "strait", "fjord",
	"inlet"]


## Historic routes through desert wastelands, kept passable as corridors of
## habitable land (lat, lon waypoints). Provinces form along them, so the
## Sahara, the Taklamakan and the Gobi can be crossed as they were in 1590.
const TRADE_ROUTES := [
	["Nile", [[30.04, 31.24], [27.18, 31.18], [25.70, 32.64], [24.09, 32.90], [21.80, 31.35], [19.17, 30.48],
		[18.55, 31.85], [17.70, 33.97], [15.60, 32.53]]],
	["Darb al-Arba'in", [[27.18, 31.18], [25.44, 30.55], [22.50, 29.60], [18.50, 27.50], [15.50, 25.80], [13.63, 25.35]]],
	["Fezzan road", [[32.90, 13.18], [30.10, 14.20], [27.05, 14.43], [25.92, 13.92], [23.00, 13.20], [18.69, 12.92],
		[15.50, 13.30], [13.30, 13.40]]],
	["Oued Righ road", [[34.85, 5.73], [34.10, 5.90], [33.10, 6.07], [31.95, 5.33]]],
	["Central Sahara road", [[31.95, 5.33], [30.57, 2.88], [28.80, 2.60], [27.20, 2.47], [25.30, 3.75],
		[22.79, 5.52], [19.50, 7.20], [16.97, 7.99], [14.20, 8.20], [12.00, 8.52]]],
	["Western Sahara road", [[31.28, -4.27], [28.50, -5.00], [26.00, -5.30], [23.60, -5.00], [22.68, -3.98],
		[19.50, -3.50], [16.77, -3.00]]],
	["Atlantic coast road", [[29.70, -9.70], [27.10, -13.20], [23.70, -15.90], [20.90, -17.00], [18.00, -16.00],
		[16.50, -15.50]]],
	["Silk Road (north)", [[40.14, 94.66], [42.82, 93.51], [42.95, 89.18], [41.73, 86.15], [41.72, 82.96],
		[41.17, 80.26], [39.47, 75.99]]],
	["Silk Road (south)", [[40.14, 94.66], [39.02, 88.17], [37.60, 83.70], [37.11, 79.93], [38.42, 77.24]]],
	["Kalgan road", [[40.84, 111.75], [42.80, 110.00], [44.80, 108.50], [47.92, 106.90]]],
	["Hajj road", [[24.47, 39.61], [27.50, 41.70], [30.00, 40.10], [32.50, 38.00]]],
]
## Habitable-land half width of a route corridor, in map pixels.
const ROUTE_HALF_WIDTH := 7.0

## Extra province density for historically rich, crowded lands that a
## country-wide average undersells.
const SEED_DENSITY_BOOST := {"EGY": 3.5}

## Finer or coarser provinces in named areas, from the user's review (16 Oct
## 2026): [ADM0 code, lat min, lat max, lon min, lon max, factor on province
## density]. A region's quota is fixed, so a boost takes provinces from the
## rest of the same region (New Guinea's go to Australia; Canada's and the
## Pacific coast's mostly from Mexico).
const SEED_BOOSTS := [
	["PNG", -12.0, 0.0, 140.0, 156.0, 0.4],  # New Guinea (east): fewer, larger provinces
	["IDN", -11.0, 0.5, 130.8, 141.1, 0.35],  # New Guinea (west)
	["AUS", -45.0, -9.0, 112.0, 154.0, 2.6],  # Australia
	["CAN", 41.0, 56.0, -141.0, -52.0, 1.9],  # southern Canada and its coasts
	["USA", 32.0, 49.5, -125.0, -116.0, 2.2],  # the Pacific coast
	["RUS", 42.0, 56.5, 126.0, 146.0, 3.0],  # Amur, Primorye, southern Khabarovsk, Sakhalin
	# A few from inland China (not the coast, not Tibet or Inner Mongolia) to
	# Germany (with Europe's larger quota) and to Manchuria.
	["DEU", 47.0, 55.5, 5.5, 15.5, 1.14],
	["CHN", 42.0, 54.0, 119.5, 135.5, 1.67],  # Manchuria
	["CHN", 20.0, 38.5, 101.0, 113.5, 0.94],  # inland China
]


static func is_waste_desert(name: String) -> bool:
	var upper := name.to_upper()
	for key in WASTE_DESERTS:
		if upper.contains(key):
			return true
	return false


static func is_waste_range(name: String) -> bool:
	var upper := name.to_upper()
	for key in WASTE_RANGES:
		if upper.contains(key):
			return true
	return false


static func waste_display_name(name: String) -> String:
	var upper := name.to_upper()
	for pair: Array in WASTE_NAMES:
		if upper.begins_with(pair[0]):
			return pair[1]
	return name.to_lower().capitalize().replace(" Of ", " of ").replace(" Al ", " al ")


## Suffixes stripped from modern first-level division names.
const ADMIN_SUFFIXES := [" Voivodeship", " Prefecture", " Autonomous Okrug", " Autonomous Oblast", " Oblast",
	" Krai", " Republic", " Governorate", " Province", " Department", " Region", " District"]

## Modern first-level divisions -> their 1590 name (after suffix stripping).
const HISTORIC_ADMIN := {
	"North Rhine-Westphalia": "Westphalia", "Rhineland-Palatinate": "Palatinate", "Saxony-Anhalt": "Altmark",
	"Mecklenburg-Western Pomerania": "Mecklenburg", "Baden-Württemberg": "Swabia", "Saarland": "Saarbrücken",
	"Free Hanseatic Bremen": "Bremen",
	"Cheshire West and Chester": "Cheshire", "Dungannon and South Tyrone": "Tyrone", "Newry and Mourne": "Mourne",
	"Brighton and Hove": "Brighton", "Redcar and Cleveland": "Cleveland", "East Riding of Yorkshire": "East Riding",
	"North Yorkshire": "North Riding", "West Yorkshire": "West Riding", "South Yorkshire": "Hallamshire",
	"Leningrad": "Ingria", "Saint Petersburg": "Neva", "Kaliningrad": "Königsberg", "Volgograd": "Tsaritsyn",
	"Sverdlovsk": "Verkhoturye", "Kirov": "Vyatka", "Ulyanovsk": "Simbirsk", "Murmansk": "Kola",
	"Chelyabinsk": "Chelyaba", "Novosibirsk": "Ob", "Krasnodar": "Kuban", "Rostov": "Don", "Orenburg": "Yaik",
	"Kemerovo": "Kuznetsk", "Jewish": "Bira", "Sakha": "Yakutia", "Tatarstan": "Kazan", "Bashkortostan": "Bashkiria",
	"Kalmykia": "Kalmyk Steppe", "Chechen": "Chechnya", "Zabaykalsky": "Dauria", "Primorsky": "Primorye",
	"Shanghai": "Songjiang", "Inner Mongolia": "Southern Mongolia", "Xizang": "Tibet",
	"Uttar Pradesh": "Hindustan", "Madhya Pradesh": "Malwa", "Maharashtra": "Deccan", "Andhra Pradesh": "Andhra",
	"Telangana": "Telingana", "Uttarakhand": "Kumaon", "Chhattisgarh": "Gondwana", "Jharkhand": "Chota Nagpur",
	"Karnataka": "Karnata", "Tamil Nadu": "Coromandel", "Kerala": "Malabar", "Odisha": "Orissa",
	"West Bengal": "Bengal", "Haryana": "Hariana", "Himachal Pradesh": "Kangra", "Chandigarh": "Sirhind",
	"Puducherry": "Gingee", "Dadra and Nagar Haveli and Daman and Diu": "Daman", "Jammu and Kashmir": "Kashmir",
	"Khyber Pakhtunkhwa": "Peshawar", "Federally Administered Tribal Areas": "Waziristan",
	"Islamabad Capital Territory": "Pothohar", "Gilgit-Baltistan": "Baltistan", "Azad Kashmir": "Muzaffarabad",
	"Balochistan": "Baluchistan",
	"Meknès-Tafilalet": "Tafilalt", "Souss-Massa-Draâ": "Sus", "Suss-Massa-Draa": "Sus", "Oriental": "Oujda",
	"Tanger-Tétouan": "Habt", "Gharb-Chrarda-Béni Hssen": "Gharb", "Marrakech-Tensift-Al Haouz": "Haouz",
	"Fès-Boulemane": "Fez", "Taza-Al Hoceima-Taounate": "Rif", "Guelmim-Es Semara": "Wadi Nun",
	"Istanbul": "Constantinople", "Izmir": "Smyrna", "İzmir": "Smyrna", "Trabzon": "Trebizond",
	"Antalya": "Adalia", "Ankara": "Angora",
}


static func historic_admin_name(name: String) -> String:
	if name.begins_with("Republic of "):
		name = name.trim_prefix("Republic of ")
	for suffix in ADMIN_SUFFIXES:
		if name.ends_with(suffix):
			name = name.trim_suffix(suffix)
	name = name.strip_edges().trim_suffix("-")
	return HISTORIC_ADMIN.get(name, HISTORIC_NAMES.get(name, name))


## Short sea crossings treated as land connections: [[lat, lon], [lat, lon]].
const STRAITS := [
	[[55.70, 12.60], [55.60, 13.00]],  # Øresund
	[[55.33, 11.10], [55.30, 10.80]],  # Great Belt
	[[55.50, 9.70], [55.45, 9.95]],  # Little Belt
	[[41.10, 29.00], [41.10, 29.10]],  # Bosporus
	[[40.20, 26.40], [40.10, 26.30]],  # Dardanelles
	[[38.20, 15.60], [38.25, 15.68]],  # Messina
	[[36.00, -5.60], [35.85, -5.40]],  # Gibraltar
	[[45.35, 36.45], [45.30, 36.65]],  # Kerch
	[[12.60, 43.30], [12.50, 43.40]],  # Bab-el-Mandeb
	[[9.30, 79.30], [9.10, 79.60]],  # Palk Strait
	[[33.95, 130.95], [33.97, 130.88]],  # Shimonoseki
	[[41.20, 140.40], [41.50, 140.30]],  # Tsugaru
	[[-5.90, 105.90], [-5.80, 105.75]],  # Sunda
	[[1.35, 103.80], [1.45, 103.75]],  # Johor (Singapore)
	[[20.20, 110.20], [20.00, 110.25]],  # Hainan
	[[41.38, 9.16], [41.24, 9.23]],  # Bonifacio
	[[38.46, 23.60], [38.47, 23.58]],  # Euripus (Euboea)
	[[51.55, -56.85], [51.65, -56.70]],  # Belle Isle
]
