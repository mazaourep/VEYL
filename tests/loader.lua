
-- Loader tests (executor build) ------------------------------------------------
local failures = 0
local function check(condition, message)
    if condition then print("PASS  " .. message) else failures += 1; print("FAIL  " .. message) end
end
local function frames(n, dt) for _ = 1, n do STEP(dt) end end
local host = game:GetService("CoreGui")
local function consoles()
    local n = 0
    for _, child in ipairs(host:GetChildren()) do
        if child.Name == "VEYLControl" then n += 1 end
    end
    return n
end
local function lastNotice() return NOTIFIED[#NOTIFIED] or "" end
local moduleCount = 0
for _ in pairs(SOURCES) do moduleCount += 1 end

-- 1. Private repository: every request returns "404: Not Found", no cache yet.
HTTP_MODE = "404"
local result = main()
frames(5)
check(result == false, "404 everywhere: loader returns false")
check(string.find(lastNotice(), "private repository", 1, true) ~= nil, "404: user is told about the private-repo case")
check(consoles() == 0 and COUNT_CONNECTIONS() == 0, "404: nothing created, nothing connected")

-- 2. Successful download.
HTTP_MODE = "ok"
HTTP_CALLS = 0
result = main()
frames(20)
check(result == true, "download: loader returns true")
check(HTTP_CALLS == moduleCount, "download: one request per module (" .. HTTP_CALLS .. "/" .. moduleCount .. ")")
check(consoles() == 1, "download: console created")
local cached = 0
for path in pairs(SOURCES) do
    if FILES["VEYL/cache/" .. path] == SOURCES[path] then cached += 1 end
end
check(cached == moduleCount, "download: complete copy cached (" .. cached .. ")")
KEY("X")
KEY("Z")
frames(30)
check(#ERRORS == 0, "download: features run without errors")

-- 3. Network down: falls back to the cache and replaces the running session.
HTTP_MODE = "error"
result = main()
frames(10)
check(result == true and consoles() == 1, "network error: cached copy loaded, still one console")

-- 4. Local mode from the workspace folder.
for path, body in pairs(SOURCES) do FILES["VEYL/" .. path] = body end
SHARED.VEYL_SOURCE = "local"
result = main()
frames(10)
check(result == true and consoles() == 1, "local mode: loaded from VEYL/src")
SHARED.VEYL_SOURCE = nil

-- 5. A module with a syntax error: nothing runs, the current session keeps running.
HTTP_MODE = "ok"
local goodEsp = SOURCES["src/esp.lua"]
SOURCES["src/esp.lua"] = "-- VEYL module: esp\nreturn function(V)\n    local broken = \nend\n"
result = main()
frames(5)
check(result == false and string.find(lastNotice(), "Syntax error in src/esp.lua", 1, true) ~= nil, "syntax error: load refused with the module name")
check(consoles() == 1 and SHARED.__VEYL_SESSION ~= nil, "syntax error: running session left untouched")
SOURCES["src/esp.lua"] = goodEsp

-- 6. A module that fails while starting: partial state is released.
local goodMisc = SOURCES["src/pages/misc.lua"]
SOURCES["src/pages/misc.lua"] = "-- VEYL module: pages/misc\nreturn function(V)\n    error(\"boom\")\nend\n"
result = main()
frames(5)
check(result == false and string.find(lastNotice(), "src/pages/misc.lua failed", 1, true) ~= nil, "start failure: reported with the module name")
check(consoles() == 0, "start failure: partially built console removed")
SOURCES["src/pages/misc.lua"] = goodMisc

-- 7. Bad VEYL_SOURCE value.
SHARED.VEYL_SOURCE = "http://insecure.example/"
result = main()
check(result == false and string.find(lastNotice(), "https://", 1, true) ~= nil, "non-https source rejected")
SHARED.VEYL_SOURCE = nil

-- 8. Clean load and final shutdown.
result = main()
frames(10)
check(result == true and consoles() == 1, "reload after failures works")
SHARED.__VEYL_SESSION.shutdown("test")
frames(5)
check(consoles() == 0 and COUNT_CONNECTIONS() == 0, "shutdown: no console, no connections")
local live = 0
for _ in pairs(DRAWINGS.live) do live += 1 end
check(live == 0, "shutdown: no Drawing objects left")
check(#ERRORS == 0, "no runtime errors (" .. #ERRORS .. ")")
print(string.format("RESULT: %d failure(s), %d error(s)", failures, #ERRORS))
