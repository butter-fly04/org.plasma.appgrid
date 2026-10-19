import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Flat button coloured from a Palette (used in the rename prompt).
Rectangle {
    id: btn

    property var colors
    property alias text: label.text
    property bool primary: false

    signal clicked()

    implicitWidth: label.implicitWidth + Kirigami.Units.gridUnit * 2
    implicitHeight: label.implicitHeight + 16
    radius: 8
    color: !colors ? "#444444"
                   : (primary ? colors.accent : (ma.containsMouse ? colors.hover : colors.button))

    QQC2.Label {
        id: label
        anchors.centerIn: parent
        color: btn.colors ? (btn.primary ? btn.colors.accentText : btn.colors.text) : "white"
        font.bold: btn.primary
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
