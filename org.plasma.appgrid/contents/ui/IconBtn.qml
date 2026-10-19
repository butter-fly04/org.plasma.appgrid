import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Round icon button with an in-window tooltip (plain QML, no popups).
Item {
    id: btn

    property var colors
    property string iconName
    property string tip
    property real boundsWidth: 0      // window width, used to keep the tooltip on screen

    signal clicked()
    scale: ma.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 100 } }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ma.containsMouse ? (btn.colors ? btn.colors.hover : Qt.rgba(1, 1, 1, 0.16)) : "transparent"
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.round(btn.height * 0.55)
        height: width
        source: btn.iconName
        isMask: true
        color: btn.colors ? btn.colors.text : "white"
    }

    Timer {
        id: tipTimer
        interval: 450
        onTriggered: {
            var gx = btn.mapToItem(null, 0, 0).x
            var want = gx + (btn.width - tipBox.width) / 2
            var maxX = btn.boundsWidth > 0 ? btn.boundsWidth - tipBox.width - 8 : want
            tipBox.x = Math.round(Math.max(8, Math.min(want, maxX)) - gx)
            tipBox.shown = true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: {
            if (containsMouse) {
                tipTimer.restart()
            } else {
                tipTimer.stop()
                tipBox.shown = false
            }
        }
        onClicked: {
            tipTimer.stop()
            tipBox.shown = false
            btn.clicked()
        }
    }

    Rectangle {
        id: tipBox
        property bool shown: false
        visible: shown
        z: 1000
        y: btn.height + 6
        width: tipLabel.implicitWidth + 20
        height: tipLabel.implicitHeight + 10
        radius: 6
        color: btn.colors ? btn.colors.popupBg : "#2e2e2e"
        border.width: 1
        border.color: btn.colors ? btn.colors.popupBorder : Qt.rgba(1, 1, 1, 0.1)

        QQC2.Label {
            id: tipLabel
            anchors.centerIn: parent
            text: btn.tip
            color: btn.colors ? btn.colors.text : "white"
        }
    }
}
