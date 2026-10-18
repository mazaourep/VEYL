-- VEYL module: ui/notify
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local LIMITS = V.LIMITS
    local Log = V.Log
    local Notify = V.Notify
    local Settings = V.Settings
    local UI = V.UI
    local Session = V.Session
    local T = V.T
    local make = V.make
    local corner = V.corner
    local stroke = V.stroke
    local padding = V.padding
    local text = V.text

    ----------------------------------------------------------------------------
    -- 18. Notifications (bounded toast stack)
    ----------------------------------------------------------------------------

    Notify.serial = 0
    local TOAST_COLORS = { info = T.accent, ok = T.ok, warn = T.warn, error = T.bad }

    function Notify.push(message, kind)
        kind = kind or "info"
        message = tostring(message)
        if kind == "warn" or kind == "error" then
            Log.add(kind, message)
        end
        local holder = UI.toastHolder
        if not holder or not holder.Parent or not Session.alive then
            if kind ~= "warn" and kind ~= "error" then
                print("[VEYL] " .. message)
            end
            return
        end
        if (kind == "info" or kind == "ok") and not Settings.get("ui.toasts") then
            return
        end
        Notify.serial += 1
        local toast = make("Frame", {
            BackgroundColor3 = T.raised,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = Notify.serial,
        })
        corner(toast, 6)
        stroke(toast, T.line)
        make("Frame", { BackgroundColor3 = TOAST_COLORS[kind] or T.accent, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 7), Size = UDim2.new(0, 3, 1, -14) }, toast)
        local label = text(toast, {
            Position = UDim2.fromOffset(16, 0),
            Size = UDim2.new(1, -24, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = message,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
        })
        padding(label, 0, 0, 7, 7)
        toast.Parent = holder
        local toasts = {}
        for _, child in ipairs(holder:GetChildren()) do
            if child:IsA("Frame") then
                table.insert(toasts, child)
            end
        end
        table.sort(toasts, function(a, b)
            return a.LayoutOrder < b.LayoutOrder
        end)
        for index = 1, #toasts - LIMITS.toasts do
            toasts[index]:Destroy()
        end
        task.delay(kind == "error" and 6 or 3.5, function()
            if toast.Parent then
                toast:Destroy()
            end
        end)
    end

    V.TOAST_COLORS = TOAST_COLORS
end
