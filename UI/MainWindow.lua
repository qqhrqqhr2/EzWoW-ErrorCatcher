--===========================================================================
-- EzWoW - Error Catcher
-- UI/MainWindow.lua : Error list + copyable details, launcher icon, slash
--===========================================================================
local _, ns = ...
local type, ipairs, tostring, pcall = type, ipairs, tostring, pcall

local UIKit = ns.UIKit
local WIDTH, HEIGHT = 820, 520
local LIST_WIDTH = 300

local window, launcher, optionsPanel, copyBox
local selected

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
local function S() return ns.Style end

local function kindColor(entry)
    if entry.kind == "error" then return S().accent end
    return S().warning
end

-- entries from older sessions also show the date ("11/06 13:05:22")
local function clockText(t, entry)
    if not t or t == 0 or type(date) ~= "function" then return "" end
    if entry and ns.db and entry.session ~= ns.db.session then
        return date("%m/%d %H:%M:%S", t)
    end
    return date("%H:%M:%S", t)
end

local function fullText(entry)
    local parts = { entry.message or "" }
    if entry.stack and entry.stack ~= "" then
        parts[#parts + 1] = "\n---- " .. ns:L("stack") .. " ----\n" .. entry.stack
    end
    if entry.locals and entry.locals ~= "" then
        parts[#parts + 1] = "\n---- " .. ns:L("locals") .. " ----\n" .. entry.locals
    end
    return table.concat(parts, "\n")
end

-----------------------------------------------------------------------------
-- List rows
-----------------------------------------------------------------------------
local function createRow(list)
    local row = CreateFrame("Button", nil, list, "BackdropTemplate")
    UIKit:ApplyBackdrop(row)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT", 1, -1)
    row.bar:SetPoint("BOTTOMLEFT", 1, 1)
    row.bar:SetWidth(3)
    row.addon = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.addon:SetPoint("TOPLEFT", 10, -5)
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("TOPRIGHT", -8, -6)
    row.msg = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.msg:SetPoint("BOTTOMLEFT", 10, 6)
    row.msg:SetJustifyH("LEFT")
    row.msg:SetTextColor(rgba(S().textMuted))
    row:SetScript("OnClick", function(self)
        selected = self.entry
        ns.RefreshWindow()
    end)
    row:SetScript("OnEnter", function(self) self.hover = true ns.PaintRow(self) end)
    row:SetScript("OnLeave", function(self) self.hover = false ns.PaintRow(self) end)
    return row
end

function ns.PaintRow(row)
    local isSelected = row.entry and row.entry == selected
    if isSelected then
        row:SetBackdropColor(rgba(S().bgAccent))
        row:SetBackdropBorderColor(rgba(S().accent))
    elseif row.hover then
        row:SetBackdropColor(rgba(S().bgHover))
        row:SetBackdropBorderColor(rgba(S().border))
    else
        row:SetBackdropColor(rgba(S().bgSecondary))
        row:SetBackdropBorderColor(rgba(S().border))
    end
end

local function updateRow(row, entry)
    row.entry = entry
    local color = kindColor(entry)
    row.bar:SetColorTexture(rgba(color))
    local width = row:GetWidth() or 0
    if width < 100 then width = LIST_WIDTH - 12 end
    row.count:SetText(((entry.count or 1) > 1 and ("x" .. entry.count .. "  ") or "") .. clockText(entry.last, entry))
    ns.FitText(row.addon, entry.addon or "?", width - 30 - (row.count:GetStringWidth() or 60), 12, 9)
    row.addon:SetTextColor(rgba(color))
    local first = (entry.message or ""):match("^[^\n]*") or ""
    first = first:gsub("^.-[Aa]dd[Oo]ns[/\\][^/\\]+[/\\]", "")
    ns.FitText(row.msg, first, width - 18, 11, 11)
    ns.PaintRow(row)
end

-----------------------------------------------------------------------------
-- Detail box (scrollable, selectable text for copying)
-----------------------------------------------------------------------------
local function createDetail(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UIKit:ApplyBackdrop(box)
    box:SetBackdropColor(rgba(S().bgInput))
    box:SetBackdropBorderColor(rgba(S().border))

    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -14, 8)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetTextColor(rgba(S().textBody))
    edit:SetWidth(400)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- read-only: typing puts the original text back
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and box.text then
            self:SetText(box.text)
            self:HighlightText()
        end
    end)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset = scroll:GetVerticalScroll()
        local view = scroll:GetHeight()
        y = -y
        if y < offset then
            scroll:SetVerticalScroll(y)
        elseif y + height > offset + view then
            scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), y + height - view))
        end
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    scroll:SetScript("OnSizeChanged", function(self, w) edit:SetWidth(math.max(50, w)) end)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)

    function box:SetDetail(text)
        self.text = text or ""
        edit:SetText(self.text)
        edit:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
    end
    function box:SelectAll()
        edit:SetFocus()
        edit:HighlightText()
    end
    box.edit = edit
    return box
end

-----------------------------------------------------------------------------
-- Window
-----------------------------------------------------------------------------
local function buildWindow()
    window = CreateFrame("Frame", "EzWoWErrorCatcherMain", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
    local pos = ns.db.frames.main
    if type(pos) == "table" and pos[1] then
        window:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        window:SetPoint("CENTER")
    end
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    UIKit:ApplyBackdrop(window, 1, 1)
    window:SetBackdropColor(rgba(S().bgPrimary))
    window:SetBackdropBorderColor(rgba(S().border))
    window.OnMoved = function(self)
        local point, _, relPoint, x, y = self:GetPoint(1)
        ns.db.frames.main = { point, relPoint, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
    end
    if UISpecialFrames then tinsert(UISpecialFrames, "EzWoWErrorCatcherMain") end

    local top = UIKit:CreateHeader(window, ns.TITLE)
    window.subtitle = top.subtitle
    window.subtitle:SetWidth(560)
    local close = UIKit:CreateCloseButton(top, function() window:Hide() end)
    close:SetPoint("TOPRIGHT", top, "TOPRIGHT", -10, -10)

    -- list
    window.list = UIKit:CreateScrollList(window, 40, 3, 2, createRow, updateRow)
    window.list:SetPoint("TOPLEFT", 12, -70)
    window.list:SetPoint("BOTTOMLEFT", 12, 76)
    window.list:SetWidth(LIST_WIDTH)
    window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.empty:SetPoint("CENTER", window.list, "CENTER", 0, 0)
    window.empty:SetWidth(LIST_WIDTH - 30)
    window.empty:SetTextColor(rgba(S().textMuted))

    -- detail
    local left = 12 + LIST_WIDTH + 10
    window.info = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.info:SetPoint("TOPLEFT", left + 2, -76)
    window.info:SetJustifyH("LEFT")
    window.info:SetTextColor(rgba(S().textMuted))
    window.copyBtn = UIKit:CreateButton(window, 120, 24, "", true, "GameFontHighlightSmall")
    window.copyBtn:SetPoint("TOPRIGHT", -12, -70)
    window.copyBtn:SetScript("OnClick", function() window.detail:SelectAll() end)
    window.removeBtn = UIKit:CreateButton(window, 100, 24, "", false, "GameFontHighlightSmall")
    window.removeBtn:SetPoint("RIGHT", window.copyBtn, "LEFT", -6, 0)
    window.removeBtn:SetScript("OnClick", function()
        if selected then
            ns.RemoveEntry(selected)
            selected = nil
        end
    end)
    window.detail = createDetail(window)
    window.detail:SetPoint("TOPLEFT", left, -100)
    window.detail:SetPoint("BOTTOMRIGHT", -12, 76)

    -- options row
    local function check(x, key, after)
        local c, t = UIKit:CreateCheck(window, function(value)
            ns.db[key] = value
            if after then after(value) end
            ns.RefreshWindow()
        end)
        c:SetPoint("BOTTOMLEFT", x, 40)
        return { check = c, label = t, key = key }
    end
    window.checks = {
        check(12, "onlyEzWoW"),
        check(172, "showOlder"),
        check(332, "chatNotice"),
        check(492, "showIcon", function(value) ns.SetLauncherShown(value) end),
        check(652, "hideIssueReport", function() if ns.UpdateIssueReportState then ns.UpdateIssueReportState() end end),
    }
    -- the issue reporter option explains itself on hover
    local issueCheck = window.checks[5].check
    issueCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local accent = S().accent
        GameTooltip:AddLine(ns:L("opt_hideIssueReport"), accent[1], accent[2], accent[3])
        GameTooltip:AddLine(ns:L("tip_hideIssueReport"), 0.929, 0.957, 0.969, true)
        GameTooltip:Show()
    end)
    issueCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    window.clearBtn = UIKit:CreateButton(window, 130, 24, "", false, "GameFontHighlightSmall")
    window.clearBtn:SetPoint("BOTTOMLEFT", 12, 10)
    window.clearBtn:SetScript("OnClick", function()
        selected = nil
        ns.ClearLog()
    end)
    window.testBtn = UIKit:CreateButton(window, 130, 24, "", false, "GameFontHighlightSmall")
    window.testBtn:SetPoint("LEFT", window.clearBtn, "RIGHT", 6, 0)
    window.testBtn:SetScript("OnClick", ns.MakeTestError)
    window.langBtn = UIKit:CreateButton(window, 160, 24, "", false, "GameFontHighlightSmall")
    window.langBtn:SetPoint("LEFT", window.testBtn, "RIGHT", 6, 0)
    local langItems = {}
    for i, v in ipairs(ns.LANGUAGE_OPTIONS) do langItems[i] = { value = v[1], text = v[2] } end
    ns.LanguageDropdown.Attach(window.langBtn, {
        items = langItems,
        colors = { accent = ns.Style.accent },
        get = function() return ns.db.language end,
        set = function(code)
            ns.db.language = code
            ns.RefreshWindow()
        end,
    })
    window.donateBtn = UIKit:CreateButton(window, 150, 24, "", true, "GameFontHighlightSmall")
    window.donateBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    window.donateBtn:SetScript("OnClick", function() ns.ShowDonatePopup() end)
    window.version = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.version:SetPoint("RIGHT", window.donateBtn, "LEFT", -10, 0)

    window:SetScript("OnShow", function()
        ns.MarkSeen()
        ns.RefreshWindow()
    end)
    -- start hidden: a new frame is shown, and the first toggle would hide it
    window:Hide()
end

function ns.RefreshWindow()
    if ns.RefreshLauncher then ns.RefreshLauncher() end
    if not window or not window:IsShown() then return end
    local entries = ns.GetEntries()
    local stillThere = false
    for _, e in ipairs(entries) do if e == selected then stillThere = true break end end
    if not stillThere then selected = entries[1] end

    window.subtitle:SetText(string.format(ns:L("subtitle"), ns.SessionCount(), #ns.GetLog()))
    window.list:SetData(entries, true)
    window.empty:SetText(ns:L("empty"))
    window.empty:SetShown(#entries == 0)

    if selected then
        local kindText = ns:L("kind_" .. (selected.kind or "error"))
        window.info:SetText(string.format("%s  ·  %s  ·  x%d  ·  %s ~ %s", selected.addon or "?", kindText,
            selected.count or 1, clockText(selected.first, selected), clockText(selected.last, selected)))
        if window.detail.text ~= fullText(selected) then window.detail:SetDetail(fullText(selected)) end
    else
        window.info:SetText("")
        window.detail:SetDetail("")
    end
    window.copyBtn:SetLabel(ns:L("selectAll"))
    window.copyBtn:SetEnabledState(selected ~= nil)
    window.removeBtn:SetLabel(ns:L("remove"))
    window.removeBtn:SetEnabledState(selected ~= nil)

    for _, item in ipairs(window.checks) do
        item.check:SetChecked(ns.db[item.key] and true or false)
        ns.FitText(item.label, ns:L("opt_" .. item.key), 128, 12, 9)
    end
    window.clearBtn:SetLabel(ns:L("clearAll"))
    window.testBtn:SetLabel(ns:L("test"))
    window.langBtn:SetLabel(ns:L("language") .. ": " .. ns:GetLanguageDisplayLabel() .. " ▼")
    window.donateBtn:SetLabel(ns:L("donate"))
    local ver = ns.GetVersion()
    window.version:SetText((ver ~= "" and ("v" .. ver .. "  ·  ") or "") .. "/ezerr")
end

function ns.ToggleWindow()
    if not ns.db then return end
    if not window then buildWindow() end
    window:SetShown(not window:IsShown())
    if window:IsShown() then window:Raise() end
end

ns.OnNewError(function() ns.RefreshWindow() end)

-----------------------------------------------------------------------------
-- Donate popup
-----------------------------------------------------------------------------
function ns.ShowDonatePopup()
    if not copyBox then
        copyBox = CreateFrame("Frame", "EzWoWErrorCatcherDonate", UIParent, "BackdropTemplate")
        copyBox:SetSize(390, 116)
        copyBox:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        UIKit:ApplyBackdrop(copyBox)
        copyBox:SetBackdropColor(S().bgPrimary[1], S().bgPrimary[2], S().bgPrimary[3], 0.98)
        copyBox:SetBackdropBorderColor(rgba(S().accent))
        copyBox.label = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        copyBox.label:SetPoint("TOP", 0, -14)
        copyBox.label:SetTextColor(rgba(S().accent))
        local box, edit = UIKit:CreateEditBox(copyBox, 346, 27)
        box:SetPoint("TOP", 0, -43)
        box:SetFrameLevel(copyBox:GetFrameLevel() + 5)
        edit:SetText(ns.DONATE_URL)
        edit:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
        edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        edit:SetScript("OnEnterPressed", function() copyBox:Hide() end)
        edit:SetScript("OnTextChanged", function(self, userInput) if userInput then self:SetText(ns.DONATE_URL) self:HighlightText() end end)
        copyBox.edit = edit
        local close = UIKit:CreateCloseButton(copyBox, function() copyBox:Hide() end)
        close:SetPoint("TOPRIGHT", -6, -6)
    end
    copyBox.label:SetText(ns:L("copy"))
    UIKit:ElevateModal(copyBox, 260)
    copyBox:Show()
    copyBox.edit:SetFocus()
    copyBox.edit:HighlightText()
end

-----------------------------------------------------------------------------
-- Launcher icon (badge = new errors since the window was last opened)
-----------------------------------------------------------------------------
function ns.PlaceLauncherDefault(btn)
    btn:ClearAllPoints()
    btn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -258, -95)
end

function ns.CreateLauncher()
    if launcher or not ns.db then return launcher end
    launcher = CreateFrame("Button", "EzWoW_ErrorCatcherIcon", UIParent)
    launcher:SetSize(32, 32)
    launcher:SetFrameStrata("HIGH")
    launcher:SetClampedToScreen(true)
    launcher:SetMovable(true)
    launcher:RegisterForDrag("LeftButton")
    launcher:RegisterForClicks("LeftButtonUp")
    local icon = launcher:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(ns.MEDIA_PATH .. "Icon")
    launcher.icon = icon
    local hl = launcher:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(ns.MEDIA_PATH .. "Icon")
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.35)

    local badge = CreateFrame("Frame", nil, launcher, "BackdropTemplate")
    badge:SetSize(18, 16)
    badge:SetPoint("TOPRIGHT", 6, 4)
    UIKit:ApplyBackdrop(badge)
    badge:SetBackdropColor(0.55, 0.12, 0.10, 0.95)
    badge:SetBackdropBorderColor(rgba(S().accent))
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.text:SetPoint("CENTER")
    launcher.badge = badge

    local pos = ns.db.frames.icon
    if type(pos) == "table" and pos[1] then
        launcher:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        ns.PlaceLauncherDefault(launcher)
    end
    launcher:SetScript("OnDragStart", function(self) self.dragging = true self:StartMoving() end)
    launcher:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        ns.db.frames.icon = { point, relPoint, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
        C_Timer.After(0, function() self.dragging = false end)
    end)
    launcher:SetScript("OnClick", function(self) if not self.dragging then ns.ToggleWindow() end end)
    launcher:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.TITLE, rgba(S().accent))
        GameTooltip:AddLine(string.format(ns:L("iconCount"), ns.SessionCount(), ns.unseen), rgba(S().textBody))
        GameTooltip:AddLine(ns:L("iconHint"), rgba(S().textMuted))
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave", function() GameTooltip:Hide() end)
    launcher:SetShown(ns.db.showIcon)
    ns.RefreshLauncher()
    return launcher
end

function ns.RefreshLauncher()
    if not launcher then return end
    local unseen = ns.unseen or 0
    if unseen > 0 then
        launcher.badge.text:SetText(unseen > 99 and "99+" or tostring(unseen))
        launcher.badge:SetWidth(math.max(18, launcher.badge.text:GetStringWidth() + 8))
        launcher.badge:Show()
        launcher.icon:SetDesaturated(false)
        launcher:SetAlpha(1)
    else
        launcher.badge:Hide()
        local any = ns.SessionCount() > 0
        launcher.icon:SetDesaturated(not any)
        launcher:SetAlpha(any and 1 or 0.6)
    end
end

function ns.SetLauncherShown(show)
    ns.db.showIcon = show and true or false
    local btn = ns.CreateLauncher()
    if btn then btn:SetShown(ns.db.showIcon) end
end

-----------------------------------------------------------------------------
-- Blizzard settings launcher
-----------------------------------------------------------------------------
function ns:RegisterBlizzardOptions()
    if optionsPanel then return end
    optionsPanel = CreateFrame("Frame", "EzWoWErrorCatcherOptionsPanel", UIParent)
    optionsPanel.name = ns.TITLE
    local icon = optionsPanel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", 18, -18)
    icon:SetTexture(ns.MEDIA_PATH .. "Icon")
    local heading = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    heading:SetText(ns.TITLE)
    heading:SetTextColor(rgba(S().accent))
    local desc = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    local open = UIKit:CreateButton(optionsPanel, 220, 28, "", true)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    open:SetScript("OnClick", function() ns.ToggleWindow() end)
    optionsPanel.refreshText = function()
        desc:SetText(ns:L("panelDesc"))
        open:SetLabel(ns:L("panelOpen"))
    end
    optionsPanel:SetScript("OnShow", optionsPanel.refreshText)
    -- fill the texts now: the settings window does not always fire OnShow
    optionsPanel.refreshText()
    if Settings and type(Settings.RegisterCanvasLayoutCategory) == "function" and type(Settings.RegisterAddOnCategory) == "function" then
        local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, optionsPanel, ns.TITLE)
        if ok and cat then pcall(Settings.RegisterAddOnCategory, cat) end
    end
end

-----------------------------------------------------------------------------
-- Slash commands (/ezerr, /오류, /ezwowerrors)
-----------------------------------------------------------------------------
SLASH_EZWOWERRORCATCHER1 = "/ezerr"
SLASH_EZWOWERRORCATCHER2 = "/오류"
SLASH_EZWOWERRORCATCHER3 = "/ezwowerrors"

SlashCmdList.EZWOWERRORCATCHER = function(msg)
    if not ns.db then return end
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "clear" or msg == "지우기" then
        selected = nil
        ns.ClearLog()
        ns.Print(ns:L("cleared"))
    elseif msg == "test" or msg == "테스트" then
        ns.MakeTestError()
    elseif msg == "icon" or msg == "아이콘" then
        ns.db.frames.icon = nil
        ns.SetLauncherShown(true)
        ns.PlaceLauncherDefault(ns.CreateLauncher())
    else
        ns.ToggleWindow()
    end
end
