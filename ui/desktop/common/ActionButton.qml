import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.Button {
    id: control
    property bool outlined: false
    property bool danger: false
    implicitHeight: 40
    implicitWidth: label.implicitWidth + 28
    leftPadding: 14
    rightPadding: 14
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4

    contentItem: EditorialText {
        id: label
        text: control.text
        font.family: DesktopTheme.mono
        font.pixelSize: 12
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        color: control.hovered && control.enabled ? DesktopTheme.accent : DesktopTheme.ink
    }

    background: Rectangle {
        color: "transparent"
        border.width: 1
        border.color: DesktopTheme.ink
    }
}
