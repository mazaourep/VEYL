-- VEYL module: app
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local RunService = V.RunService
    local UserInputService = V.UserInputService
    local TeleportService = V.TeleportService
    local Workspace = V.Workspace
    local LocalPlayer = V.LocalPlayer
    local VERSION = V.VERSION
    local Log = V.Log
    local Notify = V.Notify
    local Cap = V.Cap
    local Settings = V.Settings
    local Binds = V.Binds
    local Persist = V.Persist
    local UI = V.UI
    local Popup = V.Popup
    local Overlay = V.Overlay
    local Entities = V.Entities
    local ESP = V.ESP
    local Aim = V.Aim
    local World = V.World
    local Weapons = V.Weapons
    local Diag = V.Diag
    local Music = V.Music
    local Rejoin = V.Rejoin
    local Features = V.Features
    local App = V.App
    local Session = V.Session
    local Root = V.Root
    local isPress = V.isPress
    local Pages = V.Pages

    ----------------------------------------------------------------------------
    -- 19. Lifecycle: input router, feature wiring, startup and shutdown
    ----------------------------------------------------------------------------

    function App.dispatch(action)
        if action == "toggleUI" then
            UI.setOpen(not UI.open)
        elseif action == "toggleAim" then
            local enabled = not Settings.get("aim.enabled")
            Settings.set("aim.enabled", enabled)
            Notify.push(enabled and "Aim Lab armed." or "Aim Lab off.", "info")
        elseif action == "toggleESP" then
            local enabled = not Settings.get("esp.enabled")
            Settings.set("esp.enabled", enabled)
            Notify.push(enabled and "ESP on." or "ESP off.", "info")
        elseif action == "cycleTarget" then
            Aim.cycle()
        elseif action == "clearTarget" then
            Aim.clear(true)
        elseif action == "emergencyStop" then
            Features.emergencyStop("hotkey " .. Binds.display(Binds.map.emergencyStop))
        end
    end

    function App.shutdown(reason)
        if not Session.alive then
            return
        end
        -- Flush only unsaved changes, so a config edited on disk is not overwritten on re-execution.
        if Persist.dirty and Persist.available and Settings.get("ui.autosave") then
            Persist.token += 1
            pcall(Persist.save, false)
        end
        local steps = {
            Binds.cancelCapture,
            Popup.close,
            Aim.stop,
            ESP.stop,
            World.restoreAll,
            Music.stop,
            Diag.stop,
            Weapons.stop,
            Entities.stop,
            Overlay.clearAll,
        }
        for _, step in ipairs(steps) do
            local ok, err = pcall(step)
            if not ok then
                warn("[VEYL] Shutdown step failed: " .. tostring(err))
            end
        end
        Session.alive = false
        if UI.blur then
            UI.blur:Destroy()
            UI.blur = nil
        end
        Root:clean()
        if App.fxFolder then
            App.fxFolder:Destroy()
            App.fxFolder = nil
        end
        if Cap.shared.__VEYL_SESSION == App.handle then
            Cap.shared.__VEYL_SESSION = nil
        end
        print("[VEYL] Session ended (" .. tostring(reason) .. ").")
    end

    function App.wire()
        -- Single input router: key capture first, then popups, then hotkeys.
        Root:connect(UserInputService.InputBegan, function(input, gameProcessed)
            if Binds.capturing then
                Binds.handleCapture(input)
                return
            end
            if input.KeyCode == Enum.KeyCode.Escape and Popup.isOpen() then
                Popup.close()
                return
            end
            if gameProcessed or UserInputService:GetFocusedTextBox() then
                return
            end
            local action = Binds.match(input)
            if action then
                App.dispatch(action)
            end
        end)
        Root:connect(UserInputService.InputChanged, function(input)
            local dragging = UI.dragging
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local ok, err = pcall(dragging.update, input.Position)
                if not ok then
                    UI.dragging = nil
                    Log.add("warn", "Drag handler failed: " .. tostring(err))
                end
            end
        end)
        Root:connect(UserInputService.InputEnded, function(input)
            if isPress(input) then
                UI.dragging = nil
            end
        end)

        -- Feature switches.
        Root:give(Settings.on("aim.enabled", function(enabled)
            if enabled then
                Aim.start()
            else
                Aim.stop()
                Aim.clear(false)
            end
        end))
        Root:give(Settings.on("esp.enabled", function(enabled)
            if enabled then
                ESP.start()
            else
                ESP.stop()
            end
        end))
        Root:give(Settings.on("esp.renderer", function()
            Overlay.ensureMode()
        end))
        Root:give(Overlay.reset:Connect(function()
            ESP.dropVisuals()
            Aim.dropVisuals()
        end))
        Root:give(Settings.on("world.enabled", function(enabled)
            if enabled then
                World.apply()
                Log.add("info", "World overrides applied locally.")
            else
                World.restoreAll()
                Log.add("info", "World overrides removed; original values restored where unchanged by the game.")
            end
        end))
        Root:give(Settings.on("diag.enabled", function(enabled)
            if enabled then
                Diag.start()
            else
                Diag.stop()
            end
        end))
        Root:give(Settings.on("diag.markers", function(enabled)
            if not enabled then
                Diag.clearMarkers()
            end
        end))
        Root:give(Settings.on("music.volume", Music.applyVolume))
        Root:give(Settings.on("music.muted", Music.applyVolume))
        Root:give(Settings.changed:Connect(function(key)
            local prefix = string.match(key, "^(%a+)%.")
            if prefix == "world" and key ~= "world.enabled" and Settings.get("world.enabled") then
                local ok, err = pcall(World.apply)
                if not ok then
                    Log.add("warn", "World update failed: " .. tostring(err))
                end
            elseif (prefix == "esp" or prefix == "color") and ESP.maid then
                pcall(ESP.updateHighlights)
            end
            local spec = Settings.schema[key]
            if spec and not spec.session then
                Persist.schedule()
            end
        end))

        -- Entity lifecycle hooks shared by ESP and Aim Lab.
        Root:give(Entities.removed:Connect(function(entity)
            ESP.forget(entity)
            if Aim.selected == entity then
                Aim.clear(false)
                Notify.push(entity.name .. " was removed; the Aim Lab target was cleared.", "info")
            end
            if Aim.current == entity then
                Aim.current = nil
            end
        end))
        Root:give(Entities.changed:Connect(function(entity)
            if entity and Aim.selected == entity and not Aim.eligible(entity) then
                Aim.clear(false)
                Notify.push(entity.name .. " is no longer in the Aim Lab scope; target cleared.", "info")
            end
        end))

        -- Camera replacement and teleport results.
        Root:connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
            Log.add("info", "Workspace.CurrentCamera was replaced; Aim Lab and overlays follow the new camera.")
        end)
        Root:connect(TeleportService.TeleportInitFailed, Rejoin.onFailed)
        Root:connect(LocalPlayer.OnTeleport, function(teleportState)
            Log.add("info", "Teleport state: " .. tostring(teleportState and teleportState.Name or teleportState))
            if teleportState == Enum.TeleportState.Failed then
                Rejoin.busy = false
                Rejoin.state = "Failed"
            end
        end)

        -- Interface refresh: title status plus the visible tab only.
        local elapsed = 0
        Root:connect(RunService.Heartbeat, function(deltaTime)
            elapsed += deltaTime
            if elapsed >= 0.1 then
                elapsed = 0
                UI.refreshStatus()
                UI.updatePage(false)
            end
        end)

        if Cap.script then
            pcall(function()
                Root:connect(Cap.script.Destroying, function()
                    App.shutdown("script destroyed")
                end)
            end)
        end
    end

    -- Startup ------------------------------------------------------------------
    App.handle = {
        version = VERSION,
        shutdown = function(reason)
            App.shutdown(reason)
        end,
    }

    Persist.load(false)
    UI.build()
    Cap.buildReport(UI.parentKind)
    Pages.main()
    Pages.aim()
    Pages.visuals()
    Pages.world()
    Pages.entities()
    Pages.weapons()
    Pages.music()
    Pages.diagnostics()
    Pages.misc()
    Pages.settings()
    App.wire()
    Entities.start()
    Weapons.start()
    if Settings.get("diag.enabled") then
        Diag.start()
    end
    UI.select("Main")
    UI.updateBlur()
    Cap.shared.__VEYL_SESSION = App.handle

    Log.add("info", "VEYL Control " .. VERSION .. " loaded · " .. Cap.modeText() .. " · GUI in " .. UI.parentKind .. ".")
    if (Session.legacyRemoved or 0) > 0 then
        Log.add("info", "Removed " .. Session.legacyRemoved .. " leftover instance(s) from an earlier VEYL or Nova Admin Console run.")
    end
    Notify.push("VEYL Control ready. " .. Binds.display(Binds.map.toggleUI) .. " toggles the console.", "ok")
    if not Cap.drawingNew then
        Notify.push("Drawing API not detected: overlays use the ScreenGui fallback.", "info")
    end
    if not Persist.available then
        Notify.push("No file API detected: settings last for this session only.", "info")
    end
end
