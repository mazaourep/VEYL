
-- Focused behavior tests (executor build) --------------------------------------
local failures = 0
local function check(condition, message)
    if condition then print("PASS  " .. message) else failures += 1; print("FAIL  " .. message) end
end
local function frames(n, dt) for _ = 1, n do STEP(dt) end end
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local host = game:GetService("CoreGui")

main()
frames(10)
local gui = host:FindFirstChild("VEYLControl")
local function rowOf(labelText)
    for _, label in ipairs(FIND_ALL(gui, function(x) return CLASSNAME(x) == "TextLabel" and PROPS(x).Text == labelText end)) do
        local row = PROPS(label).Parent
        if row and PROPS(row).Name == "Row" then return row end
    end
    return nil
end
local function clickToggle(labelText)
    local row = rowOf(labelText)
    assert(row, "no row " .. labelText)
    for _, child in ipairs(row:GetChildren()) do
        if CLASSNAME(child) == "TextButton" then FIRE(child, "Activated") return end
    end
    error("no toggle button in " .. labelText)
end
local function setSlider(labelText, value)
    local row = rowOf(labelText)
    assert(row, "no row " .. labelText)
    local box = row:FindFirstChildOfClass("TextBox")
    box.Text = tostring(value)
    FIRE(box, "FocusLost", true)
end
local function sliderText(labelText)
    return PROPS(rowOf(labelText):FindFirstChildOfClass("TextBox")).Text
end
local function clickText(root, textValue)
    for _, b in ipairs(FIND_ALL(root, function(x) return CLASSNAME(x) == "TextButton" and PROPS(x).Text == textValue end)) do
        FIRE(b, "Activated")
        return true
    end
    return false
end

-- World overrides and restore rule
clickToggle("Enable world overrides")
setSlider("Brightness", 5)
check(math.abs(Lighting.Brightness - 5) < 1e-6, "World brightness applied (5)")
setSlider("Brightness", 42)
check(sliderText("Brightness") == "10.0", "out-of-range brightness clamped to 10.0 (" .. sliderText("Brightness") .. ")")
check(Lighting:FindFirstChild("VEYLColorCorrection") ~= nil, "color correction effect created")
clickToggle("Enable world overrides")
check(math.abs(Lighting.Brightness - 2) < 1e-6, "brightness restored to snapshot on disable")
check(Lighting:FindFirstChild("VEYLColorCorrection") == nil, "color correction removed on disable")
clickToggle("Enable world overrides")
Lighting.Brightness = 3 -- the game changes it after VEYL wrote 10
clickToggle("Enable world overrides")
check(math.abs(Lighting.Brightness - 3) < 1e-6, "game's newer value kept on restore (restore rule)")
Lighting.Brightness = 2

-- Keybind collision: rebind Toggle ESP to Z (used by Toggle Aim Lab) -> confirm dialog
local function bindButton(labelText)
    local row = rowOf(labelText)
    for _, child in ipairs(row:GetChildren()) do
        if CLASSNAME(child) == "TextButton" and PROPS(child).Text == "" then return child end
    end
end
FIRE(bindButton("Toggle ESP"), "Activated")
KEY("Z")
local popups = gui:FindFirstChild("Popups")
check(clickText(popups, "Reassign"), "collision opened a confirmation dialog")
frames(2)
-- Emergency stop protection: Backspace cannot unbind it
FIRE(bindButton("Emergency stop  ⚑"), "Activated")
KEY("Backspace")
frames(1)
local summary = FIND_ALL(gui, function(x) return CLASSNAME(x) == "TextLabel" and string.find(PROPS(x).Text or "", "Emergency stop", 1, true) ~= nil and string.find(PROPS(x).Text, "End", 1, true) ~= nil end)
check(#summary > 0, "emergency stop still bound to End after Backspace")

-- Music: add, play, next, volume, failure
local inputRow = nil
for _, box in ipairs(FIND_ALL(gui, function(x) return CLASSNAME(x) == "TextBox" and PROPS(x).PlaceholderText == "1234567890 or rbxassetid://1234567890" end)) do inputRow = box end
inputRow.Text = "rbxassetid://1111"; FIRE(inputRow, "FocusLost", true)
inputRow.Text = "2222"; FIRE(inputRow, "FocusLost", true)
inputRow.Text = "2222"; FIRE(inputRow, "FocusLost", true)
inputRow.Text = "abc"; FIRE(inputRow, "FocusLost", true)
frames(30, 0.1)
clickText(gui, "▶ Play")
frames(5)
local sound = SoundService:FindFirstChild("VEYLMusicPlayer")
check(sound ~= nil and PROPS(sound).SoundId == "rbxassetid://1111", "first track plays as rbxassetid://1111")
setSlider("Volume", 80)
check(sound and math.abs(PROPS(sound).Volume - 0.8) < 1e-6, "volume 80% applied to Sound")
clickToggle("Mute")
check(sound and PROPS(sound).Volume == 0, "mute sets volume 0")
clickToggle("Mute")
clickText(gui, "Next ››")
frames(3)
sound = SoundService:FindFirstChild("VEYLMusicPlayer")
check(sound ~= nil and PROPS(sound).SoundId == "rbxassetid://2222", "next plays the second track")
local titles = FIND_ALL(gui, function(x) return CLASSNAME(x) == "TextLabel" and PROPS(x).Text == "♪ Song 2222" end)
check(#titles > 0, "track title comes from asset info (Song 2222)")
FIRE(sound, "Ended")
frames(3)
check(SoundService:FindFirstChild("VEYLMusicPlayer") == nil, "queue finished with repeat Off (no sound left)")

-- ESP geometry with Drawing
local dummy = MAKE_CHARACTER("Dummy", Vector3.new(4, 3, -10))
ADD_TAG(dummy, "VEYLTestTarget")
frames(3)
clickToggle("Enable ESP")
frames(5)
local visibleBoxes = 0
for obj in pairs(DRAWINGS.live) do
    if obj.kind == "Square" and obj.Visible and obj.Filled == false and obj.Thickness == 1 then
        if obj.Size.X > 4 and obj.Size.Y > 4 and obj.Position.X > 640 and obj.Position.X < 1280 then visibleBoxes += 1 end
    end
end
check(visibleBoxes == 1, "one ESP box drawn right of center for the tagged dummy (" .. visibleBoxes .. ")")
-- Move camera so the dummy is behind it: box hidden, off-screen arrow shown
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 5, 20), Vector3.new(0, 5, 60))
frames(3)
local arrows, boxes = 0, 0
for obj in pairs(DRAWINGS.live) do
    if obj.kind == "Triangle" and obj.Visible then arrows += 1 end
    if obj.kind == "Square" and obj.Visible and obj.Filled == false and obj.Thickness == 1 then boxes += 1 end
end
check(arrows == 1 and boxes == 0, "behind camera: box hidden, off-screen arrow shown")
-- Partially behind: camera inside the box's depth range should still produce a clipped box
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(4, 4, -9.4), Vector3.new(4, 4, -60))
frames(3)
boxes = 0
for obj in pairs(DRAWINGS.live) do
    if obj.kind == "Square" and obj.Visible and obj.Filled == false and obj.Thickness == 1 then boxes += 1 end
end
check(boxes == 1, "near-plane crossing: box still drawn via edge clipping")
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 5, 20), Vector3.new(0, 5, 0))

-- Renderer switch to GUI fallback mid-session releases Drawing objects
local before = 0
for _ in pairs(DRAWINGS.live) do before += 1 end
local rendererRow = rowOf("Renderer")
for _, child in ipairs(rendererRow:GetDescendants()) do
    if CLASSNAME(child) == "TextButton" then FIRE(child, "Activated") break end
end
clickText(popups, "  GUI")
frames(3)
local after = 0
for _ in pairs(DRAWINGS.live) do after += 1 end
local overlay = host:FindFirstChild("VEYLOverlay")
check(before > 0 and after == 0 and overlay ~= nil, "switching to GUI renderer removed Drawing objects and created VEYLOverlay")

-- Persistence round trip: save, re-execute, values restored
local saveOk = clickText(gui, "Save now")
frames(1)
local saved = FILES["VEYL/config.json"]
check(saveOk and saved and string.find(saved, "1111", 1, true) ~= nil, "queue IDs saved in config")
main()
frames(10)
gui = host:FindFirstChild("VEYLControl")
check(sliderText("Volume") == "80%", "volume restored from config after re-execution (" .. sliderText("Volume") .. ")")
local espToggleOff = true
check(SoundService:FindFirstChild("VEYLMusicPlayer") == nil, "music does not auto-play after reload")

-- Malformed config is rejected without crashing
FILES["VEYL/config.json"] = "{not json"
main()
frames(5)
check(#ERRORS == 0, "malformed config ignored without errors")
FILES["VEYL/config.json"] = '{"app":"VEYL Control","settings":{"aim.fov":"huge","esp.textSize":99,"color.box":"#ZZZZZZ","esp.enabled":true},"binds":{"emergencyStop":"None","toggleUI":"KeyCode.Escape"}}'
main()
frames(5)
gui = host:FindFirstChild("VEYLControl")
check(sliderText("Text size") == "18 px", "out-of-range config value clamped (text size 18)")
check(sliderText("FOV radius") == "140 px", "invalid config number rejected (FOV stays 140)")
local stopBound = FIND_ALL(gui, function(x) return CLASSNAME(x) == "TextLabel" and string.find(PROPS(x).Text or "", "End", 1, true) and string.find(PROPS(x).Text, "Emergency stop", 1, true) end)
check(#stopBound > 0, "config cannot unbind the emergency stop")

SHARED.__VEYL_SESSION.shutdown("test")
frames(5)
LIST_CONNECTIONS()
check(COUNT_CONNECTIONS() == 0, "no leaked connections after focused tests")
check(#ERRORS == 0, "no runtime errors (" .. #ERRORS .. ")")
print(string.format("RESULT: %d failure(s), %d error(s)", failures, #ERRORS))
