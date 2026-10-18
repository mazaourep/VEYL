-- VEYL module: pages/music
-- Loaded by loader.lua (or dist/VEYL.lua). Receives the shared context table V.
return function(V)
    local Util = V.Util
    local Settings = V.Settings
    local UI = V.UI
    local Music = V.Music
    local Features = V.Features
    local Root = V.Root
    local T = V.T
    local make = V.make
    local corner = V.corner
    local text = V.text
    local isPress = V.isPress
    local Pages = V.Pages
    local rowButton = V.rowButton

    -- MUSIC --------------------------------------------------------------------
    function Pages.music()
        local page = UI.page("Music")
        local now = UI.section(page, "left", "Now playing")
        local titleRow = UI.info(now, { label = "Track", desc = "Title from Roblox asset info when available; otherwise the asset ID." })
        local assetRow = UI.info(now, { label = "Asset", desc = "Canonical asset ID and creator." })
        local statusRow = UI.info(now, { label = "Status", desc = "Loading, permission and playback state reported by Roblox." })

        local progressRow, _ = UI.row(now, 22, { label = "Progress", desc = "Click to seek once the asset has loaded." })
        local bar = make("TextButton", { Position = UDim2.new(0, 4, 0.5, -3), Size = UDim2.new(1, -96, 0, 6), BackgroundColor3 = T.line, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, progressRow)
        corner(bar, 3)
        local barFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.cyan, BorderSizePixel = 0 }, bar)
        corner(barFill, 3)
        local timeLabel = text(progressRow, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.fromOffset(84, 22), Text = "0:00 / 0:00", TextSize = 11, Font = T.mono, TextXAlignment = Enum.TextXAlignment.Right })
        Root:connect(bar.InputBegan, function(input)
            if isPress(input) then
                Music.seek((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1))
            end
        end)

        local transport = UI.buttons(now, {
            { text = "‹‹ Prev", callback = Music.previous },
            { text = "▶ Play", style = "primary", callback = Music.togglePlay },
            { text = "■ Stop", callback = function()
                Music.stop()
            end },
            { text = "Next ››", callback = function()
                Music.next(false)
            end },
        }, "Previous restarts the track if more than 3 s have played.")
        UI.slider(now, { key = "music.volume", label = "Volume", suffix = "%", desc = "Session volume. Mute overrides it." })
        UI.toggle(now, { key = "music.muted", label = "Mute", desc = "Set the Sound volume to zero." })
        UI.toggle(now, { key = "music.shuffle", label = "Shuffle", desc = "Pick a random different track when advancing." })
        UI.dropdown(now, { key = "music.repeatMode", label = "Repeat", desc = "Off, repeat one track, or repeat the whole queue." })
        UI.button(now, {
            text = "Reset player settings",
            desc = "Restore volume, mute, shuffle, repeat and the favorites filter.",
            callback = function()
                Features.resetFeature("Music")
            end,
        })

        local add = UI.section(page, "left", "Add a Roblox audio asset")
        UI.input(add, {
            label = "Audio asset ID",
            placeholder = "1234567890 or rbxassetid://1234567890",
            buttonText = "Add",
            desc = "Only audio this experience is permitted to use will load.",
            onSubmit = Music.add,
        })
        UI.note(add, "Playback uses a Roblox Sound in SoundService. Private, removed or unpermitted assets fail to load and the failure is shown above. Nothing is downloaded or re-hosted.")

        local queueSection = UI.section(page, "right", "Queue")
        local queueFilter = ""
        UI.filterBox(queueSection, "Search queue…", function(value)
            queueFilter = value
            Music.changed:Fire()
        end)
        UI.toggle(queueSection, { key = "music.favoritesOnly", label = "Favorites only", desc = "Show only starred tracks." })
        local queueCount = UI.info(queueSection, { label = "Tracks", desc = "Session queue (saved with the config when a file API exists)." })
        local queueList = UI.list(queueSection, "The queue is empty.")
        UI.button(queueSection, {
            text = "Clear queue…",
            style = "danger",
            desc = "Stop playback and remove every track.",
            callback = function()
                UI.confirm("Clear queue", "Remove all " .. #Music.queue .. " tracks from the queue?", "Clear", Music.clear)
            end,
        })

        local function buildTrackRow(track)
            return function(frame, maid)
                local title = text(frame, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -150, 0, 16), Font = T.fontMedium, Text = track.title })
                local detail = text(frame, { Position = UDim2.fromOffset(8, 19), Size = UDim2.new(1, -150, 0, 14), TextSize = 10, TextColor3 = T.muted, Text = "" })
                local remove = rowButton(frame, "×", 4, 22, "danger", maid)
                local down = rowButton(frame, "↓", 30, 22, "default", maid)
                local up = rowButton(frame, "↑", 56, 22, "default", maid)
                local star = rowButton(frame, "☆", 82, 22, "default", maid)
                local play = rowButton(frame, "▶", 108, 34, "primary", maid)
                maid:connect(play.Activated, function()
                    Music.play(track)
                end)
                maid:connect(star.Activated, function()
                    Music.toggleFavorite(track)
                end)
                maid:connect(up.Activated, function()
                    Music.move(track, -1)
                end)
                maid:connect(down.Activated, function()
                    Music.move(track, 1)
                end)
                maid:connect(remove.Activated, function()
                    Music.remove(track)
                end)
                return function(index)
                    local playing = Music.current == track
                    title.Text = (playing and "♪ " or "") .. track.title
                    title.TextColor3 = playing and T.cyan or T.text
                    local info = "rbxassetid://" .. track.id
                    if track.creator then
                        info = info .. " · " .. track.creator
                    end
                    if track.info == "notAudio" then
                        info = info .. " · " .. (track.warning or "not audio")
                    elseif track.info == "unavailable" then
                        info = info .. " · asset info unavailable"
                    end
                    detail.Text = info
                    detail.TextColor3 = track.info == "notAudio" and T.warn or T.muted
                    star.Text = track.favorite and "★" or "☆"
                    star.TextColor3 = track.favorite and T.warn or T.text
                    frame.LayoutOrder = index
                    local visible = (not Settings.get("music.favoritesOnly") or track.favorite)
                        and (queueFilter == "" or string.find(string.lower(track.title .. " " .. track.id), queueFilter, 1, true) ~= nil)
                    frame.Visible = visible
                    return visible
                end
            end
        end

        local function syncQueue()
            local present = {}
            local visibleCount = 0
            for index, track in ipairs(Music.queue) do
                present[track] = true
                local entry = queueList.get(track) or queueList.add(track, 38, buildTrackRow(track))
                if entry and entry.update(index) then
                    visibleCount += 1
                end
            end
            for track in pairs(queueList.rows) do
                if not present[track] then
                    queueList.remove(track)
                end
            end
            queueCount.set(string.format("%d of %d shown", visibleCount, #Music.queue))
        end
        Root:give(Music.changed:Connect(syncQueue))
        Root:give(Settings.on("music.favoritesOnly", syncQueue))

        local providers = UI.section(page, "right", "Provider bookmarks")
        UI.input(providers, {
            label = "Bookmark URL",
            placeholder = "Label | https://open.spotify.com/…",
            buttonText = "Save",
            desc = "Spotify, YouTube Music or YouTube links. Optional label before a | character.",
            onSubmit = Music.addBookmark,
        })
        local bookmarkList = UI.list(providers, "No bookmarks saved.")
        UI.note(providers, "Bookmarks are links only. Roblox cannot play Spotify or YouTube Music, and VEYL does not open, stream, scrape or proxy them. Copy a link to open it in your browser.", T.warn)

        local function syncBookmarks()
            local present = {}
            for index, bookmark in ipairs(Music.bookmarks) do
                present[bookmark] = true
                local entry = bookmarkList.get(bookmark) or bookmarkList.add(bookmark, 38, function(frame, maid)
                    text(frame, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -96, 0, 16), Font = T.fontMedium, Text = bookmark.label .. "  ·  " .. bookmark.provider })
                    text(frame, { Position = UDim2.fromOffset(8, 19), Size = UDim2.new(1, -96, 0, 14), TextSize = 10, TextColor3 = T.muted, Text = bookmark.url })
                    local remove = rowButton(frame, "×", 4, 22, "danger", maid)
                    local copy = rowButton(frame, "Copy link", 30, 58, "default", maid)
                    maid:connect(copy.Activated, function()
                        UI.copy("Bookmark link", bookmark.url)
                    end)
                    maid:connect(remove.Activated, function()
                        Music.removeBookmark(bookmark)
                    end)
                    return function(order)
                        frame.LayoutOrder = order
                    end
                end)
                if entry then
                    entry.update(index)
                end
            end
            for bookmark in pairs(bookmarkList.rows) do
                if not present[bookmark] then
                    bookmarkList.remove(bookmark)
                end
            end
        end
        Root:give(Music.bookmarksChanged:Connect(syncBookmarks))
        syncQueue()
        syncBookmarks()

        local playButton = transport.buttons[2]
        page.updateInterval = 0.2
        page.onUpdate = function()
            local track = Music.current
            titleRow.set(track and track.title or "No track", track and T.text or T.muted)
            assetRow.set(track and (track.id .. (track.creator and (" · " .. track.creator) or "")) or "—", T.muted)
            statusRow.set(Music.status, Music.statusColor)
            local sound = Music.sound
            if sound and sound.Parent and sound.IsLoaded and sound.TimeLength > 0 then
                barFill.Size = UDim2.fromScale(math.clamp(sound.TimePosition / sound.TimeLength, 0, 1), 1)
                timeLabel.Text = Util.formatTime(sound.TimePosition) .. " / " .. Util.formatTime(sound.TimeLength)
            else
                barFill.Size = UDim2.fromScale(0, 1)
                timeLabel.Text = sound and "loading…" or "0:00 / 0:00"
            end
            playButton.Text = Music.isPlaying() and "❚❚ Pause" or "▶ Play"
        end
    end
end
