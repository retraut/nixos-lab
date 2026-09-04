local mod = "SUPER"
local home = assert(os.getenv("HOME"), "HOME must be set")
local theme = dofile(home .. "/.config/hypr/theme.lua")

hl.config({
  animations = { enabled = true },
  cursor = { hide_on_key_press = true },
  decoration = {
    rounding = 0,
    blur = { enabled = true, size = 3, passes = 2 },
    shadow = { enabled = true, range = 4, render_power = 3, color = theme.shadow },
  },
  dwindle = { preserve_split = true, force_split = 2 },
  scrolling = {
    fullscreen_on_one_column = true,
    column_width = 0.95,
    focus_fit_method = 0,
    follow_focus = true,
    follow_min_visible = 0.35,
    wrap_focus = true,
    direction = "right",
  },
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    layout = "scrolling",
    resize_on_border = false,
    allow_tearing = false,
    col = {
      active_border = "rgb(" .. theme.accent .. ")",
      inactive_border = "rgb(" .. theme.muted .. ")",
    },
  },
  input = {
    -- English first, Ukrainian second; Alt+Shift switches between them.
    kb_layout = "us,ua",
    kb_options = "grp:alt_shift_toggle",
    follow_mouse = 1,
    numlock_by_default = true,
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      tap_to_click = true,
      disable_while_typing = false,
      tap_and_drag = true,
      drag_lock = 0,
      scroll_factor = 0.4,
    },
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    -- Omarchy behavior: allow Alt+Tab to focus another tiled window without
    -- forcing the current fullscreen client back into the tiled layout.
    on_focus_under_fullscreen = 1,
  },
  xwayland = { force_zero_scaling = true },
})

local function appSwitcherIpc(method)
  hl.exec_cmd("quickshell ipc --path " .. home .. "/.config/quickshell/shell.qml call nixos-app-switcher " .. method)
end

-- Three-finger swipe up opens Mission Control. Horizontal swipes cycle apps
-- directly, without opening the Alt+Tab overlay.
hl.gesture({
  fingers = 3,
  direction = "up",
  action = function()
    appSwitcherIpc("overview")
  end,
})
hl.gesture({
  fingers = 3,
  direction = "left",
  action = function()
    appSwitcherIpc("nextApp")
  end,
})
hl.gesture({
  fingers = 3,
  direction = "right",
  action = function()
    appSwitcherIpc("previousApp")
  end,
})

-- Keep the desktop on one persistent workspace. The window rule also folds
-- windows created by applications that request a different workspace back
-- into the single desktop.
hl.workspace_rule({ workspace = "1", persistent = true, default = true })
hl.window_rule({
  name = "single-desktop-workspace",
  match = { class = ".*" },
  workspace = "1",
})

-- Keep GNOME Sushi as a centered Quick Look overlay over the nnn terminal.
-- The fallback class covers older Sushi builds that report a short app ID.
hl.window_rule({
  name = "centered-sushi-preview",
  match = { class = "^(org\\.gnome\\.NautilusPreviewer|sushi)$" },
  float = true,
  center = true,
  size = "70% override 50% override",
  no_initial_focus = true,
})

-- Keep scrolling columns in the preferred order as applications are opened.
-- The scrolling layout inserts new windows by launch order, so this small
-- event-driven sorter moves the newly opened column beside its sorted
-- neighbors without changing the layout itself.
local webAppSortNames = {
  ["x.com"] = "x.com",
  ["youtube.com"] = "youtube",
  ["mail.google.com"] = "gmail",
}

local function windowSortName(window)
  local class = string.lower(window.initialClass or window.class or "")
  local title = string.lower(window.title or "")

  -- Keep the main workflow windows in the preferred left-to-right order.
  -- Use numeric prefixes so this remains explicit instead of depending on
  -- the applications' window classes sorting alphabetically.
  if class:find("nnn", 1, true) or title:find("nnn", 1, true) then
    return "01-nnn"
  end
  if class:find("chatgpt", 1, true) or title:find("chatgpt", 1, true) then
    return "02-chatgpt"
  end
  if class:find("codex", 1, true) or title:find("codex", 1, true) then
    return "03-codex"
  end
  if class:find("rebuild", 1, true) or title:find("rebuild", 1, true) then
    return "04-rebuild"
  end

  local webHost = class:match("^chrome%-(.-)__")
  if webHost then
    webHost = webHost:gsub("^www%.", "")
    return webAppSortNames[webHost] or webHost
  end

  if class:find("ghostty", 1, true) then return "ghostty" end
  if class:find("slack", 1, true) then return "slack" end
  if class:find("chrom", 1, true) then return "chromium" end
  return class:gsub("[^%w]+", " ")
end

local function windowSortPriority(window)
  -- nnn is the anchor window and must always remain the leftmost column.
  return windowSortName(window) == "01-nnn" and 0 or 1
end

local function windowComesBefore(left, right)
  local leftPriority = windowSortPriority(left)
  local rightPriority = windowSortPriority(right)
  if leftPriority ~= rightPriority then
    return leftPriority < rightPriority
  end
  return windowSortName(left) < windowSortName(right)
end

local function scheduleAlphabeticPlacement(window)
  if not window then return end
  local address = window.address

  local function placeWindow()
    local active = hl.get_active_window()
    if not active or (address and active.address ~= address) then return end

    local workspace = active.workspace
    if not workspace then return end

    local columns = {}
    for _, candidate in ipairs(hl.get_windows({ mapped = true })) do
      local at = candidate.at
      local candidateWorkspace = candidate.workspace
      if candidateWorkspace and candidateWorkspace.id == workspace.id
        and candidate.floating ~= true and candidate.pinned ~= true and at then
        table.insert(columns, candidate)
      end
    end

    table.sort(columns, function(left, right)
      return (left.at.x or 0) < (right.at.x or 0)
    end)

    local activeIndex = nil
    for index, candidate in ipairs(columns) do
      if (address and candidate.address == address) or candidate == active then
        activeIndex = index
        break
      end
    end
    if not activeIndex then return end

    local left = columns[activeIndex - 1]
    local right = columns[activeIndex + 1]
    if left and windowComesBefore(active, left) then
      hl.dispatch(hl.dsp.layout("swapcol l"))
      hl.timer(placeWindow, { timeout = 35, type = "oneshot" })
    elseif right and windowComesBefore(right, active) then
      hl.dispatch(hl.dsp.layout("swapcol r"))
      hl.timer(placeWindow, { timeout = 35, type = "oneshot" })
    end
  end

  -- Wait for the scrolling layout to place the new column before measuring it.
  hl.timer(placeWindow, { timeout = 100, type = "oneshot" })
end

hl.on("window.open", scheduleAlphabeticPlacement)

hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("MOZ_ENABLE_WAYLAND", "1")

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
-- Keep window transitions vertical so Alt+Tab does not feel like a side swipe.
hl.animation({ leaf = "windows", enabled = true, speed = 4.8, bezier = "easeOutQuint", style = "slide bottom" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "easeInOutCubic" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.8, bezier = "easeOutQuint" })

hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("ghostty"), { description = "Open terminal" })
hl.bind(mod .. " + SPACE", function()
  -- The warm launcher captures/restores the previous layout through its IPC
  -- handler, so opening it does not start a new Quickshell process.
  hl.exec_cmd(home .. "/.local/bin/nixos-launcher")
end, { description = "Application launcher (English)" })
hl.bind(mod .. " + CTRL + O", hl.dsp.exec_cmd("nixos-control-center"), { description = "Control center" })
hl.bind(mod .. " + SHIFT + CTRL + A", hl.dsp.exec_cmd("nixos-agents"), { description = "Agent picker" })
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("chromium"), { description = "Open browser" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd("nautilus --new-window"), { description = "Open files" })
hl.bind(mod .. " + CTRL + M", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-menu"), { description = "Desktop menu" })

-- With clickfinger_behavior enabled, a two-finger tap is a right click. Keep
-- it non-consuming so applications retain their normal context menus, and
-- open the Nix menu only when the pointer is over the wallpaper itself.
local function cursorIsOverDesktop()
  local cursor = hl.get_cursor_pos()
  local activeWorkspace = hl.get_active_workspace()
  if not cursor or not activeWorkspace then return false end

  for _, window in ipairs(hl.get_windows({ mapped = true })) do
    local at = window.at
    local size = window.size
    if at and size and window.workspace and window.workspace.id == activeWorkspace.id
      and cursor.x >= at.x and cursor.x < at.x + size.x
      and cursor.y >= at.y and cursor.y < at.y + size.y then
      return false
    end
  end

  -- Quickshell panels and popups are layer surfaces rather than windows.
  -- The bar uses keyboardFocus=None, so its interactivity can be 0 even
  -- though it still accepts pointer clicks. Match the bar explicitly before
  -- filtering out genuinely non-interactive layers such as the wallpaper.
  for _, layer in ipairs(hl.get_layers()) do
    if layer.mapped and layer.namespace == "nixos-shell-bar"
      and cursor.x >= layer.x and cursor.x < layer.x + layer.w
      and cursor.y >= layer.y and cursor.y < layer.y + layer.h then
      return false
    end

    if layer.mapped and layer.interactivity ~= 0
      and cursor.x >= layer.x and cursor.x < layer.x + layer.w
      and cursor.y >= layer.y and cursor.y < layer.y + layer.h then
      return false
    end
  end

  return true
end

local function nixosMenuIsOpen()
  return #hl.get_layers({ namespace = "nixos-menu" }) > 0
end

hl.bind("mouse:273", function()
  if nixosMenuIsOpen() or cursorIsOverDesktop() then
    hl.exec_cmd(home .. "/.local/bin/nixos-menu")
  end
end, { non_consuming = true, description = "Nix menu on desktop two-finger tap" })

hl.bind(mod .. " + L", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-lock"), { description = "Lock session" })
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-clipboard"), { description = "Clipboard history" })
hl.bind(mod .. " + CTRL + SPACE", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-emoji"), { description = "Emoji picker" })
hl.bind("PRINT", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-capture region"), { description = "Screenshot region" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-capture fullscreen"), { description = "Screenshot fullscreen" })
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-capture window"), { description = "Screenshot active window" })
-- The GA503QS has no Print Screen key; its Fn+F6 hardware shortcut emits F6.
hl.bind("F6", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-capture region"), { description = "Screenshot region (Fn+F6)" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-capture region"), { description = "Screenshot region" })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-volume up"), { description = "Volume up", locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-volume down"), { description = "Volume down", locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-volume mute"), { description = "Mute audio", locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-volume mic"), { description = "Mute microphone", locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-brightness up"), { description = "Brightness up", locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-brightness down"), { description = "Brightness down", locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-kbd-brightness up"), { description = "Keyboard brightness up", locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-kbd-brightness down"), { description = "Keyboard brightness down", locked = true, repeating = true })
-- ASUS ROG key: wev reports XF86Launch1 / physical keycode 156.
hl.bind("code:156", hl.dsp.exec_cmd("voxtype record toggle"), { description = "Toggle Voxtype transcription" })
hl.bind(mod .. " + W", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen(0), { description = "Fullscreen" })
-- Keep Alt+F available as a global fullscreen toggle. Use the physical key
-- code so it remains reliable while the Ukrainian layout is active.
hl.bind("ALT + code:33", hl.dsp.window.fullscreen(0), { description = "Fullscreen (Alt+F)" })
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mod .. " + LEFT", hl.dsp.layout("focus l"), { description = "Focus previous carousel window" })
hl.bind(mod .. " + RIGHT", hl.dsp.layout("focus r"), { description = "Focus next carousel window" })
hl.bind(mod .. " + UP", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mod .. " + DOWN", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })

-- Alt+Tab switches immediately; if Alt stays held, Quickshell promotes the
-- interaction to the overlay after a short delay. Releasing Alt commits the
-- currently selected app/window from that overlay.
local shellPath = home .. "/.config/quickshell/shell.qml"
local function appSwitcherCall(method)
  return hl.dsp.exec_cmd("quickshell ipc --path " .. shellPath .. " call nixos-app-switcher " .. method)
end

local altHoldTimer = nil
local altHoldGeneration = 0

local function altIsDown()
  return hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R")
end

local function cancelAltHold()
  altHoldGeneration = altHoldGeneration + 1
  if altHoldTimer then
    altHoldTimer:set_enabled(false)
    altHoldTimer = nil
  end
end

local function armAltHold()
  cancelAltHold()
  local generation = altHoldGeneration
  altHoldTimer = hl.timer(function()
    if generation == altHoldGeneration and altIsDown() then
      hl.exec_cmd("quickshell ipc --path " .. shellPath .. " call nixos-app-switcher openAlt")
    end
    altHoldTimer = nil
  end, { timeout = 200, type = "oneshot" })
end

local function altTabBinding(method)
  return function()
    hl.dispatch(appSwitcherCall(method))
    armAltHold()
  end
end

local function commitAlt()
  cancelAltHold()
  hl.dispatch(appSwitcherCall("commitAlt"))
end

hl.bind("ALT + TAB", altTabBinding("altTab"), { description = "App switcher" })
hl.bind("ALT + SHIFT + TAB", altTabBinding("altShiftTab"), { description = "Previous app" })
hl.bind("ALT + ALT_L", commitAlt, { release = true, description = "Commit app switcher (Alt)" })
hl.bind("ALT + ALT_R", commitAlt, { release = true, description = "Commit app switcher (AltGr)" })
hl.bind("SUPER + TAB", appSwitcherCall("commandTab"), { description = "App switcher (Command)" })
hl.bind("SUPER + SHIFT + TAB", appSwitcherCall("commandShiftTab"), { description = "Previous app (Command)" })
hl.bind("SUPER", appSwitcherCall("commitCommand"), { release = true, description = "Commit app switcher (Command)" })
-- Physical keycode 49 is the grave/backtick key on the standard keyboard.
-- Using the code keeps Cmd+`/Alt+` independent from the active layout.
hl.bind("ALT + code:49", appSwitcherCall("nextWindow"), { description = "Next window of app" })
hl.bind("ALT + SHIFT + code:49", appSwitcherCall("previousWindow"), { description = "Previous window of app" })
hl.bind("SUPER + code:49", appSwitcherCall("nextWindow"), { description = "Next window of app (Command)" })
hl.bind("SUPER + SHIFT + code:49", appSwitcherCall("previousWindow"), { description = "Previous window of app (Command)" })

-- Cmd+W closes the current window while preferring another window from the
-- same app group. Chromium receives Ctrl+W from xremap instead.
hl.bind("ALT + W", appSwitcherCall("closeCurrentWindow"), { description = "Close window" })

-- Cmd+Space is the launcher on both the laptop Alt profile and Apple Command.
hl.bind("ALT + SPACE", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-launcher"), { description = "Application launcher" })

-- Universal clipboard shortcuts. Use physical keycodes for GUI apps so the
-- injected chord still means C/V while the Ukrainian layout is active.
local function sendShortcutOnce(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function activeWindowIsTerminal()
  local window = hl.get_active_window()
  if not window then return false end

  -- Wayland does not expose the parent terminal process here. Our terminal
  -- launchers therefore use stable app classes, which we classify alongside
  -- Ghostty for clipboard and terminal-only keybindings.
  local class = string.lower((window.class or "") .. " " .. (window.initialClass or ""))
  if class:find("ghostty", 1, true)
    or class:find("com.openai.codex", 1, true)
    or class:find("org.retraut.", 1, true)
    or class:find("nnn", 1, true)
    or class:find("nnn-preview", 1, true)
    or class:find("terminal", 1, true) then
    return true
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end

  return false
end

local function activeWindowIsChromium()
  local window = hl.get_active_window()
  if not window then return false end

  local class = string.lower((window.class or "") .. " " .. (window.initialClass or ""))
  return class:find("chrom", 1, true) ~= nil
    or class:find("google%-chrome") ~= nil
    or class:find("brave%-browser") ~= nil
    or class:find("microsoft%-edge") ~= nil
end

-- App profiles use physical XKB keycodes, not layout-dependent characters.
-- This keeps Super-based shortcuts identical in the US and Ukrainian layouts.
local function bindPhysicalAppShortcut(key, predicate, sendMods, sendKey, description)
  hl.bind(mod .. " + " .. key, function()
    if predicate() then
      sendShortcutOnce(sendMods, sendKey)()
    end
  end, { description = description })
end

local function bindPhysicalAppShiftShortcut(key, predicate, sendMods, sendKey, description)
  hl.bind(mod .. " + SHIFT + " .. key, function()
    if predicate() then
      sendShortcutOnce(sendMods, sendKey)()
    end
  end, { description = description })
end

-- Keep Chromium's macOS-style new-window shortcut. Everywhere else the same
-- physical key opens the notification center, in both US and UA layouts.
hl.bind(mod .. " + code:57", function()
  if activeWindowIsChromium() then
    sendShortcutOnce("CTRL", "code:57")()
  else
    hl.exec_cmd("quickshell ipc --path " .. home .. "/.config/quickshell/shell.qml call nixos-notifications toggleCenter")
  end
end, { description = "New browser window / notification center" })

-- macOS-like browser shortcuts, scoped to Chromium-family windows. Outside a
-- browser, keep the existing Hyprland window-management behavior.
hl.unbind(mod .. " + W")
hl.unbind(mod .. " + T")
hl.unbind(mod .. " + R")
hl.unbind(mod .. " + code:20")
hl.unbind(mod .. " + code:21")
hl.unbind(mod .. " + SHIFT + code:21")

hl.bind(mod .. " + code:25", function()
  if activeWindowIsChromium() then
    -- Use the physical W key so Ctrl+W remains Ctrl+W in the Ukrainian layout.
    sendShortcutOnce("CTRL", "code:25")()
  else
    hl.dispatch(appSwitcherCall("closeCurrentWindow"))
  end
end, { description = "Close browser tab / window" })
bindPhysicalAppShortcut("code:28", activeWindowIsChromium, "CTRL", "T", "New browser tab")
bindPhysicalAppShortcut("code:27", activeWindowIsChromium, "CTRL", "R", "Refresh browser")

-- Browser zoom, scoped to Chromium-family windows. Use physical keycodes so
-- the bindings stay correct with both the US and Ukrainian layouts.
bindPhysicalAppShortcut("code:20", activeWindowIsChromium, "CTRL", "code:20", "Zoom browser out")
bindPhysicalAppShortcut("code:21", activeWindowIsChromium, "CTRL_SHIFT", "code:21", "Zoom browser in")
bindPhysicalAppShiftShortcut("code:21", activeWindowIsChromium, "CTRL_SHIFT", "code:21", "Zoom browser in")

-- Ghostty's Super bindings are routed through Hyprland so they work with both
-- layouts and terminals that were already open before a config reload.
bindPhysicalAppShortcut("code:20", activeWindowIsTerminal, "CTRL", "code:20", "Zoom terminal out")
-- Ghostty maps Ctrl+= to font increase, so do not inject Shift here even
-- though the physical key is typed as '+' by the keyboard layout.
bindPhysicalAppShortcut("code:21", activeWindowIsTerminal, "CTRL", "code:21", "Zoom terminal in")
bindPhysicalAppShiftShortcut("code:21", activeWindowIsTerminal, "CTRL", "code:21", "Zoom terminal in")

hl.bind(mod .. " + C", function()
  if activeWindowIsTerminal() then
    sendShortcutOnce("CTRL", "Insert")()
  else
    sendShortcutOnce("CTRL", "code:54")()
  end
end, { description = "Universal copy" })

hl.bind(mod .. " + V", hl.dsp.exec_cmd(home .. "/.local/bin/nixos-universal-paste"), { description = "Universal paste" })

hl.bind(mod .. " + code:38", function()
  if activeWindowIsTerminal() then
    -- Ghostty's select_all action is bound to Ctrl+Shift+A by default.
    sendShortcutOnce("CTRL_SHIFT", "code:38")()
  else
    sendShortcutOnce("CTRL", "code:38")()
  end
end, { description = "Universal select all" })

hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("systemctl --user restart nixos-xremap.service")
end)
