# VEYL Control

**Advanced Client Toolkit** for Roblox. It is one standalone Luau file (`VEYL.lua`), designed for an executor-launched client runtime, and it also runs as a normal LocalScript.

It is built for your own experience or an authorized test session. Everything it does is client-side: it never invokes game remotes, never reports hits, and never changes server-authoritative state.

## How to run

| Runtime | What to do | What you get |
|---|---|---|
| Client executor (primary target) | Execute `VEYL.lua` while in the experience. | Full feature set. Optional APIs (Drawing, `gethui`, file config, clipboard) are detected and used when present. |
| Standard LocalScript (fallback) | Put `VEYL.lua` in `StarterPlayer › StarterPlayerScripts`. | Same features with fallbacks: ScreenGui overlay, PlayerGui parent, session-only settings, copy-from-textbox. |

Re-executing the file first shuts down the previous VEYL session. It also removes leftovers from earlier builds, matched by exact name and class (`NovaAdminConsole`, `NovaOverlay`, `NovaClientFX`, and the previous `VEYL*` instances). Unrelated instances are not touched.

**Test targets:** tag a training dummy Model with the CollectionService tag `VEYLTestTarget`. An optional string attribute `VEYLTargetName` sets its label.

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

These checks were run on this file:

- `luau-compile`: compiles with no errors.
- `luau-lsp analyze` with the Roblox API type definitions: no real errors. The remaining findings are table-field inference noise and the expected executor globals.
- Every property and enum item passed to `Instance.new` helpers was checked against the Roblox API dump: 0 problems.
- Smoke and behavior tests: the script ran in the Luau VM against a mock Roblox client, in both plain mode and executor-API mode. They cover startup, hotkeys, clicking every button twice, invalid input, ESP geometry (including near-plane clipping), the World restore rule, keybind collisions, music, renderer switching, config save/reload and malformed configs, emergency stop, re-execution, and leak-free shutdown. Result: 82 checks, 0 failures.

**Not verified:** a live Roblox client or executor session. The mock models only what VEYL touches.

**Manual checks to do in a real session:**
1. Drawing's `Transparency` is treated as opacity (1 = visible). If overlays look inverted on your runtime, switch Visuals › Renderer to GUI.
2. Highlights are parented to `Workspace.VEYLClientFX` with `Adornee` set. Confirm they render.
3. Rejoin works only in a published experience, not in Studio.

## Changelog

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
