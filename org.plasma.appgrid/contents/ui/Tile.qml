import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// One grid cell: icon (or 2x2 folder preview for a group) plus label.
Item {
    id: tile

    property var entry
    property var backend
    property var colors
    property int iconSz: 64
    property bool selected: false      // keyboard selection

    signal activated()
    signal menuRequested(real mx, real my)   // position inside this tile
    signal mouseMoved()                      // the pointer actually moved over this tile

    property bool animated: true
    scale: (animated && ma.containsMouse) ? (ma.pressed ? 0.96 : 1.04) : 1.0
    Behavior on scale { enabled: tile.animated; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    readonly property bool isApp: entry ? entry.type === "app" : true
    readonly property var info: (entry && isApp && backend) ? backend.appIndex[entry.id] : null

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 12
        color: (tile.selected || ma.containsMouse) ? (tile.colors ? tile.colors.hover : Qt.rgba(1, 1, 1, 0.16)) : "transparent"
        Behavior on color { enabled: tile.animated; ColorAnimation { duration: 120 } }
        border.width: tile.selected ? 2 : 0
        border.color: tile.colors ? tile.colors.accent : "#3584e4"
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 12
        spacing: 6

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: tile.iconSz
            height: tile.iconSz

            Kirigami.Icon {
                anchors.fill: parent
                visible: tile.isApp
                source: tile.info ? tile.info.icon : ""
            }

            Rectangle {
                anchors.fill: parent
                visible: !tile.isApp
                radius: 14
                color: tile.colors ? tile.colors.folderTile : Qt.rgba(1, 1, 1, 0.18)

                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 4
                    Repeater {
                        model: (!tile.isApp && tile.entry) ? tile.entry.items.slice(0, 4) : []
                        delegate: Kirigami.Icon {
                            required property string modelData
                            width: tile.iconSz * 0.4
                            height: tile.iconSz * 0.4
                            source: tile.backend.appIndex[modelData] ? tile.backend.appIndex[modelData].icon : ""
                        }
                    }
                }
            }
        }

        QQC2.Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: tile.colors ? tile.colors.text : "white"
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
            text: tile.info ? tile.info.name : (tile.entry && !tile.isApp ? tile.entry.name : "")
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: tile.mouseMoved()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                tile.menuRequested(mouse.x, mouse.y)
            } else {
                tile.activated()
            }
        }
    }
}
