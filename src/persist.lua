-- VEYL module: persist
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local HttpService = V.HttpService
    local LIMITS = V.LIMITS
    local Log = V.Log
    local Notify = V.Notify
    local Cap = V.Cap
    local Settings = V.Settings
    local Binds = V.Binds
    local Persist = V.Persist
    local Music = V.Music
    local Session = V.Session

    ----------------------------------------------------------------------------
    -- 18. Settings persistence (only when the runtime exposes a file API)
    ----------------------------------------------------------------------------

    Persist.available = Cap.file ~= nil
    Persist.status = Persist.available and "Not saved yet" or "Session only (no file API)"
    Persist.token = 0
    Persist.loading = false

    function Persist.encode()
        return HttpService:JSONEncode({
            app = "VEYL Control",
            version = 1,
            settings = Settings.serialize(),
            binds = table.clone(Binds.map),
            music = Music.serialize(),
        })
    end

    function Persist.save(manual)
        if not Persist.available then
            if manual then
                Notify.push("This runtime has no file API. Settings stay in session memory.", "warn")
            end
            return false
        end
        local ok, err = pcall(function()
            local file = Cap.file
            if Cap.configFolder then
                local exists = false
                if file.isFolder then
                    local okFolder, result = pcall(file.isFolder, Cap.configFolder)
                    exists = okFolder and result == true
                end
                if not exists then
                    pcall(file.makeFolder, Cap.configFolder)
                end
            end
            file.write(Cap.configPath, Persist.encode())
        end)
        if ok then
            Persist.dirty = false
            Persist.status = "Saved " .. os.date("%H:%M:%S") .. " · " .. Cap.configPath
            if manual then
                Notify.push("Configuration saved to " .. Cap.configPath .. ".", "ok")
            end
        else
            Persist.status = "Save failed"
            Log.add("error", "Config save failed: " .. tostring(err))
            if manual then
                Notify.push("Config save failed: " .. tostring(err), "error")
            end
        end
        return ok
    end

    function Persist.schedule()
        if not Persist.available or Persist.loading or not Session.alive or not Settings.get("ui.autosave") then
            return
        end
        Persist.token += 1
        Persist.dirty = true
        local token = Persist.token
        task.delay(1.5, function()
            if Session.alive and token == Persist.token then
                Persist.save(false)
            end
        end)
    end

    function Persist.load(manual)
        if not Persist.available then
            if manual then
                Notify.push("This runtime has no file API to load from.", "warn")
            end
            return false
        end
        local okExists, exists = pcall(Cap.file.isFile, Cap.configPath)
        if not okExists or not exists then
            Persist.status = "No saved config yet"
            if manual then
                Notify.push("No saved configuration was found.", "warn")
            end
            return false
        end
        local okRead, content = pcall(Cap.file.read, Cap.configPath)
        if not okRead or type(content) ~= "string" then
            Persist.status = "Read failed"
            Log.add("error", "Config read failed: " .. tostring(content))
            return false
        end
        if #content > LIMITS.configBytes then
            Persist.status = "Rejected (file too large)"
            Log.add("warn", "Config ignored: file exceeds " .. LIMITS.configBytes .. " bytes.")
            return false
        end
        local okDecode, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if not okDecode or type(data) ~= "table" or data.app ~= "VEYL Control" then
            Persist.status = "Rejected (malformed file)"
            Log.add("warn", "Config ignored: the file is not a valid VEYL configuration.")
            if manual then
                Notify.push("The saved configuration is malformed and was ignored.", "error")
            end
            return false
        end
        Persist.loading = true
        local applied, rejected = Settings.loadTable(data.settings)
        Binds.loadTable(data.binds)
        for _, action in ipairs(Binds.actions) do
            Binds.changed:Fire(action.id)
        end
        Music.loadTable(data.music)
        Persist.loading = false
        Persist.status = string.format("Loaded %d values%s · %s", applied, rejected > 0 and (" (" .. rejected .. " rejected)") or "", Cap.configPath)
        Log.add("info", "Configuration loaded: " .. applied .. " values applied, " .. rejected .. " rejected.")
        if manual then
            Notify.push("Configuration reloaded.", "ok")
        end
        return true
    end
end
