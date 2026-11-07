--===========================================================================
-- EzWoW - Error Catcher
-- Modules/IssueReport.lua : Hides the Issue Reporter Frame & the "F6" Bug Line on Tooltips
--===========================================================================
local _, ns = ...
local type, ipairs, pcall = type, ipairs, pcall

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function stripColors(text)
    if type(text) ~= "string" then return "" end
    return strtrim((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
end

-- Nothing is hidden before login: the one-time settings move below needs every addon's
-- saved variables, which are only all loaded by then.
local ready = false

function ns.ShouldHideIssueReport()
    return ready and ns.db ~= nil and ns.db.hideIssueReport ~= false
end

-- One time: this option used to live in EzWoW-Tooltip. Keep a choice made there
-- (its per-character profile when that was used).
local function migrateFromTooltip()
    local db = ns.db
    if not db or db.migratedIssueReport then return end
    db.migratedIssueReport = true
    local global = _G.EzWoW_TooltipDB
    if type(global) ~= "table" then return end
    local general = type(global.general) == "table" and global.general or nil
    local value = general and general.hideIssueReport
    local perChar = _G.EzWoW_TooltipPerCharDB
    if general and general.SavedVariablesPerCharacter and type(perChar) == "table" and type(perChar.general) == "table"
        and perChar.general.hideIssueReport ~= nil then
        value = perChar.general.hideIssueReport
    end
    if value == false then db.hideIssueReport = false end
end

local function isBugLine(text)
    if not text or text == "" then return false end
    local lower = string.lower(text)
    if lower:find("to submit an issue", 1, true)
        or lower:find("submit an issue for this", 1, true)
        or lower:find("to submit a bug", 1, true)
        or lower:find("issue report", 1, true)
        or lower:find("bug report", 1, true)
        or lower:match("^press .+ to submit") then
        return true
    end
    if (text:find("이슈", 1, true) or text:find("버그", 1, true) or text:find("오류", 1, true))
        and (text:find("제보", 1, true) or text:find("신고", 1, true)) then
        return true
    end
    return false
end

-----------------------------------------------------------------------------
-- Issue reporter frame
-----------------------------------------------------------------------------
-- The reporter's own functions are left untouched (replacing them would spread taint).
local reporterHooked = false
local reporterHiddenByUs = false

function ns.UpdateIssueReportState()
    local reporter = _G.PTR_IssueReporter
    if type(reporter) ~= "table" or type(reporter.Hide) ~= "function" then return end
    if not reporterHooked then
        reporterHooked = true
        if type(reporter.Show) == "function" then
            hooksecurefunc(reporter, "Show", function(self)
                if ns.ShouldHideIssueReport() then self:Hide() end
            end)
        end
        if reporter.HookScript then
            pcall(reporter.HookScript, reporter, "OnShow", function(self)
                if ns.ShouldHideIssueReport() then self:Hide() end
            end)
        end
    end
    if ns.ShouldHideIssueReport() then
        reporter:Hide()
        reporterHiddenByUs = true
    elseif reporterHiddenByUs then
        -- show it once when the option is turned off; never force it visible later
        reporterHiddenByUs = false
        if type(reporter.Show) == "function" then pcall(reporter.Show, reporter) end
    end
end

-----------------------------------------------------------------------------
-- "Press F6 to submit a bug" tooltip line
-----------------------------------------------------------------------------
-- per-tooltip state lives in our own weak tables, never as fields on the game's tooltips
local hiddenRows = setmetatable({}, { __mode = "k" })     -- tooltip -> rows we hid
local clearHooked = setmetatable({}, { __mode = "k" })    -- tooltip -> OnTooltipCleared hooked

local function restoreRows(tip)
    local rows = tip and hiddenRows[tip]
    if not rows then return end
    hiddenRows[tip] = nil
    for _, row in ipairs(rows) do row:Show() end
end

local function hideRow(tip, row)
    row:SetText(nil)
    row:Hide()
    local rows = hiddenRows[tip]
    if not rows then
        rows = {}
        hiddenRows[tip] = rows
        if not clearHooked[tip] and tip.HasScript and tip:HasScript("OnTooltipCleared") then
            clearHooked[tip] = true
            tip:HookScript("OnTooltipCleared", restoreRows)
        end
    end
    rows[#rows + 1] = row
end

-- Only tooltips that are on screen; hidden scanning tooltips of other addons are left alone.
local UI_TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip" }
local function isScreenTooltip(tip)
    if type(tip) ~= "table" then return false end
    if tip.IsForbidden and tip:IsForbidden() then return false end
    for _, name in ipairs(UI_TOOLTIPS) do
        if _G[name] == tip then return true end
    end
    local name = tip.GetName and plain(tip:GetName())
    if type(name) == "string" and name:lower():find("scan", 1, true) then return false end
    if type(tip.IsVisible) ~= "function" or not tip:IsVisible() then return false end
    if type(tip.GetNumPoints) == "function" and tip:GetNumPoints() == 0 then return false end
    return true
end

function ns.RemoveBugLine(tip)
    if not ns.ShouldHideIssueReport() or not isScreenTooltip(tip) then return end
    local tipName = tip.GetName and plain(tip:GetName())
    if type(tipName) ~= "string" or not tip.NumLines then return end
    local changed = false
    for index = (tip:NumLines() or 0), 2, -1 do
        local left = _G[tipName .. "TextLeft" .. index]
        local text = left and plain(left:GetText())
        if type(text) == "string" and text ~= "" and isBugLine(stripColors(text)) then
            hideRow(tip, left)
            changed = true
            local prev = _G[tipName .. "TextLeft" .. (index - 1)]
            local prevText = prev and plain(prev:GetText())
            if prev and (not prevText or prevText == "" or prevText == " ") then hideRow(tip, prev) end
        end
    end
    if changed and tip:IsShown() then pcall(tip.Show, tip) end
end

for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tip and tip.HookScript then
        tip:HookScript("OnShow", function(self) ns.RemoveBugLine(self) end)
    end
end
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AllTypes then
    pcall(TooltipDataProcessor.AddTooltipPostCall, TooltipDataProcessor.AllTypes, function(tip)
        ns.RemoveBugLine(tip)
    end)
end

-----------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------
local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        migrateFromTooltip()
        ready = true
    end
    if not ready then return end
    ns.UpdateIssueReportState()
    if event ~= "ADDON_LOADED" and C_Timer and C_Timer.After then
        -- the reporter can show itself again right after loading
        C_Timer.After(0.2, ns.UpdateIssueReportState)
        C_Timer.After(1.0, ns.UpdateIssueReportState)
    end
end)
