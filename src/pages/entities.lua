-- VEYL module: pages/entities
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Workspace = V.Workspace
    local LIMITS = V.LIMITS
    local Util = V.Util
    local Notify = V.Notify
    local UI = V.UI
    local Entities = V.Entities
    local ESP = V.ESP
    local Aim = V.Aim
    local Root = V.Root
    local T = V.T
    local text = V.text
    local Pages = V.Pages
    local rowButton = V.rowButton
    local kindColorUi = V.kindColorUi
    local aimIneligibleReason = V.aimIneligibleReason

    -- ENTITIES -----------------------------------------------------------------
    function Pages.entities()
        local page = UI.page("Entities")
        local registry = UI.section(page, "left", "Live registry")
        local filterText, filterKind = "", "All"
        local inspected
        local list
        local dirty = true
        local countRow

        local function matches(entity)
            if filterKind ~= "All" and entity.kind ~= filterKind then
                return false
            end
            return filterText == "" or string.find(string.lower(entity.name), filterText, 1, true) ~= nil
        end

        local function buildRow(entity)
            return function(frame, maid)
                local nameLabel = text(frame, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -170, 0, 16), Font = T.fontMedium, Text = entity.name })
                local detail = text(frame, { Position = UDim2.fromOffset(8, 19), Size = UDim2.new(1, -170, 0, 14), TextSize = 10, TextColor3 = T.muted, Text = "" })
                local inspect = rowButton(frame, "Inspect", 4, 52, "default", maid)
                local aim = rowButton(frame, "Aim", 60, 44, "default", maid)
                local allow
                if entity.player then
                    allow = rowButton(frame, "Allow", 108, 52, "default", maid)
                    maid:connect(allow.Activated, function()
                        Entities.setAllowed(entity, not Entities.isAllowed(entity))
                        dirty = true
                    end)
                end
                maid:connect(inspect.Activated, function()
                    inspected = entity
                    UI.updatePage(true)
                end)
                maid:connect(aim.Activated, function()
                    local reason = aimIneligibleReason(entity)
                    if reason then
                        Notify.push(reason, "warn")
                    else
                        Aim.select(entity)
                    end
                end)
                return function(origin)
                    nameLabel.Text = entity.name .. (Aim.selected == entity and "  ◎" or "")
                    nameLabel.TextColor3 = kindColorUi(entity.kind)
                    local root = Entities.getRoot(entity)
                    local distance = root and (root.Position - origin).Magnitude or nil
                    local humanoid = entity.humanoid
                    local health = humanoid and string.format("%d/%d HP", math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5)) or "no HP"
                    local aimText = Aim.eligible(entity) and "aim ✓" or "aim ✗"
                    detail.Text = string.format("%s · %s · %s · %s", entity.kind, distance and (math.floor(distance + 0.5) .. " st") or "no root", health, aimText)
                    if allow then
                        allow.Text = Entities.isAllowed(entity) and "Revoke" or "Allow"
                    end
                    frame.LayoutOrder = distance and math.floor(distance) or 1e6
                end
            end
        end

        UI.filterBox(registry, "Search by name…", function(value)
            filterText = value
            dirty = true
            UI.updatePage(true)
        end)
        UI.dropdown(registry, {
            label = "Type",
            desc = "Filter by classification.",
            options = function()
                return { "All", "Test target", "Player", "NPC" }
            end,
            get = function()
                return filterKind
            end,
            set = function(value)
                filterKind = value
                dirty = true
                UI.updatePage(true)
            end,
        })
        countRow = UI.info(registry, { label = "Showing", desc = "Rows are capped at " .. LIMITS.entityRows .. " and sorted by distance from the camera." })
        list = UI.list(registry, "No live entities match.")

        local function sync()
            dirty = false
            local shown, total = 0, 0
            for _, entity in pairs(Entities.byModel) do
                local want = matches(entity)
                if want then
                    total += 1
                end
                if want and shown < LIMITS.entityRows then
                    shown += 1
                    if not list.get(entity) then
                        list.add(entity, 38, buildRow(entity))
                    end
                elseif list.get(entity) then
                    list.remove(entity)
                end
            end
            for entity in pairs(list.rows) do
                if entity.removed then
                    list.remove(entity)
                end
            end
            countRow.set(string.format("%d of %d match%s", shown, total, Entities.scanning and " · scanning" or ""))
        end

        local inspector = UI.section(page, "right", "Inspector")
        local fields = {
            name = UI.info(inspector, { label = "Name", desc = "Display name, or VEYLTargetName attribute for test targets." }),
            kind = UI.info(inspector, { label = "Classification", desc = "Test target (tag), Player (GetPlayerFromCharacter) or NPC." }),
            distance = UI.info(inspector, { label = "Distance (camera)", desc = "Measured from the current camera position, in studs." }),
            health = UI.info(inspector, { label = "Health", desc = "Humanoid Health / MaxHealth as replicated to this client." }),
            state = UI.info(inspector, { label = "Humanoid state", desc = "Humanoid:GetState() as seen by this client." }),
            position = UI.info(inspector, { label = "Root position", desc = "World position of the root part." }),
            screen = UI.info(inspector, { label = "Screen", desc = "Whether the root projects inside the viewport." }),
            eligible = UI.info(inspector, { label = "Aim / ESP scope", desc = "Eligibility under the current filters." }),
        }
        local pathNote = UI.note(inspector, "Select Inspect on a row to see details.")
        UI.buttons(inspector, {
            { text = "Select for Aim Lab", style = "primary", callback = function()
                if not inspected or inspected.removed then
                    Notify.push("Inspect an entity first.", "warn")
                    return
                end
                local reason = aimIneligibleReason(inspected)
                if reason then
                    Notify.push(reason, "warn")
                else
                    Aim.select(inspected)
                end
            end },
            { text = "Toggle allowlist", callback = function()
                if not inspected or inspected.removed or not inspected.player then
                    Notify.push("Inspect a player first.", "warn")
                    return
                end
                Entities.setAllowed(inspected, not Entities.isAllowed(inspected))
            end },
        }, "Act on the inspected entity.")

        local allowSection = UI.section(page, "right", "Session allowlist")
        local allowRow = UI.info(allowSection, { label = "Allowlisted players", desc = "Session only; never saved to disk." })
        UI.note(allowSection, "Players are excluded from Aim Lab and ESP until you allowlist them here for this session (for example your own test accounts).")
        UI.button(allowSection, {
            text = "Clear allowlist",
            desc = "Remove every player from the session allowlist.",
            callback = function()
                table.clear(Entities.allow)
                for _, entity in pairs(Entities.byModel) do
                    if entity.player then
                        Entities.changed:Fire(entity)
                    end
                end
                Notify.push("Allowlist cleared.", "ok")
            end,
        })
        UI.button(allowSection, { text = "Rebuild registry", desc = "Drop and rediscover every live entity.", callback = Entities.rebuild })

        Root:give(Entities.added:Connect(function()
            dirty = true
        end))
        Root:give(Entities.changed:Connect(function()
            dirty = true
        end))
        Root:give(Entities.removed:Connect(function(entity)
            list.remove(entity)
            if inspected == entity then
                inspected = nil
            end
            dirty = true
        end))

        page.onShow = function()
            dirty = true
        end
        page.updateInterval = 0.5
        page.onUpdate = function()
            if dirty then
                sync()
            end
            local camera = Workspace.CurrentCamera
            local origin = camera and camera.CFrame.Position or Vector3.zero
            for _, entry in pairs(list.rows) do
                entry.update(origin)
            end
            local allowCount = 0
            for _ in pairs(Entities.allow) do
                allowCount += 1
            end
            allowRow.set(tostring(allowCount))
            if inspected and not inspected.removed then
                local entity = inspected
                local root = Entities.getRoot(entity)
                local humanoid = entity.humanoid
                fields.name.set(entity.name)
                fields.kind.set(entity.kind, kindColorUi(entity.kind))
                fields.distance.set(root and (math.floor((root.Position - origin).Magnitude + 0.5) .. " st") or "No root part")
                fields.health.set(humanoid and string.format("%.0f / %.0f", humanoid.Health, humanoid.MaxHealth) or "Unavailable")
                local okState, state = pcall(function()
                    return humanoid:GetState().Name
                end)
                fields.state.set(okState and state or "Unavailable")
                fields.position.set(root and string.format("%.1f, %.1f, %.1f", root.Position.X, root.Position.Y, root.Position.Z) or "Unavailable")
                if root and camera then
                    local _, inView = camera:WorldToViewportPoint(root.Position)
                    fields.screen.set(inView and "On screen" or "Off screen")
                else
                    fields.screen.set("Unavailable")
                end
                fields.eligible.set((Aim.eligible(entity) and "Aim ✓" or "Aim ✗") .. "  ·  " .. (ESP.eligible(entity) and "ESP ✓" or "ESP ✗"))
                pathNote.set("Path: " .. Util.fullName(entity.model), T.muted)
            else
                for _, field in pairs(fields) do
                    field.set("—", T.dim)
                end
                pathNote.set("Select Inspect on a row to see details.", T.dim)
            end
        end
    end
end
