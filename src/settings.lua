-- VEYL module: settings
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Lighting = V.Lighting
    local Util = V.Util
    local Log = V.Log
    local Settings = V.Settings

    ----------------------------------------------------------------------------
    -- 4. Settings registry (validated defaults, change listeners, reset)
    ----------------------------------------------------------------------------

    Settings.schema = {}
    Settings.order = {}
    Settings.values = {}
    Settings.listeners = {}
    Settings.changed = Util.signal()

    local function define(key, spec)
        spec.key = key
        if spec.type == "color" then
            spec.default = Util.fromHex(spec.default) or spec.default
        end
        Settings.schema[key] = spec
        table.insert(Settings.order, key)
        Settings.values[key] = spec.default
    end

    local function valuesEqual(a, b)
        if typeof(a) == "Color3" and typeof(b) == "Color3" then
            return Util.colorEquals(a, b)
        end
        return a == b
    end

    function Settings.validate(key, value)
        local spec = Settings.schema[key]
        if not spec then
            return false, nil, "Unknown setting"
        end
        if spec.type == "boolean" then
            if type(value) ~= "boolean" then
                return false, nil, "Expected on/off"
            end
            return true, value
        elseif spec.type == "number" then
            local number = tonumber(value)
            if not number or number ~= number or number == math.huge or number == -math.huge then
                return false, nil, "Enter a number"
            end
            number = math.clamp(number, spec.min, spec.max)
            if spec.step then
                number = spec.min + math.floor((number - spec.min) / spec.step + 0.5) * spec.step
            end
            return true, math.clamp(Util.round(number, 4), spec.min, spec.max)
        elseif spec.type == "enum" then
            if table.find(spec.options, value) then
                return true, value
            end
            return false, nil, "Unsupported option"
        elseif spec.type == "color" then
            if typeof(value) == "Color3" then
                return true, value
            end
            local color = Util.fromHex(value)
            if color then
                return true, color
            end
            return false, nil, "Use #RRGGBB"
        end
        return false, nil, "Unsupported setting type"
    end

    function Settings.get(key)
        return Settings.values[key]
    end

    function Settings.set(key, value)
        local ok, normalized, err = Settings.validate(key, value)
        if not ok then
            return false, nil, err
        end
        if valuesEqual(Settings.values[key], normalized) then
            return true, normalized
        end
        Settings.values[key] = normalized
        local list = Settings.listeners[key]
        if list then
            for handle, callback in pairs(list) do
                if handle.connected then
                    local okCall, callErr = pcall(callback, normalized)
                    if not okCall then
                        Log.add("warn", "Setting listener for " .. key .. " failed: " .. tostring(callErr))
                    end
                end
            end
        end
        Settings.changed:Fire(key, normalized)
        return true, normalized
    end

    function Settings.on(key, callback)
        local list = Settings.listeners[key]
        if not list then
            list = {}
            Settings.listeners[key] = list
        end
        local handle = { connected = true }
        function handle:Disconnect()
            handle.connected = false
            list[handle] = nil
        end
        list[handle] = callback
        return handle
    end

    function Settings.default(key)
        local spec = Settings.schema[key]
        return spec and spec.default
    end

    function Settings.reset(key)
        local spec = Settings.schema[key]
        if spec then
            Settings.set(key, spec.default)
        end
    end

    function Settings.resetPrefix(prefix)
        for _, key in ipairs(Settings.order) do
            if prefix == nil or string.sub(key, 1, #prefix) == prefix then
                Settings.reset(key)
            end
        end
    end

    function Settings.serialize()
        local out = {}
        for _, key in ipairs(Settings.order) do
            local spec = Settings.schema[key]
            if not spec.session then
                local value = Settings.values[key]
                out[key] = typeof(value) == "Color3" and Util.toHex(value) or value
            end
        end
        return out
    end

    function Settings.loadTable(data)
        local applied, rejected = 0, 0
        if type(data) ~= "table" then
            return applied, rejected
        end
        for key, value in pairs(data) do
            local spec = type(key) == "string" and Settings.schema[key]
            if spec and not spec.session then
                local ok = Settings.set(key, value)
                if ok then
                    applied += 1
                else
                    rejected += 1
                end
            else
                rejected += 1
            end
        end
        return applied, rejected
    end

    -- Snapshot of the game's lighting at startup, used as World defaults.
    local LightingStart = {
        Brightness = Lighting.Brightness,
        ExposureCompensation = Lighting.ExposureCompensation,
        ClockTime = Lighting.ClockTime,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
    }

    -- Interface
    define("ui.translucent", { type = "boolean", default = true })
    define("ui.blur", { type = "boolean", default = false })
    define("ui.scale", { type = "number", min = 80, max = 130, step = 5, default = 100 })
    define("ui.toasts", { type = "boolean", default = true })
    define("ui.autosave", { type = "boolean", default = true })

    -- ESP / Visuals
    define("esp.enabled", { type = "boolean", default = false, session = true })
    define("esp.renderer", { type = "enum", options = { "Auto", "Drawing", "GUI" }, default = "Auto" })
    define("esp.maxDistance", { type = "number", min = 50, max = 3000, step = 10, default = 1000 })
    define("esp.boxes", { type = "boolean", default = true })
    define("esp.names", { type = "boolean", default = true })
    define("esp.distance", { type = "boolean", default = true })
    define("esp.health", { type = "boolean", default = true })
    define("esp.tracers", { type = "boolean", default = false })
    define("esp.offscreen", { type = "boolean", default = true })
    define("esp.highlight", { type = "boolean", default = false })
    define("esp.visibility", { type = "boolean", default = true })
    define("esp.visColors", { type = "boolean", default = false })
    define("esp.typeColors", { type = "boolean", default = false })
    define("esp.showTargets", { type = "boolean", default = true })
    define("esp.showNpcs", { type = "boolean", default = true })
    define("esp.showPlayers", { type = "boolean", default = true })
    define("esp.tracerOrigin", { type = "enum", options = { "Bottom", "Center", "Mouse" }, default = "Bottom" })
    define("esp.textSize", { type = "number", min = 10, max = 18, step = 1, default = 13 })
    define("esp.boxTransparency", { type = "number", min = 0, max = 90, step = 5, default = 0 })
    define("esp.tracerTransparency", { type = "number", min = 0, max = 90, step = 5, default = 30 })
    define("esp.hlDepth", { type = "enum", options = { "Occluded", "Always on top" }, default = "Occluded" })
    define("esp.hlFillTransparency", { type = "number", min = 0, max = 100, step = 5, default = 75 })
    define("esp.hlOutlineTransparency", { type = "number", min = 0, max = 100, step = 5, default = 10 })

    -- Per-element colors
    define("color.box", { type = "color", default = "#4DA8FF" })
    define("color.name", { type = "color", default = "#E6EAF2" })
    define("color.tracer", { type = "color", default = "#38D6E6" })
    define("color.health", { type = "color", default = "#58D68D" })
    define("color.target", { type = "color", default = "#FFBE5C" })
    define("color.fov", { type = "color", default = "#9FB4D9" })
    define("color.hlFill", { type = "color", default = "#4DA8FF" })
    define("color.hlOutline", { type = "color", default = "#FFFFFF" })
    define("color.visible", { type = "color", default = "#58D68D" })
    define("color.occluded", { type = "color", default = "#FF636E" })
    define("color.player", { type = "color", default = "#B794FF" })
    define("color.npc", { type = "color", default = "#38D6E6" })
    define("color.testTarget", { type = "color", default = "#FFBE5C" })

    -- Aim Lab
    define("aim.enabled", { type = "boolean", default = false, session = true })
    define("aim.activation", { type = "enum", options = { "Hold key", "Always on" }, default = "Hold key" })
    define("aim.fov", { type = "number", min = 30, max = 600, step = 5, default = 140 })
    define("aim.maxDistance", { type = "number", min = 25, max = 3000, step = 25, default = 500 })
    define("aim.targetPart", { type = "enum", options = { "Head", "Torso", "Root" }, default = "Head" })
    define("aim.priority", { type = "enum", options = { "Closest to reticle", "Shortest distance", "Lowest health" }, default = "Closest to reticle" })
    define("aim.responsiveness", { type = "number", min = 1, max = 100, step = 1, default = 25 })
    define("aim.requireLos", { type = "boolean", default = true })
    define("aim.includeNpcs", { type = "boolean", default = false })
    define("aim.lockSelected", { type = "boolean", default = true })
    define("aim.showFov", { type = "boolean", default = true })
    define("aim.showIndicator", { type = "boolean", default = true })
    define("aim.reticle", { type = "enum", options = { "Screen center", "Mouse" }, default = "Screen center" })

    -- World (local lighting overrides)
    define("world.enabled", { type = "boolean", default = false, session = true })
    define("world.brightness", { type = "number", min = 0, max = 10, step = 0.1, default = math.clamp(Util.round(LightingStart.Brightness, 1), 0, 10) })
    define("world.exposure", { type = "number", min = -3, max = 3, step = 0.05, default = math.clamp(Util.round(LightingStart.ExposureCompensation, 2), -3, 3) })
    define("world.clockOverride", { type = "boolean", default = false })
    define("world.clockTime", { type = "number", min = 0, max = 24, step = 0.1, default = math.clamp(Util.round(LightingStart.ClockTime, 1), 0, 24) })
    define("world.shadows", { type = "boolean", default = LightingStart.GlobalShadows })
    define("world.ambient", { type = "color", default = Util.toHex(LightingStart.Ambient) })
    define("world.ccEnabled", { type = "boolean", default = true })
    define("world.saturation", { type = "number", min = -100, max = 100, step = 1, default = 0 })
    define("world.contrast", { type = "number", min = -100, max = 100, step = 1, default = 0 })
    define("world.tint", { type = "color", default = "#FFFFFF" })
    define("world.bloomEnabled", { type = "boolean", default = false })
    define("world.bloomIntensity", { type = "number", min = 0, max = 100, step = 1, default = 40 })
    define("world.bloomSize", { type = "number", min = 0, max = 56, step = 1, default = 24 })
    define("world.bloomThreshold", { type = "number", min = 0, max = 4, step = 0.05, default = 2 })
    define("world.atmosEnabled", { type = "boolean", default = false })
    define("world.atmosDensity", { type = "number", min = 0, max = 1, step = 0.01, default = 0.3 })
    define("world.atmosHaze", { type = "number", min = 0, max = 10, step = 0.1, default = 1 })

    -- Music
    define("music.volume", { type = "number", min = 0, max = 100, step = 1, default = 45 })
    define("music.muted", { type = "boolean", default = false })
    define("music.shuffle", { type = "boolean", default = false })
    define("music.repeatMode", { type = "enum", options = { "Off", "One", "All" }, default = "Off" })
    define("music.favoritesOnly", { type = "boolean", default = false })

    -- Diagnostics
    define("diag.enabled", { type = "boolean", default = true })
    define("diag.markers", { type = "boolean", default = true })
    define("diag.posThreshold", { type = "number", min = 5, max = 200, step = 5, default = 30 })
    define("diag.velThreshold", { type = "number", min = 20, max = 500, step = 10, default = 150 })

    V.define = define
    V.valuesEqual = valuesEqual
    V.LightingStart = LightingStart
end
