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

-- NOTE: must be kept in a persistent (global) variable — if the watcher
-- object is GC'd, file watching silently stops.
configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
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
-- Window movement undo
----------------------------------------------------------------------
-- Move helpers funnel through setFrameTracked, which pushes the
-- pre-move frame onto a per-window stack. hyper+U pops and restores.
-- Bounded by maxUndoWindows × maxUndoDepth — once we hit either cap
-- the LRU window (or oldest frame) is dropped, so the table never
-- grows without bound.
--
-- Held-key bindings (nudge, resize) push on every auto-repeat tick,
-- so holding hyper+U unwinds a held move at the same cadence.

local maxUndoWindows = 32
local maxUndoDepth   = 100

local undoStacks = {}  -- [winID] = { frame, frame, ... } oldest first
local undoOrder  = {}  -- winIDs in MRU order, most recent at end

local function touchUndoOrder(winID)
  for i, id in ipairs(undoOrder) do
    if id == winID then table.remove(undoOrder, i); break end
  end
  table.insert(undoOrder, winID)
  while #undoOrder > maxUndoWindows do
    local evicted = table.remove(undoOrder, 1)
    undoStacks[evicted] = nil
  end
end

-- Tolerance covers subpixel rounding (frame() returns the OS-rounded
-- frame; the requested rect is float math) and apps that snap to grid
-- cells (e.g. terminals to character widths). Without this, repeated
-- presses of the same binding stack near-duplicate frames.
local function framesNear(a, b)
  local tol = 8
  return math.abs(a.x - b.x) < tol
    and math.abs(a.y - b.y) < tol
    and math.abs(a.w - b.w) < tol
    and math.abs(a.h - b.h) < tol
end

-- Like win:setFrame, but records the prior frame for hyper+U to pop.
local function setFrameTracked(win, frame)
  local prev = win:frame()
  if framesNear(prev, frame) then return end
  local id = win:id()
  if id then
    local stack = undoStacks[id]
    if not stack then
      stack = {}
      undoStacks[id] = stack
    end
    table.insert(stack, prev)
    while #stack > maxUndoDepth do table.remove(stack, 1) end
    touchUndoOrder(id)
  end
  win:setFrame(frame)
end

local function undoLastMove()
  local win = hs.window.focusedWindow()
  if not win then return end
  local id = win:id()
  if not id then return end
  local stack = undoStacks[id]
  if not stack or #stack == 0 then return end
  -- Direct setFrame: undoing isn't itself undoable (no redo, by design).
  win:setFrame(table.remove(stack))
  if #stack == 0 then
    undoStacks[id] = nil
    for i, oid in ipairs(undoOrder) do
      if oid == id then table.remove(undoOrder, i); break end
    end
  end
end

-- Pop the most recently moved window's stack, regardless of focus.
-- Walks the LRU tail, skipping (and pruning) entries whose window has
-- closed. Shows a brief alert since the affected window may not be
-- on-screen of the user's focus.
local function undoLastMoveAnyWindow()
  while #undoOrder > 0 do
    local id = undoOrder[#undoOrder]
    local stack = undoStacks[id]
    local win = stack and #stack > 0 and hs.window.get(id) or nil
    if win then
      win:setFrame(table.remove(stack))
      local app = win:application()
      hs.alert.show("Undo: " .. (app and app:name() or "window"))
      if #stack == 0 then
        undoStacks[id] = nil
        table.remove(undoOrder)
      end
      return
    end
    -- Stale or empty entry — drop it and try the next.
    undoStacks[id] = nil
    table.remove(undoOrder)
  end
end

hs.hotkey.bind(hyper,      "U", undoLastMove,          nil, undoLastMove)
hs.hotkey.bind(hyperShift, "U", undoLastMoveAnyWindow, nil, undoLastMoveAnyWindow)

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
    setFrameTracked(win, {
      x = f.x + (f.w * x),
      y = f.y + (f.h * y),
      w = f.w * w,
      h = f.h * h,
    })
  end
end

-- Aspect ratio above which a screen is treated as "wide" (ultrawide
-- territory). 16:9 ≈ 1.78, 16:10 = 1.6, 21:9 ≈ 2.33, 32:9 ≈ 3.56 — so
-- 2.0 cleanly separates laptop/standard displays from ultrawides.
local wideScreenAspect = 2.0

-- Like moveToRect, but picks rect based on the focused window's screen.
-- Each arg is a { x, y, w, h } table of 0..1 fractions. Resolved at call
-- time so dragging a window between displays just works.
local function moveToRectByScreen(normal, wide)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:screen():frame()
    local r = (f.w / f.h > wideScreenAspect) and wide or normal
    setFrameTracked(win, {
      x = f.x + f.w * r[1],
      y = f.y + f.h * r[2],
      w = f.w * r[3],
      h = f.h * r[4],
    })
  end
end

-- Resolve fractional rect against a screen frame.
local function rectOf(s, x, y, w, h)
  return { x = s.x + s.w * x, y = s.y + s.h * y, w = s.w * w, h = s.h * h }
end

-- Toggle the focused window between fractional rects `a` and `b` on the
-- given screen frame `s`. Tolerance covers apps that don't quite honor
-- setFrame.
local function toggleFrame(win, s, a, b)
  local rectA = rectOf(s, a[1], a[2], a[3], a[4])
  local rectB = rectOf(s, b[1], b[2], b[3], b[4])
  setFrameTracked(win, framesNear(win:frame(), rectA) and rectB or rectA)
end

-- Toggle the focused window between two fractional rects. If it's already
-- at (or close to) the first, move to the second; otherwise move to the
-- first.
local function moveToRectToggle(a, b)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    toggleFrame(win, win:screen():frame(), a, b)
  end
end

-- Like moveToRectToggle, but picks the {A, B} pair based on the focused
-- window's screen aspect — so a single binding can be "right half ↔ right
-- two-thirds" on a standard display and "right third ↔ right two-thirds"
-- on an ultrawide. Each arg is a { a, b } pair of fractional rects.
local function moveToRectByScreenToggle(normal, wide)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local s = win:screen():frame()
    local pair = (s.w / s.h > wideScreenAspect) and wide or normal
    toggleFrame(win, s, pair[1], pair[2])
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

-- Fullscreen / maximize the usable area (respects menu bar + Dock).
-- Press again while maximized to drop to the centered "comfortable" size.
hs.hotkey.bind(hyper, "M", moveToRectToggle({ 0, 0, 1, 1 }, { 1/8, 1/8, 6/8, 6/8 }))

-- Center at a comfortable size (good for floating utility windows)
hs.hotkey.bind(hyper, "C", moveToRect(1/8, 1/8, 6/8, 6/8))

-- Numpad layout mirrors screen regions: 7/8/9 top row, 4/5/6 middle,
-- 1/2/3 bottom row. Requires Num Lock on.
--
-- On standard displays this is a 2x2 grid (halves + quarters). On
-- ultrawides it's a 3x2 grid (vertical thirds, full or half height) —
-- halves are awkwardly large on wide screens.
hs.hotkey.bind(hyper, "pad7", moveToRectByScreen({ 0,   0,   0.5, 0.5 }, { 0,   0,   1/3, 0.5 }))
hs.hotkey.bind(hyper, "pad8", moveToRectByScreen({ 0,   0,   1,   0.5 }, { 1/3, 0,   1/3, 0.5 }))
hs.hotkey.bind(hyper, "pad9", moveToRectByScreen({ 0.5, 0,   0.5, 0.5 }, { 2/3, 0,   1/3, 0.5 }))
hs.hotkey.bind(hyper, "pad4", moveToRectByScreenToggle(
  { { 0, 0, 0.5, 1   }, { 0,   0, 2/3, 1 } },  -- normal: left 1/2 ↔ left 2/3
  { { 0, 0, 1/3, 1   }, { 0,   0, 2/3, 1 } }   -- wide:   left 1/3 ↔ left 2/3
))
hs.hotkey.bind(hyper, "pad5", moveToRectByScreenToggle(
  { { 1/8, 1/8, 6/8, 6/8 }, { 1/6, 0, 2/3, 1 } },  -- normal: comfortable centered ↔ centered 2/3
  { { 1/3, 0,   1/3, 1   }, { 1/6, 0, 2/3, 1 } }   -- wide:   middle 1/3 ↔ centered 2/3
))
hs.hotkey.bind(hyper, "pad6", moveToRectByScreenToggle(
  { { 0.5, 0, 0.5, 1   }, { 1/3, 0, 2/3, 1 } },  -- normal: right 1/2 ↔ right 2/3
  { { 2/3, 0, 1/3, 1   }, { 1/3, 0, 2/3, 1 } }   -- wide:   right 1/3 ↔ right 2/3
))
hs.hotkey.bind(hyper, "pad1", moveToRectByScreen({ 0,   0.5, 0.5, 0.5 }, { 0,   0.5, 1/3, 0.5 }))
hs.hotkey.bind(hyper, "pad2", moveToRectByScreen({ 0,   0.5, 1,   0.5 }, { 1/3, 0.5, 1/3, 0.5 }))
hs.hotkey.bind(hyper, "pad3", moveToRectByScreen({ 0.5, 0.5, 0.5, 0.5 }, { 2/3, 0.5, 1/3, 0.5 }))
hs.hotkey.bind(hyper, "pad0", moveToRectToggle({ 0, 0, 1, 1 }, { 1/8, 1/8, 6/8, 6/8 }))  -- maximize / toggle to centered

----------------------------------------------------------------------
-- Re-tile the current screen
----------------------------------------------------------------------
-- Not a tiling WM — just one-shot rearrangers for when a screen gets
-- cluttered. Operate on all standard visible windows on the focused
-- window's screen; other screens are untouched.

local tileGap = 8  -- px between tiled windows (and screen edge)

-- Target aspect ratio (w/h) for individual cells in tileGrid. 1.6 ≈ 16:10
-- feels comfortable for most app windows. Lower values prefer taller
-- cells (more rows, fewer cols); higher values prefer wider cells.
local tileTargetAspect     = 1.2
local tileTargetAspectTall = 0.4   -- tall/narrow cells; e.g. for code panes on ultrawides

-- Per-screen state for reorderable tile order. screenWindowOrder[sid]
-- is the user-preferred sequence of window IDs; reconcileOrder keeps
-- it in sync with reality (drop closed, append new). screenLastTileFn
-- is replayed after a swap so the change is visible immediately.
-- tileSilent suppresses the "Tiled N" alert during those replays.
local screenWindowOrder = {}
local screenLastTileFn  = {}
local tileSilent        = false

-- Returns wins in the saved order for this screen. Closed-window IDs
-- drop out; windows not yet in the list append at the end (sorted by
-- ID for determinism — same behavior as the old pure ID sort, just
-- applied only to newcomers). Mutates screenWindowOrder.
local function reconcileOrder(screen, wins)
  local sid = screen:id()
  local saved = screenWindowOrder[sid] or {}
  local byID = {}
  for _, w in ipairs(wins) do byID[w:id()] = w end

  local ordered, seen = {}, {}
  for _, id in ipairs(saved) do
    if byID[id] then
      table.insert(ordered, byID[id])
      seen[id] = true
    end
  end

  local fresh = {}
  for _, w in ipairs(wins) do
    if not seen[w:id()] then table.insert(fresh, w) end
  end
  table.sort(fresh, function(a, b) return a:id() < b:id() end)
  for _, w in ipairs(fresh) do table.insert(ordered, w) end

  local ids = {}
  for _, w in ipairs(ordered) do table.insert(ids, w:id()) end
  screenWindowOrder[sid] = ids

  return ordered
end

local function windowsOnCurrentScreen()
  local focused = hs.window.focusedWindow()
  if not focused then return nil, {} end
  local screen = focused:screen()
  local screenID = screen:id()
  local wins = {}
  for _, w in ipairs(hs.window.visibleWindows()) do
    if w:isStandard() and w:screen():id() == screenID then
      table.insert(wins, w)
    end
  end
  return screen, reconcileOrder(screen, wins), focused
end

-- Distribute n windows across `cols` columns. The first (n mod cols)
-- columns get one extra row; the remainder get the floor. Returns a
-- per-column row count whose sum is exactly n — no empty cells.
--
-- E.g. n=9, cols=4 -> {3, 2, 2, 2}. The first column stacks 3 windows
-- at 1/3 height while the other three stack 2 each at 1/2 height.
local function distributeColumns(n, cols)
  local base, extra = math.floor(n / cols), n % cols
  local rowsPerCol = {}
  for c = 1, cols do
    rowsPerCol[c] = base + (c <= extra and 1 or 0)
  end
  return rowsPerCol
end

-- Pick `cols` to minimize the average distance between actual cell
-- aspect ratios (after uneven distribution) and the target aspect.
-- Cells in different columns may have different heights, so we score
-- each column's cell aspect individually and average. This generalizes
-- the old uniform-grid scoring and avoids picking grids that produce
-- ugly portrait stragglers.
local function chooseGridCols(n, screenAspect, targetAspect)
  local bestCols, bestScore = 1, math.huge
  for cols = 1, n do
    local rowsPerCol = distributeColumns(n, cols)
    local total = 0
    for _, rowsInCol in ipairs(rowsPerCol) do
      local cellAspect = screenAspect * rowsInCol / cols
      total = total + math.abs(math.log(cellAspect / targetAspect))
    end
    local score = total / cols
    if score < bestScore then
      bestCols, bestScore = cols, score
    end
  end
  return bestCols
end

-- Grid tile: pick the column count that gives the best average cell
-- aspect, then size each column's cells independently so every window
-- gets a slot and no space is wasted. Optional targetAspect overrides
-- the default (e.g. tileTargetAspectTall for narrow code-pane layouts).
local function tileGrid(targetAspect)
  targetAspect = targetAspect or tileTargetAspect
  local screen, wins = windowsOnCurrentScreen()
  if not screen or #wins == 0 then return end
  local f = screen:frame()
  local n = #wins
  local cols = chooseGridCols(n, f.w / f.h, targetAspect)
  local rowsPerCol = distributeColumns(n, cols)
  local cellW = (f.w - tileGap * (cols + 1)) / cols
  local idx = 1
  for c = 1, cols do
    local rowsInCol = rowsPerCol[c]
    local cellH = (f.h - tileGap * (rowsInCol + 1)) / rowsInCol
    local x = f.x + tileGap + (c - 1) * (cellW + tileGap)
    for r = 1, rowsInCol do
      setFrameTracked(wins[idx], {
        x = x,
        y = f.y + tileGap + (r - 1) * (cellH + tileGap),
        w = cellW,
        h = cellH,
      })
      idx = idx + 1
    end
  end
  if not tileSilent then
    hs.alert.show("Tiled " .. n .. " window" .. (n == 1 and "" or "s"))
  end
end

-- Master-stack: focused window gets one half; the rest stack
-- vertically on the other half. masterSide is "left" or "right".
local function tileMasterStack(masterSide)
  return function()
    local screen, wins, focused = windowsOnCurrentScreen()
    if not screen or #wins == 0 then return end
    local f = screen:frame()

    -- Put focused window first so it becomes the master.
    local ordered = { focused }
    for _, w in ipairs(wins) do
      if w:id() ~= focused:id() then table.insert(ordered, w) end
    end

    if #ordered == 1 then
      setFrameTracked(ordered[1], {
        x = f.x + tileGap, y = f.y + tileGap,
        w = f.w - 2 * tileGap, h = f.h - 2 * tileGap,
      })
      return
    end

    local halfW   = f.w / 2
    local cellW   = halfW - 1.5 * tileGap
    local leftX   = f.x + tileGap
    local rightX  = f.x + halfW + 0.5 * tileGap
    local masterX = (masterSide == "right") and rightX or leftX
    local stackX  = (masterSide == "right") and leftX  or rightX

    setFrameTracked(ordered[1], {
      x = masterX,
      y = f.y + tileGap,
      w = cellW,
      h = f.h - 2 * tileGap,
    })

    local stackN = #ordered - 1
    local stackH = (f.h - tileGap * (stackN + 1)) / stackN
    for i = 2, #ordered do
      setFrameTracked(ordered[i], {
        x = stackX,
        y = f.y + tileGap + (i - 2) * (stackH + tileGap),
        w = cellW,
        h = stackH,
      })
    end
    if not tileSilent then
      hs.alert.show("Master + " .. stackN .. " stacked")
    end
  end
end

-- Record which tile mode was last invoked on this screen, then run it.
-- Swap bindings replay this so reorders are visible without a manual
-- re-tile.
local function rememberTile(fn)
  return function()
    local focused = hs.window.focusedWindow()
    if focused then screenLastTileFn[focused:screen():id()] = fn end
    fn()
  end
end

-- Move the focused window `delta` slots in the per-screen tile order
-- and replay the last tile mode silently. Auto-repeats, so holding the
-- key ripples the window through the layout one cell per tick.
local function swapInOrder(delta)
  return function()
    local focused = hs.window.focusedWindow()
    if not focused then return end
    local sid = focused:screen():id()
    local order = screenWindowOrder[sid]
    if not order then return end
    local fid = focused:id()
    local idx
    for i, id in ipairs(order) do
      if id == fid then idx = i; break end
    end
    if not idx then return end
    local target = idx + delta
    if target < 1 or target > #order then return end
    order[idx], order[target] = order[target], order[idx]
    local fn = screenLastTileFn[sid]
    if fn then
      tileSilent = true
      local ok, err = pcall(fn)
      tileSilent = false
      if not ok then error(err) end
    end
  end
end

hs.hotkey.bind(hyper,      "T",    rememberTile(tileGrid))
hs.hotkey.bind(hyperShift, "T",    rememberTile(function() tileGrid(tileTargetAspectTall) end))
hs.hotkey.bind(hyper,      "pad/", rememberTile(tileGrid))
hs.hotkey.bind(hyper,      "pad*", rememberTile(function() tileGrid(tileTargetAspectTall) end))
hs.hotkey.bind(hyper,      "\\",   rememberTile(tileMasterStack("left")))
hs.hotkey.bind(hyperShift, "\\",   rememberTile(tileMasterStack("right")))

hs.hotkey.bind(hyperShift, "H",        swapInOrder(-1), nil, swapInOrder(-1))
hs.hotkey.bind(hyperShift, "L",        swapInOrder( 1), nil, swapInOrder( 1))
hs.hotkey.bind(hyper,      "padenter", swapInOrder(-1), nil, swapInOrder(-1))
hs.hotkey.bind(hyper,      "pad+",     swapInOrder( 1), nil, swapInOrder( 1))

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
    setFrameTracked(win, f)
  end
end

hs.hotkey.bind({ "alt" }, "H", nudge(-nudgeStep, 0), nil, nudge(-nudgeStep, 0))
hs.hotkey.bind({ "alt" }, "L", nudge( nudgeStep, 0), nil, nudge( nudgeStep, 0))
hs.hotkey.bind({ "alt" }, "K", nudge(0, -nudgeStep), nil, nudge(0, -nudgeStep))
hs.hotkey.bind({ "alt" }, "J", nudge(0,  nudgeStep), nil, nudge(0,  nudgeStep))

-- Numpad mirror: shift+alt+8/4/6/2 = up/left/right/down. Same step,
-- same auto-repeat. Bare alt+pad4/6/8/2 is reserved for focus nav.
hs.hotkey.bind({ "shift", "alt" }, "pad4", nudge(-nudgeStep, 0), nil, nudge(-nudgeStep, 0))
hs.hotkey.bind({ "shift", "alt" }, "pad6", nudge( nudgeStep, 0), nil, nudge( nudgeStep, 0))
hs.hotkey.bind({ "shift", "alt" }, "pad8", nudge(0, -nudgeStep), nil, nudge(0, -nudgeStep))
hs.hotkey.bind({ "shift", "alt" }, "pad2", nudge(0,  nudgeStep), nil, nudge(0,  nudgeStep))

----------------------------------------------------------------------
-- Grow / shrink the focused window around its center
----------------------------------------------------------------------
-- hyper + =  makes the window a bit bigger
-- hyper + -  makes the window a bit smaller
-- Holds for auto-repeat. Clamped to the screen's usable frame.

local resizeStep = 0.05  -- fraction of screen per tap (5% each dimension)
local minSize    = 200   -- px; don't let the window disappear

local function resize(factor)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local s = win:screen():frame()
    local f = win:frame()
    local dw = s.w * resizeStep * factor
    local dh = s.h * resizeStep * factor
    local cx = f.x + f.w / 2
    local cy = f.y + f.h / 2
    local nw = math.max(minSize, math.min(s.w, f.w + dw))
    local nh = math.max(minSize, math.min(s.h, f.h + dh))
    local nx = math.max(s.x, math.min(s.x + s.w - nw, cx - nw / 2))
    local ny = math.max(s.y, math.min(s.y + s.h - nh, cy - nh / 2))
    setFrameTracked(win, { x = nx, y = ny, w = nw, h = nh })
  end
end

hs.hotkey.bind(hyper, "=", resize( 1), nil, resize( 1))
hs.hotkey.bind(hyper, "-", resize(-1), nil, resize(-1))

----------------------------------------------------------------------
-- Move between displays
----------------------------------------------------------------------

local function moveWindowToPrevScreen()
  local win = hs.window.focusedWindow()
  if win then win:moveToScreen(win:screen():previous(), true, true) end
end

local function moveWindowToNextScreen()
  local win = hs.window.focusedWindow()
  if win then win:moveToScreen(win:screen():next(), true, true) end
end

hs.hotkey.bind(hyper, "[",        moveWindowToPrevScreen)
hs.hotkey.bind(hyper, "]",        moveWindowToNextScreen)
hs.hotkey.bind(hyper, "padclear", moveWindowToPrevScreen)
hs.hotkey.bind(hyper, "pad-",     moveWindowToNextScreen)

----------------------------------------------------------------------
-- Cycle Spaces (hyper+Tab)
----------------------------------------------------------------------
-- Uses hs.spaces (private SkyLight APIs). gotoSpace is much more
-- reliable with System Settings > Accessibility > Display > Reduce
-- Motion enabled — otherwise the Mission Control animation races.

-- Returns the next user-space ID after the currently focused one,
-- wrapping around within the screen that owns the focused space.
local function nextUserSpaceID()
  local focused = hs.spaces.focusedSpace()
  if not focused then return nil end
  for _, spaces in pairs(hs.spaces.allSpaces() or {}) do
    local userSpaces = {}
    for _, sid in ipairs(spaces) do
      if hs.spaces.spaceType(sid) == "user" then
        table.insert(userSpaces, sid)
      end
    end
    for i, sid in ipairs(userSpaces) do
      if sid == focused then
        if #userSpaces < 2 then return nil end
        return userSpaces[(i % #userSpaces) + 1]
      end
    end
  end
  return nil
end

hs.hotkey.bind(hyper, "tab", function()
  local sid = nextUserSpaceID()
  if sid then hs.spaces.gotoSpace(sid) end
end)

----------------------------------------------------------------------
-- Focus navigation (vim-style hjkl) — the AeroSpace replacement
----------------------------------------------------------------------
-- These move keyboard focus to the window in the given direction,
-- across all visible windows on all screens. Bound to both hyper+hjkl
-- and bare alt+pad4/6/8/2 (numpad mirror).

local function focusDir(method)
  return function()
    local win = hs.window.focusedWindow()
    if win then win[method](win, nil, true, true) end
  end
end

hs.hotkey.bind(hyper, "H", focusDir("focusWindowWest"))
hs.hotkey.bind(hyper, "L", focusDir("focusWindowEast"))
hs.hotkey.bind(hyper, "K", focusDir("focusWindowNorth"))
hs.hotkey.bind(hyper, "J", focusDir("focusWindowSouth"))

hs.hotkey.bind({ "alt" }, "pad4", focusDir("focusWindowWest"))
hs.hotkey.bind({ "alt" }, "pad6", focusDir("focusWindowEast"))
hs.hotkey.bind({ "alt" }, "pad8", focusDir("focusWindowNorth"))
hs.hotkey.bind({ "alt" }, "pad2", focusDir("focusWindowSouth"))

-- Focus in the z-direction: reach windows stacked underneath the
-- focused one, which directional focus (hjkl) can't get to when they
-- fully overlap.
--
-- orderedWindows() is front-to-back, so the windows "underneath" are
-- the standard windows after the focused one whose frames overlap it.
-- Descend (alt+pad5) walks down that stack one window per press;
-- surface (shift+alt+pad5) focuses the deepest one, cycling the
-- opposite way.
--
-- Focusing raises, so recomputing the stack each press would just
-- ping-pong between the top two windows. Instead the stack is captured
-- when a cycle starts and an index advances through it (wrapping back
-- to the starting window); the saved cycle stays live only while focus
-- is on the window we last visited. Don't "fix" this with
-- win:sendToBack() — HS implements that by raising every other window
-- in turn, which visibly strobes the whole stack.

local function framesOverlap(a, b)
  local r = a:intersect(b)
  return r.w > 0 and r.h > 0
end

-- Returns the focused window plus the windows underneath it (front to
-- back) whose frames overlap it.
local function overlappingStack()
  local win = hs.window.focusedWindow()
  if not win then return nil, {} end
  local f = win:frame()
  local stack = {}
  local belowFocused = false
  for _, w in ipairs(hs.window.orderedWindows()) do
    if w:id() == win:id() then
      belowFocused = true
    elseif belowFocused and w:isStandard() and framesOverlap(f, w:frame()) then
      table.insert(stack, w)
    end
  end
  return win, stack
end

local zCycle = nil  -- { ids = { winID, ... }, idx = position of last-focused }

local function focusUnder()
  local cur = hs.window.focusedWindow()
  if not cur then return end

  -- Mid-cycle (focus is still where we left it): advance, skipping any
  -- windows that have closed since the cycle was captured.
  if zCycle and zCycle.ids[zCycle.idx] == cur:id() then
    for _ = 1, #zCycle.ids do
      zCycle.idx = (zCycle.idx % #zCycle.ids) + 1
      local w = hs.window.get(zCycle.ids[zCycle.idx])
      if w then
        w:focus()
        return
      end
    end
    zCycle = nil
    return
  end

  -- Otherwise start a new cycle from the current overlap stack.
  local win, stack = overlappingStack()
  if not win or #stack == 0 then return end
  local ids = { win:id() }
  for _, w in ipairs(stack) do table.insert(ids, w:id()) end
  zCycle = { ids = ids, idx = 2 }
  stack[1]:focus()
end

local function focusSurface()
  local win, stack = overlappingStack()
  if not win or #stack == 0 then return end
  stack[#stack]:focus()
end

hs.hotkey.bind({ "alt" },          "pad5", focusUnder)
hs.hotkey.bind({ "shift", "alt" }, "pad5", focusSurface)

-- Jump focus to an adjacent screen, landing on whatever window is
-- frontmost there (i.e. the one you used most recently on that screen).
-- Directional focus (hyper+hjkl) walks one window at a time, which is
-- tedious when you just want to "switch attention" to another monitor —
-- e.g. to re-tile it with hyper+T. The shift variants of hyper+[ / ]
-- mirror those move-window bindings: move the window vs. move yourself.
local function focusScreen(getScreen)
  return function()
    local win = hs.window.focusedWindow()
    local current = win and win:screen() or hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local target = getScreen(current)
    if not target or target:id() == current:id() then return end
    -- orderedWindows() is front-to-back, so the first standard window
    -- on the target screen is its most recently used one.
    for _, w in ipairs(hs.window.orderedWindows()) do
      if w:isStandard() and w:screen():id() == target:id() then
        w:focus()
        return
      end
    end
    -- No windows over there — park the mouse so the screen is still
    -- "current" for whatever comes next.
    hs.mouse.absolutePosition(hs.geometry.rectMidPoint(target:frame()))
  end
end

local focusPrevScreen = focusScreen(function(s) return s:previous() end)
local focusNextScreen = focusScreen(function(s) return s:next() end)

hs.hotkey.bind(hyperShift, "[",        focusPrevScreen)
hs.hotkey.bind(hyperShift, "]",        focusNextScreen)
hs.hotkey.bind({ "alt" },  "padclear", focusPrevScreen)
hs.hotkey.bind({ "alt" },  "pad-",     focusNextScreen)

----------------------------------------------------------------------
-- App launcher / focuser
----------------------------------------------------------------------
-- hyper+<number> launches the app if it isn't running, otherwise
-- focuses it. Edit this table to taste.
local appBindings = {
  ["1"] = "Ghostty",
  ["2"] = "Zed",
  ["3"] = "Google Chrome",
  -- ["4"] = "Slack",
  ["5"] = "Microsoft Teams",
  ["6"] = "Microsoft Outlook",
}

for key, app in pairs(appBindings) do
  hs.hotkey.bind(hyper, key, function()
    hs.application.launchOrFocus(app)
  end)
end

----------------------------------------------------------------------
-- Window hints (visual picker for any window) — bonus
----------------------------------------------------------------------
-- Press hyper+/ to overlay letters on every visible window; press a
-- letter to jump focus there. Great for "where did that window go".

-- hs.hints.style = "vimperator"
local function showWindowHints() hs.hints.windowHints() end
hs.hotkey.bind(hyper, "/",  showWindowHints)
hs.hotkey.bind({},    "help", showWindowHints)  -- bare Insert key
