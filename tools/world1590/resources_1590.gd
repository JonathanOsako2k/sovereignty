extends RefCounted
## Goods of the world in 1590, for the world generator: what famous districts
## produced, deposits and crops that arrive in their era, and the workshops,
## markets and customs houses already at work. Everything else gets a good
## from its land (see fallback()).
##
## SITES: [good, radius_km, [[lat, lon], ...]] — a province whose centre lies
## within the radius of an anchor (nearest anchor wins), or that contains an
## anchor, produces that good.

const SITES := [
	# Silver and gold
	["silver", 160, [[-19.58, -65.75]]],  # Potosí
	["silver", 140, [[22.77, -102.58], [21.02, -101.26]]],  # Zacatecas, Guanajuato
	["silver", 60, [[18.56, -99.60], [20.12, -98.73]]],  # Taxco, Pachuca
	["silver", 50, [[35.11, 132.44]]],  # Iwami Ginzan
	["silver", 40, [[49.95, 15.27], [47.35, 11.71], [50.91, 13.34], [50.37, 12.91], [48.45, 18.90], [59.92, 16.60]]],
	["gold", 200, [[6.20, -1.80]]],  # Akan goldfields (Gold Coast)
	["gold", 150, [[13.50, -11.50], [11.80, -8.70]]],  # Bambuk, Bure
	["gold", 250, [[-18.50, 31.50]]],  # Mutapa
	["gold", 140, [[6.25, -75.56], [5.70, -76.65]]],  # Antioquia, Chocó
	["gold", 35, [[48.70, 18.92]]],  # Kremnica
	# Base metals, salt, kaolin, coal
	["copper", 60, [[60.60, 15.63]]],  # Falun
	["copper", 50, [[51.60, 11.45], [35.00, 33.00]]],  # Mansfeld, Cyprus
	["copper", 250, [[-11.00, 27.00]]],  # Katanga
	["iron", 120, [[60.00, 15.00]]],  # Bergslagen
	["iron", 50, [[47.52, 14.92], [48.04, 14.42], [43.26, -2.93], [50.63, 5.57], [49.44, 11.86], [45.54, 10.22], [51.17, 7.08]]],
	["iron", 150, [[37.80, 112.50]]],  # Shanxi
	["iron", 50, [[35.30, 133.00]]],  # Izumo tatara iron
	["tin", 60, [[50.30, -5.00], [23.36, 103.15]]],  # Cornwall, Gejiu
	["tin", 150, [[4.60, 101.10]]],  # Perak
	["salt", 40, [[49.98, 20.05], [47.70, 13.60], [53.25, 10.41], [53.20, -2.50]]],
	["salt", 200, [[22.67, -3.98], [14.20, 40.30]]],  # Taoudenni, Danakil
	["salt", 80, [[29.35, 104.77]]],  # Zigong
	["kaolin", 60, [[29.27, 117.18]]],  # Jingdezhen
	["coal", 45, [[54.97, -1.61]]],  # Newcastle's coal trade
	# Spices, silk, tea, coffee, cocoa, sugar, tobacco, cotton, dyes
	["spices", 300, [[0.79, 127.38]]],  # Moluccas: cloves
	["spices", 200, [[-4.53, 129.90]]],  # Banda: nutmeg
	["spices", 250, [[10.50, 76.20]]],  # Malabar pepper
	["spices", 200, [[7.00, 80.00]]],  # Ceylon cinnamon
	["spices", 250, [[5.00, 96.00], [-6.10, 106.10]]],  # Aceh, Banten pepper
	["silk", 200, [[31.30, 120.60], [30.27, 120.15]]],  # Jiangnan
	["silk", 150, [[37.27, 49.58]]],  # Gilan
	["silk", 60, [[40.18, 29.06], [45.76, 4.84], [43.80, 10.50], [37.18, -3.60]]],  # Bursa, Lyon, Lucca, Granada
	["silk", 20, [[35.03, 135.75]]],  # Kyoto (Nishijin)
	["tea", 250, [[26.00, 118.00]]],  # Fujian
	["tea", 150, [[30.00, 118.20], [22.80, 101.00]]],  # Anhui, Yunnan
	["tea", 50, [[34.88, 135.80]]],  # Uji
	["coffee", 150, [[13.32, 43.25], [15.35, 44.20]]],  # Yemen
	["coffee", 150, [[9.31, 42.12], [7.30, 36.20]]],  # Harar, Kaffa
	["cocoa", 150, [[17.99, -92.93], [14.90, -92.30]]],  # Tabasco, Soconusco
	["cocoa", 150, [[10.50, -66.90]]],  # Caracas coast
	["sugar", 250, [[-8.05, -34.90]]],  # Pernambuco
	["sugar", 200, [[-12.97, -38.50]]],  # Bahia
	["sugar", 80, [[0.33, 6.73]]],  # São Tomé
	["sugar", 40, [[32.65, -16.90]]],  # Madeira
	["sugar", 150, [[28.30, -16.50]]],  # Canaries
	["sugar", 200, [[19.00, -70.50]]],  # Hispaniola
	["sugar", 100, [[30.40, -9.60]]],  # Sous (Saadi sugar)
	["tobacco", 250, [[22.00, -79.00]]],  # Cuba
	["tobacco", 150, [[8.60, -70.20]]],  # Barinas
	["cotton", 250, [[23.00, 72.60]]],  # Gujarat
	["cotton", 200, [[23.70, 90.40]]],  # Bengal
	["cotton", 120, [[30.80, 31.00]]],  # Nile Delta
	["cotton", 100, [[37.00, 35.30]]],  # Çukurova
	["cotton", 150, [[40.50, 71.50]]],  # Fergana
	["dyes", 150, [[14.60, -90.50]]],  # Guatemalan indigo
	["dyes", 150, [[17.06, -96.72]]],  # Oaxaca cochineal
	["dyes", 80, [[43.60, 1.44]]],  # Toulouse pastel (woad)
	["dyes", 60, [[51.00, 11.00]]],  # Thuringian woad
	# Wine and wool country (the weaving towns first: they work wool, not the
	# vineyards around them)
	["wool", 60, [[51.05, 3.72], [52.63, 1.30]]],  # Flanders, Norfolk (weaving towns)
	["wool", 30, [[43.77, 11.25], [52.16, 4.49]]],  # Florence, Leiden (weaving towns)
	["wine", 100, [[44.84, -0.58]]],  # Bordeaux
	["wine", 80, [[47.00, 4.80], [50.00, 7.60], [43.50, 11.20], [41.15, -8.61], [36.68, -6.13]]],
	["wine", 40, [[48.12, 21.41]]],  # Tokaj
	["wool", 250, [[40.00, -4.00]]],  # Castile: the Mesta's merino flocks
	["wool", 200, [[52.50, -1.50]]],  # English wool country
	# Sea, forest and wild
	["fish", 300, [[47.50, -53.00]]],  # Grand Banks
	["fish", 300, [[63.00, 9.00], [68.20, 14.00]]],  # Norwegian coast, Lofoten stockfish
	["fish", 60, [[58.40, 11.50]]],  # Bohuslän herring
	["naval_supplies", 200, [[56.95, 24.10]]],  # Riga
	["naval_supplies", 150, [[64.54, 40.54]]],  # Archangel
	["ivory", 400, [[-3.00, 35.00]]],  # East African interior
	["ivory", 200, [[7.50, -5.50]]],  # Ivory Coast
	["tropical_wood", 250, [[-12.00, -38.00]]],  # brazilwood coast
	# Gems
	["gems", 150, [[16.50, 78.50]]],  # Golconda diamonds
	["gems", 100, [[6.70, 80.40], [22.92, 96.50], [36.70, 71.00]]],  # Ratnapura, Mogok, Badakhshan
	["gems", 60, [[5.53, -74.10]]],  # Muzo emeralds
	["livestock", 30, [[37.88, -4.78]]],  # Córdoba hides (cordovan leather)
]

## Deposits and crops revealed in their era: [good, year, chance a year from
## then on, radius_km, [[lat, lon], ...]]. A province whose centre lies within
## the radius gets the deposit; once the year has come it may be found.
const DEPOSITS := [
	# Gold and silver rushes
	["gold", 1601, 0.5, 40, [[38.05, 138.40]]],  # Sado
	["gold", 1693, 0.3, 200, [[-20.40, -43.50]]],  # Minas Gerais
	["gold", 1725, 0.3, 250, [[-16.00, -50.00]]],  # Goiás
	["gold", 1846, 0.3, 200, [[57.85, 114.20]]],  # Lena goldfields
	["gold", 1848, 0.6, 150, [[38.60, -121.00]]],  # California
	["gold", 1851, 0.6, 150, [[-37.50, 144.00]]],  # Victoria
	["gold", 1858, 0.4, 100, [[39.70, -105.20]]],  # Colorado
	["gold", 1861, 0.4, 100, [[-45.00, 169.50]]],  # Otago
	["gold", 1874, 0.4, 100, [[44.00, -103.50]]],  # Black Hills
	["gold", 1886, 0.6, 100, [[-26.20, 28.00]]],  # Witwatersrand
	["gold", 1893, 0.5, 150, [[-30.75, 121.47]]],  # Kalgoorlie
	["gold", 1896, 0.6, 150, [[64.00, -139.40]]],  # Klondike
	["silver", 1623, 0.5, 40, [[59.67, 9.65]]],  # Kongsberg
	["silver", 1630, 0.4, 80, [[-10.68, -76.26]]],  # Cerro de Pasco
	["silver", 1859, 0.5, 80, [[39.30, -119.65]]],  # Comstock Lode
	["silver", 1883, 0.5, 100, [[-31.95, 141.45]]],  # Broken Hill
	["kaolin", 1616, 0.5, 40, [[33.20, 129.88]]],  # Arita
	# Coal fields of the industrial age
	["coal", 1700, 0.3, 80, [[53.50, -1.50]]], ["coal", 1700, 0.3, 40, [[50.45, 4.00]]],
	["coal", 1750, 0.3, 60, [[51.45, 7.00], [49.30, 7.00], [50.40, 3.00], [55.85, -3.90]]],
	["coal", 1750, 0.3, 80, [[50.30, 18.90]]], ["coal", 1760, 0.3, 60, [[51.70, -3.40]]],
	["coal", 1790, 0.3, 120, [[48.00, 38.00]]], ["coal", 1800, 0.3, 80, [[-32.90, 151.70]]],
	["coal", 1820, 0.3, 120, [[41.00, -76.00]]], ["coal", 1850, 0.3, 150, [[37.80, -81.20]]],
	["coal", 1850, 0.3, 200, [[54.00, 87.00]]], ["coal", 1870, 0.3, 60, [[33.65, 130.70]]],
	["coal", 1880, 0.3, 150, [[37.80, 112.50]]], ["coal", 1901, 0.4, 100, [[41.85, 123.90]]],
	# Petroleum
	["petroleum", 1846, 0.4, 80, [[40.40, 49.90]]],  # Baku
	["petroleum", 1854, 0.4, 60, [[49.30, 23.40]]],  # Boryslav
	["petroleum", 1857, 0.4, 60, [[44.95, 26.00]]],  # Ploiești
	["petroleum", 1859, 0.6, 100, [[41.60, -79.70]]],  # Pennsylvania
	["petroleum", 1885, 0.4, 100, [[4.00, 98.30]]],  # Sumatra
	["petroleum", 1887, 0.4, 80, [[20.46, 94.88]]],  # Yenangyaung
	["petroleum", 1889, 0.4, 60, [[27.40, 95.60]]],  # Digboi
	["petroleum", 1892, 0.4, 100, [[34.00, -118.20]]],  # Los Angeles basin
	["petroleum", 1893, 0.4, 80, [[43.30, 45.70]]],  # Grozny
	["petroleum", 1897, 0.4, 100, [[-1.25, 116.80]]],  # Balikpapan
	["petroleum", 1901, 0.5, 150, [[30.00, -94.10]]],  # Spindletop
	["petroleum", 1901, 0.4, 150, [[22.20, -97.90]]],  # Tampico
	["petroleum", 1905, 0.4, 150, [[36.00, -96.00]]],  # Oklahoma
	["petroleum", 1908, 0.5, 150, [[31.90, 49.30]]],  # Masjed Soleyman
	["petroleum", 1908, 0.4, 60, [[10.20, -61.60]]],  # Trinidad
	["petroleum", 1914, 0.5, 150, [[10.40, -71.50]]],  # Maracaibo
	["petroleum", 1927, 0.5, 120, [[35.47, 44.39]]],  # Kirkuk
	["petroleum", 1932, 0.5, 50, [[26.00, 50.55]]],  # Bahrain
	["petroleum", 1938, 0.5, 150, [[26.40, 50.10]]],  # Dammam
	["petroleum", 1938, 0.5, 80, [[28.90, 47.90]]],  # Burgan
	["petroleum", 1947, 0.5, 150, [[53.30, -113.50]]],  # Leduc
	# Rare earths and uranium
	["rare_earths", 1787, 0.5, 20, [[59.43, 18.35]]],  # Ytterby
	["rare_earths", 1886, 0.3, 100, [[-20.50, -40.30]]],  # Brazilian monazite sands
	["rare_earths", 1909, 0.3, 80, [[8.90, 76.60]]],  # Travancore sands
	["rare_earths", 1927, 0.5, 100, [[41.80, 109.97]]],  # Bayan Obo
	["rare_earths", 1949, 0.5, 60, [[35.48, -115.53]]],  # Mountain Pass
	["uranium", 1898, 0.4, 30, [[50.37, 12.91]]],  # Joachimsthal (radium)
	["uranium", 1898, 0.3, 150, [[38.00, -108.50]]],  # Colorado Plateau carnotite
	["uranium", 1915, 0.5, 60, [[-11.05, 26.60]]],  # Shinkolobwe
	["uranium", 1930, 0.5, 100, [[66.10, -118.00]]],  # Great Bear Lake
	["uranium", 1946, 0.5, 60, [[50.60, 12.70]]],  # Erzgebirge (Wismut)
	# Crops that arrive in their time
	["tobacco", 1612, 0.5, 150, [[37.30, -76.80]]],  # Virginia
	["tobacco", 1634, 0.5, 80, [[38.90, -76.60]]],  # Maryland
	["sugar", 1640, 0.6, 30, [[13.10, -59.60]]],  # Barbados
	["sugar", 1650, 0.5, 40, [[14.60, -61.00], [16.20, -61.50]]],  # Martinique, Guadeloupe
	["sugar", 1660, 0.5, 100, [[18.10, -77.30]]],  # Jamaica
	["sugar", 1700, 0.5, 100, [[19.00, -72.50]]],  # Saint-Domingue
	["sugar", 1730, 0.4, 40, [[-20.20, 57.50]]],  # Mauritius
	["sugar", 1790, 0.3, 200, [[22.50, -80.50]]],  # Cuba
	["sugar", 1795, 0.3, 100, [[30.00, -91.00]]],  # Louisiana
	["sugar", 1830, 0.3, 200, [[-7.30, 111.50]]],  # Java
	["sugar", 1850, 0.4, 100, [[20.80, -156.30]]],  # Hawaii
	["sugar", 1865, 0.3, 200, [[-21.00, 148.50]]],  # Queensland
	["coffee", 1711, 0.3, 200, [[-7.00, 107.60]]],  # Java
	["coffee", 1820, 0.3, 300, [[-22.50, -45.00]]],  # Brazil
	["coffee", 1830, 0.4, 100, [[7.00, 80.70]]],  # Ceylon
	["coffee", 1840, 0.3, 200, [[14.00, -89.00]]],  # Central America
	["coffee", 1850, 0.3, 200, [[5.00, -75.50]]],  # Colombia
	["tea", 1837, 0.4, 200, [[27.00, 94.00]]],  # Assam
	["tea", 1850, 0.4, 60, [[27.00, 88.30]]],  # Darjeeling
	["tea", 1867, 0.5, 100, [[6.95, 80.78]]],  # Ceylon
	["cotton", 1793, 0.3, 350, [[32.50, -86.00], [33.00, -90.00], [32.00, -83.50]]],  # cotton South
	["cocoa", 1750, 0.3, 150, [[-14.80, -39.00]]],  # Bahia
	["cocoa", 1880, 0.3, 50, [[3.50, 8.70]]],  # Fernando Po
	["spices", 1818, 0.5, 60, [[-6.10, 39.30]]],  # Zanzibar cloves
	["rubber", 1840, 0.4, 400, [[-3.10, -60.00]]],  # Amazon
	["rubber", 1870, 0.3, 200, [[-9.97, -67.80]]],  # Acre
	["rubber", 1890, 0.3, 500, [[0.00, 22.00]]],  # Congo
	["rubber", 1900, 0.4, 200, [[3.00, 101.50]]],  # Malaya
	["rubber", 1906, 0.4, 150, [[3.60, 98.70]]],  # Sumatra
	["rubber", 1926, 0.4, 100, [[6.30, -10.50]]],  # Liberia
]

## Chance (per hilly or mountain province) of an unknown gold vein,
## findable from 1590 at this yearly chance.
const GOLD_VEIN_SHARE := 0.03
const GOLD_VEIN_CHANCE := 0.01

## Buildings at work on 1 January 1590: [building, [[lat, lon], ...]] — in the
## province containing each point.
const STARTING_BUILDINGS := [
	["weavery", [[51.05, 3.72], [51.21, 3.22], [52.16, 4.49], [43.77, 11.25], [52.63, 1.30], [45.76, 4.84],
		[40.18, 29.06], [31.30, 120.62], [30.27, 120.15], [23.03, 72.58], [23.72, 90.41], [35.03, 135.75]]],
	["kilns", [[29.27, 117.18]]],  # Jingdezhen
	["ironworks", [[49.44, 11.86], [50.63, 5.57], [48.04, 14.42], [45.54, 10.22], [51.17, 7.08]]],
	["tannery", [[37.88, -4.78]]],  # Córdoba
	["marketplace", [[51.22, 4.40], [52.37, 4.90], [45.44, 12.33], [44.41, 8.93], [38.72, -9.14], [37.39, -5.99],
		[51.51, -0.13], [53.87, 10.69], [41.01, 28.98], [30.04, 31.24], [27.18, 78.01], [2.19, 102.25],
		[23.13, 113.26], [32.75, 129.87], [27.10, 56.45], [50.11, 8.68], [49.45, 11.08], [48.37, 10.90]]],
	# Seville's fleets cleared at Sanlúcar and Cádiz; with Antwerp blockaded
	# since 1585, the Dutch levied the Scheldt licences at Flushing.
	["customs_house", [[36.53, -6.29], [38.72, -9.14], [51.51, -0.13], [52.37, 4.90], [51.44, 3.57],
		[45.44, 12.33], [27.10, 56.45], [2.19, 102.25], [23.13, 113.26], [32.75, 129.87], [56.04, 12.61]]],
	["mine", [[-19.58, -65.75], [22.77, -102.58], [35.11, 132.44], [60.60, 15.63], [49.98, 20.05]]],
	["plantation", [[-8.05, -34.90], [0.33, 6.73]]],
]


## A good from the land, for provinces no site claims. `h` is a stable
## per-province number in [0, 1) for variety.
static func fallback(veg: String, topo: String, climate: String, coastal: bool, lat: float, lon: float, h: float) -> String:
	var cold := climate in ["subarctic", "arctic"]
	var tropical := climate in ["equatorial", "tropical"]
	var africa := lon > -20.0 and lon < 52.0 and lat < 15.0 and lat > -35.0
	if topo == "wetlands":
		return "fish"
	if coastal and (cold or climate == "oceanic") and h < 0.3:
		return "fish"
	if topo == "mountains" and veg != "farmland":
		if h < 0.12:
			return "iron"
		if h < 0.2:
			return "copper"
	match veg:
		"farmland":
			if climate == "mediterranean":
				return "wine" if h < 0.35 else "grain"
			if climate == "oceanic":
				return "wool" if h < 0.25 else "grain"
			if tropical:
				return "cotton" if h < 0.25 else "grain"
			return "grain"
		"grasslands":
			return "wool" if climate == "cold_arid" and h < 0.3 else "livestock"
		"sparse":
			if cold:
				return "furs" if h < 0.5 else ("fish" if coastal else "livestock")
			if climate in ["hot_arid", "cold_arid"] and h < 0.2:
				return "salt"
			return "livestock"
		"desert":
			return "salt" if h < 0.3 else "livestock"
		"woods":
			if climate == "mediterranean":
				return "wine" if h < 0.4 else "livestock"
			if tropical:
				return "tropical_wood" if h < 0.3 else ("ivory" if africa and h < 0.45 else "grain")
			return "timber" if h < 0.4 else ("livestock" if h < 0.7 else "grain")
		"forest":
			if cold:
				return "furs" if h < 0.6 else "timber"
			if coastal and h < 0.25:
				return "naval_supplies"
			return "timber"
		"jungle":
			if africa and h < 0.25:
				return "ivory"
			return "tropical_wood" if h < 0.6 else "grain"
	return "grain"
