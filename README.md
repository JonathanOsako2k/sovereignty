# Sovereignty

A mobile-first historical grand-strategy game (1590–1949), built with **Godot 4.7**
(Mobile renderer), Android first.

* `structure.md` — the design brief: vision, systems, constraints.
* `PLAN.md` — how the brief maps onto this Godot project, and the milestone
  build order. **Current state: Milestones 0–5 — the real world of 1 January 1590
  (5000 ownable provinces, ~100 impassable wastelands, ~580 sea tiles, 238 polities,
  wrap-around map from 76°N to 62°S); choose any country; country panels; occupation
  shown on the map; save, load and autosave; a simulation scheduler; diplomacy
  (subjects, alliances, marriages, rivals); an economy of estates, goods,
  buildings, tax policy, loans and bankruptcy (no armies yet).**

## Running

Open the folder in Godot 4.7 and press **F5**, or run from a terminal:

```bash
godot --path .
```

(`godot` is the Godot 4.7 executable, e.g. `D:/Programs/Godot_v4.7.1-stable_win64_console.exe`.)

The game opens on a loading screen (the title painting, what is being loaded
and a progress bar), then the title menu: **New campaign** zooms out to the 1590
world — tap a country and press **Play as …**. **Continue** loads the newest
save. Starting a campaign and loading a save show the loading screen too.
On phones the game is landscape-only.

The map's lettering is drawn from distance-field glyphs that take seconds to
make on a phone: the first start makes them and keeps them on the device
(`user://cache/map_font.res`), so later starts load them in milliseconds.

### Controls

| Action | Touch | Desktop |
| --- | --- | --- |
| Select province | Tap | Left click |
| Country panel | Tap its name on the map (tap again for the province underneath), or the owner in a province panel | same, with clicks |
| Your country | Tap its name in the top bar: its panel, and the map framed on its home | same, with clicks |
| Menu (save / load / main menu) | ☰, or Android back | ☰ or Esc |
| Pan | Drag | Drag (any button), WASD / arrows |
| Zoom | Pinch | Wheel, trackpad pinch, `+` / `-` |
| Pause / play | Play button | Space |
| Speed | − / + buttons | 1–5 |
| Deselect | ✕ on the panel, or back | Esc |

The game pauses automatically when the app is backgrounded or loses focus, and
never advances while closed.

### Saves

Where the files are (the **Saved games** page shows the exact folder):

* **Android:** `Documents/Sovereignty` on the phone's shared storage — visible in
  the Files app and over USB. If the game cannot write there, it falls back to
  its own folder `Android/data/<package>/files/Documents/Sovereignty` (reachable
  over USB), and only then to private app storage. Android lets an app read the
  files it created itself; after uninstalling and reinstalling, older saves stay
  in the folder but the game may no longer see them.
* **Desktop:** `user://saves` (on Windows `%APPDATA%/Godot/app_userdata/Sovereignty/saves`).

Each save is one file, `<slot>.srt` (the game's own extension; the content is
JSON), with a format tag, `schema_version`,
the world-data version and an MD5 fingerprint of the province-id map it was made with, and
a timestamp; static map data is not duplicated. Writing is atomic (`<slot>.tmp.srt`
→ read back and checked → the previous save becomes `<slot>.bak.srt` → rename),
and a damaged save can be recovered from its backup in the load menu. Saves
from a different world-data version or a regenerated map are listed but
refused with an explanation. The campaign autosaves (slot `autosave`) every
1 January, when the app goes to the background and when the window closes.

## Tests

Headless, no window needed. Run an import first on a fresh checkout so Godot
registers the script classes:

```bash
godot --headless --path . --import
```

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

The runner exits non-zero if any test fails, including when a test hits a script
error. Tests live in `tests/test_*.gd`; `test_game_flow.gd` drives the real scene
headlessly (title → choose a country → play → save → continue → autosave).

## The 1590 world and how it is generated

`tools/world1590/` builds the map from public-domain [Natural Earth](https://www.naturalearthdata.com)
data plus authored 1590 history. Fetch the source data once (~85 MB, not in git — Natural Earth, the
Köppen-Geiger climate grid and ETOPO1 elevation):

```bash
bash tools/fetch_source_data.sh
```

Then regenerate (about four minutes, deterministic):

```bash
godot --headless --path . --script res://tools/world1590/build_world.gd
```

It writes `data/map/province_ids.res`, `heightmap.res`, `rivers.json`,
`data/world/provinces.json`, `countries.json` and `data/scenarios/1590.json`.

* **Provinces** are built on real first-level divisions (counties, départements,
  provinces, states): small ones merge, large ones split, so each region gets
  exactly its quota of the 5000 ownable provinces — Europe 25%, China/Korea/Japan
  18%, India 13%, Middle East & Central Asia 11%, Africa 10%, South East Asia 8%,
  North America 6.5%, South America 4.5%, Oceania 1.5%, other 2.5%. Splits grow
  from seeds with high costs for crossing rivers and mountains, so interior
  borders follow them. Names are the division, its main town, or its river.
* **Wastelands** (desert and high-mountain cores, Greenland ice, the high Arctic)
  are impassable and unownable, on top of the 5000. Historic routes — the Nile,
  the trans-Saharan roads, the Silk Road, the Kalgan road — are kept as passable
  corridors, and no province is walled in.
* **Politics** come from `polities_1590.gd`: each modern country maps to who held
  it on 1 January 1590 (nearest-anchor claims with radii). `regions_1590.gd`
  holds quotas, ~1600 population estimates, terrain rules and historic names.
* **Faith** comes from `religions_1590.gd`: a base by modern country, regional
  exceptions (Huguenot France, Catholic Brabant, Westphalia and Upper Swabia,
  Lutheran Silesia and Upper Austria, Muslim Kazan and the Caucasus, Shia
  southern Iraq, Tibet, animist Borneo and Mindanao, the Swahili coast …),
  realms whose land shares their faith (the Scottish kirk, the
  prince-bishoprics, the sultanates), and the Catholic Americas and
  Philippines; and each realm's state religion.
* **Fortresses** standing in 1590 (`resources_1590.gd`): the bastioned towns
  of the Low Countries and Italy, the Habsburg–Ottoman frontier in Hungary,
  the Baltic, Russia's kremlins, Venice's and Iberia's strongholds overseas,
  India's great forts, the Ming walls and Japan's castles — besides the
  capitals of larger realms.
* **Sea tiles** split every water body over 15,000 km² (about 330 km apart along
  coasts, up to 1,300 km in open ocean), named from Natural Earth's seas, gulfs
  and straits ("Coast of …" when a name is taken). Land provinces record the
  sea tiles they touch; sea tiles record their coasts and neighbouring seas.
* **1590 water:** the Aral Sea at its full historical extent, and the
  Zuiderzee open to the sea (no Flevoland, Noordoostpolder, Wieringermeer or
  Afsluitdijk).
* Ownership falls back to the nearest claimant inside divisions known to be
  settled in 1590 (`SETTLED_DIVISIONS`), so gaps between anchor radii never
  show settled land as uncolonised.
* Wastelands follow geography only (desert, range, plateau and tundra cores,
  Greenland's ice, high-Arctic islands) — never a straight latitude line.
* The map **wraps east-west** (seam in the Bering Sea) and spans 76°N–62°S, so
  the Barents Sea and the Drake Passage are open, sailable water.

### 1590

The world as it stood on 1 January 1590. **France** is in civil war: Henry IV,
his government at Tours, against the **Catholic League**, which holds Paris,
Rouen, Lyon, Marseille, Toulouse, Dijon and Mercœur's Brittany. Spain is not at
war with France, but its volunteers fight for the League and Philip II pays it a
subsidy. **The United Provinces** are at war with Spain, with cores on the
Netherlands Spain still holds and claims on the Spanish Netherlands; the
Zuiderzee is open water. In the north-east, **the Jurchens** claim each other's
land and Nurhaci's Jianzhou is quick to war: united, they may form
**Manchuria**, which then claims all Jurchen land and takes the Wild Jurchens'
uncolonised country by marching an army in and paying a small fee instead of
settling it.

Every province has its **people** (about 150 cultures in groups, each with a
shade of its group's hue on the **Culture** map mode) and every country a
primary culture. Tap a country and its panel opens on the left with its flag
(historical flags where there are any, else one drawn in its colours). Starting
or loading a campaign shows your flag, name and year in the middle of the
screen for a moment.

### Diplomacy

Tap another country to see how it regards you — every reason listed (allies,
royal marriage, rivals, gifts, insults, envoys…) — and act: improve relations
(two envoys), send a gift, send an insult, declare or remove a rival, propose or
break an alliance or royal marriage (monarchies only), demand vassalage of a weaker
neighbour, or release a subject. Proposals show how the other side weighs them
before you confirm. Countries start with their 1590 ties: the Iberian Union
(Portugal its own kingdom in personal union with Spain), the Ottoman, Polish,
Ming and Toyotomi vassals and tributaries, the Treaty of Nonsuch, and the
rivalries of the day. AI countries act monthly by the same rules. The Diplomacy
map mode colours the world by its relation to the selected country (or yours),
and any country's panel lists its own allies, rivals, overlord and subjects.
Vassals and junior partners of personal unions are drawn in a shade of their
overlord's colour. Japan starts in January 1590: Hideyoshi's Toyotomi with
seven vassal clans, while the Kantō (the Late Hōjō) and Tōhoku are not yet his.

**Land deals.** From a country's panel, *Request to purchase land*, *Offer to
sell land* or *Exchange territory*: tap provinces on the map — theirs to ask for
(green), yours to give (red) — and set the money (buying, what you pay;
selling, what they pay you; in an exchange either way), or let *Even it out*
set it. Each province shows what it is worth (five years of what it produces).
They weigh a reluctance to part with land; what you offer against what they
give up (your land valued as it would be to them — more if it is their core):
offering less than the worth costs dearly, while paying over it tempts them less
and less with every ducat — the richer they are, the less — and never by more
than 30 points, so a province they value is not simply bought; and when they
are short of money, their want counts in full only for a sum worth half a year
of their taxes. Land that is hard for them to govern goes more easily — above
all an exclave they cannot reach from their capital over their own land (worse
without a coast to land on, and the further off), then unrest and its not being
their core — land that matters to them less so (cores,
rich provinces, the heartland near their capital, a large share of the realm);
land of yours they would get is weighed by how it fits their realm (beside
theirs, welcome; far across the sea, less so) and, buying, its price against
its worth to them; their finances when money changes hands; their opinion of
you, and rivals refuse. Every reason is shown before you offer. They never give up their
capital; a seller renounces its core on what it sells.

### Economy

Every province's people belong to an estate — **nobility, clergy, merchants,
commoners, tribesmen** — and every province produces a **good** (grain, wool,
wine, fish, timber, sugar, spices, silver, gold, kaolin …; real 1590 sites such
as Potosí silver, the Moluccan cloves or Jingdezhen's kaolin). Commoners and
tribesmen work it; development, the land, extraction buildings and calm (unrest
costs output) set how much. Prices are fixed for now; a market comes later.

Each estate earns a share of what its province produces — by its numbers and
its rank (a noble as much as 20 commoners) — and pays **tax at the rate you
set**: a slider per estate in 1 % steps (custom 20 %, at most 50 %; tribesmen
8 % / 25 %; the clergy are exempt). Above custom an estate's goodwill falls;
unhappy commoners and tribesmen stir unrest. Other policies: **court** spending
(legitimacy, the nobles' goodwill), **minting** (coin now, inflation that raises
every cost), **fort**, **army** and **navy maintenance** — each a percent slider
(court 50–250 %, minting 0–30 % of tax income, upkeep 0–150 %) whose effects scale
with it: forts' garrisons and walls, the spirit armies and fleets recover to. Gifts in
diplomacy are sized by a slider; the opinion they buy grows with their generosity.

**Rank.** Every realm is a **county**, **duchy**, **minor kingdom**, **major
kingdom** or **empire**. The more prestigious the title, the more its court is
expected to spend — a base and a share of its taxes (a county 0.25 + 4 %, an
empire 8 + 12 %), half for a tribal realm, a quarter for a colony's viceroy —
and the more it can govern and the more ties it keeps:

| Rank | Court a month | Governs in full (1590) | Ties | Envoys |
| --- | --- | --- | --- | --- |
| County | 0.25 + 4 % of taxes | 15 development | 2 | 1 |
| Duchy | 0.75 + 6 % | 50 | 3 | 1 |
| Minor kingdom | 2 + 8 % | 180 | 4 | 2 |
| Major kingdom | 4 + 10 % | 600 | 6 | 3 |
| Empire | 8 + 12 % | 2,000 | 9 | 4 |

Land beyond what a rank governs in full yields less tax (the square root of
the shortfall, at least 40 %): the Ming, with 3,380 development, collect about
three quarters of theirs. What a rank governs grows with the ages (×1.25 from
1650 up to ×2.5 from 1870). Alliances, royal marriages, subjects (not
colonies) and subsidies paid are **ties**: a realm with all its rank allows
takes on no more, and one beyond its limit has less loyal subjects. In 1590
the emperors are the Ming, the Mughals, the Ottomans, Spain, the Habsburgs and
the Safavids; other realms stand by their development, held down by their
titles (the German dukes and counts, the daimyo, the Irish lords). A realm
**rises** a rank once it has the development for it (duchy 12, minor kingdom
40, major kingdom 150, empire 500), legitimacy 50 and the money for the
coronation (100, 250, 600 or 1,500 ducats): in the country panel. AI realms
rise when their land outgrows their rank and they can afford the dearer
court; forming Manchuria makes a kingdom.

**Buildings** (one of each per province, paid up front, built over months):
extraction (farm estates, plantations, mines, lumber camps, fishing harbours),
income (marketplace, customs house), protection (fort), military (barracks:
they train soldiers), naval (dock: fleets berth there, ships are built and
sailors trained) and manufactories that
turn half the raw good into a made one (weavery: wool → cloth; kilns: kaolin →
porcelain; ironworks, tannery, joinery, distillery). Some stand in 1590.

**Discoveries**: hidden deposits turn up in their age — gold rushes, coal,
petroleum from the 1840s, rare earths and uranium later — and new crops arrive
(Virginia tobacco, Caribbean sugar, Assam tea).

**Loans and bankruptcy**: 100-ducat loans at a rate that rises with debt, up to
two years' income. A treasury that runs dry borrows; when no lender will, the
country goes bankrupt — debts repudiated, no credit for five years, dearer
credit for ten, legitimacy and stability lost. You can declare it yourself.

The top bar shows your treasury and monthly balance — tap it for the budget:
policies, next month line by line, last month's ledger (every ducat has a named
source) and the loans panel. A province's panel shows its people (what each
estate earns and pays), production, buildings and what you can build. The
**Economy** map shows output value; the **Goods** map what each province produces.

Map modes sit in four groups on the bottom bar — **Realm** (Political, Control,
Diplomacy), **Economy** (Economy, Goods), **Land** (Topography, Vegetation,
Climate) and **People** (Population); tap a group to slide its modes out. Modes
that describe provinces write it on the map: in Goods, Topography, Vegetation and
Climate each stretch of connected provinces sharing a value is named once, large,
across its whole extent ("OCEANIC", "GRAIN"); Economy and Population write each
province's output or population under its name.

### Armies and war

Realms of some size keep a small standing army at their capital in 1590, in their
own way of war — pike and shot in Europe, janissaries and sipahi for the Ottomans,
samurai in Japan, war elephants in India, horse archers on the steppe — and coastal
powers keep permanent navies (the Caspian and other lakes are navigable too). Forts
stand at the historical fortresses of 1590, the capitals of kingdoms and empires
and the great cities of larger realms — not every seat: most dukes and counts
had none — and show on the map from the region zoom in.

**Docks** (a coastal building) are where fleets berth: a fleet in port is safe
from battle, repaired and refilled, and costs half its upkeep; at sea it pays full
upkeep and is not repaired. Ships are built only at a dock. Each dock opens on one
sea, so it is never a canal. Seafaring realms start with docks at their home port
and great harbours, their navies berthed at home; a pier marks each dock on the
map. Tap one of your (or an ally's) docks with a fleet selected to sail it into
port; a fleet whose port falls to the enemy is driven out to sea.

**Over the sea:** every ship carries some soldiers and **transports** (merchant
transports and fluyts in 1590, East Indiamen, steam transports, troopships later)
carry the most; 1590 navies include a few. With an army selected, tap one of your
fleets in port where it stands or just offshore — or press *Board ship* — and it
goes aboard (the fleet panel shows what it carries, of how much room). Sail the
fleet, then tap a coast of the sea it is on to land the troops (three days);
selecting an army that is aboard shows its fleet, whose panel selects the troops.
Troops aboard a fleet that is sunk are lost with it.

Tap an army's banner to select it, then tap a province to march there (the toast
gives the days and, if enemies stand there, the odds); once ordered, it is
unselected. The **⬚** button turns on box selection: drag a box and your armies
inside it are *added* to the selection; the mode stays on for more boxes until you
give an order, which sends them off, clears the selection and ends the mode. A
selection is either armies or fleets, never both: a box over both takes the
armies, and a box of the other kind replaces the selection. **✕** below ⬚ clears
the selection. The army panel merges, splits, halts or disbands them. No army may
hold more than 100,000 men. Armies cross a sea zone where your fleet holds it (at
sea, or in a port on it); neutral land is closed in peace.

The top bar shows your **manpower** (⚔) and **sailors** (⚓); tap them for the
**Military tab**: your standing army, levies, ships, both pools, ideas, army and
navy maintenance, every army and fleet, and your wars. Declare war from a
country's panel (it shows who would join each side, and which disloyal vassals
would stay out); untick *Call our allies to arms* to fight without them.
Mobilisation is never automatic: call your **levies** from the Military tab — all
at once, or **region by region** (each region's men muster at its town); they
are missing from the fields while they serve, and those who die are lost to
their provinces. Regular regiments are raised and refilled from **manpower**,
ships crewed from **sailors**; levies use neither. Each pool has a ceiling (a
share of your people, of your coasts' for sailors) and fills only slowly by
itself: **barracks** train soldiers into it and **docks** sailors, each month,
and raise the ceilings too. Realms with a standing army in 1590 keep barracks
at their capital.

AI realms build barracks as they grow (one for a realm with a standing army,
one more for every 25 provinces), take up ideas when they can afford them
(seafaring ones press gangs first) and press men while at war and short of
them.

**Ideas** fill the pools in other ways: a realm holds one idea for each age it
has reached (one in 1590, more from 1650, 1720 and 1793) and takes one up for
half a year of its taxes. *Press gangs* (England, the Dutch, Spain, Portugal and
Venice hold it in 1590; others need a dock to take it up): an army standing in
one of your provinces — or a fleet in its dock — seizes a hundredth of its
common people for the army (or the navy), once a year a province, and its unrest
rises. *Drill grounds* make barracks train half as many again, *naval
academies* docks (from 1650), and *conscription* (from 1793) doubles the
people's share.

**Vassals** are called to their overlord's wars — unless disloyal (their opinion
of the overlord, less a share for being nearly as strong, below zero): they stay
out, but their land is open to the enemy, and the first enemy army to march in
brings them into the war.

Battles weigh numbers, unit quality, spirit, the ground and forts. The loser
**falls back** a distance that shrinks as military technology develops — up to
five provinces for the pike-and-shot armies of 1590 (which broke and fled far
before they rallied), four for the armies of the late 1700s, three in the age of
rifles, two for 20th-century divisions holding fronts (until technology arrives,
the age of the units it fields decides), one more for an army all on horseback —
to friendly ground if it can, else as far towards home as it gets; while falling
back it can be neither caught nor ordered. A beaten host is destroyed only when it has nowhere to go or the victors
outnumber what is left of it ten to one. Open land is occupied in days
(occupation changes control, never ownership) — but never a **capital**: one
without a fort still has its city walls and watch (600 men) and must be besieged
like a weaker fort. A **fort** holds a garrison (1,000 men; fewer if its upkeep
is neglected, half again at a capital) and needs at least as many besiegers;
every month they try their luck. The odds — shown on
the map, the army and the province (with every reason) — start small, grow with
each month the siege lasts, with numbers, and above all with **artillery**;
without siege equipment (guns, or the ladders and saps of a great host) a host
is down by up to 42 %. Or **storm it** (from the army or the province): far
better odds, but a tenth of the stormers fall if it is taken and a quarter if it
holds. Until 1800 a fort also **bars the roads** about it: an army in its zone —
the fort and its side's land beside it — may march into the fort or out of the
zone, but not on past it; take the fort or go round. Land you hold of the
enemy's can be **handed to an ally** in the war (its province panel). War score
comes from battles and occupation.

Each of your wars shows as a red badge centred under the top bar (⚔ and your
war score); tap it and the war opens as a pop-up in the middle of the screen,
pausing the game: your side on the left, theirs on the right, each belligerent
with an estimate of the men it has under arms (and each side's total), *Sue for
peace* beside each of theirs, and who stayed out. Close it and the game runs on. Provinces, armies and fleets open their
panels on the left of the screen; everything else on the right.

At war there is no other diplomacy with the enemy — no gifts, envoys, marriages
or alliances. **Sue for peace** with a country (in the war's panel or the
country's own): between the two sides' leaders the treaty ends the war; between a
leader and anyone else on the other side it is a separate peace that takes that
one out of the war — the leader can make it with any of the enemy, and anyone
else only with the enemy's leader. On the peace screen tap the map: their land to
demand (bright green), yours to give (bright red); paler, what each side holds of
the other's. Then money — reparations they pay (up to their treasury), or money
you pay them for peace (worth war score to them) — their forts to pull down,
their **vassalage**, their subjects set free or made yours, and alliances of
theirs to break. Each demand costs war score — land you do not hold double, your
**cores** half and your **claims** less — and what you give is worth some; the
screen shows the sums and whether they would sign: propose it, or surrender. AI
enemies offer treaties too, and AI allies of the enemy who have lost half their
land make their own peace. A five-year truce follows. Raise new regiments and
ships in your provinces: only your era's and region's units are offered — tanks
and aircraft wait for their century.

**Civil wars.** A war between two countries of one culture where one holds a
core on the other's capital (the crown against rebels claiming it) is a civil
war. Land taken in it is annexed outright, not occupied, and that is what its
war score counts: the land each side has annexed from the other, battles, and
time — the crown gains each month while the rebels hold under a quarter of the
realm, the rebels while they hold over half. The peace takes no land: the
rebels have **demands**, each worth points (an amnesty, pensions, their
privileges confirmed, keeping their lands as vassals, a ruler of their faith,
the crown for their claimant). Grant enough of them and they lay down arms,
their land returning to the crown; the better you fare, the less they ask (and
clearly beaten, they submit for nothing). Playing the rebels, you press your
demands instead.

**Volunteers.** An army can be sent to fight in another country's war without
your country joining it (*Send as volunteers* in the army panel): it marches,
fights and besieges for that country, what it takes is that country's, and you
pay its upkeep. It comes home when that war ends or when recalled. **Subsidies**:
pay a country a monthly sum from its panel; it thinks the better of you, and the
payments stop when your money runs out or you go to war with it.

**Cores and claims:** every owner has a core on its land once it has held it 25
years, and keeps its cores on land it loses; claims are lesser rights. 1590 has
its own: England's Calais, Spain's rebel Low Countries, Austria's Ottoman Hungary,
Persia's lands lost in 1590, Russia's Narva, Japan's ambitions in Korea and more.
The diplomacy map stripes the cores (and, thinner, the claims) a country has on
others' land; the province panel names them. AI countries go to war over them.

### Colonisation

Uncolonised land is settled through a country's **colonial policy** (set in the
budget): *Settle the frontier* (two colonies at once, on land next to yours or
across a strait), *Overseas ventures* (two, any coast) or *Colonial empire*
(four). In 1590 Spain and Portugal run colonial empires, England, France and the
Netherlands overseas ventures, and Russia settles its frontier; other countries
take up frontier settlement now and then when free land borders them.

Tap a free province to see how fast your settlers would take it, with every
factor named — the frontier is easiest, overseas harder the more seas lie between
it and your home ports; open land is quicker than forest, jungle, desert or
mountains; a climate like home helps (Russians in Siberia, whose Cossack frontier
also speeds them on land joined to their own); many natives slow the settlers and
sometimes rise against them, though neighbouring peoples (in your own part of the
world) are absorbed far more easily than foreigners overseas; and in tropical Africa and New
Guinea disease keeps settlers from cooler lands to the coasts, slowly, until
quinine (c. 1850) and railways (c. 1880) open the interior — peoples at home in
the tropics are not held back. Inland provinces can only be settled from your
own land beside them. A colony costs a founding fee and monthly upkeep; when it
stands, settlers arrive and the natives stay. The **Colonisation** map (Realm
group) shows free land from quick to slow, what disease closes, and colonies
under way.

### Overseas and colonial nations

The world beyond Europe and the Middle East is drawn up into **colonial
regions** — New Spain, Peru, New Granada, La Plata, Brazil, the Caribbean,
Florida, Eastern America, Louisiana, Canada, the Maghreb, West Africa, the
Congo, East and Southern Africa, India, the East Indies, the Philippines,
Australia and more (the *Colonial regions* map, under Realm, names them). A
province is **overseas** for its owner when it lies in a colonial region, in
another world region than the capital, with no route to the capital over the
owner's own land: Spain's Mexico is overseas, Russia's Siberia is not. Overseas
land is not governed as the realm's own — it raises no levies — and once a
country holds three overseas provinces in one colonial region they become a
**colonial nation**: a new country in a shade of its mother's colour, the
mother's *colony*, following it to war and sending it up to a quarter of its
taxes, though never more than half of what it has left over, so it keeps money
for its own affairs. Land settled there later joins it. A colony has a
viceroy's household (a quarter of a royal court's cost), founding money, light
garrisons, and administration that costs little where land is thinly settled.
The mother pays half its forts' upkeep and, like the situado Mexico sent to the
Caribbean, Florida and Manila, whatever it needs to stay solvent; in return
the crown takes a fifth of the gold and silver mined in its lands. 1590 opens with Spain's Viceroyalties of New
Spain and Peru, the New Kingdom of Granada, the Río de la Plata, the Audiencia
of Santo Domingo and the Philippines, and Portugal's State of Brazil, Estado da
Índia and Mozambique; smaller outposts (Melaka, Macau, Luanda…) stay the
mother's own, overseas.

### Music

The soundtrack follows the date: `music/<n Age>/<Region>/` with ages 1590–1690,
1690–1750, 1750–1830, 1830–1900 and 1900–1949. Near the turn of an age the next
age's tracks creep in; loading a save or starting a campaign crossfades at once.
An age without tracks yet plays the nearest earlier one's, and a region without
its own folder plays what there is. Music can be switched off in the menus.

### Faith

Every province holds one faith — Catholic, Lutheran, Reformed, Anglican,
Orthodox, Oriental Orthodox, Sunni, Shia, Ibadi, Hindu, Theravada or Tibetan
Buddhist, Confucian, Shinto, Animist — as it stood in 1590, and every country a
**state religion** (shown in its panel). Land of another faith than its
ruler's is restless: more unrest (and so less output) — more across families
of faith (a Muslim province under a Christian ruler) than for a heresy
(Huguenots under a Catholic king). Send a **missionary** from the province
panel to convert one of your own (held, not occupied) provinces: it costs
ducats to send and a ducat a month while it works, and takes years — longer
in richer land and across families, sooner among animists. A realm keeps one
missionary at work in 1590, more in later ages. AI realms send theirs too.
The **Religion** map mode (People) shows every faith; **Buildings**
(Economy) shows how built-up each province is and names its buildings.

### Land: topography, vegetation, climate

Every province (and wasteland) has EU5-style land, the basis for colonisation:
**topography** (flatland, hills, plateau, mountains, wetlands) from real
elevation and ruggedness, **climate** (equatorial, tropical, subtropical,
Mediterranean, oceanic, continental, subarctic, arctic, hot arid, cold arid)
from the Köppen-Geiger map, and **vegetation** (desert, sparse, grasslands,
farmland, woods, forest, jungle) from the climate's natural cover, named
landscapes, and farmland where people were dense in 1590. Each has a map mode.

## Credits

* Map data: [Natural Earth](https://www.naturalearthdata.com) (public domain).
* Climate: Kottek, M., J. Grieser, C. Beck, B. Rudolf and F. Rubel, 2006: World
  Map of the Köppen-Geiger climate classification updated. *Meteorol. Z.*, 15,
  259-263. doi:10.1127/0941-2948/2006/0130.
* Elevation: ETOPO1 Global Relief Model, NOAA National Geophysical Data Center
  (public domain).
* Title painting: Ernest Crofts (1847–1911), *Charles I on his way to
  execution* (public domain).
* Flags: from [Wikimedia Commons](https://commons.wikimedia.org); each file's
  author, source and licence are listed in `assets/flags/CREDITS.md`.

## Debug screenshots

```bash
godot --path . -- --screenshot=shot.png --at=48.86,2.35 --zoom=3 --mode=terrain
```

Starts the game, applies the options, saves a screenshot and quits. Any debug
option skips the title menu; others: `--country=FRA` (country panel), `--play=TUR`,
`--occupy=5,3546` (hand provinces to the player), `--besiege=lat,lon` (our first army set down there), `--load=<slot>`,
`--menu[=choose|pause|saves]` (show a menu page), `--timing` (how long each
stage of loading takes).

## Performance probe

```bash
godot --path . --script res://tools/profile_zoom.gd
```

Holds still at several zoom levels, then zooms and pans continuously over
Europe, printing frame time, view-update script time, draw calls and
primitives. Detail is view-dependent: rivers, forests and peaks exist only for
512-px map tiles on or near the screen (built a few per frame, nearest first),
and province names are drawn in one 2D pass for what is visible.

## Layout

```
src/core/      GameClock (calendar), GameRandom (seeded campaign randomness),
               SaveService (versioned atomic saves)
src/domain/    Province, Country, WorldState (authoritative state), WorldLoader,
               Campaign (world + clock + random: what a save holds)
src/simulation/ SimulationScheduler — runs systems on game-time cadences
src/map/       MapView + map.gdshader (2D ID-raster map, smooth borders),
               MapCamera (wrap-around), MapOverlay3D (transparent 3D layer),
               MapRivers (vector rivers), MapLod (detail levels), MapModes
src/ui/        HUD, MenuScreen, DrawerPanel → ProvincePanel / CountryPanel, UITheme
src/game.gd    Composition root (game.tscn)
data/          Static world data and scenarios
tools/         World generator (world1590/) and source-data fetch script
tests/         Headless test runner and tests
```

Rules for contributors (from `structure.md` §18): simulation logic never lives in
UI or rendering code, painting is read-only, relationships use stable IDs, and
time only advances through the clock.

## Android

An Android export preset exists (`export_presets.cfg`). It includes `data/*.json`
(the `.res` map images export automatically) and excludes `tools/`, `tests/`. Build from *Project → Export* once the Android
SDK and a debug keystore are configured in *Editor Settings → Export → Android*.
Never commit keystores or passwords.
