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
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
    layout = "dwindle",
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

-- Switch between adjacent workspaces with a three-finger horizontal swipe.
hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})

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
hl.animation({ leaf = "workspaces", enabled = false })

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
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mod .. " + LEFT", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mod .. " + UP", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mod .. " + DOWN", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })

local function focusNextWindowAcrossWorkspaces()
  local active = hl.get_active_window()
  if not active then return end

  local windows = {}
  for _, window in ipairs(hl.get_windows({ mapped = true })) do
    local workspace = window.workspace
    if workspace and workspace.id > 0 then
      table.insert(windows, window)
    end
  end

  if #windows < 2 then return end
  table.sort(windows, function(a, b)
    if a.workspace.id ~= b.workspace.id then return a.workspace.id < b.workspace.id end
    return a.stable_id < b.stable_id
  end)

  local nextIndex = 1
  for index, window in ipairs(windows) do
    if window.address == active.address then
      nextIndex = index % #windows + 1
      break
    end
  end
  local target = windows[nextIndex]
  hl.dispatch(hl.dsp.focus({ window = target }))
  hl.dispatch(hl.dsp.window.bring_to_top())
end

-- Match Omarchy: cycle focus, then reveal the newly active window above the
-- fullscreen surface. Duplicate bindings intentionally run in this order.
hl.bind("ALT + TAB", hl.dsp.window.cycle_next(), { description = "Next window on current workspace" })
hl.bind("ALT + TAB", hl.dsp.window.bring_to_top(), { description = "Reveal active window on top" })
hl.bind(mod .. " + TAB", focusNextWindowAcrossWorkspaces, { description = "Next window across all workspaces" })

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

  local class = string.lower(window.class or window.initialClass or "")
  if class:find("ghostty", 1, true) or class:find("foot", 1, true) or class:find("terminal", 1, true) then
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
    hl.dispatch(hl.dsp.window.close())
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

for i = 1, 10 do
  local label = i == 10 and "0" or tostring(i)
  hl.bind(mod .. " + " .. label, hl.dsp.focus({ workspace = tostring(i) }), { description = "Workspace " .. label })
  hl.bind(mod .. " + SHIFT + " .. label, hl.dsp.window.move({ workspace = tostring(i) }), { description = "Move window to workspace " .. label })
end

hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
end)
