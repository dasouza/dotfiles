-- Programs shared by the other config files: local programs = require("conf.programs")
return {
    terminal    = "ghostty",
    fileManager = "dolphin",
    menu        = "qs ipc call launcher toggle", -- quickshell/Launcher.qml (hyprlauncher still does the dmenu pickers)
}
