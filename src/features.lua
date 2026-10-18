-- VEYL module: features
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local TeleportService = V.TeleportService
    local LocalPlayer = V.LocalPlayer
    local Util = V.Util
    local Log = V.Log
    local Notify = V.Notify
    local Cap = V.Cap
    local Settings = V.Settings
    local Binds = V.Binds
    local UI = V.UI
    local Popup = V.Popup
    local Overlay = V.Overlay
    local ESP = V.ESP
    local Aim = V.Aim
    local World = V.World
    local Diag = V.Diag
    local Music = V.Music
    local Rejoin = V.Rejoin
    local Features = V.Features
    local Session = V.Session
    local T = V.T

    ----------------------------------------------------------------------------
    -- 16. Rejoin (documented TeleportService APIs only)
    ----------------------------------------------------------------------------

    Rejoin.busy = false
    Rejoin.state = "Idle"
    Rejoin.token = 0

    function Rejoin.request(mode)
        if Rejoin.busy then
            Notify.push("A rejoin request is already in progress.", "warn")
            return
        end
        if Cap.studio then
            Notify.push("Teleports do not work in Studio. Test rejoin in a published experience.", "warn")
            return
        end
        if mode == "server" and (type(game.JobId) ~= "string" or game.JobId == "") then
            Notify.push("This server has no JobId to rejoin.", "warn")
            return
        end
        Rejoin.busy = true
        Rejoin.token += 1
        local token = Rejoin.token
        Rejoin.state = mode == "server" and "Requesting this server…" or "Requesting matchmaking…"
        UI.flashStatus("● " .. Rejoin.state, T.warn, 6)
        Log.add("info", "Rejoin requested (" .. (mode == "server" and "current server" or "matchmaking") .. ").")
        local ok, err = pcall(function()
            if mode == "server" then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            else
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)
        if not ok then
            Rejoin.busy = false
            Rejoin.state = "Failed: " .. Util.truncate(tostring(err), 60)
            Notify.push("Rejoin request failed: " .. tostring(err), "error")
            return
        end
        task.delay(30, function()
            if Session.alive and Rejoin.busy and token == Rejoin.token then
                Rejoin.busy = false
                Rejoin.state = "No teleport progress after 30 s"
                Notify.push("Rejoin did not start within 30 seconds; the request may have been rejected.", "warn")
            end
        end)
    end

    function Rejoin.onFailed(player, result, message)
        if player ~= LocalPlayer then
            return
        end
        Rejoin.busy = false
        Rejoin.state = "Failed: " .. tostring(result and result.Name or result)
        Notify.push("Teleport failed (" .. tostring(result and result.Name or result) .. "): " .. tostring(message), "error")
    end

    ----------------------------------------------------------------------------
    -- Feature-level controls (emergency stop, resets)
    ----------------------------------------------------------------------------

    local FEATURE_PREFIXES = {
        ["Aim Lab"] = "aim.",
        ["Visuals"] = "esp.",
        ["Colors"] = "color.",
        ["World"] = "world.",
        ["Music"] = "music.",
        ["Diagnostics"] = "diag.",
        ["Interface"] = "ui.",
    }
    Features.resetTargets = { "Aim Lab", "Visuals", "Colors", "World", "Music", "Diagnostics", "Interface" }

    function Features.emergencyStop(source)
        Binds.cancelCapture()
        Popup.close()
        UI.dragging = nil
        Settings.set("aim.enabled", false)
        Settings.set("esp.enabled", false)
        Settings.set("world.enabled", false)
        Settings.set("diag.enabled", false)
        -- Direct calls as well, in case a listener failed earlier.
        pcall(Aim.stop)
        pcall(ESP.stop)
        pcall(World.restoreAll)
        pcall(Diag.stop)
        Aim.clear(false)
        Music.stop()
        Overlay.clearAll()
        UI.flashStatus("● Stopped", T.bad, 4)
        Log.add("warn", "Emergency stop (" .. tostring(source) .. "): Aim Lab, ESP, world overrides, music and diagnostics stopped.")
        Notify.push("Emergency stop: every feature is off and temporary visuals were removed.", "ok")
    end

    function Features.resetFeature(name)
        local prefix = FEATURE_PREFIXES[name]
        if not prefix then
            return
        end
        Settings.resetPrefix(prefix)
        if name == "Aim Lab" then
            Aim.clear(false)
        end
        Notify.push(name .. " settings restored to defaults.", "ok")
    end

    function Features.restoreDefaults()
        Settings.resetPrefix(nil)
        Aim.clear(false)
        Notify.push("All settings restored to defaults. Keybinds are unchanged.", "ok")
    end

    V.FEATURE_PREFIXES = FEATURE_PREFIXES
end
