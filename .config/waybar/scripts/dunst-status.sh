#!/bin/sh
# Waybar custom module: dunst notification state as JSON (alt/class match format-icons and state.css)
if [ "$(dunstctl is-paused)" = "true" ]; then
    prefix="dnd-"
    count=$(dunstctl count waiting)
else
    prefix=""
    count=$(dunstctl count history)
fi

if [ "${count:-0}" -gt 0 ]; then state="${prefix}notification"; else state="${prefix}none"; fi

printf '{"alt":"%s","class":"%s","tooltip":"%s notification(s)"}\n' "$state" "$state" "${count:-0}"
