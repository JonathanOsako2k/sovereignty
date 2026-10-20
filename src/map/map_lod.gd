class_name MapLod
extends RefCounted
## Discrete levels of map detail chosen from the zoom, with hysteresis: a level
## is entered at one zoom and only left at a lower one, so layers never flicker
## when the zoom hovers near a threshold.
##
##   WORLD     country borders and names, wastelands, major capitals
##   REGION    + province borders, forests and peaks, every capital
##   PROVINCE  + province names (country names give way)
##   DETAIL    closest zoom; everything at full size

enum Level { WORLD, REGION, PROVINCE, DETAIL }

## Zoom at which level k is entered when zooming in...
const ENTER := [0.0, 0.62, 1.9, 4.0]
## ...and the lower zoom at which it is left when zooming out.
const LEAVE := [0.0, 0.52, 1.6, 3.4]

var level: Level = Level.WORLD


## Returns true when the level changed.
func update(zoom: float) -> bool:
	var next := level
	while next < Level.DETAIL and zoom >= ENTER[next + 1]:
		next += 1
	while next > Level.WORLD and zoom < LEAVE[next]:
		next -= 1
	var changed := next != level
	level = next
	return changed


## Hysteresis for a single on/off property: shown once `value` reaches
## `show_at`, hidden again only when it drops below `hide_below`.
static func keep_shown(shown: bool, value: float, show_at: float, hide_below: float) -> bool:
	return value >= hide_below if shown else value >= show_at
