import QtQuick
import QtQuick.Controls.Basic as Basic
import UI

Basic.Button {
    id: control
    property bool outlined: true
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
        color: control.outlined && control.hovered
               ? DesktopTheme.paper
               : control.danger ? DesktopTheme.accent : DesktopTheme.ink
    }

    background: Rectangle {
        color: control.outlined && control.hovered
               ? DesktopTheme.ink : "transparent"
        border.width: control.outlined || control.activeFocus ? 1 : 0
        border.color: control.activeFocus ? DesktopTheme.accent : DesktopTheme.ink
    }
}
