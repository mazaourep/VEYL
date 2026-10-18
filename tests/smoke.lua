
-- Test driver (runs after `main` is defined) -----------------------------------
local failures = 0
local function check(condition, message)
    if condition then
        print("PASS  " .. message)
    else
        failures += 1
        print("FAIL  " .. message)
    end
end
local function frames(n, dt)
    for _ = 1, n do STEP(dt) end
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
local guiHost = EXECUTOR and game:GetService("CoreGui") or playerGui

local function veylGuis()
    local n = 0
    for _, child in ipairs(guiHost:GetChildren()) do
        if child.Name == "VEYLControl" then n += 1 end
    end
    return n
end

-- Legacy instance to be cleaned up on startup.
local legacy = Instance.new("ScreenGui")
legacy.Name = "NovaAdminConsole"
legacy.Parent = playerGui
local unrelated = Instance.new("ScreenGui")
unrelated.Name = "GameHUD"
unrelated.Parent = playerGui

local connectionsBefore = COUNT_CONNECTIONS()
main()
frames(30)
check(#ERRORS == 0, "startup without errors (" .. #ERRORS .. ")")
check(veylGuis() == 1, "one VEYLControl ScreenGui in " .. (EXECUTOR and "gethui()" or "PlayerGui"))
check(IS_DESTROYED(legacy), "legacy NovaAdminConsole removed")
check(not IS_DESTROYED(unrelated), "unrelated GameHUD kept")

local gui = guiHost:FindFirstChild("VEYLControl")
local function buttons(root)
    return FIND_ALL(root, function(x) return CLASSNAME(x) == "TextButton" end)
end
local function byText(root, textValue)
    for _, b in ipairs(buttons(root)) do
        if PROPS(b).Text == textValue then return b end
    end
    return nil
end

-- Entities
local dummy, dummyHumanoid = MAKE_CHARACTER("Dummy", Vector3.new(5, 3, -10))
ADD_TAG(dummy, "VEYLTestTarget")
local npc = MAKE_CHARACTER("Zombie", Vector3.new(15, 3, -30))
local other, otherChar = ADD_PLAYER("Friend", Vector3.new(-12, 3, -25))
frames(10)
check(#ERRORS == 0, "entity discovery without errors")

-- Live players require explicit per-session allowlisting for Aim Lab and ESP.
-- A test-target tag must not bypass that boundary for an actual Player.
ADD_TAG(otherChar, "VEYLTestTarget")
frames(6, 0.1)
clickText(gui, "Entities")
frames(12, 0.1)
local function getFriendRow()
    for _, candidate in ipairs(FIND_ALL(gui, function(x)
        return CLASSNAME(x) == "TextLabel"
            and string.find(PROPS(x).Text or "", "Friend", 1, true) ~= nil
            and PROPS(x).Parent
            and PROPS(PROPS(x).Parent).Name == "Row"
    end)) do
        return PROPS(candidate).Parent
    end
    return nil
end
local function friendDetail(row)
    if not row then return nil, "" end
    for _, candidate in ipairs(FIND_ALL(row, function(x)
        return CLASSNAME(x) == "TextLabel"
            and string.find(PROPS(x).Text or "", "A:", 1, true) ~= nil
    end)) do
        return candidate, PROPS(candidate).Text or ""
    end
    return nil, ""
end
local function friendAllowButton(row)
    if not row then return nil end
    for _, candidate in ipairs(FIND_ALL(row, function(x)
        return CLASSNAME(x) == "TextButton"
            and (PROPS(x).Text == "Allow" or PROPS(x).Text == "Revoke")
    end)) do
        return candidate
    end
    return nil
end
local friendRow = getFriendRow()
local allowButton = friendAllowButton(friendRow)
check(friendRow ~= nil and allowButton ~= nil, "live Player appears in Entities with an allowlist control")
local _, initialScope = friendDetail(friendRow)
check(string.find(initialScope, "A:—", 1, true) ~= nil
    and string.find(initialScope, "E:—", 1, true) ~= nil,
    "tagging a real Player does not bypass the allowlist")
if allowButton then
    if PROPS(allowButton).Text ~= "Allow" then FIRE(allowButton, "Activated"); frames(6, 0.1) end
    FIRE(allowButton, "Activated")
    frames(12, 0.1)
    local _, allowedScope = friendDetail(friendRow)
    check(string.find(allowedScope, "A:✓", 1, true) ~= nil
        and string.find(allowedScope, "E:✓", 1, true) ~= nil,
        "allowlisted real Player becomes eligible for Aim and ESP")
    FIRE(allowButton, "Activated")
    frames(12, 0.1)
    local _, revokedScope = friendDetail(friendRow)
    check(string.find(revokedScope, "A:—", 1, true) ~= nil
        and string.find(revokedScope, "E:—", 1, true) ~= nil,
        "revoking a real Player removes Aim and ESP eligibility")
end
clickText(gui, "Main")

-- Tools
local tool = Instance.new("Tool")
tool.Name = "Assault Rifle"
local ammo = Instance.new("IntValue", tool); ammo.Name = "Ammo"
local remote = Instance.new("RemoteEvent", tool); remote.Name = "FireRemote"
local muzzle = Instance.new("Attachment", tool); muzzle.Name = "Muzzle"
tool.Parent = Players.LocalPlayer:FindFirstChild("Backpack")
local template = Instance.new("Tool")
template.Name = "Sword"
template.Parent = game:GetService("ReplicatedStorage")
frames(60)
check(#ERRORS == 0, "tool discovery without errors")

-- Hotkeys: ESP and Aim
local cameraBefore = workspace.CurrentCamera.CFrame
KEY("X")
KEY("Z")
HELD.MouseButton2 = true
frames(60)
check(BOUND_STEPS() == 1, "Aim Lab bound one render step")
local cameraAfter = workspace.CurrentCamera.CFrame
check((cameraAfter.LookVector - cameraBefore.LookVector).Magnitude > 1e-4, "Aim Lab turned the camera toward the tagged dummy")
HELD.MouseButton2 = false
KEY("C")
KEY("V")
frames(5)
if EXECUTOR then
    check(DRAWINGS.created > 0, "Drawing objects created by ESP/Aim (" .. DRAWINGS.created .. ")")
end
check(#ERRORS == 0, "ESP + Aim Lab frames without errors")

-- Typing must not trigger hotkeys: processed input is ignored
KEY("X", true)
frames(2)

-- Text inputs: invalid and valid values
local boxes = FIND_ALL(gui, function(x) return CLASSNAME(x) == "TextBox" end)
for _, box in ipairs(boxes) do
    for _, value in ipairs({ "abc", "99999", "-5", "#GG0000", "#12AB9F", "rbxassetid://12345", "999", "7", "Mix | https://open.spotify.com/playlist/abc", "https://evil.com/x", "https://open.spotify.com/x?access_token=1" }) do
        box.Text = value
        FIRE(box, "FocusLost", true)
    end
end
frames(30)
check(#ERRORS == 0, "text input validation without errors")

-- Click every button, then every popup button (one level), skipping Unload confirmation.
local popupLayer = gui:FindFirstChild("Popups")
local snapshot = buttons(gui)
local clicked = 0
for _, button in ipairs(snapshot) do
    if not IS_DESTROYED(button) and not (PROPS(button).Text == "Unload VEYL") then
        FIRE(button, "MouseEnter")
        FIRE(button, "Activated")
        FIRE(button, "MouseButton2Click")
        FIRE(button, "MouseLeave")
        clicked += 1
        local popupButtons = buttons(popupLayer)
        for index = #popupButtons, 1, -1 do
            local pb = popupButtons[index]
            if not IS_DESTROYED(pb) and PROPS(pb).Text ~= "Unload" then
                FIRE(pb, "Activated")
            end
        end
        frames(2)
    end
end
frames(30)
check(clicked > 150, "clicked " .. clicked .. " buttons")
check(#ERRORS == 0, "button fuzz without errors")

-- Second fuzz pass with features in whatever state the first pass left them.
for _, button in ipairs(buttons(gui)) do
    if not IS_DESTROYED(button) and PROPS(button).Text ~= "Unload VEYL" and PROPS(button).Text ~= "Unload" then
        FIRE(button, "Activated")
        frames(1)
    end
end
KEY("Escape")
frames(120, 0.1)
check(#ERRORS == 0, "second fuzz pass and 12 s of frames without errors")

-- Force features on and change lighting through the World toggle, then emergency stop.
KEY("X")
KEY("Z")
frames(10)
KEY("End")
frames(5)
check(BOUND_STEPS() == 0, "emergency stop unbound Aim Lab render step")
check(math.abs(Lighting.Brightness - 2) < 1e-6 and Lighting.ClockTime == 14, "lighting restored after emergency stop")
if EXECUTOR then
    local live = 0
    for _ in pairs(DRAWINGS.live) do live += 1 end
    check(live == 0, "no live Drawing objects after emergency stop (" .. live .. ")")
end
check(SoundService:FindFirstChild("VEYLMusicPlayer") == nil, "music Sound removed after emergency stop")

-- Removing the dummy while selected must not error.
KEY("Z")
KEY("C")
frames(3)
dummy.Parent = nil
frames(5)
dummyHumanoid.Health = 0
otherChar.Parent = nil
frames(5)
check(#ERRORS == 0, "entity removal while targeted without errors")

-- Re-execution: the previous session shuts down first.
main()
frames(10)
check(veylGuis() == 1, "re-execution leaves exactly one console")
check(#ERRORS == 0, "re-execution without errors")

-- Persistence round trip (executor run only).
if EXECUTOR then
    local saved = FILES["VEYL/config.json"]
    check(saved ~= nil and string.find(saved, "VEYL Control", 1, true) ~= nil, "config written to VEYL/config.json")
    check(saved == nil or not string.find(saved, "esp.enabled", 1, true), "session-only flags not persisted")
end

-- Final shutdown and leak checks.
SHARED.__VEYL_SESSION.shutdown("test")
frames(20, 0.5)
check(veylGuis() == 0, "console removed on shutdown")
check(workspace:FindFirstChild("VEYLClientFX") == nil, "FX folder removed")
check(Lighting:FindFirstChild("VEYLClientBlur") == nil and Lighting:FindFirstChild("VEYLColorCorrection") == nil and Lighting:FindFirstChild("VEYLBloom") == nil, "Lighting effects removed")
check(BOUND_STEPS() == 0, "no render steps bound after shutdown")
check(COUNT_CONNECTIONS() == connectionsBefore, "no connections leaked (" .. COUNT_CONNECTIONS() .. " live, baseline " .. connectionsBefore .. ")")
if EXECUTOR then
    local live = 0
    for _ in pairs(DRAWINGS.live) do live += 1 end
    check(live == 0, "all Drawing objects removed (" .. DRAWINGS.created .. " created)")
end
check(#ERRORS == 0, "no errors overall")
print(string.format("RESULT: %d failure(s), %d error(s)", failures, #ERRORS))
