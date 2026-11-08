// Session commands shared by the power menu and the launcher. Everything runs through Hyprland
// rather than as a child of Quickshell, so it isn't tied to quickshell.service (whatever it
// starts would be killed whenever that restarts) and window rules apply as usual.
pragma Singleton

import Quickshell
import Quickshell.Hyprland

Singleton {
    function shellQuote(s) {
        return `'${s.replace(/'/g, "'\\''")}'`;
    }

    // `cmd` is a shell command line; it goes into a Lua string literal for hl.dsp.exec_cmd.
    function run(cmd) {
        Hyprland.dispatch(`hl.dsp.exec_cmd("${cmd.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}")`);
    }

    // hyprshutdown closes windows gracefully first (same as the old hyprland-dialog menu).
    function lock() {
        run("loginctl lock-session");
    }
    function logout() {
        run("hyprshutdown");
    }
    function reboot() {
        run("hyprshutdown -p 'systemctl reboot'");
    }
    function poweroff() {
        run("hyprshutdown -p 'systemctl poweroff'");
    }
}
