-- VEYL module: runtime
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local RunService = V.RunService
    local Lighting = V.Lighting
    local SoundService = V.SoundService
    local Workspace = V.Workspace
    local PlayerGui = V.PlayerGui
    local LEGACY_INSTANCES = V.LEGACY_INSTANCES
    local Util = V.Util
    local Cap = V.Cap
    local Session = V.Session

    ----------------------------------------------------------------------------
    -- 3. Runtime capability detection (optional executor APIs, never assumed)
    ----------------------------------------------------------------------------

    local function isCallable(value)
        return type(value) == "function"
    end

    -- Reading an undefined global returns nil; pcall guards environments that throw.
    local function readGlobal(reader)
        local ok, value = pcall(reader)
        if ok then
            return value
        end
        return nil
    end

    Cap.report = {}

    -- Shared table used only to hand the shutdown function to the next execution.
    Cap.shared = _G
    do
        local getgenvFn = readGlobal(function()
            return getgenv
        end)
        if isCallable(getgenvFn) then
            local ok, env = pcall(getgenvFn)
            if ok and type(env) == "table" then
                Cap.shared = env
            end
        end
    end

    -- Drawing: confirmed by creating and removing one Line object.
    do
        local constructor = readGlobal(function()
            return Drawing.new
        end)
        if isCallable(constructor) then
            local ok, probe = pcall(constructor, "Line")
            if ok and probe ~= nil then
                pcall(function()
                    probe:Remove()
                end)
                Cap.drawingNew = constructor
                Cap.drawingFont = readGlobal(function()
                    return Drawing.Fonts.Plex
                end)
            end
        end
    end

    -- gethui: documented hidden GUI container on runtimes that provide it.
    do
        local gethuiFn = readGlobal(function()
            return gethui
        end)
        if isCallable(gethuiFn) then
            local ok, container = pcall(gethuiFn)
            if ok and typeof(container) == "Instance" then
                Cap.hui = container
            end
        end
    end

    -- Local file API, used only for VEYL's own non-sensitive config.
    do
        local readfileFn = readGlobal(function()
            return readfile
        end)
        local writefileFn = readGlobal(function()
            return writefile
        end)
        local isfileFn = readGlobal(function()
            return isfile
        end)
        if isCallable(readfileFn) and isCallable(writefileFn) and isCallable(isfileFn) then
            local makefolderFn = readGlobal(function()
                return makefolder
            end)
            local isfolderFn = readGlobal(function()
                return isfolder
            end)
            Cap.file = {
                read = readfileFn,
                write = writefileFn,
                isFile = isfileFn,
                makeFolder = isCallable(makefolderFn) and makefolderFn or nil,
                isFolder = isCallable(isfolderFn) and isfolderFn or nil,
            }
            Cap.configFolder = Cap.file.makeFolder and "VEYL" or nil
            Cap.configPath = Cap.file.makeFolder and "VEYL/config.json" or "VEYL_config.json"
        end
    end

    -- Clipboard.
    do
        local clip = readGlobal(function()
            return setclipboard
        end) or readGlobal(function()
            return toclipboard
        end)
        if isCallable(clip) then
            Cap.clipboard = clip
        end
    end

    -- Runtime identity, only through the identification function the runtime exposes.
    do
        local identify = readGlobal(function()
            return identifyexecutor
        end) or readGlobal(function()
            return getexecutorname
        end)
        if isCallable(identify) then
            local ok, name, version = pcall(identify)
            if ok and type(name) == "string" then
                Cap.identity = Util.truncate(name .. (type(version) == "string" and (" " .. version) or ""), 48)
            end
        end
    end

    Cap.script = readGlobal(function()
        return typeof(script) == "Instance" and script or nil
    end)
    Cap.executorAware = (Cap.drawingNew or Cap.hui or Cap.file or Cap.clipboard or Cap.identity) ~= nil
    Cap.studio = RunService:IsStudio()

    function Cap.copy(text)
        if not Cap.clipboard then
            return false
        end
        local ok = pcall(Cap.clipboard, tostring(text))
        return ok
    end

    function Cap.modeText()
        if Cap.identity then
            return Cap.identity
        end
        return Cap.executorAware and "Executor APIs detected" or "Standard client (no executor APIs)"
    end

    function Cap.buildReport(guiParentKind)
        local rows = {}
        local function add(name, status, detail)
            table.insert(rows, { name = name, status = status, detail = detail })
        end
        add("Runtime", "Info", Cap.modeText())
        add("Drawing API", Cap.drawingNew and "Available" or "Fallback", Cap.drawingNew and "Overlay uses Drawing objects" or "Overlay uses ScreenGui frames")
        add("GUI container", guiParentKind == "gethui" and "Available" or "Fallback", guiParentKind == "gethui" and "Parented under gethui()" or "Parented under PlayerGui")
        add("Config files", Cap.file and "Available" or "Unavailable", Cap.file and Cap.configPath or "Settings stay in session memory")
        add("Clipboard", Cap.clipboard and "Available" or "Fallback", Cap.clipboard and "setclipboard" or "Copy from a text box with Ctrl+C")
        add("External URL opening", "Unavailable", "No documented API is used; bookmarks are copy-only")
        add("Highlight", "Available", "Standard Roblox instance")
        add("Teleport (rejoin)", Cap.studio and "Unavailable" or "Available", Cap.studio and "Studio does not support teleports" or "TeleportService")
        add("Script instance", Cap.script and "Available" or "Info", Cap.script and "Destroying cleanup bound" or "Cleanup via session handoff")
        Cap.report = rows
        return rows
    end

    ----------------------------------------------------------------------------
    -- Re-execution safety: stop the previous session, then remove known leftovers
    ----------------------------------------------------------------------------

    do
        local previous = Cap.shared.__VEYL_SESSION
        if type(previous) == "table" and isCallable(previous.shutdown) then
            local ok, err = pcall(previous.shutdown, "re-execution")
            if not ok then
                warn("[VEYL] Previous session shutdown failed: " .. tostring(err))
            end
        end
        Cap.shared.__VEYL_SESSION = nil

        local containers = {
            gui = { PlayerGui, Cap.hui },
            workspace = { Workspace },
            lighting = { Lighting },
            sound = { SoundService },
        }
        local removed = 0
        for _, spec in ipairs(LEGACY_INSTANCES) do
            for _, container in ipairs(containers[spec.where]) do
                if typeof(container) == "Instance" then
                    for _, child in ipairs(container:GetChildren()) do
                        if child.Name == spec.name and child.ClassName == spec.class then
                            local ok = pcall(function()
                                child:Destroy()
                            end)
                            if ok then
                                removed += 1
                            end
                        end
                    end
                end
            end
        end
        Session.legacyRemoved = removed
    end

    V.isCallable = isCallable
    V.readGlobal = readGlobal
end
