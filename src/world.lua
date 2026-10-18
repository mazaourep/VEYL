-- VEYL module: world
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Lighting = V.Lighting
    local Workspace = V.Workspace
    local NAMES = V.NAMES
    local Util = V.Util
    local Log = V.Log
    local Settings = V.Settings
    local World = V.World
    local App = V.App
    local make = V.make

    ----------------------------------------------------------------------------
    -- Local FX folder (diagnostic markers, highlights). Client-created, local only.
    ----------------------------------------------------------------------------

    function App.fx()
        if App.fxFolder and App.fxFolder.Parent then
            return App.fxFolder
        end
        local folder = make("Folder", { Name = NAMES.fx })
        folder:SetAttribute(NAMES.owned, true)
        folder.Parent = Workspace
        App.fxFolder = folder
        return folder
    end

    ----------------------------------------------------------------------------
    -- 13. World: local lighting overrides with a snapshot/restore rule
    --     Rule: a property is restored only if it still holds the value VEYL
    --     wrote. If the game changed it in the meantime, the game's value stays.
    ----------------------------------------------------------------------------

    World.overrides = {}
    World.effects = {}
    World.keptChanges = 0

    local function approxEqual(a, b)
        if type(a) == "number" and type(b) == "number" then
            return math.abs(a - b) < 1e-3
        end
        if typeof(a) == "Color3" and typeof(b) == "Color3" then
            return Util.colorEquals(a, b)
        end
        return a == b
    end

    function World.write(instance, property, value)
        local map = World.overrides[instance]
        if not map then
            map = {}
            World.overrides[instance] = map
        end
        local record = map[property]
        if not record then
            record = { original = instance[property] }
            map[property] = record
        end
        instance[property] = value
        record.written = instance[property]
    end

    function World.release(instance, property)
        local map = World.overrides[instance]
        local record = map and map[property]
        if not record then
            return
        end
        map[property] = nil
        if next(map) == nil then
            World.overrides[instance] = nil
        end
        if instance.Parent == nil then
            return
        end
        if approxEqual(instance[property], record.written) then
            instance[property] = record.original
        else
            World.keptChanges += 1
            Log.add("info", "World: kept the game's newer value for " .. instance.Name .. "." .. property .. ".")
        end
    end

    function World.dropEffect(name)
        local effect = World.effects[name]
        if effect then
            effect:Destroy()
            World.effects[name] = nil
        end
    end

    function World.effect(className, name)
        local effect = World.effects[name]
        if not effect or not effect.Parent then
            effect = make(className, { Name = name })
            effect:SetAttribute(NAMES.owned, true)
            effect.Parent = Lighting
            World.effects[name] = effect
        end
        return effect
    end

    local function gameAtmosphere()
        for _, child in ipairs(Lighting:GetChildren()) do
            if child:IsA("Atmosphere") and not child:GetAttribute(NAMES.owned) then
                return child
            end
        end
        return nil
    end

    function World.apply()
        if not Settings.get("world.enabled") then
            return
        end
        local values = Settings.values
        World.write(Lighting, "Brightness", values["world.brightness"])
        World.write(Lighting, "ExposureCompensation", values["world.exposure"])
        World.write(Lighting, "GlobalShadows", values["world.shadows"])
        World.write(Lighting, "Ambient", values["world.ambient"])
        if values["world.clockOverride"] then
            World.write(Lighting, "ClockTime", values["world.clockTime"])
        else
            World.release(Lighting, "ClockTime")
        end

        if values["world.ccEnabled"] then
            local effect = World.effect("ColorCorrectionEffect", NAMES.colorCorrection)
            effect.Saturation = values["world.saturation"] / 100
            effect.Contrast = values["world.contrast"] / 100
            effect.TintColor = values["world.tint"]
            effect.Enabled = true
        else
            World.dropEffect(NAMES.colorCorrection)
        end

        if values["world.bloomEnabled"] then
            local effect = World.effect("BloomEffect", NAMES.bloom)
            effect.Intensity = values["world.bloomIntensity"] / 100
            effect.Size = values["world.bloomSize"]
            effect.Threshold = values["world.bloomThreshold"]
            effect.Enabled = true
        else
            World.dropEffect(NAMES.bloom)
        end

        local existing = gameAtmosphere()
        if values["world.atmosEnabled"] then
            if existing then
                World.dropEffect(NAMES.atmosphere)
                World.write(existing, "Density", values["world.atmosDensity"])
                World.write(existing, "Haze", values["world.atmosHaze"])
            else
                local effect = World.effect("Atmosphere", NAMES.atmosphere)
                effect.Density = values["world.atmosDensity"]
                effect.Haze = values["world.atmosHaze"]
            end
        else
            World.dropEffect(NAMES.atmosphere)
            for instance in pairs(World.overrides) do
                if instance:IsA("Atmosphere") then
                    World.release(instance, "Density")
                    World.release(instance, "Haze")
                end
            end
        end
    end

    function World.restoreAll()
        for instance, map in pairs(World.overrides) do
            for property in pairs(map) do
                World.release(instance, property)
            end
        end
        table.clear(World.overrides)
        for name in pairs(World.effects) do
            World.dropEffect(name)
        end
    end

    function World.overrideCount()
        local count = 0
        for _, map in pairs(World.overrides) do
            for _ in pairs(map) do
                count += 1
            end
        end
        for _ in pairs(World.effects) do
            count += 1
        end
        return count
    end

    V.approxEqual = approxEqual
    V.gameAtmosphere = gameAtmosphere
end
