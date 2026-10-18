import QtQuick
import QtQuick.Controls
import "EditorialStyle.js" as Appearance

ScrollBar {
    id: control
    readonly property bool editorial: Appearance.desktop
    policy: ScrollBar.AlwaysOff
    visible: policy !== ScrollBar.AlwaysOff && (policy === ScrollBar.AlwaysOn || size < 1)

    property color appAccentColor: editorial ? "#031528" : "#315C9B"
    property color appTrackColor: editorial ? "#bbb5a8" : "#E8E7DA"

    hoverEnabled: true
    implicitWidth: orientation === Qt.Vertical ? 8 : 100
    implicitHeight: orientation === Qt.Horizontal ? 8 : 100

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: control.editorial ? 0 : 3
        color: control.appAccentColor
        opacity: control.pressed ? 0.85 : control.hovered ? 0.68 : 0.42
    }

    background: Rectangle {
        radius: control.editorial ? 0 : 3
        color: control.appTrackColor
        opacity: control.active || control.hovered ? 0.42 : 0
    }
}
