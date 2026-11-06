--===========================================================================
-- EzWoW - Error Catcher
-- Modules/Capture.lua : Collects Lua errors, blocked actions and Lua warnings
--===========================================================================
-- The game's error handler is wrapped, not replaced: every error still goes on
-- to the handler that was there before, so the default behaviour is unchanged.
local _, ns = ...
local type, ipairs, tostring, pcall, select = type, ipairs, tostring, pcall, select

local pending = {}        -- errors caught before the saved log is loaded
local listeners = {}
local chatNotice          -- set below (one chat line per new error)
ns.unseen = 0

-- saved text is cut to these lengths so a flood of long errors can't bloat the saved log
local MAX_MESSAGE, MAX_STACK, MAX_LOCALS = 1000, 4000, 2000
-- the window and launcher are refreshed at most this often (errors in OnUpdate fire every frame)
local NOTIFY_INTERVAL = 0.3

local function now() return time and time() or 0 end

local function safeString(value)
    if value == nil then return nil end
    if type(_G.issecretvalue) == "function" then
        local ok, secret = pcall(_G.issecretvalue, value)
        if ok and secret then return "<secret>" end
    end
    local ok, text = pcall(tostring, value)
    return ok and text or "?"
end

-- "Interface/AddOns/EzWoW-Bags/Core/Init.lua:12: ..." -> "EzWoW-Bags"
local function addonFromText(text)
    if type(text) ~= "string" then return nil end
    return text:match("[Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]")
end

function ns.OnNewError(fn)
    listeners[#listeners + 1] = fn
end

local notifyQueued, lastNotify = false, -1

local function flushNotify()
    notifyQueued = false
    lastNotify = GetTime and GetTime() or 0
    for _, fn in ipairs(listeners) do pcall(fn) end
end

-- batched: listeners run at most every NOTIFY_INTERVAL seconds
local function notify()
    if notifyQueued then return end
    local wait = NOTIFY_INTERVAL - ((GetTime and GetTime() or 0) - lastNotify)
    if wait <= 0 or not (C_Timer and C_Timer.After) then
        flushNotify()
        return
    end
    notifyQueued = true
    C_Timer.After(wait, flushNotify)
end

local function getLog()
    local log = _G.EzWoW_ErrorCatcherLog
    if type(log) ~= "table" then
        log = {}
        _G.EzWoW_ErrorCatcherLog = log
    end
    return log
end
ns.GetLog = getLog

local function prune(log)
    if #log <= ns.MAX_ENTRIES then return end
    table.sort(log, function(a, b) return (a.last or 0) > (b.last or 0) end)
    for i = #log, ns.MAX_ENTRIES + 1, -1 do log[i] = nil end
end

local function store(entry)
    local log = getLog()
    local session = ns.db and ns.db.session or 0
    for _, old in ipairs(log) do
        if old.session == session and old.key == entry.key then
            old.count = (old.count or 1) + 1
            old.last = entry.last
            if (not old.stack or old.stack == "") and entry.stack then old.stack = entry.stack end
            if (not old.locals or old.locals == "") and entry.locals then old.locals = entry.locals end
            notify()
            return
        end
    end
    entry.session = session
    log[#log + 1] = entry
    prune(log)
    ns.unseen = ns.unseen + 1
    if chatNotice then pcall(chatNotice, entry) end
    notify()
end

local function clip(text, maxLen)
    if text and #text > maxLen then return text:sub(1, maxLen) .. "..." end
    return text
end

-- kind: "error" | "blocked" | "warning"
local function record(kind, message, stack, locals, addon)
    message = clip(safeString(message) or "?", MAX_MESSAGE)
    stack = stack and clip(safeString(stack), MAX_STACK) or nil
    local entry = {
        kind = kind,
        message = message,
        stack = stack,
        locals = locals and clip(safeString(locals), MAX_LOCALS) or nil,
        addon = addon or addonFromText(message) or addonFromText(stack) or "?",
        count = 1,
        first = now(),
        last = now(),
    }
    entry.key = kind .. "\001" .. message
    if ns.db then
        store(entry)
    else
        pending[#pending + 1] = entry
    end
end
ns.Record = record

-----------------------------------------------------------------------------
-- Error handler hook
-----------------------------------------------------------------------------
local inHandler = false
local previousHandler     -- the very first handler found; never replaced
local outerHandler        -- a handler set over ours later (it may itself wrap ours)
local inChain = false     -- ours was called while another handler was on top

local function errorHandler(message, ...)
    -- re-entered through a handler that wraps ours: stop here, or the error loops forever
    if inHandler then return end
    inHandler = true
    if type(geterrorhandler) == "function" and geterrorhandler() ~= errorHandler then inChain = true end
    local okStack, stack = pcall(debugstack, 3)
    local okLocals, locals = false, nil
    if type(debuglocals) == "function" then okLocals, locals = pcall(debuglocals, 4) end
    pcall(record, "error", message, okStack and stack or nil, okLocals and locals or nil)
    -- the flag stays set while the other handlers run, so a way back to us ends above
    if outerHandler then pcall(outerHandler, message, ...) end
    local result
    if previousHandler then
        local ok, value = pcall(previousHandler, message, ...)
        if ok then result = value end
    end
    inHandler = false
    return result
end

local function installHandler()
    if type(seterrorhandler) ~= "function" or type(geterrorhandler) ~= "function" then return end
    local current = geterrorhandler()
    if current == errorHandler or inChain then return end
    if previousHandler == nil then
        previousHandler = current
    elseif current ~= previousHandler then
        -- something was set over ours: keep calling it (the guard above stops any loop)
        outerHandler = current
    end
    seterrorhandler(errorHandler)
end
-- as early as possible: errors from addons that load after this file are caught
installHandler()

-----------------------------------------------------------------------------
-- Events: blocked/forbidden actions and Lua warnings
-----------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MACRO_ACTION_BLOCKED", "LUA_WARNING", "PLAYER_REGEN_ENABLED" }) do
    pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) == ns.ADDON_NAME then
            ns:InitDB()
            for _, entry in ipairs(pending) do store(entry) end
            pending = {}
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        installHandler() -- in case something replaced it while loading
        if ns.CreateLauncher then ns.CreateLauncher() end
        if ns.RegisterBlizzardOptions then ns:RegisterBlizzardOptions() end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.FlushCombatNotice then ns.FlushCombatNotice() end
        return
    end
    if event == "LUA_WARNING" then
        local parts = {}
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            -- a secret string can't be joined: it is shown as a placeholder instead
            if type(value) == "string" then parts[#parts + 1] = safeString(value) end
        end
        record("warning", table.concat(parts, " "), nil, nil)
        return
    end
    -- ADDON_ACTION_BLOCKED / FORBIDDEN / MACRO_ACTION_BLOCKED: (addonName, functionName)
    -- no stack here: it would only be this event handler's own stack
    local addonName, functionName = ...
    local text = string.format("[%s] %s: %s()", event, safeString(addonName) or "?", safeString(functionName) or "?")
    record("blocked", text, nil, nil, safeString(addonName))
end)

-----------------------------------------------------------------------------
-- Queries
-----------------------------------------------------------------------------
function ns.GetEntries()
    local out = {}
    local db = ns.db
    if not db then return out end
    for _, entry in ipairs(getLog()) do
        local inSession = entry.session == db.session
        if (db.showOlder or inSession) and (not db.onlyEzWoW or (entry.addon or ""):find("^EzWoW")) then
            out[#out + 1] = entry
        end
    end
    table.sort(out, function(a, b) return (a.last or 0) > (b.last or 0) end)
    return out
end

function ns.SessionCount()
    local count = 0
    if not ns.db then return 0 end
    for _, entry in ipairs(getLog()) do
        if entry.session == ns.db.session then count = count + 1 end
    end
    return count
end

function ns.RemoveEntry(entry)
    local log = getLog()
    for i, e in ipairs(log) do
        if e == entry then table.remove(log, i) break end
    end
    flushNotify()
end

function ns.ClearLog()
    wipe(getLog())
    ns.unseen = 0
    flushNotify()
end

function ns.MarkSeen()
    ns.unseen = 0
    flushNotify()
end

-- /ezerr test : makes one harmless error so the capture can be checked
function ns.MakeTestError()
    C_Timer.After(0, function() error(ns:L("testError")) end)
end

-----------------------------------------------------------------------------
-- Chat notice (one line per new error, at most every 5 seconds)
-----------------------------------------------------------------------------
local lastNotice, held = 0, 0
local combatNotice        -- first new error seen in combat; printed when combat ends
chatNotice = function(entry)
    if not entry or not ns.db or not ns.db.chatNotice then return end
    if entry.addon == ns.ADDON_NAME then return end
    -- printing to chat in combat can taint the chat history: wait for combat to end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        if combatNotice then
            held = held + 1
        else
            combatNotice = entry
        end
        return
    end
    local t = GetTime and GetTime() or 0
    if t - lastNotice < 5 then
        held = held + 1
        return
    end
    lastNotice = t
    local first = (entry.message or ""):match("^[^\n]*") or ""
    if #first > 120 then first = first:sub(1, 117) .. "..." end
    local more = held > 0 and string.format(ns:L("noticeMore"), held) or ""
    held = 0
    ns.Print(string.format(ns:L("notice"), entry.addon or "?", first) .. more)
end

local function flushCombatNotice()
    local entry = combatNotice
    if not entry then return end
    combatNotice = nil
    lastNotice = -5 -- the held notice is shown now, not throttled
    chatNotice(entry)
end
ns.FlushCombatNotice = flushCombatNotice
