# Starlane

An original cozy trade-and-travel space sim for Android, built with Godot 4.3.

## What's in 1.0

Starlane is a cozy trade-and-travel space sim. Haul cargo between twenty star systems, take odd jobs, buy a market stall and then a factory, hire pilots to trade for you, and chase the Lost Lanes.

### Travel

- **Twenty systems in four regions** (Core Worlds, Rim Gardens, Dark Reach, The Frontier), eighty stations, and one hidden system you have to earn. Every system has its own sky, sun, planet, threat level, music pitch and a **wonder** to photograph: ice geysers, a ring arc, a dead dreadnought, crystal fields, stone pillars or a lighthouse.
- **One loop per system.** Each system has a single one-way highway loop. Every station, gate and the beacon has its own numbered exit ramp and entry ramp, so there are no crossroads at all. Tap the exit button (or let the GPS arm it) and the ramp peels off by itself.
- **Cruise.** On the loop, CRUISE speeds up time 3x and drops you out before your exit, a road event or a fight.
- **Road events.** Distress calls, drifting derelicts, customs checks, ion storms, comets, and pirate stops in threat 2+ systems. Turn on **Peaceful trader** in Settings to skip the pirates.
- **Radio.** Four channels (ambient, Lane FM lo-fi, Neon Drift synth, off), each with its own DJ.
- **Rest stops** in every original system: coffee for a speed boost, a nap, and a postcard album.
- **Autopilot** still plans the whole route, docks and jumps through stargates.

### Trade and work

- **Living economy.** Stations produce and consume goods, stock moves, and every crate you sell lowers the price. Market events (strikes, booms, festivals, shortages, gluts) shift prices across the galaxy.
- **Nine contract kinds:** courier, supply runs, passengers with a deadline, salvage, wonder surveys, smuggling, races, station defence and multi-step chains.
- **Five factions** (Haulers' Guild, Concord Navy, Free Miners' Union, Lantern Order, Black Comet). Work for them to raise your standing, then buy their licence for a perk: better prices, military hulls, cheap repairs, free rumours or safe passage.
- **Bars** at every station. There's a bartender, three regulars with procedural faces, rumours that leak upcoming market news and good deals, wanted posters, Orbit dice and a jukebox.

### Property and progression

- **Estate tab:** market stalls and bars earn passive income. Factories turn cheap inputs into goods, and factories next to their suppliers form a complex. Upgrade each to level 3.
- **Fleet:** keep several ships in your hangar (BUY & KEEP), fly any of them, or hire a pilot to trade with one on their own. Your property keeps earning while the game is closed (up to two hours), and you get a "while you were away" report when you come back.
- **Fourteen hulls,** from the Sparrow to the Leviathan, including licence-locked navy and smuggler ships. There are also paint jobs and cockpit trinkets.
- **Ranks** for trading, combat and exploring.
- **The Lost Lanes:** a seven-chapter story from Brother Ambry at the Lantern bars. It ends by opening Quiet Lane, the hidden twentieth system, where you can buy a home with a garden, an observatory and a hangar bay.

### Combat

- Six raider types (scouts, brawlers, snipers, bombers, aces that dodge, drones) with elites, aim assist, homing missiles and auto-attack.
- **Outfit and Workshop:** weapons, launchers, utility gear and craftable blueprints, as before.

### Also

- **Cockpit view** with a 3D cabin per hull, a live yoke and throttle, and screens.
- **Saves:** the game autosaves on dock, launch and jump, and has three manual slots. Saves from 0.2 and later carry over (1.0 uses save format v5).
- **Dev mode** (Settings → Dev mode → ON) adds a DEV MENU for testing.

## Controls

| | Touch | Gamepad | Keyboard |
|---|---|---|---|
| Pitch / yaw | Floating stick, left half of screen | Left stick | W S A D |
| Roll | ROLL pads | Right stick X | Q E |
| Throttle | Slider on the right | Right stick Y, LB / RB | R F |
| Fire | FIRE | A or RT | Space, right mouse |
| Boost | BOOST | B or LT | Shift |
| Merge / drop out / dock / jump | Context button | Y | T or Enter |
| Exit / event action | Second context button | | V |
| Photo | PHOTO | | B |
| Radio | RADIO | | N |
| Missiles | MSL | Right stick click | C or X |
| Auto-attack | Double-tap FIRE | X | G |
| Autopilot | AUTOPILOT button | Start | P |
| Star map | MAP button | Back | M or Tab |

## Art and audio

- Low-poly flat-shaded ships (six player hulls), stations, stargates, missiles, salvage canisters and rocks are generated in code (`scripts/models.gd`, `scripts/mesh_builder.gd`).
- Each system bakes its own nebula panorama at startup (`shaders/nebula_pano.gdshader`). The stars, sun, planets and atmospheres are shaders.
- Fonts: [Orbitron](https://fonts.google.com/specimen/Orbitron) and [Exo 2](https://fonts.google.com/specimen/Exo+2), under the SIL Open Font License (licenses in `assets/fonts/`).
- All sound effects and music (flight, station, combat, bar and two radio stations) are synthesized offline by `tools/make_audio.py` (numpy + scipy + ffmpeg). It uses FM bells, supersaw pads, filtered noise and convolution reverb. To regenerate them, run `python3 tools/make_audio.py`.

## Building

You need Godot 4.3 with Android export templates, plus an Android SDK that has `build-tools` (apksigner, zipalign) and `platform-tools`.

```bash
godot --headless --editor --quit                          # first import
godot --headless --export-release "Android" build/starlane.apk
```

For release signing, set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`. The prebuilt `build/starlane.apk` is arm64 and is signed with a debug key, so you can sideload it.

## Dev tools

- `godot --headless -- --simtest` runs a scripted gameplay check. It checks that every one of the twenty systems builds a clean loop (one exit per destination, gentle turns), flies a human-style pilot to every destination, runs every road event, the economy, bar, contracts, licences, estate, fleet, the v5 save round trip, raider types and the full Lost Lanes story, then covers autopilot across the roads to a raider nest, auto-attack and missile kills, salvage pickup, autopilot docking, crafting and installing gear, touch scrolling (a drag must not buy, a tap must), autopilot across a stargate, a ship trade-in, the cockpit view, save slots, the boost tail (no speed flicker on an empty meter), the main menu, an automatic road merge, riding a highway through an interchange, holding on when boosting blind through the sharpest road bend, the boost punch, GPS arrow and words agreeing, death and respawn, and save/load.
- `godot -- --autotest=/some/dir` saves a set of screenshots from a scripted flight.
- `godot -- --cockpits=/some/dir` saves one cockpit screenshot per ship (set `COCKPITS=mule,seraph` to pick hulls).
