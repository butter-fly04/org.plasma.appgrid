import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "General"
        icon: "preferences-desktop-icons"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: "Layout"
        icon: "view-list-icons"
        source: "ConfigLayout.qml"
    }
    ConfigCategory {
        name: "Appearance"
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name: "Backup"
        icon: "document-export"
        source: "ConfigBackup.qml"
    }
}
