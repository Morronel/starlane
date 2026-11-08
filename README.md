# Starlane

An original arcade space sim prototype for Android, built with Godot 4.3.
The loop is short: dock, trade or take a contract, ride the space lane, fight raiders, upgrade.

## What's in the prototype

- **Four star systems** (Tessaly, Corvan Reach, Nyx Hollow and Elysia Drift), each with two stations, its own sky, sun, planet and threat level.
- **Stargates** with limited fast travel. Every hop costs a jump charge. You start with 2 charges, can raise the cap with Jump Capacitors, and refill at stations. The jump computer plans routes of several hops.
- **Star map** with a top-down SYSTEM view (lanes, exits, gates, raiders, your ship) and a GALAXY view (gate network, threat, contracts, route preview).
- **Space lanes**: wide glowing tubes. Tap ENTER LANE near any exit, ride at 400–1200 m/s, steer around freighter traffic, and pick your exit: stations, the beacon or the stargates.
- **Arcade 6DOF flight** with 3rd-person or cockpit camera and direct or inverted steering (see Settings).
- **Combat**: raiders with attack runs and an elite in mission waves. Aim assist with a lead marker. **Double-tap FIRE** to toggle auto-attack, which fires whenever a target is in the aim cone.
- **Station screen**: contracts (raider hunts and multi-jump courier runs), a market of five commodities with best-market hints, a shipyard with a live ship preview and five upgrade tracks, and services (repairs, jump refuelling). Animated credit counter, popups, sparkles and sounds.
- **Progress is saved** automatically on dock, launch and jump.

## Controls

| | Touch | Gamepad | Keyboard |
|---|---|---|---|
| Pitch / yaw | Floating stick, left half of screen | Left stick | W S A D |
| Roll | ROLL pads | Right stick X | Q E |
| Throttle | Slider on the right | Right stick Y, LB / RB | R F |
| Fire | FIRE | A or RT | Space, right mouse |
| Boost | BOOST | B or LT | Shift |
| Lane / dock / exit / jump | Context button | Y | T or Enter |
| Auto-attack | Double-tap FIRE | X | G |
| Star map | MAP button | Back | M or Tab |

## Art and audio

- Low-poly flat-shaded ships, stations, stargates and rocks are generated in code (`scripts/models.gd`, `scripts/mesh_builder.gd`).
- Each system bakes its own nebula panorama at startup (`shaders/nebula_pano.gdshader`). The stars, sun, planets and atmospheres are shaders.
- Fonts: [Orbitron](https://fonts.google.com/specimen/Orbitron) and [Exo 2](https://fonts.google.com/specimen/Exo+2), under the SIL Open Font License (licenses in `assets/fonts/`).
- All sound effects and both ambient music tracks are synthesized offline by `tools/make_audio.py` (numpy + scipy + ffmpeg). It uses FM bells, supersaw pads, filtered noise and convolution reverb. To regenerate them, run `python3 tools/make_audio.py`.

## Building

You need Godot 4.3 with Android export templates, plus an Android SDK that has `build-tools` (apksigner, zipalign) and `platform-tools`.

```bash
godot --headless --editor --quit                          # first import
godot --headless --export-release "Android" build/starlane.apk
```

For release signing, set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`. The prebuilt `build/starlane.apk` is arm64 and is signed with a debug key, so you can sideload it.

## Dev tools

- `godot --headless -- --simtest` runs a scripted gameplay check: lane ride, auto-attack kills, docking payout, trade, stargate jump, refuel, respawn and save/load.
- `godot -- --autotest=/some/dir` saves a set of screenshots from a scripted flight.
