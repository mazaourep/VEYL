-- VEYL module: pages/settings
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local VERSION = V.VERSION
    local Notify = V.Notify
    local Cap = V.Cap
    local Binds = V.Binds
    local Persist = V.Persist
    local UI = V.UI
    local Features = V.Features
    local T = V.T
    local Pages = V.Pages

    -- SETTINGS -----------------------------------------------------------------
    function Pages.settings()
        local page = UI.page("Settings")
        local keys = UI.section(page, "left", "Keybinds")
        for _, action in ipairs(Binds.actions) do
            UI.keybind(keys, action.id)
        end
        UI.button(keys, { text = "Reset all keybinds", desc = "Restore every default binding.", callback = function()
            Binds.cancelCapture()
            Binds.resetAll()
            Notify.push("Keybinds restored to defaults.", "ok")
        end })
        UI.note(keys, "Hotkeys are ignored while you type in a text box or while a key is being captured. Collisions ask before reassigning; the emergency stop cannot be unbound.")

        local interface = UI.section(page, "left", "Interface")
        UI.toggle(interface, { key = "ui.translucent", label = "Translucent panel", desc = "Slightly see-through panel background." })
        UI.toggle(interface, { key = "ui.blur", label = "Background blur", desc = "Blur the 3D view while the console is open (off by default so gameplay stays visible)." })
        UI.slider(interface, { key = "ui.scale", label = "Interface scale", suffix = "%", desc = "Scale the console for your resolution." })
        UI.toggle(interface, { key = "ui.toasts", label = "Info notifications", desc = "Warnings and errors are always shown." })
        UI.button(interface, { text = "Center window", desc = "Move the console back to the middle of the screen.", callback = function()
            local screen = UI.gui.AbsoluteSize
            local size = UI.window.AbsoluteSize
            UI.window.Position = UDim2.fromOffset(math.floor((screen.X - size.X) / 2), math.floor((screen.Y - size.Y) / 2))
        end })

        local config = UI.section(page, "right", "Configuration")
        local statusRow = UI.info(config, { label = "Storage", desc = "Config file path, or session memory when no file API exists." })
        local autosave = UI.toggle(config, { key = "ui.autosave", label = "Auto-save", desc = "Save 1.5 s after a change when a file API exists." })
        local saveButtons = UI.buttons(config, {
            { text = "Save now", style = "primary", callback = function()
                Persist.save(true)
            end },
            { text = "Reload", callback = function()
                Persist.load(true)
            end },
        }, "Write or re-read " .. tostring(Cap.configPath or "the config file") .. ".")
        if not Persist.available then
            autosave.setEnabled(false, "Unavailable: this runtime exposes no file API. Settings last for this session only.")
            saveButtons.setEnabled(false, "Unavailable: this runtime exposes no file API.")
        end
        UI.button(config, { text = "Reset all settings…", style = "danger", desc = "Restore every setting to its default.", callback = function()
            UI.confirm("Reset all settings", "Restore every setting to its default? Keybinds are kept.", "Reset", Features.restoreDefaults)
        end })
        UI.note(config, "Saved: settings, keybinds, music queue IDs and provider bookmarks. Never saved: on/off state of Aim Lab, ESP and World, the player allowlist, or any credential. Malformed files and values are rejected.")

        local about = UI.section(page, "right", "About")
        UI.note(about, "VEYL Control " .. VERSION .. " — Advanced Client Toolkit.\nTag training dummies with the CollectionService tag VEYLTestTarget. An optional string attribute VEYLTargetName sets their label.")

        page.onUpdate = function()
            statusRow.set(Persist.status, Persist.available and T.text or T.warn)
        end
    end
end
