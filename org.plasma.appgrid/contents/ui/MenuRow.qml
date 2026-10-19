import QtQuick
import QtQuick.Controls as QQC2

// One row of the in-window context menu (plain QML, no Qt popups).
Rectangle {
    id: row

    property var colors
    property alias text: label.text
    property bool header: false

    signal triggered()

    width: parent ? parent.width : 0
    height: Math.round(label.implicitHeight + (header ? 10 : 14))
    radius: 6
    color: (!header && ma.containsMouse) ? (colors ? colors.hover : Qt.rgba(1, 1, 1, 0.18)) : "transparent"

    QQC2.Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        elide: Text.ElideRight
        color: row.colors ? (row.header ? row.colors.textDim : row.colors.text) : "white"
        font.bold: row.header
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: !row.header
        onClicked: row.triggered()
    }
}
