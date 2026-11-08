# dotfiles

Hyprland desktop for Arch Linux with a Quickshell bar and a warm amber "Dune" theme.
It runs on desktops and laptops with AMD, Intel or NVIDIA graphics. Hardware-specific settings
live in one untracked file per machine.

| Path | What |
|---|---|
| `.config/hypr/` | Hyprland (Lua config, split into `conf/`), hypridle, hyprlock, hyprpaper, hyprlauncher, hyprtoolkit theme, keybind cheatsheet script |
| `.config/quickshell/` | Bar, notifications and notification centre, app launcher, power menu, volume/brightness OSD |
| `.config/ghostty/` | Terminal + `dune-amber` theme |
| `.config/xdg-desktop-portal/` | Portal backends (KDE file chooser) |
| `packages.txt` | Arch packages the configs use |
| `install.sh` | Links everything into place and sets up this machine |

## Install

```sh
git clone https://github.com/dasouza/dotfiles ~/Repos/dotfiles
~/Repos/dotfiles/install.sh
```

`install.sh` is safe to re-run. It:

- symlinks each directory under `.config/` into `~/.config`, so the repo is the live config.
  Anything already there is moved to `<name>.pre-dotfiles`.
- links `quickshell.service` into `~/.config/systemd/user/`. Hyprland starts it, along with
  hyprpaper, hypridle and hyprpolkitagent, as systemd user units.
- removes dangling links left behind by configs that were dropped from the repo.
- writes `hypr/local.lua` from the detected GPU(s), keyboard layout and battery (see below).
- prints the `pacman` command for any missing packages, plus anything left to do by hand.

Then set a wallpaper and log in to Hyprland:

```sh
ln -s ~/Pictures/some-wallpaper.jpg ~/.config/hypr/wallpaper
```

## Per-machine settings

These files are git-ignored, so every machine keeps its own:

| File | What |
|---|---|
| `hypr/local.lua` | Monitors, keyboard layout, touchpad, GPU environment variables. Loaded last, so it can override anything. `install.sh` only writes it when it doesn't exist; delete it to regenerate. |
| `hypr/wallpaper` | Symlink to the image used by hyprpaper and hyprlock |

A desktop's `local.lua` might look like this:

```lua
hl.monitor({ output = "DP-2", mode = "3440x1440@144", position = "0x0", scale = 1 })
hl.config({ input = { kb_layout = "es" } })
hl.env("AQ_DRM_DEVICES", "/dev/dri/dgpu")       -- see "Several GPUs"
hl.env("QS_GPU_NAME", "Radeon RX 9070 XT")      -- the bar's name for the GPU
```

Monitors without a rule use their preferred mode. Output names come from `hyprctl monitors`.

## Graphics

- **AMD or Intel only**: nothing to do.
- **NVIDIA only**: `install.sh` adds the [NVIDIA environment variables](https://wiki.hypr.land/Nvidia/)
  to `local.lua` and asks for `nvidia-utils`. It warns if kernel modesetting looks off.
- **Hybrid laptop (Intel/AMD + NVIDIA)**: Hyprland renders on the integrated GPU, so the NVIDIA
  card can power down when idle. Screens wired to the NVIDIA card still work. To run something on
  the NVIDIA card, use `prime-run <command>` (from `nvidia-prime`); in Steam, set the launch options
  to `prime-run %command%`. The bar shows the NVIDIA card as asleep instead of waking it to read
  its stats.
- **Several GPUs on a desktop** (e.g. the iGPU left enabled next to a discrete card): Hyprland
  uses them all. To keep it on the card your monitors are plugged into, give that card a stable
  name with a udev rule (`cardN` numbers change between boots), then set `AQ_DRM_DEVICES` in
  `local.lua`:

  ```sh
  lspci -D | grep -E 'VGA|3D'      # find the card's PCI address, e.g. 0000:03:00.0
  echo 'KERNEL=="card*", KERNELS=="0000:03:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/dgpu"' |
      sudo tee /etc/udev/rules.d/99-dgpu.rules
  sudo udevadm control --reload && sudo udevadm trigger
  ```

The bar's performance card shows the discrete GPU's load, temperature and VRAM. It reads AMD
cards from sysfs and NVIDIA cards through `nvidia-smi`. Intel GPUs don't report a load figure,
so the card is hidden when an Intel GPU is the only one.

## Laptops

The battery appears in the bar only when there is one. The brightness keys use `brightnessctl`
and show an OSD. Touchpad options go in `local.lua`; `install.sh` adds a starting block on
laptops.

## Keybinds

Press **Super+F1** to search all keybinds; picking one runs it. **Super+Shift+F1** opens a
printable cheatsheet. Both are generated from `hypr/conf/binds.lua`, so they stay current.
The basics:

| Keys | Action |
|---|---|
| Super+Q / Super+E / Super+Space | Terminal / file manager / launcher |
| Super+C, Super+F, Super+Shift+F | Close, fullscreen, float |
| Super+arrows, Super+Shift+arrows | Move focus, move window |
| Super+1…0, Super+Shift+1…0 | Go to workspace, move window there |
| Super+º (key left of 1) | Dropdown terminal |
| Super+V | Clipboard history |
| Super+L / Super+M | Lock / power menu |
| Super+N / Super+Shift+N | Do not disturb / notification centre |
| Print, Super+Print | Screenshot region to clipboard / to `~/Pictures/Screenshots` |

## Notes

- Quickshell is the notification daemon. If dunst, mako or swaync is installed, mask it
  (`systemctl --user mask dunst`) so it can't take over through D-Bus activation;
  `install.sh` tells you if one is installed.
- Dolphin, the Breeze theme, the KDE file picker and KWallet are set up to work outside Plasma
  (`XDG_MENU_PREFIX=arch-`, `QT_QPA_PLATFORMTHEME=kde`). To use other apps, change
  `hypr/conf/programs.lua`.
- Super+Shift+M opens a Spotify scratchpad if Spotify is installed (AUR `spotify` or
  `spotify-launcher`).
- Games (Steam, gamescope) open on workspace 10 with tearing allowed, and notifications pause while
  you're on that workspace.
