-- VEYL module: pages/shared
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Settings = V.Settings
    local Entities = V.Entities
    local styledButton = V.styledButton

    ----------------------------------------------------------------------------
    -- 7. Tabs and panels
    ----------------------------------------------------------------------------

    local Pages = {}

    local function rowButton(frame, label, xFromRight, width, style, maid)
        local button = styledButton(frame, label, style, maid)
        button.AnchorPoint = Vector2.new(1, 0.5)
        button.Position = UDim2.new(1, -xFromRight, 0.5, 0)
        button.Size = UDim2.fromOffset(width, 20)
        return button
    end

    local function kindColorUi(kind)
        if kind == "Player" then
            return Settings.get("color.player")
        elseif kind == "Test target" then
            return Settings.get("color.testTarget")
        end
        return Settings.get("color.npc")
    end

    local function aimIneligibleReason(entity)
        if not Entities.isAlive(entity) then
            return "This entity is dead or has no Humanoid."
        end
        if entity.kind == "Player" and not Entities.isAllowed(entity) then
            return "Allowlist this player first (Allow button)."
        end
        if entity.kind == "NPC" and not Settings.get("aim.includeNpcs") then
            return "Enable Aim Lab › Include untagged NPCs, or tag the model VEYLTestTarget."
        end
        return nil
    end

    V.Pages = Pages
    V.rowButton = rowButton
    V.kindColorUi = kindColorUi
    V.aimIneligibleReason = aimIneligibleReason
end
