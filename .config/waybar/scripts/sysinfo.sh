#!/bin/sh
# Waybar custom modules for the left-side system stats.
# Usage: sysinfo.sh cpu|temp|disk|mem — prints Waybar JSON: the bar text, a hover tooltip with
# details, a warning/critical class for state.css, and a percentage that picks the format-icons entry.
export LC_ALL=C # dots as decimal separators in top/df output

# $1 text, $2 tooltip, $3 class, $4 percentage
out() { jq -cn --arg t "$1" --arg tt "$2" --arg c "$3" --argjson p "${4:-0}" \
    '{text: $t, tooltip: $tt, class: $c, percentage: $p}'; }

# $1 value, $2 warning threshold, $3 critical threshold
level() { awk -v v="$1" -v w="$2" -v c="$3" 'BEGIN { print (v >= c ? "critical" : v >= w ? "warning" : "") }'; }

# $1 hwmon dir, $2 sensor label → whole °C
hw_temp() {
    for l in "$1"/temp*_label; do
        [ "$(cat "$l")" = "$2" ] && { echo $(($(cat "${l%_label}_input") / 1000)); return; }
    done
}

case "$1" in
cpu)
    # Usage since the previous run, from /proc/stat deltas (iowait counts as idle, like Waybar's cpu module)
    state="${XDG_RUNTIME_DIR:-/tmp}/waybar-sysinfo-cpu"
    read -r _ u n s i w q sq st _ < /proc/stat
    total=$((u + n + s + i + w + q + sq + st))
    idle=$((i + w))
    if [ -r "$state" ]; then read -r ptotal pidle < "$state"; else ptotal=0 pidle=0; fi
    echo "$total $idle" > "$state"
    dt=$((total - ptotal))
    usage=$((dt > 0 ? 100 * (dt - (idle - pidle)) / dt : 0))

    model=$(sed -n 's/^model name\s*: //p' /proc/cpuinfo | head -1)
    mhz=$(awk '/^cpu MHz/ { s += $4; n++ } END { if (n) printf "%.0f", s / n }' /proc/cpuinfo)
    read -r l1 l5 l15 _ < /proc/loadavg
    # Current per-process usage needs two samples; the first top iteration is averaged since process start
    procs=$(top -b -n 2 -d 0.5 -o %CPU -w 200 | awk '
        /^top -/ { n++ }
        n == 2 && hdr && $9 > 0 {
            cmd = $12; for (i = 13; i <= NF; i++) cmd = cmd " " $i
            printf "%-18.18s %6.1f%%\n", cmd, $9
            if (++k == 5) exit
        }
        n == 2 && /^ *PID/ { hdr = 1 }')
    tip=$(printf '%s\n%s threads · avg %s MHz\nLoad  %s  %s  %s\n\nTop processes (%% of one core):\n%s' \
        "$model" "$(nproc)" "$mhz" "$l1" "$l5" "$l15" "$procs")
    out "$usage%" "$tip" "$(level "$usage" 75 90)" "$usage"
    ;;
temp)
    cpu="" gpu="" nvme=""
    for h in /sys/class/hwmon/hwmon*; do
        case $(cat "$h/name") in
        coretemp)
            pkg=$(hw_temp "$h" "Package id 0")
            cores=$(for l in "$h"/temp*_label; do
                case $(cat "$l") in Core*) cat "${l%_label}_input" ;; esac
            done | awk '{ s += $1; if ($1 > m) m = $1 } END { printf "%.0f°C avg · %.0f°C max", s / NR / 1000, m / 1000 }')
            cpu=$(printf 'CPU package      %s°C\nCPU cores        %s' "$pkg" "$cores")
            ;;
        amdgpu)
            gpu=$(printf 'GPU edge         %s°C\nGPU junction     %s°C\nGPU memory       %s°C' \
                "$(hw_temp "$h" edge)" "$(hw_temp "$h" junction)" "$(hw_temp "$h" mem)")
            ;;
        nvme)
            dev=$(basename "$(readlink -f "$h/device")")
            size=$(awk '{ print $NF }' "$h/device/model")
            nvme=$(printf '%s\n%-16s %s°C' "$nvme" "$dev ($size)" "$(hw_temp "$h" Composite)")
            ;;
        esac
    done
    nvme=$(printf '%s' "$nvme" | sed '/^$/d' | sort)
    tip=$(printf '%s\n\n%s\n\n%s' "$cpu" "$gpu" "$nvme")
    # 4 format-icons: the first three scale up to the 80°C critical point, the last one marks critical
    if [ "${pkg:-0}" -ge 80 ]; then class=critical pct=100; else class="" pct=$((${pkg:-0} * 74 / 80)); fi
    out "${pkg:-?}°C" "$tip" "$class" "$pct"
    ;;
disk)
    set -- $(df -h --output=used,pcent / | awk 'NR == 2 { sub(/%/, "", $2); print $1, $2 }')
    used=$1 pct=$2
    # One line per device: btrfs subvolumes like / and /home share a filesystem and its figures
    tip=$(df -h -x tmpfs -x devtmpfs -x efivarfs -x overlay --output=source,target,used,size,pcent |
        awk 'NR > 1 && !seen[$1]++ { printf "%-17s %5s / %-5s %4s\n", $2, $3, $4, $5 }')
    out "$used" "$tip" "$(level "$pct" 80 90)" "$pct"
    ;;
mem)
    eval "$(awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/ { sub(/:/, "", $1); print $1 "=" $2 }' /proc/meminfo)"
    used=$((MemTotal - MemAvailable))
    pct=$((100 * used / MemTotal))
    gib() { awk -v k="$1" 'BEGIN { printf "%.1fG", k / 1048576 }'; }
    tip=$(printf 'RAM    %s / %s  (%s%%)\nAvail  %s' "$(gib $used)" "$(gib "$MemTotal")" "$pct" "$(gib "$MemAvailable")")
    [ "$SwapTotal" -gt 0 ] && tip=$(printf '%s\nSwap   %s / %s' "$tip" "$(gib $((SwapTotal - SwapFree)))" "$(gib "$SwapTotal")")
    # RSS summed per program name, so multi-process apps (java, browsers) count once
    procs=$(ps -eo rss=,comm= | awk '{ r = $1; $1 = ""; sub(/^ /, ""); m[$0] += r }
        END { for (c in m) printf "%d\t%s\n", m[c], c }' | sort -rn | head -5 |
        awk -F'\t' '{ printf "%-18.18s %6.1fG\n", $2, $1 / 1048576 }')
    tip=$(printf '%s\n\nTop programs:\n%s' "$tip" "$procs")
    out "$(gib $used)" "$tip" "$(level "$pct" 75 85)" "$pct"
    ;;
*)
    echo "usage: $0 cpu|temp|disk|mem" >&2
    exit 1
    ;;
esac
