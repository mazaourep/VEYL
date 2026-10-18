# VEYL — MASTER IMPLEMENTATION PROMPT V7
## Executor-Aware Client Runtime · Single Script File · Real Features · Music Hub

## 0. Mission

You are acting as a senior Roblox Luau engineer, UI/UX designer, client-side systems engineer, and test engineer.

Rebrand and upgrade the existing **Nova Admin Console** project into **VEYL Control**, a polished, dense, in-game toolkit for my own Roblox experience and authorized testing. The intended runtime may be a client-side executor environment, not only a standard Roblox LocalScript. The provided gameplay videos are visual references for feature density, panel layout, and in-game workflow.

The result must be significantly more complete than a simple ESP overlay with a few toggles. It should feel like an integrated, configurable in-game toolkit with multiple tabs, real settings controls, a functional Music Hub for permitted Roblox audio assets, consistent visual feedback, and carefully managed runtime behavior.

**Non-negotiable requirements:**
- Exactly one script file. The primary target is an executor-launched client runtime with optional executor APIs; do not create separate scripts or modules.
- Preserve all existing working functionality while migrating the branding from Nova Admin Console to VEYL.
- Use real functionality only. Never present a nonfunctional control, mock result, or unsupported behavior as complete.
- Inspect existing source before editing and plan before implementation.
- Use the reference videos for visual direction, not as proof of their hidden internal behavior.
- Do not use Roblox Studio Network Simulator.
- Do not add server scripts, ModuleScripts, RemoteEvents, RemoteFunctions, external proxies, or third-party dependencies.
- Executor-specific capabilities may be used for client-side presentation, drawing, input conveniences, and local configuration only after runtime detection. Do not use them to bypass server validation, evade anti-cheat, abuse unknown remotes, or fabricate server-authoritative hits or state.

**Important runtime distinction:** an executor-injected script is not the same thing as a normal `LocalScript` placed under `StarterPlayerScripts`. Because the requested executor environment is now an explicit target, provide one standalone Luau script file intended to be executed by the chosen client runtime. Do not tell the user to place executor-only code in `StarterPlayerScripts`. If normal LocalScript compatibility is kept as a fallback, guard every optional executor API and use supported Roblox APIs when available. Never claim executor-only features run in a standard LocalScript.

## 0.1. Required Rebrand: Nova Admin Console → VEYL

The product's new permanent brand name is **VEYL**. Use **VEYL Control** as the product/interface name and **VEYL** as the compact title-bar brand. Treat “Nova Admin Console” only as the legacy name of the existing source project.

Rebrand consistently across all user-visible and internally managed identifiers where safe: window titles, tab labels, notifications, toast messages, log prefixes, GUI names, overlay names, temporary FX folders, comments, and any settings/configuration namespace that actually exists. Do not leave mixed old/new branding in the finished UI.

Suggested new identifiers, unless a verified dependency requires another name:
- Main ScreenGui: `VEYLControl`
- Overlay ScreenGui: `VEYLOverlay`
- Local-only FX folder: `VEYLClientFX`
- Log prefix: `[VEYL]`
- Title bar: `VEYL`
- Product description: `Advanced Client Toolkit`

Migration and re-execution safety:
- During startup, clean up the new VEYL instance names.
- Also detect and safely clean up legacy instances named `NovaAdminConsole`, `NovaOverlay`, and `NovaClientFX` so running the updated script does not leave duplicate consoles or stale visuals.
- Do not destroy unrelated user-created instances. Check exact names and expected class/ownership markers where possible.
- Keep existing feature behavior and input defaults intact during the rebrand.
- If an existing persisted settings namespace is found, inspect it before changing it; preserve access to existing settings or perform a safe migration instead of silently discarding them. Do not invent a persistence system if none exists.

The rebrand must not be limited to changing the visible title. Search the complete source for old branding and verify the final user-facing output is consistently VEYL.

## 1. Understand the Video References

Use the supplied videos as the main visual and interaction reference. The visible characteristics to reproduce in an original VEYL design include:

- A compact, dark, floating settings window displayed over live gameplay.
- Multiple narrow tabs across the top.
- Dense, well-grouped settings rather than oversized cards with excessive empty space.
- A two-column settings layout where the available width allows it.
- Separate sections for entity/ESP settings and local world/visual settings.
- Small, clear toggles, dropdowns, sliders, color swatches, and editable values.
- Clear selection, hover, enabled, and disabled states.
- A draggable window with close/minimize/reopen behavior.
- Gameplay remains visible behind the panel; overlays should not unnecessarily obscure the game.
- Optional in-world debug drawings such as FOV circles, target markers, boxes, and tracers.

Create an original VEYL Control design. Do not copy another product's branding, names, logos, or exact assets.

## 2. Required Development Workflow

### Phase A — Inspect

Before modifying code:
1. Read the complete existing Nova Admin Console LocalScript (the legacy source project), not a truncated excerpt.
2. Inspect every related file that is actually available in the supplied project.
3. Map existing UI construction, state, input bindings, render bindings, event connections, settings, cleanup, and feature dependencies.
4. Read the supplied user development rules and check any available project notes about earlier mistakes.
5. Record the current features and known defects.
6. Identify constraints that cannot be satisfied by a LocalScript.

Do not invent unprovided files or source-code structure. If source code needed for a task is inaccessible, state precisely what is inaccessible and continue with work supported by available evidence.

### Phase B — Plan

Provide a short implementation plan before editing, including:
- Existing features that will be preserved.
- Bugs to fix first.
- New controls and their behavior.
- Runtime and API constraints.
- Acceptance criteria and tests.

### Phase C — Implement

Make small, traceable changes. Do not rewrite the entire console unless inspection demonstrates that a rewrite is necessary and its compatibility impact is explained.

### Phase D — Verify

Run the checks genuinely available in the environment. Do not claim that Studio playtesting, screenshots, linting, or runtime tests happened unless they were actually performed.

## 3. Single-File, Executor-Aware Client Architecture

The deliverable is exactly one standalone Luau script file executed in the Roblox client through the user's selected runtime. Do not create extra scripts or modules.

The primary execution mode is **executor-aware client mode**. Do not incorrectly instruct the user to place the complete executor-dependent script in `StarterPlayer > StarterPlayerScripts`, because executor-only APIs do not exist in an ordinary LocalScript.

Keep UI creation, input handling, supported client-side rendering, accessible-instance discovery, settings state, local visual effects, diagnostics, optional executor capability adapters, and cleanup in this single file.

Organize the source into clear internal sections, for example:
1. Configuration and defaults
2. Runtime capability detection
3. Roblox service references
4. Existing-feature integration
5. State and settings registry
6. UI component builders
7. Tab and panel management
8. Keybind manager
9. Color picker and dropdown controls
10. Entity discovery
11. Aim Lab
12. ESP / Visuals
13. Local world visuals
14. Weapon candidate discovery
15. Diagnostics
16. Rejoin
17. Music Hub
18. Logging and notifications
19. Lifecycle and cleanup

Do not let a one-file requirement turn into duplicated or tangled code.

### 3.1. Executor Capability Detection and Fallbacks

At startup, build a capability report for optional runtime features. Never assume that a particular executor, API name, drawing library, or filesystem interface exists.

Detect optional capabilities conservatively and safely, including only those needed for approved client-side utility behavior:
- Drawing/overlay primitives, if provided by the runtime.
- A supported executor GUI parent/container mechanism, if provided.
- Local configuration file read/write APIs, if provided.
- Clipboard support, if provided.
- External URL opening, if provided and appropriate for a user-clicked bookmark.
- Runtime identity/version information, only if exposed without intrusive probing.

For each optional capability:
- Check that it exists and is callable before use.
- Wrap expected failure points with clear error handling.
- Provide a supported Roblox GUI fallback when feasible.
- Avoid calling unknown functions just to see what they do.
- Do not probe or dump unrelated executor internals.
- Do not hardcode compatibility to one executor brand unless the user explicitly identifies it.
- Display a concise `Runtime Capabilities` panel showing `Available`, `Unavailable`, or `Fallback` for each relevant feature.

Use executor-specific drawing primitives only for local visual presentation such as boxes, tracers, labels, FOV indicators, and other client-side overlays. Ensure every created drawing object is tracked and removed during feature shutdown or script re-execution. When the Drawing API is unavailable, fall back to supported GUI objects if practical.

If local file APIs exist, use them only for VEYL's own validated, non-sensitive configuration and playlist metadata. Do not store API keys, passwords, OAuth tokens, or other secrets. If persistent storage is unavailable, keep settings in session memory and state that limitation.

Do not use executor capabilities to bypass server validation, manipulate authoritative hit registration, invoke unknown remotes, evade anti-cheat protections, or forge server-authoritative state. Do not label a local camera/visual effect as a server-side gameplay change.

## 4. UI Layout and Design System

Build a compact, premium in-game panel inspired by the supplied videos:

- Dark charcoal/navy backgrounds, subtle borders, restrained blue/cyan highlights, readable text, and consistent spacing.
- Compact tab navigation, section headings, dividers, and a sensible two-column layout where appropriate.
- Use consistent widths and heights for toggles, dropdowns, sliders, inputs, and action buttons.
- Maintain clear contrast and selected/hover/focus states.
- Keep text legible at common game resolutions.
- Include a draggable title bar, close control, minimize behavior, and a small reopen button.
- Handle mouse, keyboard, and touch where the control makes sense.
- Use scrolling panels when content exceeds available space.
- Do not block essential gameplay input while typing in a text box or changing a keybind.
- Respect screen bounds and avoid clipped menus and off-screen popups.
- Avoid excessive animation. Use short, purposeful transitions only.

Proposed tabs (rename only when it improves consistency with the current implementation):
- **Main** — overview, quick toggles, current state, emergency stop.
- **Aim Lab** — client-side camera aim testing for explicitly configured test targets.
- **Visuals** — ESP, boxes, labels, FOV circle, tracers, target indicators.
- **World** — local-only lighting and ambience controls.
- **Entities** — searchable character/NPC registry and inspection.
- **Weapons** — automatic Tool discovery and evidence-based compatibility status.
- **Diagnostics** — local position/camera observations, performance, logs.
- **Misc** — local utility controls and other supported convenience functions.
- **Settings** — keybinds, colors, UI behavior, defaults, and cleanup.

If the current 560×460 layout is too small for the required content, improve the layout carefully. The panel may resize within reasonable screen limits, but must remain compact and usable.

## 5. Functional UI Controls — Not Decorative Mockups

Implement reusable, tested controls that genuinely modify the application's state:

### Toggle / Switch
- Correct enabled/disabled appearance.
- One callback per user action.
- Accurate current value.
- Optional keyboard shortcut association.
- No duplicate activation events.

### Slider
- Dragging works with mouse and touch.
- Supports minimum, maximum, step, and default value.
- Displays the precise current value.
- Clamps invalid and out-of-range values.
- Updates the bound feature and preview immediately where appropriate.

### Dropdown / Select
- Supports an explicit option list and current selection.
- Shows the current value, opens/closes correctly, and closes on outside click, Escape, or selection.
- Keeps popups within screen bounds.
- Supports scrolling when needed.
- Handles a changed/removed option safely.
- Does not leave orphaned popups or event connections.

### Searchable Select / Entity List
- Case-insensitive search.
- Stable selection and useful empty state.
- Clear handling when the selected entity disappears.
- No full-list recreation on every frame or unnecessarily on every refresh.

### Numeric / Text Input
- Validates input and provides understandable feedback.
- Keeps focus behavior correct.
- Does not trigger global hotkeys while the user is typing.
- Supports reset-to-default.

Every control must be linked to a real setting or action. If the corresponding feature is unavailable, disable the control and explain why instead of making it appear functional.

## 6. Keybind Manager

Create a dedicated keybind editor inside Settings.

Required behavior:
- Display each action and its current binding.
- Allow rebinding by clicking a “Press a key…” control and capturing the next supported input.
- Provide Cancel and Reset-to-default actions.
- Allow a binding to be unbound when appropriate.
- Detect collisions and offer a clear resolution; never silently bind one key to two conflicting actions.
- Support keyboard keys and mouse buttons only where applicable.
- Ignore hotkeys while text inputs are focused or while the UI is capturing a key.
- Avoid handling the same input twice.
- Preserve the existing defaults unless the user changes them.
- Keep all hotkey actions in a single input router where practical.
- Ensure the emergency stop remains easy to trigger and is not accidentally rebound without confirmation.

Preserve current defaults unless inspection shows a conflict:
- RightShift — toggle console
- Z — toggle Aim Lab
- X — toggle ESP
- C — cycle eligible test target
- V — clear selected target
- End — emergency stop

## 7. ESP Color Picker

Create a real reusable color-picker control, not a static color swatch.

Required features:
- HSV color selection area or equivalent usable picker.
- Hue control.
- RGB numeric fields.
- HEX input with validation (`#RRGGBB` and optionally `RRGGBB`).
- Immediate preview and live application.
- Per-feature color assignment.
- Reset-to-default and copy/display current HEX value.
- Clear handling for invalid values.
- Popup placement within viewport bounds.
- Complete cleanup when dismissed.

Provide independent colors for at least:
- ESP boxes
- Names and labels
- Tracers
- Health/health-bar accents where appropriate
- Target indicator
- FOV circle
- Highlight fill and outline
- Visible target versus occluded target
- NPC versus player test entities, when enabled

Do not force every visual element to share one global color if a specific per-element color is configured. If visibility-based colors are enabled, define the precedence clearly.

## 8. Main and Quick Controls

The Main tab should show:
- Global feature status.
- Quick enable/disable controls for supported features.
- Current selected test target, if any.
- Current weapon-discovery status.
- Current diagnostics status.
- Buttons for clearing a target, restoring defaults, and emergency stop.
- Clear notifications for failures and unavailable capabilities.

Emergency stop must actually stop feature update loops, disconnect feature-specific bindings, hide or destroy temporary visuals, clear temporary state, and prevent delayed tasks from reactivating features.

## 9. Aim Lab — Genuine Client-Side Scope

Implement real camera-based aim testing only for configured training dummies, NPC test targets, or explicitly allowlisted characters in the user's own experience/test sessions.

Include:
- Enable/disable and activation key.
- Hold-to-activate option when applicable.
- FOV radius.
- Maximum target distance.
- Target-point dropdown (Head, torso, root, or valid discovered points).
- Target priority dropdown (closest to reticle, shortest distance, or another genuinely implemented criterion).
- Smoothness/interpolation control.
- Line-of-sight requirement.
- Target cycling and explicit lock/clear actions.
- Optional FOV circle and target indicator.
- Graceful behavior for removed/dead targets and respawns.
- Camera replacement handling and safe restoration of supported state.

Do not claim that camera orientation controls every weapon's actual shot direction. Do not target arbitrary players outside the configured authorized test scope. Do not fabricate server-confirmed hits or add mechanisms to bypass server-side validation.

## 10. Visuals / ESP

Implement working client-side overlays for character models that the client can access:
- 2D bounding boxes.
- Name labels.
- Distance labels in `studs` (do not label studs as metres).
- Health bars.
- Tracer lines.
- Off-screen direction markers.
- Highlight fill and outline.
- Visibility / occlusion status.
- Player/NPC filters.
- Maximum visual distance.
- Per-element colors and transparency.
- Optional FOV circle and current test-target indicator.

Technical requirements:
- Use supported Roblox GUI objects, camera projection, raycasts, and `Highlight` where appropriate.
- Prefer the detected executor Drawing API for local overlay rendering when available; otherwise use supported Roblox GUI objects. Track and clean up both kinds of visual objects.
- Reuse overlay objects instead of creating them every frame.
- Handle entities crossing the near plane, being behind the camera, leaving the viewport, dying, respawning, or being removed.
- Clamp off-screen markers to sensible viewport boundaries.
- Use one consistent coordinate convention with GUI inset handling.
- Cache expensive calculations appropriately and update visibility checks at a bounded rate.
- Destroy or hide stale objects predictably when ESP is disabled.

## 11. World — Local Visual Controls

Create a separate section for visual settings that can genuinely be changed locally with supported Roblox APIs, where accessible:
- Local brightness/lighting preview.
- Local exposure or color-correction settings where applicable.
- Local saturation and bloom controls where supported.
- Local atmosphere/fog presentation where supported.
- Optional visual sky/ambience selection only when the required assets are legitimately available to the client and can be restored safely.
- Restore-original-visuals action.

Maintain a snapshot of properties this script actually changes and restore those values when disabled or stopped. Do not overwrite unrelated changes made after the initial snapshot without a clear rule.

Do not claim local lighting changes modify the server's world state. Do not add fake weather selections that do nothing. If a visual preset requires inaccessible assets or a different architecture, mark it unavailable.

## 12. Entity Scanner

Build a searchable entity registry for eligible live character models:
- Name and model path.
- Player/NPC classification where reliably determinable.
- Distance from the camera or local character, with the distance origin clearly stated.
- Available health and Humanoid state.
- Available root position.
- Screen-space visibility.
- Whether the entity is eligible for the current Aim Lab filter.

Separate live entities from stored templates and replicated asset candidates. Do not mistake every Humanoid under ReplicatedStorage or StarterPack for a live entity.

Use event-driven discovery and dirty flags. Update existing list rows where practical. If rows must be replaced, disconnect their associated events and release references before replacement.

## 13. Weapon Candidate Discovery

The user does not remember weapon names. Automatically discover accessible `Tool` candidates without requiring manual naming or paths.

Inspect appropriate client-accessible locations, including:
- LocalPlayer Backpack and equipped character.
- Workspace for dropped Tools.
- StarterPack and relevant replicated asset containers for templates.

For each candidate, show:
- Name and full path.
- Current location/state (equipped, backpack, world, template, other).
- Relevant descendants, attachments, attributes, and value objects.
- Evidence used for classification.
- Candidate confidence.
- Compatibility status and unknowns.

Important distinctions:
- Finding a Tool does not prove it is a gun.
- Finding a RemoteEvent does not prove what arguments it expects or what behavior it performs.
- A normal LocalScript cannot read protected source code of other scripts at runtime.
- Runtime discovery and source-code analysis are different tasks.

Use automatic reanalysis when a Tool's relevant descendants change, without rescanning the entire DataModel each frame. Detach watchers when candidates are removed. Do not repeatedly rescore the same unchanged object.

Do not invoke unknown remotes or fabricate a weapon firing API. Mark a weapon interface as verified only when supported by actual accessible evidence and a real verification test.

## 14. Diagnostics

Preserve and improve local character diagnostics:
- Position and velocity observations.
- WalkSpeed and Humanoid state where available.
- Camera type, subject, and relevant distance information.
- Available ping values with clear units and error handling.
- Bounded position/velocity history.
- Sudden position-change and velocity-change detection.
- Diagnostic event log and clear/reset controls.
- Markers with automatic cleanup.
- Available frame-time/FPS estimates, labelled as estimates when necessary.

Do not infer that a local position discontinuity proves a server-side desync. The system observes client-accessible data only. Do not use Studio Network Simulator.

## 15. Misc and Client-Side Utilities

Add only functions that are actually supported by the selected client runtime and fit the existing project:
- Show/hide and minimize controls.
- Copy useful diagnostic text where supported.
- Clear logs.
- Reset one feature or restore all supported local settings.
- Rebuild the entity/weapon registry on demand.
- Toggle supported local visual effects.
- Display a concise capability/compatibility report.

Do not label client-only UI actions as authoritative administration. Server actions such as kicking another player, changing server-owned health, changing another player's authoritative position, granting items, or enforcing permissions cannot be reliably provided by a LocalScript alone. Mark them unavailable under the current constraint rather than faking them or invoking arbitrary remotes.

## 16. Rejoin

Preserve and improve existing rejoin UI and error feedback within standard Roblox API constraints.

- Show request/progress state.
- Prevent duplicate requests.
- Handle immediately thrown errors.
- Handle asynchronous teleport failures where supported by the standard client API.
- Distinguish requesting the current server from normal matchmaking.
- Never promise normal matchmaking will pick a different server.
- Clearly state when testing in Studio is unsupported and requires a published-experience playtest.

Do not assume executor-only teleport functions exist. Prefer known, documented APIs and report unsupported paths. Do not use teleport helpers to bypass experience access restrictions.

## 17. Performance, Lifecycle, and Cleanup

Fix the existing known defects before expanding functionality.

### Entity list rebuild defect
If the source contains `(entitiesDirty or true)`, remove that condition. It is always true and causes unnecessary recurring rebuilds.

### Dynamic event connections
Do not store unbounded references to connections attached to UI rows that are repeatedly destroyed. Give dynamic UI items their own connection lifecycle and disconnect connections before releasing their rows.

### Tool discovery
Reanalyse candidates when relevant descendants or attributes become available. Do not rely only on one early scan. Avoid full-DataModel rescans per frame.

### ESP projection
Handle near-plane/behind-camera cases correctly. Do not hide a complete target box merely because one corner projects behind the camera if a robust clipping strategy can be used.

### Error handling
A one-time log guard must not allow a broken render loop to continue failing indefinitely. Isolate recoverable per-entity failures and disable a feature after unrecoverable repeated failures, with a useful notification.

### Camera and respawn
Handle `CurrentCamera` replacement, character death, respawn, and feature stop. Avoid permanently fighting the normal camera controller. Restore only state modified by this script.

### General requirements
- Bound logs and histories.
- Reuse visual instances.
- Separate expensive discovery from per-frame rendering.
- Avoid duplicate render bindings and input listeners.
- Remove stale entity, Tool, GUI, and Highlight references.
- Cancel or guard delayed tasks during shutdown.
- Ensure emergency stop cleans up every feature.

## 18. Settings Persistence

Within a LocalScript, keep a central settings table with validated defaults and clear reset behavior.

Use detected executor-local file APIs for VEYL configuration persistence only when available and safe. Do not assume persistence APIs exist. If they are unavailable, keep settings for the current session and document the limitation. Never store secrets in local configuration.

Validate numeric limits and enumerated selections. Reject malformed RGB/HEX values and unsupported key codes gracefully.

## 19. Testing and Acceptance Criteria

Test all available behavior in Roblox Studio where possible, without using Network Simulator.

Required checks:
- Existing console functions still work.
- Tabs and panels open, close, and scroll correctly.
- The interface does not overlap or clip at tested screen sizes.
- Every visible toggle, slider, dropdown, color picker, text input, and action button changes a real setting/action.
- Key rebinding, collision handling, cancel, and defaults work.
- Invalid HEX/RGB input is rejected with useful feedback.
- Color changes update the correct overlay elements.
- ESP visuals appear, update, and disappear correctly.
- Target selection handles removed/dead entities.
- The Entities tab does not rebuild unconditionally every second.
- Dynamic UI refresh does not accumulate connections.
- Newly discovered Tools are updated when their relevant children arrive.
- Camera replacement and character respawn do not break bindings.
- Emergency stop removes active loops, visual objects, and temporary state.
- Rejoin errors are reported honestly.
- Music controls play only permitted Roblox audio assets, and loading/permission failures are visible.
- Queue, volume, transport controls, and cleanup are tested when assets are accessible.
- Spotify/YouTube Music are not falsely presented as playable inside a standard LocalScript; provider bookmarks are clearly distinguished from playback.
- No unsupported server-side behavior is claimed as implemented.

Use syntax checking, static inspection, linting, screenshots, or live Studio tests only if those tools are available. Record which checks were actually run. Do not claim unperformed tests passed.

## 20. Music Hub — Real Playback Within Roblox's Supported Audio System

Add a dedicated **Music** tab that is a real audio player, not a decorative mockup.

### Supported in-experience music player

Implement playback using standard Roblox `Sound` objects and permitted Roblox audio assets. Use `SoundService` for non-positional music when appropriate.

Required controls:
- Play / Pause / Resume / Stop.
- Previous / Next track.
- Queue and editable playlist for the current session.
- Shuffle and repeat modes.
- Volume slider with exact displayed value.
- Playback progress and elapsed/total time when the asset has loaded successfully.
- Track title, asset ID, loading state, and playback errors.
- Search and remove queue items.
- Favorite/pin a track for the current session.
- Mute control and reset-to-default behavior.
- Clean up sound instances and event connections on stop or console shutdown.

Track input:
- Accept a valid numeric Roblox audio asset ID or a valid `rbxassetid://...` identifier.
- Normalize input to a canonical asset ID.
- Reject malformed values clearly.
- Never assume an asset will load or that the experience has permission to use it.
- Show loading, permission failure, unavailable asset, and playback failure states accurately.
- Use only audio that the experience owner is authorized to use. Do not download, rip, proxy, or re-host copyrighted music from Spotify, YouTube, or other services.

The player must bind every visible control to real `Sound` state and actual supported behavior. Do not display fake track metadata, pretend to seek when the asset is not loaded, or claim that a provider's music is playing when only a Roblox asset is playing.

### Spotify and YouTube Music — honest integration boundary

The user requested Spotify, YouTube Music, and similar services. Investigate the platform constraints and implement only integrations genuinely supported by the required architecture.

Under the mandatory one-script-file, executor-aware client constraint:
- Do not claim that a Roblox `Sound` can play a Spotify or YouTube Music URL directly.
- Do not embed a website iframe, browser player, or JavaScript SDK inside a Roblox `ScreenGui`; a ScreenGui is not a web browser or HTML container.
- Do not use undocumented URL-launching tricks or runtime hooks to fake music integration. If the executor exposes a documented external URL-opening feature, use it only after an explicit user click to open a saved provider URL; this opens the provider externally and does not provide in-game playback.
- Do not make direct external streaming requests from the LocalScript.
- Do not store OAuth access tokens, refresh tokens, client secrets, or API keys in the LocalScript.
- Do not scrape, rip, or proxy music streams.

Provide a **Provider Bookmarks** area for user-entered Spotify/YouTube Music URLs. Store bookmarks in session memory or the detected local config store, validate URLs conservatively, and display the provider and saved label. If a documented runtime URL-opening capability is available, offer an explicit open button; label it as external navigation, not playback control.

If the user requires direct Spotify playback or a YouTube embedded player inside VEYL, explain that a client executor script is not a general-purpose browser and cannot simply import Spotify's Web Playback SDK or YouTube's IFrame Player API. Do not scrape, rip, decrypt, or proxy streams. A bookmark or external-launch feature is not the same as integrated playback.

Under this task's fixed constraints, the **working Music Hub must use permitted Roblox audio asset IDs**. Treat direct Spotify/YouTube Music playback as unavailable in this architecture, and state this limitation in the final report rather than delivering a fake integration.

## 21. Executor Runtime Requests and Feature Boundaries

The user explicitly requests an executor-aware implementation. Do not ignore this requirement or silently revert to a standard LocalScript-only assumption.

Use optional executor APIs for supported client-side capabilities such as local Drawing overlays, GUI parenting where documented by the runtime, clipboard conveniences, and local configuration persistence when available. Build the capability adapter described in Section 3.1 and provide fallbacks.

Actual client-side features may include:
- ESP-style visual overlays for client-accessible entities, implemented using the available and detected drawing method.
- Camera aim testing for explicitly configured test targets.
- UI, hotkeys, color pickers, dropdowns, sliders, and session/config persistence.
- Automatic weapon candidate discovery from accessible instances and metadata.
- Raycast and projectile diagnostics from known, accessible first-party code.
- Local position history and visual discrepancy diagnostics.
- Local visual/camera settings that can be restored.
- Music Hub playback for permitted Roblox audio assets, plus Spotify/YouTube Music bookmarks and optional external opening if supported.

Do not pretend a feature is genuinely implemented merely because an executor API exists. Executor APIs cannot automatically reveal protected script source or guarantee server authority.

Do not implement server-validation bypass, anti-cheat evasion, arbitrary remote invocation, fabricated hit reports, or techniques that force authoritative hits or another player's server-side state. For features such as true Magic Bullet, Silent Aim that redirects server-validated shots, or real server-side Desync manipulation, inspect the accessible weapon architecture and state the limits honestly instead of guessing remote calls or claiming unsupported success.

Use only capabilities needed for the task. Do not dump environment secrets, scrape credential stores, or collect unrelated runtime information.

## 22. Required Final Report

Deliver:
1. The complete updated LocalScript.
2. Exact placement instructions.
3. Summary of existing features preserved.
4. Summary of new controls and their real behavior, including Music Hub.
5. A list of bugs fixed and their root causes.
6. Tests actually performed and their results.
7. Runtime capabilities detected, executor-only utilities actually used, fallbacks, and features unavailable under the single-script/client-only constraint, including direct Spotify/YouTube Music playback and server-authoritative behavior.
8. Remaining risks and manual verification steps.
9. A short changelog suitable for resuming the project in another AI session.

## Final Instruction

Create a cohesive, dense, professional in-game control panel inspired by the supplied video references, but designed specifically for VEYL Control. The target runtime is executor-aware client execution using one script file, with capability detection and graceful fallbacks. The finished UI should offer multiple well-organized tabs, compact controls, real keybind editing, a genuine ESP color picker, dropdowns, search, sliders, a functional Roblox-audio Music Hub, runtime capability reporting, live feedback, and careful state management.

Do not force the user back to a standard LocalScript-only model when they have explicitly requested an executor-aware runtime. At the same time, do not fabricate server-authoritative behavior or implement server-validation bypasses. Inspect first, plan, implement incrementally, test what is genuinely testable, fix root causes, and report honestly. Prioritize real functionality, visual polish, performance, and stability over feature count or unsupported claims.
