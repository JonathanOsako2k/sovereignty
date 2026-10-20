# Handover — Sovereignty (state as of 16 Oct 2026)

Read this first, then `PLAN.md` (milestones) and `structure.md` (the user's
design brief — the source of truth for *what* to build). `README.md` has the
short user-facing version of the commands below.

---

## 1. Where things stand

A mobile-first (Android, Galaxy Z Flip6) historical grand-strategy game,
1590–1949 (extended by the user to leave room for post-war content), built in **Godot 4.7.1, Mobile renderer**. `structure.md` suggests
Flutter; the user chose Godot and the brief is implemented in Godot.

**Done: Milestones 0–7** (M4 diplomacy, M5 economy with estates, goods,
buildings, tax policy, loans and bankruptcy, M6 colonisation, M7 armies and
war), plus an era-based soundtrack. The real world on **1 January
1590**, playable as any country, with save/load and a simulation scheduler:

| Thing | Current value |
| --- | --- |
| Map | Mercator 6144 × 3409 px, lon −170…190, lat 76°N…62°S, wraps east–west |
| Ownable provinces | exactly **5000**, regional quotas met exactly |
| Wastelands (impassable, unownable) | 98 |
| Sea tiles (incl. lake tiles) | 573 (20 on lakes) |
| Polities | 238, all playable (`ENG` is only the default for debug starts) |
| Uncolonised provinces | 1085 |
| Tests | 149, all passing (incl. a headless end-to-end flow test) |
| Data version | 7 (provinces redrawn: fewer in New Guinea, more in Australia, southern Canada, the US Pacific coast, the Russian Far East, Manchuria and Germany; older saves are refused with a message; saves also carry a fingerprint of the map) |

Working features: title menu (Continue / New campaign / Load); **choose your
country** by tapping it on the 1590 map ("Play as …"); pan / pinch / wheel zoom
with east–west wrap; tap to select a province, wasteland or sea tile; province
panel and **country panel** (tap a country's name on the map, an owner link, or
your name in the top bar; the country is tinted and outlined); eleven map modes
in four groups on the bottom bar — Realm (Political, Control, Diplomacy,
Colonisation, Colonial regions),
Economy (Economy, Goods), Land (Topography, Vegetation, Climate), People
(Population); tapping a group slides its modes out above it. Info modes write
each province's value on the map (climate, good, output, population …) with **occupation stripes**; calendar
with pause and 5 speeds driven by the **SimulationScheduler**; **save / load**
(atomic, versioned, backups, damaged-save recovery) and **autosave** (1 January,
app backgrounded, window closed); in-game menu (☰ / Esc / Android back);
transparent 3D layer (capitals, forests, peaks, selection pin, names); vector
rivers; smooth borders; LOD with hysteresis; view-dependent streaming.

**Simulating:** the economy, diplomacy, colonisation and war. Next up is
Milestone 8, 1590-era politics (see §10).

**Git:** repository initialised on `master`, **no commits yet**; everything is
untracked. Commit only when the user asks. `.gitignore` excludes `.godot/`,
`tools/source_data/`, `*.apk`, `*.apk.idsig`, `*.aab`. The user has built an
APK (`Sovereignty.apk`) themselves.

---

## 2. Working agreements with the user (important)

The user reviews the map closely and gives precise historical and visual
feedback. Standing requirements, all from their corrections:

* **Real geography and history.** Province borders and names follow real
  geography (real first-level divisions, rivers, ranges), not abstract cells.
  The user spots historical errors (e.g. Shantou must be Ming, not Portuguese;
  Flevoland didn't exist in 1590; the Aral Sea was much bigger). Verify such
  claims with tests that probe real lat/lon points (`HISTORICAL_OWNERS` in
  `tests/test_world.gd`).
* **Province count:** 5000 ownable provinces with the user's regional quotas
  (Europe 25.3 %, China/Korea/Japan 17.7 % — 15 moved from inland China to
  Germany at the user's request on 16 Oct 2026 — India 13 %, Middle East & Central Asia
  11 %, Africa 10 %, SE Asia 8 %, N. America 6.5 %, S. America 4.5 %, Oceania
  1.5 %, other 2.5 %). Going *slightly* above 5000 is acceptable if needed.
  Uncolonised land is allowed. Wastelands and sea tiles are extra.
* **Wastelands must never wall a province off** — every province must be
  reachable by land or sea (tested). Historic routes are kept as corridors
  (Nile to Sudan, trans-Saharan roads incl. Biskra–Arak, Silk Road…).
  **No straight latitude cut-offs** for wastelands (the user found a flat
  Arctic line ugly) — wastelands follow geography only.
* **Look and performance:** text and borders must be crisp when zoomed into
  dense areas like Europe; LOD layers need hysteresis; zooming must stay fast
  — only add detail where the camera is looking (plus a margin).
* **Downloads need explicit permission** each time (state file, source, size).
  All source data so far is public-domain Natural Earth.
* **Landscape only on phones** (user request, 15 Oct 2026):
  `window/handheld/orientation=4` (sensor landscape). The HUD keeps a
  portrait layout, used only for narrow desktop windows.
* **Country selection** exists (New campaign → tap a country → Play as).
  `ENG` in the scenario is only the default for debug starts.
* The user plays builds while work goes on and makes their own saves in
  `user://saves` — never delete saves you did not create (tests use their own
  folders, `user://test_saves` and `user://test_flow_saves`).
* The user often sends follow-up messages mid-task; fold them in and keep a
  short running commentary.
* **Province density (user, 16 Oct 2026):** New Guinea had too many
  provinces and Australia too few; southern and coastal Canada, the US
  Pacific coast and the Russian Far East wanted more; a few from inland
  China (never the coast) to Germany and Manchuria. Done with
  `Regions.SEED_BOOSTS` (per-country lat/lon boxes multiplying province
  density); a region's quota stays fixed, so North America's additions came
  mostly from Mexico (−17) and the eastern US (−8).
* **Colonisation (user, 16 Oct 2026):** frontiers easier; some environments
  harder for some peoples; an African kingdom expands gradually once it has
  "the right idea" (a colonial policy); Russia settles Siberia readily; and
  **Europeans must not hold Africa's interior by 1690** — only with 19th-century
  technology. The disease gate (`Colonisation.MEDICINE`) enforces that.
  The user later asked for a Russian bonus on connected land
  (`Colonisation.FRONTIER_TRADITIONS`: "Cossack frontier" ×1.6). Monthly order
  matters: colonisation runs before the AI's construction, or building eats
  the money colonies need (Russia founded none for decades).
* **Music (user, 16 Oct 2026):** `music/<n Age>/<Region>/` — ages 1590–1690,
  1690–1750, 1750–1830, 1830–1900, 1900–1949; each period plays its own
  music, transitioning slowly. Only Europe tracks for ages 1–2 exist so far;
  the user adds files there.
* **Armies and war (user, 19 Oct 2026):** forts on the map; small standing
  armies in 1590, levies called in war; drag-select several armies and merge
  them; permanent navies; the Caspian navigable; a big range of unit types
  incl. future ones (tanks, aircraft) hidden until their era, shown by region;
  100k men per stack.
* **Policies (user, 19 Oct 2026):** gifts sized by the player; court, minting,
  forts, army and navy as finer percent sliders (`Policies`), not levels.
* **Population (user, 19 Oct 2026):** "5 million people in Southern
  Mongolia" — land of tribal polities now weighs `Regions.TRIBAL_POP` (4 %)
  in population; populations only, the map is unchanged.
* **Map modes (user, 16 Oct 2026):** a map mode must write its information
  on the map (climate names in Climate, goods in Goods …) — colours alone are
  "a pain to read"; connected provinces sharing a value get **one bigger
  label**, not one each; map modes are grouped so the bottom bar isn't crowded.
* **Economy design (user, 16 Oct 2026):** estates nobility / clergy /
  merchants / commoners / tribesmen; taxes are **proportional** (a percentage
  of each estate's income — nobles and merchants are richer per head so they
  pay more each; commoners are poorer but many, so together they add up);
  **clergy cannot be taxed for now**; tax set per estate with a **slider in
  1 % steps plus − / + buttons**, with a maximum per estate; the budget panel
  is wide for thumbs. Buildings do extraction, income, protection or
  manufacture — they do **not** raise the value of goods. Prices are fixed
  until a Victoria-3-style market (later). No army/navy spending until armies.
  The user found the first tax yield too low; keep totals generous.

---

## 3. Commands

Godot executable on this machine: `D:/Programs/Godot_v4.7.1-stable_win64_console.exe`
(written `godot` below). Run from the project root.

```bash
godot --headless --path . --import                              # after adding scripts/class_names
godot --headless --path . --script res://tests/run_tests.gd     # tests (non-zero exit on failure)
godot --path .                                                  # run the game
godot --path . -- --screenshot=out.png --at=48.86,2.35 --zoom=3 --mode=terrain --select=<id>
godot --path . -- --screenshot=out.png --country=FRA --occupy=5,3546 --mode=control
godot --path . -- --screenshot=out.png --menu[=choose|pause|saves]   # menu pages
godot --path . -- --screenshot=out.png --play=TUR --load=<slot>
godot --path . -- --screenshot=out.png --play=FRA --war=SPA --days=60 --treaty   # war debug: also --levies, --military, --army[=fleet], --march=lat,lon
godot --path . --resolution 2560x1440 -- --screenshot=hd.png ...   # 2x DPI check
godot --path . --resolution 450x980 -- --screenshot=p.png ...      # narrow window (phones are landscape-only)
godot --path . --script res://tools/profile_zoom.gd             # zoom/pan performance probe
bash tools/fetch_source_data.sh                                 # Natural Earth data (~68 MB)
godot --headless --path . --script res://tools/world1590/build_world.gd   # regenerate world (~3-4 min)
```

Verification habit used so far: run tests, then take screenshots and *look*
at them (Read the PNG) before claiming something works.

---

## 4. Runtime architecture

Rule from the brief: simulation logic never in UI/rendering; painting is
read-only; stable IDs; time only through the scheduler (which drives the clock).

```
game.tscn
└─ Game (src/game.gd)                composition root: phases TITLE → CHOOSING → PLAYING;
   │                                 owns Campaign, SimulationScheduler, SaveService,
   │                                 autosave, back button, debug CLI args
   ├─ MapView (Node2D)               2D map: 3 Sprite2D copies (wrap) + map.gdshader,
   │  └─ MapRivers                    palette texture, picking (province_at), vector rivers
   ├─ MapCamera (Camera2D)           pan/zoom/pinch, wraps x into [0, width), emits view_changed
   ├─ OverlayLayer (CanvasLayer 1)
   │  ├─ MapOverlay3D (SubViewportContainer)   transparent 3D layer (see below)
   │  └─ name canvas (Node2D)        province / sea names drawn in 2D screen space
   └─ HUD (CanvasLayer 2)            top bar / choose-country bar, map-mode bar, zoom
                                     buttons, drawer (ProvincePanel | CountryPanel),
                                     MenuScreen, toast
```

| Path | Role |
| --- | --- |
| `src/core/game_clock.gd` | `GameClock`: Gregorian calendar 1 Jan 1590 → 31 Dec 1949, pause, speeds 1–5 (1/3/8/20/60 days/s), ≤8 ticks/frame, `advance(delta, can_step)`, `day_number()` (days since 1 Jan 1590), day/month/year signals, to/check/load dict |
| `src/core/game_random.gd` | `GameRandom`: the campaign's seeded RNG (randf, randi_range, chance, pick, weighted_index); seed/state saved as strings (64-bit) |
| `src/core/save_service.gd` | `SaveService`: folder from `device_save_dir()` — Android: `Documents/Sovereignty` on shared storage (user request: saves must be reachable on the phone), else app-specific `Android/data/<pkg>/files/Documents/Sovereignty`, else `user://saves`, picked by a write/rename/list test (`is_usable_dir`); desktop: `user://saves`. `<slot>.srt` (extension chosen by the user; JSON inside — note `.srt` is also the SubRip subtitle extension); header `format`, `schema_version` (5; migrations 1→2→3→4→5), `world_version`, `world_fingerprint` (MD5 of the province-id map), `saved_at`, `title`, `country`, `date_text`; atomic write (`.tmp.srt` → read back + `Campaign.check` → old file to `.bak.srt` → rename); `read`, `load_into`, `list_saves`, `latest_save`, `delete`, `folder_path`; `_migrate` hook; slot `autosave`. **Not yet verified on a phone.** |
| `src/domain/campaign.gd` | `Campaign`: world + clock + rng; `to_dict` / `check` / `restore` (all-or-nothing); `start_new(tag, seed)` returns to the scenario start |
| `src/simulation/simulation_scheduler.gd` | `SimulationScheduler`: `register(name, cadence, fn)`, `register_job(name, cadence, start)`; daily, weekly (`day_number % 7`), monthly, quarterly, yearly; registration order; jobs sliced within `frame_budget_usec` (4 ms) and the clock holds until the day's work is done; `finish_pending()` before saving |
| `src/domain/province.gd` | `Province`: static fields + campaign state; flags `is_wasteland`, `is_sea`; `neighbour_ids` (land↔land or sea↔sea), `sea_ids` (land→adjacent seas), `coast_ids` (sea→shore provinces), `division` (real admin-1 name) |
| `src/domain/country.gd` | `Country` |
| `src/domain/world_state.gd` | `WorldState`: authoritative state; `transfer_province()` (the only way to change owner; rejects wastes/seas), `set_controller()`, `set_player_country()`, `country_stats()`, `ownable_provinces()`, `sea_tiles()`, `province_near(lat, lon)`, `latlon_to_map()`, `validate()`; saves: `campaign_state()`, `check_campaign_state()`, `restore_campaign_state()` (emits `campaign_restored`) |
| `src/domain/world_loader.gd` | `WorldLoader`: loads `data/world/*.json` + scenario |
| `src/map/map_view.gd` | `MapView`; palette RGBA per id: RGB fill, A = border-country index + 1 (owner; controller in Control mode), **255 = wasteland, 254 = sea tile**; second `stripes` palette (RGB stripe colour, A = stripe width) for occupation; `select_country(tag)` |
| `src/map/map.gdshader` | Two paths: zoomed in (`spx < 0.55`) = smooth 2×2 bilinear-vote province shapes + AA borders by screen distance; zoomed out = neighbour-compare borders. Water = id 0 or palette A 254. Occupation stripes 9 screen px apart; `selected_country` tint and outline |
| `src/map/map_camera.gd` | `MapCamera`; min zoom fits height and never shows more than one map width |
| `src/map/map_lod.gd` | `MapLod`: WORLD/REGION/PROVINCE/DETAIL, enter at zoom 0.62/1.9/4.0, leave at 0.52/1.6/3.4 (hysteresis) |
| `src/map/map_rivers.gd` | `MapRivers`: rivers cut into 512-px tiles, only tiles near the view exist; widths rebuilt only after 20 % zoom drift; ≤3 new tiles/frame |
| `src/map/map_overlay_3d.gd` | `MapOverlay3D` (largest file, ~730 lines) — see below |
| `src/map/map_modes.gd` | colours per map mode, terrain/waste/sea colours, markers; `GROUPS` (bottom-bar groups), `INFO_MODES`, `info_text(p, mode, economy)` (the value written on a province), `compact_number()` |
| `src/domain/diplomacy.gd` | `Diplomacy` (world.diplomacy): subjects (vassal / personal_union / tributary), alliances, royal marriages, declared rivals (≤ 3), envoys (2), fading opinion modifiers, yearly cooldowns; `opinion()` = sum of `opinion_reasons()`; `to_dict` / `check_dict` / `load_dict`; signals `changed`, `reset` |
| `src/simulation/diplomacy_actions.gd` | `DiplomacyActions`: `blocked(action, from, to, amount)` (reason or ""; nothing with an enemy at war), `evaluate()` (the other side's reasons and total), `perform()`; strength = total development; neighbours by land or shared sea tile |
| `src/simulation/diplomacy_system.gd` | `DiplomacySystem.monthly()` (scheduler, MONTHLY): fading, envoys, simple reproducible AI (never proposes to the player) |
| `src/simulation/economy_system.gd` | `EconomySystem.new(campaign)`: `production(p)` (raw/made units, value, named factors; `VALUE_SCALE` sets the money scale), `estate_incomes(p, value)`, `province_taxes(p)` (rate × reach × goodwill), `reach_of(p)`, `budgets()` / `budget(tag)` (named lines: "Taxes: <Estate>", customs, occupied lands, tribute, minting; administration, court, forts, interest, tribute), `monthly()` (ledger, policy effects on legitimacy/inflation/goodwill, deficit → loan or bankruptcy, unrest, construction), `yearly()` (deposit discoveries, signal `discovered`), loans (`interest_rate`, `credit_limit`, `loan_blocked`, `take_loan`, `repay_blocked`, `repay_loan(tag, i)`, `declare_bankruptcy`, `ai_repayments`), buildings (`building_cost`, `build_blocked`, `start_building`, `ai_construction`); `decimal()` keeps saved numbers JSON-exact |
| `src/domain/goods.gd` | `Goods.CATALOGUE`: raw goods (kind farm/cash/wild/mine, yield, fixed price, map colour, `era`) and manufactured goods |
| `src/domain/estates.gd` | `Estates`: roles, per-head income weights, `CUSTOMARY_TAX` / `TAX_MAX` (percent), `TAX_EXEMPT` (clergy), labour, `initial_shares()`, `split()` |
| `src/domain/buildings.gd` | `Buildings.CATALOGUE` (extraction / income / protection / manufacture with recipes), `unsuitable()`, `relevant()`, `extraction_bonus()`, `recipe()`, `merchant_bonus()`, `customs_share()`, `upkeep()` |
| `src/ui/budget_panel.gd` | `BudgetPanel` (wide): treasury, debt, inflation; for the player the policies first — tax % slider with − / + per estate (clergy shown exempt), court, minting, forts — then next month's lines and last month's ledger; slider drags hold panel refreshes |
| `src/domain/colonisation.gd` | `Colonisation`: rules — `POLICIES` (colonies, overseas, upkeep), progress factors (access, `land_factor`, `familiarity`, `native_factor`, `disease_factor` with `MEDICINE` by year and `in_disease_zone`: tropical Africa, New Guinea), founding cost, `SETTLERS` |
| `src/simulation/colonisation_system.gd` | `ColonisationSystem.new(campaign, economy)`: `home_climates`, `coast_tiles`, `sea_hops` (BFS over sea tiles from the home ports), `access` (frontier / strait / overseas), `rate` (named factors), `months_to_settle`, `outlook` (for maps), `blocked`, `found_colony`, `abandon`, `monthly` (progress, uprisings, completion via `transfer_province`), `ai_monthly`, `ai_yearly` (policy adoption); signals founded/completed/abandoned/uprising |
| `src/domain/unit_types.gd` | `UnitTypes.CATALOGUE` (~50 kinds 1590–1949: domain land/sea/air, kind, years, `groups`/`tags`, men, attack, defence, morale, speed, cost, upkeep, months, siege), `groups_of(world, tag)` (traditions from the capital's region), `available`, `recruitable(world, tag, year, domain)`, `MAX_STACK` 100,000 |
| `src/domain/army.gd` | `Army`: owner, navy, location, regiments `[type, men, home]` (home = levy's province), morale, path, leg days, `aboard` (the fleet carrying it), `retreating`; `men`, `power`, `speed`, `upkeep`, `capacity` (a fleet's), `by_type`; save rows of 12 (10 read too) |
| `src/domain/overseas.gd` | `Overseas` (static): `REGIONS` (colonial regions as lat/lon boxes per world region), `region_of`, `overseas_ids` (another world region, no route to the capital over own land), `NATION_NAMES` (historical names and seats), `update(world)` (monthly and at load: hands overseas land to its colonial nation or founds one at `NATION_MIN` = 3), `found_nation` |
| `src/domain/claims.gd` | `Claims` (world.claims): cores and claims by province, `held` (owner and since when, until cored); `populate` (owners' cores, `RIGHTS_1590`), `yearly` (cores after `CORE_YEARS`), `grudges` (for the AI); saved by tag |
| `src/domain/military.gd` | `Military` (world.military): armies, wars `{id, name, attackers, defenders, start, battle_score, refused}`, truces, sieges, recruiting, levies raised; an index of who fights whom (`war_index`, `war_ids_of`, `side_in`, `at_war`, `refusing_wars`; change wars only through `add_war` / `remove_war` / `join_war` / `leave_war`); `populate(world, year)` (1590 armies, navies with transports, forts, docks), `cargo_of`, `recount_levies`, `preferred_unit`, `home_port` / `home_sea`; to/check/load dict; signals changed / wars_changed / reset |
| `src/domain/policies.gd` | `Policies`: spending sliders (court, mint, forts, army, navy: range, step, default) and their effects (court legitimacy and nobles, mint inflation, upkeep, fort siege days, max morale) |
| `src/simulation/military_system.gd` | `MilitarySystem.new(campaign, economy, actions)`: `can_enter`, `find_path` (A*, binary heap; straits by our fleet), `order_move`, `daily` (recruits, march, battles, sieges), `battle`, `estimate`, `siege_days`, `monthly` (manpower refill, supply/attrition, reinforcement, levy deaths), manpower (`manpower_limit(s)`, `manpower`, `manpower_growth`), levies (`raise_levies`, `disband_levies`, muster points; never automatic), `recruit`, `merge`/`split`/`disband`, `war_blocked`/`war_sides`/`declare_war`, `war_score`, `score_for`, `held_by`; treaties `{provinces, money, forts}`: `treaty_cost`, `treaty_blocked`, `treaty_accepted`, `describe_treaty`, `treaty_for` (white/demand/surrender), `conclude` (cedes land to whoever holds it, reparations via `economy.post`, razes forts, truces); `peace_accepted`/`peace_blocked`/`make_peace` (the simple peaces); AI (`ai_daily`: a seventh of armies a day, weekly levies and merging; `ai_monthly_peace`: treaties, offers to the player; `ai_yearly_wars`); signals incl. `peace_offered(war, treaty, from)`, `forts_changed` |
| `src/map/map_forces.gd` | `MapForces`: 3D banners and ships per army in the owner's colour (offset when sharing a province, gliding along the march), fort walls, piers at docks (placed on the real shore by rays through the id image via `province_at`, else a pixel scan; fleets in port lie off them); 2D men counts, selection rings, dashed routes with arrowheads, siege progress; `army_at`, `armies_in` (box); positions once a frame (`update_positions_later`), and only changed tokens touched |
| `src/ui/army_panel.gd` | `ArmyPanel`: one army (men, spirit, place, status, upkeep, regiments) or several (merge); Split, Halt, Disband |
| `src/ui/military_panel.gd` | `MilitaryPanel` (wide, the ⚔ Military tab): standing army, levies, ships, manpower, upkeep; mobilise or send home all, or region by region (`levy_districts`); army and navy maintenance sliders; armies and fleets (tap to select); wars (tap for the war's panel) |
| `src/ui/peace_treaty_panel.gd` | `PeaceTreatyPanel` (wide, a scroll gutter): a treaty with one country (opened by suing it for peace); score, cost of demands, worth of what we give, their answer; map taps toggle land (`toggle_province`; `highlights_changed` colours the map: demand bright green, give bright red, held paler); reparations slider, forts, vassalage, their subjects (set free / ours), their alliances; Propose / Surrender |
| `src/simulation/land_deals.gd` | `LandDeals.new(campaign, economy, actions)`: deals `{take, give, money}`; `worth` (10 years of yield to the owner), `worth_to` (at another's reach, cores ×1.5), `blocked`, `evaluate` (reasons: reluctance, value, hard to govern, importance, finances, opinion, rivalry), `propose` (land and money change hands, cores renounced), `describe` |
| `src/ui/land_deal_panel.gd` | `LandDealPanel` (wide, scroll gutter; `Kind` BUY / SELL / EXCHANGE): buying, selling or exchanging land with a country; map taps pick their land (green) and ours (red); money slider either way, *Even it out*, every reason and their answer; Propose |
| `src/ui/war_panel.gd` | `WarPanel` (a centred pop-up, not a drawer; the game pauses while it is open and runs on when it is dismissed, `closed(resume)`): one of our wars (its red badge under the top bar): score, length, our side on the left and theirs on the right with estimated men under arms and totals, *Sue for peace* beside theirs where the rules allow, those who stayed out |
| `src/audio/music_player.gd` | `MusicPlayer`: scans `res://music/<n Age>/<Region>/` (`ResourceLoader.list_directory`, so exported builds work), `age_of(year)`, picks tracks by age and the player's region (falls back to any region, to the nearest earlier age with music), next age creeping in over the last `TRANSITION_YEARS`, crossfades on `jump_to` (new campaign, load, other country), music on/off in `user://settings.cfg`; not created in headless runs |
| `src/ui/loans_panel.gd` | `LoansPanel` (wide): debt, interest, lenders' limit, next rate, each loan with Repay, Borrow, Declare bankruptcy (confirmed) |
| `src/domain/land.gd` | `Land`: value lists for topography, vegetation, climate; `display()`, `is_valid()` |
| `src/ui/*` | `HUD` (screens TITLE / CHOOSING / PLAYING), `MenuScreen` (title, pause, saves list, confirm, message; signals only), `DrawerPanel` base (`wide` flag, `refresh()`) → `ProvincePanel` (owner/controller links; people table — earns/pays per estate; production; buildings and Build buttons for own provinces; land at the bottom; debug annex/occupy) and `CountryPanel` (Play as …, Show on map), `UITheme` (touch sizes, primary/link buttons, serif titles; base canvas 720 px short side) |

**Map-mode values on the map:** category modes (`MapModes.REGION_LABEL_MODES`:
Goods, Topography, Vegetation, Climate) name each block of connected land
provinces sharing a value **once**, across its extent like a country name
(`_build_regions`: area, centre, principal axis; drawn in 2D on the names
canvas, rotated, font snapped to `REGION_LABEL_SIZES`, largest first, no
overlaps; country names hidden in these modes; province names from the
PROVINCE zoom fit around them) — the user asked for one big label per region,
not one per province. Number modes (Economy, Population) write each
province's value under its name instead (from the REGION zoom; country names
keep to the WORLD zoom). Values come from `MapModes.info_text`, cached per
province until `MapView.palette_refreshed`, which also rebuilds the regions.

**MapOverlay3D (the "transparent 3D layer"):** SubViewport with transparent
background, sized to *physical* pixels (`_fit_to_screen`) so it is sharp on
high-DPI phones; orthographic Camera3D straight down, synced from MapCamera
(`1 map px = 0.01 units`, `camera.size = view_height / zoom * 0.01`). Props
hang under a node with an **oblique shear** so heights show while bases stay
on their map pixel. Blob shadows (the Mobile renderer can't do
`shadow_to_opacity`). Scenery (trees/peaks) bucketed into 512-px tiles,
instanced only near the view (≤3 new tiles/frame, MultiMesh cached per tile).
Capitals: castle keeps (major polities ≥25 provinces always; others from the
REGION level). Country, wasteland and major-sea names: Label3D with an
**MSDF** serif SystemFont (`msdf_pixel_range = 32`; outline must stay ≤ half
of it). Province and sea-tile names: **2D** on a canvas above the 3D layer,
plain (non-MSDF) font, collision-culled, largest first, keeps already-shown
names stable. Everything placed at the wrap copy nearest the camera (`_near`).

MapOverlay3D also answers `country_label_at(map_pos)` (tapping a visible
country name opens the country; a second tap on the same name selects the
province underneath) and rebuilds names and keeps on `campaign_restored`.

**IDs in `data/map/province_ids.res`** (Image RG8, id = R + G·256):
`0` = water without a tile (small lakes), `1…5000` ownable provinces,
`5001…5098` wastelands, `5099…5674` sea tiles. Palette is 256×256 (max 65535).

---

## 5. Data files (all generated — don't hand-edit)

| File | Content |
| --- | --- |
| `data/map/province_ids.res` | RG8 Image, 6144×3409 |
| `data/map/heightmap.res` | RG8 Image, half res: R = relief (<0.5 sea depth, ≥0.5 land); G = old river mask (unused by the shader now) |
| `data/map/rivers.json` | river polylines in map px, rank 1–3 |
| `data/world/provinces.json` | `map` (size, textures, projection), `regions` (id → name, quota), `provinces[]` (incl. land, `resource`, hidden `deposits` [good, year, yearly chance]), `wastelands[]`, `seas[]` |
| `data/world/countries.json` | id, name, colour |
| `data/scenarios/1590.json` | player country, per-country capital/government/treasury, per-province owner/controller/population/development/buildings, diplomacy |

---

## 6. World generator (`tools/world1590/`)

`build_world.gd` (SceneTree script, ~2300 lines, deterministic seed 1590,
~3–4 min) reads Natural Earth GeoJSON from `tools/source_data/` (git-ignored;
`bash tools/fetch_source_data.sh` fetches all 7 layers). Pipeline:

1. **Rasterise** admin-0 countries (+ stamps for sub-pixel island states),
   lakes (no modern reservoirs), `HISTORIC_WATER` (full Aral Sea; Zuiderzee
   incl. Flevoland/Noordoostpolder/Wieringermeer/Afsluitdijk), geography
   regions → terrain, rivers (incl. lake centrelines for river valleys),
   admin-1 divisions, marine names, island names.
2. **Zones** (modern country, with sub-zones for RUS/CHN/USA/overseas) give
   ~1600 population (`POPULATION_K`) and province density from habitable area.
3. **Wastelands** (half-res distance fields, noise-wobbled thresholds): cores
   of `WASTE_DESERTS`, `WASTE_RANGES`, the Tibetan plateau, tundra regions;
   Greenland ice; islands with centre ≥ 70°N; land ≤ 58°S. Kept habitable:
   near major rivers, coasts (deserts), capitals/forced points (irregular
   blobs), `TRADE_ROUTES` corridors. **Enclave pass**: habitable pockets walled
   by wasteland with no outlet to a sea-tile-sized water body get a corridor
   (if inhabited/large) or are absorbed.
4. **Provinces on real divisions**: admin-1 units merged (< 0.55 of a province;
   never across polities that held them in 1590 — `_unit_owner` evaluates the
   rules at each division centre)
   or split per regional quota; seeds (capitals + `FORCED_POINTS` first, then
   density-weighted Poisson); Dijkstra growth inside each group with river
   (+8/+14) and mountain (+3) crossing costs; cut-off pieces join neighbours.
5. **Wasteland ids**, **sea tiles** (curated `SEA_ANCHORS` first — Channel,
   Irish Sea, Skagerrak, Kattegat, Marmara, Ligurian, Gulf of Finland, Alboran,
   Malacca, Taiwan Strait, Hormuz, Bab-el-Mandeb — then Poisson seeds 330 km
   apart at coasts → 1300 km offshore, grown across water), adjacency (land,
   sea, coasts), straits (`STRAITS`).
6. **Owners** (`polities_1590.gd`): capital province → its polity; else
   `RULES[adm0]` evaluated at the province's main town (rank ≤ 6, so coastal
   colonies follow their port), or else by **majority over ~40 points spread
   across the province**, each judged by the rules of the country it lies in
   (a single seed point used to decide, and flipped border provinces whenever
   seeds moved). A rule is a string
   (whole country) or `[default, [tag, radius_km, anchors]…]` (nearest anchor
   within radius wins). If that yields "" and the division is in
   `SETTLED_DIVISIONS`, the nearest claimant with radius 0 or ≥ 100 km wins
   (outposts like Macau never qualify). `EUROPEAN_ONLY` countries' overseas
   bits are uncolonised. Diplomacy at the start (`SUBJECTS`, `ALLIANCES`,
   `ROYAL_MARRIAGES`, `RIVALRIES`) is written into the scenario.
7. **Names**: major city (rank ≤ 3) > division (with `HISTORIC_ADMIN` renames)
   > towns > rivers > compass forms relative to the division centre > Roman
   numerals. Seas: marine feature names, "Coast of …", directional forms; a
   second pass guarantees every sizeable named sea a tile. Wastes: island /
   desert / range / tundra names.
8. **Land** (`land_1590.gd`, after population, no `rng`): climate = majority
   Köppen class of the province's samples (ET/EF below 55° = subarctic);
   topography from mean ETOPO1 elevation + median ruggedness (step to the
   neighbouring 5' cells; mountains ≥ 170 m, plateau ≥ 600 m elevation and
   < 140 m + 3 m per 100 m above 600 m, hills ≥ 55 m, wetlands = ≥ 25 %
   Natural Earth wetland); vegetation
   = Köppen natural cover, adjusted by named landscapes (steppe, desert,
   jungle, tundra), treeline, farmland at ≥ 18 people/km² (or ≥ 1.5 on a
   great river in dry land). Exported as `topography`, `vegetation`,
   `climate`, `elevation`.
9. **Population/development**, **colours** (auto palette contrasting with
   neighbours), outputs, report.

**Editing history:** add a polity to `POLITIES` (`[name, government, colour or
"", capital [lat, lon]]`) and its claims to `RULES`; add enclaves/outposts to
`FORCED_POINTS` (also used to split one modern division into its 1590 lands,
e.g. Västra Götaland → Bohuslän / Gothenburg / Dalsland / Västergötland);
settled divisions to `SETTLED_DIVISIONS`; narrow seas to `SEA_ANCHORS`; routes to
`TRADE_ROUTES`; water to `HISTORIC_WATER`; renames to `HISTORIC_NAMES` /
`HISTORIC_ADMIN` / `HISTORIC_WATER_NAMES`. Then regenerate, run tests, and add
a `TOWN_OWNERS` (pixel probe — preferred) or `HISTORICAL_OWNERS` test for
the fix. Keep anchor radii small for narrow lands (Halland, Blekinge and
Bohuslän are coastal strips; a 70 km circle reaches deep into Sweden).

**Caveat:** any change to the generator reshuffles random placement, so
"flaky" geography tests can flip (it happened several times). Prefer tests
that probe actual map pixels (`MapView.province_at(world.latlon_to_map(...))`)
or connectivity, not exact names/centres.

---

## 7. Tests (`tests/`)

Runner: `tests/run_tests.gd` runs every `test_*` method in `tests/test_*.gd`
(base class `tests/test_case.gd` with `check`, `check_eq`). It starts on the
first frame (so scenes added by tests get `_ready`) and fails a test on any
**script error**, caught through a `Logger` — before, a runtime error aborted
the test silently and it counted as passed. `push_error` output is expected in
some tests and does not count.

* `test_game_clock.gd` (9): pause, speeds, bounded ticks, month/year rollover,
  leap years, 1949 end, serialisation.
* `test_game_random.gd` (5): determinism, JSON round trip mid-stream, 64-bit seeds.
* `test_save.gd` (13): campaign round trip; save folder write test; leftover temp files ignored; save → load identical; versions and
  timestamp; backup kept; damaged save refused and its backup loads; unknown ids
  and out-of-range values named; restore all-or-nothing; newer schema, other
  world version and foreign JSON refused; listing newest first; delete; new
  campaign resets to the scenario.
* `test_scheduler.gd` (8): cadence counts over a year, weeks anchored to 1590,
  order, jobs hold the clock, headless completion, finish_pending, pause, speeds.
* `test_game_flow.gd` (1): the real scene, headless — title → new campaign →
  tap Paris → play as France → selection and links → army tap and box
  selection (boxes add up, an order ends the mode, armies before fleets and
  never both, ✕ clears) → a gift through the
  confirmation dialog → save → main menu → new campaign resets → continue →
  back button → New Year autosave.
* `test_diplomacy.gd` (11): Iberian Union keeps Portugal its own country; 1590
  subjects and treaties; opinion = sum of reasons; gift, insult, rival,
  alliance, marriage, vassal rules; envoys and fading; saved and restored;
  AI reproducible; vassals drawn in shades of their overlord.
* `test_land.gd` (3): every land province valid; real places; every kind occurs.
* `test_colonisation.gd` (9): 1590 policies; Russia's Siberian frontier; the
  disease gate (closed inland before 1850, Africans exempt); Kongo founds and
  completes a colony once it has a policy; overseas needs the policy; costs,
  slots, upkeep, abandoning; uprisings; save round trip and format 5 upgrade;
  20 years of AI without a European in Africa's interior.
* `test_military.gd` (23): transports (capacity, boarding, landing, lost with
  the fleet); retreats (no wipe, distance rule, no battle or orders while
  falling back, wiped when overwhelmed); disloyal vassals stay out until
  attacked; separate peace; vassals, alliances and land offered in peace; the
  AI's separate peace; levies by region; docks (1590 navies in port, upkeep halved, no
  canals, repairs only in port, ships built at docks, a lost port); saves from
  before docks get them; units by era and region; the forces of 1590; roads
  and neutral land; the Caspian; war (no automatic levies for the player),
  levies, occupation, battle, peace and truce; peace treaties (costs rise with
  land, money and forts; reparations paid; a fort razed; no diplomacy with an
  enemy; the treaty screen's defaults); the AI offers the player a treaty;
  forts hold out; merge/split and the 100k limit; manpower; recruitment; upkeep
  by maintenance; saving and the format 6 upgrade; an AI war ends.
* `test_overseas.gd` (4): colonial regions (Mexico, Lima, Potosí, Salvador,
  Havana, Costa Rica, Goa; none in Europe); the colonial nations of 1590
  (New Spain holds Mexico City, its capital; Spain holds nothing there
  directly; nothing of Russia's overseas); three settled provinces found the
  Thirteen Colonies, a fourth joins, tribute, saved and restored, gone in a
  new campaign; no levies overseas.
* `test_land_deals.gd` (3): land has a worth; a far outpost (Oran) sells more
  easily than the heartland (Toledo); more money, a poorer seller help; a
  rival is refused; capitals, others' land and money one lacks are blocked; a
  sale (land, money, core renounced); an exchange evened out with money; none
  at war; selling ours (cheaper, more willing; land beside theirs fits better
  than land far off; within their treasury; a bargain taken).
* `test_claims.gd` (2): the rights of 1590 (every owner's cores, Calais,
  the Low Countries, Busan, Buda; grudges; kept in a new campaign); cores
  after 25 years and kept on lost land; saved, and older saves get them.
* `test_music.gd` (2): ages by year; tracks by age and region, fallbacks,
  the next age creeping in.
* `test_map_modes.gd` (2): every mode in exactly one group; info text per mode
  (climate, goods incl. "Kaolin → Porcelain", output, population; nothing on
  the sea); compact numbers.
* `test_economy.gd` (25): estates add up to the population, uncolonised land
  tribal; every province produces a raw good (Potosí silver, Jingdezhen kaolin,
  Banten spices); deposits wait for their age; production = product of named
  factors, mines +50 %; manufactories (kilns, weaveries); buildings paid and
  built, AI builds; budget lines add up, no military, clergy untaxed; surplus
  and deficit; proportional tax rates vs goodwill and unrest; minting and
  inflation; court; ledger; loans, credit limit, bankruptcy (declared and
  forced); AI repays; discoveries; tribute; occupation; save round trip;
  format 3 and 4 upgrades; tax ceiling.
* `test_world.gd` (27): loads cleanly; 5000 ownable; regional quotas exact;
  ~45 historical owner spot checks; `TOWN_OWNERS` probes the map pixel under
  a town (France vs Franche-Comté, the Spanish Netherlands and Savoy); uncolonised exists; every country holds its
  capital; every province reachable; label points inside provinces; id texture
  ↔ province list; wrap seam; wastelands impassable/unownable + geography
  (Sahara, Everest, Changtang, Greenland ice; Nile/Fezzan/Timbuktu/Lhasa/Kashgar
  habitable); Nile and Sahara crossings; Biskra→Arak; Egypt ≥15 provinces and
  delta ≥6; divisions recorded; sea tiles (count, names, unowned); coasts ↔
  sea tiles; Cape Horn and North Cape sailable; ownership transfer rules;
  validation.

---

## 8. Performance (desktop RTX 4060 Ti; not yet measured on the Flip6)

**Simulation over time (19 Oct 2026, the user's phone report):** months got
slower and slower (≈0.3 s in 1590, 1 s by 1594, 10 s by 1600 on the phone).
The cause was not past months being replayed but AI countries without credit
declaring bankruptcy again every month, each forcing a full 5000-province
budget pass for the top bar (desktop: 4.5 s a month by 1600). Fixed, and the
economy made incremental (per-province figures kept until a province
changes; budgets re-added from them), plus: the ownable-province list built
once; colonisation caches cleared only for the countries involved; one-pass
yearly AI policy check; map palette, country names, panels and the top bar
refreshed once per frame instead of per ownership change; per-country
alliance/marriage index and a reason-free `Diplomacy.opinion()`; AI
building tries provinces richest first and remembers ones with nothing left;
monthly systems spread over days 1–4 (one frame each, same order and
outcome). Desktop now ≈60–90 ms of work a month, flat over 40 years (spikes
≈100 ms when colonies complete; ≈100–150 ms on 1 January for the autosave).

**Wartime (M7, 19 Oct 2026):** with armies and AI wars, months rose to a
median ≈260 ms (p90 ≈425, worst ≈550) on desktop. Now median ≈112 ms (p90
≈147, worst ≈225) over six years, without changing outcomes: an index of who
fights whom (`Military.war_index`, `at_war`, `wars_of` — `add_war` /
`remove_war` keep it right); war score, held land and treaty costs for every
war from one province pass (`MilitarySystem.war_stats`); AI targets for every
war in one pass a week; route search with each road's distance and ground
cached and access asked once per province a search (same routes as before,
≈2× faster); AI armies remember targets they could not reach for 120 days and
try the next nearest (before, they retried the same one forever); the map's
army tokens placed once a frame, touching only what changed, forts and docks
only when the camera moves. Each new campaign has a fresh seed, so profile
runs play different histories — compare medians, not months.

Profile a campaign headlessly, per month and per system (daily systems summed
over the month; "other" = daily listeners such as the map's tokens):
`godot --headless --path . --script res://tools/profile/campaign_profile.gd -- --play=ENG --years=12`

`tools/profile_zoom.gd`: static frames 0.5–0.9 ms; continuous zoom ~3.8 ms
avg (~11 ms worst); panning at zoom 3 ~4.8 ms; 177–514 draw calls. The big
past wins: tiled/streamed rivers and scenery, river width hysteresis, 2D
province names instead of Label3D, glyph prewarm. Map shader does 4–13 texel
fetches + palette lookups per pixel (+1 stripes lookup) — watch on device.

Saves: ~170 KB; save ≈ 39 ms, load ≈ 60 ms on desktop (the semantic check of
5000 rows dominated until its diagnostics were made lazy). Autosave runs on
the main thread once per game year — at speed 5 that is every ~6 s, so measure
the hitch on the Flip6; if noticeable, move stringify + write + check onto a
WorkerThreadPool task (snapshot `Campaign.to_dict()` on the main thread first,
and use a separate SaveService instance).

---

## 9. Known issues and open items

* ~447 provinces (9 %) still have compass/numbered names ("Bavaria IV",
  "Lower Saxony XI"): Natural Earth lacks small towns. Fix proposed to the
  user, not yet approved: GeoNames `cities1000` (~10 MB, CC-BY → needs an
  attribution line). Ask before downloading.
* Names are modern in places (Natural Earth places and divisions), with only
  partial historical renaming; uncolonised Americas use modern state names.
* Siberian tundra wastes (Taymyr, Kolyma lowlands) still echo Natural Earth's
  coarse rounded outlines; user hasn't commented since the noise fix. Option:
  drop tundra wastes.
* Some long thin corridor provinces (e.g. "Ouargla", "Tamanghasset" strung
  along Saharan roads).
* Minor ownership oddities possible (e.g. "Bukidnon" in Mindanao shows as
  Spanish). Check against history when touching `RULES`.
* Country names are straight; elongated blocks get their name along the
  principal axis (≤ 62° tilt), not curved Paradox-style. Names that would
  overlap move to a nearby spot on their own land or shrink; otherwise the
  less important one hides while the other is shown (`_update_label_blockers`,
  ~17 ms per rebuild on desktop, run at startup, on load, on ownership change).
* Not yet tested on the physical phone (performance, touch, back button,
  autosave on backgrounding).
* Country names are tappable only where their label is drawn (world and
  region zoom); at province zoom use the owner link in the province panel.
* Province panel has debug-only "Annex" / "Occupy" buttons (debug builds).
* Some 1590 details still coarse around France: Charolais (Habsburg-held
  under French suzerainty) and Orange are French; Cambrai is Spanish (held by
  Balagny for the League until 1595); Strasbourg/Lower Alsace shows Austrian;
  the Three Bishoprics (Metz, Toul, Verdun — French since 1552) sit inside
  Lorraine's provinces; Nassau-Saarbrücken shows as the Palatinate. Fixing
  the bishoprics needs extra seeds (`FORCED_POINTS`) so they get provinces.
* Province shapes are sometimes coarser than 1590 borders: the Bohuslän
  province also takes in Trollhättan on the Göta älv.
* `heightmap.res` G channel (raster rivers) is unused since vector rivers.
* The map's relief shading is still synthetic (Natural Earth ranges + noise);
  ETOPO1 is now available, so a real-elevation relief would be a natural next
  step.
* Wetlands are rare (17 provinces): Natural Earth maps few marshes.
* Population oddities seen while calibrating land: the "Rome" province has
  ~0.2 people/km², Hokkaidō ~52/km² (Japan's zone share) — farmland follows
  density, so these affect vegetation too.
* Land uses the old broad `terrain` only internally (population weights);
  colonisation rules are still to be written.

---

## 10. Next steps (from PLAN.md)

* **Colonisation balance (AI century from 1590, economy + diplomacy +
  colonisation, 16 Oct 2026):** by 1700 500 of 1085 free provinces settled —
  Siberia 61/63 (Russia 57, the Pacific by ~1640 as in history), North
  America 171/245 (faster than history: worth slowing), South America 48/162,
  Africa 117/324 (all by African states; **no outsider in the tropical
  interior**), Australia/NZ 5, New Guinea 0. Korea expands into Manchuria
  because the Jurchens have no polity in the 1590 data (add Nurhaci's
  Jianzhou Jurchens). Big treasuries pile up without armies (Russia ~39,000
  by 1650).
* **Colonisation follow-ups:** technology (M9) replaces the calendar in
  `Colonisation.MEDICINE`; colonial value in the AI's choice of land; native
  states resisting; migration growing colonies.
* **Diplomacy follow-ups:** an inbox so AI countries can propose to the player;
  war declaration and war aims with armies (M7); personal unions from
  succession (M8).
* **War follow-ups:** transports over open sea (armies now cross one sea zone
  their fleet holds), AI navies at sea, air power (aircraft are catalogued),
  war aims beyond occupied land, fronts for 20th-century war; AI fiscal sense
  (raising taxes in deficit, so fewer AI bankruptcies).
* **Milestone 8 — 1590-era politics** (PLAN.md).
* **Economy follow-ups:** trade and pop demand → market prices (user: later,
  Victoria-3 style); population growth; balance — the Ming Empire nets
  ~+1,670 a month at the start (a third of the world's people; administration
  costs only 0.25 per province), England ~+40, 179 of 238 countries in
  surplus; watch AI building over decades. Every money change needs a named
  source (tests). Store new campaign fields in `campaign_state()` and bump
  `SaveService.SCHEMA_VERSION` with an explicit `_migrate` step (never change
  the save layout silently).
* Measure on the Flip6 (shader, autosave hitch, menu/touch sizes) and act.
* Search for countries/provinces (brief §3.2) once navigation needs it.

---

## 11. Gotchas learned the hard way

* **Map lettering (Label3D, one MSDF atlas):** a glyph rendered *after* names
  are laid out grows the shared distance-field atlas and garbles the names
  already built (letters swapped: "MINE EMPIRE" for MING). `MapOverlay3D.
  _prewarm_glyphs()` renders every character a name can use — all names in both
  cases, ASCII and Latin-1/Extended-A, punctuation — *before* any label is
  built, and again (only new letters) before names are rebuilt when a country
  is founded or a save restored. Any new kind of map text must have its
  characters covered there (20 Oct 2026: the colonial nations' names tipped
  the atlas over; it had only been prewarmed after the labels were built).
* **World load order:** scenario → pops → claims → colonial nations
  (`Overseas.update`) → forces (`Military.populate`), so realms' armies and
  fleets match the land they govern (Portugal's navy is no longer sized by
  Brazil's and India's coasts).
* **Shell:** in this Bash tool, Python heredocs mangle backslashes/quotes —
  write patch scripts to the scratchpad with the Write tool and run them.
* **GDScript:** `:=` can't infer types from untyped array elements (`DX[k]`,
  dictionary values) → use explicit `var n: int = …`. Dictionary `==` compares
  *contents* (don't use it, or `Array.find`, to identify dicts — use an index
  field). Packed arrays inside Arrays/Dictionaries are modified in place.
* Run `--import` after adding a `class_name` script or headless runs can't see it.
* A parse error in one core class (e.g. `WorldState`) shows up as dozens of
  "Could not resolve external class member" errors elsewhere; check the class
  alone with `--check-only --script res://path.gd` to see the real one.
  Multi-line lambdas inside a parenthesised `if not (...)` condition don't
  parse reliably — move the check into a helper function.
* `EconomySystem` keeps each province's figures until `touch(p)` (its owner,
  unrest, buildings, resource or people changed) and budgets until
  `changed()` (anything country-level: policies, loans, goodwill, inflation,
  subjects, colonies); `invalidate()` drops everything (restores, tests that
  edit fields by hand). The economy calls these for its own changes and
  listens to ownership, control, subjects and restores; the game calls
  `changed()` after policy changes. A stale cache shows as a budget that
  ignores a change. Caches are replaced with *new* dictionaries, never
  `clear()`ed: the month's accounts walk the budgets while borrowing changes
  them (clearing once silently skipped the month for every country after the
  first borrower — `test_every_country_keeps_its_accounts_when_one_borrows`).
* `snappedf(x, 0.01)` can give 3.2600000000000002, which JSON (16 digits)
  saves as 3.26 — a round trip changes it. Use `EconomySystem.decimal(x)`
  (`roundf(x * 100) / 100`, the double nearest the decimal) for saved values.
* The Mobile renderer can't project shadows onto a transparent layer → blob shadows.
* MSDF outlines wider than half `msdf_pixel_range` produce dotted artifacts.
* Label3D text changes are expensive (~0.5 ms each) → names are drawn in 2D.
* Label3D draws each glyph (and its outline) as its own quad: translucent
  outlines of neighbouring letters overlap and stack into blotches (the user
  noticed). Use opaque colours — `_label_colors()` pre-mixes the old
  translucent look against the ground the name sits on.
* Line2D width changes re-tessellate → widths change in steps, only near view.
* Debug screenshots wait 40 frames so streamed tiles appear.
* JSON numbers load as floats — cast with `int()`. 64-bit values (RNG state)
  must be saved as strings.
* `SceneTree._initialize` runs before the root enters the tree: nodes added
  there get `_ready` only later (the test runner awaits a frame first).
* A GDScript runtime error aborts the current function and the caller carries
  on — tests need the runner's Logger to notice.
* `RULES` now shape geometry too: division merging asks who held each
  division's centre in 1590, so a rule change can move provinces. After any
  regeneration compare md5 of `province_ids.res` and `provinces.json` with the
  previous run; if they changed, bump `DATA_VERSION` (old saves are then
  refused with a clear message instead of loading onto the wrong provinces).
  Country colours in `countries.json` are re-picked on every run.

---

## 12. Short history of this work

1. Plan written (`PLAN.md`), Godot foundation, clock, fictional test map, 2D
   map + transparent 3D layer (oblique shear, blob shadows).
2. Replaced with the real 1590 world, 5000 provinces by quota; wrap-around map.
3. Wastelands; provinces rebuilt on real admin-1 divisions with river/mountain
   borders and real names; accessibility guaranteed.
4. Crisp rendering: smooth shader borders, MSDF labels, physical-resolution 3D
   layer, LOD with hysteresis; vector rivers.
5. Sahara corridors, Nile to Sudan, populous Egypt.
6. Performance: view-dependent tiles, 2D names (60 ms → 4 ms per zoom frame).
7. Sea tiles; settled-division ownership fix (Shandong); map extended to
   76°N–62°S; 1590 Aral and Zuiderzee; geography-only Arctic wastes;
   Biskra–Arak road; Shantou back to Ming.
8. Milestones 2 and 3: campaign state + atomic versioned saves, GameRandom,
   country panel and selection, occupation stripes, title / in-game / load
   menus, choose-your-country, scheduler with budgeted jobs, autosave, Android
   back button; test runner catches script errors; headless flow test.
   Landscape lock (user). France 1590 fix: Spanish claims cut back to
   Franche-Comté and Artois/Flanders (Burgundy, Champagne, Picardy French;
   Genevois Savoyard; Upper Alsace Habsburg, Saint-Dié Lorraine). Division
   merging no longer crosses 1590 polities (user spotted Sweden on Norway's
   Atlantic coast: Nordland/Troms had been merged into Norrbotten and
   Västerbotten); Bohuslän seeded apart from Gothenburg. DATA_VERSION 4.
9. Milestones 4 and 5: diplomacy (subjects, alliances, marriages, rivals,
   gifts, insults; Iberian Union; Japan 1590; vassal colour shades) and the
   economy — v1 (tax, budget, ledger, loans), then v2 at the user's request:
   estates, goods from real 1590 sites, discoveries by age (gold rushes, oil,
   rare earths, uranium), buildings and manufactories, proportional estate
   taxes with % sliders (clergy exempt), court, minting and inflation, fort
   maintenance, loans panel and bankruptcy; Goods map. Save format 5.
10. Colonisation (M6), provinces redrawn (data version 7), the era soundtrack,
    map-mode labels and groups, economy caching (16 Oct 2026).
11. Milestone 7 (armies, navies, levies, war and peace, forts on the map, army
    selection and merging), spending policies as percent sliders, sized gifts,
    thinner populations on tribal land (19 Oct 2026). Save format 7. Then the
    Military tab, manpower, mobilisation by order only, daily-rationed AI war
    planning, no diplomacy with an enemy, and peace treaties (land, reparations,
    forts) on their own screen; docks (fleets berth, ships built there);
    additive box selection (until an order, armies or fleets — armies first)
    with a clear button; wartime months ≈2–3× faster.
12. The user's war batch (20 Oct 2026): peace as a map tool with vassalage,
    subjects, alliances and separate peace (rules: leader with leader ends
    the war, a leader with anyone else takes that one out), war icons under
    the top bar and a war panel with forces, cores and claims, transports,
    vassal loyalty, retreats (a distance that shrinks as the army's
    technology develops — `MilitarySystem.retreat_steps`, the age of its
    units standing in until M9: 5/4/3/2 provinces; after a brief pause-menu
    setting the user rejected), mobilisation
    by region, a bigger top bar without zoom buttons (our name frames our
    home), red war badges centred under it, province/army/fleet panels on the
    left; tiny islands drawn by the generator from their real islets (the
    Maldives as their chain of atolls; `_enlarge_islands`, only the drawing
    changes) with taps in the sea near one snapping to it, and map
    fingerprints kept compatible across redraws (`compatible_id_textures`:
    the original fe80651b… and the interim drawing). Save format 8.
13. Overseas and colonial nations (20 Oct 2026): colonial regions, the
    overseas rule, colonial nations founded at three provinces (the 1590
    viceroyalties and Portugal's three at the start), the "colony" subject
    type, countries founded during a campaign saved as `created` in the
    world state (older saves: none; the colonial nations form at their first
    month), the Colonial regions map mode.
14. Land deals (20 Oct 2026): buying, selling and exchanging land, judged by
    named reasons, picked on the map. (README.md had a UTF-16 "# sovereignty"
    line appended by GitHub's quick-setup echo in PowerShell — removed.)
