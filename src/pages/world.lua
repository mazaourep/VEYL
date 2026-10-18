-- VEYL module: pages/world
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Notify = V.Notify
    local Settings = V.Settings
    local UI = V.UI
    local World = V.World
    local T = V.T
    local Pages = V.Pages

    -- WORLD --------------------------------------------------------------------
    function Pages.world()
        local page = UI.page("World")
        local lighting = UI.section(page, "left", "Lighting")
        UI.toggle(lighting, { key = "world.enabled", label = "Enable world overrides", desc = "Apply these values locally. Disabling restores what VEYL changed." })
        UI.slider(lighting, { key = "world.brightness", label = "Brightness", desc = "Local Lighting.Brightness." })
        UI.slider(lighting, { key = "world.exposure", label = "Exposure", desc = "Local Lighting.ExposureCompensation." })
        UI.toggle(lighting, { key = "world.clockOverride", label = "Override time of day", desc = "Hold Lighting.ClockTime at the value below (the server may change it again)." })
        UI.slider(lighting, { key = "world.clockTime", label = "Time of day", suffix = " h", desc = "Lighting.ClockTime while the override is on." })
        UI.toggle(lighting, { key = "world.shadows", label = "Global shadows", desc = "Local Lighting.GlobalShadows." })
        UI.color(lighting, { key = "world.ambient", label = "Ambient", desc = "Local Lighting.Ambient." })

        local restore = UI.section(page, "left", "Restore")
        local countRow = UI.info(restore, { label = "Active overrides", desc = "Properties and effects VEYL currently controls." })
        UI.button(restore, {
            text = "Restore original visuals",
            desc = "Turn overrides off and restore every property VEYL changed.",
            callback = function()
                if Settings.get("world.enabled") then
                    Settings.set("world.enabled", false)
                else
                    World.restoreAll()
                end
                Notify.push("Original local visuals restored.", "ok")
            end,
        })
        UI.note(restore, "Restore rule: a property returns to its snapshot only if it still has the value VEYL wrote. If the game changed it meanwhile, the game's value is kept. Changes are local to this client.")

        local correction = UI.section(page, "right", "Color correction")
        UI.toggle(correction, { key = "world.ccEnabled", label = "Enable color correction", desc = "Adds a local ColorCorrectionEffect owned by VEYL." })
        UI.slider(correction, { key = "world.saturation", label = "Saturation", suffix = "%", desc = "−100% is grayscale." })
        UI.slider(correction, { key = "world.contrast", label = "Contrast", suffix = "%", desc = "Local contrast." })
        UI.color(correction, { key = "world.tint", label = "Tint", desc = "Color tint multiplier." })

        local bloom = UI.section(page, "right", "Bloom")
        UI.toggle(bloom, { key = "world.bloomEnabled", label = "Enable bloom", desc = "Adds a local BloomEffect owned by VEYL." })
        UI.slider(bloom, { key = "world.bloomIntensity", label = "Intensity", suffix = "%", desc = "Bloom intensity." })
        UI.slider(bloom, { key = "world.bloomSize", label = "Size", desc = "Bloom size." })
        UI.slider(bloom, { key = "world.bloomThreshold", label = "Threshold", desc = "Brightness threshold for bloom." })

        local atmosphere = UI.section(page, "right", "Atmosphere / fog")
        UI.toggle(atmosphere, { key = "world.atmosEnabled", label = "Override atmosphere", desc = "Edits the game's Atmosphere (restorable) or adds a local one if none exists." })
        UI.slider(atmosphere, { key = "world.atmosDensity", label = "Density", desc = "Atmosphere.Density (fog thickness)." })
        UI.slider(atmosphere, { key = "world.atmosHaze", label = "Haze", desc = "Atmosphere.Haze." })

        local sky = UI.section(page, "right", "Sky presets")
        local skyRow = UI.info(sky, { label = "Sky presets", value = "Unavailable", desc = "No verified sky assets are bundled, so presets are not offered." })
        skyRow.set("Unavailable", T.dim)
        skyRow.setEnabled(false, "Unavailable: VEYL ships no verified, licensed skybox assets. Fake presets are not shown.")

        page.onUpdate = function()
            local count = World.overrideCount()
            countRow.set(Settings.get("world.enabled") and (count .. " active") or "None (off)", count > 0 and T.ok or T.muted)
        end
    end
end
