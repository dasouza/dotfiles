// CPU, GPU, memory and disk figures for the bar's Performance module, read from /proc, /sys and
// df. Polled every 2s (disk every minute). Sensor paths come from scripts/sensors.sh at startup.
// AMD GPUs are read from sysfs; NVIDIA ones through nvidia-smi, skipped while the card is
// runtime-suspended (hybrid laptops) because querying it would wake it up.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpu: 0         // %
    property int cpuTemp: 0     // °C
    property int gpu: 0         // %
    property int gpuTemp: 0     // °C
    property real vramUsed: 0   // bytes, like the rest
    property real vramTotal: 0
    property real memUsed: 0
    property real memTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0

    property var sensors: ({})
    readonly property bool hasGpu: sensors.gpu !== undefined
    readonly property bool nvidia: sensors.gpuDriver === "nvidia"
    readonly property bool amdGpu: hasGpu && !nvidia
    property bool gpuAsleep: false // NVIDIA dGPU powered down (hybrid laptop on the iGPU)
    // "13th Gen Intel(R) Core(TM) i7-13700K" → "Intel Core i7-13700K"
    readonly property string cpuName: (sensors.cpuName ?? "").replace(/\((R|TM)\)/g, "").replace(/^\d+\w* Gen /, "")
    readonly property string gpuName: sensors.gpuName ?? ""

    function gib(bytes) {
        return (bytes / 1073741824).toFixed(1);
    }

    Process {
        running: true
        command: ["sh", Quickshell.shellPath("scripts/sensors.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        found[line.slice(0, i)] = line.slice(i + 1);
                }
                root.sensors = found;
            }
        }
    }

    property var lastStat: null
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // "cpu user nice system idle iowait irq softirq steal ..."; iowait counts as idle
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            if (root.lastStat) {
                const dt = total - root.lastStat.total;
                root.cpu = dt > 0 ? Math.round(100 * (dt - (idle - root.lastStat.idle)) / dt) : 0;
            }
            root.lastStat = { total, idle };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kib = key => Number(text().match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))[1]);
            root.memTotal = kib("MemTotal") * 1024;
            root.memUsed = root.memTotal - kib("MemAvailable") * 1024;
        }
    }

    FileView {
        id: cpuTempFile
        path: root.sensors.cpuTemp ?? ""
        onLoaded: root.cpuTemp = Math.round(Number(text()) / 1000)
    }
    FileView {
        id: gpuBusyFile
        path: root.amdGpu ? `${root.sensors.gpu}/gpu_busy_percent` : ""
        onLoaded: root.gpu = Number(text())
    }
    FileView {
        id: gpuTempFile
        path: root.sensors.gpuTemp ?? ""
        onLoaded: root.gpuTemp = Math.round(Number(text()) / 1000)
    }
    FileView {
        id: vramUsedFile
        path: root.amdGpu ? `${root.sensors.gpu}/mem_info_vram_used` : ""
        onLoaded: root.vramUsed = Number(text())
    }
    FileView {
        path: root.amdGpu ? `${root.sensors.gpu}/mem_info_vram_total` : ""
        onLoaded: root.vramTotal = Number(text())
    }

    // NVIDIA: "active"/"suspended" (or "unsupported" without runtime PM, e.g. a desktop card)
    FileView {
        id: nvidiaPowerFile
        path: root.nvidia ? `${root.sensors.gpu}/power/runtime_status` : ""
        onLoaded: {
            root.gpuAsleep = text().trim() === "suspended";
            if (root.gpuAsleep) {
                root.gpu = 0;
                root.gpuTemp = 0;
                root.vramUsed = 0;
            } else if (!nvidiaSmi.running) {
                nvidiaSmi.running = true;
            }
        }
    }
    Process {
        id: nvidiaSmi
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
                  "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "12, 45, 512, 8188" (MiB); fields can be "[N/A]"
                const f = text.trim().split("\n")[0].split(",").map(s => Number(s.trim()) || 0);
                if (f.length < 4)
                    return;
                root.gpu = f[0];
                root.gpuTemp = f[1];
                root.vramUsed = f[2] * 1048576;
                root.vramTotal = f[3] * 1048576;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            for (const f of [cpuTempFile, gpuBusyFile, gpuTempFile, vramUsedFile, nvidiaPowerFile])
                if (f.path)
                    f.reload();
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [used, size] = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                root.diskUsed = used;
                root.diskTotal = size;
            }
        }
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }
}
