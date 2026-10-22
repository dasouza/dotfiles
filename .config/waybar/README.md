# Waybar

### Full Dekstop
<img width="2880" height="1800" alt="full_desktop_waybar" src="https://github.com/user-attachments/assets/c9ee976f-83c0-4dfd-95c5-a5d0de4bc33c" />

### Showcase
https://github.com/user-attachments/assets/150b7b3d-9b5d-4a0f-a7a4-47977d99e9e5

---

### Structure

```
waybar/
├── config.jsonc                     # Entry point, loads all modules
├── style.css                        # Main stylesheet
├── modules/
│   ├── audio.jsonc
│   ├── battery.jsonc
│   ├── clock.jsonc
│   ├── connections.jsonc
│   ├── distro.jsonc                 < Applications embedded
│   ├── groups.jsonc                 # Drawer grouping
│   ├── idle-inhibitor.jsonc
│   ├── power-profiles-daemon.jsonc
│   ├── storage.jsonc
│   ├── system.jsonc
│   ├── tray-notif.jsonc             # Tray + dunst status
│   └── workspace.jsonc
└── tokens/                          # CSS variables
    ├── colors.css                   < edit colors here
    ├── batt-clock.css
    ├── slider.css
    ├── state.css
    ├── widget.css
    └── workspace.css
```

---

### Dependencies

| Package | Purpose |
| --- | --- |
| [dunst](https://dunst-project.org/) | Notifications (`scripts/dunst-status.sh`) |
| [playerctl](https://github.com/altdesktop/playerctl) | Media controls for the `mpris` module |
| [nm-applet](https://wiki.archlinux.org/title/NetworkManager) | Network manager |
| [blueman](https://wiki.archlinux.org/title/Blueman) | Bluetooth manager |
| [pipewire](https://wiki.archlinux.org/title/PipeWire) / [pulseaudio](https://wiki.archlinux.org/title/PulseAudio) | Audio |

### Installation
```bash
git clone https://github.com/haikal-hakim/athena.git
cd athena
cp -r .config/waybar ~/.config/waybar
```
---

>[!IMPORTANT]
>Open file `waybar/modules/clock`, and change this;

```bash
{
  "clock": {
    "timezone": "REGION/CITY",
    "format": "󰃱 <span size='11pt'>{:%H.%M }</span>",
    "format-alt": "󰃱 <span size='11pt'>{:%d %B %Y}</span>",
    "tooltip-format": "<tt><small>{calendar}</small></tt>"
  }
}
```

---

### Modules

| Module | Interaction | Action |
| --- | --- | --- |
| Network | Left click | Open `nm-connection-editor` |
| | Right click | Close `nm-connection-editor` |
| Bluetooth | Left click | Open `blueman-manager` |
| | Right click | Toggle power on/off |
| Notifications (dunst) | Left click | Re-show last notification |
| | Right click | Toggle Do Not Disturb |
| | Middle click | Clear history |
| Media (mpris) | Left click | Play/pause |
| | Right click | Show/hide the Spotify scratchpad |
| | Scroll | Previous/next track |
| Clock | Click | Toggle time/date |
| | Scroll (tooltip) | Previous/next month; right click returns to this month |
| Battery | — | Logitech mouse battery (`hidpp_battery_0`) |
| Submap | — | Shown only while a Hyprland submap (Super+R resize) is active |
| Power Profiles | Click | Toggle Saver > Balance > Performance |
| Idle Inhibitor | Click | Toggle screen dimming |

---

### Colors

Edit `tokens/colors.css` to match your preference.

> [!TIP]
> For automatic color generation from your wallpaper, see `.config/matugen` and `.config/zsh`.

---

## Acknowledgments
* **[Waybar](https://github.com/Alexays/Waybar)** - Created by **Alexays**. Huge thanks for this amazing and highly customizable status bar.
* All the contributors who have made Waybar what it is today.
* I personally customized this configuration to fit the **Athena** desktop.

---
Developed by Muhammad Haikal Hakim.
