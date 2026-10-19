import QtQuick
import org.kde.kirigami as Kirigami

// Colour set for the launcher (named AppTheme because QtQuick already has a built-in `Palette` type).
//   theme "gnome"  -> dark Adwaita-style look of the GNOME app grid
//   theme "system" -> follows the active KDE / Plasma colour scheme
//   custom.enabled -> user-chosen colours override either theme
Item {
    id: pal

    property string theme: "gnome"
    property var custom: ({})

    readonly property bool gnome: theme !== "system"
    readonly property bool useCustom: custom !== null && custom !== undefined && custom.enabled === true

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    function alpha(c, v) {
        return Qt.rgba(c.r, c.g, c.b, v)
    }

    function hex(v, fallback) {
        return (typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v)) ? v : fallback
    }

    // user colours (only meaningful when useCustom)
    readonly property color cBackdrop: hex(custom ? custom.backdrop : undefined, "#0a0a0a")
    readonly property real cBackdropA: Math.max(0, Math.min(100, (custom && custom.backdropOpacity !== undefined) ? custom.backdropOpacity : 72)) / 100
    readonly property color cPopup: hex(custom ? custom.popup : undefined, "#2e2e2e")
    readonly property color cText: hex(custom ? custom.text : undefined, "#ffffff")
    readonly property color cAccent: hex(custom ? custom.accent : undefined, "#3584e4")

    // full-screen backdrop behind the grid
    readonly property color backdrop: useCustom ? alpha(cBackdrop, cBackdropA)
                                      : (gnome ? Qt.rgba(0.04, 0.04, 0.04, 0.72)
                                               : alpha(Kirigami.Theme.backgroundColor, 0.9))
    readonly property color text: useCustom ? cText : (gnome ? "#ffffff" : Kirigami.Theme.textColor)
    readonly property color textDim: alpha(text, 0.65)
    readonly property color hover: useCustom ? alpha(cText, 0.12)
                                   : (gnome ? Qt.rgba(1, 1, 1, 0.12) : alpha(Kirigami.Theme.highlightColor, 0.25))
    readonly property color folderTile: useCustom ? alpha(cText, 0.16)
                                        : (gnome ? Qt.rgba(1, 1, 1, 0.16) : alpha(Kirigami.Theme.textColor, 0.14))

    // fully opaque surfaces: group pop-up, context menu, rename prompt
    readonly property color popupBg: useCustom ? cPopup : (gnome ? "#2e2e2e" : Kirigami.Theme.backgroundColor)
    readonly property color menuBg: popupBg
    readonly property color popupBorder: useCustom ? alpha(cText, 0.1)
                                         : (gnome ? Qt.rgba(1, 1, 1, 0.08) : alpha(Kirigami.Theme.textColor, 0.2))

    readonly property color fieldBg: useCustom ? alpha(cText, 0.12)
                                     : (gnome ? Qt.rgba(1, 1, 1, 0.12) : alpha(Kirigami.Theme.textColor, 0.1))
    readonly property color button: fieldBg
    readonly property color accent: useCustom ? cAccent : (gnome ? "#3584e4" : Kirigami.Theme.highlightColor)
    readonly property color accentText: useCustom ? "#ffffff" : (gnome ? "#ffffff" : Kirigami.Theme.highlightedTextColor)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)
}
