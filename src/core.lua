-- VEYL module: core
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    ----------------------------------------------------------------------------
    -- 1. Services and bootstrap
    ----------------------------------------------------------------------------

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local SoundService = game:GetService("SoundService")
    local TeleportService = game:GetService("TeleportService")
    local CollectionService = game:GetService("CollectionService")
    local HttpService = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local ContentProvider = game:GetService("ContentProvider")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StarterPack = game:GetService("StarterPack")
    local Stats = game:GetService("Stats")
    local Workspace = game:GetService("Workspace")

    if not RunService:IsClient() then
        error("VEYL Control is a client runtime and cannot run on the server.", 0)
    end
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local LocalPlayer = Players.LocalPlayer
    while not LocalPlayer do
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        LocalPlayer = Players.LocalPlayer
    end
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 15)

    ----------------------------------------------------------------------------
    -- 2. Configuration and constants
    ----------------------------------------------------------------------------

    local VERSION = "2.0.0"

    local NAMES = {
        gui = "VEYLControl",
        overlay = "VEYLOverlay",
        fx = "VEYLClientFX",
        blur = "VEYLClientBlur",
        colorCorrection = "VEYLColorCorrection",
        bloom = "VEYLBloom",
        atmosphere = "VEYLAtmosphere",
        sound = "VEYLMusicPlayer",
        aimStep = "VEYLAimLab",
        tag = "VEYLTestTarget",
        targetLabel = "VEYLTargetName",
        owned = "VEYLOwned",
    }

    -- Instances left by earlier builds. Each entry is matched by exact name AND class.
    local LEGACY_INSTANCES = {
        { name = "NovaAdminConsole", class = "ScreenGui", where = "gui" },
        { name = "NovaOverlay", class = "ScreenGui", where = "gui" },
        { name = "NovaClientFX", class = "Folder", where = "workspace" },
        { name = "VEYLControl", class = "ScreenGui", where = "gui" },
        { name = "VEYLOverlay", class = "ScreenGui", where = "gui" },
        { name = "VEYLClientFX", class = "Folder", where = "workspace" },
        { name = "VEYLClientBlur", class = "BlurEffect", where = "lighting" },
        { name = "VEYLLocalColorCorrection", class = "ColorCorrectionEffect", where = "lighting" },
        { name = "VEYLColorCorrection", class = "ColorCorrectionEffect", where = "lighting" },
        { name = "VEYLBloom", class = "BloomEffect", where = "lighting" },
        { name = "VEYLAtmosphere", class = "Atmosphere", where = "lighting" },
        { name = "VEYLMusicPlayer", class = "Sound", where = "sound" },
    }

    local LIMITS = {
        logs = 200,
        logView = 60,
        toasts = 4,
        queue = 200,
        bookmarks = 50,
        npcs = 400,
        tools = 400,
        toolDescendants = 600,
        entityRows = 100,
        toolRows = 100,
        history = 120,
        markers = 20,
        highlights = 30,
        configBytes = 262144,
    }

    ----------------------------------------------------------------------------
    -- Module tables (declared up front so every section can reference them)
    ----------------------------------------------------------------------------

    local Util, Log, Notify, Cap, Settings, Binds, Persist = {}, {}, {}, {}, {}, {}, {}
    local UI, Popup, Overlay, Entities, ESP, Aim, World = {}, {}, {}, {}, {}, {}, {}
    local Weapons, Diag, Music, Rejoin, Features, App = {}, {}, {}, {}, {}, {}

    local Session = {
        alive = true,
        startedAt = os.clock(),
    }

    ----------------------------------------------------------------------------
    -- Utilities
    ----------------------------------------------------------------------------

    function Util.trim(value)
        return (string.gsub(string.gsub(tostring(value or ""), "^%s+", ""), "%s+$", ""))
    end

    function Util.round(value, decimals)
        local factor = 10 ^ (decimals or 0)
        return math.floor(value * factor + 0.5) / factor
    end

    function Util.decimalsForStep(step)
        if not step or step >= 1 then
            return 0
        end
        local text = string.format("%.6f", step):gsub("0+$", "")
        local dot = string.find(text, ".", 1, true)
        return dot and (#text - dot) or 0
    end

    function Util.formatNumber(value, decimals)
        if decimals <= 0 then
            return tostring(math.floor(value + 0.5))
        end
        return string.format("%." .. decimals .. "f", value)
    end

    function Util.toHex(color)
        return string.format(
            "#%02X%02X%02X",
            math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
            math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
            math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
        )
    end

    function Util.fromHex(text)
        if type(text) ~= "string" then
            return nil
        end
        local r, g, b = string.match(Util.trim(text), "^#?(%x%x)(%x%x)(%x%x)$")
        if not r then
            return nil
        end
        return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
    end

    function Util.colorEquals(a, b)
        return Util.toHex(a) == Util.toHex(b)
    end

    function Util.formatTime(seconds)
        seconds = math.max(0, math.floor(tonumber(seconds) or 0))
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    end

    function Util.fullName(instance)
        local ok, name = pcall(function()
            return instance:GetFullName()
        end)
        return ok and name or "(unavailable)"
    end

    function Util.truncate(text, maxLength)
        text = tostring(text or "")
        if #text <= maxLength then
            return text
        end
        return string.sub(text, 1, maxLength - 1) .. "…"
    end

    -- Minimal signal used by VEYL's own modules (not Roblox events).
    function Util.signal()
        local signal = { handlers = {} }
        function signal:Connect(callback)
            local handle = { connected = true }
            signal.handlers[handle] = callback
            function handle:Disconnect()
                handle.connected = false
                signal.handlers[handle] = nil
            end
            return handle
        end
        function signal:Fire(...)
            for handle, callback in pairs(signal.handlers) do
                if handle.connected then
                    local ok, err = pcall(callback, ...)
                    if not ok then
                        Log.add("warn", "Internal handler error: " .. tostring(err))
                    end
                end
            end
        end
        return signal
    end

    ----------------------------------------------------------------------------
    -- Lifecycle: Maid owns connections, instances, threads and overlay objects
    ----------------------------------------------------------------------------

    local Maid = {}
    Maid.__index = Maid

    local function cleanupTask(item)
        local kind = typeof(item)
        if kind == "RBXScriptConnection" then
            item:Disconnect()
        elseif kind == "Instance" then
            item:Destroy()
        elseif kind == "function" then
            item()
        elseif kind == "thread" then
            if coroutine.status(item) ~= "running" then
                task.cancel(item)
            end
        elseif kind == "table" then
            if item.Disconnect then
                item:Disconnect()
            elseif item.Destroy then
                item:Destroy()
            end
        end
    end

    function Maid.new()
        return setmetatable({ tasks = {} }, Maid)
    end

    function Maid:give(item)
        if item ~= nil then
            table.insert(self.tasks, item)
        end
        return item
    end

    function Maid:connect(signal, callback)
        return self:give(signal:Connect(callback))
    end

    function Maid:delay(seconds, callback)
        return self:give(task.delay(seconds, function()
            if Session.alive then
                callback()
            end
        end))
    end

    function Maid:clean()
        local tasks = self.tasks
        self.tasks = {}
        for index = #tasks, 1, -1 do
            local ok, err = pcall(cleanupTask, tasks[index])
            if not ok then
                warn("[VEYL] Cleanup error: " .. tostring(err))
            end
        end
    end

    function Maid:Destroy()
        self:clean()
    end

    -- Root owns everything that lives for the whole session.
    local Root = Maid.new()

    ----------------------------------------------------------------------------
    -- Logging (bounded ring buffer)
    ----------------------------------------------------------------------------

    Log.entries = {}
    Log.version = 0

    local LOG_TAGS = { info = "INFO", ok = " OK ", warn = "WARN", error = "FAIL" }

    function Log.add(level, message)
        message = tostring(message)
        table.insert(Log.entries, 1, { time = os.date("%H:%M:%S"), level = level or "info", text = message })
        while #Log.entries > LIMITS.logs do
            table.remove(Log.entries)
        end
        Log.version += 1
        if level == "error" or level == "warn" then
            warn("[VEYL] " .. message)
        else
            print("[VEYL] " .. message)
        end
    end

    function Log.format(entry)
        return string.format("%s [%s] %s", entry.time, LOG_TAGS[entry.level] or "INFO", entry.text)
    end

    function Log.clear()
        table.clear(Log.entries)
        Log.version += 1
    end

    -- Wrap a per-frame step so a broken loop cannot fail forever.
    function Util.guardStep(name, step, onFatal)
        local failures = 0
        return function(...)
            local ok, err = pcall(step, ...)
            if ok then
                failures = 0
                return
            end
            failures += 1
            if failures == 1 then
                Log.add("warn", name .. " error: " .. tostring(err))
            end
            if failures >= 30 then
                failures = 0
                Notify.push(name .. " stopped after 30 consecutive errors: " .. tostring(err), "error")
                if onFatal then
                    onFatal()
                end
            end
        end
    end

    V.Players = Players
    V.RunService = RunService
    V.UserInputService = UserInputService
    V.Lighting = Lighting
    V.SoundService = SoundService
    V.TeleportService = TeleportService
    V.CollectionService = CollectionService
    V.HttpService = HttpService
    V.MarketplaceService = MarketplaceService
    V.ContentProvider = ContentProvider
    V.ReplicatedStorage = ReplicatedStorage
    V.StarterPack = StarterPack
    V.Stats = Stats
    V.Workspace = Workspace
    V.LocalPlayer = LocalPlayer
    V.PlayerGui = PlayerGui
    V.VERSION = VERSION
    V.NAMES = NAMES
    V.LEGACY_INSTANCES = LEGACY_INSTANCES
    V.LIMITS = LIMITS
    V.Util = Util
    V.Log = Log
    V.Notify = Notify
    V.Cap = Cap
    V.Settings = Settings
    V.Binds = Binds
    V.Persist = Persist
    V.UI = UI
    V.Popup = Popup
    V.Overlay = Overlay
    V.Entities = Entities
    V.ESP = ESP
    V.Aim = Aim
    V.World = World
    V.Weapons = Weapons
    V.Diag = Diag
    V.Music = Music
    V.Rejoin = Rejoin
    V.Features = Features
    V.App = App
    V.Session = Session
    V.Maid = Maid
    V.cleanupTask = cleanupTask
    V.Root = Root
    V.LOG_TAGS = LOG_TAGS
end
