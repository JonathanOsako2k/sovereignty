# Sovereignty: A Mobile Grand-Strategy Game

## Project README, Design Brief and Technical Implementation Plan

**Working title:** # Sovereignty\
**Target platform:** Android first\
**Primary device target:** Samsung Galaxy Z Flip6-class phone\
**Preferred initial technology:** Godot\
**Genre:** Historical grand strategy, political simulation, economic
management and warfare\
**Campaign period:** 1590--1949\
**Design goal:** A deep, evolving grand-strategy simulation that remains
responsive, readable and battery-conscious on a modern phone.

> **Status:** This document defines the intended game and a practical
> implementation plan. It is not a claim that the game has already been
> implemented. Treat the milestones below as the build order, and keep
> the first playable version deliberately small.

------------------------------------------------------------------------

# 1. Vision

Create a mobile-first grand-strategy game in which the player guides a
state, dynasty, republic or emerging national movement through the
political and economic transformations of 1590--1945.

The game should evoke the satisfying strategic scale of classic
grand-strategy titles: a detailed political map, provinces that matter,
economic and demographic pressures, diplomacy, wars, internal politics
and long-term consequences. It must be designed around touch interaction
and phone-sized screens rather than simply shrinking a desktop
interface.

The period is important. A state in 1590 should not feel like a modern
nation-state with muskets. Political authority, armies, finance,
transport, economic production and popular identity should change over
time. The player should experience those transformations through the
simulation rather than by switching between disconnected era scenarios.

## 1.1 Core principles

1.  **One continuous campaign:** The world evolves from 1590 to 1945.
    There are no mandatory resets between eras.
2.  **History creates pressures, not scripts:** Historical events and
    institutions provide context and possible developments, but player
    actions and simulation outcomes can create alternate histories.
3.  **Provinces are the strategic foundation:** Provinces have
    ownership, control, population, production, infrastructure and local
    conditions.
4.  **Ownership is not control:** A country can legally own territory it
    does not currently occupy or effectively administer.
5.  **Institutions evolve:** States can centralise, decentralise,
    reform, stagnate, industrialise, democratise, become revolutionary
    or take other paths.
6.  **Readable on a phone:** Every major action should be reachable by
    touch, with concise summaries and optional detail.
7.  **Simulation before spectacle:** Prioritise strategic clarity, a
    responsive map and interesting decisions over expensive visual
    effects.
8.  **Offline-first:** The core game should run without a network
    connection.
9.  **Data-driven design:** Countries, provinces, goods, laws,
    technologies and events should be represented as data wherever
    practical, not hard-coded into UI screens.
10. **Performance is a design constraint:** The simulation must scale
    deliberately. It should not perform a full recalculation of the
    entire world every rendered frame.

------------------------------------------------------------------------

# 2. Campaign and historical progression

## 2.1 Starting date and end date

-   **Start:** 1590
-   **End:** 1949
-   **Default victory/ending:** The campaign concludes at the end of
    1949, with a final assessment of the player's state, its people,
    territory, economy, institutions and international position.
-   **Optional campaign lengths:** Later versions may support alternate
    start dates or scenario objectives. Do not build multiple start
    dates before the main campaign works.

The player should be able to pause, run time at different speeds,
inspect the world and make decisions while paused. Time controls should
be prominent and touch-friendly.

## 2.2 Era I --- Dynastic and provincial politics (1590--1699)

Main themes: - Dynastic legitimacy, royal marriage, succession and
inheritance. - Personal unions, claims, disputed succession and noble
influence. - Provincial privileges, estates, local autonomy and uneven
administration. - Early colonial ventures, maritime trade and overseas
possessions. - Pike-and-shot warfare, arquebuses, artillery,
fortifications and mercenary forces. - State finance based on land,
customs, monopolies, loans and negotiated taxation. - Early attempts to
centralise administration.

Design intent: The state is not yet an all-powerful modern bureaucracy.
Local elites, corporate privileges, dynastic ties and regional
institutions can meaningfully constrain the ruler.

## 2.3 Era II --- Fiscal-military states and centralisation (1700--1788)

Main themes: - Permanent armies and more regular taxation. - Improved
administrative reach, record-keeping and state borrowing. - Professional
officer corps and military reforms. - Great-power rivalry, colonial
competition and naval power. - Growing state capacity, but also debt,
corruption and resistance. - Enlightenment-era political and
administrative ideas.

Design intent: A state may become stronger by centralising, but doing so
costs money and can provoke resistance. A decentralised state may be
flexible or prosperous, but struggle to mobilise resources quickly.

## 2.4 Era III --- Revolution and constitutional transformation (1789--1847)

Main themes: - Revolutions, constitutionalism, republicanism and
political legitimacy. - Popular mobilisation, mass conscription and
national identity. - Reform, reaction, civil conflict and
counter-revolution. - Changes to property rights, privileges and
taxation. - National movements and the restructuring of old dynastic
orders.

Design intent: Revolutionary change should be a strategic problem, not
merely a random event. The player can reform before a crisis,
accommodate demands, suppress a movement or embrace revolutionary
transformation. Each route has consequences.

## 2.5 Era IV --- Industrialisation and mass politics (1848--1913)

Main themes: - Mechanised industry, railways, coal, steel and expanding
markets. - Urbanisation and changes in population distribution. - New
social classes, labour organisation and political movements. - National
unification and the formation or dissolution of states. - Modern
bureaucracy, mass education, conscription and public infrastructure. -
New ideologies, philosophies and art movements as cultural and political
context. - Imperial expansion and competition for markets, resources and
influence.

Design intent: Industrialisation should change the sources of state
power. Population, literacy, transport, capital, energy and institutions
become increasingly important. A country that industrialises early can
gain advantages, but may also face urban unrest, inequality, pollution
and political demands.

## 2.6 Era V --- Industrial warfare and total war (1914--1945)

Main themes: - Large standing armies, mechanised forces and industrial
weapons. - Rail, road, shipping, fuel and ammunition logistics. -
Economic mobilisation, rationing, borrowing and war production. - Mass
politics, propaganda, ideological conflict and expanded state
intervention. - Civilian losses, disruption, debt, inflation and
post-war instability. - The interaction between military power,
industrial capacity and supply lines.

Design intent: Armies should not fight effectively just because a
country can afford to recruit them. They need equipment, supply,
transport, fuel where relevant, trained personnel and a functioning
command structure. Total war can destroy the economic and demographic
base that sustains it.

**Important:** The period 1590--1945 contains many different political
and military systems. Do not model every century with the same army
template, economy or government interface. Use evolving rules, available
institutions and technology unlocks while keeping a common underlying
simulation.

------------------------------------------------------------------------

# 3. Player experience and interface

## 3.1 Main screen

The main screen should be map-first, with a compact strategic status bar
and a small number of contextual panels.

Suggested layout: - **Top bar:** Date, treasury, income/expenses,
stability or legitimacy, alerts and pause/speed controls. - **Main
map:** Political map by default, with pan, zoom, tap-to-select and
visual highlighting. - **Bottom action bar:** Map modes, diplomacy,
economy, military, government and journal/objectives. - **Context
drawer:** Opens when the player selects a province, country, army or
fleet. It should be dismissible and should not permanently obscure the
map. - **Alerts:** Important events such as a succession crisis,
rebellion, bankruptcy risk, army attrition or an unfulfilled peace
demand. - **Pause and speed:** Time should never advance unexpectedly
while the player is inspecting a major decision or entering text.

The UI must work in portrait and landscape orientations if practical.
The folded phone's narrow screen should be treated as a real constraint,
not an afterthought. Landscape can be the recommended strategic mode,
while portrait should remain usable for inspection and management
screens where possible.

## 3.2 Touch and navigation requirements

-   Tap a province to select it.
-   Tap a country label or country summary to open its information
    panel.
-   Pinch to zoom; drag to pan.
-   Provide visible zoom-in, zoom-out and recenter controls as an
    accessibility alternative.
-   Use a clear selection outline that remains visible at multiple zoom
    levels.
-   Make buttons large enough for fingers; avoid tiny desktop-style
    controls.
-   Do not rely on hover states.
-   Use short labels with explanatory detail available on demand.
-   Keep critical actions separated from destructive actions.
-   Confirm expensive or irreversible actions such as declaring war,
    dismissing a government or accepting a major peace settlement.
-   Preserve the current map position and zoom when opening and closing
    a panel.
-   Provide a search function for countries and provinces once the map
    contains enough entries that manual navigation becomes cumbersome.
-   Ensure UI text scales with Android font/display settings without
    clipping.

## 3.3 Map modes

Initial map modes: 1. **Political:** Countries coloured by sovereign
ownership. 2. **Control:** Current military or administrative control,
separate from ownership. 3. **Terrain:** Broad terrain classes that
affect movement, supply and combat. 4. **Population:** Population
density or population totals. 5. **Economy:** Major production,
development or economic output. 6. **Infrastructure:** Roads, railways,
ports and other transport links, depending on era. 7. **Unrest:** Local
unrest, separatism or rebellion risk. 8. **Supply:** Whether military
units can be supplied and where bottlenecks exist.

Do not implement all map modes at once. Political and control modes are
sufficient for the first playable version. Other modes can reuse the
same map geometry and change its colours or overlays.

## 3.4 Information density

The game can be deep without placing every number on the screen at once.

Use progressive disclosure: - **Overview:** The most important three to
six facts. - **Details:** Expandable lists, charts and breakdowns. -
**Advanced:** Modifiers, historical changes and formula explanations.

For example, a province summary might show population, owner,
controller, tax contribution, dominant production and unrest. Detailed
demographics, infrastructure levels, local laws and production modifiers
can be in a secondary tab.

------------------------------------------------------------------------

# 4. Core world model

## 4.1 Province

A province is the main territorial simulation unit. Each province should
have a stable ID that does not depend on its current owner or its
display name.

Minimum fields: - `id` - `name` - `region_id` - `owner_country_id` -
`controller_country_id` - `population` - `terrain_type` -
`development_level` or equivalent economic capacity -
`infrastructure_level` - `unrest` - `tax_base` - `production_profile` -
`fortification_level` - `is_coastal` - `neighbour_ids` -
`map_geometry_reference`

Later fields may include literacy, urbanisation, culture, religion where
relevant to the chosen design, disease/environmental pressures, local
privileges, resource deposits, buildings and supply capacity.

Avoid putting the entire simulation state inside a map-rendering object.
The map should display world data; it should not own the authoritative
version of that data.

## 4.2 Country

Minimum fields: - `id` - `name` - `government_type` -
`capital_province_id` - `owned_province_ids` - `treasury` - `debt` -
`monthly_income` - `monthly_expenses` - `legitimacy` or a
period-appropriate equivalent - `stability` - `centralisation` -
`administrative_capacity` - `technology_levels` -
`diplomatic_relations` - `laws_and_institutions` - `military_forces` -
`active_wars` - `succession_state` where relevant -
`national_or_dynastic_identity`

Use stable IDs for relationships. Avoid storing the same fact in many
places unless the consistency rules are explicit. For example, province
ownership should have one authoritative representation, with country
province lists either derived or maintained through a controlled
transfer function.

## 4.3 Population

Population is strategically important, but simulating every individual
is out of scope. Use aggregated population groups.

A group can represent a combination of: - province or region; - social
class or economic role; - broad cultural/political identity where
relevant; - employment sector; - literacy or education band; - wealth or
living-standard band.

For the first version, population can be aggregated at province level
with a few economic classes. Add more detailed population groups only
when the game can handle them efficiently.

Population should influence: - tax capacity; - available recruits; -
demand for goods; - production and labour supply; - urbanisation; -
unrest and political movements; - migration and demographic change; -
the human cost of war.

Avoid recalculating every demographic detail daily. Population growth,
migration and class changes can be updated monthly or annually, with
only the most important effects applied at other times.

## 4.4 Ownership, control and administration

Keep three concepts separate:

-   **Ownership:** The state that legally claims or owns the province.
-   **Control:** The power currently exercising military control,
    particularly during war.
-   **Administrative reach:** How effectively the state can tax,
    recruit, enforce laws and deliver services there.

These values can differ. An occupied province can remain legally owned
by one country while being controlled by another. A remote province may
be owned and controlled by its state but contribute little revenue
because administration and infrastructure are weak.

This distinction should be reflected in taxation, recruitment,
resistance, peace treaties and post-war recovery.

------------------------------------------------------------------------

# 5. Simulation architecture

## 5.1 Principle: simulation independent of rendering

Keep game rules separate from Flutter widgets and canvas painting. The
same simulation should be testable without opening the UI.

Recommended conceptual layers:

1.  **Domain model:** Provinces, countries, populations, armies, laws,
    goods and events.
2.  **Simulation systems:** Economy, population, diplomacy, war,
    technology, succession and politics.
3.  **Simulation scheduler:** Runs each system on its appropriate
    game-time schedule.
4.  **Game state:** Authoritative current world state and campaign date.
5.  **Persistence:** Saves and loads state.
6.  **Presentation model:** Summaries and view-ready values for the UI.
7.  **Rendering and UI:** Flutter widgets and the political map painter.

Avoid placing simulation rules directly in `build()` methods or paint
callbacks. Flutter may repaint frequently; painting must not mutate the
world.

## 5.2 Time and ticks

Use discrete simulation ticks. The player can advance time at several
speeds, but the simulation itself should update according to game time
rather than frame rate.

Suggested initial schedule: - **Daily:** Only essential military
movement or battle countdowns, if required. - **Weekly:** Military
supply checks, active battles and short-term fronts where necessary. -
**Monthly:** Taxation, recurring expenses, debt interest, production,
consumption, unrest updates and routine diplomacy. - **Quarterly:**
Trade balancing, selected market calculations and political trend
updates. - **Annually:** Population growth, demographic changes,
technology progress and long-term institutional changes.

These are starting points, not immutable rules. Keep each system's
update frequency configurable. Do not run all systems every day merely
because the game has a calendar.

Use a deterministic scheduler where practical. Given the same saved
state, player actions and random seed, the simulation should produce the
same outcome. Determinism improves debugging, reproducibility and
save/load testing.

## 5.3 Pause, speed and backgrounding

-   Paused means no simulation time advances.
-   Speed levels determine how quickly game-time ticks are processed.
-   The simulation should process a bounded amount of work per frame so
    that a large tick does not freeze the interface.
-   If the app is backgrounded, do not assume it will remain alive. Save
    safely and resume from the last committed state.
-   Decide explicitly whether offline time advances the world. For the
    first release, **do not advance the simulation while the app is
    closed**. This simplifies balancing, battery use and save
    reliability.
-   Autosave at safe checkpoints, not continuously after every tiny
    state change.

## 5.4 Event and modifier system

Use data-driven events for situations such as: - a succession crisis; -
a demand for constitutional reform; - a provincial rebellion; - a
technological breakthrough; - a financial panic; - a war exhaustion
threshold; - a national unification opportunity.

An event should have: - a stable ID; - trigger conditions; - optional
historical date or date range; - choices; - effects; - AI choice
rules; - localisation keys; - a unique or repeatable policy.

Historical dates should not force outcomes if the world state makes them
implausible. Prefer conditional events over a chain of unconditional
scripted outcomes.

------------------------------------------------------------------------

# 6. Economy

The economic simulation should be strategically meaningful but
computationally affordable.

## 6.1 First economic model

Begin with a simplified state economy: - provinces produce a small
number of goods or abstract output; - population provides labour and
demand; - the country collects taxes; - the state pays for
administration and armed forces; - infrastructure improves production
and movement; - war disrupts production and increases expenditure; -
debt can finance spending but creates interest obligations.

Do not start with a fully simulated global market containing hundreds of
goods. Prove that the core loop works first.

## 6.2 Suggested first resources

Initial abstract resources: - food; - raw materials; - manufactured
goods; - luxury goods; - military supplies.

Later eras can add more specific resources, such as grain, timber, iron,
coal, textiles, steel, oil, ammunition and machinery. Resource
availability and strategic importance should change over time.

## 6.3 State finances

Monthly budget categories: - tax revenue; - customs or trade revenue
where appropriate; - other income; - administration; - army and navy; -
infrastructure investment; - interest payments; - subsidies or special
projects; - war expenditure.

A simplified budget formula is acceptable for the prototype. The
important thing is that revenue has a clear source, costs have a clear
purpose, and the player can inspect the budget breakdown.

Avoid a system where money appears without explanation or where the only
economic decision is adjusting a single tax slider.

## 6.4 Industrialisation

Industrialisation should be a process rather than a single technology
unlock.

Potential prerequisites and modifiers: - access to resources; -
transport infrastructure; - capital or state investment; - labour
supply; - literacy and technical education; - market access; - political
and legal institutions; - technology; - stability and security.

Potential consequences: - increased output and state revenue; - urban
growth and migration; - changes in employment and class structure; -
greater demand for transport, fuel and raw materials; - labour conflict
and new political movements; - stronger military production; - pollution
or other external costs if the game models them.

The player should face meaningful trade-offs rather than receiving only
positive bonuses.

------------------------------------------------------------------------

# 7. Government, legitimacy and political change

## 7.1 Government is more than a label

Represent governments through a combination of institutions and
constraints, such as: - who selects or replaces the executive; - how
succession works; - how laws are enacted; - how taxation is
authorised; - the role of aristocratic, provincial, religious,
commercial or popular bodies; - the state's ability to enforce
decisions; - the extent of political participation; - the relationship
between central and local authority.

The available institutions should evolve with the campaign. Do not treat
a 1590 monarchy and a 1930 parliamentary state as identical objects with
different names.

## 7.2 Legitimacy and stability

Use period-appropriate sources of legitimacy. Depending on the state and
era, these may include dynastic succession, elite consent,
constitutional procedure, military success, national identity or popular
support.

Stability should reflect pressures such as: - war exhaustion; - fiscal
crisis; - succession disputes; - inequality and hardship; - unfulfilled
political demands; - repression; - regional or national movements; -
government legitimacy; - administrative effectiveness.

Avoid a single universal unrest formula that makes every country react
identically. Use shared mechanics with country-specific modifiers and
institutions.

## 7.3 Reform and revolution

Political change should offer several viable paths: - gradual reform; -
negotiated constitutional change; - centralisation; - decentralisation
or federal arrangements; - repression; - revolutionary transformation; -
reactionary restoration.

Each path should have benefits, costs and risks. Reforms can reduce
immediate pressure but upset powerful groups. Repression can suppress
mobilisation temporarily but increase long-term hostility. Revolution
can remove entrenched constraints but destabilise administration,
property arrangements and the armed forces.

------------------------------------------------------------------------

# 8. Diplomacy and warfare

## 8.1 Diplomacy

Initial diplomacy features: - relations between countries; -
alliances; - truces; - claims or territorial demands; - diplomatic
actions with costs and consequences; - war declarations; - peace
negotiations; - subject relationships where relevant.

Later features may include guarantees, coalitions, spheres of influence,
international organisations and more complex diplomatic blocs.

Diplomatic AI should be goal-driven and understandable. It should
consider threat, relative strength, alliances, claims, geography,
economic position and current commitments. Avoid giving the AI hidden
bonuses that the player cannot inspect.

## 8.2 Armies

An army should not be a single number representing all military
capability. At minimum, consider: - manpower or personnel; -
equipment; - organisation or readiness; - supply; - commander or
leadership quality; - movement speed; - terrain; - fortifications; -
technology and doctrine; - morale; - attrition.

The detail can increase over time. Early armies may rely on
pike-and-shot formations and artillery; later armies depend increasingly
on industrial production, rail transport, ammunition, fuel,
communications and large-scale logistics.

## 8.3 Movement and pathfinding

Use the province adjacency graph for movement. Each province references
neighbouring provinces, and a pathfinding algorithm calculates routes
using costs influenced by terrain, infrastructure, hostile control and
supply.

Do not use visual map pixels as the authoritative movement graph.

For the first prototype: - armies move between adjacent provinces; -
movement duration is based on terrain and infrastructure; - hostile
provinces may require combat or occupation; - an army can lose strength
or readiness if unsupplied.

Implement more advanced fronts, multi-army coordination and operational
warfare only after the basic system works.

## 8.4 Battles

A prototype battle resolution can use: - personnel; - equipment; -
organisation; - commander; - terrain; - fortifications; - supply; -
technology; - randomness with a controlled range.

Combat should not be purely random or decided by army size alone.
Present a pre-battle estimate with the major factors so that the result
is legible to the player.

## 8.5 War aims and peace

A war needs a reason and an end condition. War aims may include
territorial claims, independence, dynastic claims, regime change or
other objectives depending on era and context.

Peace terms should account for: - occupied territory; - relative war
progress; - casualties and exhaustion; - war aims; - diplomatic
position; - the willingness of each side to continue.

Do not implement a perfect diplomatic peace AI in the first milestone. A
basic war declaration, occupation, battle and peace settlement loop is
enough to validate the concept.

------------------------------------------------------------------------

# 9. Map technology and rendering

## 9.1 Recommended initial approach

Use Flutter for the application UI and a dedicated custom map-rendering
layer for the political map. The map renderer should be independent from
the simulation.

Represent provinces as stable IDs plus vector geometry or references to
preprocessed geometry. Each province should not require its own Flutter
widget. A map with thousands of provinces represented as thousands of
interactive widgets would create unnecessary overhead.

For the initial prototype, use a deliberately small map with a few
hundred provinces. Once interaction and performance are validated,
increase the map size.

## 9.2 Geometry options

Possible approaches: 1. **Preprocessed vector polygons:** Flexible for
selection and colour changes, but large complex paths can be expensive
to draw. 2. **Raster province-ID map:** Each pixel encodes a province
ID, making point selection simple; a separate image or vector layer
draws borders and labels. Resolution and scaling need careful treatment.
3. **Hybrid:** Raster IDs for hit testing, vector or raster layers for
visual borders and highlights.

Choose one approach after benchmarking a representative map. A hybrid
solution may be appropriate for a large world map, but it should not be
introduced prematurely.

## 9.3 Map interaction

The map layer should provide: - pan and zoom; - tap-to-select; -
selected-province highlighting; - political colouring; - a separate
control overlay; - optional borders and labels at suitable zoom
levels; - a way to locate a province by ID; - coordinate conversion
between screen and map space.

Hit testing should be efficient. Do not test every polygon against every
tap if a spatial index or province-ID raster can identify the candidate
quickly.

## 9.4 Labels and visual clarity

Labels should adapt to zoom: - low zoom: major countries or regions; -
medium zoom: country names and major provinces; - high zoom: local
province names and relevant terrain or city labels.

Prevent labels from overwhelming the map. Avoid rendering every province
label at every zoom level. Use collision avoidance or simple
prioritisation based on importance.

## 9.5 Asset and data size

-   Keep map geometry and static world data separate from save-game
    state.
-   Compress assets where useful.
-   Load large optional data lazily where practical.
-   Avoid embedding duplicate province geometry in each save.
-   Use stable data versioning so saves can identify the world-data
    version they depend on.

------------------------------------------------------------------------

# 10. Phone performance and memory budget

## 10.1 Target device

The initial target is a modern, reasonably capable Android phone such as
a Samsung Galaxy Z Flip6. The game must still be designed for variable
screen sizes, thermal conditions and available memory. Do not assume
every Android device has flagship performance.

The phone's processor is not a reason to simulate everything
continuously. Efficient scheduling, compact data and limited redraws
matter more than raw peak performance.

## 10.2 Performance goals

Treat the following as engineering targets to measure, not guarantees: -
**UI responsiveness:** Normal taps and panel changes should feel
immediate. - **Rendering:** Aim for smooth map interaction near the
display's normal refresh rate on the target device; a stable 60 FPS is a
sensible initial benchmark, not a requirement for every late-game
simulation step. - **Simulation:** A normal monthly tick should complete
without a noticeable freeze. If a tick is expensive, divide its work
into bounded chunks while keeping results deterministic. - **Memory:**
Avoid loading unnecessary duplicate copies of the world, map geometry
and save state. - **Battery and heat:** Do not run the simulation while
paused or when the app is backgrounded. Limit expensive animation and
unnecessary repainting. - **Late campaign:** Benchmark a dense,
late-game world with many armies, industrial provinces and active
wars---not only the quiet 1590 start.

A strategic game can remain enjoyable at a stable 30 FPS if necessary,
but map gestures and scrolling should still feel responsive. The
simulation must not block the main UI isolate for long periods.

## 10.3 Practical optimisation rules

1.  **Never simulate in the widget build path.**
2.  **Never update the whole world every rendered frame.**
3.  Use monthly, quarterly and annual schedules for systems that do not
    need daily updates.
4.  Use typed or compact data structures where profiling demonstrates a
    benefit.
5.  Avoid repeatedly allocating large temporary lists during map
    painting.
6.  Cache static map layers and province geometry.
7.  Redraw only when the map state or visible overlays change.
8.  Keep map hit testing separate from painting.
9.  Use isolates for suitable CPU-heavy work if profiling shows that the
    UI isolate is being blocked. Design message passing carefully;
    isolates do not automatically make every task faster.
10. Do not send the entire world state across an isolate boundary for
    every small calculation.
11. Avoid unnecessary animations and high-frequency timers.
12. Profile on a physical Android phone early and repeatedly.
13. Test with the phone both cool and warm; sustained performance can
    differ from short benchmarks.
14. Keep a reproducible stress-test save with many provinces, units and
    wars.
15. Measure before rewriting code for performance.

## 10.4 Suggested scale gates

Use progressive scale tests rather than assuming the final world will
work.

  -----------------------------------------------------------------------
  Gate                    Test world              Pass condition
  ----------------------- ----------------------- -----------------------
  A                       50--100 provinces       Map interaction and
                                                  basic simulation work

  B                       300--500 provinces      Political colouring,
                                                  selection and monthly
                                                  economy remain
                                                  responsive

  C                       1,000--2,000 provinces  Panning, zooming and
                                                  map modes remain
                                                  usable; no long UI
                                                  freezes

  D                       Full intended map       Late-game stress test
                                                  on physical device;
                                                  profiling identifies
                                                  acceptable bottlenecks
  -----------------------------------------------------------------------

These are testing milestones, not a promise that a particular province
count will perform identically on every phone. Geometry complexity,
number of units, number of population groups and algorithm design all
affect performance.

## 10.5 Foldable-screen considerations

-   Test both folded/narrow and unfolded/wide layouts.
-   Do not assume a single fixed aspect ratio.
-   Support layout changes without restarting the campaign.
-   Keep the map useful in narrow portrait mode, even if landscape is
    recommended for full strategic play.
-   Ensure bottom sheets and drawers do not cover the only way to select
    or deselect map objects.
-   Avoid placing critical buttons near Android gesture areas.
-   Test cutouts, system bars, keyboard appearance and display scaling.

------------------------------------------------------------------------

# 11. Technology stack

## 11.1 Initial recommendation

-   **Language:** Dart
-   **Application and UI:** Flutter
-   **Map rendering:** Custom Flutter canvas/rendering layer, selected
    after a prototype benchmark
-   **Persistence:** Local database or versioned structured save format;
    choose based on save size and query needs
-   **Build target:** Android
-   **Version control:** Git
-   **Testing:** Dart unit tests, simulation integration tests and
    physical-device performance tests
-   **Development style:** Small vertical slices, AI-assisted coding,
    review and test each change before adding more systems

Flutter is selected because this is an Android-first game with a
substantial management UI, and it allows the project to reuse
app-development skills. It is not the only viable choice. If map
rendering becomes the limiting factor, benchmark a specialised renderer
or a game engine before committing to a major rewrite.

## 11.2 Keep dependencies minimal

Do not add a large dependency for every small feature. Each package adds
maintenance, compatibility and build complexity. Prefer stable,
well-supported dependencies and keep the simulation itself in plain Dart
where possible.

Before adopting a map, database, pathfinding or rendering package: -
verify Android compatibility; - check current maintenance status; -
confirm licence compatibility; - benchmark with representative data; -
ensure the project can still be built offline once dependencies are
cached.

## 11.3 Suggested project structure

A starting structure could be:

``` text
lib/
  main.dart
  app/
    app.dart
    theme.dart
    routing.dart
  core/
    clock/
      game_clock.dart
      simulation_scheduler.dart
    persistence/
      save_service.dart
      save_migrations.dart
    random/
      game_random.dart
    diagnostics/
      performance_metrics.dart
  domain/
    models/
      province.dart
      country.dart
      army.dart
      population_group.dart
      war.dart
      treaty.dart
      event.dart
    world/
      world_state.dart
      world_loader.dart
      world_validation.dart
  simulation/
    simulation_engine.dart
    systems/
      economy_system.dart
      population_system.dart
      diplomacy_system.dart
      military_system.dart
      politics_system.dart
      technology_system.dart
    pathfinding/
      province_graph.dart
      pathfinder.dart
  map/
    map_view.dart
    map_controller.dart
    map_renderer.dart
    map_hit_test.dart
    map_geometry.dart
    map_layers.dart
    map_labels.dart
  features/
    dashboard/
    province_details/
    country_details/
    diplomacy/
    economy/
    military/
    government/
    journal/
    settings/
  data/
    definitions/
    scenarios/
test/
  domain/
  simulation/
  persistence/
  map/
  performance/
assets/
  maps/
  icons/
  fonts/
  localisation/
```

This is a proposed organisation, not a requirement to create every file
immediately. Create files as each milestone needs them. Keep one
authoritative owner for each part of the game state.

------------------------------------------------------------------------

# 12. Data, save files and reliability

## 12.1 Static definitions versus campaign state

Separate: - **Static world data:** province IDs, names, geometry,
terrain, adjacency, starting country definitions and historical data. -
**Campaign state:** current owners, controllers, finances, armies,
population, wars, laws, event flags and current date. - **Player
settings:** audio, display, map preferences, text size and other local
options.

A save should not duplicate all static map geometry if it can refer to a
compatible version of the world data.

## 12.2 Save requirements

The first release should support: - manual save; - autosave; - loading a
saved campaign; - safe handling of an interrupted or corrupt save; - a
visible save timestamp; - a schema/version number; - migration or a
clear compatibility error when formats change.

Use an atomic save strategy: write a new temporary save, validate it,
then replace the prior save only after the write succeeds. Keep at least
one recovery copy where storage permits.

## 12.3 Deterministic randomness

Use a game-owned random number generator with a saved seed or state. Do
not rely on unrelated global randomness for major simulation outcomes.
This makes bugs easier to reproduce and can reduce save/load
inconsistencies.

## 12.4 Validation

Validate world data on load: - every province ID is unique; - every
neighbour ID exists; - each country reference resolves; - each province
has a valid owner or explicitly allowed unowned status; - capital
references are valid; - map geometry references exist; - country
province lists agree with province ownership if both are stored; -
numeric values remain within reasonable ranges.

Fail with a useful diagnostic rather than silently corrupting the
campaign.

------------------------------------------------------------------------

# 13. AI-controlled countries

AI opponents should use understandable priorities, not an attempt to
predict every possible human action.

Initial AI priorities: - avoid bankruptcy where possible; - protect the
capital and core territory; - assess threats and alliances; - maintain a
viable army; - pursue simple claims or objectives; - accept peace when
the cost of continuing becomes too high; - avoid declaring wars it
cannot plausibly sustain.

Later AI can consider: - industrial and infrastructure investment; -
political reform; - national unification; - colonial strategy; - supply
and logistics; - ideological alignment; - long-term military planning.

Run AI decisions at defined intervals rather than every frame. Use
staged decision-making: first generate plausible candidate actions, then
score them. This is easier to inspect and optimise than a huge
collection of interdependent special cases.

Expose important AI modifiers in debug tools so that unreasonable
behaviour can be diagnosed.

------------------------------------------------------------------------

# 14. Scope control: what not to build first

Do **not** begin by implementing the entire 1590--1945 simulation.

Defer these features until the core loop is proven: - detailed
individual population simulation; - hundreds of goods with a fully
simulated global market; - sophisticated naval combat; - highly detailed
battle tactics; - complex colonial administration; - extensive character
simulation; - elaborate culture, religion and ideology systems; - full
historical event coverage; - multiplayer; - mod support; - cloud
saves; - online accounts; - cinematic 3D graphics; - complex
supply-chain simulation; - all historical governments and laws.

These may be valuable later, but implementing them all at once makes the
project hard to test and difficult for an AI coding assistant to
maintain.

------------------------------------------------------------------------

# 15. Development milestones

## Milestone 0 --- Project foundation

Deliverables: - Flutter project builds and runs on Android. - Git
repository is set up. - Basic app shell and orientation handling work. -
A simple test screen displays the campaign date. - A physical-device
build process is documented.

Acceptance criteria: - The app launches reliably on the target phone. -
UI scaling works in narrow and wide layouts. - The app does not require
a network connection to launch.

## Milestone 1 --- Small political map

Deliverables: - A test map with 50--100 provinces. - Province IDs and
adjacency data. - Political colours by country. - Pan, zoom and province
selection. - Province details panel. - A separate map controller and
renderer.

Acceptance criteria: - Tapping a province selects the correct ID. -
Selected highlighting remains correct while zooming and panning. -
Painting does not modify simulation state. - No province requires a
separate heavyweight widget. - Map interaction is tested on a physical
phone.

## Milestone 2 --- Countries, ownership and save/load

Deliverables: - Country definitions and starting ownership. - Ownership
transfer function. - Ownership and control map modes. - Basic campaign
state. - Manual save and load.

Acceptance criteria: - Transferring a province updates all relevant data
consistently. - Save/load restores the same world state. - Invalid IDs
produce a diagnostic. - Save format has a version number.

## Milestone 3 --- Calendar and time controls

Deliverables: - Campaign date begins in 1590. - Pause and speed
controls. - Monthly tick scheduler. - Safe app background/resume
behaviour. - Autosave at defined checkpoints.

Acceptance criteria: - Pausing prevents game-time advancement. -
Different speeds produce the expected number of ticks. - Closing and
reopening does not silently advance the campaign. - A long simulation
step does not permanently block UI input.

## Milestone 4 --- Basic economy

Deliverables: - Province output and tax base. - Country budget. -
Monthly income and expenses. - Basic army maintenance. - Budget
breakdown screen.

Acceptance criteria: - Money changes have traceable causes. - A country
can run a surplus or deficit. - The player can inspect the monthly
budget. - Tests cover taxes, maintenance and debt interest.

## Milestone 5 --- Armies and war

Deliverables: - Army units and province movement. - Pathfinding on the
adjacency graph. - Occupation and control. - Basic combat. - War
declaration and simple peace settlement.

Acceptance criteria: - Armies cannot move through nonexistent edges. -
Occupation changes control without automatically changing ownership. -
Supply or attrition has a visible effect. - War termination produces a
consistent result.

## Milestone 6 --- 1590-era political systems

Deliverables: - Dynastic succession and legitimacy. - Noble or
provincial privilege. - Early centralisation decisions. - A small number
of conditional events.

Acceptance criteria: - Succession can resolve differently depending on
state. - Local privilege can constrain central policy. - Events depend
on game conditions rather than firing blindly.

## Milestone 7 --- Era transitions

Deliverables: - Technology and institution progression. - Army and
economic changes across eras. - Revolutionary pressure and reform
choices. - Industrialisation, nationalism and mass politics. - Late-game
industrial logistics and total-war systems.

Acceptance criteria: - New systems emerge through data and rules without
replacing the campaign. - Early choices can influence later outcomes. -
The player can inspect why a state has gained or lost capacity.

## Milestone 8 --- Full-scale performance and balance

Deliverables: - Representative full-world dataset. - Late-game
stress-test save. - Performance instrumentation. - Balance and
regression tests. - Device compatibility pass.

Acceptance criteria: - The game remains responsive during map
interaction. - Heavy simulation work is measured and bounded. - No
repeated full-world recomputation occurs without justification. - Saves
survive version upgrades or fail with a clear compatibility message.

------------------------------------------------------------------------

# 16. Testing plan

## 16.1 Unit tests

Test individual rules: - tax calculation; - army maintenance; -
ownership transfer; - succession conditions; - movement cost; - battle
modifiers; - peace settlement; - population growth; - save serialization
and deserialization.

## 16.2 Simulation tests

Run headless simulations for many game months or years. These tests
should verify: - no negative or infinite values where disallowed; - no
orphaned province or country references; - no invalid ownership; -
countries do not gain unlimited money without a defined source; - armies
cannot become stuck in impossible states; - wars can terminate; - the
scheduler executes each system at the correct frequency.

## 16.3 Regression tests

Whenever a bug is fixed, add a test that would have caught it. Keep a
small set of fixed random seeds and campaign snapshots so that important
simulation outcomes can be reproduced.

## 16.4 Physical-device tests

Test on the target phone: - cold launch; - repeated map zoom and pan; -
rapidly opening and closing panels; - rotating or resizing the app; -
switching away and returning; - low battery and warm-device
conditions; - loading a large save; - running a late-game stress test; -
Android font scaling and display scaling.

Do not rely only on the emulator or desktop debug mode for performance
conclusions.

------------------------------------------------------------------------

# 17. Build and release approach

## 17.1 Development builds

Maintain a quick debug build for frequent testing. Keep logs useful but
avoid logging every province or every simulation operation during normal
play.

## 17.2 Android release

Before a release: - test a release-mode build on a physical phone; -
check app permissions and remove unnecessary ones; - confirm saves are
stored in an appropriate app-private location; - verify behaviour
without network access; - test upgrade and save compatibility; - check
app size and startup time; - ensure the UI handles Android system bars
and gesture navigation.

The exact build commands and signing setup should be documented in the
repository once the Flutter project is created. Do not commit signing
keys, passwords or private credentials.

## 17.3 No backend required initially

The first version should be entirely local: - no login; - no account
system; - no server-authoritative campaign; - no analytics dependency
required for core play; - no internet requirement.

Cloud backup, mod sharing or multiplayer can be evaluated later, after
the offline game is stable.

------------------------------------------------------------------------

# 18. AI-assisted development rules

AI coding tools can accelerate implementation, but the project needs
boundaries so that generated code does not become inconsistent.

For each task: 1. Give the assistant one concrete milestone or bug. 2.
Ask it to inspect the current architecture before editing. 3. Require a
short implementation plan. 4. Ask it to make the smallest coherent
change. 5. Require tests for new simulation rules. 6. Run formatting,
static analysis and tests. 7. Build and test on Android after meaningful
changes. 8. Review the diff before committing. 9. Update this README
when architecture or scope changes.

Do not ask an AI assistant to implement the entire game in one request.
That is likely to produce a large, fragile codebase with inconsistent
state ownership and limited testing.

## 18.1 Coding constraints

-   Simulation logic must not live inside UI widgets.
-   Painting must be read-only.
-   Stable IDs must be used for world relationships.
-   Time updates must go through the scheduler.
-   Randomness affecting the campaign must be controlled and saveable.
-   All data migrations must be explicit.
-   Avoid adding dependencies without explaining why they are needed.
-   Avoid refactoring unrelated systems during a feature task.
-   Never silently change the save schema.
-   Run tests after changing core models.
-   Do not claim performance is acceptable without measuring it.

## 18.2 Suggested first task for an AI coding assistant

> Create the initial Flutter project shell for an offline-first,
> Android-first grand-strategy game. Add a responsive main screen with a
> placeholder campaign date of January 1590, pause and speed controls, a
> central map viewport placeholder, and a province-information drawer.
> Keep simulation state separate from widgets. Do not add external
> dependencies unless necessary. Add a short README section explaining
> how to run the project, and add basic tests for the game clock. Do not
> attempt to implement the full game yet.

------------------------------------------------------------------------

# 19. Design questions to resolve during development

These questions should be answered through prototypes rather than
delaying the first build:

1.  **World coverage:** Entire world or a regional map for the first
    playable build? Recommendation: begin with a small test region, then
    expand.
2.  **Province count:** What map scale remains readable and performant
    on the target device? Decide through scale gates.
3.  **Campaign granularity:** Monthly economy and annual demographic
    changes are a good starting point; warfare may require shorter
    intervals.
4.  **Population detail:** Province aggregates first; social-class and
    culture detail later.
5.  **Trade:** Start with abstract flows; introduce detailed markets
    only if they create better decisions.
6.  **Historical fidelity:** Which systems are essential to make each
    era feel distinct, and which details are merely decorative?
7.  **Victory:** Sandbox play, state objectives, or a mixture? Start
    with sandbox play and an end-of-campaign report.
8.  **Map art:** Historical geographic accuracy, stylised political
    readability, or a hybrid? Prioritise clear borders and selectable
    provinces.
9.  **Modding:** Keep data-driven definitions in mind, but do not build
    a mod editor before the game works.
10. **Monetisation:** Keep it out of the core architecture until the
    product direction is clear.

------------------------------------------------------------------------

# 20. Definition of a successful first prototype

The first prototype is successful if the player can: - open the game
offline on the target phone; - inspect a map containing at least a few
hundred provinces; - zoom, pan and select a province; - see its owner,
controller, population and economic contribution; - inspect a country's
treasury and budget; - advance the campaign month by month from 1590; -
watch taxes and maintenance change the budget; - transfer a province
between countries; - save, close, reopen and continue the same
campaign; - perform all of this without a persistent UI freeze.

This prototype is intentionally much smaller than the final game. Its
purpose is to validate the foundation on which the 1590--1945 simulation
can be built.

------------------------------------------------------------------------

# 21. Final direction

Build **a data-driven grand-strategy simulation with a Flutter
interface**, rather than a large collection of unrelated screens. Treat
the political map, campaign state, simulation scheduler and save system
as the foundations. Add economic, political and military complexity in
measured stages.

The target is not merely to make the game launch on a Galaxy Z Flip6. It
is to make it remain understandable, responsive and reliable after
decades of in-game time, with many countries, armies and provinces
active.

The project's guiding rule is:

**Prove the smallest complete strategic loop, measure it on the actual
phone, and only then scale the world and its complexity.**
