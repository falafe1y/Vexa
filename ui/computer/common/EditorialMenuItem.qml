import QtQuick
import QtQuick.Controls

MenuItem {
    id: control
    property bool destructive: false
    readonly property bool emphasized: enabled && (highlighted || hovered || down)
    readonly property color foreground: !enabled ? "#59616a" : emphasized ? "#f3eddf" : destructive ? "#b84932" : "#031528"
    implicitHeight: 48
    leftPadding: 12
    rightPadding: 12
    hoverEnabled: true
    font.family: "Arimo"
    font.pixelSize: 16
    palette.windowText: foreground
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.foreground
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        color: control.emphasized ? (control.destructive ? "#b84932" : "#031528") : "transparent"
    }
}
