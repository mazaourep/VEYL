-- VEYL module: pages/aimlab
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Settings = V.Settings
    local UI = V.UI
    local Entities = V.Entities
    local Aim = V.Aim
    local T = V.T
    local Pages = V.Pages

    -- AIM LAB ------------------------------------------------------------------
    function Pages.aim()
        local page = UI.page("Aim Lab")
        local main = UI.section(page, "left", "Aim Lab")
        UI.toggle(main, { key = "aim.enabled", label = "Enable Aim Lab", desc = "Turns the client camera toward eligible targets. Camera only; weapons may not follow it." })
        UI.dropdown(main, { key = "aim.activation", label = "Activation", desc = "Hold the hold key to aim, or keep it always on while enabled." })
        UI.keybind(main, "aimHold")
        UI.slider(main, { key = "aim.fov", label = "FOV radius", suffix = " px", desc = "Maximum distance from the reticle on screen, in pixels." })
        UI.slider(main, { key = "aim.maxDistance", label = "Max target distance", suffix = " st", desc = "Maximum distance from the camera, in studs." })
        UI.dropdown(main, { key = "aim.targetPart", label = "Target point", desc = "Head, torso (UpperTorso/Torso) or root part. Falls back to the root part." })
        UI.dropdown(main, { key = "aim.priority", label = "Priority", desc = "How the best target inside the FOV is chosen." })
        UI.slider(main, { key = "aim.responsiveness", label = "Responsiveness", suffix = "%", desc = "Higher turns the camera faster. 100% snaps. Frame-rate independent." })
        UI.toggle(main, { key = "aim.requireLos", label = "Require line of sight", desc = "Ignore targets blocked by geometry (raycast, cached for 0.15 s)." })
        UI.toggle(main, { key = "aim.includeNpcs", label = "Include untagged NPCs", desc = "Also allow NPC models that are not tagged VEYLTestTarget." })
        UI.toggle(main, { key = "aim.lockSelected", label = "Lock to selected target", desc = "When a target is selected, aim only at it (ignores the FOV, keeps distance and sight checks)." })
        UI.dropdown(main, { key = "aim.reticle", label = "Reticle origin", desc = "Measure the FOV from the screen center or the mouse cursor." })

        local display = UI.section(page, "left", "Display")
        UI.toggle(display, { key = "aim.showFov", label = "Show FOV circle", desc = "Draw the FOV radius around the reticle." })
        UI.toggle(display, { key = "aim.showIndicator", label = "Show target indicator", desc = "Mark the current aim point." })
        UI.color(display, { key = "color.fov", label = "FOV circle color", desc = "Color of the FOV circle." })
        UI.color(display, { key = "color.target", label = "Target indicator color", desc = "Color of the target indicator." })

        local target = UI.section(page, "right", "Target")
        local selectedRow = UI.info(target, { label = "Selected", desc = "Explicit selection from Cycle or the Entities tab." })
        local currentRow = UI.info(target, { label = "Current aim target", desc = "Target chosen this frame (selection or best in FOV)." })
        local eligibleRow = UI.info(target, { label = "Eligible targets", desc = "Live players require explicit session allowlisting; NPCs and tagged test targets follow their own filters." })
        UI.buttons(target, {
            { text = "Cycle target", style = "primary", callback = Aim.cycle },
            { text = "Clear target", callback = function()
                Aim.clear(true)
            end },
        }, "Cycle selects the next eligible target by distance.")

        local scope = UI.section(page, "right", "Scope and limits")
        UI.note(scope, "Eligible: models tagged VEYLTestTarget (CollectionService), players you allowlist in Entities for this session, and untagged NPCs only when enabled.")
        UI.note(scope, "Aim Lab moves only your local camera. Whether a weapon's shots follow the camera depends on that weapon's own scripts. No hits are reported and no remotes are called.", T.warn)

        page.onUpdate = function()
            selectedRow.set(Aim.selected and Aim.selected.name or "None", Aim.selected and T.text or T.muted)
            currentRow.set(Aim.current and Aim.current.name or (Settings.get("aim.enabled") and "None in range" or "Aim Lab off"), Aim.current and T.ok or T.muted)
            local count, playerCount, npcCount, testCount = 0, 0, 0, 0
            for _, entity in pairs(Entities.byModel) do
                if Aim.eligible(entity) then
                    count += 1
                    if entity.kind == "Player" then
                        playerCount += 1
                    elseif entity.kind == "NPC" then
                        npcCount += 1
                    elseif entity.kind == "Test target" then
                        testCount += 1
                    end
                end
            end
            eligibleRow.set(string.format("%d total (P:%d · NPC:%d · T:%d)", count, playerCount, npcCount, testCount))
        end
    end
end
