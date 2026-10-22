-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- Split into files under conf/, loaded at the bottom. Each require is its own scope,
-- so an error in one file doesn't stop the others:
--   conf/programs.lua  terminal / file manager / launcher (shared)
--   conf/looks.lua     look and feel, animations, smart gaps, layouts
--   conf/binds.lua     keybindings, resize submap, scratchpads
--   conf/rules.lua     window rules, game-workspace notification pause


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Xiaomi Mi Monitor 34" ultrawide on the AMD dGPU. 144 Hz is only in the EDID's DisplayID block;
-- "preferred" would pick a lower rate, so the mode is set explicitly.
hl.monitor({
    output   = "DP-2",
    mode     = "3440x1440@144",
    position = "0x0",
    scale    = 1,
})

-- Fallback for any other monitor that gets plugged in
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function ()
  -- Import the environment first so the systemd units see WAYLAND_DISPLAY; units restart on crash.
  hl.exec_cmd("dbus-update-activation-environment --systemd --all && systemctl --user restart hyprpolkitagent hyprpaper dunst waybar hypridle")
  hl.exec_cmd("/usr/lib/pam_kwallet_init")
  hl.exec_cmd("nm-applet")
  hl.exec_cmd("blueman-applet")
  -- Clipboard history (cliphist)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  -- Keep copied text after the source app closes (package: wl-clip-persist)
  hl.exec_cmd("wl-clip-persist --clipboard regular")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

local env = {
	XCURSOR_SIZE         = "24",
	XCURSOR_THEME        = "breeze_cursors",
	HYPRCURSOR_SIZE      = "24",
	XDG_MENU_PREFIX      = "plasma-",  -- /etc/xdg/menus/plasma-applications.menu (Dolphin "Open with")
	QT_QPA_PLATFORMTHEME = "kde",      -- Breeze theming for Qt/KDE apps outside Plasma
	-- AMD dGPU via stable udev symlink (/etc/udev/rules.d/99-amd-dgpu.rules); cardN numbers change between boots.
	AQ_DRM_DEVICES       = "/dev/dri/amd-dgpu",
	-- Native Wayland for Electron apps (VS Code, Obsidian, Discord, Slack) instead of XWayland
	ELECTRON_OZONE_PLATFORM_HINT = "auto",
}

for key, value in pairs(env) do
	hl.env(key, value)
end


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

hl.config({
  ecosystem = {
    enforce_permissions = true,
  },
})

hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
hl.permission("/usr/bin/hyprlock", "screencopy", "allow")
hl.permission("/usr/bin/hyprpicker", "screencopy", "allow") -- color picker (Super+Shift+C)


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- hyprpaper handles the wallpaper
        disable_hyprland_logo   = true,
        vrr                     = 2,    -- adaptive sync for fullscreen windows only
        -- Programs started from ghostty (mpv, imv, ...) take the terminal's place instead of opening beside it
        enable_swallow          = true,
        swallow_regex           = "^(com\\.mitchellh\\.ghostty)$",
    },
    render = {
        direct_scanout = 2,             -- auto: only for fullscreen windows with content type "game"
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "es",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",
        numlock_by_default = true,

        follow_mouse = 1,

        sensitivity   = 0, -- -1.0 - 1.0, 0 means no modification.
        accel_profile = "flat", -- no mouse acceleration (consistent aim in games)

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Per-device config: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/


require("conf.looks")
require("conf.binds")
require("conf.rules")
