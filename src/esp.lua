-- VEYL module: esp
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local RunService = V.RunService
    local UserInputService = V.UserInputService
    local Workspace = V.Workspace
    local NAMES = V.NAMES
    local LIMITS = V.LIMITS
    local Util = V.Util
    local Log = V.Log
    local Settings = V.Settings
    local Overlay = V.Overlay
    local Entities = V.Entities
    local ESP = V.ESP
    local App = V.App
    local Maid = V.Maid
    local make = V.make
    local KIND_SHORT = V.KIND_SHORT

    ----------------------------------------------------------------------------
    -- 12b. ESP / Visuals
    ----------------------------------------------------------------------------

    ESP.visuals = {}
    ESP.highlights = {}
    ESP.drawn = 0

    local VISUAL_PARTS = { "boxOutline", "box", "name", "info", "healthBack", "healthFill", "tracer", "arrow" }
    local VISUAL_KINDS = {
        boxOutline = "Square",
        box = "Square",
        name = "Text",
        info = "Text",
        healthBack = "Square",
        healthFill = "Square",
        tracer = "Line",
        arrow = "Triangle",
    }
    local BLACK = Color3.new(0, 0, 0)
    local LOW_HEALTH = Color3.fromRGB(255, 80, 80)

    local function newVisual()
        local visual = {}
        for _, key in ipairs(VISUAL_PARTS) do
            visual[key] = Overlay.new(VISUAL_KINDS[key])
        end
        return visual
    end

    local function hideVisual(visual, except)
        for _, key in ipairs(VISUAL_PARTS) do
            if key ~= except then
                visual[key]:hide()
            end
        end
    end

    local function destroyVisual(visual)
        for _, key in ipairs(VISUAL_PARTS) do
            visual[key]:Destroy()
        end
    end

    function ESP.eligible(entity)
        if entity.kind == "Test target" then
            return Settings.get("esp.showTargets")
        elseif entity.kind == "NPC" then
            return Settings.get("esp.showNpcs")
        elseif entity.kind == "Player" then
            return Settings.get("esp.showPlayers") and Entities.isAllowed(entity)
        end
        return false
    end

    local function kindColor(entity, values)
        if entity.kind == "Player" then
            return values["color.player"]
        elseif entity.kind == "Test target" then
            return values["color.testTarget"]
        end
        return values["color.npc"]
    end

    -- Precedence: visibility colors > entity-type colors > the element's own color.
    local function elementColor(entity, key, values)
        if values["esp.visColors"] and values["esp.visibility"] and entity.visible ~= nil then
            return entity.visible and values["color.visible"] or values["color.occluded"]
        end
        if values["esp.typeColors"] then
            return kindColor(entity, values)
        end
        return values[key]
    end

    local CORNERS = {}
    for index = 0, 7 do
        CORNERS[index + 1] = Vector3.new(
            index % 2 == 0 and -0.5 or 0.5,
            math.floor(index / 2) % 2 == 0 and -0.5 or 0.5,
            math.floor(index / 4) % 2 == 0 and -0.5 or 0.5
        )
    end
    local EDGES = {}
    for index = 0, 7 do
        for _, bit in ipairs({ 1, 2, 4 }) do
            if bit32.band(index, bit) == 0 then
                table.insert(EDGES, { index + 1, index + bit + 1 })
            end
        end
    end
    local cornerWorld, cornerDepth = {}, {}
    local NEAR_DEPTH = 0.5

    -- Projects an oriented box; edges that cross the near plane are clipped instead
    -- of discarding the whole box when one corner is behind the camera.
    local function projectBox(camera, cameraCFrame, boxCFrame, size)
        local origin, look = cameraCFrame.Position, cameraCFrame.LookVector
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local any = false
        local function add(point)
            local screen = camera:WorldToViewportPoint(point)
            if screen.X < minX then
                minX = screen.X
            end
            if screen.X > maxX then
                maxX = screen.X
            end
            if screen.Y < minY then
                minY = screen.Y
            end
            if screen.Y > maxY then
                maxY = screen.Y
            end
            any = true
        end
        for index = 1, 8 do
            local world = boxCFrame:PointToWorldSpace(CORNERS[index] * size)
            cornerWorld[index] = world
            cornerDepth[index] = (world - origin):Dot(look)
        end
        for index = 1, 8 do
            if cornerDepth[index] >= NEAR_DEPTH then
                add(cornerWorld[index])
            end
        end
        for _, edge in ipairs(EDGES) do
            local a, b = edge[1], edge[2]
            local depthA, depthB = cornerDepth[a], cornerDepth[b]
            if (depthA >= NEAR_DEPTH) ~= (depthB >= NEAR_DEPTH) then
                add(cornerWorld[a]:Lerp(cornerWorld[b], (NEAR_DEPTH - depthA) / (depthB - depthA)))
            end
        end
        return any, minX, minY, maxX, maxY
    end

    local function drawArrow(visual, cameraCFrame, position, viewport, color)
        local relative = cameraCFrame:PointToObjectSpace(position)
        local direction = Vector2.new(relative.X, -relative.Y)
        if direction.Magnitude < 1e-3 then
            direction = Vector2.new(0, 1)
        end
        direction = direction.Unit
        local half = viewport / 2
        local reachX = math.max(half.X - 48, 10) / math.max(math.abs(direction.X), 1e-3)
        local reachY = math.max(half.Y - 48, 10) / math.max(math.abs(direction.Y), 1e-3)
        local center = half + direction * math.min(reachX, reachY)
        local side = Vector2.new(-direction.Y, direction.X) * 7
        local back = center - direction * 6
        visual.arrow:triangle(center + direction * 10, back + side, back - side, color, 0.9)
    end

    local espBudget = { left = 0 }

    local function drawEntity(entity, visual, camera, cameraCFrame, viewport, now, tracerFrom, values)
        local root = Entities.getRoot(entity)
        local humanoid = entity.humanoid
        if not root or not humanoid or humanoid.Health <= 0 then
            hideVisual(visual)
            return false
        end
        local origin = cameraCFrame.Position
        local distance = (root.Position - origin).Magnitude
        if distance > values["esp.maxDistance"] then
            hideVisual(visual)
            return false
        end
        if values["esp.visibility"] then
            Entities.visibility(entity, root, origin, espBudget, now)
        end
        local boxCFrame, size = Entities.bounds(entity, root, now)
        local inFront, minX, minY, maxX, maxY = projectBox(camera, cameraCFrame, boxCFrame, size)
        local onScreen = inFront and maxX >= 0 and minX <= viewport.X and maxY >= 0 and minY <= viewport.Y
        if not onScreen then
            hideVisual(visual, "arrow")
            if values["esp.offscreen"] then
                drawArrow(visual, cameraCFrame, root.Position, viewport, elementColor(entity, "color.box", values))
            else
                visual.arrow:hide()
            end
            return true
        end
        visual.arrow:hide()
        if maxX - minX < 4 then
            local middle = (minX + maxX) / 2
            minX, maxX = middle - 2, middle + 2
        end
        if maxY - minY < 4 then
            local middle = (minY + maxY) / 2
            minY, maxY = middle - 2, middle + 2
        end
        local boxPosition = Vector2.new(minX, minY)
        local boxSize = Vector2.new(maxX - minX, maxY - minY)
        local centerX = (minX + maxX) / 2
        local textSize = values["esp.textSize"]

        if values["esp.boxes"] then
            local opacity = 1 - values["esp.boxTransparency"] / 100
            visual.boxOutline:rect(boxPosition - Vector2.new(1, 1), boxSize + Vector2.new(2, 2), BLACK, 3, opacity * 0.6, false)
            visual.box:rect(boxPosition, boxSize, elementColor(entity, "color.box", values), 1, opacity, false)
        else
            visual.boxOutline:hide()
            visual.box:hide()
        end
        if values["esp.names"] then
            visual.name:text(entity.name, Vector2.new(centerX, minY - textSize - 3), values["color.name"], textSize, 1)
        else
            visual.name:hide()
        end
        if values["esp.distance"] then
            local status = ""
            if values["esp.visibility"] and entity.visible ~= nil then
                status = entity.visible and " · visible" or " · occluded"
            end
            visual.info:text(
                string.format("%s · %d st%s", KIND_SHORT[entity.kind] or "?", math.floor(distance + 0.5), status),
                Vector2.new(centerX, maxY + 2),
                values["color.name"],
                math.max(10, textSize - 2),
                0.9
            )
        else
            visual.info:hide()
        end
        if values["esp.health"] then
            local maxHealth = humanoid.MaxHealth
            local fraction = maxHealth > 0 and math.clamp(humanoid.Health / maxHealth, 0, 1) or 0
            local fillHeight = math.max(1, boxSize.Y * fraction)
            visual.healthBack:rect(Vector2.new(minX - 7, minY - 1), Vector2.new(4, boxSize.Y + 2), BLACK, 1, 0.6, true)
            visual.healthFill:rect(Vector2.new(minX - 6, maxY - fillHeight), Vector2.new(2, fillHeight), values["color.health"]:Lerp(LOW_HEALTH, 1 - fraction), 1, 1, true)
        else
            visual.healthBack:hide()
            visual.healthFill:hide()
        end
        if values["esp.tracers"] then
            visual.tracer:line(tracerFrom, Vector2.new(centerX, maxY), elementColor(entity, "color.tracer", values), 1, 1 - values["esp.tracerTransparency"] / 100)
        else
            visual.tracer:hide()
        end
        return true
    end

    function ESP.step()
        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end
        local values = Settings.values
        local cameraCFrame = camera.CFrame
        local viewport = camera.ViewportSize
        local now = os.clock()
        espBudget.left = 10
        local origin = values["esp.tracerOrigin"]
        local tracerFrom
        if origin == "Center" then
            tracerFrom = viewport / 2
        elseif origin == "Mouse" then
            tracerFrom = UserInputService:GetMouseLocation()
        else
            tracerFrom = Vector2.new(viewport.X / 2, viewport.Y - 2)
        end
        local drawn = 0
        for _, entity in pairs(Entities.byModel) do
            local visual = ESP.visuals[entity]
            if not entity.espBroken and ESP.eligible(entity) then
                if not visual then
                    visual = newVisual()
                    ESP.visuals[entity] = visual
                end
                local ok, result = pcall(drawEntity, entity, visual, camera, cameraCFrame, viewport, now, tracerFrom, values)
                if ok then
                    if result then
                        drawn += 1
                    end
                else
                    hideVisual(visual)
                    entity.espFails = (entity.espFails or 0) + 1
                    if entity.espFails >= 10 then
                        entity.espBroken = true
                        Log.add("warn", "ESP skips " .. entity.name .. " after repeated errors: " .. tostring(result))
                    end
                end
            elseif visual then
                hideVisual(visual)
            end
        end
        ESP.drawn = drawn
    end

    function ESP.updateHighlights()
        local values = Settings.values
        local camera = Workspace.CurrentCamera
        if not values["esp.enabled"] or not values["esp.highlight"] or not camera then
            for entity, highlight in pairs(ESP.highlights) do
                highlight:Destroy()
                ESP.highlights[entity] = nil
            end
            return
        end
        local origin = camera.CFrame.Position
        local candidates = {}
        for _, entity in pairs(Entities.byModel) do
            if ESP.eligible(entity) and Entities.isAlive(entity) then
                local root = Entities.getRoot(entity)
                if root then
                    local distance = (root.Position - origin).Magnitude
                    if distance <= values["esp.maxDistance"] then
                        table.insert(candidates, { entity = entity, distance = distance })
                    end
                end
            end
        end
        table.sort(candidates, function(a, b)
            return a.distance < b.distance
        end)
        local keep = {}
        local depth = values["esp.hlDepth"] == "Always on top" and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        for index = 1, math.min(#candidates, LIMITS.highlights) do
            local entity = candidates[index].entity
            keep[entity] = true
            local highlight = ESP.highlights[entity]
            if not highlight or not highlight.Parent then
                highlight = make("Highlight", { Name = "VEYLHighlight", Adornee = entity.model })
                highlight:SetAttribute(NAMES.owned, true)
                highlight.Parent = App.fx()
                ESP.highlights[entity] = highlight
            end
            highlight.FillColor = values["esp.typeColors"] and kindColor(entity, values) or values["color.hlFill"]
            highlight.OutlineColor = values["color.hlOutline"]
            highlight.FillTransparency = values["esp.hlFillTransparency"] / 100
            highlight.OutlineTransparency = values["esp.hlOutlineTransparency"] / 100
            highlight.DepthMode = depth
        end
        for entity, highlight in pairs(ESP.highlights) do
            if not keep[entity] then
                highlight:Destroy()
                ESP.highlights[entity] = nil
            end
        end
    end

    function ESP.dropVisuals()
        for entity, visual in pairs(ESP.visuals) do
            destroyVisual(visual)
            ESP.visuals[entity] = nil
        end
    end

    function ESP.start()
        if ESP.maid then
            return
        end
        Overlay.ensureMode()
        local maid = Maid.new()
        ESP.maid = maid
        maid:connect(RunService.RenderStepped, Util.guardStep("ESP", ESP.step, function()
            Settings.set("esp.enabled", false)
        end))
        local elapsed = 0
        maid:connect(RunService.Heartbeat, function(deltaTime)
            elapsed += deltaTime
            if elapsed >= 0.5 then
                elapsed = 0
                local ok, err = pcall(ESP.updateHighlights)
                if not ok then
                    Log.add("warn", "Highlight update failed: " .. tostring(err))
                end
            end
        end)
        ESP.updateHighlights()
        Log.add("info", "ESP started with the " .. tostring(Overlay.mode) .. " renderer.")
    end

    function ESP.stop()
        if ESP.maid then
            ESP.maid:clean()
            ESP.maid = nil
        end
        ESP.dropVisuals()
        for entity, highlight in pairs(ESP.highlights) do
            highlight:Destroy()
            ESP.highlights[entity] = nil
        end
        ESP.drawn = 0
    end

    function ESP.forget(entity)
        local visual = ESP.visuals[entity]
        if visual then
            destroyVisual(visual)
            ESP.visuals[entity] = nil
        end
        local highlight = ESP.highlights[entity]
        if highlight then
            highlight:Destroy()
            ESP.highlights[entity] = nil
        end
    end

    V.VISUAL_PARTS = VISUAL_PARTS
    V.VISUAL_KINDS = VISUAL_KINDS
    V.BLACK = BLACK
    V.LOW_HEALTH = LOW_HEALTH
    V.newVisual = newVisual
    V.hideVisual = hideVisual
    V.destroyVisual = destroyVisual
    V.kindColor = kindColor
    V.elementColor = elementColor
    V.CORNERS = CORNERS
    V.EDGES = EDGES
    V.cornerWorld = cornerWorld
    V.cornerDepth = cornerDepth
    V.NEAR_DEPTH = NEAR_DEPTH
    V.projectBox = projectBox
    V.drawArrow = drawArrow
    V.espBudget = espBudget
    V.drawEntity = drawEntity
end
