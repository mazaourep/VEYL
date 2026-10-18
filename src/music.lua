-- VEYL module: music
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local SoundService = V.SoundService
    local MarketplaceService = V.MarketplaceService
    local ContentProvider = V.ContentProvider
    local NAMES = V.NAMES
    local LIMITS = V.LIMITS
    local Util = V.Util
    local Log = V.Log
    local Notify = V.Notify
    local Settings = V.Settings
    local Persist = V.Persist
    local Music = V.Music
    local Session = V.Session
    local Maid = V.Maid
    local T = V.T
    local make = V.make

    ----------------------------------------------------------------------------
    -- 17. Music Hub: Roblox audio assets via Sound; provider links are bookmarks
    ----------------------------------------------------------------------------

    Music.queue = {}
    Music.bookmarks = {}
    Music.current = nil
    Music.sound = nil
    Music.paused = false
    Music.loadState = "none"
    Music.status = "Idle"
    Music.statusColor = T.muted
    Music.changed = Util.signal()
    Music.bookmarksChanged = Util.signal()
    Music.infoQueue = {}
    Music.infoRunning = false

    local PROVIDERS = {
        ["open.spotify.com"] = "Spotify",
        ["spotify.link"] = "Spotify",
        ["music.youtube.com"] = "YouTube Music",
        ["www.youtube.com"] = "YouTube",
        ["youtube.com"] = "YouTube",
        ["m.youtube.com"] = "YouTube",
        ["youtu.be"] = "YouTube",
    }
    local CREDENTIAL_HINTS = { "token=", "access_token", "refresh_token", "code=", "client_secret", "password", "apikey", "api_key" }

    function Music.setStatus(message, color)
        Music.status = message
        Music.statusColor = color or T.muted
    end

    function Music.isPlaying()
        local sound = Music.sound
        return sound ~= nil and sound.Parent ~= nil and sound.IsPlaying and not Music.paused
    end

    function Music.normalize(raw)
        local value = Util.trim(raw)
        local id = string.match(value, "^rbxassetid://(%d+)$") or string.match(value, "^(%d+)$")
        if not id then
            return nil, "Enter a numeric asset ID (1234567890) or rbxassetid://1234567890."
        end
        id = string.gsub(id, "^0+", "")
        if id == "" or #id > 16 then
            return nil, "That asset ID is out of range."
        end
        return id
    end

    function Music.indexOf(track)
        return track and table.find(Music.queue, track) or nil
    end

    function Music.requestInfo(track)
        table.insert(Music.infoQueue, track)
        if Music.infoRunning then
            return
        end
        Music.infoRunning = true
        task.spawn(function()
            while Session.alive and #Music.infoQueue > 0 do
                local item = table.remove(Music.infoQueue, 1)
                if table.find(Music.queue, item) then
                    local ok, info = pcall(function()
                        return MarketplaceService:GetProductInfo(tonumber(item.id), Enum.InfoType.Asset)
                    end)
                    if ok and type(info) == "table" then
                        if info.AssetTypeId == 3 then
                            item.title = Util.truncate(tostring(info.Name or item.title), 60)
                            item.creator = type(info.Creator) == "table" and info.Creator.Name or nil
                            item.info = "ok"
                        else
                            item.info = "notAudio"
                            item.warning = "Asset type " .. tostring(info.AssetTypeId) .. " is not audio"
                        end
                    else
                        item.info = "unavailable"
                    end
                    Music.changed:Fire()
                    task.wait(0.25)
                end
            end
            Music.infoRunning = false
        end)
    end

    function Music.add(raw)
        local id, err = Music.normalize(raw)
        if not id then
            Notify.push(err, "warn")
            return false
        end
        for _, track in ipairs(Music.queue) do
            if track.id == id then
                Notify.push("Asset " .. id .. " is already in the queue.", "warn")
                return false
            end
        end
        if #Music.queue >= LIMITS.queue then
            Notify.push("The queue is limited to " .. LIMITS.queue .. " tracks.", "warn")
            return false
        end
        local track = { id = id, title = "Audio " .. id, favorite = false, info = "pending" }
        table.insert(Music.queue, track)
        Music.requestInfo(track)
        Log.add("info", "Queued audio asset " .. id .. ".")
        Music.changed:Fire()
        Persist.schedule()
        return true
    end

    function Music.applyVolume(sound)
        sound = typeof(sound) == "Instance" and sound or Music.sound
        if sound then
            sound.Volume = Settings.get("music.muted") and 0 or Settings.get("music.volume") / 100
        end
    end

    function Music.stop(keepStatus)
        if Music.trackMaid then
            Music.trackMaid:clean()
            Music.trackMaid = nil
        end
        Music.sound = nil
        Music.paused = false
        Music.loadState = "none"
        if not keepStatus then
            Music.setStatus("Stopped", T.muted)
            Music.changed:Fire()
        end
    end

    function Music.play(track)
        if not track then
            if #Music.queue == 0 then
                Notify.push("The queue is empty. Add a Roblox audio asset ID first.", "warn")
                return
            end
            track = Music.queue[1]
        end
        Music.stop(true)
        Music.current = track
        local maid = Maid.new()
        Music.trackMaid = maid
        local sound = make("Sound", { Name = NAMES.sound, SoundId = "rbxassetid://" .. track.id, Looped = false })
        sound:SetAttribute(NAMES.owned, true)
        Music.applyVolume(sound)
        sound.Parent = SoundService
        maid:give(sound)
        Music.sound = sound
        Music.loadState = "loading"
        Music.setStatus("Loading asset " .. track.id .. "…", T.muted)
        maid:connect(sound.Loaded, function()
            if Music.sound == sound then
                Music.loadState = "loaded"
                Music.setStatus(Music.paused and "Paused" or "Playing", T.ok)
            end
        end)
        maid:connect(sound.Ended, function()
            if Music.sound == sound then
                Music.onEnded()
            end
        end)
        task.spawn(function()
            local ok, err = pcall(function()
                ContentProvider:PreloadAsync({ sound }, function(_, status)
                    if Music.sound == sound and status == Enum.AssetFetchStatus.Failure then
                        Music.loadState = "failed"
                        Music.setStatus("Load failed: private, removed, not audio, or not permitted here", T.bad)
                        Notify.push("Audio " .. track.id .. " failed to load. It may be private, removed, or not permitted in this experience.", "warn")
                        Music.changed:Fire()
                    end
                end)
            end)
            if not ok and Music.sound == sound then
                Log.add("warn", "Audio load check failed: " .. tostring(err))
            end
        end)
        local ok, err = pcall(function()
            sound:Play()
        end)
        if not ok then
            Music.loadState = "failed"
            Music.setStatus("Playback failed", T.bad)
            Notify.push("Playback failed for " .. track.id .. ": " .. tostring(err), "error")
        end
        maid:delay(10, function()
            if Music.sound == sound and not sound.IsLoaded and Music.loadState == "loading" then
                Music.setStatus("Still loading — may be unavailable or not permitted", T.warn)
            end
        end)
        Music.changed:Fire()
    end

    function Music.togglePlay()
        local sound = Music.sound
        if sound and sound.Parent then
            if Music.paused then
                sound:Resume()
                Music.paused = false
                Music.setStatus(Music.loadState == "loaded" and "Playing" or "Loading…", Music.loadState == "loaded" and T.ok or T.muted)
            elseif sound.IsPlaying then
                sound:Pause()
                Music.paused = true
                Music.setStatus("Paused", T.muted)
            else
                sound:Play()
            end
            Music.changed:Fire()
            return
        end
        Music.play(Music.indexOf(Music.current) and Music.current or Music.queue[1])
    end

    function Music.next(automatic)
        local count = #Music.queue
        if count == 0 then
            if not automatic then
                Notify.push("The queue is empty.", "warn")
            end
            Music.stop()
            return
        end
        local index = Music.indexOf(Music.current) or 0
        local nextIndex
        if Settings.get("music.shuffle") and count > 1 then
            if index == 0 then
                nextIndex = math.random(1, count)
            else
                nextIndex = math.random(1, count - 1)
                if nextIndex >= index then
                    nextIndex += 1
                end
            end
        elseif index < count then
            nextIndex = index + 1
        elseif not automatic or Settings.get("music.repeatMode") == "All" then
            nextIndex = 1
        else
            Music.stop(true)
            Music.setStatus("Queue finished", T.muted)
            Music.changed:Fire()
            return
        end
        Music.play(Music.queue[nextIndex])
    end

    function Music.previous()
        local sound = Music.sound
        if sound and sound.IsLoaded and sound.TimePosition > 3 then
            sound.TimePosition = 0
            return
        end
        local count = #Music.queue
        if count == 0 then
            Notify.push("The queue is empty.", "warn")
            return
        end
        local index = Music.indexOf(Music.current) or 1
        Music.play(Music.queue[index > 1 and index - 1 or count])
    end

    function Music.onEnded()
        if Settings.get("music.repeatMode") == "One" and Music.sound then
            Music.sound.TimePosition = 0
            Music.sound:Play()
            return
        end
        Music.next(true)
    end

    function Music.seek(fraction)
        local sound = Music.sound
        if not (sound and sound.IsLoaded and sound.TimeLength > 0) then
            Notify.push("Seeking becomes available after the asset has loaded.", "info")
            return
        end
        sound.TimePosition = math.clamp(fraction, 0, 1) * sound.TimeLength
    end

    function Music.remove(track)
        local index = Music.indexOf(track)
        if not index then
            return
        end
        if track == Music.current then
            Music.stop()
            Music.current = nil
        end
        table.remove(Music.queue, index)
        Music.changed:Fire()
        Persist.schedule()
    end

    function Music.move(track, delta)
        local index = Music.indexOf(track)
        local target = index and index + delta
        if not target or target < 1 or target > #Music.queue then
            return
        end
        Music.queue[index], Music.queue[target] = Music.queue[target], Music.queue[index]
        Music.changed:Fire()
        Persist.schedule()
    end

    function Music.toggleFavorite(track)
        track.favorite = not track.favorite
        Music.changed:Fire()
        Persist.schedule()
    end

    function Music.clear()
        Music.stop()
        Music.current = nil
        table.clear(Music.queue)
        Music.changed:Fire()
        Persist.schedule()
    end

    function Music.validateUrl(raw)
        local url = Util.trim(raw)
        if url == "" then
            return nil, "Paste a Spotify or YouTube Music https:// link."
        end
        if #url > 300 then
            return nil, "That link is longer than 300 characters."
        end
        if string.find(url, "[%s%c]") then
            return nil, "Links cannot contain spaces or control characters."
        end
        local host = string.match(url, "^https://([^/%?#]+)")
        if not host then
            return nil, "Only https:// links are accepted."
        end
        host = string.lower(host)
        if string.find(host, "@", 1, true) or string.find(host, ":", 1, true) then
            return nil, "Links with embedded credentials or ports are not accepted."
        end
        local provider = PROVIDERS[host]
        if not provider then
            return nil, "Supported hosts: open.spotify.com, spotify.link, music.youtube.com, youtube.com, youtu.be."
        end
        local lower = string.lower(url)
        for _, hint in ipairs(CREDENTIAL_HINTS) do
            if string.find(lower, hint, 1, true) then
                return nil, "This link looks like it contains a credential, so it was not saved."
            end
        end
        return url, provider
    end

    function Music.addBookmark(raw)
        raw = Util.trim(raw)
        local label, rest = string.match(raw, "^(.-)%s*|%s*(%S+)$")
        local url, provider = Music.validateUrl(rest or raw)
        if not url then
            Notify.push(provider, "warn")
            return false
        end
        for _, bookmark in ipairs(Music.bookmarks) do
            if bookmark.url == url then
                Notify.push("That link is already bookmarked.", "warn")
                return false
            end
        end
        if #Music.bookmarks >= LIMITS.bookmarks then
            Notify.push("Bookmarks are limited to " .. LIMITS.bookmarks .. ".", "warn")
            return false
        end
        label = Util.truncate(Util.trim(label or ""), 40)
        table.insert(Music.bookmarks, { label = label ~= "" and label or provider, url = url, provider = provider })
        Music.bookmarksChanged:Fire()
        Persist.schedule()
        Notify.push("Bookmark saved. It opens outside Roblox; it does not play here.", "ok")
        return true
    end

    function Music.removeBookmark(bookmark)
        local index = table.find(Music.bookmarks, bookmark)
        if index then
            table.remove(Music.bookmarks, index)
            Music.bookmarksChanged:Fire()
            Persist.schedule()
        end
    end

    function Music.serialize()
        local queue, bookmarks = {}, {}
        for _, track in ipairs(Music.queue) do
            table.insert(queue, { id = track.id, favorite = track.favorite })
        end
        for _, bookmark in ipairs(Music.bookmarks) do
            table.insert(bookmarks, { label = bookmark.label, url = bookmark.url })
        end
        return { queue = queue, bookmarks = bookmarks }
    end

    function Music.loadTable(data)
        if type(data) ~= "table" then
            return
        end
        if type(data.queue) == "table" then
            local seen = {}
            for _, track in ipairs(Music.queue) do
                seen[track.id] = true
            end
            for _, item in ipairs(data.queue) do
                if type(item) == "table" and #Music.queue < LIMITS.queue then
                    local id = Music.normalize(tostring(item.id or ""))
                    if id and not seen[id] then
                        seen[id] = true
                        local track = { id = id, title = "Audio " .. id, favorite = item.favorite == true, info = "pending" }
                        table.insert(Music.queue, track)
                        Music.requestInfo(track)
                    end
                end
            end
        end
        if type(data.bookmarks) == "table" then
            for _, item in ipairs(data.bookmarks) do
                if type(item) == "table" and #Music.bookmarks < LIMITS.bookmarks then
                    local url, provider = Music.validateUrl(tostring(item.url or ""))
                    if url then
                        local label = type(item.label) == "string" and Util.truncate(Util.trim(item.label), 40) or ""
                        table.insert(Music.bookmarks, { label = label ~= "" and label or provider, url = url, provider = provider })
                    end
                end
            end
        end
        Music.changed:Fire()
        Music.bookmarksChanged:Fire()
    end

    V.PROVIDERS = PROVIDERS
    V.CREDENTIAL_HINTS = CREDENTIAL_HINTS
end
