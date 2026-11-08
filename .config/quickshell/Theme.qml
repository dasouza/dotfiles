// Dune amber palette, shared with the hypr borders (conf/looks.lua), hyprlock, hyprtoolkit.conf and ghostty.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property color background: "#e6231f18"
    readonly property color surface: "#352f27"
    // Empty part of gauges/bars and card borders: visible on both background and surface,
    // and the accent fill on it is 3.9:1.
    readonly property color track: "#5c5142"
    readonly property color text: "#ebe1d4"
    readonly property color textDim: "#d1c5b4"
    readonly property color accent: "#e0b070"
    readonly property color accentText: "#422c05"
    readonly property color urgent: "#ff6b5e"
    readonly property color good: "#a6e3a1"
    readonly property color warning: "#f9e2af"

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13      // popups, OSD
    readonly property int barFontSize: 15   // bar text and icons
    readonly property int barHeight: 36
    readonly property int radius: 10
    readonly property int spacing: 8
}
