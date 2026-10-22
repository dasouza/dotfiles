---------------------
---- KEYBINDINGS ----
---------------------

local programs = require("conf.programs")
local mainMod  = "SUPER" -- Sets "Windows" key as main modifier
local volume   = "~/.config/hypr/scripts/volume.sh" -- wpctl + a dunst progress-bar OSD

-- Cheatsheet: every bind made with key() is also recorded here, grouped by the current section(),
-- and written to $XDG_RUNTIME_DIR/hypr/keybinds.tsv on start/reload for scripts/keybinds.sh
-- (Super+F1 searchable menu, waybar button, printable HTML sheet). Edit binds here and they stay in sync.
local cheatsheet = {}
local currentSection = "General"
local function section(name) currentSection = name end

-- Bind `keys` to `action` (a dispatcher or a Lua function) with a description shown in the cheatsheet
local function key(keys, action, desc, opts)
    opts = opts or {}
    opts.description = desc
    cheatsheet[#cheatsheet + 1] = { section = currentSection, keys = keys, desc = desc, action = action }
    return hl.bind(keys, action, opts)
end

-- A cheatsheet-only line, for binds made in a loop or inside a submap (not runnable from the menu)
local function note(keys, desc)
    cheatsheet[#cheatsheet + 1] = { section = currentSection, keys = keys, desc = desc }
end

-- Toggle special workspace `name`, first launching `cmd` into it if no `class` window exists yet
local function scratchpad(name, class, cmd)
    return function()
        if #hl.get_windows({ class = class }) == 0 then
            hl.dispatch(hl.dsp.exec_cmd(cmd, { workspace = "special:" .. name }))
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
    end
end

section("Apps & session")
key(mainMod .. " + Q", hl.dsp.exec_cmd(programs.terminal), "Terminal")
key(mainMod .. " + E", hl.dsp.exec_cmd(programs.fileManager), "File manager")
key(mainMod .. " + SPACE", hl.dsp.exec_cmd(programs.menu), "App launcher")
key(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | hyprlauncher --dmenu | cliphist decode | wl-copy"), "Clipboard history")
key(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), "Color picker (hex to clipboard)")
key(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"), "Lock screen")
key(mainMod .. " + M", hl.dsp.exec_cmd([[
  case "$(hyprland-dialog --title 'Power' --text 'What do you want to do?' --buttons 'Lock;Log out;Restart;Shut down;Cancel')" in
    'Lock')      loginctl lock-session ;;
    'Log out')   hyprshutdown ;;
    'Restart')   hyprshutdown -p 'systemctl reboot' ;;
    'Shut down') hyprshutdown -p 'systemctl poweroff' ;;
  esac
]]), "Power menu (lock, log out, restart, shut down)")
key(mainMod .. " + F1", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybinds.sh"), "Search keybinds (this menu)")
key(mainMod .. " + SHIFT + F1", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybinds.sh html"), "Printable keybind cheatsheet")

section("Windows")
local closeWindowBind = key(mainMod .. " + C", hl.dsp.window.close(), "Close window")
-- closeWindowBind:set_enabled(false)
key(mainMod .. " + F", hl.dsp.window.fullscreen(), "Fullscreen")
key(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), "Float / tile")
key(mainMod .. " + P", hl.dsp.window.pseudo(), "Pseudotile")
key(mainMod .. " + J", hl.dsp.layout("togglesplit"), "Toggle split direction") -- dwindle only
note(mainMod .. " + arrows", "Move focus")
note(mainMod .. " + SHIFT + arrows", "Move window")
note(mainMod .. " + mouse:272", "Drag window")
note(mainMod .. " + mouse:273", "Resize window")

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { description = "Focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { description = "Focus up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { description = "Focus down" })

-- Move window with mainMod + SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }),  { description = "Move window left" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }),    { description = "Move window up" })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }),  { description = "Move window down" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- Resize mode: Super+R, then arrows resize the active window; Escape or Enter leaves
-- (waybar's hyprland/submap module shows when it's active)
section("Resize mode")
key(mainMod .. " + R", hl.dsp.submap("resize"), "Enter resize mode")
note("arrows", "Resize the active window (in resize mode)")
note("escape / Return", "Leave resize mode")
hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 30,  y = 0,   relative = true }), { repeating = true, description = "Wider" })
    hl.bind("left",  hl.dsp.window.resize({ x = -30, y = 0,   relative = true }), { repeating = true, description = "Narrower" })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true, description = "Shorter" })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }), { repeating = true, description = "Taller" })
    hl.bind("escape", hl.dsp.submap("reset"), { description = "Leave resize mode" })
    hl.bind("Return", hl.dsp.submap("reset"), { description = "Leave resize mode" })
end)

-- Tabbed groups: Super+G turns the active window into a group (or ungroups it);
-- Super+Tab / Super+Shift+Tab switch tabs, Super+CTRL+arrows move a window into/out of a neighbouring group
section("Tabbed groups")
key(mainMod .. " + G",            hl.dsp.group.toggle(), "Make / undo a tabbed group")
key(mainMod .. " + Tab",          hl.dsp.group.next(),   "Next tab")
key(mainMod .. " + SHIFT + Tab",  hl.dsp.group.prev(),   "Previous tab")
key(mainMod .. " + CTRL + left",  hl.dsp.window.move({ into_or_create_group = "left" }),  "Join group on the left")
key(mainMod .. " + CTRL + right", hl.dsp.window.move({ into_or_create_group = "right" }), "Join group on the right")
key(mainMod .. " + CTRL + up",    hl.dsp.window.move({ into_or_create_group = "up" }),    "Join group above")
key(mainMod .. " + CTRL + down",  hl.dsp.window.move({ out_of_group = true }),            "Leave group")

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9] (and follow it),
-- or with mainMod + CTRL + [0-9] (stay where you are)
section("Workspaces")
note(mainMod .. " + 1-0", "Go to workspace 1-10")
note(mainMod .. " + SHIFT + 1-0", "Move window to workspace (and follow)")
note(mainMod .. " + CTRL + 1-0", "Send window to workspace (stay here)")
for i = 1, 10 do
    local k = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. k,         hl.dsp.focus({ workspace = i }),                       { description = "Workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. k, hl.dsp.window.move({ workspace = i }),                 { description = "Move window to workspace " .. i })
    hl.bind(mainMod .. " + CTRL + " .. k,  hl.dsp.window.move({ workspace = i, follow = false }), { description = "Send window to workspace " .. i })
end
-- Alt-tab-like: jump between the current and previous workspace (fullscreen game <-> desktop)
key("ALT + Tab", hl.dsp.focus({ workspace = "previous" }), "Previous workspace (game ↔ desktop)")
-- Scroll through existing workspaces with mainMod + scroll
key(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace")
key(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), "Previous workspace")

-- Dropdown terminal on the key left of 1 (º on the Spanish layout; code:49 works on any layout)
-- and Spotify; each is launched on first use. Their float/size rules are in rules.lua
section("Scratchpads")
key(mainMod .. " + code:49",   scratchpad("term", "com.mitchellh.ghostty.dropdown",
                                          programs.terminal .. " --class=com.mitchellh.ghostty.dropdown"), "Dropdown terminal")
key(mainMod .. " + SHIFT + M", scratchpad("music", "spotify", "spotify"), "Spotify")
key(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"), "Show / hide scratchpad")
key(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), "Move window to scratchpad")

-- Screenshots (hyprshot). Print / Shift+Print: region / whole screen to the clipboard only.
-- Super(+Shift/Ctrl)+Print: region / window / screen saved to ~/Pictures/Screenshots (also copied + notified)
section("Screenshots")
key("Print",                       hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"), "Region → clipboard")
key("SHIFT + Print",               hl.dsp.exec_cmd("hyprshot -m output -m active --clipboard-only"), "Screen → clipboard")
key(mainMod .. " + Print",         hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"), "Region → file")
key(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots"), "Window → file")
key(mainMod .. " + CTRL + Print",  hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"), "Screen → file")

-- Multimedia keys for volume (with an on-screen progress bar); media keys require playerctl
section("Media")
key("XF86AudioRaiseVolume", hl.dsp.exec_cmd(volume .. " up"),   "Volume up",     { locked = true, repeating = true })
key("XF86AudioLowerVolume", hl.dsp.exec_cmd(volume .. " down"), "Volume down",   { locked = true, repeating = true })
key("XF86AudioMute",        hl.dsp.exec_cmd(volume .. " mute"), "Mute",          { locked = true })
key("XF86AudioMicMute",     hl.dsp.exec_cmd(volume .. " mic"),  "Mute mic",      { locked = true })
key("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), "Play / pause", { locked = true })
key("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       "Next track",   { locked = true })
key("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   "Previous track", { locked = true })
hl.bind("XF86AudioPause",   hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })


-- Readable key names for the cheatsheet: "SUPER + SHIFT + left" → "Super + Shift + ←"
local keyNames = {
    SUPER = "Super", SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt", SPACE = "Space",
    left = "←", right = "→", up = "↑", down = "↓", arrows = "←↑↓→",
    ["code:49"] = "º", ["mouse:272"] = "Left-drag", ["mouse:273"] = "Right-drag",
    mouse_down = "Scroll down", mouse_up = "Scroll up", escape = "Esc", Return = "Enter",
    XF86AudioRaiseVolume = "Vol+", XF86AudioLowerVolume = "Vol−", XF86AudioMute = "Mute",
    XF86AudioMicMute = "Mic mute", XF86AudioPlay = "Play", XF86AudioNext = "Next", XF86AudioPrev = "Prev",
}
local function prettyKeys(keys)
    return (keys:gsub("[^%s+/]+", function(word) return keyNames[word] or word end))
end

-- Run cheatsheet entry `n` from the Super+F1 menu (called through `hyprctl eval`)
function keybinds_run(n)
    local entry = cheatsheet[n]
    if not entry or not entry.action then return end
    if type(entry.action) == "function" then entry.action() else hl.dispatch(entry.action) end
end

-- One line per entry: index (0 = not runnable), section, keys, description
local function writeCheatsheet()
    local lines = {}
    for i, e in ipairs(cheatsheet) do
        lines[#lines + 1] = table.concat({ e.action and i or 0, e.section, prettyKeys(e.keys), e.desc }, "\t")
    end
    local text = (table.concat(lines, "\n") .. "\n"):gsub("'", "'\\''")
    hl.exec_cmd("dir=\"${XDG_RUNTIME_DIR:-/tmp}/hypr\"; mkdir -p \"$dir\" && printf '%s' '" .. text .. "' > \"$dir/keybinds.tsv\"")
end
hl.on("hyprland.start", writeCheatsheet)
hl.on("config.reloaded", writeCheatsheet)
