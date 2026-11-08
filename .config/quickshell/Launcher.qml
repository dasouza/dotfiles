import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services

// App launcher (replaces hyprlauncher on Super+Space): slides up from the bottom centre, styled
// like the notification cards. The search box is at the bottom and the best match sits right
// above it. Fuzzy search over name, generic name, keywords and description; apps you launch
// often rank higher (counts in the state dir).
// Prefixes: ">" commands (lock, power, notifications…), "=" calculator (Enter copies the result).
// Keys: Up/Down, Tab/Shift+Tab or Ctrl+K/J move, Enter runs, Escape or clicking outside closes.
PanelWindow {
    id: launcher

    property bool open: false
    readonly property int maxShown: 8
    readonly property int rowHeight: 56

    function toggle() {
        open = !open;
    }
    onOpenChanged: {
        if (open) {
            input.text = "";
            list.currentIndex = 0;
            Qt.callLater(() => input.forceActiveFocus()); // once the window is mapped
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            launcher.toggle();
        }
    }

    // Kept mapped while the card slides out.
    visible: open || slide.running
    anchors.bottom: true
    margins.bottom: 12
    exclusiveZone: 0
    implicitWidth: 600
    implicitHeight: card.implicitHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: launcher.open
        windows: [launcher]
        onCleared: launcher.open = false
    }

    // ---- Running things ------------------------------------------------------------------------
    // Through services/Session.qml, i.e. via Hyprland, so apps aren't tied to quickshell.service.
    // App ids and arguments are shell-quoted.

    function launchApp(entry) {
        const counts = Object.assign({}, usage.counts);
        counts[entry.id] = (counts[entry.id] ?? 0) + 1;
        usage.counts = counts;
        saveTimer.restart();
        if (entry.runInTerminal)
            Session.run(`ghostty -e ${entry.command.map(Session.shellQuote).join(" ")}`);
        else
            Session.run(`gtk-launch ${Session.shellQuote(entry.id)}`);
    }
    function activate(item) {
        if (!item)
            return;
        open = false;
        item.run();
    }

    // Same commands as the Super+M power menu and the notification keybinds.
    readonly property var actions: [
        { name: "Lock", comment: "Lock the screen", glyph: 0xf033e, run: () => Session.lock() },
        { name: "Log out", comment: "Close all windows and end the session", glyph: 0xf0343, run: () => Session.logout() },
        { name: "Restart", comment: "Close all windows and reboot", glyph: 0xf0709, run: () => Session.reboot() },
        { name: "Shut down", comment: "Close all windows and power off", glyph: 0xf0425, run: () => Session.poweroff() },
        { name: "Do not disturb", comment: "Toggle notification popups", glyph: 0xf009b, run: () => Notifs.dnd = !Notifs.dnd },
        { name: "Notification centre", comment: "Open the notification history", glyph: 0xf009a, run: () => Notifs.centerOpen = true },
        { name: "Clear notifications", comment: "Empty the notification history", glyph: 0xf0e2c, run: () => Notifs.clearAll() },
        { name: "Keybinds", comment: "Search the keybind cheatsheet", glyph: 0xf030c, run: () => Session.run("~/.config/hypr/scripts/keybinds.sh") },
        { name: "Reload Hyprland", comment: "Re-read the Hyprland config", glyph: 0xf0450, run: () => Session.run("hyprctl reload") }
    ]

    // ---- Search --------------------------------------------------------------------------------

    // Higher is better, -1 = no match: exact > prefix > substring > in-order letters
    // (fewer gaps and letters at word starts score more).
    function fuzzy(query, text) {
        const t = (text ?? "").toLowerCase();
        if (!t)
            return -1;
        if (t === query)
            return 1000;
        if (t.startsWith(query))
            return 800 - t.length;
        const at = t.indexOf(query);
        if (at >= 0)
            return 600 - at + (/[\s\-_.]/.test(t[at - 1] ?? "") ? 50 : 0);
        let score = 300, ti = 0, last = -1;
        for (const c of query) {
            const found = t.indexOf(c, ti);
            if (found < 0)
                return -1;
            if (last >= 0)
                score -= Math.min(found - last - 1, 10) * 3;
            if (found === 0 || /[\s\-_.]/.test(t[found - 1]))
                score += 10;
            last = found;
            ti = found + 1;
        }
        return score;
    }

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    readonly property string query: input.text.trim()

    readonly property var results: {
        const q = query.toLowerCase();

        // Only digits, operators, brackets and "e" get evaluated.
        if (q.startsWith("=")) {
            const expr = q.slice(1).replace(/,/g, ".").replace(/\^/g, "**").trim();
            if (!expr)
                return [{ glyph: 0xf00ec, name: "Calculator", comment: "Type an expression, e.g. = 2^10 / 3", run: () => {} }];
            if (!/^[\d\s+\-*/%().e]+$/.test(expr))
                return [];
            try {
                const value = Function(`"use strict"; return (${expr});`)();
                if (typeof value !== "number" || !isFinite(value))
                    return [];
                const text = String(Number(value.toPrecision(12)));
                return [{ glyph: 0xf00ec, name: text, comment: "Enter to copy", run: () => Quickshell.execDetached(["wl-copy", text]) }];
            } catch (err) {
                return [];
            }
        }

        if (q.startsWith(">")) {
            const sub = q.slice(1).trim();
            return actions.map(a => ({ a, s: sub ? fuzzy(sub, a.name) : 0 }))
                          .filter(r => r.s >= 0)
                          .sort((x, y) => y.s - x.s)
                          .map(r => r.a);
        }

        const counts = usage.counts;
        const ranked = apps.map(e => {
            let s = q ? Math.max(fuzzy(q, e.name), fuzzy(q, e.genericName) - 50,
                                 ...e.keywords.map(k => fuzzy(q, k) - 100), fuzzy(q, e.comment) - 250) : 0;
            if (s >= 0)
                s += 40 * Math.log2(1 + (counts[e.id] ?? 0));
            return { e, s };
        }).filter(r => r.s >= 0);
        ranked.sort((x, y) => y.s - x.s || x.e.name.localeCompare(y.e.name));
        return ranked.slice(0, 50).map(r => ({
            name: r.e.name,
            comment: r.e.comment || r.e.genericName,
            icon: r.e.icon,
            run: () => launchApp(r.e)
        }));
    }
    onResultsChanged: list.currentIndex = 0

    // Launch counts, saved 1s after a launch.
    QtObject {
        id: usage
        property var counts: ({})
    }
    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher.json")
        onLoaded: {
            try {
                usage.counts = JSON.parse(text()).counts ?? {};
            } catch (err) {
                console.warn("launcher.json unreadable:", err);
            }
        }
    }
    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: usageFile.setText(JSON.stringify({ counts: usage.counts }))
    }

    // ---- Look ----------------------------------------------------------------------------------

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 24
        radius: 18
        color: Theme.background
        border.color: Theme.accent
        border.width: 2

        // Slides up into the window from below its bottom edge, fading in.
        y: launcher.open ? 0 : height
        opacity: launcher.open ? 1 : 0
        Behavior on y {
            NumberAnimation { id: slide; duration: 250; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // Best match at the bottom, next to the search box; Up goes to the next result.
            ListView {
                id: list
                Layout.fillWidth: true
                implicitHeight: Math.min(count, launcher.maxShown) * launcher.rowHeight
                visible: count > 0
                clip: true
                verticalLayoutDirection: ListView.BottomToTop
                boundsBehavior: Flickable.StopAtBounds
                model: launcher.results
                highlightMoveDuration: 120
                highlightResizeDuration: 0
                highlight: Rectangle {
                    radius: 12
                    color: Theme.surface
                    border.color: Theme.accent
                    border.width: 1
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: launcher.rowHeight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            implicitWidth: 40
                            implicitHeight: 40

                            IconImage {
                                anchors.fill: parent
                                visible: row.modelData.icon !== undefined
                                source: row.modelData.icon !== undefined ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: row.modelData.glyph !== undefined
                                radius: 20
                                color: Theme.track

                                Text {
                                    anchors.centerIn: parent
                                    text: row.modelData.glyph ? String.fromCodePoint(row.modelData.glyph) : ""
                                    color: Theme.accent
                                    font.family: "JetBrainsMono Nerd Font Propo"
                                    font.pixelSize: 20
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                elide: Text.ElideRight
                                color: row.ListView.isCurrentItem ? Theme.accent : Theme.text
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.comment ?? ""
                                elide: Text.ElideRight
                                color: Theme.textDim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: launcher.activate(row.modelData)
                    }
                }
            }

            Text {
                visible: list.count === 0 && launcher.query !== ""
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                horizontalAlignment: Text.AlignHCenter
                text: launcher.query.startsWith("=") ? "Not a valid expression" : "No results"
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }

            // Search box.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                radius: 12
                color: Theme.surface
                border.color: input.activeFocus ? Theme.accent : Theme.track
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: String.fromCodePoint(launcher.query.startsWith(">") ? 0xf018d
                                                 : launcher.query.startsWith("=") ? 0xf00ec : 0xf0349)
                        color: Theme.accent
                        font.family: "JetBrainsMono Nerd Font Propo"
                        font.pixelSize: 18
                    }

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: 'Search apps   ">" commands   "=" calculator'
                            color: Theme.textDim
                            font: input.font
                        }

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            const up = event.key === Qt.Key_Up || event.key === Qt.Key_Tab
                                       || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P));
                            const down = event.key === Qt.Key_Down || event.key === Qt.Key_Backtab
                                         || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N));
                            if (up) {
                                list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1);
                            } else if (down) {
                                list.currentIndex = Math.max(list.currentIndex - 1, 0);
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                launcher.activate(launcher.results[list.currentIndex]);
                            } else if (event.key === Qt.Key_Escape) {
                                launcher.open = false;
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
