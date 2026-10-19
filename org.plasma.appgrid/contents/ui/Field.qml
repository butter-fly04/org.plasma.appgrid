import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Pill-shaped text field coloured from a Palette (search box, rename box).
QQC2.TextField {
    id: field

    property var colors

    color: colors ? colors.text : "white"
    placeholderTextColor: colors ? colors.textDim : "gray"
    selectionColor: colors ? colors.accent : "#3584e4"
    selectedTextColor: colors ? colors.accentText : "white"
    leftPadding: Kirigami.Units.gridUnit
    rightPadding: Kirigami.Units.gridUnit
    topPadding: 8
    bottomPadding: 8

    background: Rectangle {
        radius: height / 2
        color: field.colors ? field.colors.fieldBg : "#33ffffff"
        border.width: field.activeFocus ? 2 : 0
        border.color: field.colors ? field.colors.accent : "#3584e4"
    }
}
