-- VEYL module: ui/controls
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Util = V.Util
    local Log = V.Log
    local Notify = V.Notify
    local Settings = V.Settings
    local Binds = V.Binds
    local UI = V.UI
    local Popup = V.Popup
    local Maid = V.Maid
    local Root = V.Root
    local T = V.T
    local make = V.make
    local corner = V.corner
    local stroke = V.stroke
    local padding = V.padding
    local vlist = V.vlist
    local text = V.text
    local isPress = V.isPress


    -- Rows and controls ---------------------------------------------------------

    local function resetFromRow(record, options)
        if not options.key or record.enabled == false then
            return
        end
        local now = os.clock()
        if record.lastReset and now - record.lastReset < 0.2 then
            return
        end
        record.lastReset = now
        Settings.reset(options.key)
        Notify.push((options.label or options.key) .. " reset to default.", "info")
    end

    function UI.row(section, height, options, maid)
        maid = maid or Root
        local row = make("Frame", {
            Name = "Row",
            BackgroundColor3 = T.hover,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, height),
            LayoutOrder = section.nextOrder(),
        }, section.frame)
        corner(row, 4)
        local record = {
            frame = row,
            section = section,
            enabled = true,
            text = string.lower((options.label or "") .. " " .. (options.desc or "") .. " " .. (options.search or "")),
        }
        table.insert(section.rows, record)
        maid:connect(row.MouseEnter, function()
            row.BackgroundTransparency = 0.6
            UI.setHint(record.disabledReason or options.desc or options.label)
        end)
        maid:connect(row.MouseLeave, function()
            row.BackgroundTransparency = 1
            UI.setHint(nil)
        end)
        if options.key then
            maid:connect(row.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    resetFromRow(record, options)
                end
            end)
        end
        return row, record
    end

    local function rowLabel(row, label, rightInset, height)
        return text(row, {
            Position = UDim2.fromOffset(4, 0),
            Size = UDim2.new(1, -(rightInset or 0) - 8, 0, height or row.Size.Y.Offset),
            Text = label,
        })
    end

    local function makeControl(row, record)
        local control = { row = row, record = record }
        local blocker
        function control.setEnabled(enabled, reason)
            record.enabled = enabled
            record.disabledReason = (not enabled) and reason or nil
            if not enabled and not blocker then
                blocker = make("TextButton", {
                    BackgroundColor3 = T.panel,
                    BackgroundTransparency = 0.35,
                    BorderSizePixel = 0,
                    Size = UDim2.fromScale(1, 1),
                    Text = "",
                    AutoButtonColor = false,
                }, row)
            end
            if blocker then
                blocker.Visible = not enabled
            end
        end
        return control
    end

    function UI.toggle(section, options, maid)
        maid = maid or Root
        local row, record = UI.row(section, 22, options, maid)
        rowLabel(row, options.label, 40)
        local button = make("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false }, row)
        local track = make("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.fromOffset(30, 16),
            BackgroundColor3 = T.line,
            BorderSizePixel = 0,
        }, row)
        corner(track, 8)
        local knob = make("Frame", { Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.text, BorderSizePixel = 0 }, track)
        corner(knob, 6)
        local function render(value)
            track.BackgroundColor3 = value and T.accent or T.line
            knob.Position = value and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        end
        render(Settings.get(options.key))
        maid:give(Settings.on(options.key, render))
        maid:connect(button.Activated, function()
            if record.enabled ~= false then
                Settings.set(options.key, not Settings.get(options.key))
            end
        end)
        maid:connect(button.MouseButton2Click, function()
            resetFromRow(record, options)
        end)
        return makeControl(row, record)
    end

    function UI.slider(section, options, maid)
        maid = maid or Root
        local spec = Settings.schema[options.key]
        local decimals = Util.decimalsForStep(spec.step)
        local suffix = options.suffix or ""
        local row, record = UI.row(section, 34, options, maid)
        rowLabel(row, options.label, 72, 16)
        local box = make("TextBox", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -2, 0, 0),
            Size = UDim2.fromOffset(66, 16),
            BackgroundColor3 = T.field,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = T.fontMedium,
            Text = "",
            TextColor3 = T.text,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
        }, row)
        corner(box, 3)
        padding(box, 4, 4, 0, 0)
        local boxStroke = stroke(box, T.lineSoft)
        local track = make("TextButton", {
            Position = UDim2.new(0, 4, 0, 23),
            Size = UDim2.new(1, -10, 0, 6),
            BackgroundColor3 = T.line,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, row)
        corner(track, 3)
        local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, BorderSizePixel = 0 }, track)
        corner(fill, 3)
        local knob = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(10, 10),
            BackgroundColor3 = T.text,
            BorderSizePixel = 0,
        }, track)
        corner(knob, 5)
        local function render(value)
            local fraction = math.clamp((value - spec.min) / math.max(spec.max - spec.min, 1e-6), 0, 1)
            fill.Size = UDim2.fromScale(fraction, 1)
            knob.Position = UDim2.fromScale(fraction, 0.5)
            if not box:IsFocused() then
                box.Text = Util.formatNumber(value, decimals) .. suffix
            end
        end
        render(Settings.get(options.key))
        maid:give(Settings.on(options.key, render))
        local function setFromX(x)
            local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            Settings.set(options.key, spec.min + fraction * (spec.max - spec.min))
        end
        maid:connect(track.InputBegan, function(input)
            if record.enabled == false or not isPress(input) then
                return
            end
            UI.dragging = {
                update = function(position)
                    if track.Parent then
                        setFromX(position.X)
                    end
                end,
            }
            setFromX(input.Position.X)
        end)
        maid:connect(track.MouseButton2Click, function()
            resetFromRow(record, options)
        end)
        maid:connect(box.FocusLost, function()
            if record.enabled == false then
                render(Settings.get(options.key))
                return
            end
            local raw = string.gsub(box.Text, "[^%d%.%-]", "")
            local entered = tonumber(raw)
            if not entered then
                UI.flashError(boxStroke)
                Notify.push(string.format("%s: enter a number from %s to %s.", options.label, Util.formatNumber(spec.min, decimals), Util.formatNumber(spec.max, decimals)), "warn")
            else
                local ok, normalized = Settings.set(options.key, entered)
                if ok and math.abs(normalized - entered) > 1e-6 then
                    Notify.push(string.format("%s set to %s%s (allowed %s–%s, step %s).", options.label, Util.formatNumber(normalized, decimals), suffix, Util.formatNumber(spec.min, decimals), Util.formatNumber(spec.max, decimals), tostring(spec.step)), "info")
                end
            end
            render(Settings.get(options.key))
        end)
        return makeControl(row, record)
    end

    local function fieldButton(parent, width, maid)
        local button = make("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -2, 0.5, 0),
            Size = UDim2.fromOffset(width, 20),
            BackgroundColor3 = T.field,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
        }, parent)
        corner(button, 4)
        local buttonStroke = stroke(button, T.lineSoft)
        maid:connect(button.MouseEnter, function()
            buttonStroke.Color = T.line
        end)
        maid:connect(button.MouseLeave, function()
            buttonStroke.Color = T.lineSoft
        end)
        return button
    end

    function UI.dropdown(section, options, maid)
        maid = maid or Root
        local spec = options.key and Settings.schema[options.key]
        local getOptions = options.options or function()
            return spec.options
        end
        local getValue = options.get or function()
            return Settings.get(options.key)
        end
        local setValue = options.set or function(value)
            Settings.set(options.key, value)
        end
        local row, record = UI.row(section, 22, options, maid)
        local width = options.width or 136
        rowLabel(row, options.label, width + 6)
        local button = fieldButton(row, width, maid)
        local valueLabel = text(button, { Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -24, 1, 0), TextSize = 11, Text = "" })
        text(button, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.fromOffset(10, 20), Text = "▾", TextColor3 = T.muted, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right })
        local function render()
            local value = getValue()
            local valid = table.find(getOptions(), value) ~= nil
            valueLabel.Text = tostring(value) .. (valid and "" or " (unavailable)")
            valueLabel.TextColor3 = valid and T.text or T.warn
        end
        render()
        if options.key then
            maid:give(Settings.on(options.key, render))
        end
        maid:connect(button.Activated, function()
            if record.enabled ~= false then
                Popup.select(button, getOptions(), getValue(), function(value)
                    setValue(value)
                    render()
                end)
            end
        end)
        maid:connect(button.MouseButton2Click, function()
            resetFromRow(record, options)
        end)
        local control = makeControl(row, record)
        control.refresh = render
        return control
    end

    function UI.color(section, options, maid)
        maid = maid or Root
        local row, record = UI.row(section, 22, options, maid)
        rowLabel(row, options.label, 110)
        local hex = text(row, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -40, 0, 0),
            Size = UDim2.fromOffset(64, 22),
            Font = T.mono,
            TextSize = 11,
            TextColor3 = T.muted,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        local swatch = make("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.fromOffset(30, 14),
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, row)
        corner(swatch, 3)
        stroke(swatch, T.line)
        local function render(color)
            swatch.BackgroundColor3 = color
            hex.Text = Util.toHex(color)
        end
        render(Settings.get(options.key))
        maid:give(Settings.on(options.key, render))
        local opener = make("TextButton", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 110, 1, 0), Text = "", AutoButtonColor = false }, row)
        maid:connect(opener.Activated, function()
            if record.enabled ~= false then
                Popup.colorPicker(swatch, options.key, options.label)
            end
        end)
        maid:connect(opener.MouseButton2Click, function()
            resetFromRow(record, options)
        end)
        return makeControl(row, record)
    end

    function UI.keybind(section, actionId, maid)
        maid = maid or Root
        local action = Binds.byId[actionId]
        local options = {
            label = action.label,
            desc = action.protected and "Click, then press a key. Changing the emergency stop asks for confirmation." or "Click, then press a key or Mouse 2/3. Esc cancels, Backspace unbinds.",
        }
        local row, record = UI.row(section, 22, options, maid)
        rowLabel(row, action.label .. (action.protected and "  ⚑" or ""), 146)
        local button = fieldButton(row, 112, maid)
        button.Position = UDim2.new(1, -28, 0.5, 0)
        local valueLabel = text(button, { Size = UDim2.fromScale(1, 1), TextSize = 11, Font = T.fontMedium, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
        local reset = make("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -2, 0.5, 0),
            Size = UDim2.fromOffset(22, 20),
            BackgroundColor3 = T.raised,
            BorderSizePixel = 0,
            Text = "↺",
            Font = T.fontBold,
            TextSize = 12,
            TextColor3 = T.muted,
        }, row)
        corner(reset, 4)
        local function render()
            if Binds.capturing and Binds.capturing.id == actionId then
                valueLabel.Text = "Press a key…"
                valueLabel.TextColor3 = T.accent
            else
                local bound = Binds.map[actionId]
                valueLabel.Text = Binds.display(bound)
                valueLabel.TextColor3 = bound == "None" and T.dim or T.text
            end
        end
        render()
        maid:give(Binds.changed:Connect(function(id)
            if id == actionId then
                render()
            end
        end))
        maid:connect(button.Activated, function()
            Binds.beginCapture(actionId)
            UI.setHint("Press a key or Mouse 2/3 · Esc cancels · Backspace unbinds")
        end)
        maid:connect(reset.Activated, function()
            Binds.cancelCapture()
            Binds.reset(actionId)
            Notify.push(action.label .. " reset to " .. Binds.display(action.default) .. ".", "info")
        end)
        return makeControl(row, record)
    end

    local BUTTON_STYLES = {
        default = { T.raised, T.hover, T.text },
        primary = { T.accent, T.accentHover, Color3.new(1, 1, 1) },
        danger = { T.badDim, T.badHover, Color3.fromRGB(255, 220, 225) },
    }

    local function styledButton(parent, label, style, maid)
        local colors = BUTTON_STYLES[style or "default"]
        local button = make("TextButton", {
            BackgroundColor3 = colors[1],
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = T.fontMedium,
            Text = label,
            TextColor3 = colors[3],
            TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, parent)
        corner(button, 4)
        maid:connect(button.MouseEnter, function()
            button.BackgroundColor3 = colors[2]
        end)
        maid:connect(button.MouseLeave, function()
            button.BackgroundColor3 = colors[1]
        end)
        return button
    end
    UI.styledButton = styledButton

    local function safeCallback(callback, label)
        local ok, err = pcall(callback)
        if not ok then
            Notify.push((label or "Action") .. " failed: " .. tostring(err), "error")
        end
    end

    function UI.button(section, options, maid)
        maid = maid or Root
        local row, record = UI.row(section, 24, { label = options.text, desc = options.desc, search = options.search }, maid)
        local button = styledButton(row, options.text, options.style, maid)
        button.Size = UDim2.fromScale(1, 1)
        maid:connect(button.Activated, function()
            if record.enabled ~= false then
                safeCallback(options.callback, options.text)
            end
        end)
        local control = makeControl(row, record)
        control.button = button
        return control
    end

    function UI.buttons(section, list, desc, maid)
        maid = maid or Root
        local labels = {}
        for _, item in ipairs(list) do
            table.insert(labels, item.text)
        end
        local row, record = UI.row(section, 24, { label = table.concat(labels, " "), desc = desc }, maid)
        make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
        local buttons = {}
        local count = #list
        for index, item in ipairs(list) do
            local button = styledButton(row, item.text, item.style, maid)
            button.LayoutOrder = index
            button.Size = UDim2.new(1 / count, -math.ceil(4 * (count - 1) / count), 1, 0)
            maid:connect(button.Activated, function()
                if record.enabled ~= false then
                    safeCallback(item.callback, item.text)
                end
            end)
            buttons[index] = button
        end
        local control = makeControl(row, record)
        control.buttons = buttons
        return control
    end

    function UI.info(section, options, maid)
        maid = maid or Root
        local row, record = UI.row(section, 20, options, maid)
        text(row, { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0.42, -4, 1, 0), Text = options.label, TextColor3 = T.muted, TextSize = 11 })
        local value = text(row, {
            Position = UDim2.fromScale(0.42, 0),
            Size = UDim2.new(0.58, -4, 1, 0),
            Text = options.value or "—",
            TextSize = 11,
            Font = T.fontMedium,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        local control = makeControl(row, record)
        function control.set(message, color)
            value.Text = message
            value.TextColor3 = color or T.text
        end
        return control
    end

    function UI.note(section, message, color, maid)
        maid = maid or Root
        local row, record = UI.row(section, 0, { label = message }, maid)
        row.AutomaticSize = Enum.AutomaticSize.Y
        local label = text(row, {
            Position = UDim2.fromOffset(4, 0),
            Size = UDim2.new(1, -8, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = message,
            TextColor3 = color or T.muted,
            TextSize = 11,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
        })
        padding(row, 0, 0, 2, 2)
        local control = makeControl(row, record)
        function control.set(newText, newColor)
            label.Text = newText
            if newColor then
                label.TextColor3 = newColor
            end
        end
        return control
    end

    function UI.input(section, options, maid)
        maid = maid or Root
        local row, record = UI.row(section, 24, options, maid)
        local buttonWidth = options.buttonWidth or 84
        local box = make("TextBox", {
            Size = UDim2.new(1, -(buttonWidth + 4), 1, 0),
            BackgroundColor3 = T.field,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = T.font,
            PlaceholderColor3 = T.dim,
            PlaceholderText = options.placeholder or "",
            Text = "",
            TextColor3 = T.text,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
        corner(box, 4)
        padding(box, 7, 7, 0, 0)
        local boxStroke = stroke(box, T.lineSoft)
        local button = styledButton(row, options.buttonText or "Apply", "primary", maid)
        button.AnchorPoint = Vector2.new(1, 0)
        button.Position = UDim2.fromScale(1, 0)
        button.Size = UDim2.new(0, buttonWidth, 1, 0)
        local function submit()
            if record.enabled == false then
                return
            end
            local ok, result = pcall(options.onSubmit, box.Text)
            if not ok then
                Notify.push("Input failed: " .. tostring(result), "error")
            elseif result then
                box.Text = ""
            else
                UI.flashError(boxStroke)
            end
        end
        maid:connect(button.Activated, submit)
        maid:connect(box.FocusLost, function(enterPressed)
            if enterPressed then
                submit()
            end
        end)
        local control = makeControl(row, record)
        control.box = box
        return control
    end

    -- Search box that is not a settings row (used by list views).
    function UI.filterBox(section, placeholder, onChanged, maid)
        maid = maid or Root
        local row, record = UI.row(section, 22, { label = placeholder }, maid)
        local box = make("TextBox", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = T.field,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = T.font,
            PlaceholderColor3 = T.dim,
            PlaceholderText = placeholder,
            Text = "",
            TextColor3 = T.text,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        corner(box, 4)
        padding(box, 7, 7, 0, 0)
        stroke(box, T.lineSoft)
        maid:connect(box:GetPropertyChangedSignal("Text"), function()
            onChanged(string.lower(Util.trim(box.Text)))
        end)
        record.follow = true
        return box
    end

    -- Keyed list with per-row lifecycles; rows are updated in place, never rebuilt per frame.
    function UI.list(section, emptyText)
        local holder = make("Frame", {
            Name = "List",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = section.nextOrder(),
        }, section.frame)
        vlist(holder, 3)
        local empty = text(holder, {
            Size = UDim2.new(1, 0, 0, 22),
            Text = emptyText or "Nothing here yet.",
            TextColor3 = T.dim,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = -1,
        })
        table.insert(section.rows, { frame = holder, section = section, follow = true, text = "" })
        local list = { holder = holder, rows = {}, count = 0 }
        function list.add(key, height, build)
            local existing = list.rows[key]
            if existing then
                return existing
            end
            local maid = Maid.new()
            local frame = make("Frame", {
                BackgroundColor3 = T.raised,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, height),
            })
            corner(frame, 4)
            maid:give(frame)
            local entry = { frame = frame, maid = maid }
            local ok, updater = pcall(build, frame, maid)
            if not ok then
                maid:clean()
                Log.add("warn", "List row failed to build: " .. tostring(updater))
                return nil
            end
            entry.update = updater
            frame.Parent = holder
            list.rows[key] = entry
            list.count += 1
            empty.Visible = false
            return entry
        end
        function list.get(key)
            return list.rows[key]
        end
        function list.remove(key)
            local entry = list.rows[key]
            if entry then
                list.rows[key] = nil
                list.count -= 1
                entry.maid:clean()
            end
            empty.Visible = list.count == 0
        end
        function list.clear()
            for key in pairs(list.rows) do
                list.remove(key)
            end
            empty.Visible = true
        end
        function list.setEmpty(message)
            empty.Text = message
        end
        return list
    end

    V.resetFromRow = resetFromRow
    V.rowLabel = rowLabel
    V.makeControl = makeControl
    V.fieldButton = fieldButton
    V.BUTTON_STYLES = BUTTON_STYLES
    V.styledButton = styledButton
    V.safeCallback = safeCallback
end
