#!/bin/sh
# Find the sensor files services/Resources.qml polls (hwmon and card numbers change between boots)
# and the CPU/GPU names. Prints key=value lines.
#
# GPU: on a hybrid laptop or a desktop with the iGPU enabled, the discrete card is the interesting
# one, so an NVIDIA card wins, then the AMD card with the most VRAM (an APU's carve-out is small).
# Intel GPUs don't report their load, so a machine with only one gets no GPU card in the bar.
# QS_GPU_NAME (set from hypr/local.lua) overrides the name, for when pci.ids is too vague.

for l in /sys/class/hwmon/hwmon*/temp*_label; do
    case "$(cat "$l")" in
    "Package id 0" | Tctl) echo "cpuTemp=${l%_label}_input"; break ;;
    esac
done

gpu='' driver='' best=0
for c in /sys/class/drm/card[0-9]*; do
    case "$c" in *-*) continue ;; esac # connectors (card1-DP-1...)
    d=$c/device
    case "$(sed -n 's/^DRIVER=//p' "$d/uevent" 2>/dev/null)" in
    nvidia)
        gpu=$d driver=nvidia
        break ;;
    amdgpu)
        [ -r "$d/gpu_busy_percent" ] || continue
        vram=$(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0)
        if [ "$vram" -gt "$best" ]; then best=$vram gpu=$d driver=amdgpu; fi ;;
    esac
done

if [ -n "$gpu" ]; then
    echo "gpu=$gpu"
    echo "gpuDriver=$driver"
    if [ "$driver" = amdgpu ]; then
        for l in "$gpu"/hwmon/hwmon*/temp*_label; do
            [ "$(cat "$l")" = edge ] && echo "gpuTemp=${l%_label}_input"
        done
    fi
    name=${QS_GPU_NAME:-}
    if [ -z "$name" ]; then
        vendor=$(cut -c3- "$gpu/vendor") device=$(cut -c3- "$gpu/device")
        # pci.ids names the chip with the marketing name in brackets: "Navi 48 [Radeon RX 9070/9070 XT/9070 GRE]"
        name=$(awk -v v="$vendor" -v p="$device" '
            /^#/ { next }
            !/^\t/ { if (found) exit; found = ($1 == v); next }
            found && $1 == p { sub(/^\t[0-9a-f]+ +/, ""); print; exit }' /usr/share/hwdata/pci.ids |
            sed 's/.*\[\(.*\)\].*/\1/')
    fi
    echo "gpuName=$name"
fi

echo "cpuName=$(sed -n 's/^model name\s*: //p' /proc/cpuinfo | head -1)"
