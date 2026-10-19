import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

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

    function isHex(v) {
        return /^#[0-9a-fA-F]{6}$/.test(v)
    }

    // size in px with an "Automatic" switch (value === autoMarker means automatic)
    component SizeRow: RowLayout {
        id: sr

        property int value
        property int autoMarker: 0
        property int fallback: 64
        property int from: 0
        property int to: 200

        signal edited(int v)

        QQC2.CheckBox {
            text: "Automatic"
            checked: sr.value === sr.autoMarker
            onToggled: sr.edited(checked ? sr.autoMarker : sr.fallback)
        }
        QQC2.SpinBox {
            enabled: sr.value !== sr.autoMarker
            from: sr.from
            to: sr.to
            value: sr.value !== sr.autoMarker ? sr.value : sr.fallback
            onValueModified: sr.edited(value)
        }
        QQC2.Label {
            text: "px"
            opacity: 0.7
        }
    }

    // #rrggbb field with a colour swatch
    component HexRow: RowLayout {
        id: hr

        property string value

        signal edited(string v)

        QQC2.TextField {
            id: field
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            text: hr.value
            maximumLength: 7
            validator: RegularExpressionValidator {
                regularExpression: /^#[0-9a-fA-F]{0,6}$/
            }
            onEditingFinished: {
                if (page.isHex(text)) {
                    hr.edited(text.toLowerCase())
                } else {
                    text = hr.value
                }
            }
        }
        Rectangle {
            implicitWidth: Kirigami.Units.gridUnit * 3
            implicitHeight: field.implicitHeight
            radius: 4
            color: page.isHex(field.text) ? field.text : hr.value
            border.width: 1
            border.color: Qt.rgba(0.5, 0.5, 0.5, 0.6)
        }
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: "Theme:"
            model: [
                { text: "GNOME", value: "gnome" },
                { text: "System (current KDE theme)", value: "system" }
            ]
            textRole: "text"
            currentIndex: page.cfg_theme === "system" ? 1 : 0
            onActivated: i => page.cfg_theme = model[i].value
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            wrapMode: Text.Wrap
            opacity: 0.7
            text: page.cfg_theme === "system"
                  ? "Colours follow your current KDE / Plasma colour scheme. Pop-ups are opaque."
                  : "Dark GNOME-style colours: translucent dark backdrop, pill-shaped search box and opaque dark pop-ups."
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Icons and spacing"
        }

        SizeRow {
            Kirigami.FormData.label: "Icon size:"
            value: page.cfg_iconSize
            autoMarker: 0
            fallback: 64
            from: 24
            to: 256
            onEdited: v => page.cfg_iconSize = v
        }
        SizeRow {
            Kirigami.FormData.label: "Horizontal spacing:"
            value: page.cfg_hSpacing
            autoMarker: -1
            fallback: 20
            from: 0
            to: 200
            onEdited: v => page.cfg_hSpacing = v
        }
        SizeRow {
            Kirigami.FormData.label: "Vertical spacing:"
            value: page.cfg_vSpacing
            autoMarker: -1
            fallback: 8
            from: 0
            to: 200
            onEdited: v => page.cfg_vSpacing = v
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            wrapMode: Text.Wrap
            opacity: 0.7
            text: "Automatic icon size follows your system. Automatic horizontal spacing stretches the grid to fill the screen width; a fixed value gives exactly that gap."
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Custom colours"
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Colours:"
            text: "Use custom colours (override the theme)"
            checked: page.cfg_useCustomColors
            onToggled: page.cfg_useCustomColors = checked
        }
        HexRow {
            Kirigami.FormData.label: "Background:"
            enabled: page.cfg_useCustomColors
            value: page.cfg_colorBackdrop
            onEdited: v => page.cfg_colorBackdrop = v
        }
        RowLayout {
            Kirigami.FormData.label: "Background opacity:"
            enabled: page.cfg_useCustomColors
            QQC2.Slider {
                from: 0
                to: 100
                stepSize: 1
                value: page.cfg_colorBackdropOpacity
                onMoved: page.cfg_colorBackdropOpacity = Math.round(value)
            }
            QQC2.Label {
                text: page.cfg_colorBackdropOpacity + " %"
            }
        }
        HexRow {
            Kirigami.FormData.label: "Pop-ups and menus:"
            enabled: page.cfg_useCustomColors
            value: page.cfg_colorPopup
            onEdited: v => page.cfg_colorPopup = v
        }
        HexRow {
            Kirigami.FormData.label: "Text:"
            enabled: page.cfg_useCustomColors
            value: page.cfg_colorText
            onEdited: v => page.cfg_colorText = v
        }
        HexRow {
            Kirigami.FormData.label: "Accent:"
            enabled: page.cfg_useCustomColors
            value: page.cfg_colorAccent
            onEdited: v => page.cfg_colorAccent = v
        }
        QQC2.Button {
            text: "Reset custom colours"
            icon.name: "edit-reset"
            enabled: page.cfg_useCustomColors
            onClicked: {
                page.cfg_colorBackdrop = page.cfg_colorBackdropDefault
                page.cfg_colorBackdropOpacity = page.cfg_colorBackdropOpacityDefault
                page.cfg_colorPopup = page.cfg_colorPopupDefault
                page.cfg_colorText = page.cfg_colorTextDefault
                page.cfg_colorAccent = page.cfg_colorAccentDefault
            }
        }
    }
}
