--[[
    VEYL Control — single LocalScript
    Placement: StarterPlayer > StarterPlayerScripts

    Built for an experience you own or an authorized Studio test session.
    Visual/aim-test target scope is deliberately limited to Models tagged
    "VEYLTestTarget" with CollectionService. This script does not invoke
    arbitrary remotes or implement exploit-only/server-authority behavior.

    Notes:
    - Music playback uses Roblox audio asset IDs that the experience is
      permitted to use. Spotify/YouTube URLs cannot be played by Sound.
    - Settings remain in session memory; standard LocalScripts cannot write
      arbitrary persistent files.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")
local GUI_NAME = "VEYLControl"
local BLUR_NAME = "VEYLClientBlur"
local TARGET_TAG = "VEYLTestTarget"

local C = {
    bg = Color3.fromRGB(13, 16, 25),
    panel = Color3.fromRGB(19, 23, 35),
    panel2 = Color3.fromRGB(25, 30, 44),
    panel3 = Color3.fromRGB(31, 37, 54),
    line = Color3.fromRGB(190, 204, 229),
    text = Color3.fromRGB(240, 243, 250),
    muted = Color3.fromRGB(150, 161, 183),
    accent = Color3.fromRGB(157, 132, 255),
    accent2 = Color3.fromRGB(123, 102, 229),
    teal = Color3.fromRGB(105, 224, 209),
    pink = Color3.fromRGB(250, 146, 202),
    green = Color3.fromRGB(127, 225, 172),
    red = Color3.fromRGB(255, 117, 133),
}

local connections = {}
local musicConnections = {}
local state = {
    tab = "Home",
    uiOpen = true,
    transparencyAlways = true,
    blurEnabled = true,
    visualsEnabled = false,
    visuals = {
        names = true,
        highlight = true,
        maxDistance = 500,
        color = C.teal,
    },
    aim = {
        enabled = false,
        holdToActivate = true,
        fov = 140,
        maxDistance = 500,
        smoothness = 0.12,
        selected = nil,
    },
    world = {
        enabled = false,
        brightness = math.clamp(Lighting.Brightness, 0, 5),
        saturation = 0.08,
    },
    music = {
        queue = {},
        index = 0,
        volume = 0.45,
        repeatMode = "Off",
        shuffle = false,
        muted = false,
        paused = false,
        sound = nil,
        providerBookmarks = {},
    },
    diagnostics = {
        enabled = true,
        frames = 0,
        fps = 0,
        elapsed = 0,
        logs = {},
    },
    rejoining = false,
}

local originalLighting = {
    brightness = Lighting.Brightness,
    exposure = Lighting.ExposureCompensation,
    correction = nil,
}
local worldCorrection = nil
local highlightObjects = {}
local activePopup = nil
local activeSlider = nil
local keyCapture = false
local currentBinding = Enum.KeyCode.RightShift
local toastSerial = 0
local renderElapsed = 0
local fpsFrames = 0
local fpsClock = 0
local currentTargetLabel = "None"
local musicStatus = "Ready"
local mainWindow, screenGui, dock
local searchBox
local pageGroups = {}
local toggleControls = {}
local sliderControls = {}
local dropdownControls = {}
local activePage
local activeSliderPointerX = 0
local musicProgressClock = 0
local targetValueLabel
local musicNowLabel
local pageTitleLabel
local statusLabel
local draggingWindow = false
local dragOriginInput
local dragOriginPosition

local function listen(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return make("UIStroke", {
        Color = color or C.line,
        Transparency = transparency == nil and 0.82 or transparency,
        Thickness = thickness or 1,
    }, parent)
end

local function pad(parent, left, right, top, bottom)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function tween(object, duration, properties)
    local animation = TweenService:Create(object, TweenInfo.new(duration or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    animation:Play()
    return animation
end

local function roundText(text)
    return string.lower(tostring(text or ""))
end

local function notify(message, isError)
    if not screenGui then
        print("[VEYL] " .. tostring(message))
        return
    end
    toastSerial += 1
    local serial = toastSerial
    local toast = make("Frame", {
        Name = "Toast",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -24, 1, -24),
        Size = UDim2.fromOffset(310, 54),
        BackgroundColor3 = C.panel2,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 90,
    }, screenGui)
    corner(toast, 14)
    stroke(toast, isError and C.red or C.accent, 0.42, 1)
    make("Frame", {
        BackgroundColor3 = isError and C.red or C.accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -18),
        Position = UDim2.new(0, 8, 0, 9),
        ZIndex = 91,
    }, toast)
    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 21, 0, 0),
        Size = UDim2.new(1, -30, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = tostring(message),
        TextColor3 = C.text,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 91,
    }, toast)
    task.delay(3.1, function()
        if toast.Parent and serial <= toastSerial then
            tween(toast, 0.2, { BackgroundTransparency = 1, Position = toast.Position + UDim2.fromOffset(0, 8) })
            task.delay(0.22, function()
                if toast.Parent then toast:Destroy() end
            end)
        end
    end)
end

local function log(message, isError)
    local entry = os.date("%H:%M:%S") .. "  " .. tostring(message)
    table.insert(state.diagnostics.logs, 1, entry)
    while #state.diagnostics.logs > 80 do
        table.remove(state.diagnostics.logs)
    end
    print("[VEYL] " .. tostring(message))
    if isError then notify(message, true) end
end

local function setStatus(message, bad)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = message
        statusLabel.TextColor3 = bad and C.red or C.muted
    end
end

local function updateBlur()
    local blur = Lighting:FindFirstChild(BLUR_NAME)
    if state.transparencyAlways and state.blurEnabled and state.uiOpen then
        if not blur then
            blur = make("BlurEffect", { Name = BLUR_NAME, Size = 7, Enabled = true }, Lighting)
        end
        blur.Enabled = true
        blur.Size = 7
    elseif blur then
        blur:Destroy()
    end
end

local function getTaggedTargets()
    local targets = {}
    for _, instance in ipairs(CollectionService:GetTagged(TARGET_TAG)) do
        if instance:IsA("Model") and instance:IsDescendantOf(workspace) then
            local humanoid = instance:FindFirstChildOfClass("Humanoid")
            local root = instance:FindFirstChild("HumanoidRootPart") or instance.PrimaryPart
            if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
                table.insert(targets, { model = instance, humanoid = humanoid, root = root })
            end
        end
    end
    return targets
end

local function targetName(model)
    local label = model:GetAttribute("VEYLTargetName")
    if typeof(label) == "string" and label ~= "" then return label end
    return model.Name
end

local function clearVisuals()
    for model, objects in pairs(highlightObjects) do
        for _, object in ipairs(objects) do
            if object and object.Parent then object:Destroy() end
        end
        highlightObjects[model] = nil
    end
end

local function updateVisuals()
    clearVisuals()
    if not state.visualsEnabled then return end
    for _, data in ipairs(getTaggedTargets()) do
        local model = data.model
        local created = {}
        if state.visuals.highlight then
            local highlight = make("Highlight", {
                Name = "VEYLTargetHighlight",
                Adornee = model,
                FillColor = state.visuals.color,
                OutlineColor = C.text,
                FillTransparency = 0.78,
                OutlineTransparency = 0.12,
                DepthMode = Enum.HighlightDepthMode.Occluded,
            }, model)
            table.insert(created, highlight)
        end
        if state.visuals.names then
            local billboard = make("BillboardGui", {
                Name = "VEYLTargetLabel",
                Adornee = data.root,
                AlwaysOnTop = false,
                Size = UDim2.fromOffset(190, 46),
                StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0),
                MaxDistance = state.visuals.maxDistance,
                LightInfluence = 0,
            }, screenGui)
            local label = make("TextLabel", {
                BackgroundColor3 = C.panel,
                BackgroundTransparency = 0.22,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                Font = Enum.Font.GothamSemibold,
                Text = targetName(model) .. "\nTEST TARGET",
                TextColor3 = state.visuals.color,
                TextSize = 12,
                TextStrokeTransparency = 0.85,
                TextWrapped = true,
            }, billboard)
            corner(label, 8)
            stroke(label, state.visuals.color, 0.48, 1)
            table.insert(created, billboard)
        end
        highlightObjects[model] = created
    end
end

local function setWorldPreview(enabled)
    state.world.enabled = enabled
    if enabled then
        originalLighting.brightness = Lighting.Brightness
        originalLighting.exposure = Lighting.ExposureCompensation
        Lighting.Brightness = math.clamp(state.world.brightness, 0, 5)
        Lighting.ExposureCompensation = math.clamp(state.world.brightness - 1, -2, 2)
        if not worldCorrection or not worldCorrection.Parent then
            worldCorrection = make("ColorCorrectionEffect", {
                Name = "VEYLLocalColorCorrection",
                Enabled = true,
                Saturation = state.world.saturation,
                Contrast = 0.03,
                TintColor = Color3.fromRGB(229, 226, 255),
            }, Lighting)
        end
        worldCorrection.Enabled = true
        worldCorrection.Saturation = state.world.saturation
    else
        Lighting.Brightness = originalLighting.brightness
        Lighting.ExposureCompensation = originalLighting.exposure
        if worldCorrection then
            worldCorrection:Destroy()
            worldCorrection = nil
        end
    end
end

local function validAssetId(value)
    value = tostring(value or ""):match("^%s*(.-)%s*$")
    if value:match("^rbxassetid://%d+$") then
        return value:match("(%d+)$")
    end
    if value:match("^%d+$") then
        return value
    end
    return nil
end

local function stopMusic()
    for _, connection in ipairs(musicConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(musicConnections)
    if state.music.sound then
        pcall(function() state.music.sound:Stop() end)
        state.music.sound:Destroy()
        state.music.sound = nil
    end
    state.music.paused = false
    musicStatus = "Stopped"
end

local function syncVolume()
    if state.music.sound then
        state.music.sound.Volume = state.music.muted and 0 or math.clamp(state.music.volume, 0, 1)
    end
end

local function playTrack(index)
    if #state.music.queue == 0 then
        musicStatus = "Queue is empty"
        notify("Add a permitted Roblox audio asset ID first.", true)
        return
    end
    index = math.clamp(index, 1, #state.music.queue)
    stopMusic()
    state.music.index = index
    local track = state.music.queue[index]
    local sound = make("Sound", {
        Name = "VEYLMusicPlayer",
        SoundId = "rbxassetid://" .. track.id,
        Volume = state.music.muted and 0 or math.clamp(state.music.volume, 0, 1),
        Looped = false,
        PlaybackSpeed = 1,
    }, SoundService)
    state.music.sound = sound
    state.music.paused = false
    musicStatus = "Loading asset " .. track.id
    setStatus(musicStatus, false)
    table.insert(musicConnections, sound.Loaded:Connect(function()
        if state.music.sound == sound then
            musicStatus = "Playing · " .. track.id
            setStatus(musicStatus, false)
        end
    end))
    table.insert(musicConnections, sound.Ended:Connect(function()
        if state.music.sound ~= sound then return end
        if state.music.repeatMode == "One" then
            playTrack(state.music.index)
        elseif state.music.shuffle and #state.music.queue > 1 then
            local nextIndex = math.random(1, #state.music.queue)
            if nextIndex == state.music.index then nextIndex = (nextIndex % #state.music.queue) + 1 end
            playTrack(nextIndex)
        elseif state.music.index < #state.music.queue then
            playTrack(state.music.index + 1)
        elseif state.music.repeatMode == "All" then
            playTrack(1)
        else
            musicStatus = "Queue finished"
            setStatus(musicStatus, false)
        end
    end))
    local ok, err = pcall(function() sound:Play() end)
    if not ok then
        musicStatus = "Playback failed"
        log("Audio playback failed: " .. tostring(err), true)
    else
        task.delay(6, function()
            if state.music.sound == sound and not sound.IsLoaded then
                musicStatus = "Loading or permission pending for " .. track.id
                setStatus(musicStatus, true)
                notify("Audio may be private, unavailable, or not permitted for this experience.", true)
            end
        end)
    end
end

local function addTrack(rawId)
    local id = validAssetId(rawId)
    if not id then
        notify("Enter a numeric Roblox audio asset ID or rbxassetid:// ID.", true)
        return false
    end
    if #state.music.queue >= 100 then
        notify("The session queue is limited to 100 tracks.", true)
        return false
    end
    table.insert(state.music.queue, { id = id, label = "Audio " .. id, favorite = false })
    log("Added audio asset " .. id .. " to the session queue.")
    return true
end

local function cleanupAll()
    state.aim.enabled = false
    state.visualsEnabled = false
    clearVisuals()
    if state.world.enabled then setWorldPreview(false) end
    stopMusic()
    local blur = Lighting:FindFirstChild(BLUR_NAME)
    if blur then blur:Destroy() end
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
end

-- Re-execution safety: only remove this script's exact owned GUI/effect names.
local previousGui = PLAYER_GUI:FindFirstChild(GUI_NAME)
if previousGui then previousGui:Destroy() end
local previousBlur = Lighting:FindFirstChild(BLUR_NAME)
if previousBlur then previousBlur:Destroy() end
local previousCorrection = Lighting:FindFirstChild("VEYLLocalColorCorrection")
if previousCorrection then previousCorrection:Destroy() end
local previousSound = SoundService:FindFirstChild("VEYLMusicPlayer")
if previousSound then previousSound:Destroy() end

screenGui = make("ScreenGui", {
    Name = GUI_NAME,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 80,
}, PLAYER_GUI)

-- Soft pastel ambient blobs behind the glass window.
local function addGlowBlob(xScale, yScale, diameter, color)
    for layer = 10, 1, -1 do
        local fraction = layer / 10
        local size = math.floor(diameter * fraction)
        local blob = make("Frame", {
            Name = "AmbientGlow",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(xScale, 0, yScale, 0),
            Size = UDim2.fromOffset(size, size),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.975 - ((1 - fraction) * 0.08),
            BorderSizePixel = 0,
            ZIndex = 0,
        }, screenGui)
        corner(blob, size)
    end
end
addGlowBlob(0.24, 0.37, 460, C.accent)
addGlowBlob(0.75, 0.30, 420, C.teal)
addGlowBlob(0.71, 0.72, 390, C.pink)

mainWindow = make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.455, 0),
    Size = UDim2.new(0.86, 0, 0.77, 0),
    BackgroundColor3 = C.bg,
    BackgroundTransparency = 0.13,
    BorderSizePixel = 0,
    ZIndex = 2,
    ClipsDescendants = true,
}, screenGui)
corner(mainWindow, 24)
stroke(mainWindow, Color3.fromRGB(229, 233, 255), 0.72, 1)
make("UISizeConstraint", {
    MinSize = Vector2.new(580, 420),
    MaxSize = Vector2.new(1080, 700),
}, mainWindow)
make("UIGradient", {
    Rotation = 135,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 31, 48)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(16, 20, 31)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 24, 35)),
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.04),
        NumberSequenceKeypoint.new(1, 0.13),
    }),
}, mainWindow)

local topbar = make("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 66),
    BackgroundColor3 = Color3.fromRGB(23, 27, 41),
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    ZIndex = 4,
}, mainWindow)
make("Frame", {
    BackgroundColor3 = Color3.fromRGB(220, 226, 246),
    BackgroundTransparency = 0.91,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -1),
    Size = UDim2.new(1, 0, 0, 1),
    ZIndex = 5,
}, topbar)

local brandMark = make("Frame", {
    Position = UDim2.new(0, 20, 0.5, -15),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = C.accent,
    BackgroundTransparency = 0.14,
    BorderSizePixel = 0,
    ZIndex = 6,
}, topbar)
corner(brandMark, 10)
make("UIGradient", {
    Rotation = 45,
    Color = ColorSequence.new(C.accent, C.teal),
}, brandMark)
make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Font = Enum.Font.GothamBold,
    Text = "V",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 18,
    ZIndex = 7,
}, brandMark)
make("TextLabel", {
    Name = "BrandTitle",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 60, 0, 13),
    Size = UDim2.fromOffset(190, 22),
    Font = Enum.Font.GothamBold,
    Text = "VEYL",
    TextColor3 = C.text,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
}, topbar)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 60, 0, 35),
    Size = UDim2.fromOffset(245, 16),
    Font = Enum.Font.Gotham,
    Text = "CONTROL  /  ADVANCED CLIENT TOOLKIT",
    TextColor3 = C.muted,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
}, topbar)

searchBox = make("TextBox", {
    Name = "Search",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.63, 0, 0.5, 0),
    Size = UDim2.new(0.31, 0, 0, 34),
    BackgroundColor3 = Color3.fromRGB(10, 13, 21),
    BackgroundTransparency = 0.27,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    PlaceholderColor3 = Color3.fromRGB(125, 137, 161),
    PlaceholderText = "⌕   Search settings...",
    Text = "",
    TextColor3 = C.text,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
}, topbar)
corner(searchBox, 11)
stroke(searchBox, C.line, 0.87, 1)
pad(searchBox, 12, 10, 0, 0)

statusLabel = make("TextLabel", {
    Name = "Status",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -82, 0.5, 0),
    Size = UDim2.fromOffset(190, 22),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Text = "●  CLIENT READY",
    TextColor3 = C.muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 6,
}, topbar)
local minimizeButton = make("TextButton", {
    Name = "Minimize",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -45, 0.5, 0),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = C.panel3,
    BackgroundTransparency = 0.13,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "—",
    TextColor3 = C.text,
    TextSize = 14,
    ZIndex = 6,
}, topbar)
corner(minimizeButton, 8)
local closeButton = make("TextButton", {
    Name = "Close",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -13, 0.5, 0),
    Size = UDim2.fromOffset(26, 26),
    BackgroundColor3 = Color3.fromRGB(111, 47, 71),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextColor3 = Color3.fromRGB(255, 221, 230),
    TextSize = 18,
    ZIndex = 6,
}, topbar)
corner(closeButton, 8)

local sidebar = make("Frame", {
    Name = "Sidebar",
    Position = UDim2.new(0, 0, 0, 66),
    Size = UDim2.new(0, 176, 1, -66),
    BackgroundColor3 = Color3.fromRGB(16, 20, 31),
    BackgroundTransparency = 0.24,
    BorderSizePixel = 0,
    ZIndex = 3,
}, mainWindow)
make("Frame", {
    BackgroundColor3 = C.line,
    BackgroundTransparency = 0.91,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    ZIndex = 4,
}, sidebar)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 20, 0, 20),
    Size = UDim2.new(1, -30, 0, 18),
    Font = Enum.Font.GothamSemibold,
    Text = "WORKSPACE",
    TextColor3 = Color3.fromRGB(116, 129, 153),
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
}, sidebar)
local navHolder = make("Frame", {
    Name = "Navigation",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 49),
    Size = UDim2.new(1, -20, 0, 344),
    ZIndex = 5,
}, sidebar)
make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, navHolder)

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.new(0, 177, 0, 66),
    Size = UDim2.new(1, -177, 1, -66),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, mainWindow)
local contentHeader = make("Frame", {
    Name = "ContentHeader",
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundTransparency = 1,
    ZIndex = 4,
}, content)
pageTitleLabel = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 24, 0, 12),
    Size = UDim2.new(1, -48, 0, 24),
    Font = Enum.Font.GothamBold,
    Text = "Overview",
    TextColor3 = C.text,
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
}, contentHeader)
local contentSubtitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 25, 0, 37),
    Size = UDim2.new(1, -50, 0, 15),
    Font = Enum.Font.Gotham,
    Text = "A calmer workspace for your local test session.",
    TextColor3 = C.muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
}, contentHeader)
local pageHost = make("Frame", {
    Name = "PageHost",
    Position = UDim2.new(0, 0, 0, 60),
    Size = UDim2.new(1, 0, 1, -60),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    ZIndex = 4,
}, content)

-- The dock floats below the window and keeps the primary sections one click away.
dock = make("Frame", {
    Name = "VEYLAppDock",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.93, 0),
    Size = UDim2.fromOffset(276, 62),
    BackgroundColor3 = C.panel,
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    ZIndex = 20,
}, screenGui)
corner(dock, 19)
stroke(dock, C.line, 0.75, 1)
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 11),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, dock)
pad(dock, 12, 12, 7, 7)

local pages = {}
local navButtons = {}
local navMeta = {
    { name = "Home", icon = "⌂", title = "Overview", subtitle = "A calmer workspace for your local test session." },
    { name = "Visuals", icon = "◉", title = "Visuals", subtitle = "Local debug overlays for tagged test targets only." },
    { name = "Aim Lab", icon = "⊙", title = "Aim Lab", subtitle = "Camera practice limited to VEYLTestTarget models." },
    { name = "World", icon = "◇", title = "World", subtitle = "Local lighting preview with original values restored on disable." },
    { name = "Entities", icon = "⌕", title = "Entities", subtitle = "Inspect configured test dummies and NPC targets." },
    { name = "Music", icon = "♫", title = "Music Hub", subtitle = "Play authorized Roblox audio assets in this session." },
    { name = "Diagnostics", icon = "⌁", title = "Diagnostics", subtitle = "Client-visible runtime observations and bounded logs." },
    { name = "Settings", icon = "⚙", title = "Settings", subtitle = "Appearance, hotkeys, cleanup, and session utilities." },
}

local function makePage(tabName)
    local page = make("ScrollingFrame", {
        Name = tabName:gsub("%s+", "") .. "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = C.accent,
        ScrollBarImageTransparency = 0.3,
        Visible = false,
        ZIndex = 4,
    }, pageHost)
    pad(page, 12, 14, 3, 18)
    make("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    pages[tabName] = page
    pageGroups[tabName] = {}
    return page
end

local function makeGroup(page, title, subtitle)
    local groupFrame = make("Frame", {
        Name = title:gsub("%W", "") .. "Group",
        Size = UDim2.new(1, -5, 0, 62),
        BackgroundColor3 = C.panel2,
        BackgroundTransparency = 0.33,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, page)
    corner(groupFrame, 15)
    stroke(groupFrame, C.line, 0.9, 1)
    local titleLabel = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 11),
        Size = UDim2.new(1, -28, 0, 17),
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextColor3 = C.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    }, groupFrame)
    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 29),
        Size = UDim2.new(1, -28, 0, 14),
        Font = Enum.Font.Gotham,
        Text = subtitle or "",
        TextColor3 = C.muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, groupFrame)
    local group = { frame = groupFrame, title = title, subtitle = subtitle or "", rows = {}, nextY = 51 }
    table.insert(pageGroups[state.tab], group)
    return group
end

local function makeRow(group, title, description, height)
    local row = make("Frame", {
        Name = title:gsub("%W", "") .. "Row",
        Position = UDim2.new(0, 10, 0, group.nextY),
        Size = UDim2.new(1, -20, 0, height or 49),
        BackgroundColor3 = Color3.fromRGB(12, 16, 26),
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, group.frame)
    corner(row, 10)
    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 6),
        Size = UDim2.new(1, -225, 0, 17),
        Font = Enum.Font.GothamMedium,
        Text = title,
        TextColor3 = C.text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, row)
    local desc = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 24),
        Size = UDim2.new(1, -225, 0, 14),
        Font = Enum.Font.Gotham,
        Text = description or "",
        TextColor3 = C.muted,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, row)
    group.nextY += (height or 49) + 6
    group.frame.Size = UDim2.new(1, -5, 0, group.nextY + 3)
    local rowRecord = { frame = row, title = title, description = description or "" }
    table.insert(group.rows, rowRecord)
    return row
end

local function resetGroupRows(group, rowFrames)
    for _, old in ipairs(rowFrames) do
        if old and old.Parent then old:Destroy() end
    end
    table.clear(rowFrames)
    group.rows = {}
    group.nextY = 51
    group.frame.Size = UDim2.new(1, -5, 0, 62)
end

local function makeButton(parent, label, position, size, callback, options)
    options = options or {}
    local button = make("TextButton", {
        Position = position,
        Size = size,
        BackgroundColor3 = options.color or C.panel3,
        BackgroundTransparency = options.transparency == nil and 0.12 or options.transparency,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamSemibold,
        Text = label,
        TextColor3 = options.textColor or C.text,
        TextSize = options.textSize or 10,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = options.zIndex or 8,
    }, parent)
    corner(button, options.radius or 9)
    if options.stroke then stroke(button, options.stroke, options.strokeTransparency or 0.65, 1) end
    listen(button.MouseEnter, function()
        if button.Parent then tween(button, 0.15, { BackgroundTransparency = 0.02 }) end
    end)
    listen(button.MouseLeave, function()
        if button.Parent then tween(button, 0.15, { BackgroundTransparency = options.transparency == nil and 0.12 or options.transparency }) end
    end)
    listen(button.Activated, callback)
    return button
end

local function addToggle(group, title, description, initialValue, callback)
    local row = makeRow(group, title, description, 49)
    local switch = make("TextButton", {
        Position = UDim2.new(1, -61, 0.5, -12),
        Size = UDim2.fromOffset(48, 24),
        BackgroundColor3 = initialValue and C.accent2 or Color3.fromRGB(59, 66, 82),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 8,
    }, row)
    corner(switch, 14)
    local knob = make("Frame", {
        Position = initialValue and UDim2.new(1, -21, 0, 3) or UDim2.new(0, 3, 0, 3),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 9,
    }, switch)
    corner(knob, 10)
    local value = initialValue
    local function setValue(nextValue, suppressCallback)
        value = not not nextValue
        tween(switch, 0.18, { BackgroundColor3 = value and C.accent2 or Color3.fromRGB(59, 66, 82) })
        tween(knob, 0.18, { Position = value and UDim2.new(1, -21, 0, 3) or UDim2.new(0, 3, 0, 3) })
        if not suppressCallback and callback then callback(value) end
    end
    listen(switch.Activated, function() setValue(not value, false) end)
    local control = { set = setValue, get = function() return value end, row = row }
    toggleControls[title] = control
    return control
end

local function addButtonRow(group, title, description, label, callback, color)
    local row = makeRow(group, title, description, 49)
    local button = makeButton(row, label, UDim2.new(1, -158, 0.5, -14), UDim2.fromOffset(146, 28), callback, {
        color = color or C.panel3,
        transparency = 0.13,
        stroke = color or C.line,
        strokeTransparency = 0.78,
    })
    return button
end

local function addSlider(group, title, description, minValue, maxValue, initialValue, suffix, callback)
    local row = makeRow(group, title, description, 56)
    local value = initialValue
    local valueLabel = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -11, 0.5, 0),
        Size = UDim2.fromOffset(42, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = tostring(value) .. (suffix or ""),
        TextColor3 = C.text,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 8,
    }, row)
    local track = make("Frame", {
        Position = UDim2.new(1, -175, 0.5, -3),
        Size = UDim2.fromOffset(122, 6),
        BackgroundColor3 = Color3.fromRGB(57, 64, 81),
        BorderSizePixel = 0,
        ZIndex = 8,
    }, row)
    corner(track, 5)
    local fraction = (value - minValue) / math.max(0.0001, maxValue - minValue)
    local fill = make("Frame", {
        Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        ZIndex = 9,
    }, track)
    corner(fill, 5)
    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(math.clamp(fraction, 0, 1), 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 10,
    }, track)
    corner(knob, 8)
    local function setValue(nextValue, suppressCallback)
        value = math.clamp(tonumber(nextValue) or minValue, minValue, maxValue)
        local t = (value - minValue) / math.max(0.0001, maxValue - minValue)
        fill.Size = UDim2.new(t, 0, 1, 0)
        knob.Position = UDim2.new(t, 0, 0.5, 0)
        valueLabel.Text = string.format("%s%s", tostring(math.floor(value * 100 + 0.5) / 100), suffix or "")
        if callback and not suppressCallback then callback(value) end
    end
    local slider = { track = track, set = setValue, get = function() return value end, min = minValue, max = maxValue }
    sliderControls[title] = slider
    listen(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSlider = slider
            activeSliderPointerX = input.Position.X
            local t = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            setValue(minValue + t * (maxValue - minValue), false)
        end
    end)
    listen(knob.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSlider = slider
            activeSliderPointerX = input.Position.X
        end
    end)
    return slider
end

local function addDropdown(group, title, description, options, initialValue, callback)
    local row = makeRow(group, title, description, 49)
    local selected = initialValue or options[1]
    local button
    button = makeButton(row, tostring(selected) .. "  ▾", UDim2.new(1, -178, 0.5, -14), UDim2.fromOffset(166, 28), function()
        if activePopup and activePopup.Parent then activePopup:Destroy() end
        local popup = make("Frame", {
            Name = "VEYLSelectPopup",
            BackgroundColor3 = C.panel2,
            BackgroundTransparency = 0.03,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(168, #options * 31 + 10),
            ZIndex = 40,
        }, mainWindow)
        activePopup = popup
        corner(popup, 10)
        stroke(popup, C.line, 0.55, 1)
        local abs = button.AbsolutePosition
        local shellAbs = mainWindow.AbsolutePosition
        local yOffset = abs.Y - shellAbs.Y + button.AbsoluteSize.Y + 4
        if yOffset + popup.Size.Y.Offset > mainWindow.AbsoluteSize.Y then
            yOffset = abs.Y - shellAbs.Y - popup.Size.Y.Offset - 4
        end
        popup.Position = UDim2.fromOffset(math.max(8, abs.X - shellAbs.X + button.AbsoluteSize.X - popup.Size.X.Offset), math.max(8, yOffset))
        for index, option in ipairs(options) do
            local optionValue = option
            makeButton(popup, tostring(optionValue), UDim2.new(0, 5, 0, 5 + (index - 1) * 31), UDim2.new(1, -10, 0, 27), function()
                selected = optionValue
                button.Text = tostring(selected) .. "  ▾"
                popup:Destroy()
                activePopup = nil
                if callback then callback(selected) end
            end, {
                color = optionValue == selected and C.accent2 or C.panel3,
                transparency = optionValue == selected and 0.06 or 0.24,
                radius = 7,
                zIndex = 41,
            })
        end
    end, { color = C.panel3, transparency = 0.18, stroke = C.line, strokeTransparency = 0.87 })
    local control = {
        get = function() return selected end,
        set = function(nextValue, suppressCallback)
            if table.find(options, nextValue) then
                selected = nextValue
                button.Text = tostring(selected) .. "  ▾"
                if callback and not suppressCallback then callback(selected) end
            end
        end,
    }
    dropdownControls[title] = control
    return control
end

local function addTextEntry(group, title, description, placeholder, initialText, actionLabel, callback)
    local row = makeRow(group, title, description, 57)
    local entry = make("TextBox", {
        Position = UDim2.new(1, -288, 0.5, -14),
        Size = UDim2.fromOffset(162, 28),
        BackgroundColor3 = Color3.fromRGB(10, 14, 23),
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderText = placeholder or "Enter value",
        PlaceholderColor3 = C.muted,
        Text = initialText or "",
        TextColor3 = C.text,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8,
    }, row)
    corner(entry, 8)
    stroke(entry, C.line, 0.88, 1)
    pad(entry, 8, 7, 0, 0)
    makeButton(row, actionLabel or "Apply", UDim2.new(1, -116, 0.5, -14), UDim2.fromOffset(104, 28), function()
        if callback then callback(entry.Text, entry) end
    end, { color = C.accent2, transparency = 0.12 })
    return entry
end

local function syncToggleControl(title, value)
    local control = toggleControls[title]
    if control then control.set(value, true) end
end

local function syncSliderControl(title, value)
    local control = sliderControls[title]
    if control then control.set(value, true) end
end

local function syncDropdownControl(title, value)
    local control = dropdownControls[title]
    if control then control.set(value, true) end
end

local function applySearch()
    if not activePage then return end
    local query = roundText(searchBox and searchBox.Text or "")
    for _, group in ipairs(pageGroups[state.tab] or {}) do
        local headerMatches = query == "" or string.find(roundText(group.title .. " " .. group.subtitle), query, 1, true) ~= nil
        local anyRow = false
        for _, row in ipairs(group.rows) do
            local rowMatches = query == "" or headerMatches or string.find(roundText(row.title .. " " .. row.description), query, 1, true) ~= nil
            row.frame.Visible = rowMatches
            if rowMatches then anyRow = true end
        end
        group.frame.Visible = query == "" or headerMatches or anyRow
    end
end

local function selectTab(tabName)
    if not pages[tabName] then return end
    state.tab = tabName
    activePage = pages[tabName]
    if activePopup and activePopup.Parent then activePopup:Destroy() end
    activePopup = nil
    for name, page in pairs(pages) do page.Visible = name == tabName end
    for name, button in pairs(navButtons) do
        local selected = name == tabName
        tween(button, 0.15, { BackgroundColor3 = selected and Color3.fromRGB(45, 40, 72) or C.panel, BackgroundTransparency = selected and 0.04 or 0.72 })
        local glyph = button:FindFirstChild("NavGlyph")
        local label = button:FindFirstChild("NavLabel")
        if glyph then glyph.TextColor3 = selected and C.accent or C.muted end
        if label then label.TextColor3 = selected and C.text or C.muted end
    end
    for _, item in ipairs(navMeta) do
        if item.name == tabName then
            pageTitleLabel.Text = item.title
            contentSubtitle.Text = item.subtitle
            break
        end
    end
    if searchBox then searchBox.Text = "" end
    applySearch()
end

-- Prepare all page containers first so navigation works immediately.
for _, item in ipairs(navMeta) do
    makePage(item.name)
end

-- Navigation rail.
for index, item in ipairs(navMeta) do
    local navItem = item
    local button = make("TextButton", {
        Name = navItem.name:gsub("%s+", "") .. "Nav",
        LayoutOrder = index,
        Size = UDim2.new(1, 0, 0, 39),
        BackgroundColor3 = C.panel,
        BackgroundTransparency = navItem.name == "Home" and 0.04 or 0.72,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 6,
    }, navHolder)
    corner(button, 10)
    make("TextLabel", {
        Name = "NavGlyph",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 11, 0, 0),
        Size = UDim2.fromOffset(22, 39),
        Font = Enum.Font.Gotham,
        Text = navItem.icon,
        TextColor3 = navItem.name == "Home" and C.accent or C.muted,
        TextSize = 16,
        ZIndex = 7,
    }, button)
    make("TextLabel", {
        Name = "NavLabel",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 42, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = navItem.name,
        TextColor3 = navItem.name == "Home" and C.text or C.muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
    }, button)
    navButtons[navItem.name] = button
    listen(button.Activated, function() selectTab(navItem.name) end)
end

make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 18, 1, -43),
    Size = UDim2.new(1, -30, 0, 13),
    Font = Enum.Font.Gotham,
    Text = "CLIENT SESSION  •  LOCAL",
    TextColor3 = Color3.fromRGB(113, 126, 150),
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 5,
}, sidebar)

-- Dock uses four simple monochrome line symbols: circle, triangle, diamond, hexagon.
local dockItems = {
    { symbol = "○", tab = "Home", tip = "Home" },
    { symbol = "△", tab = "Visuals", tip = "Visuals" },
    { symbol = "◇", tab = "World", tip = "World" },
    { symbol = "⬡", tab = "Music", tip = "Music Hub" },
}
for index, item in ipairs(dockItems) do
    local dockItem = item
    local iconButton = make("TextButton", {
        Name = dockItem.tab:gsub("%s+", "") .. "DockIcon",
        LayoutOrder = index,
        Size = UDim2.fromOffset(46, 46),
        BackgroundColor3 = C.panel3,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        Text = dockItem.symbol,
        TextColor3 = Color3.fromRGB(246, 247, 251),
        TextSize = dockItem.symbol == "⬡" and 21 or 23,
        ZIndex = 21,
    }, dock)
    corner(iconButton, 13)
    stroke(iconButton, C.line, 0.82, 1)
    listen(iconButton.MouseEnter, function() tween(iconButton, 0.14, { BackgroundTransparency = 0.02, Size = UDim2.fromOffset(48, 48) }) end)
    listen(iconButton.MouseLeave, function() tween(iconButton, 0.14, { BackgroundTransparency = 0.18, Size = UDim2.fromOffset(46, 46) }) end)
    listen(iconButton.Activated, function()
        mainWindow.Visible = true
        state.uiOpen = true
        selectTab(dockItem.tab)
        updateBlur()
    end)
end

-- HOME PAGE
state.tab = "Home"
local homePage = pages.Home
local welcome = make("Frame", {
    Name = "WelcomeCard",
    Size = UDim2.new(1, -5, 0, 104),
    BackgroundColor3 = Color3.fromRGB(34, 34, 59),
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    ZIndex = 5,
}, homePage)
corner(welcome, 16)
stroke(welcome, C.accent, 0.65, 1)
make("UIGradient", {
    Rotation = 15,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(53, 43, 90)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(31, 43, 63)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 52, 61)),
    }),
}, welcome)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 18, 0, 15),
    Size = UDim2.new(1, -38, 0, 27),
    Font = Enum.Font.GothamBold,
    Text = "Make space for better testing.",
    TextColor3 = C.text,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
}, welcome)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 19, 0, 47),
    Size = UDim2.new(1, -38, 0, 35),
    Font = Enum.Font.Gotham,
    Text = "VEYL Control keeps local diagnostics, test-target visuals, and permitted audio in one calm workspace.",
    TextColor3 = Color3.fromRGB(200, 204, 226),
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 6,
}, welcome)

local cardRow = make("Frame", {
    Name = "OverviewCards",
    Size = UDim2.new(1, -5, 0, 122),
    BackgroundTransparency = 1,
    ZIndex = 5,
}, homePage)
local cardLayout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, cardRow)
local function homeCard(order, title, description, glyph, tint, valueText, tab)
    local card = make("TextButton", {
        Name = title:gsub("%W", "") .. "Card",
        LayoutOrder = order,
        Size = UDim2.new(0.333, -7, 1, 0),
        BackgroundColor3 = C.panel2,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 6,
    }, cardRow)
    corner(card, 15)
    stroke(card, C.line, 0.89, 1)
    local orb = make("Frame", {
        Position = UDim2.new(0, 12, 0, 13),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = tint,
        BackgroundTransparency = 0.19,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, card)
    corner(orb, 18)
    make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamSemibold,
        Text = glyph,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 17,
        ZIndex = 8,
    }, orb)
    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 56),
        Size = UDim2.new(1, -24, 0, 17),
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextColor3 = C.text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, card)
    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 76),
        Size = UDim2.new(1, -24, 0, 29),
        Font = Enum.Font.Gotham,
        Text = valueText .. "\n" .. description,
        TextColor3 = C.muted,
        TextSize = 8,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 7,
    }, card)
    listen(card.MouseEnter, function() tween(card, 0.16, { BackgroundTransparency = 0.08 }) end)
    listen(card.MouseLeave, function() tween(card, 0.16, { BackgroundTransparency = 0.25 }) end)
    listen(card.Activated, function() selectTab(tab) end)
end
homeCard(1, "Client Toolkit", "Local tools and state", "◉", C.accent, "READY", "Visuals")
homeCard(2, "Test Targets", "Tagged models only", "△", C.teal, tostring(#getTaggedTargets()) .. " DISCOVERED", "Entities")
homeCard(3, "Music Hub", "Roblox audio assets", "♫", C.pink, "SESSION QUEUE", "Music")

local homeAppearance = makeGroup(homePage, "Appearance", "A translucent surface, in every theme.")
addToggle(homeAppearance, "Transparency stays on in every theme", "Keep the frosted panel treatment enabled.", state.transparencyAlways, function(value)
    state.transparencyAlways = value
    updateBlur()
    if mainWindow then mainWindow.BackgroundTransparency = value and 0.13 or 0.02 end
    notify(value and "Glass transparency enabled." or "Glass transparency disabled.")
end)
addToggle(homeAppearance, "Soft background blur", "Use a subtle blur while VEYL is open.", state.blurEnabled, function(value)
    state.blurEnabled = value
    updateBlur()
end)
local quickGroup = makeGroup(homePage, "Quick actions", "Fast controls for the current local session.")
addButtonRow(quickGroup, "Refresh test targets", "Re-scan VEYLTestTarget tags in Workspace.", "Refresh registry", function()
    notify("Found " .. tostring(#getTaggedTargets()) .. " eligible test target(s).")
    if state.tab == "Entities" then selectTab("Entities") end
end, C.accent2)
addButtonRow(quickGroup, "Emergency stop", "Disable Aim Lab, visuals, local lighting, and audio.", "STOP ALL", function()
    state.aim.enabled = false
    state.visualsEnabled = false
    clearVisuals()
    if state.world.enabled then setWorldPreview(false) end
    stopMusic()
    syncToggleControl("Enable Aim Lab", false)
    syncToggleControl("Enable test-target overlays", false)
    syncToggleControl("Enable world preview", false)
    currentTargetLabel = "None"
    setStatus("●  FEATURES STOPPED", false)
    notify("Local features stopped.")
    selectTab(state.tab)
end, C.red)

-- VISUALS PAGE
state.tab = "Visuals"
local visualsGroup = makeGroup(pages.Visuals, "Target overlays", "Only Models tagged VEYLTestTarget are eligible.")
addToggle(visualsGroup, "Enable test-target overlays", "Create client-side labels/highlights for tagged models.", state.visualsEnabled, function(value)
    state.visualsEnabled = value
    updateVisuals()
    setStatus(value and "●  TARGET OVERLAYS ON" or "●  CLIENT READY", false)
end)
addToggle(visualsGroup, "Name labels", "Show the configured target name above each model.", state.visuals.names, function(value)
    state.visuals.names = value
    updateVisuals()
end)
addToggle(visualsGroup, "Highlight models", "Use a native Highlight with occlusion enabled.", state.visuals.highlight, function(value)
    state.visuals.highlight = value
    updateVisuals()
end)
addSlider(visualsGroup, "Maximum visual distance", "Distance is measured in Roblox studs.", 50, 1500, state.visuals.maxDistance, " st", function(value)
    state.visuals.maxDistance = value
    for _, objects in pairs(highlightObjects) do
        for _, object in ipairs(objects) do
            if object:IsA("BillboardGui") then object.MaxDistance = value end
        end
    end
end)
addDropdown(visualsGroup, "Overlay color", "Select the accent used by the local overlay.", { "Teal", "Violet", "Pink", "White" }, "Teal", function(option)
    local colors = { Teal = C.teal, Violet = C.accent, Pink = C.pink, White = C.text }
    state.visuals.color = colors[option] or C.teal
    updateVisuals()
end)
addButtonRow(visualsGroup, "Rebuild overlays", "Remove stale instances and rebuild from current tags.", "Rebuild", updateVisuals, C.accent2)

-- AIM LAB PAGE: explicit test targets only, never arbitrary players.
state.tab = "Aim Lab"
local aimGroup = makeGroup(pages["Aim Lab"], "Camera practice", "For training dummies/NPCs you tag in your own experience.")
addToggle(aimGroup, "Enable Aim Lab", "Camera correction is limited to VEYLTestTarget models.", state.aim.enabled, function(value)
    state.aim.enabled = value
    if not value then state.aim.selected = nil; currentTargetLabel = "None" end
    setStatus(value and "●  AIM LAB ARMED" or "●  CLIENT READY", false)
end)
addToggle(aimGroup, "Hold right mouse to activate", "Requires a press-and-hold while Aim Lab is enabled.", state.aim.holdToActivate, function(value)
    state.aim.holdToActivate = value
end)
addSlider(aimGroup, "FOV radius", "Maximum distance from the screen center in pixels.", 30, 500, state.aim.fov, " px", function(value)
    state.aim.fov = value
end)
addSlider(aimGroup, "Maximum target distance", "Maximum distance from the current camera, in studs.", 50, 1500, state.aim.maxDistance, " st", function(value)
    state.aim.maxDistance = value
end)
addSlider(aimGroup, "Smoothness", "Higher values make camera interpolation faster.", 1, 50, math.floor(state.aim.smoothness * 100), "%", function(value)
    state.aim.smoothness = math.clamp(value / 100, 0.01, 0.5)
end)
local targetGroup = makeGroup(pages["Aim Lab"], "Current target", "No server-confirmed hits or weapon behavior are inferred.")
local targetStatusRow = makeRow(targetGroup, "Selected test target", "Waiting for a tagged model.", 50)
targetValueLabel = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(150, 20),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    Text = "None",
    TextColor3 = C.teal,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 8,
}, targetStatusRow)
addButtonRow(targetGroup, "Cycle test target", "Select the next eligible model for Aim Lab.", "Cycle", function()
    local targets = getTaggedTargets()
    if #targets == 0 then notify("No targets tagged VEYLTestTarget were found.", true); return end
    local currentIndex = 0
    for index, data in ipairs(targets) do
        if data.model == state.aim.selected then currentIndex = index; break end
    end
    local next = targets[(currentIndex % #targets) + 1]
    state.aim.selected = next.model
    currentTargetLabel = targetName(next.model)
    targetValueLabel.Text = currentTargetLabel
    notify("Selected test target: " .. currentTargetLabel)
end, C.accent2)
addButtonRow(targetGroup, "Clear selected target", "Release the current target lock.", "Clear target", function()
    state.aim.selected = nil
    currentTargetLabel = "None"
    targetValueLabel.Text = "None"
end)

-- WORLD PAGE
state.tab = "World"
local worldGroup = makeGroup(pages.World, "Local visual preview", "Changes affect this client only and are restored when disabled.")
addToggle(worldGroup, "Enable world preview", "Adjust local Lighting and add a local color-correction effect.", state.world.enabled, function(value)
    setWorldPreview(value)
    notify(value and "Local lighting preview enabled." or "Original local lighting restored.")
end)
addSlider(worldGroup, "Brightness", "Local Lighting.Brightness preview value.", 0, 5, state.world.brightness, "", function(value)
    state.world.brightness = value
    if state.world.enabled then
        Lighting.Brightness = value
        Lighting.ExposureCompensation = math.clamp(value - 1, -2, 2)
    end
end)
addSlider(worldGroup, "Saturation", "Local color correction saturation.", -100, 100, 8, "%", function(value)
    state.world.saturation = value / 100
    if state.world.enabled and worldCorrection then worldCorrection.Saturation = state.world.saturation end
end)
addButtonRow(worldGroup, "Restore original visuals", "Restore captured local Lighting values.", "Restore", function()
    setWorldPreview(false)
    notify("Original local lighting values restored.")
end)

-- ENTITIES PAGE
state.tab = "Entities"
local entityGroup = makeGroup(pages.Entities, "Test target registry", "This list intentionally includes only tagged live Models.")
addButtonRow(entityGroup, "Refresh registry", "Re-read tags and current Humanoid/root state.", "Refresh", function()
    selectTab("Entities")
    notify("Registry refreshed: " .. tostring(#getTaggedTargets()) .. " eligible target(s).")
end, C.accent2)
local entityListGroup = makeGroup(pages.Entities, "Eligible targets", "Add the VEYLTestTarget tag in Studio to include a model.")
local entityRefreshRows = {}
local function refreshEntityList()
    resetGroupRows(entityListGroup, entityRefreshRows)
    local targets = getTaggedTargets()
    if #targets == 0 then
        local row = makeRow(entityListGroup, "No eligible targets", "Tag a test dummy Model with VEYLTestTarget.", 50)
        table.insert(entityRefreshRows, row)
        return
    end
    for index, data in ipairs(targets) do
        local targetData = data
        local distance = 0
        local camera = workspace.CurrentCamera
        if camera then distance = (targetData.root.Position - camera.CFrame.Position).Magnitude end
        local row = makeRow(entityListGroup, targetName(targetData.model), string.format("Humanoid %.0f HP  ·  %.0f studs  ·  %s", targetData.humanoid.Health, distance, targetData.model:GetFullName()), 50)
        makeButton(row, "Select", UDim2.new(1, -82, 0.5, -13), UDim2.fromOffset(70, 26), function()
            state.aim.selected = targetData.model
            currentTargetLabel = targetName(targetData.model)
            if targetValueLabel then targetValueLabel.Text = currentTargetLabel end
            notify("Selected " .. currentTargetLabel .. " for Aim Lab.")
        end, { color = C.panel3, transparency = 0.12 })
        table.insert(entityRefreshRows, row)
    end
end
refreshEntityList()

-- MUSIC PAGE
state.tab = "Music"
local musicInputGroup = makeGroup(pages.Music, "Add a Roblox audio asset", "Only audio your experience is authorized to use can play.")
local musicIdInput = addTextEntry(musicInputGroup, "Audio asset ID", "Numeric ID or rbxassetid:// identifier.", "e.g. 1234567890", "", "Add to queue", function(textValue, input)
    if addTrack(textValue) then input.Text = "" end
end)
local transportGroup = makeGroup(pages.Music, "Playback", "Loading and permission failures are reported rather than hidden.")
addButtonRow(transportGroup, "Play / resume", "Play the selected queue entry or resume playback.", "▶  Play", function()
    if state.music.sound and state.music.sound.Parent and state.music.paused then
        state.music.sound:Resume()
        state.music.paused = false
        musicStatus = "Playing"
        setStatus(musicStatus, false)
    elseif state.music.sound and state.music.sound.Parent and state.music.sound.IsPlaying then
        notify("Audio is already playing.")
    else
        playTrack(state.music.index > 0 and state.music.index or 1)
    end
end, C.accent2)
addButtonRow(transportGroup, "Pause", "Pause the current Roblox Sound.", "Ⅱ  Pause", function()
    if state.music.sound and state.music.sound.IsPlaying then
        state.music.sound:Pause()
        state.music.paused = true
        musicStatus = "Paused"
        setStatus(musicStatus, false)
    else
        notify("No playing track to pause.", true)
    end
end)
addButtonRow(transportGroup, "Stop", "Stop and release the current Sound instance.", "■  Stop", stopMusic, C.red)
addButtonRow(transportGroup, "Previous track", "Return to the previous item in the queue.", "‹  Previous", function()
    if #state.music.queue == 0 then notify("Queue is empty.", true); return end
    playTrack(math.max(1, state.music.index - 1))
end)
addButtonRow(transportGroup, "Next track", "Advance through the queue (or shuffle if enabled).", "Next  ›", function()
    if #state.music.queue == 0 then notify("Queue is empty.", true); return end
    if state.music.shuffle and #state.music.queue > 1 then
        local nextIndex = math.random(1, #state.music.queue)
        if nextIndex == state.music.index then nextIndex = (nextIndex % #state.music.queue) + 1 end
        playTrack(nextIndex)
    else
        playTrack(state.music.index % #state.music.queue + 1)
    end
end)
addSlider(transportGroup, "Volume", "Session volume; mute overrides the slider.", 0, 100, 45, "%", function(value)
    state.music.volume = value / 100
    syncVolume()
end)
addToggle(transportGroup, "Mute", "Set the active Sound volume to zero.", state.music.muted, function(value)
    state.music.muted = value
    syncVolume()
end)
addToggle(transportGroup, "Shuffle", "Choose a random queue entry when advancing.", state.music.shuffle, function(value)
    state.music.shuffle = value
end)
local nowPlayingRow = makeRow(transportGroup, "Now playing", "Asset ID and elapsed / total time.", 50)
musicNowLabel = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(178, 20),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    Text = "No track",
    TextColor3 = C.teal,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 8,
}, nowPlayingRow)
addDropdown(transportGroup, "Repeat mode", "Off, repeat one item, or repeat the whole queue.", { "Off", "One", "All" }, state.music.repeatMode, function(value)
    state.music.repeatMode = value
end)
local queueGroup = makeGroup(pages.Music, "Session queue", "Queue items exist only for this client session.")
local queueRows = {}
local queueScroll
local function refreshQueue()
    resetGroupRows(queueGroup, queueRows)
    local queue = state.music.queue
    if #queue == 0 then
        table.insert(queueRows, makeRow(queueGroup, "Your queue is empty", "Add a permitted audio asset ID above to begin.", 50))
    else
        for index, track in ipairs(queue) do
            local trackIndex, trackData = index, track
            local marker = trackIndex == state.music.index and "  • NOW" or ""
            local row = makeRow(queueGroup, trackData.label .. marker, "rbxassetid://" .. trackData.id, 50)
            makeButton(row, "Play", UDim2.new(1, -144, 0.5, -13), UDim2.fromOffset(62, 26), function() playTrack(trackIndex) end, { color = C.accent2, transparency = 0.1 })
            makeButton(row, trackData.favorite and "★" or "☆", UDim2.new(1, -76, 0.5, -13), UDim2.fromOffset(30, 26), function()
                trackData.favorite = not trackData.favorite
                refreshQueue()
            end, { color = C.panel3, transparency = 0.12, textSize = 14 })
            makeButton(row, "×", UDim2.new(1, -40, 0.5, -13), UDim2.fromOffset(30, 26), function()
                if state.music.index == trackIndex then stopMusic(); state.music.index = 0 end
                table.remove(state.music.queue, trackIndex)
                if state.music.index > trackIndex then state.music.index -= 1 end
                if state.music.index > #state.music.queue then state.music.index = #state.music.queue end
                refreshQueue()
            end, { color = Color3.fromRGB(99, 44, 62), transparency = 0.12, textSize = 14 })
            table.insert(queueRows, row)
        end
    end
    if state.tab == "Music" then applySearch() end
end
-- Refresh queue rows after any queue-changing operation.
local originalAddTrack = addTrack
addTrack = function(rawId)
    local success = originalAddTrack(rawId)
    if success then refreshQueue() end
    return success
end
refreshQueue()
local queueManageGroup = makeGroup(pages.Music, "Queue management", "Remove everything from this session's playlist.")
addButtonRow(queueManageGroup, "Clear queue", "Stop playback and remove all session queue items.", "Clear queue", function()
    stopMusic()
    table.clear(state.music.queue)
    state.music.index = 0
    refreshQueue()
    notify("Music queue cleared.")
end, C.red)
local providerGroup = makeGroup(pages.Music, "Provider bookmarks", "Bookmarks do not play or control Spotify/YouTube Music.")
addTextEntry(providerGroup, "Save external URL", "Store a provider link for manual use outside Roblox.", "https://...", "", "Save link", function(textValue, input)
    local url = tostring(textValue or ""):match("^%s*(.-)%s*$")
    local lower = string.lower(url)
    local allowed = lower:match("^https://open%.spotify%.com/") or lower:match("^https://music%.youtube%.com/") or lower:match("^https://www%.youtube%.com/")
    if not allowed then notify("Use an https:// Spotify or YouTube Music URL.", true); return end
    table.insert(state.music.providerBookmarks, url)
    input.Text = ""
    notify("Provider URL saved for this session; playback remains external.")
end)
addButtonRow(providerGroup, "Show saved bookmark count", "Provider bookmarks are stored in session memory only.", "View count", function()
    notify(tostring(#state.music.providerBookmarks) .. " external bookmark(s) saved.")
end)

-- DIAGNOSTICS PAGE
state.tab = "Diagnostics"
local diagGroup = makeGroup(pages.Diagnostics, "Live client observations", "Values are client-visible estimates; they do not prove server desync.")
local fpsRow = makeRow(diagGroup, "Frame rate estimate", "Average over a short rolling interval.", 49)
local fpsValue = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.fromOffset(120, 20),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    Text = "— FPS",
    TextColor3 = C.teal,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 8,
}, fpsRow)
local posRow = makeRow(diagGroup, "Local position", "Current character root, in studs.", 49)
local posValue = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(190, 20),
    BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = "Unavailable", TextColor3 = C.text,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
}, posRow)
local velocityRow = makeRow(diagGroup, "Local velocity", "Magnitude from the local root assembly, in studs/s.", 49)
local velocityValue = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 20),
    BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = "Unavailable", TextColor3 = C.text,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
}, velocityRow)
local camRow = makeRow(diagGroup, "Current camera", "Client camera type and field of view.", 49)
local camValue = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(190, 20),
    BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = "Unavailable", TextColor3 = C.text,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
}, camRow)
local pingRow = makeRow(diagGroup, "Ping", "Shown only if the standard client stats path is readable.", 49)
local pingValue = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 20),
    BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = "Unavailable", TextColor3 = C.text,
    TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
}, pingRow)
local logGroup = makeGroup(pages.Diagnostics, "Event log", "Latest events first; history is capped at 80 entries.")
local logPreview = make("TextLabel", {
    Position = UDim2.new(0, 12, 0, 53),
    Size = UDim2.new(1, -24, 0, 126),
    BackgroundColor3 = Color3.fromRGB(10, 13, 21),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Font = Enum.Font.Code,
    Text = "[VEYL] Session initialized.",
    TextColor3 = C.muted,
    TextSize = 9,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 7,
}, logGroup.frame)
corner(logPreview, 8)
pad(logPreview, 9, 7, 8, 6)
logGroup.nextY = 188
logGroup.frame.Size = UDim2.new(1, -5, 0, 191)
addButtonRow(logGroup, "Clear event log", "Remove the local diagnostic history.", "Clear logs", function()
    table.clear(state.diagnostics.logs)
    logPreview.Text = "[VEYL] Log cleared."
end)

-- SETTINGS PAGE
state.tab = "Settings"
local appearanceGroup = makeGroup(pages.Settings, "Appearance", "Keep the frosted glass window subtle and readable.")
addToggle(appearanceGroup, "Glass transparency", "Toggle the main panel's translucent surface.", state.transparencyAlways, function(value)
    state.transparencyAlways = value
    mainWindow.BackgroundTransparency = value and 0.13 or 0.02
    updateBlur()
end)
addToggle(appearanceGroup, "Background blur", "Blur the 3D scene while the panel is open.", state.blurEnabled, function(value)
    state.blurEnabled = value
    updateBlur()
end)
local keysGroup = makeGroup(pages.Settings, "Keyboard shortcuts", "Click the binding button, then press a supported key.")
local keyRow = makeRow(keysGroup, "Toggle VEYL window", "Default is RightShift.", 49)
local keyButton
keyButton = makeButton(keyRow, currentBinding.Name, UDim2.new(1, -158, 0.5, -14), UDim2.fromOffset(146, 28), function()
    keyCapture = true
    keyButton.Text = "Press a key…"
    notify("Press a keyboard key to bind. Escape cancels.")
end, { color = C.accent2, transparency = 0.12 })
addButtonRow(keysGroup, "Reset keybind", "Restore the default toggle binding.", "RightShift", function()
    currentBinding = Enum.KeyCode.RightShift
    keyButton.Text = currentBinding.Name
    keyCapture = false
end)
local utilGroup = makeGroup(pages.Settings, "Utilities", "Clean up local features without touching unrelated instances.")
addButtonRow(utilGroup, "Restore defaults", "Reset session values and stop local preview effects.", "Reset defaults", function()
    state.aim.enabled = false
    state.aim.holdToActivate = true
    state.aim.fov = 140
    state.aim.maxDistance = 500
    state.aim.smoothness = 0.12
    state.aim.selected = nil
    state.visualsEnabled = false
    state.visuals.names = true
    state.visuals.highlight = true
    state.visuals.maxDistance = 500
    state.visuals.color = C.teal
    clearVisuals()
    if state.world.enabled then setWorldPreview(false) end
    state.world.brightness = math.clamp(originalLighting.brightness, 0, 5)
    state.world.saturation = 0.08
    state.music.volume = 0.45
    state.music.muted = false
    state.music.shuffle = false
    state.music.repeatMode = "Off"
    state.transparencyAlways = true
    state.blurEnabled = true
    mainWindow.BackgroundTransparency = 0.13
    syncToggleControl("Enable Aim Lab", false)
    syncToggleControl("Hold right mouse to activate", true)
    syncToggleControl("Enable test-target overlays", false)
    syncToggleControl("Name labels", true)
    syncToggleControl("Highlight models", true)
    syncToggleControl("Enable world preview", false)
    syncToggleControl("Mute", false)
    syncToggleControl("Shuffle", false)
    syncToggleControl("Transparency stays on in every theme", true)
    syncToggleControl("Glass transparency", true)
    syncToggleControl("Soft background blur", true)
    syncToggleControl("Background blur", true)
    syncSliderControl("FOV radius", 140)
    syncSliderControl("Maximum target distance", 500)
    syncSliderControl("Smoothness", 12)
    syncSliderControl("Maximum visual distance", 500)
    syncSliderControl("Brightness", math.clamp(originalLighting.brightness, 0, 5))
    syncSliderControl("Saturation", 8)
    syncSliderControl("Volume", 45)
    syncDropdownControl("Overlay color", "Teal")
    syncDropdownControl("Repeat mode", "Off")
    updateBlur()
    notify("Defaults restored for this session.")
    selectTab("Home")
end, C.accent2)
addButtonRow(utilGroup, "Emergency stop all", "Stop Aim Lab, overlays, local lighting, and music.", "STOP ALL", function()
    state.aim.enabled = false
    state.aim.selected = nil
    state.visualsEnabled = false
    clearVisuals()
    if state.world.enabled then setWorldPreview(false) end
    stopMusic()
    syncToggleControl("Enable Aim Lab", false)
    syncToggleControl("Enable test-target overlays", false)
    syncToggleControl("Enable world preview", false)
    currentTargetLabel = "None"
    if targetValueLabel and targetValueLabel.Parent then targetValueLabel.Text = "None" end
    notify("All supported local features have been stopped.")
end, C.red)
addButtonRow(utilGroup, "Rejoin current experience", "Requests a teleport; a different server is not guaranteed.", "Rejoin", function()
    if state.rejoining then notify("A rejoin request is already in progress.", true); return end
    if RunService:IsStudio() then
        notify("Teleport testing requires a published experience playtest.", true)
        return
    end
    state.rejoining = true
    setStatus("●  REQUESTING REJOIN", false)
    local ok, err = pcall(function() TeleportService:Teleport(game.PlaceId, LOCAL_PLAYER) end)
    if not ok then
        state.rejoining = false
        log("Rejoin request failed: " .. tostring(err), true)
        setStatus("●  REJOIN FAILED", true)
    end
end)

-- Build one persistent, client-side render loop for visual maintenance and diagnostics.
listen(RunService.RenderStepped, function(deltaTime)
    if not screenGui or not screenGui.Parent then return end
    renderElapsed += deltaTime
    musicProgressClock += deltaTime
    if musicProgressClock >= 0.2 then
        musicProgressClock = 0
        if musicNowLabel and musicNowLabel.Parent then
            local sound = state.music.sound
            if sound and sound.Parent and sound.IsLoaded then
                local function fmt(seconds)
                    seconds = math.max(0, math.floor(seconds))
                    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
                end
                musicNowLabel.Text = tostring(state.music.queue[state.music.index] and state.music.queue[state.music.index].id or "Audio") .. "  ·  " .. fmt(sound.TimePosition) .. " / " .. fmt(sound.TimeLength)
            elseif sound and sound.Parent then
                musicNowLabel.Text = "Loading audio asset..."
            else
                musicNowLabel.Text = "No track"
            end
        end
    end
    fpsFrames += 1
    fpsClock += deltaTime
    if fpsClock >= 1 then
        state.diagnostics.fps = math.floor(fpsFrames / fpsClock + 0.5)
        fpsFrames = 0
        fpsClock = 0
        if fpsValue and fpsValue.Parent then fpsValue.Text = tostring(state.diagnostics.fps) .. " FPS" end
        local character = LOCAL_PLAYER.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and posValue and posValue.Parent then
            local p = root.Position
            posValue.Text = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
            velocityValue.Text = string.format("%.1f st/s", root.AssemblyLinearVelocity.Magnitude)
        end
        local camera = workspace.CurrentCamera
        if camera and camValue and camValue.Parent then
            camValue.Text = camera.CameraType.Name .. "  ·  FOV " .. tostring(math.floor(camera.FieldOfView + 0.5))
        end
        if pingValue and pingValue.Parent then
            local success, value = pcall(function()
                local network = Stats:FindFirstChild("Network")
                local serverStats = network and network:FindFirstChild("ServerStatsItem")
                local ping = serverStats and serverStats:FindFirstChild("Data Ping")
                return ping and ping:GetValueString()
            end)
            pingValue.Text = success and value or "Unavailable"
        end
        if logPreview and logPreview.Parent then
            local latest = {}
            for index = 1, math.min(8, #state.diagnostics.logs) do table.insert(latest, state.diagnostics.logs[index]) end
            if #latest > 0 then logPreview.Text = table.concat(latest, "\n") end
        end
    end

    if activeSlider then
        local pointerX = activeSliderPointerX
        local track = activeSlider.track
        if track and track.Parent then
            local t = math.clamp((pointerX - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            activeSlider.set(activeSlider.min + t * (activeSlider.max - activeSlider.min), false)
        end
    end

    if state.visualsEnabled then
        for model, objects in pairs(highlightObjects) do
            local dataRoot = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
            local camera = workspace.CurrentCamera
            local distance = (dataRoot and camera) and (dataRoot.Position - camera.CFrame.Position).Magnitude or math.huge
            for _, object in ipairs(objects) do
                if object:IsA("BillboardGui") then object.Enabled = distance <= state.visuals.maxDistance end
                if object:IsA("Highlight") then object.Enabled = distance <= state.visuals.maxDistance end
            end
            if not model or not model.Parent then
                for _, object in ipairs(objects) do if object and object.Parent then object:Destroy() end end
                highlightObjects[model] = nil
            end
        end
    end

    if state.aim.enabled and (not state.aim.holdToActivate or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
        local camera = workspace.CurrentCamera
        if camera then
            local viewport = camera.ViewportSize
            local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
            local best, bestScreenDistance = nil, state.aim.fov
            local candidates = getTaggedTargets()
            local selectedStillValid = false
            for _, data in ipairs(candidates) do
                if data.model == state.aim.selected then selectedStillValid = true end
            end
            if state.aim.selected and not selectedStillValid then state.aim.selected = nil end
            for _, data in ipairs(candidates) do
                local worldDistance = (data.root.Position - camera.CFrame.Position).Magnitude
                if worldDistance <= state.aim.maxDistance and (not state.aim.selected or data.model == state.aim.selected) then
                    local targetPart = data.model:FindFirstChild("Head") or data.root
                    local screenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen and screenPoint.Z > 0 then
                        local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude
                        if distance <= bestScreenDistance then
                            bestScreenDistance = distance
                            best = targetPart
                        end
                    end
                end
            end
            if best then
                local desired = CFrame.lookAt(camera.CFrame.Position, best.Position)
                camera.CFrame = camera.CFrame:Lerp(desired, math.clamp(state.aim.smoothness * 6, 0.01, 0.9))
                currentTargetLabel = best.Parent and targetName(best.Parent) or "None"
                if targetValueLabel and targetValueLabel.Parent then targetValueLabel.Text = currentTargetLabel end
            end
        end
    end
end)

-- Mouse/touch drag on the title bar, excluding the search field and titlebar buttons.
listen(topbar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local x, y = input.Position.X, input.Position.Y
        local searchPos, searchSize = searchBox.AbsolutePosition, searchBox.AbsoluteSize
        local inSearch = x >= searchPos.X and x <= searchPos.X + searchSize.X and y >= searchPos.Y and y <= searchPos.Y + searchSize.Y
        if x < (closeButton.AbsolutePosition.X - 4) and x < (minimizeButton.AbsolutePosition.X - 4) and not inSearch and not searchBox:IsFocused() then
            draggingWindow = true
            dragOriginInput = input.Position
            dragOriginPosition = mainWindow.Position
        end
    end
end)
listen(UserInputService.InputChanged, function(input)
    if draggingWindow and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragOriginInput
        mainWindow.Position = UDim2.new(dragOriginPosition.X.Scale, dragOriginPosition.X.Offset + delta.X, dragOriginPosition.Y.Scale, dragOriginPosition.Y.Offset + delta.Y)
    end
    if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        activeSliderPointerX = input.Position.X
    end
end)
listen(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingWindow = false
        activeSlider = nil
    end
end)

listen(minimizeButton.Activated, function()
    mainWindow.Visible = false
    state.uiOpen = false
    updateBlur()
end)
listen(closeButton.Activated, function()
    mainWindow.Visible = false
    state.uiOpen = false
    updateBlur()
end)

listen(searchBox:GetPropertyChangedSignal("Text"), applySearch)
listen(UserInputService.InputBegan, function(input, processed)
    if keyCapture then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                keyCapture = false
                if keyButton and keyButton.Parent then keyButton.Text = currentBinding.Name end
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                currentBinding = input.KeyCode
                keyCapture = false
                if keyButton and keyButton.Parent then keyButton.Text = currentBinding.Name end
                notify("Window toggle key changed to " .. currentBinding.Name .. ".")
            end
        end
        return
    end
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentBinding then
        mainWindow.Visible = not mainWindow.Visible
        state.uiOpen = mainWindow.Visible
        updateBlur()
    elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.End then
        state.aim.enabled = false
        state.visualsEnabled = false
        clearVisuals()
        if state.world.enabled then setWorldPreview(false) end
        stopMusic()
        syncToggleControl("Enable Aim Lab", false)
        syncToggleControl("Enable test-target overlays", false)
        syncToggleControl("Enable world preview", false)
        currentTargetLabel = "None"
        if targetValueLabel and targetValueLabel.Parent then targetValueLabel.Text = "None" end
        setStatus("●  FEATURES STOPPED", false)
        notify("Emergency stop: supported local features are off.")
    end
end)

listen(CollectionService:GetInstanceAddedSignal(TARGET_TAG), function(instance)
    if instance:IsA("Model") then
        log("Test target tag added: " .. instance.Name)
        if state.visualsEnabled then updateVisuals() end
        if state.tab == "Entities" then refreshEntityList() end
    end
end)
listen(CollectionService:GetInstanceRemovedSignal(TARGET_TAG), function(instance)
    if highlightObjects[instance] then
        for _, object in ipairs(highlightObjects[instance]) do if object and object.Parent then object:Destroy() end end
        highlightObjects[instance] = nil
    end
    if state.aim.selected == instance then state.aim.selected = nil; currentTargetLabel = "None" end
    if state.tab == "Entities" then refreshEntityList() end
end)

-- If the character respawns, keep the panel alive; this script never changes player state.
listen(LOCAL_PLAYER.CharacterAdded, function()
    log("Local character refreshed.")
end)

listen(TeleportService.TeleportInitFailed, function(player, result, errorMessage)
    if player == LOCAL_PLAYER then
        state.rejoining = false
        setStatus("●  REJOIN FAILED", true)
        log("Teleport failed: " .. tostring(result) .. " — " .. tostring(errorMessage), true)
    end
end)

-- Keep selected tab state and visual style consistent.
selectTab("Home")
updateBlur()
log("VEYL Control loaded. Tag authorized training models with " .. TARGET_TAG .. ".")
notify("VEYL Control ready.")

listen(screenGui.Destroying, function()
    cleanupAll()
end)
listen(script.Destroying, function()
    cleanupAll()
end)
