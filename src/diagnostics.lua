-- VEYL module: diagnostics
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local RunService = V.RunService
    local Stats = V.Stats
    local Workspace = V.Workspace
    local LocalPlayer = V.LocalPlayer
    local VERSION = V.VERSION
    local LIMITS = V.LIMITS
    local Log = V.Log
    local Cap = V.Cap
    local Settings = V.Settings
    local Entities = V.Entities
    local Weapons = V.Weapons
    local Diag = V.Diag
    local App = V.App
    local Maid = V.Maid
    local T = V.T
    local make = V.make

    ----------------------------------------------------------------------------
    -- 15. Diagnostics (client-visible observations only)
    ----------------------------------------------------------------------------

    Diag.history = {}
    Diag.markers = {}
    Diag.jumps = 0
    Diag.spikes = 0
    Diag.frameMs = 0

    function Diag.fps()
        return Diag.frameMs > 0 and math.floor(1000 / Diag.frameMs + 0.5) or 0
    end

    function Diag.mark(from, to)
        if not Settings.get("diag.markers") then
            return
        end
        local folder = App.fx()
        local function ball(position, color)
            local part = make("Part", {
                Name = "VEYLMarker",
                Anchored = true,
                CanCollide = false,
                CanQuery = false,
                CanTouch = false,
                CastShadow = false,
                Material = Enum.Material.Neon,
                Shape = Enum.PartType.Ball,
                Size = Vector3.new(0.8, 0.8, 0.8),
                Color = color,
                Transparency = 0.2,
                Position = position,
            })
            part.Parent = folder
            return part
        end
        local entry = { ball(from, T.warn), ball(to, T.bad) }
        table.insert(Diag.markers, entry)
        while #Diag.markers > LIMITS.markers do
            for _, part in ipairs(table.remove(Diag.markers, 1)) do
                part:Destroy()
            end
        end
        task.delay(10, function()
            local index = table.find(Diag.markers, entry)
            if index then
                table.remove(Diag.markers, index)
                for _, part in ipairs(entry) do
                    part:Destroy()
                end
            end
        end)
    end

    function Diag.clearMarkers()
        for _, entry in ipairs(Diag.markers) do
            for _, part in ipairs(entry) do
                part:Destroy()
            end
        end
        table.clear(Diag.markers)
    end

    function Diag.sample()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or not root:IsA("BasePart") then
            Diag.previous = nil
            return
        end
        local now = os.clock()
        local sample = { t = now, position = root.Position, velocity = root.AssemblyLinearVelocity }
        local previous = Diag.previous
        if previous and now - previous.t < 1 then
            local elapsed = now - previous.t
            local moved = (sample.position - previous.position).Magnitude
            local expected = math.max(previous.velocity.Magnitude, sample.velocity.Magnitude) * elapsed + 2
            local excess = moved - expected
            if excess > Settings.get("diag.posThreshold") then
                Diag.jumps += 1
                Log.add("warn", string.format("Position discontinuity observed: %.1f st in %.2f s (%.1f st beyond the velocity estimate). Client-side observation only; it does not prove server desync.", moved, elapsed, excess))
                Diag.mark(previous.position, sample.position)
            end
            local deltaVelocity = (sample.velocity - previous.velocity).Magnitude
            if deltaVelocity > Settings.get("diag.velThreshold") then
                Diag.spikes += 1
                Log.add("info", string.format("Velocity change observed: %.0f st/s within %.2f s.", deltaVelocity, elapsed))
            end
        end
        Diag.previous = sample
        table.insert(Diag.history, sample)
        if #Diag.history > LIMITS.history then
            table.remove(Diag.history, 1)
        end
    end

    function Diag.ping()
        local okNetwork, seconds = pcall(function()
            return LocalPlayer:GetNetworkPing()
        end)
        local network = (okNetwork and type(seconds) == "number") and (math.floor(seconds * 1000 + 0.5) .. " ms") or "Unavailable"
        local okData, data = pcall(function()
            local networkStats = Stats:FindFirstChild("Network")
            local serverStats = networkStats and networkStats:FindFirstChild("ServerStatsItem")
            local item = serverStats and serverStats:FindFirstChild("Data Ping")
            return item and item:GetValueString()
        end)
        return network, (okData and data) or "Unavailable"
    end

    function Diag.resetCounters()
        Diag.jumps, Diag.spikes = 0, 0
        table.clear(Diag.history)
        Diag.previous = nil
        Diag.clearMarkers()
    end

    function Diag.start()
        if Diag.maid then
            return
        end
        local maid = Maid.new()
        Diag.maid = maid
        local elapsed = 0
        maid:connect(RunService.Heartbeat, function(deltaTime)
            elapsed += deltaTime
            if elapsed >= 0.1 then
                elapsed = 0
                local ok, err = pcall(Diag.sample)
                if not ok and not Diag.sampleFailed then
                    Diag.sampleFailed = true
                    Log.add("warn", "Diagnostics sample failed: " .. tostring(err))
                end
            end
        end)
        maid:connect(RunService.RenderStepped, function(deltaTime)
            local ms = deltaTime * 1000
            Diag.frameMs = Diag.frameMs == 0 and ms or (Diag.frameMs * 0.9 + ms * 0.1)
        end)
        maid:connect(LocalPlayer.CharacterAdded, function()
            Diag.previous = nil
            Log.add("info", "Local character respawned; observations continue on the new character.")
        end)
    end

    function Diag.stop()
        if Diag.maid then
            Diag.maid:clean()
            Diag.maid = nil
        end
        Diag.clearMarkers()
        Diag.previous = nil
        Diag.frameMs = 0
    end

    function Diag.summary()
        local lines = {}
        local function add(line)
            table.insert(lines, line)
        end
        local network, data = Diag.ping()
        add("VEYL Control " .. VERSION .. " diagnostic summary (" .. os.date("%Y-%m-%d %H:%M:%S") .. ")")
        add("Runtime: " .. Cap.modeText())
        for _, row in ipairs(Cap.report) do
            add("  " .. row.name .. ": " .. row.status .. " — " .. row.detail)
        end
        add("Place: " .. game.PlaceId .. "  ·  Studio: " .. tostring(Cap.studio))
        add("FPS (estimate): " .. Diag.fps() .. "  ·  network ping: " .. network .. "  ·  data ping: " .. data)
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            local p = root.Position
            add(string.format("Position: %.1f, %.1f, %.1f  ·  speed %.1f st/s", p.X, p.Y, p.Z, root.AssemblyLinearVelocity.Magnitude))
        end
        local camera = Workspace.CurrentCamera
        if camera then
            add("Camera: " .. camera.CameraType.Name .. "  ·  FOV " .. math.floor(camera.FieldOfView + 0.5))
        end
        add(string.format("Entities: %d  ·  tool candidates: %d  ·  position jumps: %d  ·  velocity spikes: %d", Entities.count, Weapons.count, Diag.jumps, Diag.spikes))
        add("Recent log:")
        for index = 1, math.min(20, #Log.entries) do
            add("  " .. Log.format(Log.entries[index]))
        end
        return table.concat(lines, "\n")
    end
end
