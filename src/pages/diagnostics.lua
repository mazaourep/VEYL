-- VEYL module: pages/diagnostics
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Workspace = V.Workspace
    local LocalPlayer = V.LocalPlayer
    local LIMITS = V.LIMITS
    local Log = V.Log
    local UI = V.UI
    local Diag = V.Diag
    local T = V.T
    local make = V.make
    local corner = V.corner
    local padding = V.padding
    local text = V.text
    local Pages = V.Pages

    -- DIAGNOSTICS --------------------------------------------------------------
    function Pages.diagnostics()
        local page = UI.page("Diagnostics")
        local live = UI.section(page, "left", "Live client observations")
        local rows = {
            fps = UI.info(live, { label = "Frame rate", desc = "Estimate from a smoothed RenderStepped frame time." }),
            frame = UI.info(live, { label = "Frame time", desc = "Smoothed frame time in milliseconds." }),
            position = UI.info(live, { label = "Position", desc = "Local HumanoidRootPart position, studs." }),
            velocity = UI.info(live, { label = "Velocity", desc = "AssemblyLinearVelocity magnitude, studs per second." }),
            walk = UI.info(live, { label = "WalkSpeed", desc = "Local Humanoid.WalkSpeed." }),
            state = UI.info(live, { label = "Humanoid state", desc = "Local Humanoid:GetState()." }),
            camera = UI.info(live, { label = "Camera", desc = "CameraType and FieldOfView." }),
            subject = UI.info(live, { label = "Camera subject", desc = "Camera.CameraSubject." }),
            camDistance = UI.info(live, { label = "Camera ↔ character", desc = "Distance from the camera to your root part, studs." }),
            ping = UI.info(live, { label = "Network ping", desc = "Player:GetNetworkPing() in milliseconds, if available." }),
            dataPing = UI.info(live, { label = "Data ping (Stats)", desc = "Stats › Network › ServerStatsItem › Data Ping, if readable." }),
            history = UI.info(live, { label = "History", desc = "Bounded 10 Hz sample buffer." }),
        }

        local detection = UI.section(page, "right", "Discontinuity detection")
        UI.toggle(detection, { key = "diag.enabled", label = "Enable sampling", desc = "Sample local position and velocity at 10 Hz." })
        UI.toggle(detection, { key = "diag.markers", label = "Place markers", desc = "Temporary local markers (removed after 10 s, max " .. LIMITS.markers .. ")." })
        UI.slider(detection, { key = "diag.posThreshold", label = "Position jump threshold", suffix = " st", desc = "Distance beyond what velocity explains before an event is logged." })
        UI.slider(detection, { key = "diag.velThreshold", label = "Velocity change threshold", suffix = " st/s", desc = "Velocity change within one sample before an event is logged." })
        local jumpsRow = UI.info(detection, { label = "Position jumps", desc = "Observed since the last reset." })
        local spikesRow = UI.info(detection, { label = "Velocity spikes", desc = "Observed since the last reset." })
        UI.button(detection, { text = "Reset counters and markers", desc = "Clear history, counters and markers.", callback = Diag.resetCounters })
        UI.note(detection, "These are client-side observations. A local position jump does not prove a server-side desync; Studio Network Simulator is not used.", T.warn)

        local logSection = UI.section(page, "right", "Event log")
        local logHolder = make("ScrollingFrame", {
            BackgroundColor3 = T.field,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 200),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = T.line,
            LayoutOrder = logSection.nextOrder(),
        }, logSection.frame)
        corner(logHolder, 4)
        table.insert(logSection.rows, { frame = logHolder, follow = true, text = "" })
        local logText = text(logHolder, {
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = T.mono,
            TextSize = 11,
            TextColor3 = T.muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = "",
        })
        padding(logText, 6, 6, 4, 4)
        UI.buttons(logSection, {
            { text = "Clear log", callback = Log.clear },
            { text = "Copy log", callback = function()
                local lines = {}
                for _, entry in ipairs(Log.entries) do
                    table.insert(lines, Log.format(entry))
                end
                UI.copy("Event log", #lines > 0 and table.concat(lines, "\n") or "(empty)")
            end },
        }, "Latest first; capped at " .. LIMITS.logs .. " entries.")
        local shownVersion = -1

        page.updateInterval = 0.25
        page.onUpdate = function()
            if Diag.maid then
                rows.fps.set(Diag.fps() .. " FPS (estimate)")
                rows.frame.set(string.format("%.1f ms", Diag.frameMs))
            else
                rows.fps.set("Sampling off", T.muted)
                rows.frame.set("—", T.muted)
            end
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if root and root:IsA("BasePart") then
                local p = root.Position
                rows.position.set(string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z))
                rows.velocity.set(string.format("%.1f st/s", root.AssemblyLinearVelocity.Magnitude))
            else
                rows.position.set("No character", T.muted)
                rows.velocity.set("—", T.muted)
            end
            if humanoid then
                rows.walk.set(string.format("%.1f", humanoid.WalkSpeed))
                rows.state.set(humanoid:GetState().Name)
            else
                rows.walk.set("—", T.muted)
                rows.state.set("—", T.muted)
            end
            local camera = Workspace.CurrentCamera
            if camera then
                rows.camera.set(camera.CameraType.Name .. " · FOV " .. math.floor(camera.FieldOfView + 0.5))
                local subject = camera.CameraSubject
                rows.subject.set(subject and (subject.Name .. " (" .. subject.ClassName .. ")") or "None")
                rows.camDistance.set((root and root:IsA("BasePart")) and string.format("%.1f st", (camera.CFrame.Position - root.Position).Magnitude) or "—")
            else
                rows.camera.set("No camera", T.bad)
            end
            local network, data = Diag.ping()
            rows.ping.set(network)
            rows.dataPing.set(data)
            rows.history.set(#Diag.history .. " / " .. LIMITS.history .. " samples")
            jumpsRow.set(tostring(Diag.jumps), Diag.jumps > 0 and T.warn or T.text)
            spikesRow.set(tostring(Diag.spikes))
            if shownVersion ~= Log.version then
                shownVersion = Log.version
                local lines = {}
                for index = 1, math.min(LIMITS.logView, #Log.entries) do
                    table.insert(lines, Log.format(Log.entries[index]))
                end
                logText.Text = #lines > 0 and table.concat(lines, "\n") or "(log is empty)"
            end
        end
    end
end
