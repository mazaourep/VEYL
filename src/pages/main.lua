-- VEYL module: pages/main
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Cap = V.Cap
    local Settings = V.Settings
    local Binds = V.Binds
    local Persist = V.Persist
    local UI = V.UI
    local Overlay = V.Overlay
    local Entities = V.Entities
    local ESP = V.ESP
    local Aim = V.Aim
    local World = V.World
    local Weapons = V.Weapons
    local Diag = V.Diag
    local Music = V.Music
    local Features = V.Features
    local Root = V.Root
    local T = V.T
    local Pages = V.Pages

    -- MAIN ---------------------------------------------------------------------
    function Pages.main()
        local page = UI.page("Main")
        local status = UI.section(page, "left", "Status")
        local rows = {
            runtime = UI.info(status, { label = "Runtime", desc = "Detected runtime. See Misc › Runtime capabilities for details." }),
            aim = UI.info(status, { label = "Aim Lab", desc = "Camera aim testing for eligible test targets." }),
            target = UI.info(status, { label = "Selected target", desc = "Explicit Aim Lab selection (C cycles, V clears by default)." }),
            esp = UI.info(status, { label = "ESP", desc = "Client-side overlays for eligible entities." }),
            world = UI.info(status, { label = "World overrides", desc = "Local lighting overrides currently applied." }),
            music = UI.info(status, { label = "Music", desc = "Music Hub playback state." }),
            entities = UI.info(status, { label = "Entities tracked", desc = "Live character models in Workspace." }),
            weapons = UI.info(status, { label = "Tool candidates", desc = "Tools discovered automatically; see Weapons." }),
            diag = UI.info(status, { label = "Diagnostics", desc = "Frame-rate estimate and ping." }),
            config = UI.info(status, { label = "Configuration", desc = "Where settings are stored." }),
        }

        local quick = UI.section(page, "right", "Quick toggles")
        UI.toggle(quick, { key = "aim.enabled", label = "Aim Lab", desc = "Arm camera aim testing for eligible targets." })
        UI.toggle(quick, { key = "esp.enabled", label = "ESP overlays", desc = "Boxes, labels, health bars and tracers for eligible entities." })
        UI.toggle(quick, { key = "world.enabled", label = "World overrides", desc = "Apply the local lighting settings from the World tab." })
        UI.toggle(quick, { key = "diag.enabled", label = "Diagnostics sampling", desc = "Sample local position and velocity at 10 Hz." })
        UI.toggle(quick, { key = "diag.markers", label = "Discontinuity markers", desc = "Place temporary local markers where a position jump was observed." })
        UI.toggle(quick, { key = "music.muted", label = "Mute music", desc = "Silence the Music Hub without stopping it." })

        local actions = UI.section(page, "right", "Actions")
        UI.buttons(actions, {
            { text = "Cycle target", callback = Aim.cycle },
            { text = "Clear target", callback = function()
                Aim.clear(true)
            end },
        }, "Cycle through eligible Aim Lab targets or clear the selection.")
        UI.button(actions, {
            text = "Restore defaults…",
            desc = "Reset every setting to its default after confirmation. Keybinds are kept.",
            callback = function()
                UI.confirm("Restore defaults", "Reset all settings to their defaults? Active features will be switched off. Keybinds are kept.", "Restore", Features.restoreDefaults)
            end,
        })
        UI.button(actions, {
            text = "EMERGENCY STOP",
            style = "danger",
            desc = "Stop every feature loop, restore lighting, stop audio and remove temporary visuals.",
            callback = function()
                Features.emergencyStop("button")
            end,
        })

        local hotkeys = UI.section(page, "right", "Hotkeys")
        local hotkeyNote = UI.note(hotkeys, "")
        local function renderHotkeys()
            local lines = {}
            for _, action in ipairs(Binds.actions) do
                table.insert(lines, string.format("%-10s %s", Binds.display(Binds.map[action.id]), action.label))
            end
            hotkeyNote.set(table.concat(lines, "\n"), T.muted)
        end
        renderHotkeys()
        Root:give(Binds.changed:Connect(renderHotkeys))

        page.onUpdate = function()
            rows.runtime.set(Cap.modeText(), Cap.executorAware and T.cyan or T.muted)
            if Settings.get("aim.enabled") then
                local activation = Settings.get("aim.activation") == "Always on" and "always on" or ("hold " .. Binds.display(Binds.map.aimHold))
                rows.aim.set((Aim.current and ("Tracking " .. Aim.current.name) or "Armed") .. " · " .. activation, T.ok)
            else
                rows.aim.set("Off", T.muted)
            end
            rows.target.set(Aim.selected and Aim.selected.name or "None (auto within FOV)", Aim.selected and T.text or T.muted)
            if Settings.get("esp.enabled") then
                rows.esp.set(string.format("On · %s · %d drawn", tostring(Overlay.mode), ESP.drawn), T.ok)
            else
                rows.esp.set("Off", T.muted)
            end
            rows.world.set(Settings.get("world.enabled") and string.format("On · %d overrides", World.overrideCount()) or "Off", Settings.get("world.enabled") and T.ok or T.muted)
            rows.music.set(Music.status, Music.statusColor)
            local players, npcs, targets = 0, 0, 0
            for _, entity in pairs(Entities.byModel) do
                if entity.kind == "Player" then
                    players += 1
                elseif entity.kind == "NPC" then
                    npcs += 1
                else
                    targets += 1
                end
            end
            rows.entities.set(string.format("%d (%d players · %d NPC · %d test)%s", Entities.count, players, npcs, targets, Entities.scanning and " · scanning" or ""))
            local ranged = 0
            for _, record in pairs(Weapons.byTool) do
                if record.ranged then
                    ranged += 1
                end
            end
            rows.weapons.set(string.format("%d found · %d likely ranged", Weapons.count, ranged))
            if Diag.maid then
                local network = Diag.ping()
                rows.diag.set(string.format("%d FPS (est.) · ping %s", Diag.fps(), network), T.text)
            else
                rows.diag.set("Off", T.muted)
            end
            rows.config.set(Persist.status, Persist.available and T.text or T.warn)
        end
        page.updateInterval = 0.5
    end
end
