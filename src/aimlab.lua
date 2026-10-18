-- VEYL module: aimlab
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local RunService = V.RunService
    local UserInputService = V.UserInputService
    local Workspace = V.Workspace
    local NAMES = V.NAMES
    local Util = V.Util
    local Log = V.Log
    local Notify = V.Notify
    local Settings = V.Settings
    local Binds = V.Binds
    local Overlay = V.Overlay
    local Entities = V.Entities
    local Aim = V.Aim

    ----------------------------------------------------------------------------
    -- 11. Aim Lab (client camera only; explicit test scope)
    ----------------------------------------------------------------------------

    Aim.selected = nil
    Aim.current = nil
    Aim.running = false
    local aimBudget = { left = 0 }

    function Aim.eligible(entity)
        if entity.removed or not Entities.isAlive(entity) then
            return false
        end
        if entity.kind == "Test target" then
            return true
        elseif entity.kind == "Player" then
            return Entities.isAllowed(entity)
        end
        return Settings.get("aim.includeNpcs") == true
    end

    function Aim.eligibleList(origin)
        local list = {}
        for _, entity in pairs(Entities.byModel) do
            if Aim.eligible(entity) then
                local root = Entities.getRoot(entity)
                if root then
                    table.insert(list, { entity = entity, distance = (root.Position - origin).Magnitude })
                end
            end
        end
        table.sort(list, function(a, b)
            if a.distance == b.distance then
                return a.entity.id < b.entity.id
            end
            return a.distance < b.distance
        end)
        local entities = {}
        for index, item in ipairs(list) do
            entities[index] = item.entity
        end
        return entities
    end

    function Aim.reticle(camera)
        if Settings.get("aim.reticle") == "Mouse" then
            return UserInputService:GetMouseLocation()
        end
        return camera.ViewportSize / 2
    end

    function Aim.select(entity, silent)
        Aim.selected = entity
        if entity then
            Log.add("info", "Aim Lab target selected: " .. entity.name)
            if not silent then
                Notify.push("Aim Lab target: " .. entity.name, "info")
            end
        end
    end

    function Aim.clear(announce)
        local had = Aim.selected ~= nil
        Aim.selected = nil
        Aim.current = nil
        if announce then
            Notify.push(had and "Aim Lab target cleared." or "No Aim Lab target was selected.", "info")
        end
    end

    function Aim.cycle()
        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end
        local list = Aim.eligibleList(camera.CFrame.Position)
        if #list == 0 then
            Notify.push("No eligible targets. Tag a model VEYLTestTarget, allowlist a player in Entities, or enable untagged NPCs.", "warn")
            return
        end
        local index = table.find(list, Aim.selected) or 0
        Aim.select(list[index % #list + 1])
    end

    function Aim.pick(camera, now)
        local values = Settings.values
        local origin = camera.CFrame.Position
        local partName = values["aim.targetPart"]
        local maxDistance = values["aim.maxDistance"]
        local requireLos = values["aim.requireLos"]
        aimBudget.left = 6

        local selected = Aim.selected
        if selected then
            if not Aim.eligible(selected) then
                Aim.clear(false)
                Notify.push("Selected target is no longer available (removed, dead or out of scope).", "info")
            elseif values["aim.lockSelected"] then
                local part = Entities.part(selected, partName)
                if part and (part.Position - origin).Magnitude <= maxDistance then
                    if not requireLos or Entities.visibility(selected, part, origin, aimBudget, now) == true then
                        return selected, part
                    end
                end
                return nil, nil
            end
        end

        local reticle = Aim.reticle(camera)
        local priority = values["aim.priority"]
        local best, bestPart, bestScore = nil, nil, nil
        for _, entity in pairs(Entities.byModel) do
            if Aim.eligible(entity) then
                local part = Entities.part(entity, partName)
                if part then
                    local distance = (part.Position - origin).Magnitude
                    if distance <= maxDistance then
                        local screen, inView = camera:WorldToViewportPoint(part.Position)
                        if inView and screen.Z > 0 then
                            local offset = (Vector2.new(screen.X, screen.Y) - reticle).Magnitude
                            if offset <= values["aim.fov"] then
                                local score
                                if priority == "Shortest distance" then
                                    score = distance
                                elseif priority == "Lowest health" then
                                    score = entity.humanoid.Health
                                else
                                    score = offset
                                end
                                if (bestScore == nil or score < bestScore)
                                    and (not requireLos or Entities.visibility(entity, part, origin, aimBudget, now) == true) then
                                    best, bestPart, bestScore = entity, part, score
                                end
                            end
                        end
                    end
                end
            end
        end
        return best, bestPart
    end

    function Aim.ensureVisuals()
        if not Aim.visuals then
            Aim.visuals = { fov = Overlay.new("Circle"), indicator = Overlay.new("Circle") }
        end
        return Aim.visuals
    end

    function Aim.dropVisuals()
        if Aim.visuals then
            Aim.visuals.fov:Destroy()
            Aim.visuals.indicator:Destroy()
            Aim.visuals = nil
        end
    end

    function Aim.step(deltaTime)
        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end
        local values = Settings.values
        local now = os.clock()
        local target, part = Aim.pick(camera, now)
        Aim.current = target
        local visuals = Aim.ensureVisuals()
        if values["aim.showFov"] then
            visuals.fov:circle(Aim.reticle(camera), values["aim.fov"], values["color.fov"], 1, 0.8)
        else
            visuals.fov:hide()
        end
        if values["aim.showIndicator"] and part then
            local screen, inView = camera:WorldToViewportPoint(part.Position)
            if inView then
                visuals.indicator:circle(Vector2.new(screen.X, screen.Y), 7, values["color.target"], 2, 1)
            else
                visuals.indicator:hide()
            end
        else
            visuals.indicator:hide()
        end
        local active = values["aim.activation"] == "Always on" or Binds.isHeld("aimHold")
        if active and part and not UserInputService:GetFocusedTextBox() then
            local cameraCFrame = camera.CFrame
            local desired = CFrame.lookAt(cameraCFrame.Position, part.Position)
            local strength = math.clamp(values["aim.responsiveness"] / 100, 0.01, 1)
            local alpha = 1 - (1 - strength) ^ (math.min(deltaTime, 0.1) * 60)
            camera.CFrame = cameraCFrame:Lerp(desired, math.clamp(alpha, 0, 1))
        end
    end

    function Aim.start()
        if Aim.running then
            return
        end
        Overlay.ensureMode()
        Aim.running = true
        pcall(function()
            RunService:UnbindFromRenderStep(NAMES.aimStep)
        end)
        -- Runs right after the default camera update so the normal controller keeps ownership otherwise.
        RunService:BindToRenderStep(NAMES.aimStep, Enum.RenderPriority.Camera.Value + 1, Util.guardStep("Aim Lab", Aim.step, function()
            Settings.set("aim.enabled", false)
        end))
        Log.add("info", "Aim Lab armed.")
    end

    function Aim.stop()
        if Aim.running then
            pcall(function()
                RunService:UnbindFromRenderStep(NAMES.aimStep)
            end)
            Aim.running = false
        end
        Aim.dropVisuals()
        Aim.current = nil
    end

    V.aimBudget = aimBudget
end
