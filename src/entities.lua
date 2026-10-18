-- VEYL module: entities
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Players = V.Players
    local CollectionService = V.CollectionService
    local Workspace = V.Workspace
    local LocalPlayer = V.LocalPlayer
    local NAMES = V.NAMES
    local LIMITS = V.LIMITS
    local Util = V.Util
    local Log = V.Log
    local Entities = V.Entities
    local App = V.App
    local Session = V.Session
    local Maid = V.Maid

    ----------------------------------------------------------------------------
    -- 10. Entity discovery (event-driven, live Workspace models only)
    ----------------------------------------------------------------------------

    Entities.byModel = {}
    Entities.count = 0
    Entities.npcCount = 0
    Entities.allow = {}
    Entities.playerMaids = {}
    Entities.added = Util.signal()
    Entities.removed = Util.signal()
    Entities.changed = Util.signal()
    Entities.maid = Maid.new()
    Entities.nextId = 0
    Entities.scanToken = 0

    local KIND_SHORT = { ["Test target"] = "Test", Player = "Player", NPC = "NPC" }

    local function entityKind(model)
        local player = Players:GetPlayerFromCharacter(model)
        if CollectionService:HasTag(model, NAMES.tag) then
            return "Test target", player
        end
        if player then
            return "Player", player
        end
        return "NPC", nil
    end

    local function entityName(entity)
        local model = entity.model
        if entity.kind == "Test target" then
            local label = model:GetAttribute(NAMES.targetLabel)
            if type(label) == "string" and label ~= "" then
                return Util.truncate(label, 40)
            end
        end
        local player = entity.player
        if player then
            if player.DisplayName ~= player.Name then
                return player.DisplayName .. " (@" .. player.Name .. ")"
            end
            return player.Name
        end
        return model.Name
    end

    function Entities.track(model)
        if not Session.alive or typeof(model) ~= "Instance" or not model:IsA("Model") then
            return
        end
        local existing = Entities.byModel[model]
        if existing then
            Entities.refreshKind(existing)
            return
        end
        if model == LocalPlayer.Character or not model:IsDescendantOf(Workspace) then
            return
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end
        local kind, player = entityKind(model)
        if player == LocalPlayer then
            return
        end
        if kind == "NPC" and Entities.npcCount >= LIMITS.npcs then
            if not Entities.npcLimitLogged then
                Entities.npcLimitLogged = true
                Log.add("warn", "NPC registry limit (" .. LIMITS.npcs .. ") reached; further NPC models are not tracked.")
            end
            return
        end
        Entities.nextId += 1
        local entity = {
            id = Entities.nextId,
            model = model,
            humanoid = humanoid,
            kind = kind,
            player = player,
            maid = Maid.new(),
            rootRetry = 0,
            bbAt = 0,
            visAt = 0,
        }
        entity.name = entityName(entity)
        entity.maid:connect(model.AncestryChanged, function()
            if not model:IsDescendantOf(Workspace) then
                Entities.untrack(model, "removed from Workspace")
            end
        end)
        entity.maid:connect(humanoid.AncestryChanged, function(_, parent)
            if parent ~= model then
                local replacement = model:FindFirstChildOfClass("Humanoid")
                if replacement then
                    entity.humanoid = replacement
                else
                    Entities.untrack(model, "Humanoid removed")
                end
            end
        end)
        Entities.byModel[model] = entity
        Entities.count += 1
        if kind == "NPC" then
            Entities.npcCount += 1
        end
        Entities.added:Fire(entity)
    end

    function Entities.untrack(model, reason)
        local entity = Entities.byModel[model]
        if not entity then
            return
        end
        Entities.byModel[model] = nil
        Entities.count -= 1
        if entity.kind == "NPC" then
            Entities.npcCount -= 1
        end
        entity.removed = true
        entity.maid:clean()
        Entities.removed:Fire(entity, reason)
    end

    function Entities.refreshKind(entity)
        local kind, player = entityKind(entity.model)
        if player == LocalPlayer then
            Entities.untrack(entity.model, "local character")
            return
        end
        if kind ~= entity.kind or player ~= entity.player then
            if entity.kind == "NPC" then
                Entities.npcCount -= 1
            end
            if kind == "NPC" then
                Entities.npcCount += 1
            end
            entity.kind = kind
            entity.player = player
            entity.name = entityName(entity)
            Entities.changed:Fire(entity)
        end
    end

    function Entities.getRoot(entity)
        local root = entity.root
        if root and root.Parent then
            return root
        end
        local now = os.clock()
        if now < entity.rootRetry then
            return nil
        end
        local model, humanoid = entity.model, entity.humanoid
        root = humanoid and humanoid.RootPart
        if not (root and root.Parent) then
            root = model:FindFirstChild("HumanoidRootPart")
            if not (root and root:IsA("BasePart")) then
                root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            end
        end
        entity.root = root
        if not root then
            entity.rootRetry = now + 0.5
        end
        return root
    end

    function Entities.isAlive(entity)
        local humanoid = entity.humanoid
        return humanoid ~= nil and humanoid.Parent ~= nil and humanoid.Health > 0
    end

    function Entities.isAllowed(entity)
        return entity.player ~= nil and Entities.allow[entity.player.UserId] == true
    end

    function Entities.setAllowed(entity, allowed)
        if not entity.player then
            return
        end
        Entities.allow[entity.player.UserId] = allowed or nil
        Log.add("info", (allowed and "Allowlisted " or "Removed from allowlist: ") .. entity.name)
        Entities.changed:Fire(entity)
    end

    function Entities.part(entity, which)
        local model = entity.model
        if which == "Head" then
            local head = model:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                return head
            end
        elseif which == "Torso" then
            local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
            if torso and torso:IsA("BasePart") then
                return torso
            end
        end
        return Entities.getRoot(entity)
    end

    -- Cached bounding box relative to the root, refreshed at most once per second.
    function Entities.bounds(entity, root, now)
        if not entity.bbOffset or now - entity.bbAt > 1 then
            entity.bbAt = now
            local ok, boxCFrame, size = pcall(entity.model.GetBoundingBox, entity.model)
            if ok and size.Magnitude > 0.5 and size.Magnitude < 60 then
                entity.bbOffset = root.CFrame:ToObjectSpace(boxCFrame)
                entity.bbSize = size
            else
                entity.bbOffset = CFrame.new(0, -0.5, 0)
                entity.bbSize = Vector3.new(4, 5.5, 2)
            end
        end
        return root.CFrame * entity.bbOffset, entity.bbSize
    end

    local losParams = RaycastParams.new()
    losParams.FilterType = Enum.RaycastFilterType.Exclude
    losParams.IgnoreWater = true

    function Entities.lineOfSight(entity, part, origin)
        local filter = { entity.model }
        local character = LocalPlayer.Character
        if character then
            table.insert(filter, character)
        end
        local camera = Workspace.CurrentCamera
        if camera then
            table.insert(filter, camera)
        end
        if App.fxFolder and App.fxFolder.Parent then
            table.insert(filter, App.fxFolder)
        end
        losParams.FilterDescendantsInstances = filter
        return Workspace:Raycast(origin, part.Position - origin, losParams) == nil
    end

    -- Visibility is cached per entity and limited by a per-frame raycast budget.
    function Entities.visibility(entity, part, origin, budget, now)
        if entity.visible ~= nil and now - entity.visAt < 0.15 then
            return entity.visible
        end
        if budget.left <= 0 then
            return entity.visible
        end
        budget.left -= 1
        entity.visible = Entities.lineOfSight(entity, part, origin)
        entity.visAt = now
        return entity.visible
    end

    function Entities.considerHumanoid(humanoid)
        local model = humanoid.Parent
        if model and model:IsA("Model") then
            Entities.track(model)
        end
    end

    function Entities.watchPlayer(player)
        if player == LocalPlayer or Entities.playerMaids[player] then
            return
        end
        local maid = Maid.new()
        Entities.playerMaids[player] = maid
        maid:connect(player.CharacterAdded, function(character)
            task.defer(function()
                if Session.alive then
                    Entities.track(character)
                end
            end)
        end)
        maid:connect(player.CharacterRemoving, function(character)
            Entities.untrack(character, "character removing")
        end)
        if player.Character then
            Entities.track(player.Character)
        end
    end

    function Entities.scan()
        Entities.scanToken += 1
        local token = Entities.scanToken
        Entities.scanning = true
        task.spawn(function()
            local descendants = Workspace:GetDescendants()
            for index, instance in ipairs(descendants) do
                if not Session.alive or token ~= Entities.scanToken then
                    return
                end
                if instance.ClassName == "Humanoid" then
                    Entities.considerHumanoid(instance)
                end
                if index % 4000 == 0 then
                    task.wait()
                end
            end
            for _, instance in ipairs(CollectionService:GetTagged(NAMES.tag)) do
                Entities.track(instance)
            end
            if token == Entities.scanToken then
                Entities.scanning = false
            end
        end)
    end

    function Entities.start()
        local maid = Entities.maid
        maid:connect(Players.PlayerAdded, Entities.watchPlayer)
        maid:connect(Players.PlayerRemoving, function(player)
            local playerMaid = Entities.playerMaids[player]
            if playerMaid then
                playerMaid:clean()
                Entities.playerMaids[player] = nil
            end
            Entities.allow[player.UserId] = nil
        end)
        for _, player in ipairs(Players:GetPlayers()) do
            Entities.watchPlayer(player)
        end
        maid:connect(Workspace.DescendantAdded, function(instance)
            if instance.ClassName == "Humanoid" then
                task.defer(function()
                    if Session.alive and instance.Parent then
                        Entities.considerHumanoid(instance)
                    end
                end)
            end
        end)
        maid:connect(CollectionService:GetInstanceAddedSignal(NAMES.tag), function(instance)
            local entity = Entities.byModel[instance]
            if entity then
                Entities.refreshKind(entity)
            else
                Entities.track(instance)
            end
            Log.add("info", "Test target tag added: " .. instance.Name)
        end)
        maid:connect(CollectionService:GetInstanceRemovedSignal(NAMES.tag), function(instance)
            local entity = Entities.byModel[instance]
            if entity then
                Entities.refreshKind(entity)
            end
        end)
        maid:connect(LocalPlayer.CharacterAdded, function(character)
            if Entities.byModel[character] then
                Entities.untrack(character, "local character")
            end
        end)
        Entities.scan()
    end

    function Entities.rebuild()
        for model in pairs(Entities.byModel) do
            Entities.untrack(model, "registry rebuild")
        end
        Entities.npcLimitLogged = false
        for player, playerMaid in pairs(Entities.playerMaids) do
            playerMaid:clean()
            Entities.playerMaids[player] = nil
        end
        for _, player in ipairs(Players:GetPlayers()) do
            Entities.watchPlayer(player)
        end
        Entities.scan()
        Log.add("info", "Entity registry rebuilt.")
    end

    function Entities.stop()
        Entities.scanToken += 1
        Entities.maid:clean()
        for player, playerMaid in pairs(Entities.playerMaids) do
            playerMaid:clean()
            Entities.playerMaids[player] = nil
        end
        for model in pairs(Entities.byModel) do
            Entities.untrack(model, "shutdown")
        end
    end

    V.KIND_SHORT = KIND_SHORT
    V.entityKind = entityKind
    V.entityName = entityName
    V.losParams = losParams
end
