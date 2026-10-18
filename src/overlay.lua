-- VEYL module: overlay
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local PlayerGui = V.PlayerGui
    local NAMES = V.NAMES
    local Util = V.Util
    local Cap = V.Cap
    local Settings = V.Settings
    local UI = V.UI
    local Overlay = V.Overlay
    local T = V.T
    local make = V.make
    local stroke = V.stroke

    ----------------------------------------------------------------------------
    -- 12a. Overlay renderer: Drawing API when available, ScreenGui fallback
    --      Both use viewport coordinates (WorldToViewportPoint, GUI inset ignored).
    ----------------------------------------------------------------------------

    Overlay.registry = {}
    Overlay.mode = nil
    Overlay.reset = Util.signal()

    local NullPrim = {}
    NullPrim.__index = NullPrim
    function NullPrim:hide() end
    function NullPrim:line() end
    function NullPrim:rect() end
    function NullPrim:text() end
    function NullPrim:circle() end
    function NullPrim:triangle() end
    function NullPrim:Destroy() end

    local DrawPrim = {}
    DrawPrim.__index = DrawPrim

    local DRAW_DEFAULTS = {
        Line = { Thickness = 1 },
        Square = { Thickness = 1, Filled = false },
        Text = { Center = true, Outline = true, Size = 13 },
        Circle = { Thickness = 1, NumSides = 48, Filled = false },
        Triangle = { Thickness = 1, Filled = true },
    }

    local function newDrawPrim(kind)
        local ok, object = pcall(Cap.drawingNew, kind)
        if not ok or object == nil then
            return nil
        end
        pcall(function()
            object.Visible = false
        end)
        for property, value in pairs(DRAW_DEFAULTS[kind]) do
            pcall(function()
                object[property] = value
            end)
        end
        if kind == "Text" and Cap.drawingFont ~= nil then
            pcall(function()
                object.Font = Cap.drawingFont
            end)
        end
        local prim = setmetatable({ object = object, shown = false }, DrawPrim)
        Overlay.registry[prim] = true
        return prim
    end

    function DrawPrim:hide()
        if self.shown then
            self.shown = false
            self.object.Visible = false
        end
    end

    function DrawPrim:show()
        if not self.shown then
            self.shown = true
            self.object.Visible = true
        end
    end

    -- Drawing "Transparency" is opacity on common runtimes (1 = fully visible).
    function DrawPrim:line(from, to, color, thickness, opacity)
        local object = self.object
        object.From = from
        object.To = to
        object.Color = color
        object.Thickness = thickness
        object.Transparency = opacity
        self:show()
    end

    function DrawPrim:rect(position, size, color, thickness, opacity, filled)
        local object = self.object
        object.Position = position
        object.Size = size
        object.Color = color
        object.Thickness = thickness
        object.Transparency = opacity
        object.Filled = filled == true
        self:show()
    end

    function DrawPrim:text(value, position, color, size, opacity)
        local object = self.object
        object.Text = value
        object.Position = position
        object.Color = color
        object.Size = size
        object.Transparency = opacity
        self:show()
    end

    function DrawPrim:circle(center, radius, color, thickness, opacity)
        local object = self.object
        object.Position = center
        object.Radius = radius
        object.Color = color
        object.Thickness = thickness
        object.Transparency = opacity
        self:show()
    end

    function DrawPrim:triangle(a, b, c, color, opacity)
        local object = self.object
        object.PointA = a
        object.PointB = b
        object.PointC = c
        object.Color = color
        object.Transparency = opacity
        self:show()
    end

    function DrawPrim:Destroy()
        Overlay.registry[self] = nil
        local object = self.object
        self.object = nil
        if object ~= nil then
            pcall(function()
                object:Remove()
            end)
        end
    end

    local GuiPrim = {}
    GuiPrim.__index = GuiPrim

    function Overlay.guiRoot()
        if Overlay.gui and Overlay.gui.Parent then
            return Overlay.gui
        end
        local gui = make("ScreenGui", {
            Name = NAMES.overlay,
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = 90,
        })
        gui:SetAttribute(NAMES.owned, true)
        gui.Parent = (UI.gui and UI.gui.Parent) or PlayerGui
        Overlay.gui = gui
        return gui
    end

    local function newGuiPrim(kind)
        local root = Overlay.guiRoot()
        local object, outline
        if kind == "Line" then
            object = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, root)
        elseif kind == "Square" then
            object = make("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, root)
            outline = stroke(object, Color3.new(1, 1, 1))
        elseif kind == "Text" then
            object = make("TextLabel", {
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(260, 16),
                Font = T.fontMedium,
                TextStrokeColor3 = Color3.new(0, 0, 0),
                TextStrokeTransparency = 0.35,
                Visible = false,
            }, root)
        elseif kind == "Circle" then
            object = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, root)
            make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, object)
            outline = stroke(object, Color3.new(1, 1, 1))
        else
            object = make("TextLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Text = "▲",
                Font = T.fontBold,
                Visible = false,
            }, root)
        end
        local prim = setmetatable({ object = object, outline = outline, shown = false }, GuiPrim)
        Overlay.registry[prim] = true
        return prim
    end

    GuiPrim.hide = DrawPrim.hide
    GuiPrim.show = DrawPrim.show

    function GuiPrim:line(from, to, color, thickness, opacity)
        local object = self.object
        local delta = to - from
        object.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
        object.Size = UDim2.fromOffset(delta.Magnitude, thickness)
        object.Rotation = math.deg(math.atan2(delta.Y, delta.X))
        object.BackgroundColor3 = color
        object.BackgroundTransparency = 1 - opacity
        self:show()
    end

    function GuiPrim:rect(position, size, color, thickness, opacity, filled)
        local object, outline = self.object, self.outline
        object.Position = UDim2.fromOffset(position.X, position.Y)
        object.Size = UDim2.fromOffset(size.X, size.Y)
        if filled then
            object.BackgroundColor3 = color
            object.BackgroundTransparency = 1 - opacity
            outline.Enabled = false
        else
            object.BackgroundTransparency = 1
            outline.Enabled = true
            outline.Color = color
            outline.Thickness = thickness
            outline.Transparency = 1 - opacity
        end
        self:show()
    end

    function GuiPrim:text(value, position, color, size, opacity)
        local object = self.object
        object.Text = value
        object.Position = UDim2.fromOffset(position.X, position.Y)
        object.Size = UDim2.fromOffset(260, size + 4)
        object.TextColor3 = color
        object.TextSize = size
        object.TextTransparency = 1 - opacity
        self:show()
    end

    function GuiPrim:circle(center, radius, color, thickness, opacity)
        local object, outline = self.object, self.outline
        object.Position = UDim2.fromOffset(center.X, center.Y)
        object.Size = UDim2.fromOffset(radius * 2, radius * 2)
        outline.Color = color
        outline.Thickness = thickness
        outline.Transparency = 1 - opacity
        self:show()
    end

    function GuiPrim:triangle(a, b, c, color, opacity)
        local object = self.object
        local base = (b + c) / 2
        local direction = a - base
        local length = math.max(direction.Magnitude, 1)
        object.Position = UDim2.fromOffset((a.X + base.X) / 2, (a.Y + base.Y) / 2)
        object.Size = UDim2.fromOffset(length * 2, length * 2)
        object.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
        object.TextSize = math.max(8, math.floor(length * 1.5))
        object.TextColor3 = color
        object.TextTransparency = 1 - opacity
        self:show()
    end

    function GuiPrim:Destroy()
        Overlay.registry[self] = nil
        if self.object then
            self.object:Destroy()
            self.object = nil
        end
    end

    function Overlay.resolveMode()
        if Settings.get("esp.renderer") ~= "GUI" and Cap.drawingNew then
            return "Drawing"
        end
        return "GUI"
    end

    function Overlay.modeText()
        local preference = Settings.get("esp.renderer")
        local mode = Overlay.mode or Overlay.resolveMode()
        if preference == "Drawing" and mode ~= "Drawing" then
            return "GUI (Drawing unavailable)", T.warn
        end
        if mode == "GUI" and preference == "Auto" then
            return "GUI fallback", T.warn
        end
        return mode, T.ok
    end

    function Overlay.clearAll()
        for prim in pairs(Overlay.registry) do
            prim:Destroy()
        end
        table.clear(Overlay.registry)
        if Overlay.gui then
            Overlay.gui:Destroy()
            Overlay.gui = nil
        end
    end

    function Overlay.ensureMode()
        local mode = Overlay.resolveMode()
        if mode ~= Overlay.mode then
            Overlay.clearAll()
            Overlay.mode = mode
            Overlay.reset:Fire(mode)
        end
    end

    function Overlay.new(kind)
        if not Overlay.mode then
            Overlay.mode = Overlay.resolveMode()
        end
        if Overlay.mode == "Drawing" then
            return newDrawPrim(kind) or setmetatable({}, NullPrim)
        end
        return newGuiPrim(kind)
    end

    V.NullPrim = NullPrim
    V.DrawPrim = DrawPrim
    V.DRAW_DEFAULTS = DRAW_DEFAULTS
    V.newDrawPrim = newDrawPrim
    V.GuiPrim = GuiPrim
    V.newGuiPrim = newGuiPrim
end
