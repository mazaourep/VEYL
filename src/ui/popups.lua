-- VEYL module: ui/popups
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Util = V.Util
    local Notify = V.Notify
    local Cap = V.Cap
    local Settings = V.Settings
    local UI = V.UI
    local Popup = V.Popup
    local Maid = V.Maid
    local T = V.T
    local make = V.make
    local corner = V.corner
    local stroke = V.stroke
    local padding = V.padding
    local vlist = V.vlist
    local text = V.text
    local isPress = V.isPress
    local styledButton = V.styledButton
    local safeCallback = V.safeCallback

    ----------------------------------------------------------------------------
    -- 9. Popups: dropdown, confirm, text viewer, color picker
    ----------------------------------------------------------------------------

    function Popup.isOpen()
        return Popup.maid ~= nil
    end

    function Popup.close()
        local maid = Popup.maid
        Popup.maid = nil
        if maid then
            maid:clean()
        end
    end

    function Popup.open(size, anchor, modal)
        Popup.close()
        local layer = UI.popupLayer
        local maid = Maid.new()
        Popup.maid = maid
        local blocker = make("TextButton", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = modal and 0.55 or 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
        }, layer)
        maid:give(blocker)
        maid:connect(blocker.Activated, function()
            Popup.close()
        end)
        local frame = make("Frame", {
            BackgroundColor3 = T.raised,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(size.X, size.Y),
            Active = true,
        }, layer)
        corner(frame, 6)
        stroke(frame, T.line)
        maid:give(frame)
        local layerPosition, screen = layer.AbsolutePosition, layer.AbsoluteSize
        local x, y
        if anchor then
            local anchorPosition, anchorSize = anchor.AbsolutePosition - layerPosition, anchor.AbsoluteSize
            x = anchorPosition.X + anchorSize.X - size.X
            y = anchorPosition.Y + anchorSize.Y + 4
            if y + size.Y > screen.Y - 4 then
                y = anchorPosition.Y - size.Y - 4
            end
        else
            x = (screen.X - size.X) / 2
            y = (screen.Y - size.Y) / 2
        end
        x = math.clamp(x, 4, math.max(4, screen.X - size.X - 4))
        y = math.clamp(y, 4, math.max(4, screen.Y - size.Y - 4))
        frame.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
        maid:give(function()
            if UI.dragging and UI.dragging.owner == maid then
                UI.dragging = nil
            end
        end)
        return frame, maid
    end

    function Popup.select(anchor, options, current, onPick)
        local itemHeight = 22
        local visible = math.clamp(#options, 1, 8)
        local width = math.max(anchor.AbsoluteSize.X, 150)
        local frame, maid = Popup.open(Vector2.new(width, visible * itemHeight + 8), anchor, false)
        local scroll = make("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = T.line,
        }, frame)
        padding(scroll, 4, 4, 4, 4)
        vlist(scroll, 0)
        if #options == 0 then
            text(scroll, { Size = UDim2.new(1, 0, 0, itemHeight), Text = "No options available", TextColor3 = T.dim, TextSize = 11 })
        end
        for index, option in ipairs(options) do
            local selected = option == current
            local button = make("TextButton", {
                BackgroundColor3 = selected and T.accent or T.hover,
                BackgroundTransparency = selected and 0.2 or 1,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, itemHeight),
                Font = selected and T.fontMedium or T.font,
                Text = "  " .. tostring(option),
                TextColor3 = T.text,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = index,
            }, scroll)
            corner(button, 3)
            maid:connect(button.MouseEnter, function()
                if not selected then
                    button.BackgroundTransparency = 0.3
                end
            end)
            maid:connect(button.MouseLeave, function()
                if not selected then
                    button.BackgroundTransparency = 1
                end
            end)
            maid:connect(button.Activated, function()
                Popup.close()
                onPick(option)
            end)
        end
    end

    function UI.confirm(title, message, confirmText, onConfirm, onCancel)
        local frame, maid = Popup.open(Vector2.new(340, 150), nil, true)
        padding(frame, 12, 12, 10, 10)
        text(frame, { Size = UDim2.new(1, 0, 0, 18), Text = title, Font = T.fontBold, TextSize = 13 })
        text(frame, {
            Position = UDim2.fromOffset(0, 24),
            Size = UDim2.new(1, 0, 1, -56),
            Text = message,
            TextColor3 = T.muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
        local decided = false
        local cancel = styledButton(frame, "Cancel", "default", maid)
        cancel.AnchorPoint = Vector2.new(1, 1)
        cancel.Position = UDim2.new(1, -104, 1, 0)
        cancel.Size = UDim2.fromOffset(96, 24)
        local accept = styledButton(frame, confirmText or "Confirm", "primary", maid)
        accept.AnchorPoint = Vector2.new(1, 1)
        accept.Position = UDim2.fromScale(1, 1)
        accept.Size = UDim2.fromOffset(96, 24)
        maid:connect(cancel.Activated, function()
            Popup.close()
        end)
        maid:connect(accept.Activated, function()
            decided = true
            Popup.close()
            safeCallback(onConfirm, title)
        end)
        maid:give(function()
            if not decided and onCancel then
                safeCallback(onCancel, title)
            end
        end)
    end

    function Popup.textViewer(title, body)
        local frame, maid = Popup.open(Vector2.new(440, 280), nil, true)
        padding(frame, 10, 10, 8, 10)
        text(frame, { Size = UDim2.new(1, -30, 0, 18), Text = title, Font = T.fontBold, TextSize = 13 })
        text(frame, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 16), Text = "Clipboard API unavailable — select the text and press Ctrl+C.", TextColor3 = T.muted, TextSize = 11 })
        local close = styledButton(frame, "×", "default", maid)
        close.AnchorPoint = Vector2.new(1, 0)
        close.Position = UDim2.fromScale(1, 0)
        close.Size = UDim2.fromOffset(22, 18)
        maid:connect(close.Activated, function()
            Popup.close()
        end)
        local scroll = make("ScrollingFrame", {
            BackgroundColor3 = T.field,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 40),
            Size = UDim2.new(1, 0, 1, -40),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4,
        }, frame)
        corner(scroll, 4)
        local box = make("TextBox", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ClearTextOnFocus = false,
            MultiLine = true,
            TextEditable = true,
            Font = T.mono,
            Text = body,
            TextColor3 = T.text,
            TextSize = 11,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, scroll)
        padding(box, 6, 6, 6, 6)
        return frame, maid
    end

    -- Copies text through the clipboard API, or shows a selectable viewer as fallback.
    function UI.copy(title, body)
        if Cap.copy(body) then
            Notify.push(title .. " copied to the clipboard.", "ok")
        else
            Popup.textViewer(title, body)
        end
    end

    function Popup.colorPicker(anchor, key, labelText)
        local frame, maid = Popup.open(Vector2.new(252, 216), anchor, false)
        local hue, saturation, value = Settings.get(key):ToHSV()
        local internal = false

        text(frame, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(200, 16), Text = labelText, Font = T.fontBold })
        local close = styledButton(frame, "×", "default", maid)
        close.Position = UDim2.fromOffset(226, 5)
        close.Size = UDim2.fromOffset(20, 18)
        maid:connect(close.Activated, function()
            Popup.close()
        end)

        local field = make("TextButton", { Position = UDim2.fromOffset(8, 28), Size = UDim2.fromOffset(160, 124), BorderSizePixel = 0, Text = "", AutoButtonColor = false }, frame)
        local whiteLayer = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, field)
        make("UIGradient", { Transparency = NumberSequence.new(0, 1) }, whiteLayer)
        local blackLayer = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, field)
        make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, blackLayer)
        local fieldCursor = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundTransparency = 1 }, field)
        corner(fieldCursor, 5)
        stroke(fieldCursor, Color3.new(1, 1, 1), 0, 2)

        local hueKeys = {}
        for index = 0, 6 do
            table.insert(hueKeys, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV((index % 6) / 6, 1, 1)))
        end
        local hueBar = make("TextButton", { Position = UDim2.fromOffset(174, 28), Size = UDim2.fromOffset(14, 124), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Text = "", AutoButtonColor = false }, frame)
        make("UIGradient", { Rotation = 90, Color = ColorSequence.new(hueKeys) }, hueBar)
        local hueCursor = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, hueBar)
        stroke(hueCursor, Color3.new(0, 0, 0), 0.2)

        local newSwatch = make("Frame", { Position = UDim2.fromOffset(196, 28), Size = UDim2.fromOffset(48, 44), BorderSizePixel = 0 }, frame)
        corner(newSwatch, 4)
        local original = Settings.get(key)
        local oldSwatch = make("TextButton", { Position = UDim2.fromOffset(196, 76), Size = UDim2.fromOffset(48, 30), BackgroundColor3 = original, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, frame)
        corner(oldSwatch, 4)
        text(frame, { Position = UDim2.fromOffset(196, 108), Size = UDim2.fromOffset(48, 14), Text = "new / old", TextSize = 9, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center })

        local function field3(x, width, placeholder)
            local box = make("TextBox", {
                Position = UDim2.fromOffset(x, 160),
                Size = UDim2.fromOffset(width, 20),
                BackgroundColor3 = T.field,
                BorderSizePixel = 0,
                ClearTextOnFocus = false,
                Font = T.mono,
                PlaceholderText = placeholder,
                PlaceholderColor3 = T.dim,
                Text = "",
                TextColor3 = T.text,
                TextSize = 11,
            }, frame)
            corner(box, 3)
            return box, stroke(box, T.lineSoft)
        end
        local redBox, redStroke = field3(8, 38, "R")
        local greenBox, greenStroke = field3(50, 38, "G")
        local blueBox, blueStroke = field3(92, 38, "B")
        local hexBox, hexStroke = field3(134, 110, "#RRGGBB")

        local function render()
            local current = Settings.get(key)
            field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
            fieldCursor.Position = UDim2.fromScale(saturation, 1 - value)
            hueCursor.Position = UDim2.new(0.5, 0, hue, 0)
            newSwatch.BackgroundColor3 = current
            local channels = {
                { redBox, current.R },
                { greenBox, current.G },
                { blueBox, current.B },
            }
            for _, pair in ipairs(channels) do
                if not pair[1]:IsFocused() then
                    pair[1].Text = tostring(math.floor(pair[2] * 255 + 0.5))
                end
            end
            if not hexBox:IsFocused() then
                hexBox.Text = Util.toHex(current)
            end
        end

        local function syncFromColor(color)
            local h, s, v = color:ToHSV()
            if v > 0 then
                saturation = s
                if s > 0 then
                    hue = h
                end
            end
            value = v
        end

        local function commitHsv()
            internal = true
            Settings.set(key, Color3.fromHSV(hue, saturation, value))
            internal = false
            render()
        end

        local function commitColor(color)
            syncFromColor(color)
            internal = true
            Settings.set(key, color)
            internal = false
            render()
        end

        maid:give(Settings.on(key, function(color)
            if not internal then
                syncFromColor(color)
                render()
            end
        end))

        maid:connect(field.InputBegan, function(input)
            if not isPress(input) then
                return
            end
            local function update(position)
                if not field.Parent then
                    return
                end
                local origin, size = field.AbsolutePosition, field.AbsoluteSize
                saturation = math.clamp((position.X - origin.X) / math.max(size.X, 1), 0, 1)
                value = 1 - math.clamp((position.Y - origin.Y) / math.max(size.Y, 1), 0, 1)
                commitHsv()
            end
            UI.dragging = { owner = maid, update = update }
            update(input.Position)
        end)
        maid:connect(hueBar.InputBegan, function(input)
            if not isPress(input) then
                return
            end
            local function update(position)
                if not hueBar.Parent then
                    return
                end
                hue = math.clamp((position.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 0.999)
                commitHsv()
            end
            UI.dragging = { owner = maid, update = update }
            update(input.Position)
        end)
        maid:connect(oldSwatch.Activated, function()
            commitColor(original)
        end)

        local function rgbHandler(box, boxStroke, channel)
            maid:connect(box.FocusLost, function()
                local number = tonumber(Util.trim(box.Text))
                if not number or number ~= math.floor(number) or number < 0 or number > 255 then
                    UI.flashError(boxStroke)
                    Notify.push(channel .. " must be a whole number from 0 to 255.", "warn")
                    render()
                    return
                end
                local current = Settings.get(key)
                local r, g, b = math.floor(current.R * 255 + 0.5), math.floor(current.G * 255 + 0.5), math.floor(current.B * 255 + 0.5)
                if channel == "Red" then
                    r = number
                elseif channel == "Green" then
                    g = number
                else
                    b = number
                end
                commitColor(Color3.fromRGB(r, g, b))
            end)
        end
        rgbHandler(redBox, redStroke, "Red")
        rgbHandler(greenBox, greenStroke, "Green")
        rgbHandler(blueBox, blueStroke, "Blue")
        maid:connect(hexBox.FocusLost, function()
            local color = Util.fromHex(hexBox.Text)
            if not color then
                UI.flashError(hexStroke)
                Notify.push("HEX must be #RRGGBB or RRGGBB (0-9, A-F).", "warn")
                render()
                return
            end
            commitColor(color)
        end)

        local function action(label, x, style, callback)
            local button = styledButton(frame, label, style, maid)
            button.Position = UDim2.fromOffset(x, 188)
            button.Size = UDim2.fromOffset(76, 20)
            maid:connect(button.Activated, callback)
        end
        action("Reset", 8, "default", function()
            Settings.reset(key)
        end)
        action("Copy HEX", 88, "default", function()
            local hex = Util.toHex(Settings.get(key))
            if Cap.copy(hex) then
                Notify.push("Copied " .. hex .. ".", "ok")
            else
                hexBox:CaptureFocus()
                hexBox.SelectionStart = 1
                hexBox.CursorPosition = #hexBox.Text + 1
                Notify.push("Clipboard unavailable. The HEX value is selected; press Ctrl+C.", "info")
            end
        end)
        action("Done", 168, "primary", function()
            Popup.close()
        end)
        render()
    end
end
