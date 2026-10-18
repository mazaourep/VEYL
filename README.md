# VEYL Control

**Advanced Client Toolkit** for Roblox: a modular Luau toolkit started by a single loader through `loadstring`.

It is built for your own experience or an authorized test session. Everything it does is client-side: it never invokes game remotes, never reports hits, and never changes server-authoritative state.

## How to run

Run this one line in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mazaourep/VEYL/main/loader.lua"))()
```

`loader.lua` downloads the 30 modules in `src/` in parallel and compiles all of them. Nothing runs until every module has compiled, then they start in order. If any module fails, the loader releases whatever was already created and shows the module name in a Roblox notification.

> **This repository is private right now.** Unauthenticated `HttpGet` receives `404` from `raw.githubusercontent.com`, so the line above only works after one of these:
> 1. Make the repository public. Also, the files must be on `main` (merge this branch).
> 2. Host `loader.lua` and `src/` somewhere public and point `VEYL_SOURCE` there.
> 3. Use local mode (below). It works with a private repository and offline.
>
> Never put a GitHub token in the loader.

### Options (set before the `loadstring` line)

```lua
-- Fetch from another public base URL. Pin a commit SHA for a reproducible build.
getgenv().VEYL_SOURCE = "https://raw.githubusercontent.com/<owner>/<repo>/<commit-sha>/"

-- Read the modules from the executor workspace folder instead of the network.
-- Copy src/ to <executor workspace>/VEYL/src/ first, then run loader.lua the same way.
getgenv().VEYL_SOURCE = "local"
```

After a successful download, a complete copy is cached in `VEYL/cache/` when the runtime has a file API. If a later download fails, that copy is used. Remote code runs with your executor's privileges, so load VEYL only from a source you control.

### Without HttpGet or loadstring

`dist/VEYL.lua` is a generated single-file build of the same modules. Execute it directly, or place it in `StarterPlayer › StarterPlayerScripts` as a LocalScript. There, executor-only features fall back: ScreenGui overlay, PlayerGui parent, session-only settings, copy-from-textbox.

Re-running VEYL by any route first shuts down the previous session. It also removes leftovers from earlier builds, matched by exact name and class (`NovaAdminConsole`, `NovaOverlay`, `NovaClientFX`, older `VEYL*` instances). Unrelated instances are not touched.

**Test targets:** tag a training dummy Model with the CollectionService tag `VEYLTestTarget`. An optional string attribute `VEYLTargetName` sets its label.

## Project layout

| Path | Contents |
|---|---|
| `loader.lua` | Entry point. Holds the module list (the single source of truth for load order), fetching, cache and local mode. |
| `src/core.lua` | Services, constants, module tables, utilities, Maid lifecycle, log |
| `src/runtime.lua` | Executor capability detection, re-execution handoff, legacy cleanup |
| `src/settings.lua`, `binds.lua`, `persist.lua` | Validated settings registry, keybind manager, config file |
| `src/ui/` | `window` (window, tabs, sections), `controls`, `popups` (dropdown, confirm, color picker), `notify` |
| `src/overlay.lua`, `entities.lua`, `esp.lua`, `aimlab.lua` | Drawing/GUI renderer, entity registry, ESP, Aim Lab |
| `src/world.lua`, `weapons.lua`, `diagnostics.lua`, `music.lua`, `features.lua` | World overrides, tool discovery, diagnostics, Music Hub, rejoin and emergency stop |
| `src/pages/` | One file per tab, plus `shared.lua` helpers |
| `src/app.lua` | Input router, feature wiring, startup and shutdown |
| `dist/VEYL.lua` | Generated single-file build |
| `tools/bundle.py` | Rebuilds `dist/VEYL.lua` |
| `tests/` | Mock-Roblox test suites (`tests/run.sh`) |

Each module is `return function(V) … end`. The shared context table `V` passes values between modules: a module reads the names it needs at the top (`local Settings = V.Settings`) and publishes its own at the bottom (`V.ESP = ESP`).

### Development

```sh
python3 tools/bundle.py   # after editing src/, regenerate dist/VEYL.lua
tests/run.sh              # run all test suites (downloads the Luau CLI if luau is not on PATH)
```

To add a module, create it under `src/` with the `-- VEYL module: <name>` first line, then add its path to `MODULES` in `loader.lua` at the right position.

## Default hotkeys (rebindable in Settings › Keybinds)

| Key | Action |
|---|---|
| RightShift | Toggle console |
| Z | Toggle Aim Lab |
| Mouse 2 (hold) | Aim Lab hold key |
| X | Toggle ESP |
| C | Cycle test target |
| V | Clear selected target |
| End | Emergency stop (cannot be unbound; rebinding asks for confirmation) |

Hotkeys are ignored while you type in a text box or while a key is being captured. A binding that collides with another action asks before reassigning.

## Tabs

- **Main:** live status, quick toggles, cycle/clear target, restore defaults, emergency stop.
- **Aim Lab:** activation (hold/always), FOV, max distance, target point, priority, responsiveness, line of sight, lock to selection, reticle origin, FOV circle, target indicator.
- **Visuals:** 2D boxes (near-plane clipped), names, distance in studs, health bars, tracers, off-screen arrows, Highlight, occlusion check, filters, transparency, and an HSV/RGB/HEX color picker for 13 separate colors.
- **World:** local brightness, exposure, time of day, shadows, ambient, color correction, bloom, atmosphere. Everything VEYL changed is restored on disable.
- **Entities:** searchable live registry (players, NPCs, test targets), inspector, session allowlist.
- **Weapons:** automatic Tool discovery with evidence, confidence and unknowns. Every tool is marked *Unverified*.
- **Music:** Roblox audio player (queue, shuffle, repeat, seek, volume, favorites, reorder) plus Spotify/YouTube Music bookmarks.
- **Diagnostics:** FPS estimate, position, velocity, camera, ping, discontinuity detection with markers, event log.
- **Misc:** runtime capability report, utilities, rejoin (this server or matchmaking), server-side actions listed as unavailable, unload.
- **Settings:** keybinds, interface scale/translucency/blur, configuration storage.

## Scope and honest limits

- Aim Lab and ESP only cover three groups: tagged test targets, players you allowlist for the session in Entities, and (opt-in for Aim Lab) untagged NPCs.
- Aim Lab moves only your local camera. Whether a weapon's shots follow the camera depends on that weapon's own scripts.
- Silent aim, shot redirection, magic bullet, desync, kicking, changing other players' health or position, and granting items need server authority. They are listed as unavailable and are not implemented.
- Spotify and YouTube Music cannot play inside Roblox. Bookmarks are links you copy and open in a browser. No URL-opening API is used.
- World changes and diagnostic markers are local to your client.
- Settings persist to `VEYL/config.json` only when the runtime has a file API. Not saved: the on/off state of Aim Lab, ESP and World, the player allowlist, and any credential.

## Verification

These checks were run on the modules, the loader and the bundle:

- `luau-compile`: compiles with no errors.
- `luau-lsp analyze` with the Roblox API type definitions: no real errors. The remaining findings are table-field inference noise and the expected executor globals.
- Every property and enum item passed to `Instance.new` helpers was checked against the Roblox API dump: 0 problems. Every module was also checked on its own for missing imports and for unused or shadowed locals: none found.
- Smoke and behavior tests: the script ran in the Luau VM against a mock Roblox client, in both plain mode and executor-API mode. They cover startup, hotkeys, clicking every button twice, invalid input, ESP geometry (including near-plane clipping), the World restore rule, keybind collisions, music, renderer switching, config save/reload and malformed configs, emergency stop, re-execution, and leak-free shutdown.
- Loader tests: 404 from a private repo, successful download, cache fallback, local mode, a module with a syntax error (the running session is left untouched), a module that fails while starting (partial state removed), and a non-https source.
- Result: 4 suites, 101 checks, 0 failures (`tests/run.sh`).

**Not verified:** a live Roblox client or executor session. The mock models only what VEYL touches. It also assumes executors run `loadstring` chunks in the executor's global environment, as common executors do.

**Manual checks to do in a real session:**
1. Drawing's `Transparency` is treated as opacity (1 = visible). If overlays look inverted on your runtime, switch Visuals › Renderer to GUI.
2. Highlights are parented to `Workspace.VEYLClientFX` with `Adornee` set. Confirm they render.
3. Rejoin works only in a published experience, not in Studio.

## Changelog

### 2.1.0
- Split the 7,000-line script into 30 modules under `src/`, connected through a shared context table. Imports and exports were generated mechanically and checked by the linter.
- Added `loader.lua`: parallel download, compile-everything-before-running, retry, cache fallback, local mode, `VEYL_SOURCE` override, a Roblox notification on failure, and cleanup of partially started modules.
- Added `dist/VEYL.lua` (generated single-file build), `tools/bundle.py`, and `tests/` with a loader test suite.

### 2.0.0
- Rewrote the earlier LocalScript as an executor-aware single file. Capability detection covers Drawing, `gethui`, file I/O, clipboard and identity, each with a fallback.
- New compact UI: top tabs, two-column panels, a hover hint bar, a resizable and draggable window, minimize, close/reopen, and per-tab search.
- Added a central validated settings registry with right-click reset, plus a keybind manager, a color picker, dropdown popups that close on Esc or an outside click, and numeric slider input.
- Added a Maid lifecycle. Every connection, instance, thread and Drawing object is owned and released. Emergency stop and unload leave nothing behind.
- Fixed earlier defects:
  - "Refresh registry" did not refresh.
  - Dynamic rows leaked connections.
  - Aim Lab called `GetTagged` every frame and its smoothing depended on frame rate.
  - Restore Visuals overwrote Lighting.
  - The three emergency-stop paths behaved differently.
  - Duplicate toggles were not synced.
  - Glow layers stayed visible after closing.
  - Popups never closed.
- Added the Weapons, Misc and Settings feature sets, a Music Hub with load-failure detection, rejoin modes and config persistence.
- On shutdown, the config is written only when there are unsaved changes, so a file edited on disk is not overwritten on re-execution.
