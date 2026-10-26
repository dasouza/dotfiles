#!/bin/sh
# Screen brightness keys: change the panel backlight with brightnessctl, then show a dunst
# notification with a progress bar that replaces the previous one (same OSD style as volume.sh).
# Usage: brightness.sh up|down

case "$1" in
up)   brightnessctl -q -e4 -n2 set 5%+ ;;
down) brightnessctl -q -e4 -n2 set 5%- ;;
*)    echo "usage: $0 up|down" >&2; exit 1 ;;
esac

# brightnessctl -m prints e.g. "intel_backlight,backlight,9600,50%,19200"
pct=$(brightnessctl -m | cut -d, -f4 | tr -d %)
dunstify -a osd -u low -t 1500 -i display-brightness-symbolic \
    -h string:x-dunst-stack-tag:brightness -h int:value:"$pct" "Brightness $pct%"
