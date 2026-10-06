-- Grammar Fixer (on-device) for Hammerspoon
-- Hotkey: Ctrl + Option + Cmd + G
--
-- Works in any app:
--   * If text is selected, that text is corrected.
--   * In chat-style apps (SELECT_ALL_APPS), if nothing is selected, the whole
--     message box is selected automatically (Cmd+A) and corrected.
--   * In all other apps, select the text first. Cmd+A there could select a whole
--     document, so the script won't do it for you.
-- Proofreading runs locally via ~/Projects/grammarfix/grammarfix
-- (Apple's on-device model). Nothing leaves your Mac.

local GRAMMARFIX = os.getenv("HOME") .. "/Projects/grammarfix/grammarfix"
local HOTKEY_MODS, HOTKEY_KEY = {"ctrl", "alt", "cmd"}, "G"
local MAX_CHARS = 5000   -- beyond this the on-device model struggles; also guards against accidental select-all

-- Apps where Cmd+A in a text box selects only that box, so auto-select is safe.
local SELECT_ALL_APPS = {
  ["com.tinyspeck.slackmacgap"]      = true,  -- Slack
  ["com.anthropic.claudefordesktop"] = true,  -- Claude desktop app
  ["com.microsoft.teams2"]           = true,  -- Microsoft Teams
  ["Cisco-Systems.Spark"]            = true,  -- Webex
  ["com.apple.MobileSMS"]            = true,  -- Messages
  ["com.google.Chrome"]              = true,  -- Chrome
  ["com.apple.Safari"]               = true,  -- Safari
  ["com.microsoft.edgemac"]          = true,  -- Edge
  ["company.thebrowser.Browser"]     = true,  -- Arc
  ["org.mozilla.firefox"]            = true,  -- Firefox
}

-- Apps where the hotkey is disabled (Cmd+C with no selection copies a whole line,
-- and you don't want grammar "fixes" in code anyway).
local BLOCKED_APPS = {
  ["com.microsoft.VSCode"]             = true,
  ["com.todesktop.230313mzl4w4u92"]    = true,  -- Cursor
  ["com.apple.dt.Xcode"]               = true,
  ["com.apple.Terminal"]               = true,
  ["com.googlecode.iterm2"]            = true,
  ["dev.warp.Warp-Stable"]             = true,
}

local currentTask = nil   -- keep a reference so the task isn't garbage-collected

local function trim(s)
  local t = (s or ""):gsub("^%s+", "")
  t = t:gsub("%s+$", "")
  return t
end

local function isBlocked(bundleID)
  if not bundleID then return true end
  if BLOCKED_APPS[bundleID] then return true end
  if bundleID:match("^com%.jetbrains%.") then return true end  -- IntelliJ, PyCharm, etc.
  return false
end

local function restoreClipboard(saved)
  hs.timer.doAfter(0.5, function()
    if saved then hs.pasteboard.writeAllData(saved) end
  end)
end

if not hs.fs.attributes(GRAMMARFIX) then
  hs.alert.show("Grammar fix: " .. GRAMMARFIX .. " not found", 5)
end

hs.hotkey.bind(HOTKEY_MODS, HOTKEY_KEY, function()
  local app = hs.application.frontmostApplication()
  local bundleID = app and app:bundleID()

  if isBlocked(bundleID) then
    hs.alert.show("Grammar fix is off in this app")
    return
  end

  if currentTask and currentTask:isRunning() then
    hs.alert.show("Grammar fix: already working…")
    return
  end

  local saved = hs.pasteboard.readAllData()
  local startCount = hs.pasteboard.changeCount()

  -- Try copying the current selection first.
  hs.eventtap.keyStroke({"cmd"}, "c", 0)
  hs.timer.usleep(150000)

  if hs.pasteboard.changeCount() == startCount then
    if SELECT_ALL_APPS[bundleID] then
      -- Chat-style app: select the whole message box and copy that.
      hs.eventtap.keyStroke({"cmd"}, "a", 0)
      hs.eventtap.keyStroke({"cmd"}, "c", 0)
      hs.timer.usleep(150000)
    else
      hs.alert.show("Grammar fix: select text first")
      return
    end
  end

  local text = hs.pasteboard.getContents()
  if hs.pasteboard.changeCount() == startCount or not text or text:match("^%s*$") then
    hs.alert.show("Grammar fix: nothing to correct")
    restoreClipboard(saved)
    return
  end

  if #text > MAX_CHARS then
    hs.alert.show("Grammar fix: text too long (" .. #text .. " chars, max " .. MAX_CHARS .. ")", 3)
    restoreClipboard(saved)
    return
  end

  -- Hand the text to grammarfix through a temp file.
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  f:write(text)
  f:close()

  local working = hs.alert.show("Correcting…", 30)

  currentTask = hs.task.new(GRAMMARFIX, function(exitCode, stdOut, stdErr)
    os.remove(tmp)
    hs.alert.closeSpecific(working)

    if exitCode ~= 0 then
      local msg = trim(stdErr)
      if msg == "" then msg = "exit code " .. tostring(exitCode) end
      hs.alert.show("Grammar fix: " .. msg, 4)
      restoreClipboard(saved)
      return
    end

    local corrected = stdOut or ""
    if trim(corrected) == "" then
      hs.alert.show("Grammar fix: no output")
      restoreClipboard(saved)
      return
    end

    if trim(corrected) == trim(text) then
      hs.alert.show("No changes needed ✓")
      restoreClipboard(saved)
      return
    end

    -- Make sure you're still in the same app before pasting.
    local front = hs.application.frontmostApplication()
    if not front or front:bundleID() ~= bundleID then
      hs.pasteboard.setContents(corrected)
      hs.alert.show("You switched apps — corrected text is on your clipboard")
      return
    end

    hs.pasteboard.setContents(corrected)
    hs.eventtap.keyStroke({"cmd"}, "v", 0)
    hs.alert.show("Fixed ✓")
    restoreClipboard(saved)
  end, { tmp })

  currentTask:start()
end)

hs.alert.show("Grammar fixer (on-device) loaded")
