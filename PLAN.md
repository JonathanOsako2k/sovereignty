# Sovereignty — Implementation Plan

This plan turns `structure.md` (the design brief for *The Long Century*) into
concrete build steps for **this** repository.

## Engine decision

`structure.md` recommends Flutter, but explicitly allows "a game engine" when map
rendering is the limiting factor. This repository is a **Godot 4.7** project using
the **Mobile** renderer, so the brief's architecture is mapped onto Godot:

| Brief (Flutter)                | This project (Godot)                                         |
| ------------------------------ | ------------------------------------------------------------ |
| Plain-Dart domain/simulation   | `RefCounted` GDScript classes in `src/core`, `src/domain`, `src/simulation` — no nodes, testable headless |
| Custom canvas map painter      | `src/map/` — 2D province-ID raster + shader, plus a transparent 3D overlay |
| Widgets                        | `Control` nodes in `src/ui/` (built in code, touch-sized theme) |
| Dart unit tests                | `tests/` headless runner (`godot --headless --script res://tests/run_tests.gd`) |
| Isolates                       | `WorkerThreadPool` — only if profiling shows the main thread is blocked |

## Map rendering: 2D map with a transparent 3D layer

```
 ┌───────────────────────────────────────────────┐  CanvasLayer 2  HUD (Controls)
 │ ┌───────────────────────────────────────────┐ │  CanvasLayer 1  SubViewportContainer
 │ │  SubViewport (transparent_bg, own World3D)│ │     └ Camera3D: orthographic, straight down,
 │ │  capitals · labels · trees · peaks ·      │ │        position/size synced to the Camera2D
 │ │  selection pin · shadow catcher           │ │
 │ └───────────────────────────────────────────┘ │
 │  World 2D: Sprite2D + map.gdshader            │  Camera2D: pan / pinch / wheel zoom
 │  (province-ID texture → palette lookup,       │
 │   borders, relief shading, selection)         │
 └───────────────────────────────────────────────┘
```

* **2D base (authoritative for hit-testing and colour).** One texture encodes a
  province ID per pixel (`R + G·256`, `0` = sea). A 256×256 *palette* texture
  holds a colour per province ID; the shader looks it up and draws province,
  country and coast borders by comparing neighbouring IDs. Changing a map mode
  or an owner rewrites only the palette (one small texture upload). A tap is a
  single `Image.get_pixel` lookup — no polygon testing.
* **Transparent 3D layer (decoration and markers only).** A `SubViewport` with a
  transparent background renders 3D objects over the map. Its orthographic camera
  looks straight down and is driven from the 2D camera every time the view changes
  (`1 map pixel = 0.01 world units`, `camera.size = viewport_height / zoom`), so a
  3D object placed at map pixel *(x, y)* always sits exactly over that pixel. A
  plane with `shadow_to_opacity` catches the shadows of 3D objects so they fall
  onto the 2D map.
* **Neither layer owns game state.** Both read `WorldState` and redraw when told
  that something changed; painting never mutates the world.

## Milestones

Each milestone ends with its acceptance checks passing (headless tests + a
manual run). Do not start the next milestone with a failing one.

### M0 — Project foundation ✅
1. Godot project settings: main scene, 720×720 base canvas with `expand` stretch
   (same UI scale in portrait and landscape on a 22:9 foldable), landscape-only on
   phones (sensor landscape, at the user's request; the portrait layout remains for
   narrow desktop windows),
   1280×720 desktop window.
2. `GameClock` (pure logic): 1 Jan 1590 → 31 Dec 1949, Gregorian months, pause,
   5 speeds, bounded ticks per frame, day/month/year signals.
3. App shell: top bar (country, date, pause, speed), pauses when the app is
   backgrounded or loses focus.
4. Headless test runner + clock tests.
5. `git init`, README with run/test commands.

**Accept:** launches offline; date advances only while unpaused; tests pass.

### M1 — Political map ✅ (now the real world of 1590)
1. `tools/generate_map.gd`: deterministic (seed 1590) generator for a ~90-province
   test continent → `data/map/province_ids.png`, `data/map/heightmap.png`,
   `data/world/provinces.json` (IDs, names, terrain, adjacency, label points),
   `data/world/countries.json`, `data/scenarios/1590.json` (starting owners).
2. `WorldLoader` + `WorldState` with validation (unique IDs, symmetric
   adjacency, every reference resolves) and a single `transfer_province()`.
3. `MapView` (2D shader map), `MapCamera` (drag, pinch, wheel, trackpad, zoom
   buttons, clamped to the map), `MapOverlay3D` (synced transparent 3D layer:
   capitals, country/province labels by zoom level, forest and mountain props,
   selection pin, shadows).
4. Map modes: Political, Control, Terrain, Population.
5. Province panel: side panel in landscape, bottom sheet in portrait.

**Accept:** tapping selects the correct ID; selection and 3D objects stay aligned
while panning/zooming; painting is read-only; no node per province for picking;
tests for world loading, adjacency and ownership transfer pass.

**M1.5 — Real world of 1 January 1590 ✅** (replaced the fictional test map)
* Natural Earth geography, Mercator 6144×2961, wraps east-west.
* 5000 ownable provinces on real first-level divisions, exact regional quotas;
  82 impassable wastelands on top; Nile/Sahara/Silk Road corridors; every
  province reachable (tested).
* 217 polities from authored 1590 rules (`tools/world1590/polities_1590.gd`),
  ~1180 uncolonised provinces; 37 historical spot-check tests.
* Rendering: smooth anti-aliased borders when zoomed in, vector rivers, MSDF
  serif labels with collision culling, 3D layer at physical resolution, LOD
  levels with hysteresis (`MapLod`).
* Open: ~9% of provinces in large divisions still have compass/numbered names
  (Natural Earth lacks small towns) — add a town gazetteer (e.g. GeoNames, CC-BY).
* Sea tiles (~590, incl. ~20 on lakes) with names and sea/coast adjacency for
  naval movement; map extended to 76°N–62°S; 1590 Aral Sea and Zuiderzee;
  settled-division ownership fallback (fixed e.g. eastern Shandong showing as
  uncolonised) and four more Indian kingdoms; wastelands follow geography only.
* Open: country-select screen (player is England for now).
* View-dependent detail (`tools/profile_zoom.gd`, desktop RTX 4060 Ti): continuous
  zoom went from 60 ms/frame (160 ms worst) to ~3.8 ms (~11 ms worst); panning at
  zoom 3 ~4.8 ms. Rivers and scenery are tiled and streamed around the view;
  province names are one 2D draw pass. Still to measure on the Flip6.
**Still to do by hand:** run on the physical Z Flip6 (needs Android export setup — see M2 step 6).

### M2 — Countries, ownership and save/load ✅
1. Country panel: tap a country's name on the map, the owner/controller links in the
   province panel, or the player's name in the top bar. The selected country is
   tinted and outlined on the map (`selected_country` shader uniform).
2. Ownership/control separation in the UI: occupied provinces are striped — the
   occupier's colour over the owner's in Political mode, the owner's over the
   occupier's in Control mode (second 256×256 `stripes` palette); Control mode draws
   country borders by controller.
3. `SaveService` (`src/core/save_service.gd`): `<slot>.srt` files (JSON inside) with
   `format`, `schema_version`, `world_version`, `world_fingerprint`, `saved_at`, title;
   atomic write (`.tmp.srt` → read back and checked → previous save kept as `.bak.srt`
   → rename); explicit migration hook. On Android saves go to `Documents/Sovereignty`
   so the player can reach them (fallbacks: app folder on shared storage, then
   private storage); desktop uses `user://saves/`.
   `Campaign` (`src/domain/campaign.gd`) bundles world + clock + random stream;
   `WorldState.restore_campaign_state()` is all-or-nothing with readable diagnostics.
4. Menus (`MenuScreen`): title (Continue / New campaign / Load), in-game menu
   (☰, Esc, Android back: Resume / Save / Load / Main menu), saved-games list with
   timestamps, damaged saves flagged with a "Load backup" option, confirmations for
   loading over a running game, deleting and leaving.
5. `GameRandom` (`src/core/game_random.gd`): seeded, 64-bit state saved as strings.
6. Country selection: New campaign → "Choose your country" → tap it on the map →
   "Play as …".
7. Android: `quit_on_go_back=false` (back button opens the menu instead of killing the
   app); export preset includes `data/*.json`.

**Accept (met, `tests/test_save.gd`, `tests/test_game_flow.gd`):** save → load gives an
identical serialised state; damaged, foreign, newer-format and other-world-version saves
are refused with diagnostics and leave the campaign untouched; unknown ids are named;
save carries versions.

### M3 — Calendar, scheduler and autosave ✅
1. `SimulationScheduler` (`src/simulation/`): systems register a cadence (daily, weekly
   counted from 1 Jan 1590, monthly, quarterly, yearly) and run in registration order on
   clock ticks; `Game` advances time only through `scheduler.process_frame()`.
2. Budgeted work: heavy systems register as jobs that run in slices within a 4 ms
   frame budget; the clock holds until the day's work is done, so results do not
   depend on frame rate. Headless `step_day()` runs everything to completion.
3. Autosave (slot `autosave`, with its own backup) every 1 January after the day's
   work, when Android backgrounds the app, and on window close. Saves always finish
   pending work first.

**Accept (met, `tests/test_scheduler.gd`):** speeds produce expected tick counts;
pausing stops everything; loading starts paused; slow work is sliced across frames.
No systems are registered yet — the economy (M4) is the first.

### M4 — Diplomacy (no war yet) ✅
Done before the economy at the user's request; war declaration waits for armies (M6).
1. `Diplomacy` (`src/domain/diplomacy.gd`): subjects (vassal, personal union, tributary),
   alliances, royal marriages, declared rivalries (max 3), envoys (2 per country), and
   opinion — always a sum of named reasons (allies, marriage, rivals, common rival,
   overlord/subject, and fading effects: gifts, insults, improved relations, broken
   alliances or marriages, release). Saved (save format 2, with an explicit upgrade from 1).
2. `DiplomacyActions` (`src/simulation/`): one rulebook for player and AI — improve
   relations, send gift (costs ducats, yearly), send insult (yearly), declare/remove
   rival (worthy and near enough), propose/break alliance, propose/break royal marriage
   (monarchies only), demand vassalage (weaker neighbour), release subject. Proposals are
   judged by the other side as a visible list of reasons; subjects leave foreign affairs
   to their overlord.
3. `DiplomacySystem`: monthly through the scheduler — fading, envoys, and a simple,
   reproducible AI (rivals, alliances, marriages, envoys, insults, gifts; never proposes
   to the player yet, never demands vassalage).
4. 1590 start (`polities_1590.gd` SUBJECTS / ALLIANCES / ROYAL_MARRIAGES / RIVALRIES):
   the Iberian Union (Portugal its own country in personal union with Spain), Ottoman,
   Polish, Ming, Burmese, Safavid and Toyotomi subjects, Nonsuch etc. Japan in January
   1590: Toyotomi centre and west with five vassal clans; the Hōjō, Satake, Satomi and the
   Tōhoku clans not yet under Hideyoshi.
5. UI: country panel relations (opinion with reasons, ties) and actions with previews and
   confirmations; Diplomacy map mode (relations to the player); notices when others act.

**Next for diplomacy:** answering AI proposals (an inbox), guarantees, war declaration
and war aims (with M7), succession that forms personal unions (M8).

### M5 — Economy ✅
First pass (v1): monthly province tax, budget lines, ledger, loans, tribute,
occupation; top-bar treasury, budget panel, Economy map. Extended (v2, at the
user's request) into people, goods and policies:

1. **People by estate** (`Estates`): nobility, clergy, merchants, commoners,
   tribesmen, divided at the start from development, government, coast, capital
   and nomadic land (uncolonised and tribal lands are mostly tribesmen).
2. **Goods** (`Goods`): every land province produces one raw good (farm, cash crop,
   gathered or mined) at a fixed price for now — real 1590 sites from
   `tools/world1590/resources_1590.gd` (Potosí silver, Moluccan cloves, Jingdezhen
   kaolin …), land and climate elsewhere. Commoners and tribesmen work it: output =
   workers × yield × development × land × extraction buildings × calm (unrest).
3. **Discoveries**: hidden deposits found in their age by a yearly roll — gold rushes
   (Sado 1601 … Klondike 1896), coal fields, petroleum (Baku 1846 …), rare earths,
   uranium, new crops (Virginia tobacco, Caribbean sugar, Assam tea …), and a few
   hidden gold veins in hills and mountains open from 1590.
4. **Buildings** (`Buildings`), one of each, paid up front and built over months:
   extraction (farm estates, plantation, mine, lumber camp, fishing harbour),
   income (marketplace, customs house), protection (fort, upkeep), manufacture
   (weavery, ironworks, porcelain kilns, tannery, joinery, distillery: half the
   raw output becomes a made good). 52 historical buildings stand in 1590.
5. **Estate incomes and taxes**: each estate draws a share of the output by head
   count and rank (a noble as much as 20 commoners, a cleric 8, a merchant 6, a
   tribesman 0.7); taxes are proportional — a percentage of each estate's income
   set by the government (custom 20 %, tribesmen 8 %; at most 50 %, tribesmen
   25 %; the clergy are exempt), collected as far as reach and the estate's
   goodwill allow. Goodwill drifts towards a target (−2.5 per point above custom;
   the court moves the nobles, inflation the merchants); low workers' goodwill
   raises unrest, which costs output.
6. **Policies**: tax rate per estate (slider in 1 % steps with − / +), court
   (legitimacy, nobles), minting (income now, inflation that raises every cost),
   fort maintenance. No military spending until armies exist (M6).
7. **Loans and bankruptcy**: 100-ducat loans at a rate that rises with debt (5 % +
   4 % per year of income owed, capped at 25 %), up to two years' income; a
   treasury that runs dry borrows, and when no lender will, the country goes
   bankrupt (debts repudiated, no credit for 5 years, dearer for 10, legitimacy,
   stability and estates suffer). The player can declare bankruptcy too.
8. UI: budget panel with estate tax lines and policies; loans panel; province panel
   with people, production, buildings and Build actions; Economy (output value) and
   Goods map modes. Save format 5 (from 3: debt becomes one loan at 8 %; from 4:
   tax levels become percentages).

**Accept (met, `tests/test_economy.gd`):** every money change has a named source;
surplus and deficit both occur; estates add up to the population; production is the
product of named factors; buildings, manufactories, policies, inflation, loans,
bankruptcy, discoveries, tribute, occupation and saving tested.

**Later (with trade, M9):** a market sets prices from supply and pop demand
(Victoria-style); goods flow along trade routes.

### M6 — Colonisation ✅
At the user's request (16 Oct 2026): frontiers easier to settle; some lands harder for
some peoples (an African kingdom expands into its neighbourhood gradually once it has
the idea; Russia fills Siberia readily); and no European conquest of Africa's interior
before the 19th century (quinine, steamboats, railways).
1. `Colonisation` (rules, `src/domain/colonisation.gd`) and `ColonisationSystem`
   (`src/simulation/colonisation_system.gd`, monthly and yearly through the scheduler).
2. **Colonial policy** per country — the "idea": None / Settle the frontier (2 colonies,
   land and straits) / Overseas ventures (2, any coast) / Colonial empire (4). 1590:
   Spain and Portugal empire, England, France, the Netherlands overseas, Russia frontier.
   AI countries with free land beside them take up frontier settlement now and then.
3. **A colony** in an uncolonised province advances monthly by named factors: access
   (frontier ×1.5, a strait ×1.1, overseas ×0.7 falling with the seas crossed from the
   home ports), the land (vegetation × topography; arctic ×0.4), climate familiarity
   (against the climates near the capital), natives (half speed at 25,000 people; they
   rise now and then and undo progress; neighbouring peoples — land in the settler's own
   part of the world — count half as many and rise half as often), Russia's
   Cossack frontier (×1.6 on land joined to its own, at the user's request) and disease (tropical Africa and New Guinea, for
   peoples not at home in the tropics: coasts only and slowly before 1850, the interior
   opens partly from 1850 and mostly from 1880 — the year stands in until technology).
   Inland provinces are only reached from our land beside them, so colonies creep inland.
4. Founding costs ducats (more across more seas); colonies and the colonial office cost
   upkeep (budget line "Colonial upkeep"). A finished colony passes through
   `WorldState.transfer_province()`; settlers arrive and the natives stay as tribesmen.
5. UI: province panel (who is settling, progress, our pace with every factor, Found a
   colony / Abandon), colonial policy slider in the budget, Colonisation map mode (free
   land from quick to slow for the perspective country, closed by disease, colonies
   striped; years written on the map). Save format 6.

**Accept (met, `tests/test_colonisation.gd`):** frontier, overseas and disease rules;
an African kingdom completes a colony once it adopts a policy; costs and upkeep in the
ledger; uprisings; saving and the format 5 upgrade; 20 years of AI settle land without a
European in tropical Africa's interior.

### M7 — Armies and war ✅
User's brief (19 Oct 2026): forts shown on the map; realms of some size keep a small
army in 1590 and call levies in war; drag-select several armies and merge them; navies
permanent; the Caspian navigable; a wide range of units including future ones (tanks,
aircraft) hidden until their era and shown by region; a 100k stack limit for the
fronts of later wars.
1. `UnitTypes` (~50 kinds: 1590 regional troops — pike and shot, janissaries,
   samurai, war elephants, horse archers, Cossacks, turtle ships… — to divisions,
   armour, aircraft and carriers), each with years and the regions or countries that
   field them. `Army` (regiments of one country; levies remember their province),
   `Military` (world.military: armies, wars, truces, sieges, recruiting) — saved
   (format 7).
2. 1590 forces (`Military.populate`): standing armies of 0.12 % of the people (realms of
   4+ provinces, at most 60k) in the realm's own units at the capital; permanent navies
   for countries with 4+ provinces on the open sea, berthed at a dock in their home
   port (docks too at coastal cities of development 9+); forts at capitals and great
   cities. **Docks** (coastal building): fleets berth there (safe, repaired, half
   upkeep; at sea no repairs), ships are built only there, each opens on one sea (no
   canals), a fleet whose port falls is driven to sea; piers on the map.
3. `MilitarySystem`: marching by A* (days from distance, pace, ground; neutral land
   closed; a sea zone crossed where our fleet holds it), fleets over every water incl.
   the Caspian; battles (power, ground, forts, luck; the loser retreats or is destroyed)
   with a pre-battle estimate; sieges (forts 90 days at full upkeep, capitals ×1.5,
   artillery helps) and occupation of open land in 10 days — control only; attrition
   beyond supply; reinforcement and spirit at home; levies (0.4 % of commoners and
   tribesmen, mustered ~350 km apart, missing from the fields, their dead lost to the
   people; called only by order, never automatically); manpower for regular regiments
   (0.3 % of the people, refilling over ten years; levies don't use it); recruitment
   in provinces; merge, split, disband, the 100k limit.
4. War: declaration (defender's overlord leads; subjects, defensive allies and willing
   allies join), war score (occupation + battles); no other diplomacy with an enemy;
   peace by **treaty** — each province the side holds, reparations up to the loser's
   treasury, forts pulled down, each term costing war score (land what holding it earns,
   money by the payer's year of taxes, forts 4 each) — or surrender; then 5-year
   truces; levies go home. AI: mobilises itself (never the player), campaigns planned
   daily for a seventh of its armies, on the nearest enemy land avoiding stronger hosts,
   merging, treaties when winning (land, then reparations from spare score), crushed or
   stalemated, offers to the player; yearly wars on weaker neighbouring rivals.
5. Map and UI: banners and ships in the owner's colour, men under each, rings and dashed
   routes for the selected, siege progress, fort walls (`MapForces`); tap an army, tap a
   destination (days and odds); a ⬚ button for box selection (a box adds to the
   selection, the mode staying on until an order, which clears it; armies or fleets, never both — armies first; ✕
   clears); army panel (merge, split,
   halt, disband); the **Military tab** (⚔: standing army, levies, ships, manpower,
   mobilisation, army and navy maintenance, every army and fleet, wars); the enemy's
   panel at war (the war first, diplomacy closed, "Negotiate peace"); the **peace
   treaty screen** (land toggles, reparations slider, fort toggles, cost against our
   score, their answer; Propose or Surrender); forces, sieges and Raise in the
   province panel.

**Accept (met, `tests/test_military.gd`):** units by era and region; the forces of 1590;
no movement over non-edges or into neutral land; the Caspian sailable; occupation ≠
ownership; battles with losses; forts hold out longer; levies leave and return to the
fields; merge/split and the stack limit; manpower limits regiments; recruitment;
upkeep by maintenance; treaties cost war score by land, money and forts, pay
reparations and pull forts down; no diplomacy with an enemy; the AI offers the player
a treaty; docks berth fleets (half upkeep, repairs only in port, ships built only there,
no canals, a lost port drives the fleet out) and old saves get them; box selection adds
up until an order ends the mode, keeps armies and fleets apart (armies first), ✕ clears it
(`test_game_flow.gd`); saving and the format 6 upgrade; an AI war
ends within ten years.

**Added (20 Oct 2026, the user's war batch):** peace treaties as a map tool (their
land to demand green, ours to give red), terms for vassalage, freeing or taking their
subjects and breaking their alliances; separate peace (leader with leader ends the war;
a leader with anyone else on the other side takes that one out); suing for peace from a
country's panel or the war's; AI allies of the enemy make separate peace when half their
land is lost; each of our wars as an icon under the top bar, its panel listing the
belligerents with estimated forces; cores and claims (`Claims`: owners' cores after 25
years, the rights of 1590, cheaper to take, AI wars over them, stripes on the diplomacy
map); ship capacity and transports (board in port or offshore, land on a coast, lost
with a sunk fleet); vassals called to war unless disloyal (opinion less a share for
size), the disloyal staying out until their land is attacked; retreats instead of
stackwipes (a fall-back that shrinks as technology develops — by the age of its units
until technology exists (M9): 5 provinces to 1750, 4 to 1830, 3 to 1900, 2 after; +1
all mounted; wiped only when cut off or outnumbered ten to one; no battles or orders while
falling back);
mobilisation by region; a daily budget for the AI's route searches. Save format 8.
Tests in `test_military.gd`, `test_claims.gd`, `test_game_flow.gd`.

**Added (20 Oct 2026): overseas and colonial nations.** Colonial regions
(`Overseas.REGIONS`, 26 boxes by world region; a *Colonial regions* map mode labels them);
overseas = in a colonial region, another world region than the capital, no route home
over one's own land (no levies there); three overseas provinces in a region found a
colonial nation (a new country, the "colony" subject type: tribute 25 %, follows its
mother to war; later land there joins it); the 1590 start has Spain's six and
Portugal's three. Countries can now be founded during a campaign (`WorldState.created`,
saved; the map's country index wraps past 253). Tests in `test_overseas.gd`.

**Added (20 Oct 2026): land deals** (`LandDeals`, `LandDealPanel`): buying land,
selling land, and exchanging territory with money either way, judged as a sum of named reasons — worth
(10 years of yield), land hard to govern, land that matters, finances, opinion,
rivalry; map picking like the peace table. Tests in `test_land_deals.gd`.

**Added (21 Oct 2026): war rules.** Before 1800 a fort bars the roads about it
(`fort_zones`: an army in its zone may enter the fort or leave the zone, not march
on past it); sieges are monthly tries whose odds grow with time, numbers and
artillery and fall without siege equipment (to −42 %), or a costly storm; occupied
land handed to an ally; war without calling allies; manpower and sailors pools with
barracks and docks training them (top bar); ideas (one per age) with press gangs;
money paid for peace; land purchases priced with a capped, diminishing premium and
exclaves cheaper to their owner. Tests in `test_war_rules.gd`.

**Added (21 Oct 2026): faith and the 1590 scenario.** Every province's faith and
every realm's state religion as in 1590 (generator: `religions_1590.gd`); unrest in
land of another faith; missionaries (a slot per age, cost and upkeep, years to
convert); the AI sends its own, takes up ideas and builds barracks; ~240 historical
fortresses; Religion and Buildings map modes; a loading screen; loading ~40 % faster
(glyph cache, one recolour per restore, trusted new-campaign start). Tests in
`test_religion.gd`.

**Added (22 Oct 2026): capitals besieged.** A capital without a fort must be
besieged (its city walls), never simply occupied; only kingdoms and empires
start with a fortified capital (lesser seats where history fortified them).

**Added (22 Oct 2026): ranks.** County, duchy, minor kingdom, major kingdom,
empire: the court each is expected to keep (base + share of taxes; tribal half,
colonial a quarter), the development each governs in full (taxes fall beyond;
more with the ages), the ties (alliances, marriages, subjects, subsidies) and
envoys each keeps; rising a rank by coronation (player and AI). Tests in
`test_ranks.gd`.

**Added (21 Oct 2026): a real 1590.** The French Wars of Religion (Henry IV against
the Catholic League, a civil war: land taken is annexed, war score from annexation,
battles and a monthly tick, peace by granting the rebels' demands), Spanish
volunteers and subsidies for the League, the Dutch revolt with its cores and
claims, the Jurchens' rivalry and the forming of Manchuria (integrating Wild
Jurchen land by army and fee); cultures and a Culture map mode; volunteers and
subsidies for anyone; flags and a title card. Tests in `test_1590.gd`.

**Next for war:** AI use of transports and navies at sea, AI volunteers and
subsidies, rebellions arising during play (unrest, pretenders), air power (aircraft are
catalogued), war aims beyond land (and for the AI: vassalage, freeing subjects), fronts
for 20th-century war, cores decaying over the centuries.

### M8 — 1590-era politics
Dynastic succession & legitimacy, estates/privileges constraining policy,
centralisation decisions, data-driven conditional events.

Historical situations to consider:
1. Dutch independence war, the united provinces will be at war with Spain since the start. Spain just lost to the British in the battle of Trafalgar. So Spain have little to no transport ship. This gives the Dutch a significant advantage to win the war early game. Also the Portuguese are disloyal so they will not help Spain to defeat the Dutch.
2. Japan near its end of unification and the begining of the Imjin war
3. Russian Rapid colonisation of Siberia
4. Ottoman Habsburg war
5. Unification of the Jurchens, a mechanism to allow Manchu to quickly rise and give the ming internal problems and crisis which have to be dealt with by them. Create a unique mechanism that they can instantly annex the uncolonised manchu province by paying a fee and sending troops there. Symbolising them reaching out to the wild jurchens and integrating them. So they do become cores.
6. Iberian Union and how Spain can handle it
### M9 — Era transitions
Technology/institution progression, era-specific armies and economies,
revolution & reform, industrialisation, total-war logistics.

### M10 — Scale, performance, balance
Scale gates B–D from the brief (300–500, 1–2k provinces, full map), late-game
stress save, profiling on device, regression seeds, compatibility pass.

## Known risks / decisions to revisit
* **Shader cost:** the map shader does 4–13 texel fetches per pixel. Measure on the
  Flip6; if needed, precompute a border mask texture when ownership changes.
* **Memory:** the 6144×2961 RG8 province map is ~36 MB on the GPU plus a CPU copy
  for picking. Fine on the Flip6; revisit for low-end devices.
* **3D layer resolution:** the SubViewport renders at canvas resolution; on very
  high-DPI screens raise its size scale if 3D objects look soft.
