class_name Cultures
extends RefCounted
## The peoples of the world in 1590, in culture groups. Every province holds
## one culture (Province.culture, from the scenario) and every country a
## primary culture (Country.culture). Two countries of one culture where one
## holds a core on the other's capital fight a civil war (MilitarySystem).
## The map colours each group in its own hue, each culture a shade of it.

## Group -> [name, hue].
const GROUPS := {
	"british": ["British", 0.0], "french": ["French", 0.62], "iberian": ["Iberian", 0.09],
	"italian": ["Italian", 0.32], "germanic": ["Germanic", 0.15], "nordic": ["Nordic", 0.55],
	"uralic": ["Uralic", 0.47], "baltic": ["Baltic", 0.42], "west_slavic": ["West Slavic", 0.92],
	"east_slavic": ["East Slavic", 0.04], "south_slavic": ["South Slavic", 0.75], "carpathian": ["Carpathian", 0.27],
	"hellenic": ["Hellenic", 0.58], "turkic": ["Turkic", 0.11], "caucasian": ["Caucasian", 0.82],
	"iranian": ["Iranian", 0.36], "arab": ["Arab", 0.13], "berber": ["Berber", 0.07], "indo_aryan": ["Indo-Aryan", 0.95],
	"dravidian": ["Dravidian", 0.5], "tibeto_burman": ["Tibeto-Burman", 0.68], "tai": ["Tai", 0.24],
	"austroasiatic": ["Austroasiatic", 0.44], "austronesian": ["Austronesian", 0.52], "east_asian": ["East Asian", 0.01],
	"altaic": ["Altaic", 0.19], "siberian": ["Siberian", 0.6], "west_african": ["West African", 0.08],
	"sudanic": ["Sudanic", 0.16], "east_african": ["East African", 0.3], "bantu": ["Bantu", 0.38],
	"southern_african": ["Southern African", 0.86], "mesoamerican": ["Mesoamerican", 0.05],
	"north_american": ["North American", 0.21], "andean": ["Andean", 0.12], "south_american": ["South American", 0.4],
	"oceanian": ["Oceanian", 0.57], "arctic": ["Arctic", 0.54],
}

## Culture -> [name, group].
const CATALOGUE := {
	"english": ["English", "british"], "scottish": ["Scots", "british"], "gaelic": ["Gaelic", "british"],
	"welsh": ["Welsh", "british"],
	"french": ["French", "french"], "occitan": ["Occitan", "french"], "breton": ["Breton", "french"],
	"walloon": ["Walloon", "french"],
	"castilian": ["Castilian", "iberian"], "catalan": ["Catalan", "iberian"], "portuguese": ["Portuguese", "iberian"],
	"galician": ["Galician", "iberian"], "basque": ["Basque", "iberian"],
	"lombard": ["Lombard", "italian"], "venetian": ["Venetian", "italian"], "tuscan": ["Tuscan", "italian"],
	"neapolitan": ["Neapolitan", "italian"], "sicilian": ["Sicilian", "italian"], "sardinian": ["Sardinian", "italian"],
	"high_german": ["High German", "germanic"], "low_german": ["Low German", "germanic"], "dutch": ["Dutch", "germanic"],
	"flemish": ["Flemish", "germanic"], "frisian": ["Frisian", "germanic"],
	"danish": ["Danish", "nordic"], "swedish": ["Swedish", "nordic"], "norwegian": ["Norwegian", "nordic"],
	"icelandic": ["Icelandic", "nordic"],
	"finnish": ["Finnish", "uralic"], "estonian": ["Estonian", "uralic"], "sami": ["Sámi", "uralic"],
	"volga_finnic": ["Volga Finnic", "uralic"], "hungarian": ["Hungarian", "uralic"],
	"lithuanian": ["Lithuanian", "baltic"], "latvian": ["Latvian", "baltic"],
	"polish": ["Polish", "west_slavic"], "czech": ["Czech", "west_slavic"], "slovak": ["Slovak", "west_slavic"],
	"russian": ["Russian", "east_slavic"], "ruthenian": ["Ruthenian", "east_slavic"],
	"belarusian": ["Belarusian", "east_slavic"],
	"slovene": ["Slovene", "south_slavic"], "croatian": ["Croatian", "south_slavic"], "serbian": ["Serbian", "south_slavic"],
	"bosniak": ["Bosniak", "south_slavic"], "bulgarian": ["Bulgarian", "south_slavic"],
	"romanian": ["Romanian", "carpathian"], "albanian": ["Albanian", "carpathian"],
	"greek": ["Greek", "hellenic"],
	"turkish": ["Turkish", "turkic"], "azeri": ["Azeri", "turkic"], "turkmen": ["Turkmen", "turkic"],
	"uzbek": ["Uzbek", "turkic"], "kazakh": ["Kazakh", "turkic"], "kyrgyz": ["Kyrgyz", "turkic"],
	"crimean_tatar": ["Crimean Tatar", "turkic"], "volga_tatar": ["Volga Tatar", "turkic"], "bashkir": ["Bashkir", "turkic"],
	"nogai": ["Nogai", "turkic"], "siberian_tatar": ["Siberian Tatar", "turkic"], "uyghur": ["Uyghur", "turkic"],
	"yakut": ["Yakut", "turkic"],
	"georgian": ["Georgian", "caucasian"], "armenian": ["Armenian", "caucasian"], "circassian": ["Circassian", "caucasian"],
	"dagestani": ["Dagestani", "caucasian"],
	"persian": ["Persian", "iranian"], "kurdish": ["Kurdish", "iranian"], "baluchi": ["Baluchi", "iranian"],
	"pashtun": ["Pashtun", "iranian"], "tajik": ["Tajik", "iranian"],
	"levantine": ["Levantine Arab", "arab"], "iraqi": ["Mesopotamian Arab", "arab"], "egyptian": ["Egyptian Arab", "arab"],
	"maghrebi": ["Maghrebi Arab", "arab"], "bedouin": ["Bedouin", "arab"], "yemeni": ["Yemeni", "arab"],
	"omani": ["Omani", "arab"], "sudanese": ["Sudanese Arab", "arab"],
	"berber": ["Berber", "berber"], "tuareg": ["Tuareg", "berber"],
	"hindustani": ["Hindustani", "indo_aryan"], "punjabi": ["Punjabi", "indo_aryan"], "sindhi": ["Sindhi", "indo_aryan"],
	"kashmiri": ["Kashmiri", "indo_aryan"], "gujarati": ["Gujarati", "indo_aryan"], "rajasthani": ["Rajasthani", "indo_aryan"],
	"marathi": ["Marathi", "indo_aryan"], "bengali": ["Bengali", "indo_aryan"], "oriya": ["Oriya", "indo_aryan"],
	"assamese": ["Assamese", "indo_aryan"], "nepali": ["Nepali", "indo_aryan"], "sinhala": ["Sinhala", "indo_aryan"],
	"telugu": ["Telugu", "dravidian"], "kannada": ["Kannada", "dravidian"], "tamil": ["Tamil", "dravidian"],
	"malayalam": ["Malayali", "dravidian"], "gond": ["Gond", "dravidian"],
	"tibetan": ["Tibetan", "tibeto_burman"], "burmese": ["Burmese", "tibeto_burman"], "arakanese": ["Arakanese", "tibeto_burman"],
	"hill": ["Hill peoples", "tibeto_burman"],
	"thai": ["Siamese", "tai"], "lao": ["Lao", "tai"], "shan": ["Shan", "tai"], "lanna": ["Lanna", "tai"],
	"khmer": ["Khmer", "austroasiatic"], "mon": ["Mon", "austroasiatic"], "vietnamese": ["Vietnamese", "austroasiatic"],
	"montagnard": ["Highlanders", "austroasiatic"],
	"malay": ["Malay", "austronesian"], "javanese": ["Javanese", "austronesian"], "sundanese": ["Sundanese", "austronesian"],
	"balinese": ["Balinese", "austronesian"], "bugis": ["Bugis", "austronesian"], "dayak": ["Dayak", "austronesian"],
	"batak": ["Batak", "austronesian"], "tagalog": ["Tagalog", "austronesian"], "visayan": ["Visayan", "austronesian"],
	"moro": ["Moro", "austronesian"], "moluccan": ["Moluccan", "austronesian"], "cham": ["Cham", "austronesian"],
	"malagasy": ["Malagasy", "austronesian"], "formosan": ["Formosan", "austronesian"],
	"han": ["Han", "east_asian"], "cantonese": ["Cantonese", "east_asian"], "min": ["Min", "east_asian"],
	"wu": ["Wu", "east_asian"], "korean": ["Korean", "east_asian"], "japanese": ["Japanese", "east_asian"],
	"ryukyuan": ["Ryukyuan", "east_asian"], "ainu": ["Ainu", "east_asian"],
	"mongol": ["Mongol", "altaic"], "oirat": ["Oirat", "altaic"], "jurchen": ["Jurchen", "altaic"],
	"evenk": ["Tungusic", "altaic"],
	"ugrian": ["Ugrian", "siberian"], "samoyed": ["Samoyed", "siberian"], "chukchi": ["Chukchi", "siberian"],
	"wolof": ["Wolof", "west_african"], "mande": ["Mande", "west_african"], "fulani": ["Fulani", "west_african"],
	"songhai": ["Songhai", "west_african"], "mossi": ["Mossi", "west_african"], "akan": ["Akan", "west_african"],
	"kru": ["Kru", "west_african"], "gbe": ["Ewe-Fon", "west_african"], "yoruba": ["Yoruba", "west_african"],
	"edo": ["Edo", "west_african"], "igbo": ["Igbo", "west_african"], "nupe": ["Nupe-Jukun", "west_african"],
	"hausa": ["Hausa", "sudanic"], "kanuri": ["Kanuri", "sudanic"], "sudanic": ["Central Sudanic", "sudanic"],
	"nubian": ["Nubian", "sudanic"], "nilotic": ["Nilotic", "sudanic"],
	"amhara": ["Amhara", "east_african"], "oromo": ["Oromo", "east_african"], "somali": ["Somali", "east_african"],
	"afar": ["Afar", "east_african"],
	"swahili": ["Swahili", "bantu"], "lakes_bantu": ["Lakes Bantu", "bantu"], "central_bantu": ["Central Bantu", "bantu"],
	"kongo": ["Kongo", "bantu"], "mbundu": ["Mbundu", "bantu"], "shona": ["Shona", "bantu"],
	"nguni": ["Nguni", "southern_african"], "sotho": ["Sotho-Tswana", "southern_african"], "khoisan": ["Khoisan", "southern_african"],
	"nahua": ["Nahua", "mesoamerican"], "maya": ["Maya", "mesoamerican"], "zapotec": ["Zapotec", "mesoamerican"],
	"purepecha": ["Purépecha", "mesoamerican"], "chichimec": ["Chichimec", "mesoamerican"], "chibcha": ["Chibcha", "mesoamerican"],
	"algonquian": ["Algonquian", "north_american"], "iroquoian": ["Iroquoian", "north_american"],
	"muskogean": ["Muskogean", "north_american"], "plains": ["Plains", "north_american"], "pueblo": ["Pueblo", "north_american"],
	"pacific": ["Pacific", "north_american"], "athabaskan": ["Dene", "north_american"],
	"taino": ["Taíno", "south_american"], "carib": ["Carib", "south_american"], "tupi": ["Tupi", "south_american"],
	"ge": ["Jê", "south_american"], "guarani": ["Guaraní", "south_american"], "amazonian": ["Amazonian", "south_american"],
	"pampean": ["Pampas and Patagonia", "south_american"],
	"quechua": ["Quechua", "andean"], "aymara": ["Aymara", "andean"], "mapuche": ["Mapuche", "andean"],
	"aboriginal": ["Aboriginal", "oceanian"], "maori": ["Māori", "oceanian"], "polynesian": ["Polynesian", "oceanian"],
	"melanesian": ["Melanesian", "oceanian"], "micronesian": ["Micronesian", "oceanian"], "papuan": ["Papuan", "oceanian"],
	"inuit": ["Inuit", "arctic"],
}

static var _colors := {}


static func has(id: String) -> bool:
	return CATALOGUE.has(id)


static func name_of(id: String) -> String:
	return CATALOGUE[id][0] if CATALOGUE.has(id) else "Unknown"


static func group_of(id: String) -> String:
	return CATALOGUE[id][1] if CATALOGUE.has(id) else ""


static func group_name(id: String) -> String:
	return GROUPS[group_of(id)][0] if GROUPS.has(group_of(id)) else ""


## The group's hue; each culture of the group a shade of it (lighter and
## darker in turn, the hue nudged), so neighbours of one group stay apart.
static func color_of(id: String) -> Color:
	if _colors.is_empty():
		var index := {}
		for c: String in CATALOGUE:
			var g: String = CATALOGUE[c][1]
			var i: int = index.get(g, 0)
			index[g] = i + 1
			var hue: float = fposmod(GROUPS[g][1] + 0.025 * ((i % 3) - 1), 1.0)
			var value: float = [0.82, 0.62, 0.92, 0.52, 0.72][i % 5]
			var sat: float = [0.55, 0.65, 0.4, 0.7, 0.5][(i / 2) % 5]
			_colors[c] = Color.from_hsv(hue, sat, value)
	return _colors.get(id, Color(0.6, 0.6, 0.6))
