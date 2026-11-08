//@ pragma UseQApplication
// Entry point. Run `qs` to start; files hot-reload on save.
// UseQApplication: tray apps' right-click menus are platform menus, which need it.
import Quickshell

ShellRoot {
    Bar {}
    Osd {}
    Popups {}
    Launcher {}
    PowerMenu {}
}
