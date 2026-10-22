extends RefCounted
## Faith on 1 January 1590 for the world generator: every province's religion
## and every realm's state religion (ids as in src/domain/religions.gd).
##
## A province's faith is decided in steps, each overriding the last:
## 1. its modern country (BY_COUNTRY), else its world region (BY_REGION);
## 2. AREAS: boxes [lat_min, lat_max, lon_min, lon_max] or circles
##    [[lat, lon], km] for the regions that differ — Huguenot France, Catholic
##    Westphalia and Upper Swabia, Lutheran Silesia and Royal Prussia, the
##    Muslim Volga and Caucasus, Shia southern Iraq, Tibet, the animist
##    interiors of Borneo, Sulawesi and Mindanao, the Swahili coast …
##    (optionally only for some modern countries);
## 3. OWNERS: realms whose land shares their faith (the Scottish kirk, the
##    Catholic prince-bishoprics, Muslim sultanates in animist lands …);
## 4. conquest: Spanish and Portuguese land in the Americas and the
##    Philippines is Catholic (conversion followed conquest within a
##    generation).
## A realm's state religion is STATE's, else its capital province's.

const BY_REGION := {
	"EUR": "catholic", "MECA": "sunni", "IND": "hindu", "CJK": "confucian", "SEA": "animist",
	"AFR": "animist", "NAM": "animist", "SAM": "animist", "OCE": "animist", "OTH": "animist",
}

const BY_COUNTRY := {
	# Western Europe
	"ESP": "catholic", "PRT": "catholic", "AND": "catholic", "FRA": "catholic", "MCO": "catholic",
	"ITA": "catholic", "SMR": "catholic", "VAT": "catholic", "MLT": "catholic", "IRL": "catholic",
	"GBR": "anglican", "IMN": "anglican", "GGY": "anglican", "JEY": "anglican",
	"NLD": "reformed", "BEL": "catholic", "LUX": "catholic", "CHE": "reformed", "LIE": "catholic",
	# Central Europe
	"DEU": "protestant", "AUT": "catholic", "CZE": "protestant", "SVK": "protestant", "HUN": "reformed",
	"SVN": "catholic", "HRV": "catholic", "POL": "catholic", "LTU": "catholic",
	# The north
	"DNK": "protestant", "NOR": "protestant", "SWE": "protestant", "FIN": "protestant", "ISL": "protestant",
	"FRO": "protestant", "ALD": "protestant", "EST": "protestant", "LVA": "protestant",
	# The east and the Balkans
	"RUS": "orthodox", "BLR": "orthodox", "UKR": "orthodox", "MDA": "orthodox", "ROU": "orthodox",
	"BGR": "orthodox", "SRB": "orthodox", "MNE": "orthodox", "KOS": "orthodox", "MKD": "orthodox",
	"GRC": "orthodox", "ALB": "orthodox", "BIH": "sunni", "CYP": "orthodox", "CYN": "orthodox",
	# The Middle East and Central Asia
	"TUR": "sunni", "GEO": "orthodox", "ARM": "oriental", "AZE": "shia", "IRN": "shia", "IRQ": "sunni",
	"SYR": "sunni", "LBN": "sunni", "ISR": "sunni", "PSX": "sunni", "JOR": "sunni", "SAU": "sunni",
	"YEM": "sunni", "OMN": "ibadi", "ARE": "sunni", "QAT": "sunni", "BHR": "shia", "KWT": "sunni",
	"AFG": "sunni", "UZB": "sunni", "TKM": "sunni", "TJK": "sunni", "KGZ": "sunni", "KAZ": "sunni",
	# South Asia
	"IND": "hindu", "PAK": "sunni", "BGD": "sunni", "KAS": "sunni", "NPL": "hindu", "BTN": "vajrayana",
	"LKA": "theravada", "MDV": "sunni",
	# East Asia
	"CHN": "confucian", "HKG": "confucian", "MAC": "confucian", "TWN": "animist", "KOR": "confucian",
	"PRK": "confucian", "JPN": "shinto", "MNG": "vajrayana",
	# South East Asia
	"MMR": "theravada", "THA": "theravada", "LAO": "theravada", "KHM": "theravada", "VNM": "confucian",
	"MYS": "sunni", "SGP": "sunni", "BRN": "sunni", "IDN": "sunni", "PHL": "animist", "TLS": "animist",
	# Africa
	"EGY": "sunni", "LBY": "sunni", "TUN": "sunni", "DZA": "sunni", "MAR": "sunni", "SAH": "sunni",
	"MRT": "sunni", "SDN": "sunni", "TCD": "sunni", "NER": "sunni", "MLI": "sunni", "SEN": "sunni",
	"GMB": "sunni", "DJI": "sunni", "SOM": "sunni", "SOL": "sunni", "ETH": "oriental", "ERI": "oriental",
	"COM": "sunni", "CPV": "catholic", "STP": "catholic",
}

const AREAS := [
	# --- The British Isles ---
	["catholic", [51.3, 55.5, -10.7, -5.4], ["GBR"]],  # Ulster
	# --- France: the Huguenot south and west ---
	["reformed", [[43.30, -0.37], 90.0], ["FRA"]],  # Béarn
	["reformed", [[46.16, -1.15], 80.0], ["FRA"]],  # La Rochelle, Aunis and Saintonge
	["reformed", [[44.0, 4.0], 75.0], ["FRA"]],  # the Cévennes, Nîmes
	["reformed", [[44.02, 1.35], 45.0], ["FRA"]],  # Montauban
	# --- The Low Countries: Catholic Brabant and Limburg ---
	["catholic", [51.2, 51.72, 4.2, 6.2], ["NLD"]],
	# --- Switzerland: the Catholic cantons ---
	["catholic", [[46.95, 8.40], 45.0], ["CHE"]],  # Lucerne and the forest cantons
	["catholic", [[46.80, 7.15], 20.0], ["CHE"]],  # Fribourg
	["catholic", [[46.22, 7.60], 45.0], ["CHE"]],  # Valais
	["catholic", [[46.20, 8.95], 40.0], ["CHE"]],  # Ticino
	# --- The Empire: Catholic lands amid Lutheran Germany, Protestant ones in Habsburg lands ---
	["catholic", [47.45, 48.30, 7.5, 10.3], ["DEU"]],  # Breisgau and Upper Swabia (Further Austria)
	["catholic", [[51.72, 8.75], 45.0], ["DEU"]],  # Paderborn
	["catholic", [[52.28, 8.05], 30.0], ["DEU"]],  # Osnabrück
	["catholic", [[50.55, 9.68], 30.0], ["DEU"]],  # Fulda
	["catholic", [[51.40, 10.20], 25.0], ["DEU"]],  # the Eichsfeld
	["protestant", [[48.30, 14.30], 70.0], ["AUT"]],  # Upper Austria
	["protestant", [[51.10, 17.03], 160.0], ["POL", "CZE"]],  # Silesia
	["protestant", [[54.35, 18.65], 70.0], ["POL"]],  # Royal Prussia: Danzig, Elbing, Thorn
	["catholic", [46.5, 48.2, 16.0, 18.0], ["HUN"]],  # Royal Hungary's west
	["catholic", [[42.07, 19.51], 60.0], ["ALB", "MNE"]],  # Shkodër and the Catholic north
	["sunni", [43.0, 44.3, 26.0, 28.6], ["BGR"]],  # the Deliorman and Shumen: Turks
	["sunni", [41.3, 42.0, 24.0, 25.9], ["BGR", "GRC"]],  # the Rhodopes: Pomaks
	["sunni", [45.2, 47.6, 28.2, 33.0], ["UKR", "MDA"]],  # the Budjak and Yedisan: Nogai
	["sunni", [44.3, 46.3, 32.4, 36.7], ["UKR", "RUS"]],  # Crimea: Tatars
	["sunni", [46.8, 47.4, 38.8, 40.0], ["RUS", "UKR"]],  # Azov
	# --- Russia: the Volga, the steppe, the north and Siberia ---
	["sunni", [54.0, 56.7, 47.5, 54.0], ["RUS"]],  # Kazan Tatars
	["sunni", [51.5, 56.5, 53.0, 60.0], ["RUS"]],  # Bashkirs
	["sunni", [45.5, 48.5, 44.5, 49.5], ["RUS"]],  # Astrakhan
	["sunni", [45.5, 47.3, 40.5, 47.5], ["RUS"]],  # Nogai steppe, to the Manych
	["sunni", [41.2, 44.8, 45.5, 48.5], ["RUS"]],  # Dagestan
	["sunni", [43.0, 45.5, 36.5, 46.2], ["RUS"]],  # the north-west Caucasus and the Kuma
	["animist", [56.3, 57.3, 46.0, 50.5], ["RUS"]],  # the Mari
	["animist", [56.5, 58.5, 51.5, 54.5], ["RUS"]],  # the Udmurts
	["animist", [65.0, 72.0, 46.0, 60.0], ["RUS"]],  # Nenets tundra
	["animist", [55.5, 67.0, 58.5, 60.0], ["RUS"]],  # the Mansi and Khanty of the Urals' east slope
	["sunni", [49.0, 53.0, 55.0, 61.0], ["RUS"]],  # the steppe at Orsk: Bashkirs, Kazakhs
	["animist", [42.0, 78.0, 60.0, 180.0], ["RUS"]],  # Siberia to the Pacific
	["animist", [60.0, 72.0, -180.0, -168.0], ["RUS"]],  # Chukotka, across the date line
	["sunni", [56.5, 58.8, 64.5, 69.0], ["RUS"]],  # Siberian Tatars: Tyumen, Tobolsk
	# --- The Middle East ---
	["sunni", [34.0, 37.5, 45.0, 47.5], ["IRN"]],  # Kurdistan
	["sunni", [25.0, 30.0, 58.5, 63.5], ["IRN"]],  # Baluchistan
	["shia", [29.0, 33.5, 43.0, 48.6], ["IRQ"]],  # Najaf, Karbala, Basra
	["catholic", [[34.20, 35.90], 30.0], ["LBN"]],  # the Maronites of Mount Lebanon
	["shia", [24.5, 27.5, 48.5, 51.0], ["SAU"]],  # al-Hasa and Qatif
	["shia", [14.5, 17.5, 43.0, 45.5], ["YEM"]],  # the Zaydi highlands
	["shia", [33.5, 35.5, 65.5, 68.5], ["AFG"]],  # Hazarajat
	# --- South Asia ---
	["catholic", [[15.50, 73.83], 35.0], ["IND"]],  # Goa
	["animist", [21.5, 27.5, 92.2, 97.5], ["IND"]],  # the north-eastern hills: Naga, Mizo, Chin
	["animist", [25.0, 25.95, 89.8, 92.8], ["IND"]],  # the Khasi and Garo hills
	["animist", [26.9, 29.5, 91.5, 97.5], ["IND"]],  # Arunachal
	["vajrayana", [32.5, 36.0, 76.5, 80.0], ["IND"]],  # Ladakh
	["hindu", [[9.66, 80.02], 70.0], ["LKA"]],  # Jaffna
	# --- East Asia ---
	["sunni", [36.5, 49.5, 73.0, 91.0], ["CHN"]],  # the Tarim basin and Turpan
	["sunni", [41.5, 44.5, 91.0, 96.0], ["CHN"]],  # Hami
	["vajrayana", [27.5, 36.5, 78.0, 101.5], ["CHN"]],  # Tibet, Qinghai and Kham
	["vajrayana", [35.5, 39.0, 90.0, 97.5], ["CHN"]],  # the Qaidam
	["animist", [42.0, 54.0, 118.0, 135.5], ["CHN"]],  # Manchuria: the Wild Jurchens, Daur, Evenks
	["vajrayana", [39.0, 42.5, 105.0, 112.0], ["CHN"]],  # the Hetao and Tümed: Mongols
	["animist", [41.4, 46.0, 139.0, 146.0], ["JPN"]],  # Ezo: the Ainu
	# --- South East Asia ---
	["animist", [11.5, 15.5, 107.0, 108.4], ["VNM"]],  # the central highlands
	["animist", [20.5, 23.5, 102.0, 105.0], ["VNM"]],  # the Tai and Hmong uplands
	["theravada", [8.4, 11.6, 104.4, 107.2], ["VNM"]],  # the Mekong delta: Khmer
	["animist", [21.5, 28.5, 92.5, 98.8], ["MMR"]],  # the Kachin, Naga and Chin hills
	["animist", [1.0, 3.5, 98.0, 100.0], ["IDN"]],  # the Batak
	["animist", [-4.0, 7.0, 108.5, 119.0], ["IDN", "MYS", "BRN"]],  # Borneo (its sultanates by their owners)
	["animist", [-4.0, -2.5, 125.8, 131.0], ["IDN"]],  # Seram and Buru
	["animist", [-3.6, 1.6, 97.0, 99.3], ["IDN"]],  # Mentawai and Nias
	["animist", [-5.0, -1.8, 101.0, 103.5], ["IDN"]],  # the Rejang and Kerinci
	["animist", [-6.0, 2.0, 118.5, 125.5], ["IDN"]],  # Sulawesi (Makassar turns to Islam in 1605)
	["animist", [-11.0, -7.5, 116.0, 127.5], ["IDN"]],  # the Lesser Sundas
	["animist", [-9.5, 0.0, 130.0, 141.5], ["IDN"]],  # New Guinea
	["hindu", [-8.9, -8.0, 114.4, 115.8], ["IDN"]],  # Bali
	["animist", [5.0, 9.9, 121.8, 127.0], ["PHL"]],  # Mindanao
	["animist", [16.0, 18.5, 120.5, 121.5], ["PHL"]],  # the Cordillera
	# --- Africa ---
	["animist", [-5.0, 11.5, 13.5, 24.5], ["TCD"]],  # the south of Chad
	["animist", [-5.0, 10.5, 0.0, 16.0], ["NGA"]],  # below the Hausa lands
	["animist", [3.4, 10.0, 34.0, 41.0], ["ETH"]],  # the Oromo
	["sunni", [9.0, 14.5, 39.8, 43.0], ["ETH", "ERI", "DJI"]],  # the Afar
	["sunni", [4.0, 9.5, 42.0, 48.0], ["ETH"]],  # the Ogaden: Somalis
	["sunni", [14.5, 18.5, 38.8, 43.5], ["ERI"]],  # the coast and the Danakil
	["sunni", [[-3.22, 40.12], 60.0], ["KEN"]],  # Malindi
	["sunni", [[-4.05, 39.67], 60.0], ["KEN"]],  # Mombasa
	["sunni", [[-2.27, 40.90], 60.0], ["KEN"]],  # Lamu and Pate
	["sunni", [[-6.16, 39.19], 60.0], ["TZA"]],  # Zanzibar
	["sunni", [[-8.96, 39.51], 60.0], ["TZA"]],  # Kilwa
	["sunni", [[-15.03, 40.73], 50.0], ["MOZ"]],  # Mozambique Island
	["sunni", [[-20.15, 34.70], 60.0], ["MOZ"]],  # Sofala
	["catholic", [[-8.84, 13.23], 40.0], ["AGO"]],  # Luanda
	["animist", [8.0, 12.5, 10.0, 16.0], ["CMR", "NGA"]],  # Mandara and the Benue
]

## Realms whose land, wherever it lies, shares their faith.
const OWNERS := {
	"SCO": "reformed", "TYR": "catholic", "TYC": "catholic", "PAL": "reformed", "BAV": "catholic",
	"KOL": "catholic", "MAI": "catholic", "TRI": "catholic", "MUN": "catholic", "WBG": "catholic",
	"BAB": "catholic", "LOR": "catholic", "LIE": "catholic", "SLZ": "catholic", "JUL": "catholic",
	"KOM": "catholic", "TRA": "reformed", "PRU": "protestant", "CRL": "protestant",
	"POM": "protestant", "BRA": "protestant", "WUR": "protestant", "HES": "protestant", "BRW": "protestant",
	"SAX": "protestant", "NED": "reformed", "RAG": "catholic", "AKT": "shinto", "ABY": "oriental",
	"MNG": "confucian", "TOU": "theravada",
	"CRI": "sunni", "NOG": "sunni", "SIB": "sunni", "OIR": "vajrayana", "KHA": "vajrayana",
	"CHK": "vajrayana", "TMD": "vajrayana", "ORD": "vajrayana", "TIB": "vajrayana", "LAD": "vajrayana",
	"BLT": "shia", "JIA": "animist", "HAI": "animist", "JAF": "hindu", "CHA": "hindu", "GEL": "hindu",
	"BLA": "hindu", "PAT": "sunni", "BRN": "sunni", "SUL": "sunni", "MGD": "sunni", "BJM": "sunni",
	"KUT": "sunni", "TER": "sunni", "TID": "sunni", "MAH": "sunni", "KTH": "sunni", "HAR": "sunni",
	"AUA": "sunni", "MLD": "sunni", "MBA": "sunni", "PTE": "sunni", "KIL": "sunni", "ZAN": "sunni",
	"KON": "catholic", "SIN": "animist", "SAL": "animist", "BOR": "sunni", "BAG": "sunni",
	"DRF": "sunni", "MOS": "animist", "YAT": "animist", "KAA": "animist", "ZAZ": "sunni", "KNO": "sunni",
	"KAT": "sunni", "KEB": "sunni", "GOB": "sunni", "AIR": "sunni", "SON": "sunni", "FUN": "sunni",
}

## Realms of the Catholic conquest: their land in the Americas and the Philippines is Catholic.
const CONQUERORS := ["SPA", "POR"]
const CONQUEST_COUNTRIES := ["PHL"]
const CONQUEST_REGIONS := ["NAM", "SAM"]

## State religions that are not simply their capital's faith.
const STATE := {
	"ENG": "anglican", "SCO": "reformed", "NED": "reformed", "FRA": "catholic", "SPA": "catholic",
	"POR": "catholic", "AUS": "catholic", "TRA": "catholic", "PAL": "reformed", "SAX": "protestant",
	"BRA": "protestant", "HES": "protestant", "SWI": "reformed", "PLC": "catholic", "TUR": "sunni",
	"SAF": "shia", "MUG": "sunni", "AHM": "shia", "BIJ": "shia", "GOL": "shia", "BID": "sunni",
	"KHD": "sunni", "ORI": "sunni", "BHT": "sunni", "SND": "sunni", "VIJ": "hindu", "MNG": "confucian",
	"JOS": "confucian", "JAP": "shinto", "CHA": "hindu", "KON": "catholic", "ABY": "oriental",
	"OMA": "ibadi", "VEN": "catholic", "KOM": "catholic", "RAG": "catholic",
}


static func _hit(area: Array, lat: float, lon: float, adm: String, km: Callable) -> bool:
	if area.size() > 2 and not adm in area[2]:
		return false
	var shape: Array = area[1]
	if shape.size() == 4:
		return lat >= shape[0] and lat <= shape[1] and lon >= shape[2] and lon <= shape[3]
	return km.call(lat, lon, shape[0][0], shape[0][1]) <= shape[1]


## A province's faith: `adm` its modern country, `region` its world region,
## `owner` its 1590 realm; `km` measures great-circle distance.
static func province_religion(adm: String, region: String, owner: String, lat: float, lon: float,
		km: Callable) -> String:
	var faith: String = BY_COUNTRY.get(adm, BY_REGION.get(region, "animist"))
	for area: Array in AREAS:
		if _hit(area, lat, lon, adm, km):
			faith = area[0]
	if OWNERS.has(owner):
		faith = OWNERS[owner]
	if owner in CONQUERORS and (region in CONQUEST_REGIONS or adm in CONQUEST_COUNTRIES):
		faith = "catholic"
	return faith
