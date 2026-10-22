# dotfiles

Hyprland desktop on Arch Linux: warm amber "Dune" theme.

| Path | What |
|---|---|
| `.config/hypr/` | Hyprland (Lua config, split into `conf/`), hypridle, hyprlock, hyprpaper, hyprlauncher, hyprtoolkit theme, helper scripts |
| `.config/waybar/` | Waybar, based on [athena](https://github.com/haikal-hakim/athena) by Muhammad Haikal Hakim (MIT) |
| `.config/dunst/` | Notifications |
| `.config/ghostty/` | Terminal + `dune-amber` theme |
| `.config/xdg-desktop-portal/` | Portal backends (KDE file chooser) |

## Install

```sh
git clone <this repo> ~/Repos/dotfiles
~/Repos/dotfiles/install.sh
```

`install.sh` symlinks each directory into `~/.config`, so the repo is the live config. Anything already
there gets moved to `<name>.pre-dotfiles`.

## Not included

- The wallpaper (`~/Pictures/Wallpapers/Dune/...`, referenced from `hyprpaper.conf` and `hyprlock.conf`)
- Hardware-specific bits worth adjusting on another machine: the monitor block in `hypr/hyprland.lua`
  (DP-2, 3440x1440@144) and `AQ_DRM_DEVICES`, which relies on a local udev rule
