-- VEYL module: pages/weapons
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local LIMITS = V.LIMITS
    local UI = V.UI
    local Weapons = V.Weapons
    local Root = V.Root
    local T = V.T
    local text = V.text
    local Pages = V.Pages
    local rowButton = V.rowButton

    -- WEAPONS ------------------------------------------------------------------
    function Pages.weapons()
        local page = UI.page("Weapons")
        local candidates = UI.section(page, "left", "Tool candidates")
        local filterText, filterLocation = "", "All"
        local inspected
        local dirty = true
        local list
        local countRow

        local function matches(record)
            if filterLocation ~= "All" and record.location ~= filterLocation then
                return false
            end
            return filterText == "" or string.find(string.lower(record.name), filterText, 1, true) ~= nil
        end

        local function buildRow(record)
            return function(frame, maid)
                local nameLabel = text(frame, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -72, 0, 16), Font = T.fontMedium, Text = record.name })
                local detail = text(frame, { Position = UDim2.fromOffset(8, 19), Size = UDim2.new(1, -72, 0, 14), TextSize = 10, TextColor3 = T.muted, Text = "" })
                local inspect = rowButton(frame, "Inspect", 4, 56, "default", maid)
                maid:connect(inspect.Activated, function()
                    inspected = record
                    UI.updatePage(true)
                end)
                return function()
                    nameLabel.Text = record.name
                    nameLabel.TextColor3 = record.ranged and T.cyan or T.text
                    detail.Text = string.format("%s · %s · %s confidence", record.location or "?", record.classification or "Analyzing", record.confidence or "?")
                    frame.LayoutOrder = (record.ranged and 0 or 1000) + record.id % 1000
                end
            end
        end

        UI.filterBox(candidates, "Search tools…", function(value)
            filterText = value
            dirty = true
            UI.updatePage(true)
        end)
        UI.dropdown(candidates, {
            label = "Location",
            desc = "Filter by where the tool currently is.",
            options = function()
                return { "All", "Equipped", "Backpack", "World", "Other player", "Template", "Other" }
            end,
            get = function()
                return filterLocation
            end,
            set = function(value)
                filterLocation = value
                dirty = true
                UI.updatePage(true)
            end,
        })
        countRow = UI.info(candidates, { label = "Showing", desc = "Tools from your Backpack, character, Workspace, StarterPack and ReplicatedStorage." })
        list = UI.list(candidates, "No tools discovered yet.")

        local function sync()
            dirty = false
            local shown, total = 0, 0
            for _, record in pairs(Weapons.byTool) do
                local want = matches(record)
                if want then
                    total += 1
                end
                if want and shown < LIMITS.toolRows then
                    shown += 1
                    if not list.get(record) then
                        list.add(record, 38, buildRow(record))
                    end
                elseif list.get(record) then
                    list.remove(record)
                end
            end
            for record in pairs(list.rows) do
                if record.removed then
                    list.remove(record)
                end
            end
            for _, entry in pairs(list.rows) do
                entry.update()
            end
            countRow.set(string.format("%d of %d match", shown, total))
        end

        local inspector = UI.section(page, "right", "Inspector")
        local fields = {
            name = UI.info(inspector, { label = "Name", desc = "Tool.Name" }),
            location = UI.info(inspector, { label = "Location", desc = "Equipped, Backpack, World, Other player, Template or Other." }),
            classification = UI.info(inspector, { label = "Classification", desc = "Heuristic from names, values, attachments, sounds and animations." }),
            confidence = UI.info(inspector, { label = "Confidence", desc = "Strength of the evidence, not proof." }),
            compat = UI.info(inspector, { label = "Compatibility", desc = "Verified only after a real verification test. None exists, so every tool is Unverified." }),
        }
        local pathNote = UI.note(inspector, "Select Inspect on a row to see evidence.")
        local evidenceNote = UI.note(inspector, "")
        local unknownNote = UI.note(inspector, "", T.warn)
        local detailNote = UI.note(inspector, "")

        local about = UI.section(page, "right", "How discovery works")
        UI.note(about, "Discovery is automatic and event-driven: tools are re-analysed when their descendants or attributes change, never by rescanning every frame.")
        UI.note(about, "Finding a Tool does not prove it is a gun, and finding a remote does not reveal its arguments. VEYL lists remotes but never invokes them, and script source cannot be read at runtime.", T.warn)
        UI.button(about, { text = "Rescan tools", desc = "Drop and rediscover every tool candidate.", callback = Weapons.rescan })

        Root:give(Weapons.added:Connect(function()
            dirty = true
        end))
        Root:give(Weapons.changed:Connect(function(record)
            local entry = list.get(record)
            if entry then
                entry.update()
            end
            dirty = true
        end))
        Root:give(Weapons.removed:Connect(function(record)
            list.remove(record)
            if inspected == record then
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
            local record = inspected
            if record and not record.removed then
                fields.name.set(record.name)
                fields.location.set(record.location or "?")
                fields.classification.set(record.classification or "Analyzing", record.ranged and T.cyan or T.text)
                fields.confidence.set(record.confidence or "?")
                fields.compat.set("Unverified", T.warn)
                pathNote.set("Path: " .. (record.path or "?"), T.muted)
                evidenceNote.set("Evidence:\n• " .. (#record.evidence > 0 and table.concat(record.evidence, "\n• ") or "none found"), T.text)
                local unknowns = table.clone(record.unknowns)
                table.insert(unknowns, "No verified fire interface; VEYL never invokes tool remotes. Aim Lab only turns the camera.")
                unknownNote.set("Unknowns:\n• " .. table.concat(unknowns, "\n• "), T.warn)
                local details = {}
                if #record.attributes > 0 then
                    table.insert(details, "Attributes: " .. table.concat(record.attributes, ", "))
                end
                if #record.values > 0 then
                    table.insert(details, "Value objects: " .. table.concat(record.values, ", "))
                end
                if #record.remotes > 0 then
                    table.insert(details, "Remotes (not invoked): " .. table.concat(record.remotes, ", "))
                end
                detailNote.set(#details > 0 and table.concat(details, "\n") or "No attributes, value objects or remotes.", T.muted)
            else
                for _, field in pairs(fields) do
                    field.set("—", T.dim)
                end
                pathNote.set("Select Inspect on a row to see evidence.", T.dim)
                evidenceNote.set("", T.dim)
                unknownNote.set("", T.dim)
                detailNote.set("", T.dim)
            end
        end
    end
end
