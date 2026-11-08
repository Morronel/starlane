# Starlane

An original arcade space sim prototype for Android, built with Godot 4.3.
The loop is short: dock, trade or take a contract, ride the space lane, fight raiders, upgrade.

## What's in the prototype

- **Tessaly system**: two stations, Halcyon Yard and Verdant Spire, plus Kessler Beacon, an asteroid field and a ringed gas giant.
- **Arcade 6DOF flight** with chase camera, boost, auto-banking and speed dust.
- **Space lane**: tap ENTER LANE near any gate, ride at 400–1200 m/s, steer inside the tube to overtake freighter traffic (collisions hurt), and tap EXIT at the exit you want, or DROP OUT anywhere.
- **Combat**: raiders that make attack runs and break off, an elite in mission waves, aim assist with a lead indicator, shields that regenerate and a hull that needs repairs.
- **Docking**: autopilot docking, then a station screen with a mission board (raider hunts and courier runs), a three-commodity market, a shipyard with 4 upgrade tracks, and repairs.
- **Death**: insurance respawns you at the last station. You lose your cargo and 10% of your credits.

## Controls

| | Touch | Gamepad | Keyboard |
|---|---|---|---|
| Pitch / yaw | Floating stick, left half of screen | Left stick | W S A D |
| Roll | ROLL pads | Right stick X | Q E |
| Throttle | Slider on the right | Right stick Y, LB / RB | R F |
| Fire | FIRE | A or RT | Space, right mouse |
| Boost | BOOST | B or LT | Shift |
| Lane / dock / exit | Context button | Y | T or Enter |

## Art direction

Everything is procedural, so there are no external assets to license:
- Low-poly flat-shaded ships, stations, gates and rocks are generated in code (`scripts/models.gd`, `scripts/mesh_builder.gd`).
- The nebula is baked once at startup into a panorama (`shaders/nebula_pano.gdshader`). The stars, sun, gas giant and atmosphere are shader billboards and spheres.
- HDR glow (bloom) with ACES tonemapping, additive glowing lanes, and sounds made by a tiny synthesizer (`scripts/sfx.gd`).

You can swap in CC0 models later (Kenney Space Kit, Quaternius Ultimate Spaceships) by replacing the mesh functions in `models.gd`.

## Building

You need Godot 4.3 with Android export templates, plus an Android SDK that has `build-tools` (apksigner, zipalign) and `platform-tools`.

```bash
godot --headless --editor --quit                          # first import
godot --headless --export-release "Android" build/starlane.apk
```

For release signing, set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`. The prebuilt `build/starlane.apk` is arm64 and is signed with a debug key, so you can sideload it.

## Dev tools

- `godot --headless -- --simtest` runs a scripted gameplay check: lane ride, mission kill, docking payout, trade and respawn.
- `godot -- --autotest=/some/dir` saves a set of screenshots from a scripted flight.
