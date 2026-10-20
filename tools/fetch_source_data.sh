#!/usr/bin/env bash
# Downloads the public source data the world generator needs (~85 MB) into
# tools/source_data/. It is not committed to git and never ships with the game.
#   * Natural Earth vector layers (public domain), ~66 MB
#   * Köppen-Geiger climate classification, 0.5° grid, 1951-2000
#     (Kottek et al. 2006, doi:10.1127/0941-2948/2006/0130), ~245 kB; cite it
#   * ETOPO1 elevation (NOAA NGDC, public domain) sampled every 5 arc-minutes
#     from an ERDDAP server, ~18.7 MB netCDF
set -euo pipefail
cd "$(dirname "$0")/source_data" 2>/dev/null || { mkdir -p "$(dirname "$0")/source_data"; cd "$(dirname "$0")/source_data"; }
BASE="https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"
for f in ne_50m_admin_0_countries ne_50m_lakes ne_50m_geography_regions_polys ne_10m_populated_places_simple \
		ne_10m_admin_1_states_provinces ne_10m_rivers_lake_centerlines ne_10m_geography_marine_polys; do
	echo "Fetching $f"
	curl -sSL -o "$f.geojson" "$BASE/$f.geojson"
done

echo "Fetching Koeppen-Geiger climate map"
curl -sSL -o Koeppen-Geiger-ASCII.zip "https://koeppen-geiger.vu-wien.ac.at/data/Koeppen-Geiger-ASCII.zip"
unzip -o -q Koeppen-Geiger-ASCII.zip && rm Koeppen-Geiger-ASCII.zip

echo "Fetching ETOPO1 elevation (every 5 arc-minutes)"
curl -sSL -o etopo1_5min.nc \
	"https://tds.marine.rutgers.edu/erddap/griddap/etopo180.nc?altitude%5B(-90.0):5:(90.0)%5D%5B(-180.0):5:(180.0)%5D"
