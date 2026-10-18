-- VEYL module: ui/window
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Lighting = V.Lighting
    local Workspace = V.Workspace
    local PlayerGui = V.PlayerGui
    local VERSION = V.VERSION
    local NAMES = V.NAMES
    local Util = V.Util
    local Log = V.Log
    local Notify = V.Notify
    local Cap = V.Cap
    local Settings = V.Settings
    local Binds = V.Binds
    local UI = V.UI
    local Popup = V.Popup
    local Music = V.Music
    local Session = V.Session
    local Root = V.Root

    ----------------------------------------------------------------------------
    -- 6. UI component builders
    ----------------------------------------------------------------------------

    local T = {
        bg = Color3.fromRGB(12, 15, 21),
        title = Color3.fromRGB(16, 20, 28),
        panel = Color3.fromRGB(18, 22, 31),
        raised = Color3.fromRGB(26, 31, 42),
        field = Color3.fromRGB(10, 13, 19),
        hover = Color3.fromRGB(34, 41, 56),
        line = Color3.fromRGB(44, 52, 68),
        lineSoft = Color3.fromRGB(31, 37, 50),
        text = Color3.fromRGB(226, 232, 242),
        muted = Color3.fromRGB(140, 151, 171),
        dim = Color3.fromRGB(96, 106, 124),
        accent = Color3.fromRGB(64, 156, 255),
        accentHover = Color3.fromRGB(92, 172, 255),
        cyan = Color3.fromRGB(56, 214, 230),
        ok = Color3.fromRGB(88, 214, 141),
        warn = Color3.fromRGB(255, 190, 92),
        bad = Color3.fromRGB(255, 99, 110),
        badDim = Color3.fromRGB(110, 38, 50),
        badHover = Color3.fromRGB(140, 48, 62),
        font = Enum.Font.Gotham,
        fontMedium = Enum.Font.GothamMedium,
        fontBold = Enum.Font.GothamBold,
        mono = Enum.Font.Code,
    }

    local STATUS_COLORS = { Available = T.ok, Fallback = T.warn, Unavailable = T.bad, Info = T.muted }

    local function make(className, properties, parent)
        local instance = Instance.new(className)
        if properties then
            for property, value in pairs(properties) do
                instance[property] = value
            end
        end
        if parent then
            instance.Parent = parent
        end
        return instance
    end

    local function corner(parent, radius)
        return make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
    end

    local function stroke(parent, color, transparency, thickness)
        return make("UIStroke", {
            Color = color or T.line,
            Transparency = transparency or 0,
            Thickness = thickness or 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, parent)
    end

    local function padding(parent, left, right, top, bottom)
        return make("UIPadding", {
            PaddingLeft = UDim.new(0, left or 0),
            PaddingRight = UDim.new(0, right or 0),
            PaddingTop = UDim.new(0, top or 0),
            PaddingBottom = UDim.new(0, bottom or 0),
        }, parent)
    end

    local function vlist(parent, gap)
        return make("UIListLayout", {
            Padding = UDim.new(0, gap or 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Vertical,
        }, parent)
    end

    local function text(parent, properties)
        local label = make("TextLabel", {
            BackgroundTransparency = 1,
            Font = T.font,
            TextColor3 = T.text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        for property, value in pairs(properties) do
            label[property] = value
        end
        label.Parent = parent
        return label
    end

    local function isPress(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
    end

    UI.pages = {}
    UI.pageOrder = {}
    UI.sections = {}
    UI.open = true
    UI.minimized = false
    UI.dragging = nil
    UI.MIN_SIZE = Vector2.new(560, 380)
    UI.DEFAULT_HINT = "Hover a control for details · right-click a setting to reset it"

    function UI.flashError(target)
        if not target then
            return
        end
        local original = T.lineSoft
        target.Color = T.bad
        task.delay(1.2, function()
            if target.Parent then
                target.Color = original
            end
        end)
    end

    function UI.setHint(message)
        if UI.hintLabel then
            UI.hintLabel.Text = message or UI.DEFAULT_HINT
        end
    end

    function UI.flashStatus(message, color, seconds)
        if UI.status then
            UI.status.Text = message
            UI.status.TextColor3 = color or T.muted
            UI.statusUntil = os.clock() + (seconds or 3)
        end
    end

    function UI.refreshStatus()
        if not UI.status or (UI.statusUntil and os.clock() < UI.statusUntil) then
            return
        end
        local parts = {}
        if Settings.get("aim.enabled") then
            table.insert(parts, "AIM")
        end
        if Settings.get("esp.enabled") then
            table.insert(parts, "ESP")
        end
        if Settings.get("world.enabled") then
            table.insert(parts, "WORLD")
        end
        if Music.isPlaying() then
            table.insert(parts, "♪")
        end
        UI.status.Text = #parts > 0 and ("● " .. table.concat(parts, " · ")) or "● Idle"
        UI.status.TextColor3 = #parts > 0 and T.cyan or T.muted
    end

    function UI.updateBlur()
        local wanted = Session.alive and UI.open and Settings.get("ui.blur")
        if wanted then
            if not UI.blur or not UI.blur.Parent then
                UI.blur = make("BlurEffect", { Name = NAMES.blur, Size = 8 })
                UI.blur:SetAttribute(NAMES.owned, true)
                UI.blur.Parent = Lighting
            end
        elseif UI.blur then
            UI.blur:Destroy()
            UI.blur = nil
        end
    end

    function UI.setOpen(open)
        UI.open = open
        if UI.window then
            UI.window.Visible = open
            UI.reopen.Visible = not open
        end
        if not open then
            Popup.close()
            Binds.cancelCapture()
            UI.dragging = nil
        end
        UI.updateBlur()
    end

    function UI.setMinimized(minimized)
        UI.minimized = minimized
        UI.tabBar.Visible = not minimized
        UI.body.Visible = not minimized
        UI.hintBar.Visible = not minimized
        UI.grip.Visible = not minimized
        UI.minimizeButton.Text = minimized and "▢" or "–"
        UI.window.Size = UDim2.fromOffset(UI.size.X, minimized and 32 or UI.size.Y)
        if minimized then
            Popup.close()
        end
        UI.clampWindow()
    end

    function UI.clampWindow()
        local window, gui = UI.window, UI.gui
        if not window or not gui then
            return
        end
        local screen = gui.AbsoluteSize
        local size = window.AbsoluteSize
        local position = window.Position
        window.Position = UDim2.fromOffset(
            math.clamp(position.X.Offset, 0, math.max(0, screen.X - size.X)),
            math.clamp(position.Y.Offset, 0, math.max(0, screen.Y - size.Y))
        )
    end

    function UI.setSize(width, height)
        local screen = UI.gui.AbsoluteSize
        local scale = UI.scale and UI.scale.Scale or 1
        local maxWidth = math.max(240, (screen.X - 8) / scale)
        local maxHeight = math.max(200, (screen.Y - 8) / scale)
        width = math.clamp(width, math.min(UI.MIN_SIZE.X, maxWidth), maxWidth)
        height = math.clamp(height, math.min(UI.MIN_SIZE.Y, maxHeight), maxHeight)
        UI.size = Vector2.new(math.floor(width), math.floor(height))
        UI.window.Size = UDim2.fromOffset(UI.size.X, UI.minimized and 32 or UI.size.Y)
        UI.clampWindow()
    end

    local function applyTranslucency()
        local on = Settings.get("ui.translucent")
        if UI.window then
            UI.window.BackgroundTransparency = on and 0.06 or 0
        end
        for _, section in ipairs(UI.sections) do
            if section.frame.Parent then
                section.frame.BackgroundTransparency = on and 0.15 or 0
            end
        end
    end

    function UI.build()
        local gui = make("ScreenGui", {
            Name = NAMES.gui,
            ResetOnSpawn = false,
            IgnoreGuiInset = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 100,
        })
        gui:SetAttribute(NAMES.owned, true)
        UI.gui = gui
        Root:give(gui)

        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local width = math.clamp(math.floor(viewport.X * 0.6), math.min(UI.MIN_SIZE.X, viewport.X - 16), 880)
        local height = math.clamp(math.floor(viewport.Y * 0.68), math.min(UI.MIN_SIZE.Y, viewport.Y - 60), 620)
        UI.size = Vector2.new(width, height)

        local window = make("Frame", {
            Name = "Window",
            BackgroundColor3 = T.bg,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(math.floor((viewport.X - width) / 2), math.floor((viewport.Y - height) / 2) - 18),
            Size = UDim2.fromOffset(width, height),
            ClipsDescendants = true,
            Active = true,
        }, gui)
        corner(window, 8)
        stroke(window, T.line)
        UI.window = window
        UI.scale = make("UIScale", { Scale = Settings.get("ui.scale") / 100 }, window)

        -- Title bar
        local titleBar = make("Frame", {
            Name = "TitleBar",
            BackgroundColor3 = T.title,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 32),
            Active = true,
        }, window)
        make("Frame", { BackgroundColor3 = T.lineSoft, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) }, titleBar)
        local mark = make("Frame", { BackgroundColor3 = T.accent, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(18, 18) }, titleBar)
        corner(mark, 4)
        make("UIGradient", { Rotation = 45, Color = ColorSequence.new(T.accent, T.cyan) }, mark)
        text(mark, { Size = UDim2.fromScale(1, 1), Text = "V", Font = T.fontBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center })
        text(titleBar, { Position = UDim2.fromOffset(34, 0), Size = UDim2.fromOffset(42, 32), Text = "VEYL", Font = T.fontBold, TextSize = 14 })
        text(titleBar, { Position = UDim2.fromOffset(76, 0), Size = UDim2.fromOffset(70, 32), Text = "Control", TextColor3 = T.muted, TextSize = 12 })

        local search = make("TextBox", {
            Name = "Search",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -214, 0.5, 0),
            Size = UDim2.fromOffset(150, 22),
            BackgroundColor3 = T.field,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = T.font,
            PlaceholderColor3 = T.dim,
            PlaceholderText = "Search this tab…",
            Text = "",
            TextColor3 = T.text,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, titleBar)
        corner(search, 4)
        stroke(search, T.lineSoft)
        padding(search, 7, 7, 0, 0)
        UI.search = search

        UI.status = text(titleBar, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -68, 0.5, 0),
            Size = UDim2.fromOffset(136, 20),
            Text = "● Idle",
            TextColor3 = T.muted,
            TextSize = 11,
            Font = T.fontMedium,
            TextXAlignment = Enum.TextXAlignment.Right,
        })

        local function titleButton(label, offset, color)
            local button = make("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, offset, 0.5, 0),
                Size = UDim2.fromOffset(24, 22),
                BackgroundColor3 = color,
                BorderSizePixel = 0,
                AutoButtonColor = true,
                Font = T.fontBold,
                Text = label,
                TextColor3 = T.text,
                TextSize = 13,
            }, titleBar)
            corner(button, 4)
            return button
        end
        UI.minimizeButton = titleButton("–", -38, T.raised)
        local closeButton = titleButton("×", -10, T.badDim)
        Root:connect(UI.minimizeButton.Activated, function()
            UI.setMinimized(not UI.minimized)
        end)
        Root:connect(closeButton.Activated, function()
            UI.setOpen(false)
            Notify.push("VEYL hidden. Press " .. Binds.display(Binds.map.toggleUI) .. " or the VEYL button to reopen.", "info")
        end)

        -- Tab bar
        local tabBar = make("ScrollingFrame", {
            Name = "Tabs",
            BackgroundColor3 = T.bg,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 32),
            Size = UDim2.new(1, 0, 0, 30),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.X,
            ScrollingDirection = Enum.ScrollingDirection.X,
            ScrollBarThickness = 0,
        }, window)
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2),
        }, tabBar)
        padding(tabBar, 6, 6, 0, 0)
        make("Frame", { BackgroundColor3 = T.lineSoft, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 61), Size = UDim2.new(1, 0, 0, 1) }, window)
        UI.tabBar = tabBar

        UI.body = make("Frame", {
            Name = "Body",
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 62),
            Size = UDim2.new(1, 0, 1, -84),
        }, window)

        -- Hint bar
        local hintBar = make("Frame", {
            Name = "HintBar",
            BackgroundColor3 = T.title,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 22),
        }, window)
        make("Frame", { BackgroundColor3 = T.lineSoft, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }, hintBar)
        UI.hintLabel = text(hintBar, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -120, 1, 0), Text = UI.DEFAULT_HINT, TextColor3 = T.muted, TextSize = 11 })
        text(hintBar, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 0), Size = UDim2.fromOffset(90, 22), Text = "v" .. VERSION, TextColor3 = T.dim, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right })
        UI.hintBar = hintBar

        local grip = make("TextButton", {
            Name = "ResizeGrip",
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.fromScale(1, 1),
            Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1,
            Text = "◢",
            TextColor3 = T.dim,
            TextSize = 11,
            Font = T.font,
            AutoButtonColor = false,
        }, window)
        UI.grip = grip

        -- Popup layer, toast stack and reopen button live outside the window.
        UI.popupLayer = make("Frame", { Name = "Popups", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
        UI.toastHolder = make("Frame", {
            Name = "Toasts",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -12, 1, -12),
            Size = UDim2.fromOffset(300, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, gui)
        make("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
        }, UI.toastHolder)
        UI.reopen = make("TextButton", {
            Name = "Reopen",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 6),
            Size = UDim2.fromOffset(96, 24),
            BackgroundColor3 = T.title,
            BorderSizePixel = 0,
            Font = T.fontBold,
            Text = "VEYL  ▸",
            TextColor3 = T.text,
            TextSize = 12,
            Visible = false,
        }, gui)
        corner(UI.reopen, 6)
        stroke(UI.reopen, T.accent, 0.3)
        Root:connect(UI.reopen.Activated, function()
            UI.setOpen(true)
        end)

        -- Dragging and resizing share one pointer pipeline (see the input router).
        Root:connect(titleBar.InputBegan, function(input)
            if not isPress(input) then
                return
            end
            local x = input.Position.X
            local searchLeft = search.AbsolutePosition.X
            if x >= searchLeft - 4 or search:IsFocused() then
                return
            end
            local start = input.Position
            local origin = window.Position
            UI.dragging = {
                update = function(position)
                    window.Position = UDim2.fromOffset(origin.X.Offset + position.X - start.X, origin.Y.Offset + position.Y - start.Y)
                    UI.clampWindow()
                end,
            }
        end)
        Root:connect(grip.InputBegan, function(input)
            if not isPress(input) then
                return
            end
            local start = input.Position
            local startSize = UI.size
            UI.dragging = {
                update = function(position)
                    local scale = UI.scale.Scale
                    UI.setSize(startSize.X + (position.X - start.X) / scale, startSize.Y + (position.Y - start.Y) / scale)
                end,
            }
        end)
        Root:connect(gui:GetPropertyChangedSignal("AbsoluteSize"), function()
            UI.setSize(UI.size.X, UI.size.Y)
        end)
        Root:connect(search:GetPropertyChangedSignal("Text"), function()
            UI.applySearch()
        end)
        Root:give(Settings.on("ui.scale", function(value)
            UI.scale.Scale = value / 100
            UI.setSize(UI.size.X, UI.size.Y)
        end))
        Root:give(Settings.on("ui.translucent", applyTranslucency))
        Root:give(Settings.on("ui.blur", UI.updateBlur))

        UI.parentKind = "PlayerGui"
        if Cap.hui then
            local ok = pcall(function()
                gui.Parent = Cap.hui
            end)
            if ok and gui.Parent == Cap.hui then
                UI.parentKind = "gethui"
            end
        end
        if UI.parentKind ~= "gethui" then
            gui.Parent = PlayerGui
        end
        applyTranslucency()
        UI.clampWindow()
    end

    -- Pages and sections -------------------------------------------------------

    function UI.page(name)
        local scroll = make("ScrollingFrame", {
            Name = string.gsub(name, "%s+", "") .. "Page",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = T.line,
            VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
            Visible = false,
        }, UI.body)
        padding(scroll, 8, 8, 8, 8)
        local columns = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y }, scroll)
        local left = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, columns)
        vlist(left, 8)
        local right = make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, columns)
        vlist(right, 8)

        local tab = make("TextButton", {
            Name = string.gsub(name, "%s+", "") .. "Tab",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(0, 1),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = #UI.pageOrder + 1,
        }, UI.tabBar)
        padding(tab, 10, 10, 0, 0)
        local tabLabel = text(tab, {
            Size = UDim2.fromScale(0, 1),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = name,
            Font = T.fontMedium,
            TextColor3 = T.muted,
            TextTruncate = Enum.TextTruncate.None,
        })
        local underline = make("Frame", {
            BackgroundColor3 = T.accent,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, -4, 1, 0),
            Size = UDim2.new(1, 8, 0, 2),
            Visible = false,
        }, tab)
        local page = { name = name, scroll = scroll, left = left, right = right, sections = {}, tabLabel = tabLabel, underline = underline }
        UI.pages[name] = page
        table.insert(UI.pageOrder, name)
        Root:connect(tab.Activated, function()
            UI.select(name)
        end)
        Root:connect(tab.MouseEnter, function()
            if UI.current ~= name then
                tabLabel.TextColor3 = T.text
            end
        end)
        Root:connect(tab.MouseLeave, function()
            if UI.current ~= name then
                tabLabel.TextColor3 = T.muted
            end
        end)
        return page
    end

    function UI.select(name)
        local page = UI.pages[name]
        if not page then
            return
        end
        Popup.close()
        UI.current = name
        for _, otherName in ipairs(UI.pageOrder) do
            local other = UI.pages[otherName]
            local active = otherName == name
            other.scroll.Visible = active
            other.tabLabel.TextColor3 = active and T.text or T.muted
            other.underline.Visible = active
        end
        if UI.search.Text ~= "" then
            UI.search.Text = ""
        else
            UI.applySearch()
        end
        if page.onShow then
            local ok, err = pcall(page.onShow)
            if not ok then
                Log.add("warn", name .. " tab refresh failed: " .. tostring(err))
            end
        end
        UI.updatePage(true)
    end

    function UI.updatePage(force)
        if not UI.open or UI.minimized then
            return
        end
        local page = UI.pages[UI.current]
        if page and page.onUpdate then
            local now = os.clock()
            if force or now - (page.lastUpdate or 0) >= (page.updateInterval or 0.25) then
                page.lastUpdate = now
                local ok, err = pcall(page.onUpdate)
                if not ok and not page.updateFailed then
                    page.updateFailed = true
                    Log.add("warn", page.name .. " tab update failed: " .. tostring(err))
                end
            end
        end
    end

    function UI.applySearch()
        local page = UI.pages[UI.current]
        if not page then
            return
        end
        local query = string.lower(Util.trim(UI.search.Text))
        for _, section in ipairs(page.sections) do
            local titleMatch = query == "" or string.find(string.lower(section.title), query, 1, true) ~= nil
            local any = false
            for _, record in ipairs(section.rows) do
                if not record.follow then
                    local match = titleMatch or string.find(record.text, query, 1, true) ~= nil
                    record.frame.Visible = match
                    any = any or match
                end
            end
            local visible = titleMatch or any
            for _, record in ipairs(section.rows) do
                if record.follow then
                    record.frame.Visible = visible
                end
            end
            section.frame.Visible = visible
        end
    end

    function UI.section(page, column, title)
        local parent = column == "right" and page.right or page.left
        local frame = make("Frame", {
            Name = string.gsub(title, "%W", "") .. "Section",
            BackgroundColor3 = T.panel,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = #page.sections + 1,
        }, parent)
        corner(frame, 6)
        stroke(frame, T.lineSoft)
        padding(frame, 8, 8, 6, 8)
        vlist(frame, 3)
        text(frame, {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, 18),
            Text = string.upper(title),
            Font = T.fontBold,
            TextSize = 11,
            TextColor3 = T.muted,
            LayoutOrder = 0,
        })
        local section = { frame = frame, title = title, rows = {}, order = 0, page = page }
        function section.nextOrder()
            section.order += 1
            return section.order
        end
        table.insert(page.sections, section)
        table.insert(UI.sections, section)
        return section
    end

    V.T = T
    V.STATUS_COLORS = STATUS_COLORS
    V.make = make
    V.corner = corner
    V.stroke = stroke
    V.padding = padding
    V.vlist = vlist
    V.text = text
    V.isPress = isPress
    V.applyTranslucency = applyTranslucency
end
