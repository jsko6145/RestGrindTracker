-- Addon version tracking
local AddonVersion = "1.0.0"
-- Main addon frame
local addonFrame = CreateFrame("Frame")
local sessionStartTime = 0
local lastXP = 0
local timePlayedSeconds = nil -- populated via TIME_PLAYED_MSG
local timePlayedRequestPending = false
local timePlayedRequestAttempts = 0
local MAX_TIME_PLAYED_ATTEMPTS = 5

-- Exponential-ish backoff schedule in seconds
local timePlayedRetryDelays = {2, 5, 10, 20, 30}

local function RequestTimePlayedWithRetry()
    if timePlayedSeconds then return end -- already have data
    if timePlayedRequestPending then return end -- request already in flight
    if timePlayedRequestAttempts >= MAX_TIME_PLAYED_ATTEMPTS then return end -- give up

    timePlayedRequestPending = true
    timePlayedRequestAttempts = timePlayedRequestAttempts + 1
    RequestTimePlayed()

    -- Schedule a retry if still not populated after delay
    local attempt = timePlayedRequestAttempts
    local delay = timePlayedRetryDelays[attempt] or 30
    C_Timer.After(delay, function()
        if not timePlayedSeconds and timePlayedRequestAttempts == attempt then
            -- no response arrived (TIME_PLAYED_MSG would set timePlayedSeconds)
            timePlayedRequestPending = false
            RequestTimePlayedWithRetry()
        end
    end)
end

-- Classic XP required per level (1–60)
local XPToLevel60 = {
    400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, -- 1–10
    8700, 9800, 10900, 12000, 13300, 14600, 15900, 17300, 18800, 20300, -- 11–20
    21800, 23300, 24900, 26500, 28500, 30500, 32500, 34500, 37000, 39500, -- 21–30
    42000, 44500, 47500, 50500, 53500, 56500, 59500, 63000, 66500, 70000, -- 31–40
    73500, 77000, 81000, 85000, 89000, 93000, 97000, 101000, 105000, 109000, -- 41–50
    113000, 117000, 121000, 126000, 131000, 136000, 141000, 146000, 151000 -- 51–59
}
local MAX_LEVEL = 60

-- Initialize saved data
local function GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return realm .. "-" .. name
end

local function InitSavedData()
    if not RestGrindData then RestGrindData = {} end
    local charKey = GetCharKey()
    if not RestGrindData[charKey] then
        RestGrindData[charKey] = {
            totalXP = 0,
            totalKills = 0,
            -- totalPlaytime field removed; now relying on Blizzard /played API (TIME_PLAYED_MSG)
            framePos = { point = "CENTER", x = 0, y = 0 }
        }
    end
end

-- Format hours as readable string
local function FormatTime(hours)
    local h = math.floor(hours)
    local m = math.floor((hours - h) * 60)
    return string.format("%dh %dm", h, m)
end

-- Calculate total XP remaining to level 60
local function GetRemainingXPTo60()
    local level = UnitLevel("player")
    local currentXP = UnitXP("player")
    local remainingXP = 0

    for i = level, MAX_LEVEL - 1 do
        remainingXP = remainingXP + XPToLevel60[i]
    end

    remainingXP = remainingXP - currentXP
    return math.max(0, remainingXP)
end

-- Calculate XP remaining to next level
local function GetXPToNextLevel()
    local level = UnitLevel("player")
    if level >= MAX_LEVEL then return 0 end
    return UnitXPMax("player") - UnitXP("player")
end

-- Create movable UI frame
local display = CreateFrame("Frame", "RestGrindTrackerFrame", UIParent, "BackdropTemplate")
display:SetSize(360, 140)
display:SetMovable(true)
display:EnableMouse(true)
display:RegisterForDrag("LeftButton")
display:SetScript("OnDragStart", display.StartMoving)
display:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    local charKey = GetCharKey()
    if RestGrindData and RestGrindData[charKey] then
        RestGrindData[charKey].framePos = { point = point, x = x, y = y }
    end
end)

-- Set backdrop
display:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    tile = true, tileSize = 16
})
display:SetBackdropColor(0, 0, 0, 0.5)

-- Text
display.text = display:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
display.text:SetPoint("CENTER")

-- Update text
local function UpdateDisplay()
    local charKey = GetCharKey()
    local charData = RestGrindData[charKey]
    if not charData then return end

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0

    local sessionPlaytime = (GetTime() - sessionStartTime) / 3600
    local totalPlaytime
    if timePlayedSeconds then
        totalPlaytime = timePlayedSeconds / 3600
    else
        -- Fallback before TIME_PLAYED_MSG arrives: show session time only
        totalPlaytime = sessionPlaytime
    end
    local totalXP = charData.totalXP
    local totalKills = charData.totalKills
    local xpPerHour = totalPlaytime > 0 and (totalXP / totalPlaytime) or 0

    local xpTo60 = GetRemainingXPTo60()
    local estHoursTo60 = xpPerHour > 0 and (xpTo60 / xpPerHour) or 0

    local xpToNext = GetXPToNextLevel()
    local estHoursToNext = xpPerHour > 0 and (xpToNext / xpPerHour) or 0

    display.text:SetText(string.format(
        "Rested XP: %s\nTotal Kills: %d\nTotal XP: %s\nXP/hour: %.0f\nTime Played: %s\nTo Level 60: %s\nTo Next Level: %s",
        BreakUpLargeNumbers(restedXP),
        totalKills,
        BreakUpLargeNumbers(totalXP),
        xpPerHour,
        FormatTime(totalPlaytime),
        FormatTime(estHoursTo60),
        FormatTime(estHoursToNext)
    ))
end

-- Events
addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:RegisterEvent("PLAYER_LOGIN")
addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addonFrame:RegisterEvent("PLAYER_LOGOUT")
addonFrame:RegisterEvent("PLAYER_XP_UPDATE")
addonFrame:RegisterEvent("TIME_PLAYED_MSG")

addonFrame:SetScript("OnEvent", function(self, event, arg1)
    local charKey = GetCharKey()
    if event == "ADDON_LOADED" and arg1 == "RestGrindTracker" then
        InitSavedData()

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        sessionStartTime = GetTime()
        lastXP = UnitXP("player")

    -- Ask server for /played data (with retry in case of throttle)
    RequestTimePlayedWithRetry()

        local charData = RestGrindData[charKey]
        local pos = charData and charData.framePos or nil
        if pos and pos.point then
            display:ClearAllPoints()
            display:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        else
            display:SetPoint("CENTER")
        end

        UpdateDisplay()

    elseif event == "PLAYER_LOGOUT" then
        -- No manual accumulation needed; relying on Blizzard's /played tracking

    elseif event == "PLAYER_XP_UPDATE" then
        local charData = RestGrindData[charKey]
        if charData then
            local newXP = UnitXP("player")
            local gained = newXP - lastXP
            if gained < 0 then
                gained = (UnitXPMax("player") - lastXP) + newXP
            end

            if gained > 0 then
                charData.totalXP = charData.totalXP + gained
                charData.totalKills = charData.totalKills + 1
            end

            lastXP = newXP
            UpdateDisplay()
        end
    elseif event == "TIME_PLAYED_MSG" then
        -- event args: totalTimePlayed, levelTimePlayed
        timePlayedSeconds = arg1 -- total time played in seconds
        timePlayedRequestPending = false
        UpdateDisplay()
    end
end)
