-- VEYL module: weapons
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Players = V.Players
    local RunService = V.RunService
    local ReplicatedStorage = V.ReplicatedStorage
    local StarterPack = V.StarterPack
    local Workspace = V.Workspace
    local LocalPlayer = V.LocalPlayer
    local LIMITS = V.LIMITS
    local Util = V.Util
    local Log = V.Log
    local Weapons = V.Weapons
    local Session = V.Session
    local Maid = V.Maid

    ----------------------------------------------------------------------------
    -- 14. Weapon candidate discovery (evidence only; nothing is invoked)
    ----------------------------------------------------------------------------

    Weapons.byTool = {}
    Weapons.count = 0
    Weapons.dirty = {}
    Weapons.maid = Maid.new()
    Weapons.added = Util.signal()
    Weapons.removed = Util.signal()
    Weapons.changed = Util.signal()
    Weapons.nextId = 0
    Weapons.scanToken = 0

    local RANGED_WORDS = { "gun", "rifle", "pistol", "smg", "shotgun", "sniper", "blaster", "crossbow", "launcher", "revolver", "carbine", "musket", "cannon", "laser", "bow" }
    local MELEE_WORDS = { "sword", "knife", "katana", "axe", "blade", "dagger", "spear", "hammer", "mace", "scythe", "bat" }
    local RANGED_STATS = { "ammo", "magazine", "clip", "firerate", "rpm", "spread", "recoil", "bullet", "projectile", "reload", "mag" }
    local GENERIC_STATS = { "damage", "range", "headshot", "cooldown", "velocity" }
    local MUZZLE_WORDS = { "muzzle", "firepoint", "barrel", "shootpoint", "flash" }
    local FIRE_WORDS = { "fire", "shoot", "shot", "gunshot", "reload" }

    local function matchWord(name, words)
        local lower = string.lower(name)
        for _, word in ipairs(words) do
            if string.find(lower, word, 1, true) then
                return word
            end
        end
        return nil
    end

    local function sortedKeys(map)
        local keys = {}
        for key in pairs(map) do
            table.insert(keys, key)
        end
        table.sort(keys)
        return keys
    end

    function Weapons.inScope(tool)
        return tool:IsDescendantOf(Workspace) or tool:IsDescendantOf(LocalPlayer) or tool:IsDescendantOf(StarterPack) or tool:IsDescendantOf(ReplicatedStorage)
    end

    local function toolLocation(tool)
        local character = LocalPlayer.Character
        if character and tool:IsDescendantOf(character) then
            return "Equipped"
        end
        if tool:IsDescendantOf(LocalPlayer) then
            return "Backpack"
        end
        if tool:IsDescendantOf(Workspace) then
            local ancestor = tool.Parent
            while ancestor and ancestor ~= Workspace do
                if ancestor:IsA("Model") and Players:GetPlayerFromCharacter(ancestor) then
                    return "Other player"
                end
                ancestor = ancestor.Parent
            end
            return "World"
        end
        if tool:IsDescendantOf(StarterPack) or tool:IsDescendantOf(ReplicatedStorage) then
            return "Template"
        end
        return "Other"
    end

    function Weapons.analyze(record)
        local tool = record.tool
        local evidence, unknowns = {}, {}
        local ranged, melee, generic = 0, 0, 0

        local word = matchWord(tool.Name, RANGED_WORDS)
        if word then
            ranged += 2
            table.insert(evidence, "Name contains \"" .. word .. "\" (ranged keyword)")
        end
        word = matchWord(tool.Name, MELEE_WORDS)
        if word then
            melee += 2
            table.insert(evidence, "Name contains \"" .. word .. "\" (melee keyword)")
        end

        local rangedStats, genericStats = {}, {}
        local function noteStat(name)
            local hit = matchWord(name, RANGED_STATS)
            if hit then
                rangedStats[hit] = true
                return
            end
            hit = matchWord(name, GENERIC_STATS)
            if hit then
                genericStats[hit] = true
            end
        end

        local attributes = {}
        for name, value in pairs(tool:GetAttributes()) do
            table.insert(attributes, name .. " = " .. Util.truncate(tostring(value), 24))
            noteStat(name)
        end
        table.sort(attributes)

        local values, remotes = {}, {}
        local scripts, muzzle, fireSound, fireAnimation = 0, nil, nil, nil
        local descendants = tool:GetDescendants()
        for index, descendant in ipairs(descendants) do
            if index > LIMITS.toolDescendants then
                table.insert(unknowns, "Only the first " .. LIMITS.toolDescendants .. " of " .. #descendants .. " descendants were inspected.")
                break
            end
            local className = descendant.ClassName
            if descendant:IsA("ValueBase") then
                if #values < 30 then
                    table.insert(values, descendant.Name .. " (" .. className .. ")")
                end
                noteStat(descendant.Name)
            elseif className == "RemoteEvent" or className == "RemoteFunction" or className == "UnreliableRemoteEvent" then
                table.insert(remotes, descendant.Name .. " (" .. className .. ")")
            elseif descendant:IsA("LuaSourceContainer") then
                scripts += 1
            elseif className == "Attachment" or descendant:IsA("BasePart") then
                if not muzzle and matchWord(descendant.Name, MUZZLE_WORDS) then
                    muzzle = descendant.Name
                end
            elseif className == "Sound" then
                if not fireSound and matchWord(descendant.Name, FIRE_WORDS) then
                    fireSound = descendant.Name
                end
            elseif className == "Animation" then
                if not fireAnimation and matchWord(descendant.Name, FIRE_WORDS) then
                    fireAnimation = descendant.Name
                end
            end
        end

        local rangedList = sortedKeys(rangedStats)
        if #rangedList > 0 then
            ranged += math.min(#rangedList, 4)
            table.insert(evidence, "Ranged-style stats: " .. table.concat(rangedList, ", "))
        end
        local genericList = sortedKeys(genericStats)
        if #genericList > 0 then
            generic += math.min(#genericList, 2)
            table.insert(evidence, "Combat-style stats: " .. table.concat(genericList, ", "))
        end
        if muzzle then
            ranged += 2
            table.insert(evidence, "Muzzle-like attachment/part: " .. muzzle)
        end
        if fireSound then
            ranged += 1
            table.insert(evidence, "Firing/reload sound: " .. fireSound)
        end
        if fireAnimation then
            ranged += 1
            table.insert(evidence, "Firing/reload animation: " .. fireAnimation)
        end
        local handle = tool:FindFirstChild("Handle")
        if handle then
            table.insert(evidence, "Has a Handle part")
        elseif tool.RequiresHandle then
            table.insert(unknowns, "RequiresHandle is true but no Handle exists yet (it may still be streaming in).")
        end
        if tool.ToolTip ~= "" then
            table.insert(evidence, "ToolTip: " .. Util.truncate(tool.ToolTip, 60))
        end
        if #remotes > 0 then
            table.insert(evidence, #remotes .. " remote(s) present — listed only, never invoked")
            table.insert(unknowns, "Remote arguments and server-side behavior are unknown.")
        end
        if scripts > 0 then
            table.insert(unknowns, scripts .. " script(s) define the behavior; their source cannot be read at runtime.")
        end

        local classification
        if ranged >= 3 and ranged > melee then
            classification = "Likely ranged weapon"
        elseif melee >= 2 and melee >= ranged then
            classification = "Likely melee weapon"
        elseif ranged + melee + generic >= 1 then
            classification = "Possible weapon"
        else
            classification = "Tool (purpose unknown)"
        end
        local score = math.max(ranged, melee) + generic
        record.classification = classification
        record.confidence = score >= 6 and "High" or score >= 3 and "Medium" or score >= 1 and "Low" or "None"
        record.ranged = classification == "Likely ranged weapon"
        record.evidence = evidence
        record.unknowns = unknowns
        record.attributes = attributes
        record.values = values
        record.remotes = remotes
        record.location = toolLocation(tool)
        record.path = Util.fullName(tool)
        record.name = tool.Name
        record.compat = "Unverified"
        record.analyzedAt = os.clock()
    end

    function Weapons.track(tool)
        if not Session.alive or Weapons.byTool[tool] or not tool:IsA("Tool") or not Weapons.inScope(tool) then
            return
        end
        if Weapons.count >= LIMITS.tools then
            if not Weapons.limitLogged then
                Weapons.limitLogged = true
                Log.add("warn", "Tool registry limit (" .. LIMITS.tools .. ") reached; further tools are not tracked.")
            end
            return
        end
        Weapons.nextId += 1
        local record = { tool = tool, maid = Maid.new(), id = Weapons.nextId, name = tool.Name }
        local function markDirty()
            Weapons.dirty[record] = true
        end
        record.maid:connect(tool.DescendantAdded, markDirty)
        record.maid:connect(tool.DescendantRemoving, markDirty)
        record.maid:connect(tool.AttributeChanged, markDirty)
        record.maid:connect(tool.AncestryChanged, function()
            if Weapons.inScope(tool) then
                markDirty()
            else
                Weapons.untrack(tool)
            end
        end)
        Weapons.byTool[tool] = record
        Weapons.count += 1
        local ok, err = pcall(Weapons.analyze, record)
        if not ok then
            record.classification = "Analysis failed"
            record.confidence = "None"
            record.evidence, record.unknowns, record.attributes, record.values, record.remotes = {}, { tostring(err) }, {}, {}, {}
            record.location, record.path, record.compat = toolLocation(tool), Util.fullName(tool), "Unverified"
        end
        Weapons.added:Fire(record)
    end

    function Weapons.untrack(tool)
        local record = Weapons.byTool[tool]
        if not record then
            return
        end
        Weapons.byTool[tool] = nil
        Weapons.count -= 1
        Weapons.dirty[record] = nil
        record.removed = true
        record.maid:clean()
        Weapons.removed:Fire(record)
    end

    function Weapons.scan()
        Weapons.scanToken += 1
        local token = Weapons.scanToken
        task.spawn(function()
            for _, container in ipairs({ LocalPlayer, Workspace, StarterPack, ReplicatedStorage }) do
                local descendants = container:GetDescendants()
                for index, instance in ipairs(descendants) do
                    if not Session.alive or token ~= Weapons.scanToken then
                        return
                    end
                    if instance.ClassName == "Tool" then
                        Weapons.track(instance)
                    end
                    if index % 4000 == 0 then
                        task.wait()
                    end
                end
            end
        end)
    end

    function Weapons.start()
        local function onDescendant(instance)
            if instance.ClassName == "Tool" then
                task.defer(function()
                    if Session.alive and instance.Parent then
                        Weapons.track(instance)
                    end
                end)
            end
        end
        for _, container in ipairs({ LocalPlayer, Workspace, StarterPack, ReplicatedStorage }) do
            Weapons.maid:connect(container.DescendantAdded, onDescendant)
        end
        local elapsed = 0
        Weapons.maid:connect(RunService.Heartbeat, function(deltaTime)
            elapsed += deltaTime
            if elapsed < 0.5 then
                return
            end
            elapsed = 0
            local processed = 0
            for record in pairs(Weapons.dirty) do
                Weapons.dirty[record] = nil
                if not record.removed then
                    local ok, err = pcall(Weapons.analyze, record)
                    if not ok then
                        Log.add("warn", "Tool analysis failed for " .. record.name .. ": " .. tostring(err))
                    end
                    Weapons.changed:Fire(record)
                end
                processed += 1
                if processed >= 25 then
                    break
                end
            end
        end)
        Weapons.scan()
    end

    function Weapons.rescan()
        for tool in pairs(Weapons.byTool) do
            Weapons.untrack(tool)
        end
        Weapons.limitLogged = false
        Weapons.scan()
        Log.add("info", "Tool candidates rescanned.")
    end

    function Weapons.stop()
        Weapons.scanToken += 1
        Weapons.maid:clean()
        for tool in pairs(Weapons.byTool) do
            Weapons.untrack(tool)
        end
    end

    V.RANGED_WORDS = RANGED_WORDS
    V.MELEE_WORDS = MELEE_WORDS
    V.RANGED_STATS = RANGED_STATS
    V.GENERIC_STATS = GENERIC_STATS
    V.MUZZLE_WORDS = MUZZLE_WORDS
    V.FIRE_WORDS = FIRE_WORDS
    V.matchWord = matchWord
    V.sortedKeys = sortedKeys
    V.toolLocation = toolLocation
end
