import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_icon
    property string cfg_iconDefault
    property bool cfg_useCustomButtonImage
    property bool cfg_useCustomButtonImageDefault
    property string cfg_customButtonImage
    property string cfg_customButtonImageDefault
    property bool cfg_animations
    property bool cfg_animationsDefault
    property string cfg_powerActions
    property string cfg_powerActionsDefault

    readonly property var allActions: [
        { id: "lock", name: "Lock screen" },
        { id: "sleep", name: "Sleep" },
        { id: "hibernate", name: "Hibernate" },
        { id: "restart", name: "Restart" },
        { id: "shutdown", name: "Shut down" },
        { id: "logout", name: "Log out" }
    ]

    function hasAction(id) {
        return cfg_powerActions.split(",").indexOf(id) >= 0
    }

    // keeps the fixed order lock, sleep, hibernate, restart, shut down, log out
    function setAction(id, on) {
        cfg_powerActions = allActions
            .filter(function (a) { return a.id === id ? on : hasAction(a.id) })
            .map(function (a) { return a.id })
            .join(",")
    }

    readonly property string currentIconSource: (cfg_useCustomButtonImage && cfg_customButtonImage.length > 0)
                                                ? cfg_customButtonImage : cfg_icon

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: "Panel icon:"
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: page.currentIconSource
                fallback: "view-app-grid"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            QQC2.Button {
                text: "Choose icon…"
                icon.name: "preferences-desktop-icons"
                enabled: picker.status === Loader.Ready
                onClicked: picker.item.chooseIcon()
            }
            QQC2.Button {
                text: "Custom image…"
                icon.name: "document-open"
                enabled: picker.status === Loader.Ready
                onClicked: picker.item.chooseImage()
            }
            QQC2.Button {
                text: "Default"
                icon.name: "edit-reset"
                onClicked: {
                    page.cfg_icon = page.cfg_iconDefault
                    page.cfg_useCustomButtonImage = false
                }
            }
        }

        // loaded lazily so a missing module cannot break this page
        Loader {
            id: picker
            source: "IconPicker.qml"
        }

        QQC2.TextField {
            Kirigami.FormData.label: "Icon name:"
            visible: picker.status === Loader.Error
            placeholderText: "e.g. view-app-grid"
            text: page.cfg_icon
            onEditingFinished: {
                page.cfg_icon = text
                page.cfg_useCustomButtonImage = false
            }
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            wrapMode: Text.Wrap
            opacity: 0.7
            visible: picker.status === Loader.Error
            text: "The icon chooser isn't available on this system, so type an icon name instead."
        }

        Connections {
            target: picker.item
            ignoreUnknownSignals: true
            function onIconChosen(name) {
                page.cfg_icon = name
                page.cfg_useCustomButtonImage = false
            }
            function onImageChosen(url) {
                page.cfg_customButtonImage = url
                page.cfg_useCustomButtonImage = true
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Animations:"
            text: "Fade, zoom and hover effects"
            checked: page.cfg_animations
            onToggled: page.cfg_animations = checked
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Power and session buttons"
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            wrapMode: Text.Wrap
            opacity: 0.7
            text: "Shown as icons at the right end of the search bar. Untick any you don't want."
        }

        Repeater {
            model: page.allActions

            delegate: QQC2.CheckBox {
                required property var modelData
                text: modelData.name
                checked: page.hasAction(modelData.id)
                onToggled: page.setAction(modelData.id, checked)
            }
        }
    }
}
