// Notification daemon. Every notification becomes an entry in `history` (newest
// first, max 50), saved to the state dir so it survives restarts; `popups` are the ones on screen.
// Popups.qml shows popups, modules/NotifCenter.qml the history, modules/Bell.qml the count.
// After a restart, restored entries keep their text but their action buttons are gone.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Do-not-disturb set by hand (bell / centre / Super+N). The game workspace pauses on top of it,
    // so leaving workspace 10 never clears a DND you set yourself.
    property bool dnd: false
    readonly property bool onGameWorkspace: Hyprland.focusedMonitor?.activeWorkspace?.id === 10
    readonly property bool paused: dnd || onGameWorkspace

    property bool centerOpen: false
    onCenterOpenChanged: if (centerOpen) popups = []

    property var history: []
    property var popups: []
    readonly property int maxHistory: 50

    // Ticks every 30s so "5m"-style ages stay current.
    property real now: Date.now()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }
    function age(time) {
        const m = Math.floor((now - time) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m}m` : m < 1440 ? `${Math.floor(m / 60)}h` : `${Math.floor(m / 1440)}d`;
    }

    // Per-app rules: short popup, kept out of history.
    function isTransient(e) {
        return e.appName === "Spotify" || e.transientHint;
    }

    // Milliseconds; 0 = stays until dismissed. Sender-supplied timeouts (seconds) win, else urgency.
    function timeoutFor(e) {
        if (e.appName === "Spotify")
            return 3000;
        if (e.expireTimeout > 0)
            return e.expireTimeout * 1000;
        switch (e.urgency) {
        case NotificationUrgency.Critical: return 0;
        case NotificationUrgency.Low: return 5000;
        default: return 8000;
        }
    }

    function showPopup(e) {
        if (!centerOpen)
            popups = [e, ...popups.filter(p => p !== e)];
    }

    function hidePopup(e) {
        popups = popups.filter(p => p !== e);
        if (isTransient(e))
            e.notification?.expire();
    }

    function hideAllPopups() {
        for (const e of popups)
            hidePopup(e);
    }

    function remove(e) {
        popups = popups.filter(p => p !== e);
        history = history.filter(h => h !== e);
        e.notification?.dismiss();
    }

    function clearAll() {
        for (const e of history)
            e.notification?.dismiss();
        popups = [];
        history = [];
    }

    // Runs the notification's default action (what clicking it in the app would do), if it's still live.
    function invokeDefault(e) {
        e.notification?.actions.find(a => a.identifier === "default")?.invoke();
    }

    // Image hints served by Quickshell (image://...) don't outlive the process; only files/URLs are kept.
    function keepable(url) {
        return url && !url.startsWith("image://") ? url : "";
    }

    function fields(n) {
        return {
            notifId: n.id,
            appName: n.appName,
            appIcon: n.appIcon,
            desktopEntry: n.desktopEntry,
            image: n.image,
            summary: n.summary,
            body: n.body,
            urgency: n.urgency,
            transientHint: n.transient,
            expireTimeout: n.expireTimeout,
            progress: Number(n.hints?.value ?? -1)
        };
    }

    function track(n, e) {
        e.notification = n;
        // Apps update notifications in place (progress, edited messages): refresh and re-show.
        const update = () => {
            Object.assign(e, fields(n), { time: Date.now() });
            if (!root.paused)
                root.showPopup(e);
        };
        n.summaryChanged.connect(update);
        n.bodyChanged.connect(update);
        n.hintsChanged.connect(update);
        // The app withdrew it (e.g. Slack after you read the message): drop it everywhere.
        n.closed.connect(reason => {
            if (reason === NotificationCloseReason.CloseRequested) {
                root.popups = root.popups.filter(p => p !== e);
                root.history = root.history.filter(h => h !== e);
            }
        });
    }

    function add(n) {
        n.tracked = true;
        const e = entryComponent.createObject(null, fields(n));
        track(n, e);
        if (!isTransient(e)) {
            const kept = [e, ...history];
            for (const old of kept.slice(maxHistory))
                old.notification?.dismiss();
            history = kept.slice(0, maxHistory);
        }
        if (!paused)
            showPopup(e);
        else if (isTransient(e))
            n.expire();
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => root.add(n)
    }

    Component {
        id: entryComponent

        QtObject {
            property var notification: null
            property int notifId
            property string appName
            property string appIcon
            property string desktopEntry
            property string image
            property string summary
            property string body
            property int urgency: NotificationUrgency.Normal
            property bool transientHint: false
            property real expireTimeout: -1
            property int progress: -1 // 0–100 from the "value" hint, -1 without
            property real time: Date.now()
            readonly property var actions: notification?.actions ?? []
        }
    }

    // Saved as { dnd, notifications: [...] }, 1s after the last change.
    property bool restored: false
    FileView {
        id: store
        path: Quickshell.statePath("notifications.json")
        onLoaded: root.restore(text())
        onLoadFailed: root.restored = true // first run: no file yet
    }
    function restore(json) {
        if (restored)
            return;
        let saved = {};
        try {
            saved = JSON.parse(json);
        } catch (err) {
            console.warn("notifications.json unreadable, starting empty:", err);
        }
        dnd = saved.dnd ?? false;
        // After a config reload the notifications are still live (keepOnReload): reattach them.
        const live = server.trackedNotifications.values;
        const entries = (saved.notifications ?? []).map(s => {
            const e = entryComponent.createObject(null, s);
            const n = live.find(l => l.id === s.notifId && l.summary === s.summary);
            if (n)
                track(n, e);
            return e;
        });
        for (const n of live)
            if (!entries.some(e => e.notification === n))
                entries.push(entryComponent.createObject(null, fields(n)));
        history = [...entries, ...history].sort((a, b) => b.time - a.time).slice(0, maxHistory);
        restored = true;
    }
    function save() {
        store.setText(JSON.stringify({
            dnd,
            notifications: history.map(e => ({
                notifId: e.notifId,
                appName: e.appName,
                appIcon: keepable(e.appIcon),
                desktopEntry: e.desktopEntry,
                image: keepable(e.image),
                summary: e.summary,
                body: e.body,
                urgency: e.urgency,
                time: e.time
            }))
        }));
    }
    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: root.save()
    }
    onHistoryChanged: if (restored) saveTimer.restart()
    onDndChanged: if (restored) saveTimer.restart()

    // `qs ipc call notifs <fn>`: Super+N / Super+Shift+N in hypr/conf/binds.lua.
    IpcHandler {
        target: "notifs"

        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
        function toggleCenter(): void {
            root.centerOpen = !root.centerOpen;
        }
        function clear(): void {
            root.clearAll();
        }
    }
}
