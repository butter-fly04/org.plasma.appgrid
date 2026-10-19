import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Export / import of this widget's own settings (layout, groups, hidden apps, theme).
KCM.SimpleKCM {
    id: page

    property string cfg_layoutJson
    property string cfg_layoutJsonDefault
    property string cfg_hiddenJson
    property string cfg_hiddenJsonDefault
    property string cfg_powerActions
    property string cfg_powerActionsDefault
    property string cfg_theme
    property string cfg_themeDefault
    property int cfg_iconSize
    property int cfg_iconSizeDefault
    property int cfg_hSpacing
    property int cfg_hSpacingDefault
    property int cfg_vSpacing
    property int cfg_vSpacingDefault
    property bool cfg_useCustomColors
    property bool cfg_useCustomColorsDefault
    property string cfg_colorBackdrop
    property string cfg_colorBackdropDefault
    property int cfg_colorBackdropOpacity
    property int cfg_colorBackdropOpacityDefault
    property string cfg_colorPopup
    property string cfg_colorPopupDefault
    property string cfg_colorText
    property string cfg_colorTextDefault
    property string cfg_colorAccent
    property string cfg_colorAccentDefault

    readonly property string format: "org.example.appgrid.settings"

    property QtObject io: null
    property string ioError: ""
    property string statusText: ""
    property bool statusOk: true

    readonly property string exportText: buildExport()

    function buildExport() {
        var lay = [], hid = []
        try {
            lay = JSON.parse(cfg_layoutJson)
        } catch (e) {
            lay = []
        }
        try {
            hid = JSON.parse(cfg_hiddenJson)
        } catch (e2) {
            hid = []
        }
        return JSON.stringify({
            format: format,
            version: 1,
            theme: cfg_theme === "system" ? "system" : "gnome",
            layout: lay,
            hidden: hid,
            powerActions: cfg_powerActions,
            appearance: {
                iconSize: cfg_iconSize,
                hSpacing: cfg_hSpacing,
                vSpacing: cfg_vSpacing,
                customColors: {
                    enabled: cfg_useCustomColors,
                    backdrop: cfg_colorBackdrop,
                    backdropOpacity: cfg_colorBackdropOpacity,
                    popup: cfg_colorPopup,
                    text: cfg_colorText,
                    accent: cfg_colorAccent
                }
            }
        }, null, 2)
    }

    function setStatus(ok, msg) {
        statusOk = ok
        statusText = msg
    }

    function copyExport() {
        clip.text = exportText
        clip.selectAll()
        clip.copy()
        setStatus(true, "Copied to the clipboard.")
    }

    function isHex(v) {
        return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v)
    }

    function clampInt(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    function importAppearance(ap) {
        if (!ap || typeof ap !== "object") {
            return
        }
        if (typeof ap.iconSize === "number") {
            cfg_iconSize = ap.iconSize <= 0 ? 0 : clampInt(ap.iconSize, 24, 256)
        }
        if (typeof ap.hSpacing === "number") {
            cfg_hSpacing = ap.hSpacing < 0 ? -1 : clampInt(ap.hSpacing, 0, 200)
        }
        if (typeof ap.vSpacing === "number") {
            cfg_vSpacing = ap.vSpacing < 0 ? -1 : clampInt(ap.vSpacing, 0, 200)
        }
        var cc = ap.customColors
        if (cc && typeof cc === "object") {
            cfg_useCustomColors = cc.enabled === true
            if (isHex(cc.backdrop)) {
                cfg_colorBackdrop = cc.backdrop.toLowerCase()
            }
            if (typeof cc.backdropOpacity === "number") {
                cfg_colorBackdropOpacity = clampInt(cc.backdropOpacity, 0, 100)
            }
            if (isHex(cc.popup)) {
                cfg_colorPopup = cc.popup.toLowerCase()
            }
            if (isHex(cc.text)) {
                cfg_colorText = cc.text.toLowerCase()
            }
            if (isHex(cc.accent)) {
                cfg_colorAccent = cc.accent.toLowerCase()
            }
        }
    }

    function importText(t) {
        var o
        try {
            o = JSON.parse(t)
        } catch (e) {
            setStatus(false, "That isn't valid JSON: " + e.message)
            return
        }
        if (!o || o.format !== format || !Array.isArray(o.layout)) {
            setStatus(false, "That isn't a settings export from this launcher.")
            return
        }
        var lay = []
        o.layout.forEach(function (e) {
            if (e && e.type === "app" && typeof e.id === "string") {
                lay.push({ type: "app", id: e.id })
            } else if (e && e.type === "group" && Array.isArray(e.items)) {
                lay.push({
                    type: "group",
                    name: String(e.name || "Group"),
                    gid: typeof e.gid === "string" ? e.gid : undefined,
                    items: e.items.filter(function (i) { return typeof i === "string" })
                })
            }
        })
        var hid = Array.isArray(o.hidden) ? o.hidden.filter(function (i) { return typeof i === "string" }) : []
        cfg_layoutJson = JSON.stringify(lay)
        cfg_hiddenJson = JSON.stringify(hid)
        cfg_theme = o.theme === "system" ? "system" : "gnome"
        if (typeof o.powerActions === "string") {
            cfg_powerActions = o.powerActions.split(",").filter(function (a) { return ["lock","sleep","hibernate","restart","shutdown","logout"].indexOf(a) >= 0 }).join(",")
        }
        importAppearance(o.appearance)
        setStatus(true, "Imported. Press Apply to use these settings.")
    }

    Component.onCompleted: {
        var c = Qt.createComponent(Qt.resolvedUrl("FileIO.qml"))
        if (c.status === Component.Ready) {
            io = c.createObject(page)
            io.saved.connect(function (p) { page.setStatus(true, "Saved to " + p) })
            io.loaded.connect(function (t) { page.importText(t) })
            io.failed.connect(function (m) { page.setStatus(false, m) })
        } else {
            ioError = c.errorString()
        }
    }

    TextEdit {
        id: clip
        visible: false
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "Back up or move this launcher's settings: app order, groups, hidden apps, theme, icon size, spacing and colours. Nothing from the system application menu is included. Export reflects the settings as saved, so press Apply on other pages first."
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.ioError.length > 0
            type: Kirigami.MessageType.Warning
            text: "File access isn't available here, so use copy and paste instead."
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.statusText.length > 0
            type: page.statusOk ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
            text: page.statusText
        }

        Kirigami.Heading {
            level: 3
            text: "Export"
        }
        RowLayout {
            QQC2.Button {
                text: "Save to file…"
                icon.name: "document-save"
                enabled: page.io !== null
                onClicked: page.io.chooseSave(page.exportText)
            }
            QQC2.Button {
                text: "Copy to clipboard"
                icon.name: "edit-copy"
                onClicked: page.copyExport()
            }
        }
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 9
            QQC2.TextArea {
                readOnly: true
                text: page.exportText
                font.family: "monospace"
                wrapMode: TextEdit.NoWrap
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            level: 3
            text: "Import"
        }
        QQC2.Button {
            text: "Load from file…"
            icon.name: "document-open"
            enabled: page.io !== null
            onClicked: page.io.chooseLoad()
        }
        QQC2.Label {
            text: "Or paste exported settings here:"
        }
        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 7
            QQC2.TextArea {
                id: pasteArea
                font.family: "monospace"
                wrapMode: TextEdit.NoWrap
                placeholderText: "{ \"format\": \"" + page.format + "\", … }"
            }
        }
        QQC2.Button {
            text: "Import pasted text"
            icon.name: "document-import"
            enabled: pasteArea.text.trim().length > 0
            onClicked: page.importText(pasteArea.text)
        }
    }
}
