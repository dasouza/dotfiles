#!/bin/sh
# Keybind cheatsheet, built from $XDG_RUNTIME_DIR/hypr/keybinds.tsv (written by conf/binds.lua on
# start/reload, so it always matches the loaded binds).
# Usage: keybinds.sh        searchable menu (hyprlauncher); picking an entry runs it
#        keybinds.sh html   printable cheatsheet opened in the browser
dir="${XDG_RUNTIME_DIR:-/tmp}/hypr"
list="$dir/keybinds.tsv"

if [ ! -s "$list" ]; then
    notify-send -a keybinds "Keybind cheatsheet" "No keybind list yet — reload Hyprland (it's written on start/reload)."
    exit 1
fi

# Menu line for a TSV record: "Super + R   Enter resize mode   · Resize mode"
menu_lines() { awk -F'\t' '{ printf "%s   %s   · %s\n", $3, $4, $2 }' "$list"; }

if [ "$1" = html ]; then
    out="$dir/keybinds.html"
    {
        cat <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hyprland Keybinds</title>
<style>
  :root { --bg: #1e1e2e; --card: #262637; --fg: #cdd6f4; --muted: #a6adc8; --accent: #89b4fa; --key: #313244; --key-border: #45475a; }
  @media (prefers-color-scheme: light) {
    :root { --bg: #eff1f5; --card: #ffffff; --fg: #2b2d3a; --muted: #5c5f77; --accent: #1e66f5; --key: #e6e9ef; --key-border: #bcc0cc; }
  }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 24px 16px; background: var(--bg); color: var(--fg);
         font: 14px/1.4 "JetBrainsMono Nerd Font", ui-monospace, monospace; }
  header { max-width: 1200px; margin: 0 auto 16px; display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; }
  h1 { margin: 0; font-size: 20px; }
  header p { margin: 0; color: var(--muted); font-size: 12px; }
  main { max-width: 1200px; margin: 0 auto; columns: 320px 3; column-gap: 16px; }
  section { break-inside: avoid; background: var(--card); border-radius: 10px; padding: 12px 14px; margin: 0 0 16px; }
  h2 { margin: 0 0 8px; font-size: 13px; text-transform: uppercase; letter-spacing: .06em; color: var(--accent); }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 3px 0; vertical-align: top; }
  td:first-child { white-space: nowrap; padding-right: 12px; }
  kbd { display: inline-block; padding: 0 5px; border: 1px solid var(--key-border); border-bottom-width: 2px;
        border-radius: 4px; background: var(--key); font: inherit; font-size: 12px; }
  @page { size: A4 landscape; margin: 10mm; }
  @media print {
    :root { --bg: #fff; --card: #fff; --fg: #000; --muted: #444; --accent: #1e40af; --key: #f2f2f2; --key-border: #999; }
    body { padding: 0; font-size: 10.5px; }
    section { border: 1px solid #ccc; padding: 8px 10px; margin-bottom: 8px; }
    main { columns: 3; }
  }
</style></head><body>
<header><h1>Hyprland keybinds</h1>
<p>Super+F1 searches these · generated from conf/binds.lua · Ctrl+P to print</p></header>
<main>
EOF
        awk -F'\t' '
            function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
            # "Super + Shift + R" → <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>R</kbd>
            function keys(s,   n, parts, i, r) {
                n = split(s, parts, / \+ /)
                for (i = 1; i <= n; i++) r = r (i > 1 ? " + " : "") "<kbd>" esc(parts[i]) "</kbd>"
                return r
            }
            $2 != sec { if (sec != "") print "</table></section>"; sec = $2; print "<section><h2>" esc(sec) "</h2><table>" }
            { print "<tr><td>" keys($3) "</td><td>" esc($4) "</td></tr>" }
            END { if (sec != "") print "</table></section>" }
        ' "$list"
        printf '</main></body></html>\n'
    } > "$out"
    xdg-open "$out" >/dev/null 2>&1 &
    exit
fi

sel=$(menu_lines | hyprlauncher --dmenu) || exit 0
[ -n "$sel" ] || exit 0

# Index of the picked entry (0 = cheatsheet-only line, e.g. "Super + 1-0")
n=$(menu_lines | awk -v s="$sel" 'index($0, s) == 1 && length($0) == length(s) { print NR; exit }')
[ -n "$n" ] || exit 0
idx=$(sed -n "${n}p" "$list" | cut -f1)
if [ "$idx" = 0 ]; then
    notify-send -a keybinds "Keybind" "$sel"
    exit
fi
res=$(hyprctl eval "keybinds_run($idx)")
[ "$res" = ok ] || notify-send -a keybinds "Couldn't run that keybind" "Press the keys instead: $sel"
