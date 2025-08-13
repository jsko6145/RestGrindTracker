-- Main addon frame
local addonFrame = CreateFrame("Frame")
local sessionStartTime = 0
local lastXP = 0

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
local function InitSavedData()
    if not RestGrindData then
        RestGrindData = {
            totalXP = 0,
            totalKills = 0,
            totalPlaytime = 0,
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
    RestGrindData.framePos = { point = point, x = x, y = y }
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
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0

    local sessionPlaytime = (GetTime() - sessionStartTime) / 3600
    local totalPlaytime = RestGrindData.totalPlaytime + sessionPlaytime
    local totalXP = RestGrindData.totalXP
    local totalKills = RestGrindData.totalKills
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

addonFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "RestGrindTracker" then
        InitSavedData()

    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        sessionStartTime = GetTime()
        lastXP = UnitXP("player")

        local pos = RestGrindData.framePos
        if pos and pos.point then
            display:ClearAllPoints()
            display:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        else
            display:SetPoint("CENTER")
        end

        UpdateDisplay()

    elseif event == "PLAYER_LOGOUT" then
        local sessionDuration = (GetTime() - sessionStartTime) / 3600
        RestGrindData.totalPlaytime = RestGrindData.totalPlaytime + sessionDuration

    elseif event == "PLAYER_XP_UPDATE" then
        local newXP = UnitXP("player")
        local gained = newXP - lastXP
        if gained < 0 then
            gained = (UnitXPMax("player") - lastXP) + newXP
        end

        if gained > 0 then
            RestGrindData.totalXP = RestGrindData.totalXP + gained
            RestGrindData.totalKills = RestGrindData.totalKills + 1
        end

        lastXP = newXP
        UpdateDisplay()
    end
end)
