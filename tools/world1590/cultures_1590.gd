extends RefCounted
## Peoples on 1 January 1590 for the world generator: every province's culture
## and every realm's primary culture (ids as in src/domain/cultures.gd).
## Decided like faith (religions_1590.gd): the modern country (BY_COUNTRY,
## else BY_REGION), then AREAS (boxes [lat_min, lat_max, lon_min, lon_max] or
## circles [[lat, lon], km], optionally for some modern countries only; the
## last that covers a province wins), then OWNERS (realms whose land is
## theirs), then the Spanish Antilles (Castilian settlers where the Taíno were
## gone). A realm's culture is STATE's, else its capital's.

const BY_REGION := {
	"EUR": "high_german", "MECA": "bedouin", "IND": "hindustani", "CJK": "han", "SEA": "malay",
	"AFR": "central_bantu", "NAM": "algonquian", "SAM": "amazonian", "OCE": "melanesian", "OTH": "evenk",
}

const BY_COUNTRY := {
	# Europe
	"GBR": "english", "IMN": "gaelic", "GGY": "french", "JEY": "french", "IRL": "gaelic", "FRA": "french",
	"MCO": "lombard", "BEL": "flemish", "NLD": "dutch", "LUX": "high_german", "DEU": "high_german", "AUT": "high_german",
	"CHE": "high_german", "LIE": "high_german", "ESP": "castilian", "PRT": "portuguese", "AND": "catalan",
	"ITA": "tuscan", "SMR": "tuscan", "VAT": "tuscan", "MLT": "sicilian", "DNK": "danish", "NOR": "norwegian",
	"SWE": "swedish", "FIN": "finnish", "ISL": "icelandic", "FRO": "icelandic", "ALD": "swedish", "EST": "estonian",
	"LVA": "latvian", "LTU": "lithuanian", "POL": "polish", "CZE": "czech", "SVK": "slovak", "HUN": "hungarian",
	"SVN": "slovene", "HRV": "croatian", "BIH": "bosniak", "SRB": "serbian", "MNE": "serbian", "KOS": "albanian",
	"MKD": "bulgarian", "ALB": "albanian", "GRC": "greek", "BGR": "bulgarian", "ROU": "romanian", "MDA": "romanian",
	"UKR": "ruthenian", "BLR": "belarusian", "RUS": "russian", "CYP": "greek", "CYN": "greek",
	# The Middle East and Central Asia
	"TUR": "turkish", "GEO": "georgian", "ARM": "armenian", "AZE": "azeri", "IRN": "persian", "IRQ": "iraqi",
	"SYR": "levantine", "LBN": "levantine", "ISR": "levantine", "PSX": "levantine", "JOR": "levantine",
	"SAU": "bedouin", "YEM": "yemeni", "OMN": "omani", "ARE": "bedouin", "QAT": "bedouin", "BHR": "bedouin",
	"KWT": "bedouin", "AFG": "pashtun", "UZB": "uzbek", "TKM": "turkmen", "TJK": "tajik", "KGZ": "kyrgyz",
	"KAZ": "kazakh",
	# South Asia
	"IND": "hindustani", "PAK": "punjabi", "BGD": "bengali", "KAS": "kashmiri", "NPL": "nepali", "BTN": "tibetan",
	"LKA": "sinhala", "MDV": "sinhala",
	# East Asia
	"CHN": "han", "HKG": "cantonese", "MAC": "cantonese", "TWN": "formosan", "KOR": "korean", "PRK": "korean",
	"JPN": "japanese", "MNG": "mongol",
	# South East Asia
	"MMR": "burmese", "THA": "thai", "LAO": "lao", "KHM": "khmer", "VNM": "vietnamese", "MYS": "malay",
	"SGP": "malay", "BRN": "malay", "IDN": "malay", "PHL": "tagalog", "TLS": "moluccan",
	# Africa
	"EGY": "egyptian", "LBY": "maghrebi", "TUN": "maghrebi", "DZA": "maghrebi", "MAR": "maghrebi", "SAH": "maghrebi",
	"MRT": "maghrebi", "SDN": "sudanese", "SDS": "nilotic", "TCD": "sudanic", "NER": "hausa", "NGA": "hausa",
	"BEN": "gbe", "TGO": "gbe", "GHA": "akan", "CIV": "akan", "LBR": "kru", "SLE": "mande", "GIN": "mande",
	"GNB": "mande", "SEN": "wolof", "GMB": "mande", "MLI": "mande", "BFA": "mossi", "CMR": "central_bantu",
	"CAF": "sudanic", "COD": "central_bantu", "COG": "central_bantu", "GAB": "central_bantu", "GNQ": "central_bantu",
	"AGO": "mbundu", "ZMB": "central_bantu", "MWI": "central_bantu", "MOZ": "shona", "ZWE": "shona", "BWA": "sotho",
	"ZAF": "nguni", "LSO": "sotho", "SWZ": "nguni", "NAM": "khoisan", "KEN": "lakes_bantu", "TZA": "lakes_bantu",
	"UGA": "lakes_bantu", "RWA": "lakes_bantu", "BDI": "lakes_bantu", "ETH": "amhara", "ERI": "amhara",
	"DJI": "afar", "SOM": "somali", "SOL": "somali", "MDG": "malagasy", "COM": "swahili", "CPV": "portuguese",
	"STP": "portuguese",
	# The Americas
	"USA": "algonquian", "CAN": "algonquian", "MEX": "nahua", "GTM": "maya", "BLZ": "maya", "SLV": "maya",
	"HND": "chibcha", "NIC": "chibcha", "CRI": "chibcha", "PAN": "chibcha", "CUB": "taino", "DOM": "taino",
	"HTI": "taino", "PRI": "taino", "JAM": "taino", "BHS": "taino", "COL": "chibcha", "VEN": "carib", "GUY": "carib",
	"SUR": "carib", "ECU": "quechua", "PER": "quechua", "BOL": "aymara", "CHL": "mapuche", "ARG": "pampean",
	"PRY": "guarani", "URY": "pampean", "BRA": "tupi", "FLK": "pampean", "GRL": "inuit",
	# Oceania
	"AUS": "aboriginal", "NZL": "maori", "PNG": "papuan", "SLB": "melanesian", "VUT": "melanesian",
	"NCL": "melanesian", "FJI": "melanesian", "WSM": "polynesian", "ASM": "polynesian", "TON": "polynesian",
	"NIU": "polynesian", "COK": "polynesian", "PYF": "polynesian", "WLF": "polynesian", "FSM": "micronesian",
	"PLW": "micronesian", "MHL": "micronesian", "KIR": "micronesian", "NRU": "micronesian", "GUM": "micronesian",
	"MNP": "micronesian",
}

const AREAS := [
	# --- The British Isles ---
	["scottish", [55.0, 61.0, -8.7, -2.6], ["GBR"]], ["scottish", [55.8, 61.0, -2.6, -0.7], ["GBR"]],
	["gaelic", [56.3, 59.0, -7.8, -3.8], ["GBR"]], ["gaelic", [56.5, 58.6, -8.0, -6.0], ["GBR"]],
	["welsh", [51.35, 53.45, -5.4, -2.65], ["GBR"]], ["gaelic", [54.0, 55.4, -8.2, -5.4], ["GBR"]],
	# --- France and the Low Countries ---
	["occitan", [42.3, 46.0, -1.0, 7.8], ["FRA"]], ["occitan", [43.2, 45.3, -1.8, -1.0], ["FRA"]],
	["basque", [42.9, 43.5, -1.8, -0.7], ["FRA"]], ["catalan", [42.3, 42.95, 1.7, 3.2], ["FRA"]],
	["breton", [47.3, 48.9, -4.9, -2.6], ["FRA"]], ["high_german", [47.4, 49.1, 6.8, 8.3], ["FRA"]],
	["tuscan", [41.3, 43.1, 8.5, 9.6], ["FRA"]], ["flemish", [50.6, 51.1, 2.0, 3.0], ["FRA"]],
	["walloon", [49.4, 50.75, 2.8, 6.5], ["BEL"]], ["frisian", [52.8, 53.5, 5.3, 6.3], ["NLD"]],
	# --- The Empire and Switzerland ---
	["low_german", [51.8, 55.1, 5.8, 15.0], ["DEU"]],
	["french", [45.8, 47.5, 5.9, 7.2], ["CHE"]], ["lombard", [45.8, 46.6, 8.4, 9.3], ["CHE"]],
	# --- Iberia and Italy ---
	["catalan", [40.5, 42.9, 0.15, 3.4], ["ESP"]], ["catalan", [38.0, 40.8, -0.9, 0.6], ["ESP"]],
	["catalan", [38.6, 40.1, 1.1, 4.4], ["ESP"]], ["galician", [41.8, 43.8, -9.4, -6.8], ["ESP"]],
	["basque", [42.5, 43.5, -3.4, -1.7], ["ESP"]],
	["lombard", [44.0, 46.6, 6.6, 10.6], ["ITA"]], ["lombard", [44.0, 45.2, 9.2, 12.4], ["ITA"]],
	["venetian", [44.8, 46.7, 10.6, 13.9], ["ITA"]], ["neapolitan", [39.8, 42.8, 13.0, 18.6], ["ITA"]],
	["neapolitan", [37.9, 39.8, 15.6, 17.2], ["ITA"]], ["sicilian", [36.6, 38.4, 12.3, 15.7], ["ITA"]],
	["sardinian", [38.8, 41.3, 8.1, 9.9], ["ITA"]],
	# --- Central and eastern Europe ---
	["high_german", [50.6, 51.8, 14.8, 17.2], ["POL"]], ["low_german", [53.0, 54.9, 14.0, 17.0], ["POL"]],
	["low_german", [[54.35, 18.65], 40.0], ["POL"]], ["low_german", [54.3, 55.4, 19.6, 22.9], ["RUS"]],
	["hungarian", [47.7, 48.3, 17.2, 22.5], ["SVK"]],
	["hungarian", [46.0, 48.0, 21.0, 22.8], ["ROU"]], ["hungarian", [45.7, 47.0, 25.0, 26.5], ["ROU"]],
	["high_german", [[45.80, 24.15], 40.0], ["ROU"]], ["high_german", [[45.65, 25.60], 25.0], ["ROU"]],
	["crimean_tatar", [44.3, 46.3, 32.4, 36.7], ["UKR", "RUS"]], ["nogai", [45.2, 47.6, 28.2, 32.4], ["UKR", "MDA"]],
	["turkish", [43.0, 44.3, 26.0, 28.6], ["BGR"]],
	# --- Russia ---
	["volga_tatar", [54.0, 56.7, 47.5, 54.0], ["RUS"]], ["bashkir", [51.5, 56.5, 53.0, 60.0], ["RUS"]],
	["volga_finnic", [56.3, 58.5, 46.0, 54.5], ["RUS"]], ["volga_finnic", [53.5, 55.2, 42.5, 46.5], ["RUS"]],
	["volga_finnic", [60.0, 65.0, 48.0, 60.0], ["RUS"]], ["nogai", [45.5, 47.3, 40.5, 47.5], ["RUS"]],
	["nogai", [45.5, 48.5, 44.5, 49.5], ["RUS"]], ["dagestani", [41.2, 44.8, 45.5, 48.5], ["RUS"]],
	["circassian", [43.0, 45.5, 36.5, 46.2], ["RUS"]], ["finnish", [61.0, 66.5, 30.0, 36.0], ["RUS"]],
	["sami", [66.0, 70.0, 28.0, 41.0], ["RUS"]], ["samoyed", [65.0, 72.0, 44.0, 60.0], ["RUS"]],
	["evenk", [42.0, 78.0, 60.0, 180.0], ["RUS"]], ["ugrian", [55.0, 67.0, 58.5, 82.0], ["RUS"]],
	["samoyed", [65.0, 78.0, 60.0, 110.0], ["RUS"]], ["kyrgyz", [49.0, 56.0, 82.0, 98.0], ["RUS"]],
	["mongol", [49.5, 56.0, 98.0, 117.0], ["RUS"]], ["yakut", [58.0, 72.0, 105.0, 140.0], ["RUS"]],
	["chukchi", [58.0, 72.0, 140.0, 180.0], ["RUS"]], ["chukchi", [60.0, 72.0, -180.0, -168.0], ["RUS"]],
	["siberian_tatar", [56.5, 58.8, 64.5, 69.0], ["RUS"]], ["kazakh", [49.0, 53.0, 55.0, 61.0], ["RUS"]],
	# --- The Middle East ---
	["kurdish", [36.8, 39.5, 38.5, 44.8], ["TUR"]],
	["azeri", [36.5, 39.8, 44.0, 49.0], ["IRN"]], ["kurdish", [33.5, 37.0, 45.0, 48.0], ["IRN"]],
	["baluchi", [25.0, 30.0, 58.5, 63.5], ["IRN"]], ["turkmen", [37.0, 38.5, 54.0, 57.5], ["IRN"]],
	["iraqi", [30.0, 32.5, 47.8, 50.0], ["IRN"]], ["kurdish", [35.2, 37.5, 42.5, 46.5], ["IRQ"]],
	["uzbek", [36.0, 37.5, 64.0, 69.5], ["AFG"]], ["tajik", [35.0, 38.5, 69.5, 75.0], ["AFG"]],
	["persian", [33.5, 35.5, 65.5, 68.5], ["AFG"]], ["persian", [33.0, 35.8, 60.5, 63.0], ["AFG"]],
	# --- South Asia ---
	["pashtun", [29.5, 36.0, 69.0, 72.3], ["PAK"]], ["baluchi", [24.8, 31.5, 60.8, 69.5], ["PAK"]],
	["sindhi", [23.5, 28.6, 66.6, 71.2], ["PAK"]], ["kashmiri", [33.0, 36.5, 73.0, 75.5], ["PAK"]],
	["rajasthani", [23.5, 30.2, 69.5, 77.5], ["IND"]], ["gujarati", [20.0, 24.7, 68.0, 74.5], ["IND"]],
	["punjabi", [29.5, 33.5, 72.0, 77.5], ["IND"]], ["kashmiri", [32.5, 35.0, 73.5, 76.5], ["IND"]],
	["tibetan", [32.5, 36.0, 76.5, 80.0], ["IND"]], ["marathi", [15.5, 22.0, 72.5, 80.5], ["IND"]],
	["gond", [19.0, 24.0, 78.5, 84.0], ["IND"]], ["oriya", [17.8, 22.5, 81.5, 87.5], ["IND"]],
	["telugu", [13.5, 19.5, 76.5, 84.5], ["IND"]], ["kannada", [11.5, 18.3, 74.0, 78.5], ["IND"]],
	["tamil", [8.0, 13.5, 77.0, 80.5], ["IND"]], ["malayalam", [8.0, 12.8, 74.8, 77.3], ["IND"]],
	["bengali", [21.5, 27.0, 86.5, 92.5], ["IND"]], ["assamese", [25.95, 28.0, 89.5, 96.0], ["IND"]],
	["hill", [21.5, 27.5, 92.2, 97.5], ["IND"]], ["hill", [25.0, 25.95, 89.8, 92.8], ["IND"]],
	["tamil", [[9.66, 80.02], 90.0], ["LKA"]],
	# --- East Asia ---
	["cantonese", [21.0, 25.5, 106.0, 117.0], ["CHN"]], ["min", [23.5, 28.3, 115.8, 120.8], ["CHN"]],
	["wu", [27.0, 32.2, 118.5, 122.5], ["CHN"]], ["uyghur", [36.5, 49.5, 73.0, 91.0], ["CHN"]],
	["uyghur", [41.5, 44.5, 91.0, 96.0], ["CHN"]], ["tibetan", [27.5, 36.5, 78.0, 101.5], ["CHN"]],
	["tibetan", [35.5, 39.0, 90.0, 97.5], ["CHN"]], ["mongol", [40.8, 50.5, 106.0, 122.0], ["CHN"]],
	["mongol", [39.0, 41.0, 105.0, 112.0], ["CHN"]], ["jurchen", [42.0, 54.0, 118.0, 135.5], ["CHN"]],
	["evenk", [47.0, 53.6, 118.0, 127.0], ["CHN"]],
	["ainu", [41.4, 46.0, 139.0, 146.0], ["JPN"]], ["ryukyuan", [24.0, 28.5, 122.5, 131.5], ["JPN"]],
	["oirat", [45.0, 50.5, 87.0, 95.5], ["MNG"]],
	# --- South East Asia ---
	["shan", [19.5, 24.5, 96.5, 101.2], ["MMR"]], ["arakanese", [16.0, 21.5, 92.0, 94.6], ["MMR"]],
	["hill", [21.5, 28.5, 92.5, 98.8], ["MMR"]], ["mon", [14.0, 17.8, 96.8, 99.0], ["MMR"]],
	["lanna", [17.5, 20.5, 97.3, 101.5], ["THA"]], ["malay", [5.5, 7.2, 100.5, 102.2], ["THA"]],
	["cham", [10.5, 14.0, 107.8, 109.5], ["VNM"]], ["khmer", [8.4, 11.6, 104.4, 107.2], ["VNM"]],
	["montagnard", [11.5, 15.5, 107.0, 108.4], ["VNM"]], ["lao", [20.5, 23.5, 102.0, 105.0], ["VNM"]],
	["dayak", [-4.0, 7.0, 108.5, 119.0], ["IDN", "MYS", "BRN"]],
	["javanese", [-8.9, -5.8, 108.8, 114.6], ["IDN"]], ["sundanese", [-7.9, -5.8, 105.0, 108.8], ["IDN"]],
	["balinese", [-8.9, -8.0, 114.4, 115.8], ["IDN"]], ["bugis", [-6.0, 2.0, 118.5, 125.5], ["IDN"]],
	["batak", [1.0, 3.5, 98.0, 100.0], ["IDN"]], ["moluccan", [-9.0, 3.0, 125.5, 131.0], ["IDN"]],
	["moluccan", [-11.0, -7.5, 116.0, 125.5], ["IDN"]], ["papuan", [-9.5, 0.0, 130.0, 141.5], ["IDN"]],
	["visayan", [9.0, 12.8, 121.5, 126.5], ["PHL"]], ["moro", [4.5, 9.9, 119.0, 127.0], ["PHL"]],
	# --- Africa ---
	["berber", [36.0, 37.0, 3.6, 6.5], ["DZA"]], ["berber", [34.8, 35.8, 5.8, 7.2], ["DZA"]],
	["tuareg", [18.0, 27.5, 3.0, 12.0], ["DZA", "LBY", "NER", "MLI"]],
	["berber", [34.6, 35.5, -4.5, -2.5], ["MAR"]], ["berber", [29.5, 33.5, -9.8, -3.0], ["MAR"]],
	["nubian", [18.0, 22.0, 29.0, 33.5], ["SDN", "EGY"]], ["sudanic", [11.0, 16.0, 22.0, 27.5], ["SDN"]],
	["sudanic", [9.5, 12.5, 27.5, 32.5], ["SDN"]],
	["tuareg", [15.0, 23.5, 13.5, 24.0], ["TCD"]], ["kanuri", [12.5, 15.0, 13.5, 17.0], ["TCD"]],
	["songhai", [11.5, 16.0, 0.0, 4.0], ["NER"]], ["kanuri", [13.0, 15.0, 11.0, 15.5], ["NER"]],
	["kanuri", [10.0, 14.0, 11.5, 14.7], ["NGA"]], ["nupe", [7.0, 10.5, 4.0, 11.5], ["NGA"]],
	["yoruba", [6.3, 9.4, 2.7, 5.7], ["NGA"]], ["edo", [5.5, 7.6, 5.0, 6.8], ["NGA"]], ["igbo", [4.4, 6.9, 6.7, 8.5], ["NGA"]],
	["mossi", [8.3, 11.2, -3.3, 0.6], ["GHA"]], ["kru", [4.3, 7.5, -8.6, -6.0], ["CIV"]], ["mande", [8.0, 10.8, -8.0, -2.5], ["CIV"]],
	["fulani", [10.2, 12.2, -13.5, -11.5], ["GIN"]], ["fulani", [14.0, 16.7, -14.0, -11.3], ["SEN"]],
	["mande", [12.3, 13.8, -16.8, -11.3], ["SEN"]], ["songhai", [15.0, 20.0, -5.0, 4.5], ["MLI"]],
	["tuareg", [18.5, 25.0, -5.0, 4.5], ["MLI"]], ["fulani", [13.5, 15.5, -6.0, -3.5], ["MLI"]],
	["sudanic", [8.0, 13.2, 11.0, 16.2], ["CMR"]], ["kongo", [-6.5, -4.0, 12.0, 16.5], ["COD"]],
	["kongo", [-5.5, -3.5, 11.0, 13.0], ["COG"]], ["kongo", [-8.5, -4.4, 11.5, 16.5], ["AGO"]],
	["central_bantu", [-17.5, -10.4, 34.5, 41.0], ["MOZ"]], ["nguni", [-27.0, -21.0, 31.0, 36.0], ["MOZ"]],
	["swahili", [[-15.03, 40.73], 60.0], ["MOZ"]], ["swahili", [[-20.15, 34.70], 60.0], ["MOZ"]],
	["khoisan", [-35.0, -26.0, 16.0, 24.5], ["ZAF"]], ["sotho", [-30.5, -24.5, 24.5, 29.5], ["ZAF"]],
	["central_bantu", [-19.5, -17.0, 13.0, 21.0], ["NAM"]],
	["nilotic", [-1.0, 1.0, 33.8, 35.0], ["KEN"]], ["somali", [0.0, 5.0, 38.5, 42.0], ["KEN"]],
	["nilotic", [2.0, 5.0, 34.0, 38.5], ["KEN"]], ["nilotic", [-3.0, -0.5, 35.0, 37.5], ["KEN"]],
	["swahili", [-4.8, -1.5, 39.0, 41.6], ["KEN"]], ["swahili", [-10.5, -4.5, 38.5, 40.6], ["TZA"]],
	["nilotic", [2.0, 4.3, 30.5, 34.5], ["UGA"]],
	["oromo", [3.4, 9.5, 34.0, 41.0], ["ETH"]], ["somali", [4.0, 9.5, 42.0, 48.0], ["ETH"]],
	["afar", [9.0, 14.5, 39.8, 43.0], ["ETH"]], ["afar", [12.5, 16.5, 39.5, 43.2], ["ERI"]],
	# --- The Americas ---
	["muskogean", [24.5, 36.0, -92.0, -79.0], ["USA"]], ["iroquoian", [40.5, 45.5, -80.5, -73.5], ["USA"]],
	["plains", [29.0, 49.0, -104.5, -94.0], ["USA"]], ["pueblo", [31.0, 38.0, -112.5, -103.0], ["USA"]],
	["pacific", [32.0, 49.0, -125.0, -112.5], ["USA"]], ["athabaskan", [54.0, 72.0, -170.0, -130.0], ["USA"]],
	["inuit", [58.0, 72.0, -170.0, -140.0], ["USA"]], ["polynesian", [18.0, 23.0, -161.0, -154.0], ["USA"]],
	["athabaskan", [55.0, 70.0, -141.0, -100.0], ["CAN"]], ["inuit", [60.0, 84.0, -141.0, -55.0], ["CAN"]],
	["inuit", [53.5, 60.0, -64.0, -55.0], ["CAN"]], ["iroquoian", [43.0, 46.5, -80.5, -73.0], ["CAN"]],
	["pacific", [48.0, 60.0, -133.0, -122.0], ["CAN"]], ["plains", [49.0, 54.0, -114.0, -100.0], ["CAN"]],
	["maya", [14.5, 21.7, -92.5, -86.5], ["MEX"]], ["zapotec", [15.6, 18.6, -98.6, -93.8], ["MEX"]],
	["purepecha", [18.6, 20.5, -103.5, -100.5], ["MEX"]], ["chichimec", [22.0, 33.0, -118.0, -97.0], ["MEX"]],
	["maya", [13.0, 16.0, -89.5, -87.0], ["HND"]],
	["carib", [11.5, 18.5, -64.5, -59.0], []],
	["amazonian", [0.0, 8.0, -72.0, -66.0], ["COL"]],
	["aymara", [-18.5, -14.5, -71.0, -68.5], ["PER"]], ["amazonian", [-13.0, 0.0, -76.0, -68.0], ["PER", "ECU"]],
	["amazonian", [-23.0, -10.0, -66.0, -57.5], ["BOL"]], ["guarani", [-23.0, -18.0, -64.0, -57.5], ["BOL"]],
	["aymara", [-28.0, -17.0, -71.0, -67.0], ["CHL"]],
	["quechua", [-28.0, -21.5, -68.0, -64.0], ["ARG"]], ["guarani", [-30.0, -22.0, -60.0, -53.5], ["ARG"]],
	["guarani", [-28.0, -22.0, -64.0, -58.0], ["ARG"]],
	["amazonian", [-12.0, 5.5, -74.0, -44.0], ["BRA"]], ["ge", [-20.0, -10.0, -60.0, -44.5], ["BRA"]],
	["guarani", [-34.0, -20.0, -58.0, -48.5], ["BRA"]],
]

## Realms whose land is theirs, wherever it lies.
const OWNERS := {
	"JIA": "jurchen", "HAI": "jurchen", "OIR": "oirat", "KHA": "mongol", "CHK": "mongol", "TMD": "mongol",
	"ORD": "mongol", "TIB": "tibetan", "LAD": "tibetan", "BLT": "tibetan", "SIB": "siberian_tatar", "NOG": "nogai",
	"CRI": "crimean_tatar", "KZH": "kazakh", "BUK": "uzbek", "KHI": "uzbek", "YRK": "uyghur", "TUP": "uyghur",
	"DGS": "dagestani", "KRT": "georgian", "KAK": "georgian", "IME": "georgian", "AKT": "japanese",
}
## Castilian where Spain's settlers had replaced the Taíno.
const SETTLED := {"SPA": ["CUB", "DOM", "HTI", "PRI", "JAM"]}

## Primary cultures that are not simply their capital's.
const STATE := {
	"TUR": "turkish", "SAF": "persian", "MUG": "hindustani", "SPA": "castilian", "AUS": "high_german",
	"PLC": "polish", "FRA": "french", "LEA": "french", "ENG": "english", "SCO": "scottish", "NED": "dutch",
	"SWE": "swedish", "DEN": "danish", "RUS": "russian", "MNG": "han", "JOS": "korean", "JAP": "japanese",
	"ABY": "amhara", "SAD": "maghrebi", "KON": "kongo", "POR": "portuguese", "CRI": "crimean_tatar",
	"VEN": "venetian", "JIA": "jurchen", "HAI": "jurchen", "OMA": "omani",
}


static func _hit(area: Array, lat: float, lon: float, adm: String, km: Callable) -> bool:
	if area.size() > 2 and not area[2].is_empty() and not adm in area[2]:
		return false
	var shape: Array = area[1]
	if shape.size() == 4:
		return lat >= shape[0] and lat <= shape[1] and lon >= shape[2] and lon <= shape[3]
	return km.call(lat, lon, shape[0][0], shape[0][1]) <= shape[1]


static func province_culture(adm: String, region: String, owner: String, lat: float, lon: float, km: Callable) -> String:
	var culture: String = BY_COUNTRY.get(adm, BY_REGION.get(region, "central_bantu"))
	for area: Array in AREAS:
		if _hit(area, lat, lon, adm, km):
			culture = area[0]
	if OWNERS.has(owner):
		culture = OWNERS[owner]
	if adm in SETTLED.get(owner, []):
		culture = "castilian"
	return culture
