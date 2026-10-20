# Sovereignty — notes for Claude

Godot 4.7.1 (Mobile renderer) grand-strategy game set in the real world of
1590, Android first. **Start every session by reading `HANDOVER.md`** — it has
the current state, the user's standing requirements, architecture, commands,
known issues and next steps. `structure.md` is the user's design brief (what to
build); `PLAN.md` tracks milestones.

Essentials:

* Godot: `D:/Programs/Godot_v4.7.1-stable_win64_console.exe`
* Tests: `godot --headless --path . --script res://tests/run_tests.gd` (run
  `--import` first after adding scripts)
* Regenerate the world: `godot --headless --path . --script res://tools/world1590/build_world.gd`
  (needs `bash tools/fetch_source_data.sh` once); never hand-edit `data/`.
* Check visual changes with `godot --path . -- --screenshot=out.png --at=lat,lon --zoom=Z`
  and look at the image.
* Simulation logic stays out of UI/rendering; ownership changes only through
  `WorldState.transfer_province()`.
* Ask before downloading anything; don't commit unless asked.
