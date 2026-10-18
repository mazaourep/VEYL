-- Minimal Roblox client mock for smoke-testing VEYL.lua in the plain Luau VM.
-- It models only what VEYL touches. It is NOT a Roblox emulator.

ERRORS = {}
local function report(kind, err)
    table.insert(ERRORS, kind .. ": " .. tostring(err))
    print("!! " .. kind .. ": " .. tostring(err))
end
REPORT = report

local realOs = os
NOW = 1000
local mockOs = { clock = function() return NOW end, date = realOs.date, time = realOs.time }

local nativeTypeof = typeof
local function mockTypeof(value)
    if type(value) == "table" then
        local mt = getmetatable(value)
        if type(mt) == "table" and rawget(mt, "__type") then
            return rawget(mt, "__type")
        end
    end
    return nativeTypeof(value)
end

-- Vector3 ------------------------------------------------------------------
local V3 = {}
V3.__type = "Vector3"
V3.__index = function(self, key)
    if key == "Magnitude" then
        return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
    elseif key == "Unit" then
        local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
        if m == 0 then return self end
        return Vector3.new(self.X / m, self.Y / m, self.Z / m)
    end
    return V3[key]
end
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
    return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
    if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
    return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Lerp(a, b, t) return a + (b - a) * t end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1) }

-- Vector2 ------------------------------------------------------------------
local V2 = {}
V2.__type = "Vector2"
V2.__index = function(self, key)
    if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y)
    elseif key == "Unit" then
        local m = math.sqrt(self.X * self.X + self.Y * self.Y)
        if m == 0 then return self end
        return Vector2.new(self.X / m, self.Y / m)
    end
    return V2[key]
end
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    if type(b) == "number" then return v2(a.X * b, a.Y * b) end
    return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
    if type(b) == "number" then return v2(a.X / b, a.Y / b) end
    return v2(a.X / b.X, a.Y / b.Y)
end
V2.__unm = function(a) return v2(-a.X, -a.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
Vector2 = { new = v2, zero = v2(0, 0) }

-- CFrame -------------------------------------------------------------------
local CF = {}
CF.__type = "CFrame"
local function cf(p, r)
    return setmetatable({ p = p, r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
local function rotate(r, v)
    return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function transpose(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
local function matmul(a, b)
    local out = {}
    for i = 0, 2 do
        for j = 0, 2 do
            out[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
        end
    end
    return out
end
CF.__index = function(self, key)
    if key == "Position" then return self.p
    elseif key == "LookVector" then return v3(-self.r[3], -self.r[6], -self.r[9])
    elseif key == "X" then return self.p.X
    elseif key == "Y" then return self.p.Y
    elseif key == "Z" then return self.p.Z
    end
    return CF[key]
end
CF.__mul = function(a, b)
    if getmetatable(b) == CF then
        return cf(a.p + rotate(a.r, b.p), matmul(a.r, b.r))
    end
    return a.p + rotate(a.r, b)
end
function CF.PointToWorldSpace(self, v) return self.p + rotate(self.r, v) end
function CF.PointToObjectSpace(self, v) return rotate(transpose(self.r), v - self.p) end
function CF.Inverse(self)
    local rt = transpose(self.r)
    return cf(-rotate(rt, self.p), rt)
end
function CF.ToObjectSpace(self, other) return CF.Inverse(self) * other end
function CF.Lerp(self, other, t)
    local p = self.p + (other.p - self.p) * t
    local look = self.LookVector + (other.LookVector - self.LookVector) * t
    if look.Magnitude < 1e-6 then return cf(p, other.r) end
    return CFrame.lookAt(p, p + look)
end
CFrame = {
    new = function(x, y, z)
        if x == nil then return cf(v3(0, 0, 0)) end
        if type(x) == "table" then return cf(x) end
        return cf(v3(x, y, z))
    end,
    lookAt = function(eye, target)
        local look = (target - eye).Unit
        local right = look:Cross(v3(0, 1, 0))
        if right.Magnitude < 1e-6 then right = v3(1, 0, 0) end
        right = right.Unit
        local up = right:Cross(look)
        -- columns: right, up, -look
        return cf(eye, { right.X, up.X, -look.X, right.Y, up.Y, -look.Y, right.Z, up.Z, -look.Z })
    end,
}

-- UDim / UDim2 / Color3 / sequences -----------------------------------------
local UD = { __type = "UDim" }
UD.__index = UD
UDim = { new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end }
local UD2 = { __type = "UDim2" }
UD2.__index = UD2
local function ud2(xs, xo, ys, yo) return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2) end
UD2.__add = function(a, b) return ud2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
UDim2 = {
    new = function(xs, xo, ys, yo) return ud2(xs or 0, xo or 0, ys or 0, yo or 0) end,
    fromOffset = function(x, y) return ud2(0, x or 0, 0, y or 0) end,
    fromScale = function(x, y) return ud2(x or 0, 0, y or 0, 0) end,
}

local C3 = { __type = "Color3" }
C3.__index = C3
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3.ToHSV(c)
    local r, g, b = c.R, c.G, c.B
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, v = 0, 0, max
    local d = max - min
    if max > 0 then s = d / max end
    if d > 0 then
        if max == r then h = (g - b) / d % 6 elseif max == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, s, v
end
Color3 = {
    new = c3,
    fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
    fromHSV = function(h, s, v)
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
        elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) else return c3(v, p, q) end
    end,
}
ColorSequence = { new = function(...) return { kind = "ColorSequence", args = { ... } } end }
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
NumberSequence = { new = function(...) return { kind = "NumberSequence", args = { ... } } end }
NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
RaycastParams = { new = function() return {} end }

-- Enum ---------------------------------------------------------------------
local enumCache = {}
local ENUM_VALUES = { RenderPriority = { Camera = 200 } }
Enum = setmetatable({}, {
    __index = function(_, enumName)
        enumCache[enumName] = enumCache[enumName] or setmetatable({}, {
            __index = function(t, itemName)
                local item = setmetatable({ Name = itemName, EnumType = enumName, Value = (ENUM_VALUES[enumName] or {})[itemName] or 0 }, { __type = "EnumItem", __tostring = function() return "Enum." .. enumName .. "." .. itemName end })
                rawset(t, itemName, item)
                return item
            end,
        })
        return enumCache[enumName]
    end,
})

-- Signals ------------------------------------------------------------------
local SIGNALS = setmetatable({}, { __mode = "k" })
local Signal = {}
Signal.__index = Signal
local Connection = { __type = "RBXScriptConnection" }
Connection.__index = Connection
function Connection:Disconnect() self.Connected = false end
local function newSignal(name)
    local s = setmetatable({ handlers = {}, name = name }, Signal)
    SIGNALS[s] = true
    return s
end
NEWSIGNAL = newSignal
function Signal:Connect(fn)
    local c = setmetatable({ Connected = true, fn = fn }, Connection)
    table.insert(self.handlers, c)
    return c
end
function Signal:Once(fn)
    local c
    c = self:Connect(function(...) c:Disconnect() fn(...) end)
    return c
end
function Signal:Fire(...)
    local list = table.clone(self.handlers)
    for _, c in ipairs(list) do
        if c.Connected then
            local ok, err = pcall(c.fn, ...)
            if not ok then report("handler(" .. tostring(self.name) .. ")", err) end
        end
    end
    -- compact
    local alive = {}
    for _, c in ipairs(self.handlers) do if c.Connected then table.insert(alive, c) end end
    self.handlers = alive
end
function Signal:Wait() return nil end
function COUNT_CONNECTIONS()
    local n = 0
    for s in pairs(SIGNALS) do
        for _, c in ipairs(s.handlers) do if c.Connected then n += 1 end end
    end
    return n
end

-- task scheduler -------------------------------------------------------------
local queue = {}
local cancelled = setmetatable({}, { __mode = "k" })
local function schedule(at, co, args)
    table.insert(queue, { at = at, co = co, args = args })
end
local function resume(co, ...)
    if cancelled[co] or coroutine.status(co) == "dead" then return end
    local ok, err = coroutine.resume(co, ...)
    if not ok then report("task", err) end
end
task = {
    spawn = function(fn, ...)
        local co = type(fn) == "thread" and fn or coroutine.create(fn)
        resume(co, ...)
        return co
    end,
    defer = function(fn, ...)
        local co = type(fn) == "thread" and fn or coroutine.create(fn)
        schedule(NOW, co, { ... })
        return co
    end,
    delay = function(t, fn, ...)
        local co = coroutine.create(fn)
        schedule(NOW + (t or 0), co, { ... })
        return co
    end,
    wait = function(t)
        local co = coroutine.running()
        schedule(NOW + (t or 0.016), co, {})
        return coroutine.yield()
    end,
    cancel = function(co) cancelled[co] = true end,
}
function RUN_SCHEDULER()
    local ran = true
    local guard = 0
    while ran and guard < 1000 do
        ran = false
        guard += 1
        table.sort(queue, function(a, b) return a.at < b.at end)
        local due = {}
        local rest = {}
        for _, item in ipairs(queue) do
            if item.at <= NOW then table.insert(due, item) else table.insert(rest, item) end
        end
        queue = rest
        for _, item in ipairs(due) do
            ran = true
            resume(item.co, table.unpack(item.args))
        end
    end
end

-- Instances ----------------------------------------------------------------
local DATA = setmetatable({}, { __mode = "k" })
local INSTANCE_MT = { __type = "Instance" }
local ALL_INSTANCES = setmetatable({}, { __mode = "k" })

local function isA(className, target)
    local c = className
    while c do
        if c == target then return true end
        c = SUPER[c]
    end
    return target == "Instance"
end

local EVENTS = {
    Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true,
    AncestryChanged = true, Destroying = true, AttributeChanged = true, MouseEnter = true, MouseLeave = true,
    Activated = true, MouseButton1Click = true, MouseButton2Click = true, InputBegan = true, InputChanged = true,
    InputEnded = true, FocusLost = true, Loaded = true, Ended = true, Died = true, CharacterAdded = true,
    CharacterRemoving = true, PlayerAdded = true, PlayerRemoving = true, Heartbeat = true, RenderStepped = true,
    TeleportInitFailed = true, OnTeleport = true,
}

local DEFAULTS = {
    Name = nil, Visible = true, Text = "", Enabled = true, Health = 100, MaxHealth = 100, WalkSpeed = 16,
    BackgroundTransparency = 0, Transparency = 0, TextTransparency = 0, LayoutOrder = 0, Rotation = 0,
    Brightness = 2, ExposureCompensation = 0, ClockTime = 14, GlobalShadows = true, Density = 0.3, Haze = 0,
    Volume = 0.5, TimePosition = 0, TimeLength = 0, IsPlaying = false, IsLoaded = false, RequiresHandle = true,
    ToolTip = "", FieldOfView = 70, DisplayName = "", UserId = 0, AutomaticSize = nil,
}

local function data(inst) return DATA[inst] end

local function absSize(inst)
    local d = data(inst)
    if d.ClassName == "ScreenGui" or d.ClassName == "Folder" or d.ClassName == "PlayerGui" then
        return Vector2.new(1280, 684)
    end
    local size = d.props.Size
    local parent = d.props.Parent
    local ps = (parent and DATA[parent] and absSize(parent)) or Vector2.new(1280, 684)
    if not size then return Vector2.new(100, 20) end
    return Vector2.new(size.X.Scale * ps.X + size.X.Offset, size.Y.Scale * ps.Y + size.Y.Offset)
end
local function absPos(inst)
    local d = data(inst)
    local parent = d.props.Parent
    if d.ClassName == "ScreenGui" or not parent or not DATA[parent] then return Vector2.new(0, 0) end
    local pos = d.props.Position
    local pp = absPos(parent)
    local ps = absSize(parent)
    if not pos then return pp end
    return Vector2.new(pp.X + pos.X.Scale * ps.X + pos.X.Offset, pp.Y + pos.Y.Scale * ps.Y + pos.Y.Offset)
end

local function signalOf(inst, name)
    local d = data(inst)
    d.signals[name] = d.signals[name] or newSignal(d.ClassName .. "." .. name)
    return d.signals[name]
end
local function propSignal(inst, name)
    local d = data(inst)
    d.propSignals[name] = d.propSignals[name] or newSignal(d.ClassName .. ":" .. name)
    return d.propSignals[name]
end

local function descendants(inst, out)
    out = out or {}
    for _, child in ipairs(data(inst).children) do
        table.insert(out, child)
        descendants(child, out)
    end
    return out
end

local function isDescendantOf(inst, ancestor)
    local p = data(inst).props.Parent
    while p do
        if p == ancestor then return true end
        p = DATA[p] and DATA[p].props.Parent
    end
    return false
end

local METHODS = {}
function METHODS.GetChildren(self) return table.clone(data(self).children) end
function METHODS.GetDescendants(self) return descendants(self) end
function METHODS.FindFirstChild(self, name)
    for _, child in ipairs(data(self).children) do if data(child).props.Name == name then return child end end
    return nil
end
function METHODS.WaitForChild(self, name) return METHODS.FindFirstChild(self, name) end
function METHODS.FindFirstChildOfClass(self, className)
    for _, child in ipairs(data(self).children) do if data(child).ClassName == className then return child end end
    return nil
end
function METHODS.FindFirstChildWhichIsA(self, className)
    for _, child in ipairs(data(self).children) do if isA(data(child).ClassName, className) then return child end end
    return nil
end
function METHODS.FindFirstAncestorOfClass(self, className)
    local p = data(self).props.Parent
    while p do
        if data(p).ClassName == className then return p end
        p = data(p).props.Parent
    end
    return nil
end
function METHODS.IsA(self, className) return isA(data(self).ClassName, className) end
function METHODS.IsDescendantOf(self, ancestor) return isDescendantOf(self, ancestor) end
function METHODS.GetFullName(self)
    local parts = {}
    local p = self
    while p and DATA[p] and data(p).ClassName ~= "DataModel" do
        table.insert(parts, 1, data(p).props.Name)
        p = data(p).props.Parent
    end
    return table.concat(parts, ".")
end
function METHODS.SetAttribute(self, k, v) data(self).attrs[k] = v; signalOf(self, "AttributeChanged"):Fire(k) end
function METHODS.GetAttribute(self, k) return data(self).attrs[k] end
function METHODS.GetAttributes(self) return table.clone(data(self).attrs) end
function METHODS.GetPropertyChangedSignal(self, name) return propSignal(self, name) end
function METHODS.Destroy(self)
    local d = data(self)
    if d.destroyed then return end
    signalOf(self, "Destroying"):Fire()
    for _, child in ipairs(table.clone(d.children)) do METHODS.Destroy(child) end
    self.Parent = nil
    d.destroyed = true
    -- Roblox disconnects every connection to a destroyed instance.
    for _, sig in pairs(d.signals) do for _, c in ipairs(sig.handlers) do c.Connected = false end end
    for _, sig in pairs(d.propSignals) do for _, c in ipairs(sig.handlers) do c.Connected = false end end
end
function METHODS.ClearAllChildren(self) for _, c in ipairs(table.clone(data(self).children)) do METHODS.Destroy(c) end end
function METHODS.Remove(self) self.Parent = nil end

local CLASS_METHODS = {}
INSTANCE_FACTORY = nil

local function newInstance(className, parent)
    local proxy = setmetatable({}, INSTANCE_MT)
    DATA[proxy] = { ClassName = className, props = { Name = className }, children = {}, attrs = {}, signals = {}, propSignals = {} }
    ALL_INSTANCES[proxy] = true
    if CLASS_METHODS[className] and CLASS_METHODS[className].init then CLASS_METHODS[className].init(proxy) end
    if parent then proxy.Parent = parent end
    return proxy
end

INSTANCE_MT.__index = function(self, key)
    local d = DATA[self]
    if key == "ClassName" then return d.ClassName end
    local cm = CLASS_METHODS[d.ClassName]
    local c = d.ClassName
    while c do
        local m = CLASS_METHODS[c]
        if m and m[key] then return m[key] end
        c = SUPER[c]
    end
    if METHODS[key] then return METHODS[key] end
    if EVENTS[key] then return signalOf(self, key) end
    if key == "AbsoluteSize" then return absSize(self) end
    if key == "AbsolutePosition" then return absPos(self) end
    if key == "Position" and isA(d.ClassName, "BasePart") then return (d.props.CFrame or CFrame.new()).Position end
    local value = d.props[key]
    if value ~= nil then return value end
    if key == "Parent" then return nil end
    if cm and cm.getters and cm.getters[key] then return cm.getters[key](self) end
    local default = DEFAULTS[key]
    if default ~= nil then return default end
    if d.ClassName == "Players" or isA(d.ClassName, "Instance") then
        local child = METHODS.FindFirstChild(self, key)
        if child then return child end
    end
    return nil
end

INSTANCE_MT.__newindex = function(self, key, value)
    local d = DATA[self]
    if d.destroyed and key == "Parent" and value ~= nil then
        error("The Parent property of " .. tostring(d.props.Name) .. " is locked")
    end
    if key == "Parent" then
        local old = d.props.Parent
        if old == value then return end
        if old then
            local list = DATA[old].children
            local i = table.find(list, self)
            if i then table.remove(list, i) end
            local p = old
            while p do
                signalOf(p, "DescendantRemoving"):Fire(self)
                p = DATA[p].props.Parent
            end
        end
        d.props.Parent = value
        if value then
            table.insert(DATA[value].children, self)
            signalOf(value, "ChildAdded"):Fire(self)
            local added = { self }
            for _, x in ipairs(descendants(self)) do table.insert(added, x) end
            local p = value
            while p do
                for _, x in ipairs(added) do signalOf(p, "DescendantAdded"):Fire(x) end
                p = DATA[p].props.Parent
            end
        end
        signalOf(self, "AncestryChanged"):Fire(self, value)
        for _, x in ipairs(descendants(self)) do signalOf(x, "AncestryChanged"):Fire(self, value) end
        propSignal(self, "Parent"):Fire()
        return
    end
    if key == "Position" and isA(d.ClassName, "BasePart") then
        d.props.CFrame = CFrame.new(value)
        return
    end
    d.props[key] = value
    if d.propSignals[key] then d.propSignals[key]:Fire() end
end
INSTANCE_MT.__tostring = function(self) return tostring(DATA[self].props.Name) end

Instance = { new = function(className, parent) return newInstance(className, parent) end }

-- Class behavior -------------------------------------------------------------
CLASS_METHODS.TextBox = {
    IsFocused = function() return false end,
    CaptureFocus = function() end,
    ReleaseFocus = function() end,
}
CLASS_METHODS.Model = {
    GetBoundingBox = function(self)
        local root = METHODS.FindFirstChild(self, "HumanoidRootPart")
        local cframe = root and root.CFrame or CFrame.new()
        return cframe, Vector3.new(4, 5.5, 2)
    end,
}
CLASS_METHODS.Humanoid = {
    GetState = function() return Enum.HumanoidStateType.Running end,
    getters = { RootPart = function(self)
        local parent = self.Parent
        return parent and METHODS.FindFirstChild(parent, "HumanoidRootPart")
    end },
}
CLASS_METHODS.Sound = {
    Play = function(self)
        DATA[self].props.IsPlaying = true
        if not DATA[self].props.IsLoaded then
            DATA[self].props.IsLoaded = true
            DATA[self].props.TimeLength = 120
            signalOf(self, "Loaded"):Fire()
        end
    end,
    Pause = function(self) DATA[self].props.IsPlaying = false end,
    Resume = function(self) DATA[self].props.IsPlaying = true end,
    Stop = function(self) DATA[self].props.IsPlaying = false end,
}
CLASS_METHODS.Player = { GetNetworkPing = function() return 0.042 end }
CLASS_METHODS.Camera = {
    WorldToViewportPoint = function(self, world)
        local cframe = self.CFrame
        local viewport = self.ViewportSize
        local l = cframe:PointToObjectSpace(world)
        local depth = -l.Z
        local f = (viewport.Y / 2) / math.tan(math.rad(self.FieldOfView) / 2)
        local d = depth == 0 and 1e-6 or depth
        local sx = viewport.X / 2 + l.X / math.abs(d) * f
        local sy = viewport.Y / 2 - l.Y / math.abs(d) * f
        local inView = depth > 0 and sx >= 0 and sx <= viewport.X and sy >= 0 and sy <= viewport.Y
        return Vector3.new(sx, sy, depth), inView
    end,
}

-- DataModel -----------------------------------------------------------------
game = newInstance("DataModel")
DATA[game].props.Name = "Game"
DATA[game].props.PlaceId = 123456
DATA[game].props.JobId = "job-abc"
local services = {}
CLASS_METHODS.DataModel = {
    GetService = function(_, name)
        if not services[name] then
            services[name] = newInstance(name, game)
            DATA[services[name]].props.Name = name
        end
        return services[name]
    end,
    IsLoaded = function() return true end,
}
workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
DATA[Lighting].props.Ambient = Color3.fromRGB(70, 70, 70)
DATA[Lighting].props.Brightness = 2
DATA[Lighting].props.ExposureCompensation = 0
DATA[Lighting].props.ClockTime = 14
DATA[Lighting].props.GlobalShadows = true

local camera = newInstance("Camera", workspace)
DATA[camera].props.CFrame = CFrame.lookAt(Vector3.new(0, 5, 20), Vector3.new(0, 5, 0))
DATA[camera].props.ViewportSize = Vector2.new(1280, 720)
DATA[camera].props.CameraType = Enum.CameraType.Custom
DATA[workspace].props.CurrentCamera = camera
CLASS_METHODS.Workspace = { Raycast = function() return nil end }

-- Players
local localPlayer = newInstance("Player", Players)
DATA[localPlayer].props.Name = "Tester"
DATA[localPlayer].props.DisplayName = "Tester"
DATA[localPlayer].props.UserId = 1
newInstance("PlayerGui", localPlayer).Name = "PlayerGui"
newInstance("Backpack", localPlayer).Name = "Backpack"
DATA[Players].props.LocalPlayer = localPlayer

function MAKE_CHARACTER(name, position, parent)
    local model = newInstance("Model")
    model.Name = name
    local root = newInstance("Part", model)
    root.Name = "HumanoidRootPart"
    root.CFrame = CFrame.new(position)
    DATA[root].props.AssemblyLinearVelocity = Vector3.zero
    local head = newInstance("Part", model)
    head.Name = "Head"
    head.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
    local humanoid = newInstance("Humanoid", model)
    model.Parent = parent or workspace
    return model, humanoid, root
end
local localCharacter = MAKE_CHARACTER("Tester", Vector3.new(0, 3, 15))
DATA[localPlayer].props.Character = localCharacter

local playerList = { localPlayer }
CLASS_METHODS.Players = {
    GetPlayers = function() return table.clone(playerList) end,
    GetPlayerFromCharacter = function(_, model)
        for _, p in ipairs(playerList) do if p.Character == model then return p end end
        return nil
    end,
}
function ADD_PLAYER(name, position)
    local p = newInstance("Player", Players)
    p.Name = name
    p.DisplayName = name
    p.UserId = #playerList + 100
    table.insert(playerList, p)
    signalOf(Players, "PlayerAdded"):Fire(p)
    local char = MAKE_CHARACTER(name, position)
    p.Character = char
    signalOf(p, "CharacterAdded"):Fire(char)
    return p, char
end

-- RunService / UserInputService
local renderSteps = {}
CLASS_METHODS.RunService = {
    IsClient = function() return true end,
    IsStudio = function() return false end,
    BindToRenderStep = function(_, name, priority, fn) renderSteps[name] = fn end,
    UnbindFromRenderStep = function(_, name) renderSteps[name] = nil end,
}
function BOUND_STEPS() local n = 0 for _ in pairs(renderSteps) do n += 1 end return n end
HELD = {}
CLASS_METHODS.UserInputService = {
    GetFocusedTextBox = function() return nil end,
    IsKeyDown = function(_, key) return HELD[key.Name] == true end,
    IsMouseButtonPressed = function(_, t) return HELD[t.Name] == true end,
    GetMouseLocation = function() return Vector2.new(640, 360) end,
}
function STEP(dt)
    dt = dt or 1 / 60
    NOW += dt
    RUN_SCHEDULER()
    signalOf(RunService, "RenderStepped"):Fire(dt)
    for name, fn in pairs(renderSteps) do
        local ok, err = pcall(fn, dt)
        if not ok then report("renderstep " .. name, err) end
    end
    signalOf(RunService, "Heartbeat"):Fire(dt)
end
function KEY(name, processed)
    local input = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode[name], Position = Vector3.new(0, 0, 0) }
    signalOf(UIS, "InputBegan"):Fire(input, processed == true)
    signalOf(UIS, "InputEnded"):Fire(input, processed == true)
end

-- CollectionService
local tags = {}
CLASS_METHODS.CollectionService = {
    HasTag = function(_, inst, tag) return tags[tag] ~= nil and tags[tag][inst] == true end,
    GetTagged = function(_, tag)
        local out = {}
        for inst in pairs(tags[tag] or {}) do table.insert(out, inst) end
        return out
    end,
    GetInstanceAddedSignal = function(self, tag) return signalOf(self, "Added_" .. tag) end,
    GetInstanceRemovedSignal = function(self, tag) return signalOf(self, "Removed_" .. tag) end,
}
function ADD_TAG(inst, tag)
    tags[tag] = tags[tag] or {}
    tags[tag][inst] = true
    signalOf(CollectionService, "Added_" .. tag):Fire(inst)
end

-- Other services
TELEPORTS = {}
CLASS_METHODS.TeleportService = {
    Teleport = function(_, placeId) table.insert(TELEPORTS, "match:" .. placeId) end,
    TeleportToPlaceInstance = function(_, placeId, jobId) table.insert(TELEPORTS, "server:" .. placeId .. ":" .. jobId) end,
}
CLASS_METHODS.MarketplaceService = {
    GetProductInfo = function(_, id)
        if id == 404 then error("HTTP 404") end
        return { AssetTypeId = id == 7 and 1 or 3, Name = "Song " .. id, Creator = { Name = "Composer" } }
    end,
}
CLASS_METHODS.ContentProvider = {
    PreloadAsync = function(_, list, callback)
        for _, item in ipairs(list) do
            if callback then callback(item.SoundId, string.find(item.SoundId, "999") and Enum.AssetFetchStatus.Failure or Enum.AssetFetchStatus.Success) end
        end
    end,
}

-- JSON for HttpService
local function encode(v)
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then return tostring(v)
    elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", string.byte(c)) end) .. '"'
    elseif t == "table" then
        if #v > 0 or next(v) == nil then
            local parts = {}
            for _, x in ipairs(v) do table.insert(parts, encode(x)) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for k, x in pairs(v) do table.insert(parts, encode(tostring(k)) .. ":" .. encode(x)) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("cannot encode " .. t)
end
local function decode(s)
    local i = 1
    local function ws() i = s:find("[^%s]", i) or #s + 1 end
    local value
    local function str()
        i += 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == "" then error("unterminated string") end
            if c == '"' then i += 1 break end
            if c == "\\" then
                local n = s:sub(i + 1, i + 1)
                if n == "u" then table.insert(out, string.char(tonumber(s:sub(i + 2, i + 5), 16) % 256)); i += 6
                else table.insert(out, ({ n = "\n", t = "\t", r = "\r" })[n] or n); i += 2 end
            else table.insert(out, c); i += 1 end
        end
        return table.concat(out)
    end
    function value()
        ws()
        local c = s:sub(i, i)
        if c == "{" then
            i += 1
            local obj = {}
            ws()
            if s:sub(i, i) == "}" then i += 1 return obj end
            while true do
                ws()
                local k = str()
                ws(); assert(s:sub(i, i) == ":", "expected :"); i += 1
                obj[k] = value()
                ws()
                local d = s:sub(i, i); i += 1
                if d == "}" then break end
                assert(d == ",", "expected ,")
            end
            return obj
        elseif c == "[" then
            i += 1
            local arr = {}
            ws()
            if s:sub(i, i) == "]" then i += 1 return arr end
            while true do
                table.insert(arr, value())
                ws()
                local d = s:sub(i, i); i += 1
                if d == "]" then break end
                assert(d == ",", "expected ,")
            end
            return arr
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == "true" then i += 4 return true
        elseif s:sub(i, i + 4) == "false" then i += 5 return false
        elseif s:sub(i, i + 3) == "null" then i += 4 return nil
        else
            local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
            if not num or num == "" then error("bad json at " .. i) end
            i += #num
            return tonumber(num)
        end
    end
    return value()
end
CLASS_METHODS.HttpService = {
    JSONEncode = function(_, v) return encode(v) end,
    JSONDecode = function(_, s) return decode(s) end,
}

-- Helpers for tests -----------------------------------------------------------
function FIND_ALL(root, predicate, out)
    out = out or {}
    for _, d in ipairs(descendants(root)) do
        if predicate(d) then table.insert(out, d) end
    end
    return out
end
function FIRE(inst, event, ...) signalOf(inst, event):Fire(...) end
function PROPS(inst) return DATA[inst].props end
function CLASSNAME(inst) return DATA[inst].ClassName end
function IS_DESTROYED(inst) return DATA[inst].destroyed == true end
MOCK_TYPEOF = mockTypeof
MOCK_OS = mockOs

-- Optional executor APIs (enabled per test run) --------------------------------
FILES = {}
DRAWINGS = { created = 0, removed = 0, live = {} }
function ENABLE_EXECUTOR(env)
    env.gethui = function() return game:GetService("CoreGui") end
    env.readfile = function(p) return FILES[p] or error("no file") end
    env.writefile = function(p, c) FILES[p] = c end
    env.isfile = function(p) return FILES[p] ~= nil end
    env.makefolder = function() end
    env.isfolder = function() return true end
    env.setclipboard = function(t) CLIPBOARD = t end
    env.identifyexecutor = function() return "MockExec", "1.0" end
    env.Drawing = {
        new = function(kind)
            DRAWINGS.created += 1
            local obj = { kind = kind, Visible = false }
            DRAWINGS.live[obj] = true
            function obj:Remove()
                if DRAWINGS.live[obj] then DRAWINGS.live[obj] = nil; DRAWINGS.removed += 1 end
            end
            return obj
        end,
        Fonts = { Plex = 2 },
    }
end
function LIST_CONNECTIONS()
    for s in pairs(SIGNALS) do
        local n = 0
        for _, c in ipairs(s.handlers) do if c.Connected then n += 1 end end
        if n > 0 then print("LIVE", s.name, n) end
    end
end

-- Loader support: HttpGet served from SOURCES, notifications captured.
HTTP_MODE = "ok"
NOTIFIED = {}
HTTP_CALLS = 0
CLASS_METHODS.DataModel.HttpGet = function(_, url)
    HTTP_CALLS += 1
    if HTTP_MODE == "error" then error("HttpError: ConnectFail") end
    local path = string.match(url, "/(src/.+)$")
    if HTTP_MODE == "ok" and path and SOURCES[path] then return SOURCES[path] end
    return "404: Not Found"
end
CLASS_METHODS.StarterGui = { SetCore = function(_, _, data) table.insert(NOTIFIED, data.Text) end }
