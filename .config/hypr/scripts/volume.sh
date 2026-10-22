#!/bin/sh
# Volume keys: change the default sink (or toggle the mic) with wpctl, then show a dunst
# notification with a progress bar that replaces the previous one instead of stacking.
# Usage: volume.sh up|down|mute|mic

case "$1" in
up)   wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
mic)  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
*)    echo "usage: $0 up|down|mute|mic" >&2; exit 1 ;;
esac

# $1 tag, $2 icon, $3 summary, $4 percentage (omitted: no bar)
osd() {
    dunstify -a osd -u low -t 1500 -i "$2" \
        -h string:x-dunst-stack-tag:"$1" ${4:+-h int:value:"$4"} "$3"
}

if [ "$1" = mic ]; then
    # wpctl prints e.g. "Volume: 1.00 [MUTED]"
    case "$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)" in
    *MUTED*) osd mic microphone-sensitivity-muted "Microphone muted" ;;
    *)       osd mic audio-input-microphone "Microphone on" ;;
    esac
    exit
fi

out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
vol=$(echo "$out" | awk '{ printf "%d", $2 * 100 + 0.5 }')
case "$out" in
*MUTED*) osd volume audio-volume-muted "Muted" ;;
*)
    if [ "$vol" -ge 66 ]; then icon=audio-volume-high
    elif [ "$vol" -ge 33 ]; then icon=audio-volume-medium
    else icon=audio-volume-low; fi
    osd volume "$icon" "Volume $vol%" "$vol"
    ;;
esac
