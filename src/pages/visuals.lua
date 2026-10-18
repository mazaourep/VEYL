-- VEYL module: pages/visuals
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local LIMITS = V.LIMITS
    local Notify = V.Notify
    local Settings = V.Settings
    local UI = V.UI
    local Overlay = V.Overlay
    local ESP = V.ESP
    local Pages = V.Pages

    -- VISUALS ------------------------------------------------------------------
    function Pages.visuals()
        local page = UI.page("Visuals")
        local esp = UI.section(page, "left", "ESP")
        UI.toggle(esp, { key = "esp.enabled", label = "Enable ESP", desc = "Draw client-side overlays for eligible entities." })
        UI.dropdown(esp, { key = "esp.renderer", label = "Renderer", desc = "Auto uses the Drawing API when detected, otherwise ScreenGui frames." })
        local rendererRow = UI.info(esp, { label = "Active renderer", desc = "Renderer currently in use." })
        UI.slider(esp, { key = "esp.maxDistance", label = "Max visual distance", suffix = " st", desc = "Entities farther than this from the camera are hidden (studs)." })
        UI.toggle(esp, { key = "esp.boxes", label = "2D boxes", desc = "Screen-space bounding boxes (near-plane clipped)." })
        UI.toggle(esp, { key = "esp.names", label = "Name labels", desc = "Display name above each box." })
        UI.toggle(esp, { key = "esp.distance", label = "Distance and type", desc = "Type, distance in studs, and visibility status below each box." })
        UI.toggle(esp, { key = "esp.health", label = "Health bars", desc = "Humanoid health bar beside each box." })
        UI.toggle(esp, { key = "esp.tracers", label = "Tracers", desc = "Lines from the tracer origin to each entity." })
        UI.toggle(esp, { key = "esp.offscreen", label = "Off-screen arrows", desc = "Edge arrows pointing toward entities outside the view." })
        UI.toggle(esp, { key = "esp.highlight", label = "Highlight", desc = "Roblox Highlight fill/outline for the nearest " .. LIMITS.highlights .. " entities (engine limit)." })
        UI.toggle(esp, { key = "esp.visibility", label = "Occlusion check", desc = "Raycast visibility at a bounded rate (10 checks per frame, cached 0.15 s)." })

        local filters = UI.section(page, "left", "Filters")
        UI.toggle(filters, { key = "esp.showTargets", label = "Test targets", desc = "Models tagged VEYLTestTarget." })
        UI.toggle(filters, { key = "esp.showNpcs", label = "NPCs", desc = "Live non-player Humanoid models in Workspace." })
        UI.toggle(filters, { key = "esp.showPlayers", label = "Allowlisted players", desc = "Players appear only after you allowlist them in Entities." })

        local style = UI.section(page, "left", "Style")
        UI.slider(style, { key = "esp.textSize", label = "Text size", suffix = " px", desc = "Label text size." })
        UI.slider(style, { key = "esp.boxTransparency", label = "Box transparency", suffix = "%", desc = "0% is fully opaque." })
        UI.slider(style, { key = "esp.tracerTransparency", label = "Tracer transparency", suffix = "%", desc = "0% is fully opaque." })
        UI.dropdown(style, { key = "esp.tracerOrigin", label = "Tracer origin", desc = "Where tracer lines start." })
        UI.dropdown(style, { key = "esp.hlDepth", label = "Highlight depth", desc = "Occluded hides the highlight behind walls; Always on top shows it through them." })
        UI.slider(style, { key = "esp.hlFillTransparency", label = "Highlight fill transparency", suffix = "%", desc = "Highlight fill transparency." })
        UI.slider(style, { key = "esp.hlOutlineTransparency", label = "Highlight outline transparency", suffix = "%", desc = "Highlight outline transparency." })

        local colors = UI.section(page, "right", "Colors")
        UI.color(colors, { key = "color.box", label = "Boxes", desc = "Box and off-screen arrow color." })
        UI.color(colors, { key = "color.name", label = "Names and labels", desc = "Name and distance label color." })
        UI.color(colors, { key = "color.tracer", label = "Tracers", desc = "Tracer line color." })
        UI.color(colors, { key = "color.health", label = "Health bar", desc = "Health color at full health; it blends to red as health drops." })
        UI.color(colors, { key = "color.target", label = "Target indicator", desc = "Aim Lab target indicator." })
        UI.color(colors, { key = "color.fov", label = "FOV circle", desc = "Aim Lab FOV circle." })
        UI.color(colors, { key = "color.hlFill", label = "Highlight fill", desc = "Highlight fill color." })
        UI.color(colors, { key = "color.hlOutline", label = "Highlight outline", desc = "Highlight outline color." })
        UI.toggle(colors, { key = "esp.visColors", label = "Visibility colors", desc = "Color boxes, tracers and arrows by visible/occluded state (needs the occlusion check)." })
        UI.color(colors, { key = "color.visible", label = "Visible", desc = "Used when the entity is in line of sight." })
        UI.color(colors, { key = "color.occluded", label = "Occluded", desc = "Used when the entity is behind geometry." })
        UI.toggle(colors, { key = "esp.typeColors", label = "Entity-type colors", desc = "Color boxes, tracers, arrows and highlight fill by player/NPC/test target." })
        UI.color(colors, { key = "color.player", label = "Players", desc = "Entity-type color for allowlisted players." })
        UI.color(colors, { key = "color.npc", label = "NPCs", desc = "Entity-type color for NPCs." })
        UI.color(colors, { key = "color.testTarget", label = "Test targets", desc = "Entity-type color for tagged test targets." })
        UI.note(colors, "Precedence for boxes, tracers and arrows: visibility colors › entity-type colors › element color. Names always use the name color.")
        UI.button(colors, {
            text = "Reset all colors",
            desc = "Restore every color to its default.",
            callback = function()
                Settings.resetPrefix("color.")
                Notify.push("Colors restored to defaults.", "ok")
            end,
        })

        page.onUpdate = function()
            local label, color = Overlay.modeText()
            rendererRow.set(Settings.get("esp.enabled") and (label .. " · " .. ESP.drawn .. " drawn") or label, color)
        end
    end
end
