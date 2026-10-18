--[[
    VEYL Control — loader
    Fetches the VEYL modules, compiles all of them, then runs them in order.

    RUN (executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/mazaourep/VEYL/main/loader.lua"))()

    OPTIONS (set before running the line above):
        getgenv().VEYL_SOURCE = "https://raw.githubusercontent.com/<owner>/<repo>/<branch-or-commit>/"
            Base URL the modules are fetched from. Pin a commit SHA for a reproducible build.
        getgenv().VEYL_SOURCE = "local"
            Read the modules from the executor workspace folder instead: VEYL/src/... (works offline
            and with a private repository).

    The last complete download is cached in VEYL/cache/ when a file API exists, and is used
    only if every module fails to download. Remote code runs with your executor's privileges:
    load VEYL only from a source you control.
]]

local LOADER_VERSION = "1.0.0"
local DEFAULT_SOURCE = "https://raw.githubusercontent.com/mazaourep/VEYL/main/"
local CACHE_ROOT = "VEYL/cache/"
local LOCAL_ROOT = "VEYL/"
local FETCH_TIMEOUT = 30
local MODULE_MARKER = "-- VEYL module: "

local MODULES = {
    "src/core.lua",
    "src/runtime.lua",
    "src/settings.lua",
    "src/binds.lua",
    "src/persist.lua",
    "src/ui/window.lua",
    "src/ui/controls.lua",
    "src/ui/popups.lua",
    "src/ui/notify.lua",
    "src/overlay.lua",
    "src/entities.lua",
    "src/esp.lua",
    "src/aimlab.lua",
    "src/world.lua",
    "src/weapons.lua",
    "src/diagnostics.lua",
    "src/music.lua",
    "src/features.lua",
    "src/pages/shared.lua",
    "src/pages/main.lua",
    "src/pages/aimlab.lua",
    "src/pages/visuals.lua",
    "src/pages/world.lua",
    "src/pages/entities.lua",
    "src/pages/weapons.lua",
    "src/pages/music.lua",
    "src/pages/diagnostics.lua",
    "src/pages/misc.lua",
    "src/pages/settings.lua",
    "src/app.lua",
}

-- Optional executor APIs, read defensively (an undefined global is simply nil).
local function readGlobal(reader)
    local ok, value = pcall(reader)
    return ok and value or nil
end
local function callable(value)
    return type(value) == "function"
end

local shared = _G
local getgenvFn = readGlobal(function()
    return getgenv
end)
if callable(getgenvFn) then
    local ok, env = pcall(getgenvFn)
    if ok and type(env) == "table" then
        shared = env
    end
end

local compile = readGlobal(function()
    return loadstring
end)
local fileApi = {
    read = readGlobal(function()
        return readfile
    end),
    write = readGlobal(function()
        return writefile
    end),
    isFile = readGlobal(function()
        return isfile
    end),
    makeFolder = readGlobal(function()
        return makefolder
    end),
}
local canRead = callable(fileApi.read) and callable(fileApi.isFile)
local canWrite = callable(fileApi.write)

local function report(message, isError)
    if isError then
        warn("[VEYL loader] " .. message)
    else
        print("[VEYL loader] " .. message)
    end
end

local function notifyFailure(message)
    report(message, true)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "VEYL failed to load",
            Text = string.sub(message, 1, 180),
            Duration = 10,
        })
    end)
end

local function httpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" then
        return body
    end
    local okAsync, bodyAsync = pcall(function()
        return game:HttpGetAsync(url)
    end)
    if okAsync and type(bodyAsync) == "string" then
        return bodyAsync
    end
    return nil, tostring(ok and "empty response" or body)
end

local function isModule(body)
    return type(body) == "string" and string.sub(body, 1, #MODULE_MARKER) == MODULE_MARKER
        and string.find(body, "return function(V)", 1, true) ~= nil
end

local function readLocal(path)
    if not canRead then
        return nil, "this runtime has no readfile/isfile"
    end
    local okExists, exists = pcall(fileApi.isFile, path)
    if not okExists or not exists then
        return nil, "missing " .. path
    end
    local ok, body = pcall(fileApi.read, path)
    if not ok then
        return nil, tostring(body)
    end
    return body
end

local function writeCache(sources)
    if not canWrite then
        return
    end
    local folders = { "VEYL", "VEYL/cache", "VEYL/cache/src", "VEYL/cache/src/ui", "VEYL/cache/src/pages" }
    if callable(fileApi.makeFolder) then
        for _, folder in ipairs(folders) do
            pcall(fileApi.makeFolder, folder)
        end
    end
    for _, path in ipairs(MODULES) do
        pcall(fileApi.write, CACHE_ROOT .. path, sources[path])
    end
end

-- Downloads every module in parallel; returns sources or nil plus the failures.
local function fetchRemote(base)
    local sources, failures = {}, {}
    local pending = #MODULES
    for _, path in ipairs(MODULES) do
        task.spawn(function()
            local body, err
            for _ = 1, 2 do
                body, err = httpGet(base .. path)
                if isModule(body) then
                    break
                end
                err = err or "not a VEYL module (HTTP error page?)"
                body = nil
            end
            if body then
                sources[path] = body
            else
                table.insert(failures, path .. ": " .. tostring(err))
            end
            pending -= 1
        end)
    end
    local started = os.clock()
    while pending > 0 and os.clock() - started < FETCH_TIMEOUT do
        task.wait(0.05)
    end
    if pending > 0 then
        table.insert(failures, pending .. " module(s) timed out after " .. FETCH_TIMEOUT .. " s")
    end
    if #failures > 0 then
        return nil, failures
    end
    return sources
end

local function fetchFromFiles(root)
    local sources, failures = {}, {}
    for _, path in ipairs(MODULES) do
        local body, err = readLocal(root .. path)
        if isModule(body) then
            sources[path] = body
        else
            table.insert(failures, path .. ": " .. tostring(err or "not a VEYL module"))
        end
    end
    if #failures > 0 then
        return nil, failures
    end
    return sources
end

local function load()
    if not callable(compile) then
        notifyFailure("This runtime has no loadstring, so the loader cannot run. Use dist/VEYL.lua instead.")
        return false
    end
    local source = shared.VEYL_SOURCE
    local sources, failures
    if source == "local" then
        report("Loading modules from the workspace folder " .. LOCAL_ROOT)
        sources, failures = fetchFromFiles(LOCAL_ROOT)
    else
        local base = type(source) == "string" and source or DEFAULT_SOURCE
        if string.sub(base, 1, 8) ~= "https://" then
            notifyFailure("VEYL_SOURCE must be an https:// URL or \"local\".")
            return false
        end
        if string.sub(base, -1) ~= "/" then
            base ..= "/"
        end
        report("Fetching " .. #MODULES .. " modules from " .. base)
        sources, failures = fetchRemote(base)
        if sources then
            writeCache(sources)
        else
            report("Download failed (" .. #failures .. " problem(s)); trying the local cache.", true)
            local cached = fetchFromFiles(CACHE_ROOT)
            if cached then
                report("Using the cached copy from the last successful download.", true)
                sources = cached
            end
        end
    end
    if not sources then
        local hint = source == "local" and "Copy the src folder to <workspace>/VEYL/src."
            or "A private repository returns 404 to HttpGet: make it public, set VEYL_SOURCE, or use VEYL_SOURCE = \"local\"."
        report("Module problems: " .. table.concat(failures, " | "), true)
        notifyFailure(hint .. " (" .. #failures .. " module problem(s); first: " .. failures[1] .. ")")
        return false
    end

    -- Compile everything first, so a broken module stops the load before anything runs.
    local factories = {}
    for index, path in ipairs(MODULES) do
        local chunk, err = compile(sources[path], "=VEYL/" .. path)
        if not chunk then
            notifyFailure("Syntax error in " .. path .. ": " .. tostring(err))
            return false
        end
        local ok, factory = pcall(chunk)
        if not ok or not callable(factory) then
            notifyFailure(path .. " did not return a module function: " .. tostring(factory))
            return false
        end
        factories[index] = factory
    end

    local V = { LOADER_VERSION = LOADER_VERSION }
    for index, path in ipairs(MODULES) do
        local ok, err = pcall(factories[index], V)
        if not ok then
            notifyFailure("Module " .. path .. " failed while starting: " .. tostring(err))
            -- Release whatever the earlier modules already created.
            if V.App and callable(V.App.shutdown) and V.Session and V.Session.alive then
                pcall(V.App.shutdown, "load failure")
            elseif V.Root then
                if V.Session then
                    V.Session.alive = false
                end
                pcall(function()
                    V.Root:clean()
                end)
            end
            return false
        end
    end
    report("VEYL Control " .. tostring(V.VERSION) .. " loaded (loader " .. LOADER_VERSION .. ").")
    return true
end

if shared.__VEYL_LOADING then
    report("A load is already in progress; ignoring this call.", true)
    return false
end
shared.__VEYL_LOADING = true
local ok, result = pcall(load)
shared.__VEYL_LOADING = nil
if not ok then
    notifyFailure("Loader error: " .. tostring(result))
    return false
end
return result
