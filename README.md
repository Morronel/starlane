# Starlane

An original arcade space sim prototype for Android, built with Godot 4.3.
The loop is short: dock, trade or take a contract, ride the roads and highways, fight raiders, upgrade.

## What's in the prototype

- **Main menu** at startup over a view of your station: CONTINUE (shows your ship, credits and location), NEW GAME, LOAD GAME, SETTINGS and EXIT. Settings → MAIN MENU brings it back from anywhere (the game autosaves first).

- **Six star systems with eighteen stations.** Each system is a graph about 70 km across. Four interchanges on a ring plus a core interchange are linked by grand highways. Stations, stargates, the beacon and four crossroads hang off them on about twenty small roads, so there are always several ways to get somewhere. Every system has its own sky, sun, planet and threat level.
- **Three ways to move.** Free flight is steer, throttle and boost (about 120 to 300 m/s). **Roads** are slim, cool-tinted tubes dotted with small light studs. They wind a lot and carry you at up to 900 m/s (1280 with boost). **Grand highways** are wide, warm-white tubes with a double core and big pylon rings every 5 km. They take a few seconds to wind up to 4000 m/s (5600 with boost) and cross the whole system in under a minute. Both stay calm (no flashing stripes) and are tinted from the current system's sky.
- **Turns and junctions.** In a bend the tube pushes you toward the outside wall. Easy bends ride themselves, but in sharp ones at full speed you have to hold the inside line, and boosting through them gets you thrown off. The TURN PUSH gauge shows where you are in the tube and how hard the bend pushes. Every track ends at a junction. Lean toward a branch inside the tube to take it, stay centred to carry straight on (highways prefer highways), or stay centred at a station, gate or the beacon to stop there. The HUD previews the junction and lights up the branch you'll take. You can merge onto any road or highway anywhere: fly into it along it, or tap ENTER ROAD / ENTER HIGHWAY when close.
- **Destinations and autopilot.** Pick a station or a contract on the star map (or TRACK a contract at a station) and a marker shows where to go. AUTOPILOT plans the fastest route across the whole network (free flight, roads and highways), picks the branches at every junction, eases off for sharp bends, drops out, docks, and even jumps through stargates. It rides a bit slower than a pilot flying flat out. Boost works without breaking it. Any stick input takes back control.
- **Stargates** with limited fast travel. Each hop costs a jump charge. Refill at stations and carry more with Jump Capacitors.
- **Hangar:** six ships, from the Sparrow interceptor to the Mule hauler and the Seraph. Trade in your current ship (60% back). Gear moves over where it fits.
- **Outfit:** primary weapons (pulse lasers, ion repeater, scatter blaster, plasma lance, rail driver), secondary launchers with homing missiles and torpedoes, and utility gear (shields, armor, engines, cargo pods, tractor beam, nano-repair, afterburner, targeting computer, jump capacitors). Each ship has its own slot layout, and every station stocks different gear.
- **Workshop:** salvage parts (scrap, circuits, plasma coils, lattice crystal, void shards) drop from raiders and drift in asteroid fields. Blueprints turn them into gear, including unique items like the Hellfire Repeater, Aegis Lattice and Ghost Drive. Rare blueprints drop from elite raiders or are sold at research stations.
- **Combat:** raiders with attack runs and elites in mission waves, aim assist with a lead marker, homing missiles, and auto-attack (double-tap FIRE). Tense combat music kicks in while you're fighting.
- **Cockpit view** (Settings → Camera → 1ST PERSON). Every hull has its own 3D cabin: the Sparrow's bubble canopy, the Wren's panoramic glass, the Kestrel's angular fighter frame with a head-up glass, the Mule's freighter bridge with a steering wheel and overhead panel, the Corsair's armoured slit and the Seraph's gold-trimmed canopy with a hologram radar. The yoke turns with your stick and roll (and with the autopilot), the throttle lever follows the throttle, and live screens show radar, ship status, nav, weapons or cargo. A head-up readout (speed, throttle, shield and hull) sits beside the crosshair in every cabin. Indicator lights blink, the cabin lights up when you fire, and it flashes red when you are hit or the hull runs low.
- **Station screen** with drag-anywhere kinetic scrolling (a drag never presses the button under your finger), animated cards, rolling credits, popups and sparkles.
- **Saves:** the game autosaves on dock, launch and jump. Settings → SAVES has three manual slots (save, load, delete) and NEW GAME. Saves from 0.2 and later carry over.
- **Dev mode** (Settings → Dev mode → ON) adds a DEV MENU for testing: credits, repairs, missiles, jump charges, parts, all blueprints, a full cargo hold, any ship and any gear.

## Controls

| | Touch | Gamepad | Keyboard |
|---|---|---|---|
| Pitch / yaw | Floating stick, left half of screen | Left stick | W S A D |
| Roll | ROLL pads | Right stick X | Q E |
| Throttle | Slider on the right | Right stick Y, LB / RB | R F |
| Fire | FIRE | A or RT | Space, right mouse |
| Boost | BOOST | B or LT | Shift |
| Merge / drop out / dock / jump | Context button | Y | T or Enter |
| Missiles | MSL | Right stick click | C or X |
| Auto-attack | Double-tap FIRE | X | G |
| Autopilot | AUTOPILOT button | Start | P |
| Star map | MAP button | Back | M or Tab |

## Art and audio

- Low-poly flat-shaded ships (six player hulls), stations, stargates, missiles, salvage canisters and rocks are generated in code (`scripts/models.gd`, `scripts/mesh_builder.gd`).
- Each system bakes its own nebula panorama at startup (`shaders/nebula_pano.gdshader`). The stars, sun, planets and atmospheres are shaders.
- Fonts: [Orbitron](https://fonts.google.com/specimen/Orbitron) and [Exo 2](https://fonts.google.com/specimen/Exo+2), under the SIL Open Font License (licenses in `assets/fonts/`).
- All sound effects and the three music tracks (flight, station and combat) are synthesized offline by `tools/make_audio.py` (numpy + scipy + ffmpeg). It uses FM bells, supersaw pads, filtered noise and convolution reverb. To regenerate them, run `python3 tools/make_audio.py`.

## Building

You need Godot 4.3 with Android export templates, plus an Android SDK that has `build-tools` (apksigner, zipalign) and `platform-tools`.

```bash
godot --headless --editor --quit                          # first import
godot --headless --export-release "Android" build/starlane.apk
```

For release signing, set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`. The prebuilt `build/starlane.apk` is arm64 and is signed with a debug key, so you can sideload it.

## Dev tools

- `godot --headless -- --simtest` runs a scripted gameplay check. It checks the network (every node reachable, turn tuning), then covers autopilot across the roads to a raider nest, auto-attack and missile kills, salvage pickup, autopilot docking, crafting and installing gear, touch scrolling (a drag must not buy, a tap must), autopilot across a stargate, a ship trade-in, the cockpit view, save slots, the boost tail (no speed flicker on an empty meter), the main menu, an automatic road merge, riding a highway through an interchange, being thrown off when boosting blind through a sharp bend, death and respawn, and save/load.
- `godot -- --autotest=/some/dir` saves a set of screenshots from a scripted flight.
- `godot -- --cockpits=/some/dir` saves one cockpit screenshot per ship (set `COCKPITS=mule,seraph` to pick hulls).
