-- VEYL module: binds
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local UserInputService = V.UserInputService
    local Util = V.Util
    local Notify = V.Notify
    local Binds = V.Binds
    local Persist = V.Persist
    local UI = V.UI

    ----------------------------------------------------------------------------
    -- 8. Keybind manager (the single input router lives in app.lua)
    ----------------------------------------------------------------------------

    Binds.actions = {
        { id = "toggleUI", label = "Toggle console", default = "KeyCode.RightShift" },
        { id = "toggleAim", label = "Toggle Aim Lab", default = "KeyCode.Z" },
        { id = "aimHold", label = "Aim Lab hold key", default = "UserInputType.MouseButton2", hold = true },
        { id = "toggleESP", label = "Toggle ESP", default = "KeyCode.X" },
        { id = "cycleTarget", label = "Cycle test target", default = "KeyCode.C" },
        { id = "clearTarget", label = "Clear selected target", default = "KeyCode.V" },
        { id = "emergencyStop", label = "Emergency stop", default = "KeyCode.End", protected = true },
    }
    Binds.byId = {}
    Binds.map = {}
    Binds.lookup = {}
    Binds.enums = {}
    Binds.changed = Util.signal()
    Binds.capturing = nil

    local BIND_MOUSE = { MouseButton2 = "Mouse 2", MouseButton3 = "Mouse 3" }
    local BIND_RESERVED = { Escape = true, Backspace = true, Unknown = true }

    for _, action in ipairs(Binds.actions) do
        Binds.byId[action.id] = action
        Binds.map[action.id] = action.default
    end

    function Binds.parse(text)
        if text == "None" then
            return "None"
        end
        if type(text) ~= "string" then
            return nil
        end
        local enumName, item = string.match(text, "^(%a+)%.(%w+)$")
        if enumName == "KeyCode" and not BIND_RESERVED[item] then
            local ok, keyCode = pcall(function()
                return Enum.KeyCode[item]
            end)
            if ok and keyCode then
                return text
            end
        elseif enumName == "UserInputType" and BIND_MOUSE[item] then
            return text
        end
        return nil
    end

    function Binds.fromInput(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local name = input.KeyCode.Name
            if BIND_RESERVED[name] then
                return nil
            end
            return "KeyCode." .. name
        end
        if BIND_MOUSE[input.UserInputType.Name] then
            return "UserInputType." .. input.UserInputType.Name
        end
        return nil
    end

    function Binds.display(text)
        if not text or text == "None" then
            return "Unbound"
        end
        local enumName, item = string.match(text, "^(%a+)%.(%w+)$")
        if enumName == "UserInputType" then
            return BIND_MOUSE[item] or item
        end
        return item or text
    end

    function Binds.rebuild()
        table.clear(Binds.lookup)
        for id, text in pairs(Binds.map) do
            if text ~= "None" and not Binds.byId[id].hold then
                Binds.lookup[text] = id
            end
            if text ~= "None" and not Binds.enums[text] then
                local enumName, item = string.match(text, "^(%a+)%.(%w+)$")
                local ok, value = pcall(function()
                    if enumName == "KeyCode" then
                        return Enum.KeyCode[item]
                    end
                    return Enum.UserInputType[item]
                end)
                if ok and value then
                    Binds.enums[text] = { kind = enumName, value = value }
                end
            end
        end
    end

    function Binds.ownerOf(text, exceptId)
        for id, bound in pairs(Binds.map) do
            if bound == text and id ~= exceptId then
                return id
            end
        end
        return nil
    end

    function Binds.set(id, text)
        if not Binds.byId[id] or not Binds.parse(text) then
            return false
        end
        Binds.map[id] = text
        Binds.rebuild()
        Binds.changed:Fire(id)
        Persist.schedule()
        return true
    end

    function Binds.reset(id)
        local action = Binds.byId[id]
        if not action then
            return
        end
        local owner = Binds.ownerOf(action.default, id)
        if owner then
            Binds.map[owner] = "None"
            Binds.changed:Fire(owner)
        end
        Binds.set(id, action.default)
    end

    function Binds.resetAll()
        for _, action in ipairs(Binds.actions) do
            Binds.map[action.id] = action.default
        end
        Binds.rebuild()
        for _, action in ipairs(Binds.actions) do
            Binds.changed:Fire(action.id)
        end
        Persist.schedule()
    end

    function Binds.match(input)
        local text = Binds.fromInput(input)
        return text and Binds.lookup[text] or nil
    end

    function Binds.isHeld(id)
        local text = Binds.map[id]
        if not text or text == "None" or UserInputService:GetFocusedTextBox() then
            return false
        end
        local entry = Binds.enums[text]
        if not entry then
            return false
        end
        if entry.kind == "KeyCode" then
            return UserInputService:IsKeyDown(entry.value)
        end
        return UserInputService:IsMouseButtonPressed(entry.value)
    end

    function Binds.loadTable(data)
        if type(data) ~= "table" then
            return
        end
        local used = {}
        for _, action in ipairs(Binds.actions) do
            local text = Binds.parse(data[action.id])
            if text and (text == "None" or not used[text]) and not (action.protected and text == "None") then
                Binds.map[action.id] = text
            end
            if Binds.map[action.id] ~= "None" then
                if used[Binds.map[action.id]] then
                    -- A collision in a hand-edited file falls back to that action's default.
                    Binds.map[action.id] = action.default
                end
                used[Binds.map[action.id]] = true
            end
        end
        Binds.rebuild()
    end

    function Binds.beginCapture(id)
        if Binds.capturing then
            Binds.cancelCapture()
        end
        Binds.capturing = { id = id }
        Binds.changed:Fire(id)
    end

    function Binds.cancelCapture()
        local capture = Binds.capturing
        Binds.capturing = nil
        if capture then
            Binds.changed:Fire(capture.id)
        end
    end

    function Binds.handleCapture(input)
        local capture = Binds.capturing
        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.MouseButton1
            or inputType == Enum.UserInputType.MouseWheel or inputType == Enum.UserInputType.Focus then
            return
        end
        local id = capture.id
        local action = Binds.byId[id]
        if inputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
            Binds.cancelCapture()
            Notify.push("Rebind cancelled.", "info")
            return
        end
        if inputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Backspace then
            Binds.capturing = nil
            if action.protected then
                Binds.changed:Fire(id)
                Notify.push(action.label .. " cannot be unbound. Rebind it to another key instead.", "warn")
                return
            end
            Binds.set(id, "None")
            Notify.push(action.label .. " is now unbound.", "info")
            return
        end
        local text = Binds.fromInput(input)
        if not text then
            Notify.push("That input cannot be bound. Use a keyboard key, Mouse 2 or Mouse 3.", "warn")
            return
        end
        Binds.capturing = nil
        if text == Binds.map[id] then
            Binds.changed:Fire(id)
            return
        end
        local owner = Binds.ownerOf(text, id)
        if owner and Binds.byId[owner].protected then
            Binds.changed:Fire(id)
            Notify.push(Binds.display(text) .. " is the emergency stop key. Rebind emergency stop first.", "warn")
            return
        end
        local function apply()
            if owner then
                Binds.map[owner] = "None"
                Binds.changed:Fire(owner)
            end
            Binds.set(id, text)
            Notify.push(action.label .. " → " .. Binds.display(text), "ok")
        end
        if owner or action.protected then
            local lines = {}
            if action.protected then
                table.insert(lines, "Rebind the emergency stop to " .. Binds.display(text) .. "?")
            end
            if owner then
                table.insert(lines, Binds.display(text) .. " is bound to " .. Binds.byId[owner].label .. ". Reassigning leaves that action unbound.")
            end
            Binds.changed:Fire(id)
            UI.confirm("Confirm keybind", table.concat(lines, "\n"), "Reassign", apply)
        else
            apply()
        end
    end

    Binds.rebuild()

    V.BIND_MOUSE = BIND_MOUSE
    V.BIND_RESERVED = BIND_RESERVED
end
