-- VEYL module: pages/misc
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Log = V.Log
    local Notify = V.Notify
    local Cap = V.Cap
    local UI = V.UI
    local Entities = V.Entities
    local Weapons = V.Weapons
    local Diag = V.Diag
    local Rejoin = V.Rejoin
    local Features = V.Features
    local App = V.App
    local T = V.T
    local STATUS_COLORS = V.STATUS_COLORS
    local Pages = V.Pages

    -- MISC ---------------------------------------------------------------------
    function Pages.misc()
        local page = UI.page("Misc")
        local capabilities = UI.section(page, "left", "Runtime capabilities")
        for _, row in ipairs(Cap.report) do
            local control = UI.info(capabilities, { label = row.name, desc = row.detail })
            control.set(row.status .. " · " .. row.detail, STATUS_COLORS[row.status] or T.text)
        end
        UI.note(capabilities, "Optional executor APIs are detected once at startup and never assumed. Every one has a fallback or is reported as unavailable.")

        local utilities = UI.section(page, "left", "Utilities")
        UI.button(utilities, { text = "Copy diagnostic summary", desc = "Runtime, capabilities, performance, counts and recent log lines.", callback = function()
            UI.copy("Diagnostic summary", Diag.summary())
        end })
        UI.buttons(utilities, {
            { text = "Rebuild entities", callback = Entities.rebuild },
            { text = "Rescan tools", callback = Weapons.rescan },
        }, "Rediscover live entities or tool candidates on demand.")
        UI.button(utilities, { text = "Clear event log", desc = "Remove the bounded diagnostic log.", callback = function()
            Log.clear()
            Notify.push("Event log cleared.", "ok")
        end })
        local resetTarget = Features.resetTargets[1]
        UI.dropdown(utilities, {
            label = "Feature to reset",
            desc = "Choose which group of settings to restore.",
            options = function()
                return Features.resetTargets
            end,
            get = function()
                return resetTarget
            end,
            set = function(value)
                resetTarget = value
            end,
        })
        UI.button(utilities, { text = "Reset selected feature", desc = "Restore that group's settings to defaults (this also switches it off).", callback = function()
            Features.resetFeature(resetTarget)
        end })

        local rejoin = UI.section(page, "right", "Rejoin")
        local rejoinState = UI.info(rejoin, { label = "State", desc = "Teleport request progress." })
        UI.button(rejoin, { text = "Rejoin this server", style = "primary", desc = "TeleportToPlaceInstance with the current JobId. Fails for full, closing or reserved servers.", callback = function()
            Rejoin.request("server")
        end })
        UI.button(rejoin, { text = "Rejoin via matchmaking", desc = "Teleport to this place; Roblox may pick the same or a different server.", callback = function()
            Rejoin.request("matchmaking")
        end })
        UI.note(rejoin, "Studio does not support teleports; use a published experience. Errors are reported as they occur, including asynchronous TeleportInitFailed results.")

        local authority = UI.section(page, "right", "Server-side actions")
        local unavailable = {
            { "Kick a player", "Requires server code; a client cannot remove another player." },
            { "Set another player's health", "Health is server-authoritative." },
            { "Move other players", "Other characters' positions are owned by the server or their clients." },
            { "Grant items", "Inventory changes require server code." },
            { "Enforce permissions", "Permissions must be checked on the server." },
            { "Shot redirection / silent aim", "Would require forging server-validated hits; not implemented." },
        }
        for _, item in ipairs(unavailable) do
            local control = UI.info(authority, { label = item[1], desc = item[2] })
            control.set("Unavailable", T.dim)
            control.setEnabled(false, "Unavailable under the client-only constraint: " .. item[2])
        end

        local session = UI.section(page, "right", "Session")
        UI.button(session, { text = "Unload VEYL", style = "danger", desc = "Stop everything, restore lighting and remove every VEYL instance.", callback = function()
            UI.confirm("Unload VEYL", "Stop all features, restore local visuals and remove the console? Re-execute the script to start again.", "Unload", function()
                App.shutdown("unloaded by user")
            end)
        end })

        page.onUpdate = function()
            rejoinState.set(Rejoin.state, Rejoin.busy and T.warn or T.text)
        end
    end
end
