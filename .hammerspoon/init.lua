-- ~/.hammerspoon/init.lua
-- Keyboard-driven window management, vim-style.
-- Reload with hyper+R, or just save this file (auto-reload is set up below).

----------------------------------------------------------------------
-- Config
----------------------------------------------------------------------

-- Disable animations so window moves feel instant.
hs.window.animationDuration = 0

-- "Hyper" = cmd+alt+ctrl. Add shift for the "heavier" variants.
local hyper      = { "cmd", "alt", "ctrl" }
local hyperShift = { "cmd", "alt", "ctrl", "shift" }

----------------------------------------------------------------------
-- Auto-reload config on save
----------------------------------------------------------------------

local function reloadConfig(files)
  for _, file in ipairs(files) do
    if file:sub(-4) == ".lua" then
      hs.reload()
      return
    end
  end
end

hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
hs.alert.show("Hammerspoon config loaded")

hs.hotkey.bind(hyper, "R", function() hs.reload() end)

----------------------------------------------------------------------
-- Start JankyBorders (github.com/FelixKratz/JankyBorders)
----------------------------------------------------------------------
-- Equivalent of AeroSpace's `after-startup-command`. Kill any running
-- instance first so config reloads don't stack copies, then relaunch
-- detached (trailing `&`) so borders keeps running independent of
-- Hammerspoon — otherwise each reload would kill and restart it.

hs.execute(
  "/usr/bin/pkill -x borders; " ..
  "/opt/homebrew/bin/borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0 " ..
  ">/dev/null 2>&1 &",
  false
)

----------------------------------------------------------------------
-- Window movement helpers
----------------------------------------------------------------------

-- Move focused window to a fractional rect of its screen.
-- x, y, w, h are all 0..1 fractions of the usable screen frame.
local function moveToRect(x, y, w, h)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:screen():frame()
    win:setFrame({
      x = f.x + (f.w * x),
      y = f.y + (f.h * y),
      w = f.w * w,
      h = f.h * h,
    })
  end
end

-- Halves
hs.hotkey.bind(hyper, "Left",  moveToRect(0,   0,   0.5, 1))
hs.hotkey.bind(hyper, "Right", moveToRect(0.5, 0,   0.5, 1))
hs.hotkey.bind(hyper, "Up",    moveToRect(0,   0,   1,   0.5))
hs.hotkey.bind(hyper, "Down",  moveToRect(0,   0.5, 1,   0.5))

-- Quarters (hyper+shift+arrow = top-left, top-right, etc.)
hs.hotkey.bind(hyperShift, "Left",  moveToRect(0,   0,   0.5, 0.5))
hs.hotkey.bind(hyperShift, "Right", moveToRect(0.5, 0,   0.5, 0.5))
hs.hotkey.bind(hyperShift, "Up",    moveToRect(0.5, 0.5, 0.5, 0.5))  -- bottom-right; tweak if you prefer
hs.hotkey.bind(hyperShift, "Down",  moveToRect(0,   0.5, 0.5, 0.5))

-- Thirds (handy on ultrawides)
hs.hotkey.bind(hyper, "D", moveToRect(0,    0, 1/3, 1))  -- left third
hs.hotkey.bind(hyper, "F", moveToRect(1/3,  0, 1/3, 1))  -- middle third
hs.hotkey.bind(hyper, "G", moveToRect(2/3,  0, 1/3, 1))  -- right third

-- Two-thirds
hs.hotkey.bind(hyperShift, "D", moveToRect(0,   0, 2/3, 1))  -- left two-thirds
hs.hotkey.bind(hyperShift, "G", moveToRect(1/3, 0, 2/3, 1))  -- right two-thirds

-- Fullscreen / maximize the usable area (respects menu bar + Dock)
hs.hotkey.bind(hyper, "M", moveToRect(0, 0, 1, 1))

-- Center at a comfortable size (good for floating utility windows)
hs.hotkey.bind(hyper, "C", moveToRect(1/8, 1/8, 6/8, 6/8))

-- Numpad layout mirrors screen regions: 7/8/9 top row, 4/5/6 middle,
-- 1/2/3 bottom row. Requires Num Lock on.
hs.hotkey.bind(hyper, "pad7", moveToRect(0,   0,   0.5, 0.5))  -- top-left
hs.hotkey.bind(hyper, "pad8", moveToRect(0,   0,   1,   0.5))  -- top half
hs.hotkey.bind(hyper, "pad9", moveToRect(0.5, 0,   0.5, 0.5))  -- top-right
hs.hotkey.bind(hyper, "pad4", moveToRect(0,   0,   0.5, 1))    -- left half
hs.hotkey.bind(hyper, "pad5", moveToRect(0,   0,   1,   1))    -- maximize
hs.hotkey.bind(hyper, "pad6", moveToRect(0.5, 0,   0.5, 1))    -- right half
hs.hotkey.bind(hyper, "pad1", moveToRect(0,   0.5, 0.5, 0.5))  -- bottom-left
hs.hotkey.bind(hyper, "pad2", moveToRect(0,   0.5, 1,   0.5))  -- bottom half
hs.hotkey.bind(hyper, "pad3", moveToRect(0.5, 0.5, 0.5, 0.5))  -- bottom-right

----------------------------------------------------------------------
-- Nudge the focused window (option + hjkl)
----------------------------------------------------------------------
-- Option+h/j/k/l shifts the focused window by `nudgeStep` pixels.
-- Hold the key to keep moving (auto-repeat).

local nudgeStep = 50

local function nudge(dx, dy)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()
    f.x = f.x + dx
    f.y = f.y + dy
    win:setFrame(f)
  end
end

hs.hotkey.bind({ "alt" }, "H", nudge(-nudgeStep, 0), nil, nudge(-nudgeStep, 0))
hs.hotkey.bind({ "alt" }, "L", nudge( nudgeStep, 0), nil, nudge( nudgeStep, 0))
hs.hotkey.bind({ "alt" }, "K", nudge(0, -nudgeStep), nil, nudge(0, -nudgeStep))
hs.hotkey.bind({ "alt" }, "J", nudge(0,  nudgeStep), nil, nudge(0,  nudgeStep))

----------------------------------------------------------------------
-- Move between displays
----------------------------------------------------------------------

hs.hotkey.bind(hyper, "[", function()
  local win = hs.window.focusedWindow()
  if win then win:moveToScreen(win:screen():previous(), true, true) end
end)

hs.hotkey.bind(hyper, "]", function()
  local win = hs.window.focusedWindow()
  if win then win:moveToScreen(win:screen():next(), true, true) end
end)

----------------------------------------------------------------------
-- Focus navigation (vim-style hjkl) — the AeroSpace replacement
----------------------------------------------------------------------
-- These move keyboard focus to the window in the given direction,
-- across all visible windows on all screens.

hs.hotkey.bind(hyper, "H", function()
  local win = hs.window.focusedWindow()
  if win then win:focusWindowWest(nil, true, true) end
end)
hs.hotkey.bind(hyper, "L", function()
  local win = hs.window.focusedWindow()
  if win then win:focusWindowEast(nil, true, true) end
end)
hs.hotkey.bind(hyper, "K", function()
  local win = hs.window.focusedWindow()
  if win then win:focusWindowNorth(nil, true, true) end
end)
hs.hotkey.bind(hyper, "J", function()
  local win = hs.window.focusedWindow()
  if win then win:focusWindowSouth(nil, true, true) end
end)

----------------------------------------------------------------------
-- App launcher / focuser
----------------------------------------------------------------------
-- hyper+<letter> launches the app if it isn't running, otherwise
-- focuses it. Edit this table to taste.

local appBindings = {
  T = "Ghostty",       -- or "iTerm", "Terminal", "Alacritty", etc.
  E = "Zed",
  B = "Google Chrome",
  S = "Slack",
  N = "Obsidian",
}

for key, app in pairs(appBindings) do
  hs.hotkey.bind(hyperShift, key, function()
    hs.application.launchOrFocus(app)
  end)
end

----------------------------------------------------------------------
-- Window hints (visual picker for any window) — bonus
----------------------------------------------------------------------
-- Press hyper+/ to overlay letters on every visible window; press a
-- letter to jump focus there. Great for "where did that window go".

-- hs.hints.style = "vimperator"
hs.hotkey.bind(hyper, "/", function()
  hs.hints.windowHints()
end)
