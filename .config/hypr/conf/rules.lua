--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- App launcher (Super+Space): centered floating panel that pops in and dims everything behind it
hl.window_rule({
    name       = "launcher",
    match      = { class = "^hyprlauncher$" },

    float      = true,
    center     = true,
    dim_around = true,
    rounding   = 16,
    animation  = "popin 85%",
})

-- Video players, browsers and games stay fully opaque when unfocused
hl.window_rule({
    name    = "opaque-media",
    match   = { class = "^(org\\.jellyfin\\.JellyfinDesktop|mpv|vlc|google-chrome|steam_app_.*|gamescope|starcitizen\\.exe)$" },
    opacity = "1 override 1 override",
})
hl.window_rule({ name = "opaque-video", match = { content = "video" }, opacity = "1 override 1 override" })

-- Don't lock/blank the screen while anything is fullscreen
hl.window_rule({ name = "idle-inhibit-fullscreen", match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- Games: allow tearing (lower latency), stay opaque, open on their own workspace (10)
hl.window_rule({
    name      = "games-tearing",
    match     = { class = "^(steam_app_.*|gamescope|starcitizen\\.exe)$" },
    immediate = true,
    workspace = "10",
})
hl.window_rule({ name = "games-content", match = { content = "game" }, immediate = true, opacity = "1 override 1 override", workspace = "10" })

-- Small utility windows and portal file pickers float centered
hl.window_rule({
    name   = "float-utilities",
    match  = { class = "^(org\\.pulseaudio\\.pavucontrol|blueman-manager|nm-connection-editor|org\\.freedesktop\\.impl\\.portal\\.desktop\\.kde|xdg-desktop-portal-gtk)$" },
    float  = true,
    center = true,
    size   = { "(monitor_w*0.5)", "(monitor_h*0.6)" },
})

-- Picture-in-picture: floating, on every workspace, aspect ratio kept
hl.window_rule({
    name              = "picture-in-picture",
    match             = { title = "^(Picture[- ]in[- ][Pp]icture)$" },
    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
    size              = { "(monitor_w*0.3)", "(monitor_h*0.3)" },
})

-- Scratchpads (binds in binds.lua): dropdown terminal along the top, Spotify floating centered.
-- Spotify always lives in its scratchpad, also when launched from the waybar drawer
hl.window_rule({
    name   = "scratchpad-term",
    match  = { class = "^(com\\.mitchellh\\.ghostty\\.dropdown)$" },
    workspace = "special:term silent",
    float  = true,
    size   = { "(monitor_w*0.6)", "(monitor_h*0.45)" },
    move   = "(monitor_w*0.2) 60",
})
hl.window_rule({
    name   = "scratchpad-music",
    match  = { class = "^([Ss]potify)$" },
    workspace = "special:music silent",
    float  = true,
    center = true,
    -- Spotify keeps requesting activation while hidden, which marks special:music urgent (red in waybar)
    suppress_event = "activate",
    size   = { "(monitor_w*0.6)", "(monitor_h*0.7)" },
})
-- Spotify maps with an empty class and sets it afterwards, so the rule above can miss it.
-- Catch the late class change and apply the same placement by hand.
hl.on("window.class", function(w)
    if not w or not (w.class or ""):match("^[Ss]potify$") then return end
    if w.workspace and w.workspace.name == "special:music" then return end
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
    if w.monitor then
        local mw, mh = w.monitor.width / w.monitor.scale, w.monitor.height / w.monitor.scale
        hl.dispatch(hl.dsp.window.resize({ x = math.floor(mw * 0.6), y = math.floor(mh * 0.7), window = w }))
    end
    hl.dispatch(hl.dsp.window.move({ workspace = "special:music", follow = false, window = w }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
end)

-- Pause notifications (dunst do-not-disturb) while the game workspace (10) is active.
-- A marker file records that the pause was ours, so a DND you had already set from waybar is left alone.
local gamePauseMarker = "${XDG_RUNTIME_DIR:-/tmp}/dunst-paused-for-games"
local onGameWorkspace = false
hl.on("workspace.active", function(ws)
    if not ws or ws.special then return end
    if ws.id == 10 and not onGameWorkspace then
        onGameWorkspace = true
        hl.exec_cmd('[ "$(dunstctl is-paused)" = true ] || { dunstctl set-paused true && touch "' .. gamePauseMarker .. '"; }')
    elseif ws.id ~= 10 and onGameWorkspace then
        onGameWorkspace = false
        hl.exec_cmd('[ -e "' .. gamePauseMarker .. '" ] && rm "' .. gamePauseMarker .. '" && dunstctl set-paused false')
    end
end)
