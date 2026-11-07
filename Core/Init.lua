--===========================================================================
-- EzWoW - Error Catcher
-- Core/Init.lua : Namespace, EzWoW Style Palette, Helpers & SavedVariables
--===========================================================================
local ADDON_NAME, ns = ...
local type, pairs, tostring, pcall = type, pairs, tostring, pcall

_G.EzWoW_ErrorCatcher = ns

ns.ADDON_NAME = ADDON_NAME or "EzWoW-ErrorCatcher"
ns.TITLE = "EzWoW - Error Catcher"
ns.MEDIA_PATH = "Interface\\AddOns\\EzWoW-ErrorCatcher\\Media\\"
ns.DONATE_URL = "https://buymeacoffee.com/qqhrqqhr2"

-----------------------------------------------------------------------------
-- EzWoW Style v1.0 Palette (Brand Accent: Coral #E77C70)
-----------------------------------------------------------------------------
ns.Style = {
    bgPrimary   = { 0.071, 0.094, 0.122, 0.97 },
    bgSecondary = { 0.114, 0.157, 0.192, 0.96 },
    bgInput     = { 0.047, 0.067, 0.086, 0.96 },
    bgHover     = { 0.160, 0.210, 0.260, 1.00 },
    bgAccent    = { 0.220, 0.120, 0.110, 0.96 },
    bgAccentHot = { 0.300, 0.160, 0.150, 1.00 },
    border      = { 0.204, 0.298, 0.357, 1.00 },
    textBody    = { 0.929, 0.957, 0.969, 1.00 },
    textMuted   = { 0.655, 0.725, 0.773, 1.00 },
    accent      = { 0.906, 0.486, 0.439, 1.00 }, -- #E77C70
    accentHex   = "E77C70",
    warning     = { 0.950, 0.760, 0.330, 1.00 }, -- gold: blocked actions / warnings
    disabled    = { 0.388, 0.447, 0.482, 1.00 },
}

ns.MAX_ENTRIES = 300   -- kept across sessions (oldest dropped first)

ns.DEFAULTS = {
    language    = "auto",
    chatNotice  = true,
    showIcon    = true,
    onlyEzWoW   = false,
    showOlder   = false,
    hideIssueReport = true,   -- issue reporter frame and the "F6" bug line on tooltips
    frames      = {},
}

function ns.Print(msg)
    print("|cff" .. ns.Style.accentHex .. "EzWoW - Error Catcher:|r " .. tostring(msg or ""))
end

function ns.GetVersion()
    local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if type(getter) == "function" then
        local ok, ver = pcall(getter, ns.ADDON_NAME, "Version")
        if ok and type(ver) == "string" and ver ~= "" and not ver:find("^@") then
            return ver
        end
    end
    return ""
end

function ns.FitText(fs, text, maxWidth, baseSize, minSize)
    if not fs then return end
    text = text or ""
    fs:SetWordWrap(false)
    if fs.SetTextScale then fs:SetTextScale(1) end
    local font, rawSize, flags = fs:GetFont()
    if not font then
        fs:SetText(text)
        return
    end
    local function applySize(size)
        if fs.SetTextScale and rawSize and rawSize > 0 then
            fs:SetTextScale(size / rawSize)
        else
            fs:SetFont(font, size, flags)
        end
    end
    applySize(baseSize)
    fs:SetText(text)
    local size = baseSize
    while fs:GetStringWidth() > maxWidth and size > minSize do
        size = size - 0.5
        applySize(size)
    end
    if fs:GetStringWidth() > maxWidth then
        local original = text
        while #text > 0 and fs:GetStringWidth() > maxWidth do
            local cut = #text
            while cut > 1 and string.byte(text, cut) >= 128 and string.byte(text, cut) < 192 do
                cut = cut - 1
            end
            text = text:sub(1, cut - 1)
            fs:SetText(text .. "...")
            if text == original then break end
        end
    end
end

-----------------------------------------------------------------------------
-- SavedVariables (errors are kept in EzWoW_ErrorCatcherLog)
-----------------------------------------------------------------------------
function ns:InitDB()
    if type(_G.EzWoW_ErrorCatcherDB) ~= "table" then _G.EzWoW_ErrorCatcherDB = {} end
    local db = _G.EzWoW_ErrorCatcherDB
    for key, value in pairs(self.DEFAULTS) do
        if db[key] == nil then db[key] = (type(value) == "table") and {} or value end
    end
    if type(db.frames) ~= "table" then db.frames = {} end
    db.session = (tonumber(db.session) or 0) + 1
    self.db = db
    if ns.OnDBReady then ns.OnDBReady() end
end
